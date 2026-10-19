local log = require('gitgraph.log')
local config = require('gitgraph').config

local M = {}

--- Execute a command interactively in a floating terminal window
--- This ensures SSH key passphrases, credentials, and pinentry prompts work seamlessly and securely.
---@param cmd string[]
---@param title string
---@param on_done? fun(success: boolean)
function M.run_interactive(cmd, title, on_done)
  local width = math.min(math.floor(vim.o.columns * 0.8), 100)
  local height = math.min(math.floor(vim.o.lines * 0.5), 20)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })

  local success = false
  local full_cmd = type(cmd) == 'table' and table.concat(cmd, ' ') or cmd

  vim.fn.termopen(full_cmd, {
    on_exit = function(_, exit_code)
      success = (exit_code == 0)
      vim.schedule(function()
        if success then
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
          if on_done then
            on_done(true)
          end
        else
          vim.notify('[gitgraph] ' .. title .. ' exited with code ' .. tostring(exit_code) .. '. Press <q> or <Enter> in the terminal to close.', vim.log.levels.WARN)
          -- Map q and <CR> to close the window on failure so user can read the error message
          if vim.api.nvim_buf_is_valid(buf) then
            vim.keymap.set('n', 'q', function()
              if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
              end
              if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
              end
              if on_done then
                on_done(false)
              end
            end, { buffer = buf, nowait = true })
            vim.keymap.set('n', '<CR>', function()
              if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
              end
              if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
              end
              if on_done then
                on_done(false)
              end
            end, { buffer = buf, nowait = true })
          end
        end
      end)
    end,
  })

  -- Automatically enter terminal insert mode so user can type passphrase / key prompt immediately
  vim.cmd('startinsert')
end

--- Execute a git command asynchronously or synchronously
---@param args string[]
---@param opts? { on_success?: fun(out: string), on_error?: fun(err: string), silent?: boolean }
function M.run(args, opts)
  opts = opts or {}
  local git_cmd = (config and config.git_cmd) or 'git'
  local cmd = vim.list_extend({ git_cmd }, args)

  if vim.system then
    vim.system(cmd, { text = true }, function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          if not opts.silent and obj.stdout and #obj.stdout > 0 then
            log.info(obj.stdout)
          end
          if opts.on_success then
            opts.on_success(obj.stdout)
          end
        else
          local err_msg = (obj.stderr and #obj.stderr > 0 and obj.stderr) or (obj.stdout or 'git command failed')
          vim.notify('[gitgraph] ' .. vim.trim(err_msg), vim.log.levels.ERROR)
          if opts.on_error then
            opts.on_error(err_msg)
          end
        end
      end)
    end)
  else
    -- Fallback for older Neovim versions
    local full_cmd = table.concat(cmd, ' ')
    local handle = io.popen(full_cmd .. ' 2>&1')
    if not handle then
      vim.notify('[gitgraph] failed to spawn ' .. full_cmd, vim.log.levels.ERROR)
      return
    end
    local output = handle:read('*a')
    local success = handle:close()
    if success then
      if opts.on_success then
        opts.on_success(output)
      end
    else
      vim.notify('[gitgraph] ' .. vim.trim(output), vim.log.levels.ERROR)
      if opts.on_error then
        opts.on_error(output)
      end
    end
  end
end

--- Get current active branch name
---@param cb fun(branch: string?)
function M.get_current_branch(cb)
  M.run({ 'rev-parse', '--abbrev-ref', 'HEAD' }, {
    silent = true,
    on_success = function(out)
      cb(vim.trim(out))
    end,
    on_error = function()
      cb(nil)
    end,
  })
end

--- Checkout commit, branch, or tag
---@param target string
---@param on_done fun()
---@param opts? { pull?: boolean, no_pull?: boolean }
function M.checkout(target, on_done, opts)
  opts = opts or {}

  -- If explicitly requested no_pull (e.g. keymap 'C'), checkout directly without pulling
  if opts.no_pull then
    M.run({ 'checkout', target }, {
      on_success = function()
        vim.notify('[gitgraph] Checked out: ' .. target, vim.log.levels.INFO)
        on_done()
      end,
    })
    return
  end

  -- If explicitly requested pull (e.g. keymap 'c'), checkout and pull if tracking branch exists
  if opts.pull then
    M.run({ 'checkout', target }, {
      on_success = function()
        local git_cmd = (config and config.git_cmd) or 'git'
        M.run_interactive({ git_cmd, 'pull' }, 'Git Pull (' .. target .. ')', function(ok)
          if ok then
            vim.notify('[gitgraph] Checked out and pulled: ' .. target, vim.log.levels.INFO)
          else
            vim.notify('[gitgraph] Checked out ' .. target .. ' (pull had errors or cancelled)', vim.log.levels.WARN)
          end
          on_done()
        end)
      end,
    })
    return
  end

  -- Default behavior: Check if target is a local branch with an upstream
  M.run({ 'rev-parse', '--verify', 'refs/heads/' .. target }, {
    silent = true,
    on_success = function()
      -- It is a local branch, check if upstream exists and if it is behind
      M.run({ 'rev-list', '--count', target .. '..@{u}' }, {
        silent = true,
        on_success = function(behind_count_str)
          local behind = tonumber(vim.trim(behind_count_str)) or 0
          if behind > 0 then
            vim.ui.select({
              '1. Checkout & Pull (' .. behind .. ' commit(s) behind)',
              '2. Checkout local only',
              '3. Cancel',
            }, {
              prompt = 'Branch ' .. target .. ' is behind upstream by ' .. behind .. ' commit(s):',
            }, function(choice)
              if not choice or choice:match('^3') then
                return
              end
              if choice:match('^1') then
                M.run({ 'checkout', target }, {
                  on_success = function()
                    local git_cmd = (config and config.git_cmd) or 'git'
                    M.run_interactive({ git_cmd, 'pull' }, 'Git Pull (' .. target .. ')', function(ok)
                      if ok then
                        vim.notify('[gitgraph] Checked out and pulled: ' .. target, vim.log.levels.INFO)
                      else
                        vim.notify('[gitgraph] Checked out ' .. target .. ' (pull had errors or cancelled)', vim.log.levels.WARN)
                      end
                      on_done()
                    end)
                  end,
                })
              else
                M.run({ 'checkout', target }, {
                  on_success = function()
                    vim.notify('[gitgraph] Checked out: ' .. target, vim.log.levels.INFO)
                    on_done()
                  end,
                })
              end
            end)
            return
          end

          -- Not behind, regular checkout
          M.run({ 'checkout', target }, {
            on_success = function()
              vim.notify('[gitgraph] Checked out: ' .. target, vim.log.levels.INFO)
              on_done()
            end,
          })
        end,
        on_error = function()
          -- No upstream tracking branch, regular checkout
          M.run({ 'checkout', target }, {
            on_success = function()
              vim.notify('[gitgraph] Checked out: ' .. target, vim.log.levels.INFO)
              on_done()
            end,
          })
        end,
      })
    end,
    on_error = function()
      -- Not a local branch (commit hash or tag or remote branch)
      M.run({ 'checkout', target }, {
        on_success = function()
          vim.notify('[gitgraph] Checked out: ' .. target, vim.log.levels.INFO)
          on_done()
        end,
      })
    end,
  })
end

--- Create branch at commit
---@param base_target string
---@param checkout_after boolean
---@param on_done fun()
function M.create_branch(base_target, checkout_after, on_done)
  local action_str = checkout_after and 'Create & checkout branch' or 'Create branch'
  vim.ui.input({ prompt = action_str .. ' (at ' .. base_target:sub(1, 7) .. '): ' }, function(name)
    if not name or name == '' then
      return
    end
    local cmd = checkout_after and { 'checkout', '-b', name, base_target } or { 'branch', name, base_target }
    M.run(cmd, {
      on_success = function()
        local msg = checkout_after and ('Created & checked out branch: ' .. name) or ('Created branch: ' .. name)
        vim.notify('[gitgraph] ' .. msg, vim.log.levels.INFO)
        on_done()
      end,
    })
  end)
end

--- Create tag at commit
---@param commit_hash string
---@param push_after boolean
---@param on_done fun()
function M.add_tag(commit_hash, push_after, on_done)
  vim.ui.input({ prompt = 'Tag name' .. (push_after and ' (will push)' or '') .. ': ' }, function(tag_name)
    if not tag_name or tag_name == '' then
      return
    end
    vim.ui.input({ prompt = 'Tag message (optional): ' }, function(msg)
      local args = { 'tag' }
      if msg and msg ~= '' then
        table.insert(args, '-a')
        table.insert(args, tag_name)
        table.insert(args, '-m')
        table.insert(args, msg)
      else
        table.insert(args, tag_name)
      end
      table.insert(args, commit_hash)

      M.run(args, {
        on_success = function()
          if push_after then
            local git_cmd = (config and config.git_cmd) or 'git'
            M.run_interactive({ git_cmd, 'push', 'origin', tag_name }, 'Git Push Tag (' .. tag_name .. ')', function(ok)
              if ok then
                vim.notify('[gitgraph] Added and pushed tag: ' .. tag_name, vim.log.levels.INFO)
              else
                vim.notify('[gitgraph] Added tag ' .. tag_name .. ' (push failed or cancelled)', vim.log.levels.WARN)
              end
              on_done()
            end)
          else
            vim.notify('[gitgraph] Added tag: ' .. tag_name, vim.log.levels.INFO)
            on_done()
          end
        end,
      })
    end)
  end)
end

--- Cherry pick commit
---@param commit_hash string
---@param no_commit boolean if true, applies changes staged without committing (-n / --no-commit)
---@param on_done fun()
function M.cherry_pick(commit_hash, no_commit, on_done)
  local args = no_commit and { 'cherry-pick', '--no-commit', commit_hash } or { 'cherry-pick', commit_hash }
  M.run(args, {
    on_success = function()
      local short = commit_hash:sub(1, 7)
      if no_commit then
        vim.notify('[gitgraph] Cherry-picked ' .. short .. ' (staged, not committed)', vim.log.levels.INFO)
        on_done()
        -- Open diffview for review if available
        pcall(vim.cmd, 'DiffviewOpen')
      else
        vim.notify('[gitgraph] Cherry-picked: ' .. short, vim.log.levels.INFO)
        on_done()
      end
    end,
  })
end

--- Revert commit
---@param commit_hash string
---@param on_done fun()
function M.revert(commit_hash, on_done)
  M.run({ 'revert', '--no-edit', commit_hash }, {
    on_success = function()
      vim.notify('[gitgraph] Reverted: ' .. commit_hash:sub(1, 7), vim.log.levels.INFO)
      on_done()
    end,
  })
end

--- Reset to commit
---@param commit_hash string
---@param on_done fun()
function M.reset(commit_hash, on_done)
  vim.ui.select({
    { label = 'Soft (--soft) Keep staged changes', flag = '--soft' },
    { label = 'Mixed (--mixed) Keep unstaged working changes', flag = '--mixed' },
    { label = 'Hard (--hard) Discard all changes', flag = '--hard' },
  }, {
    prompt = 'Select reset mode for ' .. commit_hash:sub(1, 7) .. ':',
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    M.run({ 'reset', choice.flag, commit_hash }, {
      on_success = function()
        vim.notify('[gitgraph] Reset ' .. choice.flag .. ' to ' .. commit_hash:sub(1, 7), vim.log.levels.INFO)
        on_done()
      end,
    })
  end)
end

--- Merge branch/commit into current branch
---@param target string
---@param no_commit boolean if true, merges without commit (--no-commit --no-ff) and opens diffview
---@param on_done fun()
function M.merge(target, no_commit, on_done)
  local args = no_commit and { 'merge', '--no-commit', '--no-ff', target } or { 'merge', target }
  M.run(args, {
    on_success = function()
      if no_commit then
        vim.notify('[gitgraph] Merged ' .. target .. ' (staged, not committed)', vim.log.levels.INFO)
        on_done()
        pcall(vim.cmd, 'DiffviewOpen')
      else
        vim.notify('[gitgraph] Merged ' .. target .. ' into HEAD', vim.log.levels.INFO)
        on_done()
      end
    end,
  })
end

--- Rebase current branch onto target
---@param target string
---@param on_done fun()
function M.rebase(target, on_done)
  M.run({ 'rebase', target }, {
    on_success = function()
      vim.notify('[gitgraph] Rebased onto ' .. target, vim.log.levels.INFO)
      on_done()
    end,
  })
end

--- Push branch
---@param branch string
---@param on_done fun()
function M.push(branch, on_done)
  local git_cmd = (config and config.git_cmd) or 'git'
  M.run_interactive({ git_cmd, 'push', 'origin', branch }, 'Git Push (' .. branch .. ')', function(ok)
    if ok then
      vim.notify('[gitgraph] Pushed ' .. branch .. ' to origin', vim.log.levels.INFO)
    else
      vim.notify('[gitgraph] Push failed or cancelled for ' .. branch, vim.log.levels.WARN)
    end
    on_done()
  end)
end

--- Pull branch
---@param branch string
---@param on_done fun()
function M.pull(branch, on_done)
  local git_cmd = (config and config.git_cmd) or 'git'
  M.run_interactive({ git_cmd, 'pull', 'origin', branch }, 'Git Pull (' .. branch .. ')', function(ok)
    if ok then
      vim.notify('[gitgraph] Pulled ' .. branch .. ' from origin', vim.log.levels.INFO)
    else
      vim.notify('[gitgraph] Pull failed or cancelled for ' .. branch, vim.log.levels.WARN)
    end
    on_done()
  end)
end

--- Delete branch
---@param branch string
---@param on_done fun()
function M.delete_branch(branch, on_done)
  vim.ui.select({ 'No, Cancel', 'Yes, Delete (-d)', 'Force Delete (-D)' }, {
    prompt = 'Delete branch ' .. branch .. '?',
  }, function(choice)
    if not choice or choice == 'No, Cancel' then
      return
    end
    local flag = (choice == 'Force Delete (-D)') and '-D' or '-d'
    M.run({ 'branch', flag, branch }, {
      on_success = function()
        vim.notify('[gitgraph] Deleted branch: ' .. branch, vim.log.levels.INFO)
        on_done()
      end,
    })
  end)
end

--- Delete tag
---@param tag string
---@param on_done fun()
function M.delete_tag(tag, on_done)
  M.run({ 'tag', '-d', tag }, {
    on_success = function()
      vim.notify('[gitgraph] Deleted tag: ' .. tag, vim.log.levels.INFO)
      on_done()
    end,
  })
end

--- Open Diffview for commit, range, or uncommitted changes
---@param from? string
---@param to? string
function M.view_diff(from, to)
  if not from or from == '*' or from == '' then
    local ok = pcall(vim.cmd, 'DiffviewOpen')
    if not ok then
      vim.notify('[gitgraph] diffview.nvim not found or failed to open working directory diff', vim.log.levels.WARN)
    end
    return
  end

  if to then
    local cmd = 'DiffviewOpen ' .. from .. '~1..' .. to
    local ok = pcall(vim.cmd, cmd)
    if not ok then
      vim.notify('[gitgraph] diffview.nvim not found or failed to open range diff', vim.log.levels.WARN)
    end
  else
    local cmd = 'DiffviewOpen ' .. from .. '^!'
    local ok = pcall(vim.cmd, cmd)
    if not ok then
      vim.notify('[gitgraph] diffview.nvim not found or failed to open commit diff', vim.log.levels.WARN)
    end
  end
end

--- Yank text to clipboard
---@param text string
---@param label string
function M.copy_to_clipboard(text, label)
  vim.fn.setreg('+', text)
  vim.fn.setreg('"', text)
  vim.notify('[gitgraph] Copied ' .. label .. ' to clipboard', vim.log.levels.INFO)
end

return M

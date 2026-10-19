local actions = require('gitgraph.actions')
local utils = require('gitgraph.utils')

local M = {}

--- Parse context from commit and cursor column
---@param commit I.Commit
---@param col integer 0-indexed cursor column
---@param line_str string
---@return { type: 'branch'|'tag'|'commit', branch?: string, is_remote?: boolean, tag?: string, commit: I.Commit }
function M.resolve_context(commit, col, line_str)
  -- Check if cursor is over any tag
  if commit.tags and #commit.tags > 0 then
    for _, t in ipairs(commit.tags) do
      local clean_tag = t:gsub('tag:%s*', '')
      local s, e = line_str:find(clean_tag, 1, true)
      if s and e and (col + 1) >= (s - 4) and (col + 1) <= (e + 4) then
        return { type = 'tag', tag = clean_tag, commit = commit }
      end
    end
  end

  -- Check if cursor is over any branch name badge
  if commit.branch_names and #commit.branch_names > 0 then
    for _, b in ipairs(commit.branch_names) do
      local clean = b:gsub('HEAD %-> ', '')
      local s, e = line_str:find(clean, 1, true)
      if s and e and (col + 1) >= (s - 3) and (col + 1) <= (e + 3) then
        local is_remote = clean:match('^origin/') or clean:match('^upstream/') or clean:match('^remote/')
        return { type = 'branch', branch = clean, is_remote = not not is_remote, commit = commit }
      end
    end
  end

  -- Default to commit context
  return { type = 'commit', commit = commit }
end

--- Build menu options based on resolved context
---@param ctx table
---@param refresh_fn fun()
---@return { label: string, execute: fun() }[]
function M.get_menu_items(ctx, refresh_fn)
  local items = {}

  if ctx.type == 'branch' then
    local branch = ctx.branch
    local is_remote = ctx.is_remote

    table.insert(items, {
      label = '󰘬 Checkout branch: ' .. branch,
      execute = function()
        actions.checkout(branch, refresh_fn)
      end,
    })

    table.insert(items, {
      label = '󰜛 Merge ' .. branch .. ' into HEAD',
      execute = function()
        actions.merge(branch, refresh_fn)
      end,
    })

    table.insert(items, {
      label = '󰁨 Rebase HEAD onto ' .. branch,
      execute = function()
        actions.rebase(branch, refresh_fn)
      end,
    })

    if not is_remote then
      table.insert(items, {
        label = ' Push branch to origin',
        execute = function()
          actions.push(branch, refresh_fn)
        end,
      })

      table.insert(items, {
        label = ' Pull branch from origin',
        execute = function()
          actions.pull(branch, refresh_fn)
        end,
      })

      table.insert(items, {
        label = '󰆴 Delete branch',
        execute = function()
          actions.delete_branch(branch, refresh_fn)
        end,
      })
    end

    table.insert(items, {
      label = '󰅟 View changes (Diffview)',
      execute = function()
        actions.view_diff(branch)
      end,
    })

    table.insert(items, {
      label = '󰆏 Copy branch name',
      execute = function()
        actions.copy_to_clipboard(branch, 'branch name')
      end,
    })

    table.insert(items, {
      label = '󰆏 Copy commit hash (' .. ctx.commit.hash:sub(1, 7) .. ')',
      execute = function()
        actions.copy_to_clipboard(ctx.commit.hash, 'commit hash')
      end,
    })

    return items
  end

  if ctx.type == 'tag' then
    local tag = ctx.tag
    table.insert(items, {
      label = '󰘬 Checkout tag: ' .. tag,
      execute = function()
        actions.checkout(tag, refresh_fn)
      end,
    })

    table.insert(items, {
      label = '󰆴 Delete tag: ' .. tag,
      execute = function()
        actions.delete_tag(tag, refresh_fn)
      end,
    })

    table.insert(items, {
      label = '󰅟 View changes (Diffview)',
      execute = function()
        actions.view_diff(tag)
      end,
    })

    table.insert(items, {
      label = '󰆏 Copy tag name',
      execute = function()
        actions.copy_to_clipboard(tag, 'tag')
      end,
    })

    return items
  end

  -- Context is commit
  local c = ctx.commit
  local short_hash = c.hash:sub(1, 7)

  table.insert(items, {
    label = '󰅟 View changes (Diffview)',
    execute = function()
      actions.view_diff(c.hash)
    end,
  })

  table.insert(items, {
    label = '󰘬 Checkout commit (' .. short_hash .. ')',
    execute = function()
      actions.checkout(c.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰙅 Create branch at ' .. short_hash,
    execute = function()
      actions.create_branch(c.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰓻 Add tag at ' .. short_hash,
    execute = function()
      actions.add_tag(c.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰜛 Merge ' .. short_hash .. ' into HEAD',
    execute = function()
      actions.merge(c.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰁨 Rebase HEAD onto ' .. short_hash,
    execute = function()
      actions.rebase(c.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰑕 Cherry-pick ' .. short_hash,
    execute = function()
      actions.cherry_pick(c.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰁯 Revert commit ' .. short_hash,
    execute = function()
      actions.revert(c.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰦛 Reset current branch to ' .. short_hash,
    execute = function()
      actions.reset(c.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰆏 Copy commit hash (' .. short_hash .. ')',
    execute = function()
      actions.copy_to_clipboard(c.hash, 'commit hash')
    end,
  })

  table.insert(items, {
    label = '󰆏 Copy commit message',
    execute = function()
      actions.copy_to_clipboard(c.msg, 'commit message')
    end,
  })

  return items
end

--- Build range context menu options
---@param from I.Commit
---@param to I.Commit
---@param refresh_fn fun()
---@return { label: string, execute: fun() }[]
function M.get_range_menu_items(from, to, refresh_fn)
  local items = {}
  local from_short = from.hash:sub(1, 7)
  local to_short = to.hash:sub(1, 7)

  table.insert(items, {
    label = '󰅟 Compare commits (Diffview ' .. from_short .. '..' .. to_short .. ')',
    execute = function()
      actions.view_diff(from.hash, to.hash)
    end,
  })

  table.insert(items, {
    label = '󰑕 Cherry-pick range (' .. from_short .. '..' .. to_short .. ')',
    execute = function()
      actions.cherry_pick(from.hash .. '..' .. to.hash, refresh_fn)
    end,
  })

  table.insert(items, {
    label = '󰆏 Copy range (' .. from_short .. '..' .. to_short .. ')',
    execute = function()
      actions.copy_to_clipboard(from.hash .. '..' .. to.hash, 'commit range')
    end,
  })

  return items
end

--- Open context menu at current cursor / mouse position
---@param graph I.Row[]
---@param refresh_fn fun()
---@param pos? { row: integer, col: integer }
function M.open_context_menu(graph, refresh_fn, pos)
  pos = pos or (function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    return { row = cursor[1], col = cursor[2] }
  end)()

  local commit = utils.get_commit_from_row(graph, pos.row)
  if not commit then
    vim.notify('[gitgraph] No commit found at row ' .. pos.row, vim.log.levels.WARN)
    return
  end

  local line_str = vim.api.nvim_get_current_line()
  local ctx = M.resolve_context(commit, pos.col, line_str)
  local items = M.get_menu_items(ctx, refresh_fn)

  local prompt_title = 'Git Action [' .. ctx.type:upper() .. ']'
  if ctx.type == 'branch' then
    prompt_title = prompt_title .. ' ' .. ctx.branch
  elseif ctx.type == 'tag' then
    prompt_title = prompt_title .. ' ' .. ctx.tag
  else
    prompt_title = prompt_title .. ' ' .. ctx.commit.hash:sub(1, 7)
  end

  vim.ui.select(items, {
    prompt = prompt_title .. ':',
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice and choice.execute then
      choice.execute()
    end
  end)
end

--- Open visual range context menu
---@param from I.Commit
---@param to I.Commit
---@param refresh_fn fun()
function M.open_range_menu(from, to, refresh_fn)
  local items = M.get_range_menu_items(from, to, refresh_fn)
  vim.ui.select(items, {
    prompt = 'Git Range Action (' .. from.hash:sub(1, 7) .. '..' .. to.hash:sub(1, 7) .. '):',
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice and choice.execute then
      choice.execute()
    end
  end)
end

return M

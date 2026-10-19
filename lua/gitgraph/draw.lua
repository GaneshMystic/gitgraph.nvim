local log = require('gitgraph.log')
local utils = require('gitgraph.utils')
local core = require('gitgraph.core')

local M = {
  options = nil,
  args = nil,
  current_limit = nil,
  has_more = false,
  is_loading = false,
  load_more_line = nil,
}

--- Load more commits and populate the list further
function M.load_more()
  if M.is_loading or not M.has_more then
    return
  end
  M.is_loading = true

  local config = require('gitgraph').config
  local step = (M.options and M.options.page_size) or 50
  M.current_limit = (M.current_limit or 50) + step

  local new_args = vim.deepcopy(M.args or {})
  new_args.max_count = M.current_limit

  vim.notify('[gitgraph] Loading more commits...', vim.log.levels.INFO)

  -- Preserve cursor position so the view doesn't jump unexpectedly
  local cur_win = vim.api.nvim_get_current_win()
  local prev_cursor = pcall(vim.api.nvim_win_get_cursor, cur_win) and vim.api.nvim_win_get_cursor(cur_win) or nil

  M.draw(config, M.options or {}, new_args, { preserve_cursor = true, prev_cursor = prev_cursor })
  M.is_loading = false
end

--- Redraw graph with current options and args
function M.refresh()
  local config = require('gitgraph').config
  M.draw(config, M.options or {}, M.args or {})
end

--- Cleanly close GitGraph and restore the previous buffer/window
function M.close()
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_win_get_buf(current_win)

  -- If previous buffer is valid and was replaced in current window, restore it
  if M.prev_buf and vim.api.nvim_buf_is_valid(M.prev_buf) and current_buf == M.buf then
    pcall(vim.api.nvim_win_set_buf, current_win, M.prev_buf)
    return
  end

  -- If opened in a dedicated split window and multiple windows exist, close it
  if #vim.api.nvim_list_wins() > 1 then
    pcall(vim.api.nvim_win_close, current_win, true)
    return
  end

  -- Fallback: switch to alternate buffer or delete buffer
  local alt_buf = vim.fn.bufnr('#')
  if alt_buf > 0 and vim.api.nvim_buf_is_valid(alt_buf) and alt_buf ~= M.buf then
    pcall(vim.api.nvim_win_set_buf, current_win, alt_buf)
  else
    pcall(vim.cmd, 'bdelete')
  end
end

---@param config I.GGConfig
---@param options I.DrawOptions
---@param args I.GitLogArgs
---@param extra? { preserve_cursor?: boolean, prev_cursor?: integer[] }
function M.draw(config, options, args, extra)
  extra = extra or {}
  M.graph = {}
  M.options = options
  M.args = args

  -- Track current commit limit for lazy loading
  if not extra.preserve_cursor then
    M.current_limit = args.max_count or (options and options.page_size) or 50
  end

  local so = os.clock()

  if utils.check_cmd('git --version') then
    log.error('git command not found, please install it')
    return
  end

  if utils.check_cmd('git status') then
    log.error('does not seem to be a valid git repo')
    return
  end

  -- remember previous buffer and window to restore seamlessly on close
  local prev_win = vim.api.nvim_get_current_win()
  local prev_buf = vim.api.nvim_win_get_buf(prev_win)
  if prev_buf ~= M.buf then
    M.prev_win = prev_win
    M.prev_buf = prev_buf
  end

  -- reuse or create buffer
  do
    if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
      M.buf = vim.api.nvim_create_buf(false, true)
    end
  end

  -- set active buffer to this one
  local buf = M.buf
  assert(buf)
  vim.api.nvim_win_set_buf(0, buf)

  vim.api.nvim_set_option_value('modifiable', true, { buf = buf }) -- make modifiable
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf }) -- unlisted
  vim.api.nvim_set_option_value('wrap', false, { scope = 'local' }) -- turn off linewrap

  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1) -- clear highlights

  -- clear
  do
    local cl_start = os.clock()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    local clear_dur = os.clock() - cl_start
    log.info('clear dur', clear_dur * 1000, 'ms')
  end

  -- extract graph data
  local effective_args = vim.deepcopy(args or {})
  if M.current_limit then
    effective_args.max_count = M.current_limit
  end

  local graph, lines, highlights, head_loc, total_loaded = core.gitgraph(config, options, effective_args)
  M.graph = graph

  -- Check if more commits could be available
  M.has_more = (M.current_limit ~= nil) and (total_loaded >= M.current_limit)

  if M.has_more then
    local load_more_text = '  󰑖 -- Load more commits (hover or place cursor here to populate) --'
    lines[#lines + 1] = load_more_text
    M.load_more_line = #lines
    highlights[#highlights + 1] = {
      hg = 'GitGraphLoadMore',
      row = #lines,
      start = 2,
      stop = #load_more_text,
    }
  else
    M.load_more_line = nil
  end

  local start = os.clock()
  -- put graph data in buffer
  do
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines) -- text

    -- highlights

    local function high()
      for _, hl in ipairs(highlights) do
        local offset = 1
        vim.api.nvim_buf_add_highlight(buf, -1, hl.hg, hl.row - 1, hl.start - 1 + offset, hl.stop + offset)
      end
    end

    local co = coroutine.create(high)

    local function wait_poll()
      if coroutine.status(co) ~= 'dead' then
        coroutine.resume(co)
        vim.defer_fn(wait_poll, 16) -- Adjust delay as needed
      end
    end

    vim.defer_fn(wait_poll, 1)
  end

  do
    if extra.preserve_cursor and extra.prev_cursor then
      local target_line = math.min(extra.prev_cursor[1], #lines)
      pcall(vim.api.nvim_win_set_cursor, 0, { target_line, extra.prev_cursor[2] or 0 })
    else
      local cursor_line = head_loc or 1
      vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })
    end
  end

  utils.apply_buffer_options(buf)
  utils.apply_buffer_mappings(buf, M.graph, config, M.refresh)

  -- Setup auto-trigger for load more when cursor is placed on or reaches the load-more line
  local augroup_name = 'GitGraphLoadMore_' .. buf
  local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorHold' }, {
    group = augroup,
    buffer = buf,
    callback = function()
      if not M.has_more or M.is_loading or not M.load_more_line then
        return
      end
      local cursor = vim.api.nvim_win_get_cursor(0)
      if cursor[1] >= M.load_more_line then
        M.load_more()
      end
    end,
  })

  local dur = os.clock() - start
  log.info('rest dur:', dur * 1000, 'ms')

  local tot_dur = os.clock() - so
  log.info('total dur:', tot_dur * 1000, 'ms')
end

return M

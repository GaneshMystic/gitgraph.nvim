local log = require('gitgraph.log')
local highlights = require('gitgraph.highlights')

local M = {}

---@param branch_names string[]
---@param branch_color_idx integer
---@return string, table[]
function M.format_branch_badges(branch_names, branch_color_idx)
  if #branch_names == 0 then
    return '', {}
  end

  local locals = {}
  local remotes = {}
  local others = {}

  for _, b in ipairs(branch_names) do
    local clean = b:gsub('HEAD %-> ', '')
    local remote_prefix, branch_part = clean:match('^(%a+)/(%a.+)$')
    if remote_prefix and (remote_prefix == 'origin' or remote_prefix == 'upstream' or remote_prefix == 'remote') then
      remotes[#remotes + 1] = { remote = remote_prefix, branch = branch_part, full = clean }
    else
      if clean == 'HEAD' or clean:match('^HEAD/') then
        others[#others + 1] = clean
      else
        locals[#locals + 1] = clean
      end
    end
  end

  local segments = {}
  local matched_remotes = {}

  for _, l_branch in ipairs(locals) do
    local paired_remote = nil
    for idx, r in ipairs(remotes) do
      if not matched_remotes[idx] and r.branch == l_branch then
        paired_remote = r
        matched_remotes[idx] = true
        break
      end
    end

    segments[#segments + 1] = { text = ' ', hg = 'GitGraphBranch' .. branch_color_idx .. 'Cap' }
    segments[#segments + 1] = { text = ' ' .. l_branch .. ' ', hg = 'GitGraphBranch' .. branch_color_idx .. 'Badge' }

    if paired_remote then
      segments[#segments + 1] = { text = '', hg = 'GitGraphBranch' .. branch_color_idx .. 'RemoteSep' }
      segments[#segments + 1] = { text = ' ' .. paired_remote.remote, hg = 'GitGraphRemoteBadge' }
      segments[#segments + 1] = { text = ' ', hg = 'GitGraphRemoteCap' }
    else
      segments[#segments + 1] = { text = ' ', hg = 'GitGraphBranch' .. branch_color_idx .. 'Cap' }
    end
  end

  for idx, r in ipairs(remotes) do
    if not matched_remotes[idx] then
      segments[#segments + 1] = { text = ' ', hg = 'GitGraphBranch' .. branch_color_idx .. 'Cap' }
      segments[#segments + 1] = { text = '󰅟  ' .. r.full, hg = 'GitGraphBranch' .. branch_color_idx .. 'Badge' }
      segments[#segments + 1] = { text = ' ', hg = 'GitGraphBranch' .. branch_color_idx .. 'Cap' }
    end
  end

  for _, o in ipairs(others) do
    segments[#segments + 1] = { text = ' ', hg = 'GitGraphRemoteCap' }
    segments[#segments + 1] = { text = ' ' .. o .. ' ', hg = 'GitGraphRemoteBadge' }
    segments[#segments + 1] = { text = ' ', hg = 'GitGraphRemoteCap' }
  end

  local full_str = ''
  local hls = {}
  local cur_pos = 0

  for _, seg in ipairs(segments) do
    local start = cur_pos
    local stop = start + #seg.text
    full_str = full_str .. seg.text
    cur_pos = stop
    hls[#hls + 1] = { hg = seg.hg, start = start, stop = stop }
  end

  return full_str, hls
end

---@param tags string[]
---@return string, table[]
function M.format_tag_badges(tags)
  if #tags == 0 then
    return '', {}
  end

  local segments = {}
  for _, t in ipairs(tags) do
    local clean_tag = t:gsub('tag:%s*', '')
    segments[#segments + 1] = { text = ' ', hg = 'GitGraphTagCap' }
    segments[#segments + 1] = { text = ' 󰓻 ' .. clean_tag, hg = 'GitGraphTagBadge' }
    segments[#segments + 1] = { text = ' ', hg = 'GitGraphTagCap' }
  end

  local full_str = ''
  local hls = {}
  local cur_pos = 0

  for _, seg in ipairs(segments) do
    local start = cur_pos
    local stop = start + #seg.text
    full_str = full_str .. seg.text
    cur_pos = stop
    hls[#hls + 1] = { hg = seg.hg, start = start, stop = stop }
  end

  return full_str, hls
end

---@param options I.DrawOptions
---@param graph I.Row[]
---@param sym I.GGSymbols
---@param fields I.GGVarName[]
---@param commits table<string, I.Commit>
---@return string[]
---@return I.Highlight[]
---@return integer?
function M.graph_to_lines(options, graph, sym, fields, commits)
  local ITEM_HGS = highlights.ITEM_HGS
  local BRANCH_HGS = highlights.BRANCH_HGS

  local NUM_BRANCH_COLORS = #BRANCH_HGS

  local start = os.clock()

  ---@type integer?
  local head_loc = 1

  ---@type string[]
  local lines = {}

  ---@type I.Highlight[]
  local highlights_arr = {}

  ---@param cell I.Cell
  ---@return string
  local function commit_cell_symb(cell)
    assert(cell.is_commit)

    if options.mode == 'debug' then
      return cell.commit.msg
    end

    if #cell.commit.parents > 1 then
      -- merge commit
      return #cell.commit.children == 0 and sym.merge_commit_end or sym.merge_commit
    else
      -- regular commit
      return #cell.commit.children == 0 and sym.commit_end or sym.commit
    end
  end

  ---@param row I.Row
  ---@return string
  local function row_to_str(row)
    local row_strs = {}
    for j = 1, #row.cells do
      local cell = row.cells[j]
      if cell.connector then
        cell.symbol = cell.connector
      else
        assert(cell.commit)
        cell.symbol = commit_cell_symb(cell)
      end
      row_strs[#row_strs + 1] = cell.symbol
    end
    return table.concat(row_strs)
  end

  ---@param row I.Row
  ---@param row_idx integer
  ---@param continuation_symbols string[]
  ---@return I.Highlight[]
  local function row_to_highlights(row, row_idx, continuation_symbols)
    local row_hls = {}
    local offset = 0

    for j = 1, #row.cells do
      local cell = row.cells[j]

      local width = cell.symbol and #cell.symbol or 1
      local start = offset
      local stop = start + width
      offset = offset + width

      if cell.commit then
        local hg = 'GitGraphBranch' .. tostring(j % NUM_BRANCH_COLORS + 1)
        row_hls[#row_hls + 1] = { hg = hg, row = row_idx, start = start, stop = stop }
      elseif cell.symbol == sym.GHOR then
        for k = j + 1, #row.cells do
          local rcell = row.cells[k]
          if rcell.commit and vim.tbl_contains(continuation_symbols, rcell.symbol) then
            local hg = 'GitGraphBranch' .. tostring(k % NUM_BRANCH_COLORS + 1)
            row_hls[#row_hls + 1] = { hg = hg, row = row_idx, start = start, stop = stop }
            break
          end
        end
      end
    end
    return row_hls
  end

  ---@param row I.Row
  ---@return string
  local function row_to_test(row)
    local row_strs = {}

    for i = 1, #row.cells do
      local cell = row.cells[i]
      if cell.connector then
        row_strs[#row_strs + 1] = cell.connector
      else
        assert(cell.commit)
        local symbol = cell.commit.msg
        symbol = cell.emphasis and symbol:lower() or symbol
        row_strs[#row_strs + 1] = symbol
      end
    end

    return table.concat(row_strs)
  end

  ---@param row I.Row
  ---@return string
  local function row_to_debg(row)
    local row_strs = {}
    for i = 1, #row.cells do
      local cell = row.cells[i]
      local symbol = ' '
      if cell.commit then
        symbol = cell.commit.msg
        symbol = cell.emphasis and symbol:lower() or symbol
      end
      row_strs[#row_strs + 1] = symbol
    end
    return table.concat(row_strs)
  end

  local width = 0
  for _, row in ipairs(graph) do
    if #row.cells > width then
      width = #row.cells
    end
  end

  local continuation_symbols = {
    sym.GCLD,
    sym.GCLU,
    sym.GFORKD,
    sym.GFORKU,
    sym.GLUDCD,
    sym.GLUDCU,
    sym.GLRDCL,
    sym.GLRUCL,
  }

  local head_found = false

  for idx = 1, #graph do
    local proper_row = graph[idx]

    local row_str_arr = {}
    local offset = 0

    ---@param stuff string
    local function add_to_row(stuff)
      row_str_arr[#row_str_arr + 1] = stuff
      offset = offset + #stuff + 1
    end

    local padding = width + 2

    if options.mode == 'debug' then
      add_to_row(row_to_debg(proper_row))
      add_to_row((' '):rep(padding - #proper_row.cells))
      add_to_row(row_to_str(proper_row))
    elseif options.mode == 'test' then
      add_to_row(row_to_test(proper_row))
    else
      add_to_row(row_to_str(proper_row))
    end

    if options.mode ~= 'test' then
      local c = proper_row.commit
      if c then
        local hash_val = c.hash:sub(1, 7)
        local timestamp = c.author_date
        local author = c.author_name

        local is_head = false
        if not head_found then
          for _, b in ipairs(c.branch_names) do
            if b:match('HEAD %->') then
              is_head = true
              head_found = true
              head_loc = idx
              break
            end
          end
        end

        local items = {
          ['hash'] = hash_val,
          ['timestamp'] = timestamp,
          ['author'] = author,
          ['branch_name'] = '',
          ['tag'] = '',
          ['message'] = c.msg,
        }

        local pad_size = padding - #proper_row.cells

        if is_head then
          pad_size = pad_size - 2
        end
        local pad_str = (' '):rep(pad_size)
        add_to_row(pad_str)
        if is_head then
          add_to_row('*')
        end

        for _, name in ipairs(fields) do
          if name == 'branch_name' and #c.branch_names > 0 then
            local badge_str, badge_hls = M.format_branch_badges(c.branch_names, c.j % NUM_BRANCH_COLORS + 1)
            for _, bh in ipairs(badge_hls) do
              highlights_arr[#highlights_arr + 1] = {
                hg = bh.hg,
                row = idx,
                start = offset + bh.start,
                stop = offset + bh.stop,
              }
            end
            add_to_row(badge_str)
          elseif name == 'tag' and #c.tags > 0 then
            local badge_str, badge_hls = M.format_tag_badges(c.tags)
            for _, bh in ipairs(badge_hls) do
              highlights_arr[#highlights_arr + 1] = {
                hg = bh.hg,
                row = idx,
                start = offset + bh.start,
                stop = offset + bh.stop,
              }
            end
            add_to_row(badge_str)
          elseif name == 'message' then
            highlights_arr[#highlights_arr + 1] = {
              start = offset,
              stop = offset + #c.msg,
              row = idx,
              hg = ITEM_HGS['message'].name,
            }
            add_to_row(c.msg)
          end
        end

        if options.mode == 'debug' then
          local parents = ''
          for _, h in ipairs(graph[idx].commit.parents) do
            local p = commits[h]
            parents = parents .. (p and p.msg or '?')
          end

          local children = ''
          for _, h in ipairs(graph[idx].commit.children) do
            local p = commits[h]
            children = children .. (p and p.msg or '?')
          end
          if #children == 0 then
            children = '_'
          end
          local dbg_suffix = ':  ' .. children .. ' ' .. c.msg .. ' ' .. parents
          row_str_arr[#row_str_arr + 1] = dbg_suffix
          offset = offset + #dbg_suffix
        end
      else
        local c = graph[idx - 1].commit
        assert(c)
        if options.mode ~= 'debug' then
          add_to_row((' '):rep(padding - #proper_row.cells))
          add_to_row((' '):rep(7))

          local items = {
            ['hash'] = c.hash:sub(1, 7),
            ['timestamp'] = c.author_date,
            ['author'] = c.author_name,
            ['branch_name'] = '',
            ['tag'] = '',
            ['message'] = c.msg,
          }

          for _, name in ipairs(fields) do
            if name == 'hash' or name == 'timestamp' or name == 'author' then
              local value = items[name]
              if value then
                highlights_arr[#highlights_arr + 1] = {
                  hg = ITEM_HGS[name].name,
                  row = idx,
                  start = offset,
                  stop = offset + #value,
                }
                add_to_row(value .. ' ')
              end
            -- elseif name == 'message' then
            --   highlights_arr[#highlights_arr + 1] = {
            --     start = offset,
            --     stop = offset + #c.msg,
            --     row = idx,
            --     hg = ITEM_HGS['message'].name,
            --   }
            --   add_to_row(c.msg)
            end
          end
        end
      end

      for _, hl in ipairs(row_to_highlights(proper_row, idx, continuation_symbols)) do
        highlights_arr[#highlights_arr + 1] = hl
      end
    end

    if options.mode == 'debug' then
      lines[#lines + 1] = table.concat(row_str_arr, ' '):gsub('%s*$', '')
    else
      lines[#lines + 1] = table.concat(row_str_arr, ' ')
    end
  end

  local dur = os.clock() - start
  log.info('graph_to_lines dur:', dur * 1000, 'ms')

  return lines, highlights_arr, head_loc
end

return M

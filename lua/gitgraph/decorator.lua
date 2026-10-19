local log = require('gitgraph.log')

local M = {}

---@param sym I.GGSymbols
---@param opt I.DrawOptions
---@return I.GGSymbols
function M.get_symbols(sym, opt)
  ---@type I.GGSymbols
  return vim.tbl_extend('force', sym, {
    GFORKU = opt.pretty and '⓵' or sym.GFORKU, -- '┼',
    GFORKD = opt.pretty and '⓴' or sym.GFORKD, -- '┼',
    GRUDCD = opt.pretty and '⓶' or sym.GRUDCD, -- '├',
    GRUDCU = opt.pretty and '⓸' or sym.GRUDCU, -- '├',
    GLUDCD = opt.pretty and '⓷' or sym.GLUDCD, -- '┤',
    GLUDCU = opt.pretty and '⓹' or sym.GLUDCU, -- '┤',
    GLRDCL = opt.pretty and 'ⓢ' or sym.GLRDCL, -- '┬',
    GLRDCR = opt.pretty and 'ⓣ' or sym.GLRDCR, -- '┬',
    GLRUCL = opt.pretty and 'ⓥ' or sym.GLRUCL, -- '┴',
    GLRUCR = opt.pretty and 'ⓤ' or sym.GLRUCR, -- '┴',

    commit = opt.pretty and 'ⓚ' or sym.commit,
    merge_commit = opt.pretty and '⓮' or sym.merge_commit,
    commit_end = opt.pretty and 'ⓛ' or sym.commit_end,
    merge_commit_end = opt.pretty and '⓯' or sym.merge_commit_end,
  })
end

---@param c I.Cell?
---@return string?
local function hash(c)
  return c and c.commit and c.commit.hash
end

--- inserts vertical and horizontal pipes
---@param graph I.Row[]
---@param sym I.GGSymbols
function M.insert_vert_and_hor_pipes(graph, sym)
  local start = os.clock()

  for i = 2, #graph - 1 do
    local row = graph[i]

    ---@param cells I.Cell[]
    local function count_emph(cells)
      local n = 0
      for _, c in ipairs(cells) do
        if c.commit and c.emphasis then
          n = n + 1
        end
      end
      return n
    end

    local num_emphasized = count_emph(graph[i].cells)

    -- vertical connections
    for j = 1, #row.cells, 2 do
      local this = graph[i].cells[j]
      local below = graph[i + 1].cells[j]

      local tch, bch = hash(this), hash(below)

      if not this.is_commit and not this.connector then
        local ignore_this = (num_emphasized > 1 and (this.emphasis or false))

        if not ignore_this and bch == tch then
          local has_repeats = false
          local first_repeat = nil
          for k = 1, #row.cells, 2 do
            local cell_k, cell_j = row.cells[k], row.cells[j]
            local rkc, rjc = (not cell_k.connector and cell_k.commit), (not cell_j.connector and cell_j.commit)

            if k ~= j and (rkc and rjc) and rkc.hash == rjc.hash then
              has_repeats = true
              first_repeat = k
              break
            end
          end

          if not has_repeats then
            local cell = graph[i].cells[j]
            cell.connector = sym.GVER
          else
            local k = first_repeat
            local this_k = graph[i].cells[k]
            local below_k = graph[i + 1].cells[k]

            local bkc, tkc = (not below_k.connector and below_k.commit), (not this_k.connector and this_k.commit)
            if (bkc and tkc) and bkc.hash == tkc.hash then
              local cell = graph[i].cells[j]
              cell.connector = sym.GVER
            end
          end
        end
      end
    end

    do
      assert(#graph % 2 == 1)
      local last_row = graph[#graph]
      for j = 1, #last_row.cells, 2 do
        local cell = last_row.cells[j]
        if cell.commit and not cell.is_commit then
          cell.connector = sym.GVER
        end
      end
    end

    -- horizontal connections
    local stopped = {}
    for j = 1, #row.cells, 2 do
      local this = graph[i].cells[j]
      local below = graph[i + 1].cells[j]
      if not this.connector and (not below or below.connector == ' ') then
        assert(this.commit)
        stopped[#stopped + 1] = j
      end
    end

    local intervals = {}
    for _, j in ipairs(stopped) do
      local curr = 1
      for k = curr, j do
        local cell_k, cell_j = row.cells[k], row.cells[j]
        local rkc, rjc = (not cell_k.connector and cell_k.commit), (not cell_j.connector and cell_j.commit)
        if (rkc and rjc) and (rkc.hash == rjc.hash) then
          if k < j then
            intervals[#intervals + 1] = { start = k, stop = j }
          end
          curr = j
          break
        end
      end
    end

    do
      local low = #row.cells
      local high = 1
      for j = 1, #row.cells, 2 do
        local c = row.cells[j]
        if c.emphasis then
          if j > high then
            high = j
          end
          if j < low then
            low = j
          end
        end
      end

      if high > low then
        intervals[#intervals + 1] = { start = low, stop = high }
      end
    end

    if i % 2 == 0 then
      for _, interval in ipairs(intervals) do
        local a, b = interval.start, interval.stop
        for j = a + 1, b - 1 do
          local this = graph[i].cells[j]
          if this.connector == ' ' then
            this.connector = sym.GHOR
          end
        end
      end
    end
  end

  local dur = os.clock() - start
  log.info('insert_vert_and_hor_pipes dur:', dur * 1000, 'ms')
end

---@param graph I.Row[]
---@param sym I.GGSymbols
function M.insert_symbols_on_connector_rows(graph, sym)
  local start = os.clock()

  local symb_map = {
    [10] = sym.GCLU,
    [9] = sym.GCLD,
    [6] = sym.GCRU,
    [5] = sym.GCRD,
    [14] = sym.GLRU,
    [13] = sym.GLRD,
    [11] = sym.GLUD,
    [7] = sym.GRUD,
  }

  for i = 2, #graph, 2 do
    local row = graph[i]
    local above = graph[i - 1]
    local below = graph[i + 1]

    for j = 1, #row.cells, 2 do
      local this = row.cells[j]

      if this.connector == sym.GVER then
        goto continue
      end

      local lc = row.cells[j - 1]
      local rc = row.cells[j + 1]
      local uc = above and above.cells[j]
      local dc = below and below.cells[j]

      local l = lc and (lc.connector ~= ' ' or lc.commit) or false
      local r = rc and (rc.connector ~= ' ' or rc.commit) or false
      local u = uc and (uc.connector ~= ' ' or uc.commit) or false
      local d = dc and (dc.connector ~= ' ' or dc.commit) or false

      local nn = 0
      local symb_n = 0
      for idx, b in ipairs({ l, r, u, d }) do
        if b then
          nn = nn + 1
          symb_n = symb_n + bit.lshift(1, 4 - idx)
        end
      end

      local symbol = symb_map[symb_n] or '?'

      if i == #graph and symbol == '?' then
        symbol = sym.GVER
      end

      local commit_dir_above = above.commit and above.commit.j == j

      ---@type 'l' | 'r' | nil
      local clh_above = nil
      local commit_above = above.commit and above.commit.j ~= j
      if commit_above then
        clh_above = above.commit.j < j and 'l' or 'r'
      end

      if clh_above and symbol == sym.GLRD then
        if clh_above == 'l' then
          symbol = sym.GLRDCL
        elseif clh_above == 'r' then
          symbol = sym.GLRDCR
        end
      elseif symbol == sym.GLRU then
        symbol = sym.GLRUCL
      end

      local merge_dir_above = commit_dir_above and #above.commit.parents > 1

      if symbol == sym.GLUD then
        symbol = merge_dir_above and sym.GLUDCU or sym.GLUDCD
      end

      if symbol == sym.GRUD then
        symbol = merge_dir_above and sym.GRUDCU or sym.GRUDCD
      end

      if nn == 4 then
        symbol = merge_dir_above and sym.GFORKD or sym.GFORKU
      end

      if row.cells[j].commit then
        row.cells[j].connector = symbol
      end

      ::continue::
    end
  end

  local dur = os.clock() - start
  log.info('insert_symbols_on_connector_rows dur:', dur * 1000, 'ms')
end

return M

local log = require('gitgraph.log')
local utils = require('gitgraph.utils')

local M = {}

---@param cells I.Cell[]
---@return I.Cell[]
local function propagate(cells)
  local new_cells = {}
  for _, cell in ipairs(cells) do
    if cell.connector then
      new_cells[#new_cells + 1] = { connector = ' ' }
    elseif cell.commit then
      assert(cell.commit)
      new_cells[#new_cells + 1] = { commit = cell.commit }
    else
      new_cells[#new_cells + 1] = { connector = ' ' }
    end
  end
  return new_cells
end

---@param cells I.Cell[]
---@param hash string
---@param start integer?
---@return integer?
local function find(cells, hash, start)
  local start = start or 1
  for idx = start, #cells, 2 do
    local c = cells[idx]
    if c.commit and c.commit.hash == hash then
      return idx
    end
  end
  return nil
end

---@param cells I.Cell[]
---@param start integer?
---@return integer
local function next_vacant_j(cells, start)
  local start = start or 1
  for i = start, #cells, 2 do
    local cell = cells[i]
    if cell.connector == ' ' then
      return i
    end
  end
  return #cells + 1
end

--- returns the generated row and the integer (j) location of the commit
---@param c I.Commit
---@param prev_row I.Row?
---@return I.Row, integer
local function generate_commit_row(c, prev_row)
  local j = nil ---@type integer?

  local rowc = {} ---@type I.Cell[]

  if prev_row then
    rowc = propagate(prev_row.cells)
    j = find(prev_row.cells, c.hash)
  end

  -- if reserved location use it
  if j then
    c.j = j
    rowc[j] = { commit = c, is_commit = true }

    -- clear any supurfluous reservations
    for k = j + 1, #rowc do
      local v = rowc[k]
      if v.commit and v.commit.hash == c.hash then
        rowc[k] = { connector = ' ' }
      end
    end
  else
    j = next_vacant_j(rowc)
    c.j = j
    rowc[j] = { commit = c, is_commit = true }
    rowc[j + 1] = { connector = ' ' }
  end

  return { cells = rowc, commit = c }, j
end

---@param commits table<string, I.Commit>
---@param prev_commit_row I.Row
---@param prev_connector_row I.Row
---@param commit_row I.Row
---@param commit_loc integer
---@param curr_commit I.Commit
---@param next_commit I.Commit?
---@return I.Row, boolean
local function generate_connector_row(commits, prev_commit_row, prev_connector_row, commit_row, commit_loc, curr_commit, next_commit)
  local found_bi_crossing = false

  -- connector row (reservation row)
  --
  -- first we propagate
  local connector_cells = propagate(commit_row.cells)

  -- connector row
  --
  -- now we proceed to add the parents of the commit we just added
  if #curr_commit.parents > 0 then
    ---@param rem_parents string[]
    local function reserve_remainder(rem_parents)
      --
      -- reserve the rest of the parents in slots to the right of us
      --
      for _, h in ipairs(rem_parents) do
        local j = find(commit_row.cells, h, commit_loc)
        if not j then
          local j = next_vacant_j(connector_cells, commit_loc)
          connector_cells[j] = { commit = commits[h], emphasis = true }
          connector_cells[j + 1] = { connector = ' ' }
        else
          connector_cells[j].emphasis = true
        end
      end
    end

    -- we start by peeking at next commit and seeing if it is one of our parents
    -- we only do this if one of our propagating branches is already destined for this commit
    ---@type I.Cell?
    local tracker = nil
    if next_commit then
      for _, cell in ipairs(connector_cells) do
        if cell.commit and cell.commit.hash == next_commit.hash then
          tracker = cell
          break
        end
      end
    end

    local next_p_idx = nil -- default to picking first parent
    if tracker and next_commit then
      -- this loop updates next_p_idx to the next commit if they are identical
      for k, h in ipairs(curr_commit.parents) do
        if h == next_commit.hash then
          next_p_idx = k
          break
        end
      end
    end

    -- add parents
    if next_p_idx then
      assert(tracker)
      -- if next commit is our parent then we do some complex logic
      if #curr_commit.parents == 1 then
        -- simply place parent at our location
        connector_cells[commit_loc].commit = commits[curr_commit.parents[1]]
        connector_cells[commit_loc].emphasis = true
      else
        -- void the cell at our location (will be replaced by our parents in a moment)
        connector_cells[commit_loc] = { connector = ' ' }

        -- put emphasis on tracker for the special parent
        tracker.emphasis = true

        -- only reserve parents that are different from next commit
        ---@type string[]
        local rem_parents = {}
        for k, h in ipairs(curr_commit.parents) do
          if k ~= next_p_idx then
            rem_parents[#rem_parents + 1] = h
          end
        end

        assert(#rem_parents == #curr_commit.parents - 1, 'unexpected amount of rem parents')
        reserve_remainder(rem_parents)

        -- we fill this with the next commit if it is empty, a bit hacky
        if connector_cells[commit_loc].connector == ' ' then
          connector_cells[commit_loc].commit = tracker.commit
          connector_cells[commit_loc].emphasis = true
          connector_cells[commit_loc].connector = nil
          tracker.emphasis = false
        end
      end
    else
      -- simply add first parent at our location and then reserve the rest
      connector_cells[commit_loc].commit = commits[curr_commit.parents[1]]
      connector_cells[commit_loc].emphasis = true

      local rem_parents = {}
      for k = 2, #curr_commit.parents do
        rem_parents[#rem_parents + 1] = curr_commit.parents[k]
      end

      reserve_remainder(rem_parents)
    end

    local connector_row = { cells = connector_cells } ---@type I.Row

    -- handle bi-connector rows
    local is_bi_crossing, bi_crossing_safely_resolveable = utils.get_is_bi_crossing(commit_row, connector_row, next_commit)

    -- used for troubleshooting and tracking complexity of tests
    if is_bi_crossing then
      found_bi_crossing = true
    end

    if is_bi_crossing and bi_crossing_safely_resolveable and next_commit then
      utils.resolve_bi_crossing(prev_commit_row, prev_connector_row, commit_row, connector_row, next_commit)
    end

    return connector_row, found_bi_crossing
  else
    -- if we're here then it means that this commit has no common ancestors with other commits
    for i = 1, #connector_cells, 2 do
      local cell = connector_cells[i]
      if cell.commit and cell.commit.hash == curr_commit.hash then
        connector_cells[i] = { connector = ' ' }
      end
    end

    local connector_row = { cells = connector_cells }

    return connector_row, found_bi_crossing
  end
end

---@param commits table<string, I.Commit>
---@param sorted_commits string[]
---@return I.Row[], boolean
function M.straight_j(commits, sorted_commits)
  local found_bi_crossing = false

  local start = os.clock()

  local graph = {} ---@type I.Row[]

  for i, c_hash in ipairs(sorted_commits) do
    -- get the input parameters
    local curr_commit = commits[c_hash]
    local next_commit = commits[sorted_commits[i + 1]]
    local prev_commit_row = graph[#graph - 1]
    local prev_connector_row = graph[#graph]

    -- generate commit and connector row for the current commit
    local commit_row, commit_loc = generate_commit_row(curr_commit, prev_connector_row)
    local connector_row = nil ---@type I.Row
    local bi_crossing = false
    if i < #sorted_commits then
      connector_row, bi_crossing = generate_connector_row(commits, prev_commit_row, prev_connector_row, commit_row, commit_loc, curr_commit, next_commit)
      if bi_crossing then
        found_bi_crossing = true
      end
    end

    -- write the result
    graph[#graph + 1] = commit_row
    if connector_row then
      graph[#graph + 1] = connector_row
    end
  end

  local dur = os.clock() - start
  log.info('straight_j dur:', dur * 1000, 'ms')

  return graph, found_bi_crossing
end

return M

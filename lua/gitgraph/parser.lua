local log = require('gitgraph.log')

local M = {}

---@param raw_commits I.RawCommit[]
---@return table<string, I.Commit>, string[]
function M.process_raw_commits(raw_commits)
  local start = os.clock()

  local commits = {} --- @type table<string, I.Commit>
  local sorted_commits = {} --- @type string[]

  for _, rc in ipairs(raw_commits) do
    local commit = {
      msg = rc.msg,
      branch_names = rc.branch_names,
      tags = rc.tags,
      author_date = rc.author_date,
      author_name = rc.author_name,
      hash = rc.hash,
      i = -1,
      j = -1,
      parents = rc.parents,
      children = {},
      is_uncommitted = rc.is_uncommitted,
    }

    sorted_commits[#sorted_commits + 1] = commit.hash
    commits[rc.hash] = commit
  end

  local dur = os.clock() - start
  log.info('process_raw_commits dur:', dur * 1000, 'ms')

  return commits, sorted_commits
end

---@param commits table<string, I.Commit>
---@param sorted_commits string[]
function M.populate_child_parent_data(commits, sorted_commits)
  local start = os.clock()
  for _, c_hash in ipairs(sorted_commits) do
    local c = commits[c_hash]

    for _, h in ipairs(c.parents) do
      local p = commits[h]
      if p then
        p.children[#p.children + 1] = c.hash
      else
        -- create a virtual parent, it is not added to the list of commit hashes
        commits[h] = {
          hash = h,
          author_name = 'virtual',
          msg = 'virtual parent',
          author_date = 'unknown',
          parents = {},
          children = { c.hash },
          branch_names = {},
          tags = {},
          i = -1,
          j = -1,
        }
      end
    end
  end

  local dur = os.clock() - start
  log.info('populate_child_parent_data dur:', dur * 1000, 'ms')
end

return M

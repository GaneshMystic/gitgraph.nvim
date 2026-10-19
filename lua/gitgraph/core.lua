local log = require('gitgraph.log')
local parser = require('gitgraph.parser')
local layout = require('gitgraph.layout')
local decorator = require('gitgraph.decorator')
local renderer = require('gitgraph.renderer')

---@class I.DrawOptions
---@field mode? 'debug' | 'test'
---@field pretty? boolean

---@class I.Highlight
---@field hg string -- NOTE: fine to use string since lua internalizes strings
---@field row integer
---@field start integer
---@field stop integer

local M = {}

---@class I.GitLogArgs
---@field all? boolean
---@field revision_range? string
---@field max_count? integer
---@field skip? integer

---@param config I.GGConfig
---@param options I.DrawOptions
---@param args I.GitLogArgs
---@return I.Row[]
---@return string[]
---@return I.Highlight[]
---@return integer?
function M.gitgraph(config, options, args)
  --- depends on `git`
  local data = require('gitgraph.git').git_log_pretty(args, config.format.timestamp)

  --- does the magic
  local start = os.clock()
  local graph, lines, highlights, head_loc = M._gitgraph(data, options, config.symbols, config.format.fields)
  local dur = os.clock() - start
  log.info('_gitgraph dur:', dur * 1000, 'ms')

  return graph, lines, highlights, head_loc
end

---@param raw_commits I.RawCommit[]
---@param opt I.DrawOptions
---@param sym I.GGSymbols
---@param fields I.GGVarName[]
---@return I.Row[]
---@return string[]
---@return I.Highlight[]
---@return integer? -- head location
---@return boolean -- true if contained bi-crossing
function M._gitgraph(raw_commits, opt, sym, fields)
  sym = decorator.get_symbols(sym, opt)

  local commits, sorted_commits = parser.process_raw_commits(raw_commits)

  parser.populate_child_parent_data(commits, sorted_commits)

  local graph, found_bi_crossing = layout.straight_j(commits, sorted_commits)

  decorator.insert_vert_and_hor_pipes(graph, sym)

  decorator.insert_symbols_on_connector_rows(graph, sym)

  local lines, highlights, head_loc = renderer.graph_to_lines(opt, graph, sym, fields, commits)

  return graph, lines, highlights, head_loc, found_bi_crossing
end

return M

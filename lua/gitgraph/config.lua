local log = require('gitgraph.log')

---@class I.GGSymbols
---@field merge_commit string
---@field commit string
---@field merge_commit_end string
---@field commit_end string
---@field GVER string
---@field GHOR string
---@field GCLD string
---@field GCRD string
---@field GCLU string
---@field GCRU string
---@field GLRU string
---@field GLRD string
---@field GLUD string
---@field GRUD string
---@field GFORKU string
---@field GFORKD string
---@field GRUDCD string
---@field GRUDCU string
---@field GLUDCD string
---@field GLUDCU string
---@field GLRDCL string
---@field GLRDCR string
---@field GLRUCL string
---@field GLRUCR string

---@alias I.GGVarName "hash" | "timestamp" | "author" | "branch_name" | "tag" | "message" 

---@class I.GGFormat
---@field timestamp string
---@field fields I.GGVarName[]

---@class I.Hooks
---@field on_select_commit fun(commit: I.Commit)
---@field on_select_range_commit fun(from: I.Commit, to: I.Commit)

---@class I.GGKeymaps
---@field context_menu? string | string[]
---@field checkout? string | string[]
---@field close? string | string[]
---@field create_branch? string | string[]
---@field push? string | string[]
---@field pull? string | string[]
---@field add_tag? string | string[]
---@field cherry_pick? string | string[]
---@field revert? string | string[]
---@field reset? string | string[]
---@field merge? string | string[]
---@field rebase? string | string[]
---@field refresh? string | string[]
---@field copy_hash? string | string[]
---@field copy_message? string | string[]

---@class I.GGConfig
---@field symbols I.GGSymbols
---@field format I.GGFormat
---@field hooks I.Hooks
---@field keymaps I.GGKeymaps
---@field log_level integer

local M = {}

---@type I.GGConfig
M.defaults = {
  git_cmd = "git",
  symbols = {
    merge_commit = "",
    commit = "",
    merge_commit_end = "",
    commit_end = "",

    -- Advanced symbols
    GVER = '│',
    GHOR = '─',
    GCLD = '╮',
    GCRD = '╭',
    GCLU = '╯',
    GCRU = '╰',
    GLRU = '┴',
    GLRD = '┬',
    GLUD = '┤',
    GRUD = '├',
    GFORKU = '┼',
    GFORKD = '┼',
    GRUDCD = '├',
    GRUDCU = '├',
    GLUDCD = '┤',
    GLUDCU = '┤',
    GLRDCL = '┬',
    GLRDCR = '┬',
    GLRUCL = '┴',
    GLRUCR = '┴',
  },
  keymaps = {
    context_menu = { '<CR>', 'm', '<Space>' },
    checkout = 'C',
    close = { 'x', 'q' },
    create_branch = 'a',
    push = 'p',
    pull = 'P',
    add_tag = 't',
    cherry_pick = 'c',
    revert = 'v',
    reset = 'r',
    merge = 'M',
    rebase = 'R',
    refresh = 'gr',
    copy_hash = 'y',
    copy_message = 'Y',
  },
  hooks = {
    on_select_commit = function(commit)
      log.info('selected commit:', commit.hash)
    end,
    on_select_range_commit = function(from, to)
      log.info('selected range:', from.hash, to.hash)
    end,
  },
  format = {
    timestamp = '%d %b %Y %H:%M',
    fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag', 'message' },
  },
  log_level = vim.log.levels.ERROR,
}

return M

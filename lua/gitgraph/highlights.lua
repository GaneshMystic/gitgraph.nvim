local M = {}

---@class I.HighlightGroup
---@field name string
---@field fg string

---@type table<string, I.HighlightGroup>
M.ITEM_HGS = {
  hash = { name = 'GitGraphHash', fg = '#5c454f' },
  timestamp = { name = 'GitGraphTimestamp', fg = '#6d6d2e' },
  author = { name = 'GitGraphAuthor', fg = '#255256' },
  branch_name = { name = 'GitGraphBranchName', fg = '#4ec9b0' },
  tag = { name = 'GitGraphBranchTag', fg = '#dcdcaa' },
  message = { name = 'GitGraphBranchMsg', fg = '#b6d6cf' },
}

---@type I.HighlightGroup[]
M.BRANCH_HGS = {
  { name = 'GitGraphBranch1', fg = '#458588' },
  { name = 'GitGraphBranch2', fg = '#b16286' },
  { name = 'GitGraphBranch3', fg = '#d79921' },
  { name = 'GitGraphBranch4', fg = '#98971a' },
  { name = 'GitGraphBranch5', fg = '#d5651c' },
}

--- sets highlight groups if they are missing
function M.set_highlights()
  local function set_hl(name, highlight)
    local existing_hg = vim.api.nvim_get_hl(0, { name = name })
    if vim.tbl_isempty(existing_hg) then
      vim.api.nvim_set_hl(0, name, vim.tbl_deep_extend('force', highlight, { default = true }))
    end
  end

  for i, hg in ipairs(M.BRANCH_HGS) do
    set_hl(hg.name, { fg = hg.fg })
    set_hl('GitGraphBranch' .. i .. 'Cap', { fg = hg.fg })
    set_hl('GitGraphBranch' .. i .. 'Badge', { fg = '#282828', bg = hg.fg, bold = true })
    set_hl('GitGraphBranch' .. i .. 'RemoteSep', { fg = hg.fg, bg = '#3c3836' })
  end

  set_hl('GitGraphRemoteBadge', { fg = '#ebdbb2', bg = '#3c3836' })
  set_hl('GitGraphRemoteCap', { fg = '#3c3836' })

  local tag_color = M.ITEM_HGS.tag.fg
  set_hl('GitGraphTagCap', { fg = tag_color })
  set_hl('GitGraphTagBadge', { fg = '#282828', bg = tag_color, bold = true })

  for _, hg in pairs(M.ITEM_HGS) do
    set_hl(hg.name, { fg = hg.fg })
  end
end

return M

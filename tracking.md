# Tracking: Powerline Badges for Branch Names in gitgraph.nvim

## Tasks
- [x] **Highlights (`lua/gitgraph/highlights.lua`)**: Define color groups for branch caps, badge background/foreground, remote separators, remote badge, and remote caps (`GitGraphBranchNBadge`, `GitGraphBranchNCap`, `GitGraphBranchNRemoteSep`, `GitGraphRemoteBadge`, `GitGraphRemoteCap`, etc.).
- [x] **Config (`lua/gitgraph/config.lua`)**: Review default configurations and field formatting support.
- [x] **Parsing & Formatting (`lua/gitgraph/core.lua`)**: Implement `format_branch_badges` to parse branch names (local and remote pairing, multiple branches) and produce multi-segment powerline badge strings with precise highlight spans.
- [x] **Rendering (`lua/gitgraph/core.lua`)**: Update `graph_to_lines` to render branch badges using dynamic branch color mapping (`c.j % NUM_BRANCH_COLORS + 1`).
- [x] **Tests & Validation**: Verify implementation against existing test suite (`nvim --headless -u NONE -c "set runtimepath+=." -l lua/gitgraph/tests.lua`).

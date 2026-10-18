# Memory.md - AI Memory for gitgraph.nvim

Welcome! This document serves as the project memory for `gitgraph.nvim`, a Neovim plugin written in 100% Lua that draws interactive git graphs in a buffer.

## Architecture & File Structure

- `lua/gitgraph.lua`: Main entry point. Exposes `setup()`, `draw()`, `test()`, and `random()`.
- `lua/gitgraph/config.lua`: Default configuration (`I.GGConfig`), symbols (`I.GGSymbols`), format options, hooks, and log levels.
- `lua/gitgraph/core.lua`: Core algorithm (`_gitgraph`) responsible for:
  - Processing raw commits and building parent-child relationships.
  - Generating topological rows (commit rows and connector rows).
  - Inserting vertical and horizontal pipes / ASCII/Unicode branch symbols.
  - Converting the graph structure into lines and Neovim highlights (`graph_to_lines`).
- `lua/gitgraph/draw.lua`: Handles creating/managing the Neovim buffer/window, rendering the graph, setting up keymaps (e.g. `<CR>` for commit selection), and triggering hooks (`on_select_commit`, `on_select_range_commit`).
- `lua/gitgraph/git.lua`: Interacts with system `git` (executes `git log` with custom format strings to extract commits, parent hashes, author, date, branches, tags).
- `lua/gitgraph/highlights.lua`: Defines highlight groups (`GitGraphHash`, `GitGraphTimestamp`, `GitGraphAuthor`, `GitGraphBranchName`, `GitGraphBranchTag`, `GitGraphBranchMsg`, and `GitGraphBranch1` through `GitGraphBranch5`).
- `lua/gitgraph/utils.lua`: Helper functions (e.g., crossing resolution, bi-crossing detection).
- `lua/gitgraph/tests.lua`: Test suite runner (`test()` and `random()`).
- `lua/gitgraph/log.lua`: Lightweight logging utility.

## Key Features & Roadmap

### Completed

- 100% Lua
- Temporal topological order with branch lane sticking
- Merge commit and branch children identification
- Hooks for extension (e.g., `diffview.nvim`)
- Configurable date formats and highlight groups
- Performant scrolling and branch crossings

### Future / Roadmap

- Auto updating graph
- Performant load times for large repos
- Additional interactive features / keymaps

## Development Rules

- Conversing in minimal words with the user.
- Use `git ls-files` instead of recursive file listing commands like `ls -R`.

# gitgraph.nvim

An interactive, visually rich Git Graph plugin for Neovim written in 100% Lua.

`gitgraph.nvim` renders clear topological commit histories directly in a Neovim buffer with distinct branch lanes, powerline-styled branch/tag badges, smooth navigation, and a comprehensive set of interactive Git workflow actions (checkout, merge, rebase, cherry-pick, branch/tag creation, push/pull, and deep integration with [diffview.nvim](https://github.com/sindrets/diffview.nvim)).

> **Credit & Appreciation**: Built upon the great foundation of [isakbm/gitgraph.nvim](https://github.com/isakbm/gitgraph.nvim) by [Isak Buhl-Mortensen](https://github.com/isakbm). His core topological graph algorithm made this possible. I added several interactive features, visual refinements, and workflows for daily use—sharing it here in case others find it helpful!

---

## ✨ Features

- **Topological & Temporal Layout**: Commits stick cleanly to their respective branch lanes with intuitive branch crossing and merge-parent tracking.
- **Modern Powerline Badges**: Multi-segment Powerline branch and remote tracking badges (`  feature  origin/main `), color-coordinated with each branch lane.
- **Context-Aware Interactive Menu**: Press `<CR>` or `<Space>` on any commit, branch badge, or tag to invoke an intelligent action menu via `vim.ui.select`.
- **Mouse & Keyboard Driven**: Full support for quick hotkeys as well as right-click context menus and double-click commit inspections.
- **Safety-First Git Operations**:
  - Intelligent checkout prompts when a local branch is behind remote upstream (`Checkout & Pull` vs `Checkout local`).
  - Staged / no-commit options for merges and cherry-picks with instant [diffview.nvim](https://github.com/sindrets/diffview.nvim) staging reviews.
- **High Performance**: 100% asynchronous execution for Git actions without blocking the editor UI.
- **Extensible Hooks**: Built-in triggers for commit range selection and custom diff viewing.

---

## 📦 Installation

Install with your preferred Neovim package manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'GaneshMystic/gitgraph.nvim',
  dependencies = { 'sindrets/diffview.nvim' }, -- Optional, recommended for diff previews
  opts = {
    symbols = {
      merge_commit = 'M',
      commit = '*',
    },
    format = {
      timestamp = '%H:%M:%S %d-%m-%Y',
      fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag' },
    },
    hooks = {
      on_select_commit = function(commit)
        vim.cmd(':DiffviewOpen ' .. commit.hash .. '^!')
      end,
      on_select_range_commit = function(from, to)
        vim.cmd(':DiffviewOpen ' .. from.hash .. '~1..' .. to.hash)
      end,
    },
  },
  keys = {
    {
      '<leader>gl',
      function()
        require('gitgraph').draw({}, { all = true, max_count = 5000 })
      end,
      desc = 'GitGraph - Open Graph',
    },
  },
}
```

---

## ⌨️ Keymaps & Interactive Controls

All keymaps are active inside the GitGraph buffer and fully customizable via `opts.keymaps`:

| Action | Default Keymap | Description |
| :--- | :--- | :--- |
| **Context Menu** | `<CR>`, `<Space>` | Open context-sensitive action menu (tailored to hovered commit, branch badge, or tag) |
| **Checkout & Pull** | `c` | Checkout branch/commit and pull latest changes from cloud |
| **Checkout (No Pull)** | `C` | Checkout commit/branch directly without pulling changes from cloud |
| **Difference View** | `d` | Open Diffview for current commit, branch, tag, or uncommitted changes |
| **Create Branch & Checkout** | `a` | Create a new branch at target and switch to it immediately |
| **Create Branch Only** | `A` | Create branch at target without switching |
| **Add Tag & Push** | `t` | Create an annotated or lightweight tag and push it directly to remote |
| **Add Tag Only** | `T` | Create a tag locally |
| **Cherry-Pick (Review)** | `p` | Cherry-pick staged changes without committing (`--no-commit`) and open Diffview for review |
| **Cherry-Pick & Commit** | `P` | Cherry-pick and commit immediately |
| **Merge (Review)** | `m` | Merge branch/commit staged without committing (`--no-commit`) and review |
| **Merge & Commit** | `M` | Merge commit/branch into `HEAD` directly |
| **Rebase** | `R` | Rebase current `HEAD` onto selected commit/branch |
| **Reset** | `r` | Reset current branch to selected commit (prompts for `--soft`, `--mixed`, or `--hard`) |
| **Revert** | `v` | Revert selected commit |
| **Push** | `gp` | Push branch to `origin` |
| **Pull** | `gP` | Pull branch from `origin` |
| **Refresh** | `gr` | Re-fetch and redraw graph |
| **Copy Hash / Name** | `y` | Copy target commit hash or branch name to system clipboard |
| **Copy Message** | `Y` | Copy commit message to system clipboard |
| **Close** | `q`, `x` | Close GitGraph buffer and restore previous window layout |

### Mouse Support

- `<LeftMouse>`: Navigate and place cursor directly on commits, branch pills, or tags.
- `<2-LeftMouse>` (Double Click): Instantly inspect the commit / open diff view.
- `<RightMouse>`: Open context action menu directly for the clicked target (branch, tag, or commit).

---

## ⚙️ Configuration

Default options passed into `require('gitgraph').setup(opts)`:

```lua
require('gitgraph').setup({
  git_cmd = 'git',
  symbols = {
    merge_commit = 'M',
    commit = '*',
    merge_commit_end = 'M',
    commit_end = '*',

    -- Graph branch connector lines
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
  format = {
    timestamp = '%H:%M:%S %d-%m-%Y',
    fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag' },
  },
  hooks = {
    on_select_commit = function(commit) end,
    on_select_range_commit = function(from, to) end,
  },
  keymaps = {
    context_menu = { '<CR>', '<Space>' },
    checkout = 'C',
    checkout_pull = 'c',
    diffview = 'd',
    close = { 'x', 'q' },
    create_branch = 'A',
    create_branch_checkout = 'a',
    push = 'gp',
    pull = 'gP',
    add_tag = 'T',
    add_tag_push = 't',
    cherry_pick = 'p',
    cherry_pick_commit = 'P',
    merge = 'm',
    merge_commit = 'M',
    revert = 'v',
    reset = 'r',
    rebase = 'R',
    refresh = 'gr',
    copy_hash = 'y',
    copy_message = 'Y',
  },
})
```

---

## 🎨 Highlight Groups

You can customize any highlight group used by `gitgraph.nvim`:

### Commit Details
- `GitGraphHash`: Commit hash color.
- `GitGraphTimestamp`: Date & timestamp display.
- `GitGraphAuthor`: Commit author.
- `GitGraphBranchName`: Fallback branch text highlight.
- `GitGraphBranchTag`: Tag badge text highlight.
- `GitGraphBranchMsg`: Commit summary message.

### Branch Lanes & Badges
- `GitGraphBranch1` to `GitGraphBranch5`: Rotating colors assigned to each branch lane and connector.
- Dynamic Powerline badge groups for each branch color index (e.g. `GitGraphBranch1Badge`, `GitGraphBranch1Cap`, `GitGraphBranch1RemoteSep`, `GitGraphRemoteBadge`, `GitGraphRemoteCap`).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

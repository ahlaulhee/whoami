# neovim-setup: verify on the real machine

Verified in the Fedora 45 WSL environment on 2026-11-08 (details in `notes/research/neovim-0.12.md`): `Lazy! sync` (18 plugins), all 17 mason packages, all 17 treesitter parsers; LSP attach for roslyn, vtsls, gopls, basedpyright + ruff, lua_ls on test projects; conform formats all five languages on save; eslint_d and golangci-lint report diagnostics; nvim-ts-autotag closes and renames tags; `:checkhealth` without errors; tmux config loads and vim-tmux-navigator moves across nvim splits and tmux panes; screenshot foot → tmux → nvim with icons (needs the Nerd symbols font).

Only the real machine can confirm:

- `testedOn` versions (Neovim, tmux, .NET SDK, Node, Go, Python) on your install.
- Roslyn on a real solution (first start ~7 s in the test project; larger solutions take longer).
- `<Tab>` vs `<C-i>` distinct inside tmux in foot (extended-keys settings load, behaviour untested).
- Clipboard: yank in Neovim → paste in another app (wl-clipboard) and tmux copy mode `y` → paste.
- Keymaps: carried over from github.com/ahlaulhee/neovim; adjust to taste.
- opencode: sign in to a provider, send one message in the TUI, then `<leader>aa` from Neovim; edit permission diffs (`da`/`dr`) and auto-reload of edited files. In WSL the connection and context strings were verified up to sending (no prompt sent to avoid starting a model run).
- codediff: review loop with real agent changes; stage/discard hunk keys `<leader>gs`/`<leader>gr` inside the view.
- Screenshot for the article: tmux with nvim + neo-tree, picker, completion menu.

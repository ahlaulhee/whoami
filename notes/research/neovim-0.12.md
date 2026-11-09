# Neovim 0.12 config (lazy.nvim, native LSP, mason) + tmux: config and verification

Verified on 2026-11-08 in the WSL distro `FedoraLinux-45`: Neovim 0.12.6 (`neovim-0.12.6-1.fc45`), tmux 3.8 (`tmux-3.8-2.fc45`), tree-sitter-cli 0.26.11, Node 22.23.1 / npm 10.9.8, Go 1.27.3, .NET SDK 10.0.113, Python 3.15.0, uv 0.13.5.

Files:
- Neovim config: `C:/dev/scratch-nvim/nvim/` → `~/.config/nvim/` (stow package `nvim/.config/nvim/...`)
  - `init.lua`, `lua/config/{options,keymaps,autocmds,lazy}.lua`
  - `lua/plugins/{colorscheme,completion,explorer,format,git,lint,lsp,mini,tmux,treesitter}.lua`
  - `lazy-lock.json` (written by `Lazy! sync`), `.stylua.toml` (2 spaces, so format-on-save keeps the config's own style)
- tmux: `C:/dev/scratch-nvim/tmux.conf` → `~/.config/tmux/tmux.conf`
- Screenshot: `C:/dev/scratch-nvim/nvim.png` (foot → tmux → nvim with `Counter.tsx` and neo-tree, 1600×900 headless Mango output)
- Test harness: `C:/dev/scratch-nvim/test/` (projects `cs/ go/ ts/ py/ lua/`, bad samples in `samples/`, scripts in `scripts/`, logs `*.log`, `health.txt`). The scripts copy `test/` to `/root/nvtest` inside WSL so `node_modules`, `bin/`, `obj/` stay off NTFS.

## Install (Fedora 45)

```sh
sudo dnf install neovim git gcc make ripgrep fd-find unzip tree-sitter-cli \
  nodejs nodejs-npm golang dotnet-sdk-10.0 python3 python3-pip uv wl-clipboard tmux
# optional, for mini.icons glyphs if the terminal font is plain Maple Mono (Terra):
sudo dnf install nerdfontssymbolsonly-nerd-fonts
```

Notes:
- Fedora's npm is the separate package `nodejs-npm` (`dnf install npm` finds nothing).
- nvim-treesitter's README wants tree-sitter-cli ≥ 0.26.1 "installed via your package manager, **not npm**" plus a C compiler, `tar` and `curl`.
- Packages actually installed in WSL for this work: `nodejs-npm golang dotnet-sdk-10.0 uv fd-find tmux python3-pip` (plus their dependencies: dotnet host/runtime/targeting packs, golang-bin/src, …) and `nerdfontssymbolsonly-nerd-fonts`. `neovim git gcc make ripgrep unzip tree-sitter-cli nodejs wl-clipboard foot grim` were already there. Full log: `test/dnf.log`.

Bootstrap a new machine (all three block until done; `test/scripts/bootstrap.sh`):

```sh
nvim --headless "+Lazy! sync" +qa
nvim --headless -c "lua require('nvim-treesitter').install({ 'c_sharp', 'typescript', 'tsx', 'javascript', 'go', 'lua', 'python', 'html', 'css', 'json', 'yaml', 'bash', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline' }):wait(600000)" +qa
nvim --headless +MasonInstallAll +qa
```

In an interactive session none of this is needed: missing parsers and mason tools are installed on `VimEnter` (the Mason window opens and shows progress).

## Plugins

Versions from `lazy-lock.json` (commit, commit date, nearest tag from `git describe`).

| Plugin | Repo | Commit (date) | Tag / branch | Setup used | Docs |
|---|---|---|---|---|---|
| lazy.nvim | https://github.com/folke/lazy.nvim | `306a055` (2025-12-17) | main (healthcheck reports 11.17.5) | bootstrap clone + `require("lazy").setup({ spec = { { import = "plugins" } }, rocks = { enabled = false }, … })` | https://lazy.folke.io/installation |
| vague.nvim | https://github.com/vague-theme/vague.nvim | `73f8aaa` (2026-10-08) | v2.1.5 | `require("vague").setup({})`, `vim.cmd.colorscheme("vague")`, `priority = 1000` | README |
| mason.nvim | https://github.com/mason-org/mason.nvim | `2a6940a` (2026-06-11) | v2.3.1 | `setup({ registries = { "github:mason-org/mason-registry", "github:Crashdummyy/mason-registry" } })`, `mason-registry.is_installed()`, `:MasonInstall` | `:h mason`, `:h mason-registry.refresh()` (doc/mason.txt) |
| nvim-lspconfig | https://github.com/neovim/nvim-lspconfig | `993d048d` (2026-11-06) | v2.12.0+61 | no setup; supplies `lsp/<name>.lua`; we call `vim.lsp.config()` / `vim.lsp.enable()` | https://github.com/neovim/nvim-lspconfig#quickstart, https://neovim.io/doc/user/lsp.html#lsp-config |
| roslyn.nvim | https://github.com/seblyng/roslyn.nvim | `1310387` (2026-11-01) | main (no tags) | `opts = {}`, `ft = { "cs", "razor" }` | README |
| lazydev.nvim | https://github.com/folke/lazydev.nvim | `ff2cbcb` (2026-03-14) | v1.10.0+ | `ft = "lua"`, `library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } }` | README |
| blink.cmp | https://github.com/Saghen/blink.cmp | `78336bc` (2026-04-04) | v1.10.2 (`version = "1.*"`) | `keymap.preset = "default"`, `snippets.preset = "default"`, `sources.per_filetype.lua = { inherit_defaults = true, "lazydev" }`, `fuzzy.implementation = "prefer_rust_with_warning"` | https://cmp.saghen.dev/installation, …/configuration/snippets, …/configuration/sources |
| friendly-snippets | https://github.com/rafamadriz/friendly-snippets | `7a1c9f7` (2026-11-08) | main | loaded automatically by blink's snippets source | blink snippets doc |
| conform.nvim | https://github.com/stevearc/conform.nvim | `016802d` (2026-08-11) | master (v9.1.0 is the latest release) | `formatters_by_ft`, `format_on_save = function(bufnr) … end` | README "Setup", `:h conform` |
| nvim-lint | https://github.com/mfussenegger/nvim-lint | `52107ce` (2026-10-29) | master (no releases) | `linters_by_ft`, `try_lint(names)` in an autocmd, `get_namespace()` in the test | README "Usage" |
| nvim-treesitter | https://github.com/nvim-treesitter/nvim-treesitter | `19bdfc04` (2026-11-07) | **main** | `install(parsers)`, `FileType` autocmd with `vim.treesitter.start()` and `indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"` | https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md |
| nvim-ts-autotag | https://github.com/windwp/nvim-ts-autotag | `d7220b5` (2026-10-03) | main (no tags) | `setup({ opts = { enable_close = true, enable_rename = true, enable_close_on_slash = false } })` | README "Setup" |
| neo-tree.nvim | https://github.com/nvim-neo-tree/neo-tree.nvim | `1a14083` (2026-09-01) | branch v3.x (latest release 3.42.0) | `lazy = false` (README: "neo-tree will lazily load itself"), `filesystem.follow_current_file`, `use_libuv_file_watcher` | README "lazy.nvim example" |
| nui.nvim | https://github.com/MunifTanjim/nui.nvim | `10fc361` (2026-08-21) | 0.4.0+10 | neo-tree dependency | |
| plenary.nvim | https://github.com/nvim-lua/plenary.nvim | `74b06c6` (2026-04-10) | v0.1.4+40 | neo-tree dependency | |
| mini.nvim | https://github.com/nvim-mini/mini.nvim (moved from echasnovski/mini.nvim) | `f9ac12d` (2026-11-08) | main (`version = false`; stable is v0.18.0) | `mini.ai`, `mini.pairs`, `mini.surround`, `mini.icons` + `MiniIcons.mock_nvim_web_devicons()`, `mini.statusline`, `mini.starter` (items: `sections.pick()`, `recent_files(5, false, false)`, `builtin_actions()`), `mini.pick` (+ `vim.ui.select = MiniPick.ui_select`), `mini.extra`, `mini.clue` | https://github.com/nvim-mini/mini.nvim/tree/main/readmes, `:h mini-pick`, `:h MiniExtra.pickers.lsp()`, `:h mini-clue` |
| gitsigns.nvim | https://github.com/lewis6991/gitsigns.nvim | `ef707fb` (2026-11-05) | main (latest release v2.1.0) | `on_attach` buffer maps: `nav_hunk`, `stage_hunk`, `reset_hunk`, `preview_hunk_inline`, `blame_line` | README |
| vim-tmux-navigator | https://github.com/christoomey/vim-tmux-navigator | `e41c431` (2026-01-25) | v1.0+84 | the README's lazy.nvim spec verbatim (`cmd` + `keys`) | README "lazy.nvim" |

## How the pieces fit

### LSP (`plugins/lsp.lua`)

- Servers are enabled with `vim.lsp.enable({ "vtsls", "html", "cssls", "jsonls", "tailwindcss", "gopls", "lua_ls", "basedpyright", "ruff" })`. Their `cmd`/`filetypes`/`root_markers` come from nvim-lspconfig's `lsp/*.lua`, which Neovim merges automatically once the plugin is on the runtimepath. Only basedpyright gets an override (`settings.basedpyright.disableOrganizeImports = true`, ruff does imports).
- C#: roslyn.nvim registers and starts its own `roslyn` config; it is *not* in the list (lspconfig also ships `roslyn_ls`, which stays disabled).
- Ruff hover is disabled on `LspAttach`, as in Ruff's Neovim docs (https://docs.astral.sh/ruff/editors/setup/#neovim: "Disable hover in favor of Pyright", plus `disableOrganizeImports = true` on the pyright side).
- Completion capabilities: blink's `plugin/blink-cmp.lua` runs `vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities(...) })`. That only works if blink is loaded before the first server starts, so blink is not lazy-loaded (its docs don't lazy-load it either; it defers its own work). `:checkhealth vim.lsp` shows the merged capabilities (resolveSupport, labelDetailsSupport, snippetSupport) on every enabled config.
- mason is `lazy = false` because `setup()` prepends `~/.local/share/nvim/mason/bin` to PATH (`:checkhealth mason` → "PATH: prepend").
- Tool installation: one list of 17 mason package names, one function `install_missing()` that filters with `mason-registry.is_installed()` and calls `:MasonInstall --quiet <missing>`. Exposed as `:MasonInstallAll`; also runs once on `VimEnter`. `:MasonInstall` blocks in headless mode (mason.txt: "This will run the command in blocking mode and the command won't yield back until all packages have finished installing") and refreshes the registries itself (source: `lua/mason/api/command.lua`).
  - `--quiet` matters: without it, a headless run streams installer stderr through `nvim_err_write`, and because the command is called from Lua (`vim.cmd`), the first stderr line (`go: downloading golang.org/x/tools v0.23.0`) was raised as `Lua :command callback: … Vim:go: downloading …`. With `--quiet` the same run exits 0 with no output.
  - `VimEnter` vs headless: `-c`/`+` commands run before `VimEnter` (checked: `--cmd "au VimEnter …" -c "…"` prints only the `-c` output with `-c qa`). So the startup auto-install never races a scripted bootstrap.
- `LspAttach` keymaps: the 0.12 defaults are kept (`:h lsp-defaults`: `gra`, `gri`, `grn`, `grr`, `grt`, `grx` (codelens run), `gO`, `K`, insert `CTRL-S`). Added: `gd` (definition picker), `gD` (declaration), `gR` (references picker), `<leader>ss` (document symbols), `<leader>sS` (workspace symbols, live query). `MiniExtra.pickers.lsp({ scope = … })` supports `declaration`, `definition`, `document_symbol`, `implementation`, `references`, `type_definition`, `workspace_symbol`, `workspace_symbol_live`.

### Treesitter (`plugins/treesitter.lua`)

- `branch = "main"`, `lazy = false`, `build = ":TSUpdate"` (README: "This plugin does not support lazy-loading").
- No `setup()` call (README: "You do not need to call `setup` … using default values"; install dir defaults to `stdpath('data')/site`).
- `require('nvim-treesitter').install(parsers)` on `VimEnter` (async, a no-op for installed parsers).
- One `FileType` autocmd whose pattern is built from `vim.treesitter.language.get_filetypes(lang)` for each parser (so `c_sharp` → `cs`, `tsx` → `typescriptreact`, `bash` → `sh`/`bash`), calling `vim.treesitter.start()` and setting the experimental indentexpr. `pcall` guards the very first start while a parser is still compiling.
- `markdown_inline` is added to the requested list: the markdown parser injects it for inline emphasis/links.

### Completion, format, lint

- blink.cmp `version = "1.*"` downloads the prebuilt Rust fuzzy matcher (`:checkhealth blink.cmp`: "blink_cmp_fuzzy lib is downloaded/built"). Snippet engine: `snippets.preset = "default"` = `vim.snippet`; friendly-snippets is picked up automatically (blink docs: "When using the built-in `vim.snippet` snippet engine, friendly-snippets will be automatically loaded, if available").
- conform: `cs = csharpier`, JS/TS/JSX/TSX/JSON/JSONC/CSS/HTML/YAML/Markdown = `prettierd`, `go = goimports, gofumpt`, `lua = stylua`, `python = ruff_organize_imports, ruff_format`. Format on save with `lsp_format = "fallback"`; timeout 1000 ms, 3000 ms for C# (csharpier starts a .NET process). `<leader>f` formats async. Loaded on `BufWritePre`.
- nvim-lint: `eslint_d` for JS/TS/JSX/TSX, `golangcilint` for Go. Runs on `BufReadPost`, `BufWritePost`, `InsertLeave`. eslint_d is skipped unless `vim.fs.root(buf, { "eslint.config.{js,mjs,cjs,ts,mts,cts}" })` finds a flat config (otherwise eslint_d reports a "no config" error in every non-ESLint project). nvim-lint's golangcilint definition detects golangci-lint v1/v2.0/v2.1+ and picks the matching flags.
  - **Lazy-loading trap (found and fixed):** loading nvim-lint on `BufReadPost` lazy-loads it from lazy.nvim's own `BufReadPost` handler, which runs *before* Neovim's `filetypedetect` autocmd; the replayed event saw `filetype == ""` and linted nothing (instrumented: `lint cb BufReadPost {}`). Loading on `ft = vim.tbl_keys(linters_by_ft)` fixes it: lazy replays `BufReadPost` for the new group from inside `FileType`, and later buffers hit our autocmd after `filetypedetect`.

### Editor (`config/*.lua`)

- Options: relative numbers, `signcolumn=yes`, `winborder=rounded` (0.11+ default float border), `inccommand=split`, `undofile`, smart case, 4-space indent with 2 spaces for prettier filetypes (FileType autocmd; Go and Python already get tabs / 4 spaces from Neovim's ftplugins), `clipboard=unnamedplus` set in `vim.schedule` (provider detected: `wl-copy`).
- Diagnostics: `severity_sort`, virtual text, float after `]d`/`[d`. `jump = { float = true }` is deprecated in 0.12 (`:h deprecated`: "float" in `vim.diagnostic.Opts.Jump` → "Use `on_jump` instead"), so the config uses `jump.on_jump` → `vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })`, the same call the deprecated path makes internally (`runtime/lua/vim/diagnostic.lua` ~l.1310).
- `vim.hl.on_yank()` on `TextYankPost`.

## Decisions

- **mason-lspconfig: not used.** In v2 it maps lspconfig names to mason packages (`ensure_installed`) and calls `vim.lsp.enable` for installed servers (`automatic_enable`). Neither covers formatters/linters (csharpier, prettierd, goimports, gofumpt, stylua, eslint_d, golangci-lint), and `roslyn` comes from a second registry and is started by roslyn.nvim, not `vim.lsp.enable`. So a tool list and an install function are needed anyway; with them, mason-lspconfig would only save typing nine server names, and an explicit `vim.lsp.enable` list makes it obvious what runs.
- **mini.clue instead of which-key.** mini.nvim is already loaded, so key hints cost no extra plugin; it is configured with the triggers and `gen_clues` from its own docs example plus two group labels (`<Leader>s` Search, `<Leader>g` Git). Hint window delay 300 ms (default 1000). Trade-off: unlike which-key, mini.clue needs triggers listed explicitly; new prefixes need a trigger line.
- **gitsigns: yes.** Hunk signs, `]h`/`[h`, stage/reset/preview hunk and line blame in one plugin, and mini.statusline reads `gitsigns` branch/diff data without extra config. The mini alternative would be two more modules (mini.diff + mini.git) and no line blame. The author used gitsigns before.
- **Web servers: html, cssls, jsonls, tailwindcss: yes.** html/css/json are one npm package (`vscode-langservers-extracted` 4.10.0, the mason packages `html-lsp`/`css-lsp`/`json-lsp` share it). tailwindcss has `workspace_required = true` and only finds a root with a `tailwind.config.*` or a `package.json` that depends on `tailwindcss` (lspconfig `lsp/tailwindcss.lua`), so it stays idle elsewhere (it did not attach in the test React project). No SchemaStore plugin.
- **blink keymap preset `default`** (`<C-y>` accept, `<C-n>/<C-p>`, `<C-space>`, `<C-e>`, `<C-k>` signature, `<Tab>/<S-Tab>` snippet jumps): it matches Neovim's built-in completion keys and the kickstart heritage of the old config.
- **Auto-install on `VimEnter`** (mason tools and parsers): first interactive start sets everything up; headless scripts are unaffected (see above).
- **neo-tree `lazy = false`**: per its README; it still defers loading and can hijack `nvim <dir>`.
- **tmux prefix C-a.** Home row. Its clashes (readline beginning-of-line, Neovim increment) are handled by `bind C-a send-prefix` (press twice). C-b is page-up in Neovim and backward-char in readline, with no gain over C-a.
- **tmux status line on top.** Neovim's statusline and command line are at the bottom; putting tmux's bar there stacks three bars. (The Quickshell bar is a separate layer-shell surface at the top of the screen, not inside the terminal.)
- **tmux splits `prefix v` / `prefix h`** mirror Neovim's `<leader>v` / `<leader>h`; `%` and `"` are rebound to keep the cwd too, and `c` opens new windows in the cwd.
- **No TPM.** The vim-tmux-navigator tmux side is the README snippet pasted in. The snippet's version check pipes through `bc`, which Fedora doesn't install by default (`which bc` → not found in WSL), so both `if-shell` lines would silently fail and leave `C-\` unbound. The snippet keeps only the tmux ≥ 3.0 binding.
- **Extended keys in tmux** (`extended-keys on`, `extended-keys-format csi-u`, `terminal-features foot*:extkeys`): meant to keep `<Tab>` (bnext) distinct from `<C-i>` (jump forward) inside tmux. tmux accepts the options; whether `<C-i>` arrives distinct inside Neovim in a real foot window was not tested [INFERENCE].
- **Old keymaps dropped:** arrow-key resize, `<leader>b` new buffer, `<leader>se`, `<leader>xs` (would make `<leader>x` wait for a second key), tab maps `<leader>t*`, `<leader>lw`, `<leader>st` terminal, terminal `<C-q>`. Not in the carry-over list; `<C-w>` window commands are covered by mini.clue's window clues. The old README listed `[d` as "next" (swapped); 0.12's defaults are `]d` next / `[d` previous.

## Keymaps

Leader = Space.

| Mode | Keys | Action | Source |
|---|---|---|---|
| i | `jj` | Escape | keymaps.lua |
| t | `<Esc><Esc>` | Leave terminal mode | keymaps.lua |
| n, x | `<C-s>` | `:write` (insert `<C-s>` stays LSP signature help) | keymaps.lua |
| n | `<Esc>` | `:nohlsearch` | keymaps.lua |
| n | `x` | Delete char into black-hole register | keymaps.lua |
| n | `<C-d>` / `<C-u>` / `n` / `N` | Scroll / search, cursor centred | keymaps.lua |
| x | `<` / `>` | Indent, keep selection | keymaps.lua |
| x | `p` | Paste without yanking the selection (built-in `v_P`) | keymaps.lua |
| n | `<Tab>` / `<S-Tab>` | Next / previous buffer | keymaps.lua |
| n | `<leader>x` | Close buffer | keymaps.lua |
| n | `<leader>v` / `<leader>h` | Vertical / horizontal split | keymaps.lua |
| n | `]d` / `[d` / `]D` / `[D` | Next / prev / last / first diagnostic (+ float) | Neovim default |
| n | `<C-w>d` | Diagnostic float | Neovim default |
| n | `<leader>q` | Diagnostics → location list | keymaps.lua |
| n | `<C-h/j/k/l>`, `<C-\>` | Move across Neovim splits and tmux panes, previous | vim-tmux-navigator |
| n | `<leader>sf` | Files | mini.pick |
| n | `<leader>sg` | Live grep | mini.pick |
| n | `<leader>sw` | Grep word under cursor | mini.pick |
| n | `<leader><leader>` | Buffers | mini.pick |
| n | `<leader>sh` | Help | mini.pick |
| n | `<leader>sd` | Diagnostics | mini.extra |
| n | `<leader>sr` | Resume last picker | mini.pick |
| n | `<leader>s.` | Recent files (oldfiles) | mini.extra |
| n | `<leader>sk` | Keymaps | mini.extra |
| n | `grn` / `gra` / `grr` / `gri` / `grt` / `grx` / `gO` / `K` | Rename / code action / references / implementation / type definition / codelens / document symbols / hover | Neovim 0.12 default |
| i | `<C-s>` | Signature help | Neovim default |
| n | `gd` / `gR` | Definition / references (picker) | LspAttach, mini.extra |
| n | `gD` | Declaration | LspAttach |
| n | `<leader>ss` / `<leader>sS` | Document / workspace symbols (picker) | LspAttach, mini.extra |
| n, x | `<leader>f` | Format buffer/selection | conform |
| n | `<leader>e` | Toggle neo-tree, reveal current file | neo-tree |
| n | `]h` / `[h` | Next / previous hunk | gitsigns |
| n | `<leader>gs` / `<leader>gr` / `<leader>gp` / `<leader>gb` | Stage / reset / preview hunk, blame line | gitsigns |
| i | `<C-space>` / `<C-y>` / `<C-n>` `<C-p>` / `<C-e>` / `<C-k>` / `<Tab>` `<S-Tab>` | Open / accept / select / hide / signature / snippet jump | blink.cmp `default` preset |
| n, x | `sa` / `sd` / `sr` / `sf` `sF` / `sh` | Add / delete / replace / find / highlight surrounding | mini.surround |
| o, x | `a`/`i` + `f` `a` `q` `b` `t` `?` … | Function call, argument, quote, bracket, tag, prompt textobjects | mini.ai |

tmux (prefix `C-a`):

| Keys | Action |
|---|---|
| `C-a C-a` | Send `C-a` to the program |
| `prefix v` / `prefix %` | Split side by side, same cwd |
| `prefix h` / `prefix "` | Split stacked, same cwd |
| `prefix c` | New window, same cwd |
| `prefix r` | Reload `~/.config/tmux/tmux.conf` |
| `prefix C-l` | Clear screen (`C-l` itself is the navigator) |
| `C-h/j/k/l`, `C-\` (no prefix) | Pane navigation, passed to Neovim when it runs in the pane |
| copy mode `v` / `C-v` / `y` | Begin selection / rectangle / copy to Wayland clipboard (`copy-command wl-copy`; mouse drag uses it too) |

## Mason packages and their runtimes

Installed versions from each `mason-receipt.json`:

| Mason package | Source (receipt id) | Needs at install / run time |
|---|---|---|
| roslyn | `pkg:github/Crashdummyy/roslynLanguageServer@5.14.0-1.26554.1` | download only; runs on the .NET 10 runtime (`runtimeconfig.json`: `Microsoft.NETCore.App` 10.0.0, rollForward Major) → `dotnet-sdk-10.0` |
| csharpier | `pkg:nuget/csharpier@1.2.6` | .NET SDK (installed as a `dotnet tool`) |
| vtsls | `pkg:npm/@vtsls/language-server@0.3.0` | node + npm |
| html-lsp, css-lsp, json-lsp | `pkg:npm/vscode-langservers-extracted@4.10.0` | node + npm |
| tailwindcss-language-server | `pkg:npm/@tailwindcss/language-server@0.16.0` | node + npm |
| prettierd | `pkg:npm/@fsouza/prettierd@0.29.0` | node + npm |
| eslint_d | `pkg:npm/eslint_d@15.1.0` | node + npm; uses the project's own `eslint` |
| gopls | `pkg:golang/golang.org/x/tools/gopls@v0.23.0` | Go (`go install`) |
| goimports | `pkg:golang/golang.org/x/tools@v0.52.0#cmd/goimports` | Go |
| gofumpt | `pkg:golang/mvdan.cc/gofumpt@v0.12.0` | Go |
| golangci-lint | `pkg:github/golangci/golangci-lint@v2.15.0` | prebuilt binary; Go toolchain at run time to type-check |
| basedpyright | `pkg:pypi/basedpyright@1.40.2` | python3 + venv + pip; pulls `nodejs-wheel-binaries` 24.19.0, so no system node needed |
| ruff | `pkg:github/astral-sh/ruff@0.17.4` | prebuilt binary |
| lua-language-server | `pkg:github/LuaLS/lua-language-server@3.19.2` | prebuilt binary |
| stylua | `pkg:github/johnnymorganz/stylua@v2.6.0` | prebuilt binary (unzip) |

`:checkhealth mason` warnings are only for runtimes no package here uses (cargo, luarocks, Ruby/gem, Composer/PHP, java/javac, julia).

## Verification (WSL, 2026-11-08)

1. **Toolchain install**: `dnf install` OK (log `test/dnf.log`). The first attempt waited for another agent's dnf lock; the script retries.
2. **Plugins / mason**: `nvim --headless "+Lazy! sync" +qa`: 18 plugins, no errors. `nvim --headless +MasonInstallAll +qa`: all 17 packages installed (receipts listed above; `test/bootstrap.log`). Repeat test after deleting gopls/goimports/stylua: reinstalled in 2.6 s, nvim exit 0, no error output (`test/mason.log`).
3. **Treesitter**: all 17 parsers built (`bash c_sharp css go html javascript json lua markdown markdown_inline python query tsx typescript vimdoc vim yaml`; `:checkhealth nvim-treesitter` lists them with their H/L/F/I/J query coverage).
   - First attempt failed for 12 parsers with `Dynamic library … parser.so not found after build attempt. Are you running multiple processes building to the same output location?`: the config's startup `install()` and the bootstrap's `install():wait()` (and lazy's `build = ":TSUpdate"`) built the same parsers at once. Moving the config's install to `VimEnter` fixed it; the next run reported `Installed 12/12 languages`.
4. **Test projects** (`test/verify.log`, script `test/scripts/verify.sh`, harness `test/scripts/check.lua`):
   - LSP, the assignment's 15 s one-liner: `cs/Program.cs: { "roslyn" }`, `ts/src/App.tsx: { "vtsls" }`, `go/main.go: { "gopls" }`, `py/main.py: { "basedpyright", "ruff" }`, `lua/init.lua: { "lua_ls" }`.
   - LSP, wait-until-initialized: all five PASS (client initialised 20–160 ms after the `-c` command runs; roslyn "initialised" here means the warm daemon, see the next line). 9/9 checks in the final `verify.log` PASS.
   - Roslyn readiness (`test/roslyn.log`): cold start (daemon killed) client initialised after 1485 ms, first hover on `Console` answered after 7074 ms; warm start (daemon still running) 107 ms / 3087 ms.
   - conform format-on-save (`:write` on a badly formatted copy, `diff -u` before/after, all changed): `Bad.cs` (csharpier, ~0.8 s incl. nvim startup), `Bad.tsx` (prettierd, ~0.3 s), `cmd/bad/main.go` (goimports + gofumpt: import order, `var x = 1` → `x := 1`), `bad.py` (ruff: imports split/sorted, PEP 8 spacing), `bad.lua` (stylua).
   - nvim-lint: `Bad.tsx` → `2:9 [eslint_d] 'unused' is assigned a value but never used. (@typescript-eslint/no-unused-vars)`; same diagnostic when `Bad.tsx` is opened as a second buffer after startup; `cmd/bad/main.go` → `11:11 [errcheck] Error return value of 'os.Remove' is not checked`.
   - nvim-ts-autotag (feedkeys in a TSX buffer, inside `<main>`): typing `<div>` gives `<div></div>`; changing the open tag to `section` and leaving insert mode gives `<section></section>`. PASS.
   - Startup (`test/startup.log`): `:messages` empty; 15 sampled keymaps resolve (`<leader>sf/sg/sw/<leader>/sh/sd/sr/s./e/f`, `<C-h>`, `<Tab>`, `jj`, terminal `<Esc><Esc>`, visual `p`); `clipboard=unnamedplus` with provider `wl-copy`; `--startuptime` ≈ 27–31 ms with no file, ≈ 131–144 ms opening a TSX file (treesitter + LSP + lint).
5. **`:checkhealth lazy mason nvim-treesitter vim.lsp blink.cmp`** (`test/health.txt`): no ERRORs.
   - lazy ✅ (luarocks disabled). nvim-treesitter ✅ (ABI 15, tree-sitter-cli 0.26.11, install dir writable and on rtp).
   - blink.cmp: 1 warning, informational ("Some providers may show up as 'disabled' but are enabled dynamically"; lazydev is listed as disabled because it is per-filetype).
   - mason: 9 warnings, all unused runtimes (see above). Both registries installed.
   - vim.lsp: 20 warnings, all `Unknown filetype '…'` for filetypes in lspconfig's server configs that Neovim doesn't detect (`gotmpl` from gopls; `aspnetcorerazor`, `django-html`, `ejs`, `hbs`, `mdx`, `postcss`, … from tailwindcss). Harmless.
6. **tmux** (`test/tmux.log`, `test/scripts/tmux-check.sh`, private socket `-L nvcheck`): `tmux -f tmux.conf new -d` exit 0, `source-file` exit 0, `show-messages` has nothing besides the executed commands (no errors). `list-keys` has `-T root C-h … if-shell "ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE …" "send-keys C-h" "select-pane -L"` (and C-j/k/l/`C-\`, plus the copy-mode-vi ones). Options read back: prefix C-a, escape-time 10, default-terminal tmux-256color, `foot*:RGB:extkeys`, extended-keys on, status-position top, copy-command wl-copy, focus-events on, base-index 1.
   - Navigator end to end, with a real client attached through `script` and keys sent via `send-keys -K` (goes through the key tables like typing): C-l in nvim (one window) → shell pane; C-h in the shell → nvim pane; after `:vsplit`, C-h stays in nvim (window 1/2); C-l → right split (2/2); C-l at the edge → shell pane. `prefix v` from the nvim pane splits in `/root/nvtest/ts/src`.
7. **Screenshot**: `C:/dev/scratch-nvim/nvim.png` (foot → tmux → nvim + neo-tree, headless Mango with software GL). The first shot showed tofu boxes for every mini.icons glyph because plain Maple Mono has no Nerd Font symbols; after `dnf install nerdfontssymbolsonly-nerd-fonts` foot falls back to Symbols Nerd Font through fontconfig and the icons render (folder, React, LSP).

## Caveats

- **Roslyn startup**: ~1.5 s to initialise and ~7 s until it answers requests on a cold start for a one-file console project (larger solutions will take longer [INFERENCE]); it runs in daemon mode and stays alive 900 s after the last client (roslyn.nvim README), so the next start is faster (3 s to first hover here). roslyn.nvim looks for `.sln`/`.slnx`/`.slnf` (`lua/roslyn/sln/discovery.lua`) and otherwise the project file (the test project has only `Hello.csproj` and attached); `:Roslyn target` switches between several solutions.
- **csharpier via mason vs dotnet tool**: mason installs csharpier 1.2.6 as a dotnet tool into its own directory, used for every project. conform's csharpier formatter first runs `dotnet csharpier --version`; if a repo has a local tool manifest (`dotnet new tool-manifest && dotnet tool install csharpier`), conform uses that pinned version instead (`dotnet csharpier format --stdin-path`). Use the local tool when a team pins a version, so everyone formats with the same CSharpier release.
- **mini.icons needs Nerd Font glyphs**: with plain Maple Mono, install `nerdfontssymbolsonly-nerd-fonts` (Terra) or Maple Mono NF; or set `require("mini.icons").setup({ style = "ascii" })`.
- **eslint_d** only runs where an ESLint flat config exists, and uses the project's `node_modules/eslint`; a project needs `npm install` first.
- **golangci-lint** type-checks with the Go toolchain; expect the first run in a module to be slower while its cache fills [INFERENCE] (the test module reported within the 60 s check window).
- **Treesitter indent** is experimental (README). With the global 4-space indent, the autotag test's new line inside `<main>` was indented 8 columns past it (two levels); with the 2-space setting for TSX it is one level (6 columns under `<main>` at 4). prettier normalises indentation on save anyway. Parsers must be rebuilt after nvim-treesitter updates; `build = ":TSUpdate"` does that on `Lazy sync`.
- **Two nvim-treesitter installs at once** (e.g. a bootstrap script while an interactive nvim is starting for the first time) can fail with "multiple processes building to the same output location". Re-run the install.
- **tmux `terminal-features` is appended** (`set -as`) on every `prefix r`, so the `foot*` entry appears once per reload (`terminal-features[3]` and `[4]` after one reload). Harmless.
- **Format-on-save timeouts** (1 s, 3 s for C#) passed in the tests including daemon start for prettierd; on a slow first `csharpier` run, conform skips formatting for that save and logs a timeout.
- The mason registry for roslyn is a third party (Crashdummyy). roslyn.nvim recommends it because nuget's `roslyn-language-server` lags behind the VS Code build.

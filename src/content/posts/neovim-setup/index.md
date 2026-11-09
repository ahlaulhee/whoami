---
slug: neovim-setup
title: My Neovim config
description: Neovim 0.12 on Fedora 45 with native LSP for .NET, TypeScript/React, Go, Lua and Python, blink.cmp, conform, nvim-lint, mini.nvim, neo-tree and vague.nvim, used inside tmux next to a coding agent.
pubDate: 2026-11-08
tags: [neovim, tmux, lsp, dotnet, typescript, go, python, lua, opencode]
testedOn: [Fedora 45, Neovim 0.12.6, tmux 3.8, opencode 2.2.6, .NET SDK 10, Node.js 22, Go 1.27, Python 3.15]
series:
  name: Fedora 45 + Mango from scratch
  part: 3
---

This is the editor I work in every day: Neovim 0.12 inside tmux, set up for .NET, TypeScript and React, Go, Lua and Python. It has what you'd expect from an IDE: language servers, completion with snippets, formatting on save, linting, a file tree, and a fuzzy picker for files and text.

It builds on the Fedora 45 and Mango setup from parts 1 and 2, but nothing here depends on Mango; any Fedora 45 machine with a terminal works.

## Install the toolchains

Neovim 0.12 is in Fedora 45, and so is every compiler and runtime the language servers need:

```bash
sudo dnf install neovim tmux git gcc make unzip ripgrep fd-find tree-sitter-cli wl-clipboard \
  nodejs npm golang dotnet-sdk-10.0 python3 uv
```

| Package | Why |
| --- | --- |
| `gcc`, `make`, `tree-sitter-cli` | compile the treesitter parsers |
| `ripgrep`, `fd-find` | text search and file listing for the picker |
| `wl-clipboard` | copy and paste between Neovim and the rest of the desktop |
| `nodejs`, `npm` | the TypeScript, HTML, CSS, JSON and Tailwind servers, prettierd and eslint_d |
| `golang` | gopls, goimports, gofumpt and golangci-lint are built with it |
| `dotnet-sdk-10.0` | runs the Roslyn server and csharpier, and builds your C# projects |
| `python3`, `uv` | basedpyright and ruff, and your Python projects |
| `unzip` | mason unpacks several downloads with it |

The icons in the file tree, statusline and completion menu come from the symbols-only Nerd Font installed in part 2, next to Maple Mono.

The servers, formatters and linters themselves come from [mason.nvim](https://github.com/mason-org/mason.nvim), which installs them into Neovim's data directory, so they stay at the versions the config expects regardless of what Fedora ships.

## Layout

The config is two Stow packages in the same `~/dotfiles` repository as the rest of the series:

```txt
~/dotfiles
├── nvim/.config/nvim/
│   ├── init.lua
│   ├── .stylua.toml
│   ├── lazy-lock.json
│   └── lua/
│       ├── config/
│       │   ├── options.lua
│       │   ├── keymaps.lua
│       │   ├── autocmds.lua
│       │   └── lazy.lua
│       └── plugins/
│           ├── agent.lua
│           ├── colorscheme.lua
│           ├── completion.lua
│           ├── diff.lua
│           ├── explorer.lua
│           ├── format.lua
│           ├── git.lua
│           ├── lint.lua
│           ├── lsp.lua
│           ├── mini.lua
│           ├── tmux.lua
│           └── treesitter.lua
└── tmux/.config/tmux/tmux.conf
```

```bash
stow --no-folding -d ~/dotfiles -t ~ nvim tmux
```

`lua/config` holds plain Neovim settings and `lua/plugins` has one file per concern. `lazy-lock.json` records the exact commit of every plugin, so a new machine gets the same versions until you run an update. The whole tree, lockfile and `tmux.conf` included, is also [here](/files/neovim/nvim-config.tar.gz) as an archive. `.stylua.toml` sets two-space indentation, so formatting on save keeps the config's own style:

```toml title="~/dotfiles/nvim/.config/nvim/.stylua.toml"
column_width = 100
indent_type = "Spaces"
indent_width = 2
```

## The base: options and keymaps

`init.lua` sets the leader key first, because plugins read it when they define their mappings, and then loads the rest:

```lua title="~/dotfiles/nvim/.config/nvim/init.lua"
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
```

```lua title="~/dotfiles/nvim/.config/nvim/lua/config/options.lua"
local o = vim.opt

-- UI
o.number = true
o.relativenumber = true
o.cursorline = true
o.signcolumn = "yes" -- always reserve the column so diagnostics/git signs don't shift text
o.showmode = false -- mini.statusline shows the mode
o.scrolloff = 10
o.splitright = true
o.splitbelow = true
o.list = true
o.listchars = { tab = "  ", nbsp = "␣" } -- tabs look like spaces; mark only non-breaking spaces
o.winborder = "rounded" -- default border for floats (hover, signature help, diagnostics)
o.inccommand = "split" -- live preview of :s in a split
o.confirm = true -- ask instead of failing on :q with unsaved changes

-- Editing
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.breakindent = true
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.mouse = "a"

-- Faster CursorHold and a short wait before mini.clue shows its hints
o.updatetime = 250
o.timeoutlen = 300

-- Reload files changed on disk (by an agent in another tmux pane) when the
-- buffer has no unsaved edits. Already the default; explicit because the
-- checktime autocmd relies on it.
o.autoread = true

-- System clipboard through wl-clipboard. Scheduled because detecting the
-- clipboard provider costs startup time.
vim.schedule(function()
  o.clipboard = "unnamedplus"
end)

-- Diagnostics: sort by severity and show a float after ]d/[d jumps
vim.diagnostic.config({
  severity_sort = true,
  float = { source = "if_many" },
  virtual_text = { source = "if_many", spacing = 2 },
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
    end,
  },
})
```

`winborder` is new in 0.11 and puts a border on every floating window, hover and signature help included, without configuring each plugin. The `jump.on_jump` callback replaces the `float` option that 0.12 deprecates.

The keymaps are the ones I've carried across configs for years:

```lua title="~/dotfiles/nvim/.config/nvim/lua/config/keymaps.lua"
local map = vim.keymap.set

map("i", "jj", "<Esc>", { desc = "Exit insert mode" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map({ "n", "x" }, "<C-s>", "<cmd>write<CR><Esc>", { desc = "Save file" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "x", '"_x', { desc = "Delete char (no yank)" })

-- Keep the cursor centred while scrolling and searching
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centred)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centred)" })
map("n", "n", "nzzzv", { desc = "Next match (centred)" })
map("n", "N", "Nzzzv", { desc = "Previous match (centred)" })

-- Stay in visual mode after indenting; paste over a selection without yanking it
map("x", "<", "<gv", { desc = "Indent left" })
map("x", ">", ">gv", { desc = "Indent right" })
map("x", "p", "P", { desc = "Paste (keep register)" })

-- Buffers and splits
map("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "<leader>v", "<C-w>v", { desc = "Split vertically" })
map("n", "<leader>h", "<C-w>s", { desc = "Split horizontally" })

map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
```

`<C-s>` saves only in normal and visual mode; in insert mode it stays Neovim's default, which shows the signature of the function you're calling. `]d` and `[d` for diagnostics are built in since 0.10, so they're not here.

```lua title="~/dotfiles/nvim/.config/nvim/lua/config/autocmds.lua"
local augroup = vim.api.nvim_create_augroup("config", { clear = true })

-- Briefly highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.hl.on_yank()
  end,
})

-- 'autoread' only acts when timestamps are checked. Neovim does that when it
-- regains focus; this also checks when idle or switching buffers, so edits by
-- any agent show up while Neovim keeps the focus.
vim.api.nvim_create_autocmd({ "CursorHold", "BufEnter" }, {
  group = augroup,
  callback = function()
    if vim.fn.getcmdwintype() == "" then -- :checktime is not allowed in the cmdline window
      vim.cmd.checktime()
    end
  end,
})
```

## Plugins with lazy.nvim

[lazy.nvim](https://lazy.folke.io/) installs itself on the first start and then loads every file in `lua/plugins`:

```lua title="~/dotfiles/nvim/.config/nvim/lua/config/lazy.lua"
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out } }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "vague" } },
  rocks = { enabled = false }, -- no plugin here needs luarocks
  change_detection = { notify = false },
})
```

`:Lazy` opens its window, `:Lazy update` updates everything and rewrites `lazy-lock.json`, and `:Lazy restore` goes back to the versions in the lockfile.

## Colorscheme

[vague.nvim](https://github.com/vague-theme/vague.nvim) is a low-contrast dark theme. It loads before every other UI plugin so they pick up its colors:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/colorscheme.lua"
return {
  "vague-theme/vague.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("vague").setup({})
    vim.cmd.colorscheme("vague")
  end,
}
```

## Language servers

Since 0.11, Neovim configures and starts language servers by itself: `vim.lsp.config` describes a server and `vim.lsp.enable` turns it on for its filetypes. Two plugins fill the gaps. [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) is now only a collection of server definitions (the command, the filetypes, how to find the project root) that `vim.lsp.enable` reads by name. mason.nvim installs the binaries and puts them on Neovim's `PATH`.

| Language | Server | Notes |
| --- | --- | --- |
| C# | Roslyn, through [roslyn.nvim](https://github.com/seblyng/roslyn.nvim) | the same server as the VS Code C# extension |
| TypeScript, JavaScript, React | vtsls | wraps the TypeScript service VS Code uses |
| HTML, CSS, JSON, Tailwind | html, cssls, jsonls, tailwindcss | Tailwind only attaches in projects that use it |
| Go | gopls | |
| Lua | lua_ls, with [lazydev.nvim](https://github.com/folke/lazydev.nvim) | lazydev teaches it the Neovim API and your plugins |
| Python | basedpyright and ruff | basedpyright for types and completion, ruff for lint diagnostics and fixes |

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/lsp.lua"
-- Servers enabled through vim.lsp.enable (nvim-lspconfig names).
-- C# (roslyn) is started by roslyn.nvim instead.
local servers = {
  "vtsls", "html", "cssls", "jsonls", "tailwindcss",
  "gopls", "lua_ls", "basedpyright", "ruff",
}

-- Everything mason installs (mason package names).
local tools = {
  -- language servers
  "roslyn", "vtsls", "html-lsp", "css-lsp", "json-lsp", "tailwindcss-language-server",
  "gopls", "lua-language-server", "basedpyright", "ruff",
  -- formatters (conform.nvim)
  "csharpier", "prettierd", "goimports", "gofumpt", "stylua",
  -- linters (nvim-lint)
  "eslint_d", "golangci-lint",
}

return {
  {
    "mason-org/mason.nvim",
    lazy = false, -- puts mason's bin dir on PATH before any server starts
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry", -- provides `roslyn`
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)

      local registry = require("mason-registry")
      local function install_missing()
        local missing = vim.tbl_filter(function(name)
          return not registry.is_installed(name)
        end, tools)
        if #missing > 0 then
          vim.cmd.MasonInstall({ "--quiet", unpack(missing) })
        end
      end
      vim.api.nvim_create_user_command("MasonInstallAll", install_missing, {
        desc = "Install every tool listed in plugins/lsp.lua",
      })
      vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = install_missing })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = { "mason-org/mason.nvim" },
    config = function()
      -- ruff and basedpyright both serve Python; basedpyright owns hover and imports.
      vim.lsp.config("basedpyright", {
        settings = { basedpyright = { disableOrganizeImports = true } },
      })
      vim.lsp.enable(servers)

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
        callback = function(args)
          local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
          if client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end

          local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
          end
          local pick_lsp = function(scope)
            return function()
              require("mini.extra").pickers.lsp({ scope = scope })
            end
          end
          map("gd", pick_lsp("definition"), "Goto definition")
          map("gD", vim.lsp.buf.declaration, "Goto declaration")
          map("gR", pick_lsp("references"), "References (picker)")
          map("<leader>ss", pick_lsp("document_symbol"), "Document symbols")
          map("<leader>sS", pick_lsp("workspace_symbol"), "Workspace symbols")
        end,
      })
    end,
  },

  {
    "seblyng/roslyn.nvim",
    ft = { "cs", "razor" },
    dependencies = { "mason-org/mason.nvim" },
    opts = {},
  },

  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
}
```

The Roslyn server isn't in mason's main registry; the [Crashdummyy registry](https://github.com/Crashdummyy/mason-registry) packages it from the same builds the VS Code extension downloads, which is why `registries` lists both. roslyn.nvim finds the `.sln` or `.csproj` above the file you open and starts the server for that solution. The first start in a project takes a while, because Roslyn loads and analyzes the whole solution.

On Linux, Neovim doesn't offer file watching to language servers, so Roslyn watches the solution itself, and each folder tree it watches costs one inotify instance. The kernel allows 128 instances per user, shared by every program in the session. A five-project solution used 20 of them in my tests and a 40-project one 48. When Roslyn runs out, the projects it hadn't loaded yet fail with `The configured user limit (128) on the number of inotify instances has been reached` in `:LspLog`, and completion and diagnostics stop working in them. Raise the limit once:

```bash
echo 'fs.inotify.max_user_instances = 1024' | sudo tee /etc/sysctl.d/90-inotify.conf
sudo sysctl --system
```

`MasonInstallAll` installs everything in `tools` that's missing, and the `VimEnter` autocmd runs it on every start, so a new machine fills itself in the first time you open Neovim. To do it in one go from a shell, which blocks until every download has finished:

```bash
nvim --headless +MasonInstallAll +qa
```

Neovim already maps the common LSP actions: `K` for hover, `grn` to rename, `gra` for code actions, `grr` for references, `gri` for implementations, `gO` for the document outline and, in insert mode, `<C-s>` for signature help. The `LspAttach` callback adds `gd`, references and symbol search through the picker, so long result lists can be filtered.

## Completion and snippets

[blink.cmp](https://cmp.saghen.dev/) shows completions from the language server, file paths, snippets and words in open buffers. Its release builds include a fuzzy matcher compiled in Rust, which is why the spec pins `version = "1.*"`:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/completion.lua"
return {
  "saghen/blink.cmp",
  version = "1.*",
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    keymap = { preset = "default" }, -- <C-y> accept, <C-n>/<C-p> select, <C-space> open, <C-e> hide
    appearance = { nerd_font_variant = "mono" },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 300 },
    },
    signature = { enabled = true },
    snippets = { preset = "default" }, -- Neovim's built-in vim.snippet
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      per_filetype = {
        lua = { inherit_defaults = true, "lazydev" },
      },
      providers = {
        lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
      },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
}
```

Snippets come from [friendly-snippets](https://github.com/rafamadriz/friendly-snippets), a collection in the VS Code format covering all the languages here, and expand through Neovim's own `vim.snippet`, so there's no separate snippet engine. `<Tab>` and `<S-Tab>` jump between the snippet's fields. blink also registers its capabilities with every language server by itself, so the LSP file doesn't mention it.

## Formatting on save

[conform.nvim](https://github.com/stevearc/conform.nvim) runs a command-line formatter on save and falls back to the language server's formatter when a filetype has none:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/format.lua"
local prettier = { "prettierd" }

return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "x" },
      desc = "Format buffer/selection",
    },
  },
  opts = {
    formatters_by_ft = {
      cs = { "csharpier" },
      javascript = prettier,
      javascriptreact = prettier,
      typescript = prettier,
      typescriptreact = prettier,
      json = prettier,
      jsonc = prettier,
      css = prettier,
      html = prettier,
      yaml = prettier,
      markdown = prettier,
      go = { "goimports", "gofumpt" },
      lua = { "stylua" },
      python = { "ruff_organize_imports", "ruff_format" },
    },
    format_on_save = function(bufnr)
      -- csharpier starts a .NET process; give it more time than the others.
      local timeout = vim.bo[bufnr].filetype == "cs" and 3000 or 1000
      return { timeout_ms = timeout, lsp_format = "fallback" }
    end,
  },
}
```

prettierd is prettier kept running in the background, which saves the Node start-up on every save. Go gets its imports sorted and then gofumpt's stricter formatting; Python gets its imports sorted and formatted by ruff. `:ConformInfo` shows which formatter applies to the current buffer and why one might be failing.

## Linting

Most linting here comes from language servers: ruff for Python, Roslyn's analyzers for C#, gopls's checks for Go. [nvim-lint](https://github.com/mfussenegger/nvim-lint) covers the two linters that aren't servers, ESLint and golangci-lint:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/lint.lua"
local linters_by_ft = {
  javascript = { "eslint_d" },
  javascriptreact = { "eslint_d" },
  typescript = { "eslint_d" },
  typescriptreact = { "eslint_d" },
  go = { "golangcilint" },
}

-- eslint_d reports an error in projects without an ESLint config; only run it where one exists.
local eslint_configs = {
  "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs",
  "eslint.config.ts", "eslint.config.mts", "eslint.config.cts",
}

return {
  "mfussenegger/nvim-lint",
  ft = vim.tbl_keys(linters_by_ft),
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = linters_by_ft

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("lint", { clear = true }),
      callback = function(args)
        local names = linters_by_ft[vim.bo[args.buf].filetype] or {}
        if not vim.fs.root(args.buf, eslint_configs) then
          names = vim.tbl_filter(function(name)
            return name ~= "eslint_d"
          end, names)
        end
        lint.try_lint(names)
      end,
    })
  end,
}
```

ESLint uses the project's own config and plugins, so it only runs in projects that have a flat config file; without one, every save would show a "no configuration found" error instead.

## Treesitter and HTML/JSX tags

Treesitter parses each file into a syntax tree, which gives better highlighting and indentation than regular expressions. The [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/tree/main) plugin was rewritten on its `main` branch: it now only installs parsers and their queries, and highlighting is Neovim's built-in `vim.treesitter.start()`, which you turn on per filetype:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/treesitter.lua"
local parsers = {
  "c_sharp", "typescript", "tsx", "javascript", "go", "lua", "python",
  "html", "css", "json", "yaml", "bash", "vim", "vimdoc", "query",
  "markdown", "markdown_inline",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- Install missing parsers once the UI is up (a no-op when all are installed).
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          require("nvim-treesitter").install(parsers)
        end,
      })

      -- Parser names are not filetype names (c_sharp -> cs, tsx -> typescriptreact, ...).
      local filetypes = {}
      for _, lang in ipairs(parsers) do
        vim.list_extend(filetypes, vim.treesitter.language.get_filetypes(lang))
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter", { clear = true }),
        pattern = filetypes,
        callback = function(args)
          -- pcall: the parser may still be compiling on the very first start.
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = false,
      },
    },
  },
}
```

The parsers are compiled on your machine, which is what `tree-sitter-cli` and `gcc` are for. The old `ensure_installed` option is gone; `install()` replaces it and does nothing for parsers that are already there.

[nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag) uses the tree to edit tags: typing `<div>` in an HTML, JSX or TSX file adds `</div>`, and renaming the opening tag renames the closing one as you type.

## mini.nvim: editing, picker, statusline, start screen

[mini.nvim](https://github.com/nvim-mini/mini.nvim) is a collection of independent modules in one plugin. I use eight of them, plus mini.extra for more pickers:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/mini.lua"
return {
  "nvim-mini/mini.nvim",
  version = false,
  lazy = false,
  priority = 900, -- after the colorscheme, before neo-tree asks for icons
  config = function()
    -- Text editing
    require("mini.ai").setup() -- more a/i textobjects: f(unction call), a(rgument), q(uote), ...
    require("mini.pairs").setup() -- auto-close brackets and quotes
    require("mini.surround").setup() -- sa/sd/sr/sf/sh: add/delete/replace/find/highlight surrounding

    -- UI
    require("mini.icons").setup()
    MiniIcons.mock_nvim_web_devicons() -- neo-tree asks nvim-web-devicons for icons
    require("mini.statusline").setup()

    -- Picker
    require("mini.pick").setup()
    require("mini.extra").setup()
    vim.ui.select = MiniPick.ui_select -- code actions and other menus use the picker

    local starter = require("mini.starter")
    starter.setup({
      items = {
        starter.sections.pick(),
        starter.sections.recent_files(5, false, false),
        starter.sections.builtin_actions(),
      },
    })

    local pick, extra = MiniPick.builtin, MiniExtra.pickers
    local function map(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { desc = desc })
    end
    map("<leader>sf", pick.files, "Search files")
    map("<leader>sg", pick.grep_live, "Search by grep (live)")
    map("<leader>sw", function()
      pick.grep({ pattern = vim.fn.expand("<cword>") })
    end, "Search word under cursor")
    map("<leader><leader>", pick.buffers, "Search buffers")
    map("<leader>sh", pick.help, "Search help")
    map("<leader>sd", extra.diagnostic, "Search diagnostics")
    map("<leader>sr", pick.resume, "Search resume")
    map("<leader>s.", extra.oldfiles, "Search recent files")
    map("<leader>sk", extra.keymaps, "Search keymaps")

    -- Key hints: after 'timeoutlen' on a prefix, show what can follow.
    local clue = require("mini.clue")
    clue.setup({
      triggers = {
        { mode = { "n", "x" }, keys = "<Leader>" },
        { mode = "n", keys = "[" },
        { mode = "n", keys = "]" },
        { mode = "i", keys = "<C-x>" },
        { mode = { "n", "x" }, keys = "g" },
        { mode = { "n", "x" }, keys = "'" },
        { mode = { "n", "x" }, keys = "`" },
        { mode = { "n", "x" }, keys = '"' },
        { mode = { "i", "c" }, keys = "<C-r>" },
        { mode = "n", keys = "<C-w>" },
        { mode = { "n", "x" }, keys = "z" },
      },
      clues = {
        { mode = "n", keys = "<Leader>s", desc = "+Search" },
        { mode = "n", keys = "<Leader>g", desc = "+Git" },
        { mode = { "n", "x" }, keys = "<Leader>a", desc = "+Agent (opencode)" },
        { mode = { "n", "x" }, keys = "<Leader>d", desc = "+Diff review" },
        clue.gen_clues.square_brackets(),
        clue.gen_clues.builtin_completion(),
        clue.gen_clues.g(),
        clue.gen_clues.marks(),
        clue.gen_clues.registers(),
        clue.gen_clues.windows(),
        clue.gen_clues.z(),
      },
    })
  end,
}
```

- **mini.ai** adds text objects: `cif` changes the inside of a function call's parentheses, `daa` deletes an argument with its comma, `ciq` changes inside the nearest quotes of any kind.
- **mini.pairs** closes brackets and quotes as you type them.
- **mini.surround** works on surrounding characters: `saiw"` wraps a word in quotes, `sd(` deletes the parentheses around the cursor, `sr'"` replaces single quotes with double.
- **mini.icons** provides the file icons. `mock_nvim_web_devicons()` makes it answer for nvim-web-devicons, which neo-tree expects, so there's only one icon plugin.
- **mini.statusline** shows the mode, the git branch and diff counts from gitsigns, the diagnostics, the file and the cursor position.
- **mini.pick** is the picker, and mini.extra adds pickers for diagnostics, recent files, keymaps and LSP results. Files come from `fd` and text search from `rg`, so `.gitignore` is respected. Type to filter, `<C-n>`/`<C-p>` to move, Enter to open, `<C-s>` and `<C-v>` to open in a split.
- **mini.starter** is the start screen when Neovim opens without a file: recent files and the picker.
- **mini.clue** shows, after you press a prefix like `<leader>` or `g` and wait, which keys can follow. It replaces which-key without adding another plugin.

## File explorer

[neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) is the side tree, with git status per file:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/explorer.lua"
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  lazy = false, -- neo-tree defers its own loading; this lets it open on `nvim <dir>`
  keys = {
    { "<leader>e", "<cmd>Neotree toggle reveal<CR>", desc = "Explorer (reveal file)" },
  },
  opts = {
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
    },
  },
}
```

`<leader>e` opens it with the current file selected. Inside the tree, `a` adds a file (end the name with `/` for a directory), `r` renames, `d` deletes, `m` moves, `H` shows hidden files and `?` lists every key. The file watcher keeps the tree up to date when files change outside Neovim.

## Git signs

[gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) marks added, changed and removed lines next to the line numbers and works on hunks:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/git.lua"
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(bufnr)
      local gs = require("gitsigns")
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end
      map("n", "]h", function()
        gs.nav_hunk("next")
      end, "Next hunk")
      map("n", "[h", function()
        gs.nav_hunk("prev")
      end, "Previous hunk")
      map("n", "<leader>gs", gs.stage_hunk, "Stage/unstage hunk")
      map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
      map("n", "<leader>gp", gs.preview_hunk_inline, "Preview hunk")
      map("n", "<leader>gb", gs.blame_line, "Blame line")
    end,
  },
}
```

## tmux

I run Neovim inside tmux: one session per project, with windows for the editor, a shell, and the dev server or test runner, which survive closing the terminal. tmux is in the toolchain install above; its config lives in `~/.config/tmux/tmux.conf`, which tmux 3.8 reads directly:

```bash title="~/dotfiles/tmux/.config/tmux/tmux.conf"
# Prefix: C-a (home row). C-b is page-up in Neovim and backward-char in the
# shell; C-a's clash (shell line-start, Neovim increment) is covered by
# pressing it twice.
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Terminal: tmux-256color inside, 24-bit colour and extended keys (so <Tab>
# and <C-i> stay distinct in Neovim) when the outer terminal is foot.
set -g default-terminal "tmux-256color"
set -as terminal-features ",foot*:RGB:extkeys"
set -s extended-keys on
set -s extended-keys-format csi-u

set -s escape-time 10   # don't delay <Esc> in Neovim
set -g focus-events on  # forward FocusGained/FocusLost to Neovim ('autoread' checks)
set -g mouse on

# Numbering from 1, no gaps after closing a window
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Copy mode: vi keys, y/mouse-drag copy to the Wayland clipboard
setw -g mode-keys vi
set -s copy-command "wl-copy"
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi C-v send -X rectangle-toggle
bind -T copy-mode-vi y send -X copy-pipe-and-cancel

# Splits and new windows open in the current pane's directory.
# prefix v / prefix h mirror Neovim's <leader>v / <leader>h.
bind v split-window -h -c "#{pane_current_path}"
bind h split-window -v -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"
bind '"' split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"

# prefix o: opencode in a split to the right, in the current pane's directory
# (replaces the default "next pane"; C-h/j/k/l already move between panes).
bind o split-window -h -c "#{pane_current_path}" opencode

bind r source-file ~/.config/tmux/tmux.conf \; display "tmux.conf reloaded"

# Smart pane switching with awareness of Vim splits.
# See: https://github.com/christoomey/vim-tmux-navigator
vim_pattern='(\S+/)?g?\.?(view|l?n?vim?x?|fzf)(diff)?(-wrapped)?'
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +${vim_pattern}$'"
bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
bind-key -n 'C-\' if-shell "$is_vim" 'send-keys C-\\' 'select-pane -l'

bind-key -T copy-mode-vi 'C-h' select-pane -L
bind-key -T copy-mode-vi 'C-j' select-pane -D
bind-key -T copy-mode-vi 'C-k' select-pane -U
bind-key -T copy-mode-vi 'C-l' select-pane -R
bind-key -T copy-mode-vi 'C-\' select-pane -l

# C-l is taken by the navigator; prefix C-l clears the screen instead.
bind C-l send-keys 'C-l'

# Status line (Paradise palette) at the top, away from Neovim's statusline.
set -g status-position top
set -g status-style "bg=#151515,fg=#a39d9d"
set -g status-left "#[bg=#8da3b9,fg=#151515,bold] #S #[default] "
set -g status-left-length 30
set -g status-right "#{?client_prefix,#[bg=#d9bc8c fg=#151515 bold] PREFIX #[default] ,}#[fg=#a39d9d]#h "
setw -g window-status-format " #I #W "
setw -g window-status-current-format "#[bg=#424242,fg=#e8e3e3,bold] #I #W#{?window_zoomed_flag, [Z],} "
setw -g window-status-separator ""
set -g pane-border-style "fg=#424242"
set -g pane-active-border-style "fg=#8da3b9"
set -g message-style "bg=#151515,fg=#d9bc8c"
setw -g mode-style "bg=#424242,fg=#e8e3e3"
```

A few of these settings exist only for Neovim:

- `escape-time 10`: by default tmux waits half a second after `<Esc>` to see whether it starts a key sequence, which makes leaving insert mode feel slow.
- `RGB` in `terminal-features` passes 24-bit color through, so vague.nvim looks the same inside tmux as outside. `focus-events` lets Neovim notice when you switch back to it, to reload files changed outside.
- `extended-keys` keeps `<Tab>` and `<C-i>` apart. Without it they reach Neovim as the same key.
- The `is_vim` block is the tmux half of [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator): it checks whether the current pane is running Neovim and either passes `C-h/j/k/l` to it or moves to the neighbouring pane.

The Neovim half is a plugin with the same four keys. At the edge of Neovim's splits, it hands the movement back to tmux:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/tmux.lua"
return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
    "TmuxNavigatorProcessList",
  },
  keys = {
    { "<C-h>", "<cmd><C-U>TmuxNavigateLeft<CR>", desc = "Window/pane left" },
    { "<C-j>", "<cmd><C-U>TmuxNavigateDown<CR>", desc = "Window/pane down" },
    { "<C-k>", "<cmd><C-U>TmuxNavigateUp<CR>", desc = "Window/pane up" },
    { "<C-l>", "<cmd><C-U>TmuxNavigateRight<CR>", desc = "Window/pane right" },
    { "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<CR>", desc = "Previous window/pane" },
  },
}
```

So `C-h/j/k/l` moves between Neovim splits and tmux panes as if they were one grid, and `C-a v` / `C-a h` split the tmux window the same way `<leader>v` / `<leader>h` split Neovim. `C-a d` detaches; `tmux attach` brings the session back with everything still running.

## Working with a coding agent

Most days a coding agent runs in a tmux pane next to Neovim. It edits files in the project; I read what it changed, keep the parts I want and throw away the rest, and send it more context from the editor. Two plugins make that comfortable: [codediff.nvim](https://github.com/esmuellert/codediff.nvim) for reviewing changes, which works with any agent because it only reads git, and [opencode.nvim](https://github.com/nickjvandyke/opencode.nvim) for talking to [opencode](https://opencode.ai/) from Neovim.

### opencode

Terra has two opencode packages that both install `/usr/bin/opencode`: `opencode` is the older 1.x line, and `opencode-cli` is version 2, which opencode.nvim needs:

```bash
sudo dnf install opencode-cli
```

`prefix o` in the tmux config above opens it in a split to the right, in the current directory. Pick a model and sign in to a provider inside opencode the first time; which one is up to you. The opencode TUI needs one message in the project before Neovim can send anything to it, because the plugin attaches to an existing session.

All opencode 2 clients share one background service per user, which writes its address to `~/.local/state/opencode/service.json`. opencode.nvim reads that file, so it finds the opencode running in the other pane without a port or any configuration:

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/agent.lua"
local function oc(fn, ...)
  local args = { ... }
  return function()
    return require("opencode")[fn](unpack(args))
  end
end

local nx = { "n", "x" }

return {
  "nickjvandyke/opencode.nvim",
  -- main branch targets opencode 2; pinned by lazy-lock.json.
  keys = {
    { "<leader>aa", oc("ask", "@this: "), mode = nx, desc = "Ask about @this (cursor/selection)" },
    { "<leader>ab", oc("ask", "@buffer: "), desc = "Ask about @buffer" },
    { "<leader>ad", oc("ask", "@diagnostics: "), mode = nx, desc = "Ask about @diagnostics" },
    { "<leader>as", oc("select"), mode = nx, desc = "Select prompt/command" },
    -- Operator: <leader>ao{motion} (or a visual selection) appends the range to
    -- opencode's prompt without asking; dot-repeatable.
    { "<leader>ao", oc("operator", "@this"), mode = nx, expr = true, desc = "Send range (motion)" },
    {
      "<leader>al",
      function()
        return require("opencode").operator("@this") .. "_"
      end,
      expr = true,
      desc = "Send line",
    },
  },
  init = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      server = {
        -- Called when no opencode is running: open it in a tmux split next to
        -- Neovim (focus stays here), the same as tmux prefix o.
        start = function()
          if vim.env.TMUX then
            vim.system({ "tmux", "split-window", "-h", "-d", "-c", vim.fn.getcwd(), "opencode" })
          else
            vim.cmd("vsplit term://opencode | wincmd p")
          end
        end,
      },
    }
  end,
}
```

`<leader>aa` asks a question about the code under the cursor or the selection: the prompt starts with a reference like `src/app.ts:L12-L20` that opencode resolves to the code. `<leader>ab` does the same for the whole buffer, `<leader>ad` for the diagnostics, and `<leader>ao` adds a range to opencode's prompt without asking anything yet, so you can collect several pieces before writing the question. When opencode wants to edit a file, the plugin shows the proposed change as a diff in Neovim; `da` accepts it and `dr` rejects it. Files opencode changes reload by themselves, and the `checktime` autocmd above does the same for any other agent.

opencode.nvim can use snacks.nvim for nicer input boxes, but doesn't need it: without snacks it asks through Neovim's own input and picks through `vim.ui.select`, which mini.pick provides.

### Reviewing changes with codediff

codediff opens a tab with a VS Code style diff and a tree of every changed file, and keeps both up to date while the agent works: a file the agent creates appears in the tree within a few seconds.

```lua title="~/dotfiles/nvim/.config/nvim/lua/plugins/diff.lua"
-- In the view: ]c/[c hunks, ]f/[f files, - stage/unstage file, S/U stage/unstage
-- all, X discard file, t inline/side-by-side, gf open file, q close, g? help.
return {
  "esmuellert/codediff.nvim",
  cmd = "CodeDiff",
  keys = {
    { "<leader>dd", "<cmd>CodeDiff<CR>", desc = "Review working tree changes" },
    { "<leader>ds", "<cmd>CodeDiff --staged<CR>", desc = "Review staged changes" },
    { "<leader>df", "<cmd>CodeDiff file HEAD<CR>", desc = "Diff file vs HEAD" },
    { "<leader>dh", "<cmd>CodeDiff history %<CR>", desc = "File history" },
    { "<leader>dh", ":CodeDiff history<CR>", mode = "x", desc = "Selected lines history" },
    { "<leader>dH", "<cmd>CodeDiff history<CR>", desc = "Repo history" },
  },
  opts = {
    keymaps = {
      view = {
        -- Defaults are <leader>hs/hu/hr, which would shadow <leader>h (split)
        -- inside the diff tab; reuse gitsigns' <leader>g hunk keys instead.
        stage_hunk = "<leader>gs",
        unstage_hunk = "<leader>gu",
        discard_hunk = "<leader>gr",
      },
    },
  },
}
```

codediff computes diffs with a native library (`libvscode_diff`) that it downloads into its plugin folder the first time you open a diff, or when you run `:CodeDiff install`, so there's nothing to build. Inside the review tab its own keys take over a few of mine on those buffers (`<leader>e`, `q`, `t`, `-`); they come back when the tab closes.

My review loop after the agent says it's done:

1. `<leader>dd` opens the review tab with every changed file.
2. `]f` / `[f` move between files and `]c` / `[c` between hunks. `t` switches between side-by-side and inline.
3. `<leader>gs` stages a hunk I want to keep and `<leader>gr` discards one I don't; `-` stages a whole file and `X` discards it.
4. `q` closes the tab, and I commit what's staged or ask the agent to redo the rest.

`<leader>dh` shows the history of the current file, or of the selected lines in visual mode, which is the quickest way to see when and why a block changed. All of this reads git only, so it works the same with omp, Claude Code or any other agent running in the other pane.

## First start

Open Neovim once and let it fill in:

```bash
nvim
```

lazy.nvim clones every plugin at the commit in `lazy-lock.json`, treesitter compiles the parsers in the background, and mason starts downloading the servers, formatters and linters. `:Lazy`, `:Mason` and `:messages` show their progress. When they're done, `:checkhealth` reports anything missing; the sections worth reading are `vim.lsp`, `mason`, `nvim-treesitter` and `blink.cmp`.

Open a file of each language and run `:checkhealth vim.lsp` to see which servers attached to it. In a C# project, the first file you open starts Roslyn, which needs some time to load the solution before completion and diagnostics appear.

## Keymaps

Leader is Space. Besides the editor keymaps at the top:

| Keys | Action |
| --- | --- |
| `<leader>sf` | find files |
| `<leader>sg` | live grep |
| `<leader>sw` | grep the word under the cursor |
| `<leader><leader>` | open buffers |
| `<leader>s.` | recent files |
| `<leader>sd` | diagnostics |
| `<leader>sh` | help |
| `<leader>sk` | keymaps |
| `<leader>sr` | resume the last picker |
| `<leader>ss` / `<leader>sS` | symbols in the file / the workspace |
| `gd` / `gD` | go to definition / declaration |
| `gR` | references in the picker |
| `K`, `grn`, `gra`, `grr`, `gri` | hover, rename, code action, references, implementations (Neovim defaults) |
| `<leader>f` | format the buffer or selection |
| `<leader>e` | file tree |
| `]h` / `[h` | next / previous git hunk |
| `<leader>gs` / `gr` / `gp` / `gb` | stage, reset, preview hunk; blame line |
| `C-h/j/k/l` | move between splits and tmux panes |
| `<C-y>`, `<C-n>`/`<C-p>`, `<C-space>` | accept, select, open completion |
| `<leader>aa` / `ab` / `ad` | ask opencode about the cursor or selection / the buffer / the diagnostics |
| `<leader>ao{motion}`, `<leader>al` | add a range / the current line to opencode's prompt |
| `<leader>as` | pick an opencode prompt or command |
| `<leader>dd` / `ds` / `df` | review working tree / staged changes / current file vs HEAD |
| `<leader>dh` / `dH` | history of the file (or selected lines) / the repo |

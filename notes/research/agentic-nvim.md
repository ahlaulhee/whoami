# Agent workflow in Neovim: opencode in tmux + opencode.nvim + codediff.nvim

Checked on 2026-11-08 in the WSL distro `FedoraLinux-45`: Neovim 0.12.6, tmux 3.8, OpenCode v2.2.6 (Terra `opencode-cli`). This builds on [neovim-0.12.md](neovim-0.12.md).

Setup: OpenCode's TUI runs in a tmux pane next to Neovim (tmux `prefix o`). **opencode.nvim** sends editor context (cursor, selection, buffer, diagnostics) to it, and **codediff.nvim** shows the working-tree changes in a live diff tab where you can stage or discard them. Nothing else is added (no Copilot, no snacks.nvim).

Files:
- `C:/dev/scratch-agentic/nvim/`: the full `~/.config/nvim` tree. New files: `lua/plugins/agent.lua` and `lua/plugins/diff.lua`. Changed: `lua/plugins/mini.lua` (clue groups), `lua/config/options.lua` (`autoread`), `lua/config/autocmds.lua` (checktime), `lazy-lock.json`.
- `C:/dev/scratch-agentic/tmux.conf`: `~/.config/tmux/tmux.conf` with the new `prefix o` binding.

## Sources

- OpenCode install, v1 vs v2: https://opencode.ai/docs/ and https://opencode.ai/download (v2 is current: `curl -fsSL https://opencode.ai/v2/install | bash` or `npm install -g @opencode/cli`)
- Shared background service, `--standalone`/`--server`: https://opencode.ai/docs/cli/
- `opencode serve --port`: https://opencode.ai/docs/cli/commands/
- Config paths: https://opencode.ai/docs/config/ (server/project `opencode.json(c)`), https://opencode.ai/docs/cli/config/ (TUI `cli.json`)
- V1 to V2 migration (same config locations, v1 and v2 can't be installed side by side): https://opencode.ai/docs/migrate-v1/
- opencode.nvim: https://github.com/nickjvandyke/opencode.nvim (README; `lua/opencode/config.lua`, `lua/opencode/server/discovery/init.lua`, `lua/opencode/health.lua`, `plugin/events/reload.lua` at commit `4851ae5`)
- codediff.nvim: https://github.com/esmuellert/codediff.nvim (README; `lua/codediff/core/installer/*.lua`, `lua/codediff/ui/refresh/init.lua` at tag v4.0.6)
- Neovim checks file timestamps on FocusGained (at most once every 2 s): `do_autocmd_focusgained()` in https://github.com/neovim/neovim/blob/release-0.12/src/nvim/autocmd.c

## OpenCode on Fedora 45

`dnf repoquery 'opencode*'` (Terra) lists two different products:

| Package | Version | What it is |
|---|---|---|
| `opencode` | 1.18.18-1.fc45 | OpenCode **v1** |
| `opencode-cli` | 2.2.6-1.fc45 | OpenCode **v2** (the current release, same version as npm `@opencode/cli` 2.2.6) |

On npm, `opencode-ai` is still v1 (`latest` = 1.19.5); v2 is `@opencode/cli`. Both versions install the `opencode` command and can't be installed side by side.

opencode.nvim's `main` branch targets v2 (its release tags target v1), and its health check warns below 2.0. So I installed v2 from Terra, which dnf keeps updated:

```sh
sudo dnf install opencode-cli     # Terra; installs /usr/bin/opencode
opencode --version                # opencode v2.2.6
```

Installed by this work: `opencode-cli-2.2.6-1.fc45.x86_64` and `opencode-cli-bash-completion-2.2.6-1.fc45.noarch`. That is the only system package. codediff.nvim also downloaded two files into its plugin directory (see below). The official alternative is `curl -fsSL https://opencode.ai/v2/install | bash`. [INFERENCE] With the RPM, update through dnf, not `opencode upgrade`.

Config paths (v2, same as v1):
- server/agent settings: `~/.config/opencode/opencode.json(c)`, plus `<project>/opencode.json(c)` or `<project>/.opencode/opencode.json(c)`
- TUI settings: `~/.config/opencode/cli.json`
- the background service registers itself in `~/.local/state/opencode/service.json` (`{"id","version","url","pid","password"}`, mode 0600)

### How opencode.nvim finds an OpenCode running in another pane

In v2, every `opencode` client starts or reuses **one shared background service per user**. The service listens on a random 127.0.0.1 port, uses basic auth (user `opencode` plus a generated password) and writes its URL and password to `service.json`. To find a server, opencode.nvim tries in order: the server it is already connected to, `opts.server.url`, the `service*.json` registrations (newest first), and finally `opts.server.start()`, after which it polls for 5 s. So **no `--port` is needed.** `opencode serve --port N` plus `server.url` is only for a fixed or remote server.

Prompts go to "the most recently updated root session for Neovim's cwd" (`GET /api/session?directory=<cwd>`). Start Neovim and OpenCode in the same directory, and send at least one message from the TUI first. Until then, sends fail with "No OpenCode session found for `<cwd>`. Start one in the TUI."

Dependencies: `curl` and `opencode` on PATH. snacks.nvim is **optional**: it only enhances `ask()` (input with LSP completion) and `select()` (picker with preview). Without it, `ask()` uses `vim.ui.input` (with `<Tab>` completion of `@contexts`) and `select()` uses `vim.ui.select`, which this config routes to mini.pick.

### autoread / checktime

- opencode.nvim sets `autoread` if you haven't, and runs `:checktime` on OpenCode's `file.edited` / `filesystem.changed` events. Buffers reload as OpenCode writes them, but only while a connection exists (any `<leader>a` key connects).
- Neovim runs `check_timestamps` on FocusGained, and tmux already has `focus-events on`, so switching back to the Neovim pane reloads files.
- Added for any agent (omp included), so changes also show up while Neovim keeps focus: `autocmd CursorHold,BufEnter * checktime` (skipped in the cmdline window), plus an explicit `o.autoread = true` (already the default).

## codediff.nvim

- lazy.nvim spec: `cmd = "CodeDiff"` plus keys. Without the plugin manager it needs no compiler or build step.
- Prebuilt library: on first use (or `:CodeDiff install`, or `install!` to force), it downloads `libvscode_diff_linux_x64_<ver>.so` from the GitHub release into the **plugin root**: `~/.local/share/nvim/lazy/codediff.nvim/libvscode_diff_4.0.6.so`. It bundles `libgomp.so.1` only if the system has none (Fedora has it).
- Live updates: the explorer has `auto_refresh = true` by default. On first open it downloads `codediff-watcher_0.23.2` (a native file watcher) into the same directory and falls back to polling every 500 ms. Verified below: a file created while the view was open appeared within 3 s.
- Commands: `:CodeDiff` (working tree vs index/HEAD, explorer with Changes/Staged groups), `:CodeDiff --staged`, `:CodeDiff <rev>`, `:CodeDiff main...` (merge base), `:CodeDiff file HEAD`, `:CodeDiff history`, `:CodeDiff history %` (current file), `:'<,'>CodeDiff history` (selected lines), `:CodeDiff pr 512`, `:CodeDiff merge <file>`.
- Default keys inside the view:

| Key | Where | Action |
|---|---|---|
| `]c` / `[c` | diff | next / previous hunk |
| `]f` / `[f` | diff, explorer | next / previous file |
| `-` | diff, explorer | stage/unstage file |
| `S` / `U` | explorer | stage all / unstage all |
| `X` | explorer | discard (restore) file |
| `<CR>` | explorer, history | open file / expand commit |
| `R` | explorer, history | refresh |
| `gS` | diff | swap staged/unstaged view of the file |
| `do` / `dp` | diff | diffget / diffput |
| `ih` | diff | hunk text object |
| `t` | diff | side-by-side ⇄ inline |
| `gc` | diff | fold unchanged (compact) |
| `gf` | diff | open the file in the previous tab |
| `<leader>b` / `<leader>e` | view | toggle / focus explorer |
| `g?` | view | help |
| `q` | view | close the tab |

- Changed from the defaults: hunk stage/unstage/discard are `<leader>gs` / `<leader>gu` / `<leader>gr`, the same keys as gitsigns. The defaults (`<leader>hs/hu/hr`) would make `<leader>h` (split) wait for a second key inside the diff tab.

## Final setup

`lua/plugins/agent.lua` (opencode.nvim, loaded on its keys):
- `vim.g.opencode_opts.server.start`: inside tmux it runs `tmux split-window -h -d -c <cwd> opencode`, the same as `prefix o`, and focus stays in Neovim. Outside tmux it falls back to the plugin default, `vsplit term://opencode | wincmd p`.
- Everything else uses the defaults: contexts `@this @buffer @buffers @diagnostics @marks @quickfix @visible`; prompts explain/review/fix/implement/optimize/document/test/diagnostics; buffer reload and the edit-permission diff are on (OpenCode's edit permission requests open in a tab: `da` accept, `dr` reject, `dp`/`do` per hunk, `q` close).

`lua/plugins/diff.lua` (codediff.nvim, loaded by `cmd = "CodeDiff"` + keys): `opts.keymaps.view.{stage,unstage,discard}_hunk` only.

`lua/plugins/mini.lua`: clue groups `<Leader>a` "+Agent (opencode)" and `<Leader>d` "+Diff review" (normal and visual).

tmux.conf:

```tmux
bind o split-window -h -c "#{pane_current_path}" opencode
```

This replaces tmux's default `prefix o` (select next pane); `<C-h/j/k/l>` already handle pane movement. When OpenCode exits, the pane closes.

Typical loop: `prefix o`, then send a first message in the TUI (this creates the session). From Neovim, `<leader>aa` / `<leader>ao{motion}` add context; `<leader>dd` keeps a live review tab open while the agent works. In that tab, `-`/`<leader>gs` stage what you accept and `X`/`<leader>gr` discard the rest.

## Keymaps

| Keys | Mode | Action |
|---|---|---|
| `<leader>aa` | n, x | Ask OpenCode, input prefilled with `@this: ` (cursor position or selection) |
| `<leader>ab` | n | Ask, prefilled with `@buffer: ` |
| `<leader>ad` | n, x | Ask, prefilled with `@diagnostics: ` |
| `<leader>as` | n, x | Select a built-in prompt or server command (mini.pick) |
| `<leader>ao` | n, x | Operator: append `@this` for `{motion}` / selection to the session without asking; dot-repeatable |
| `<leader>al` | n | Same for the current line |
| `<leader>dd` | n | `:CodeDiff` (review working tree) |
| `<leader>ds` | n | `:CodeDiff --staged` |
| `<leader>df` | n | `:CodeDiff file HEAD` |
| `<leader>dh` | n | `:CodeDiff history %` (file history) |
| `<leader>dh` | x | `:'<,'>CodeDiff history` (history of the selected lines) |
| `<leader>dH` | n | `:CodeDiff history` (repo) |
| `prefix o` | tmux | OpenCode in a split to the right, in the pane's directory |

Collisions: before this change, `<leader>a` and `<leader>d` had no mappings (existing leader maps were `<leader>{e,f,h,q,v,x,<leader>}`, `s*`, `g*`). I left out the README's suggested `<C-a>` (tmux prefix, increment), `<C-x>` (decrement) and `go`/`goo` (built-in `go`). Inside a CodeDiff tab, its buffer-local maps take over on the diff buffers while the tab is open: `<leader>e` (neo-tree → focus the codediff explorer), `<leader>gs/gr` (gitsigns → codediff, same meaning), `gc` (the comment operator → compact mode), plus `q`, `t`, `-`.

## Verification (2026-11-08, exact output trimmed)

```text
$ nvim --headless '+Lazy! sync' +qa        → exit 0
lazy-lock.json:
  "codediff.nvim": { "branch": "main", "commit": "09d9ebef2cc5a5c04db7a349cd6c61bdf84ecc8e" },   (2026-09-15, tag v4.0.6)
  "opencode.nvim": { "branch": "main", "commit": "4851ae503585dc5142ad66a98e8952a74e1f7b3a" },   (2026-10-30)
$ stylua --check lua                       → STYLUA_OK
$ nvim --headless +qa                      → startup messages: []

$ nvim --headless '+CodeDiff install' +qa
Installing libvscode-diff v4.0.6 for linux x64...
Downloading from: https://github.com/esmuellert/codediff.nvim/releases/download/v4.0.6/libvscode_diff_linux_x64_4.0.6.so
Successfully installed libvscode-diff!
System libgomp.so.1 found, no need to bundle
libvscode-diff installation successful!
→ ~/.local/share/nvim/lazy/codediff.nvim/libvscode_diff_4.0.6.so (425552 bytes)
```

`:CodeDiff`, run headless in a scratch repo (`M a.lua`, `M b.txt`, `?? c.txt`), with `a.lua` open:

```text
CodeDiff ok=true err=
Installing codediff-watcher v0.23.2 for linux x64...
Successfully installed codediff-watcher!
tab 1
  win 1000 buf 1 ft=lua name=/tmp/cdtest/a.lua lines=6
tab 2
  win 1004 buf 5 ft=codediff-explorer name=/tmp/cdtest/CodeDiff Explorer [2] lines=5
  win 1001 buf 7 ft= name=codediff:////tmp/cdtest///8e1119f…/a.lua lines=5     (HEAD side, virtual)
  win 1002 buf 1 ft=lua name=/tmp/cdtest/a.lua lines=6                          (working file, editable)
# then wrote new_by_agent.txt from outside the view; 3 s later the explorer read:
 Changes (4)
   a.lua              M
   b.txt              M
   c.txt             ??
   new_by_agent.txt  ??
 Staged Changes (0)
```

OpenCode in tmux (`tmux list-keys -T prefix o` → `bind-key -T prefix o split-window -h -c "#{pane_current_path}" opencode`; I ran the same command because no client was attached):

```text
panes: 1 bash /tmp/cdtest 110x50 | 2 opencode /tmp/cdtest 109x50
TUI: "Ask anything…"  Build · Big Pickle OpenCode   /tmp/cdtest:master   2.2.6
~/.local/state/opencode/service.json: {"id":"84ac…","version":"2.2.6","url":"http://127.0.0.1:49374","pid":36233,"password":"<redacted>"}
GET /api/info → {"version":"2.2.6","pid":36233,…,"urls":["http://127.0.0.1:49374"]}
ss: LISTEN 127.0.0.1:49374 users:(("opencode",pid=36233))
```

`:checkhealth opencode` (after `:Lazy load opencode.nvim`):

```text
- opencode.nvim git commit: `4851ae503585dc5142ad66a98e8952a74e1f7b3a`
- `vim.g.opencode_opts`: { server = { start = <function 1> } }
- ✅ OK `opencode v2.2.6` available.
- ✅ OK `curl` available.
- ✅ OK OpenCode background service (v2.2.6) registered at `http://127.0.0.1:49374`.
- ⚠️ WARNING snacks.nvim not available: `ask()` and `select()` not enhanced.   (intended)
```

Connecting and sending context through the real keymaps (fed via `nvim_feedkeys`, so the keys went through mini.clue). I created an empty session with `POST /api/session {"location":{"directory":"/tmp/cdtest"}}`. Only `Server:prompt` was stubbed, which captured the text instead of sending `POST /api/session/<id>/prompt`:

```text
CONNECTED url=http://127.0.0.1:49374 connected=true      (auto-discovered via service.json; SSE /api/event subscribed)
COMMANDS: init, review, goal
SESSION ses_e41f1d0daffeY2yirOAUASA23W dir=/tmp/cdtest
ASK prompt=Ask OpenCode:  default=@this:                 (<leader>aa, cursor on a.lua:3:3)
SENT 1 text="a.lua:L3:C3: why 2?"                        (<leader>aa)
SENT 2 text="a.lua:L2-L3"                                (<leader>aoj)
SENT 3 text="a.lua:L5-L5"                                (V<leader>ao)
SENT 4 text="a.lua:L1-L1"                                (<leader>al)
autoread=true
```

`server.start` from Neovim running inside tmux, with OpenCode already in pane 2: a third pane `opencode /tmp/cdtest` opened, and the previously active pane kept focus (`-d`).

Keymaps (`nvim_get_keymap` / `nvim_buf_get_keymap`): global `n` `<leader>aa ab ad al ao as dd ds df dh dH`, `x` `<leader>aa ad ao as dh`, no other owners of these keys. In the CodeDiff tab, the diff buffers have `<leader>gs` "Stage hunk under cursor", `<leader>gu` "Unstage hunk under cursor", `<leader>gr` "Discard hunk under cursor", and no `<leader>h*`.

Afterwards I deleted the test session and the tmux session, ran `opencode service stop` (no listener left), and removed all scratch files.

## Caveats

- **Auth/providers are left to you.** Nothing was configured: no `/connect`, no API keys. Note that v2 ships free hosted models (the TUI defaulted to "Big Pickle (OpenCode)"), so there is no auth boundary before a model runs. For that reason the verification never submitted a prompt. Choose a model and provider in the TUI (`/connect`, `/models`) before relying on it.
- The first send from Neovim needs an existing session for the same cwd (send one message in the TUI first).
- `:checkhealth opencode` reports "No healthcheck found" until the plugin is loaded (it loads on `<leader>a…`). Run `:Lazy load opencode.nvim` first.
- One shared service per user: every TUI and Neovim instance sees the same sessions. `opencode --standalone` makes a private server, which opencode.nvim won't discover; it would need `server.url`.
- The review side is agent-agnostic: codediff.nvim only reads git state, and reloading works through `autoread` + checktime (FocusGained / CursorHold / BufEnter). omp, or any other agent, works the same way in a tmux pane. Only `<leader>a` is OpenCode-specific.
- opencode.nvim tracks `main` (v2 API). A lazy update can pull breaking changes; `lazy-lock.json` pins the tested commit. Its release tags (`version = "*"`) are for OpenCode v1.
- tmux `prefix o` no longer cycles panes.

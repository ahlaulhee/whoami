# Roslyn on Linux: inotify usage (2026-11-09)

Tested in the Fedora 45 WSL distro with the article's Neovim config: Neovim 0.12.6, roslyn.nvim `1310387`, Roslyn 5.14.0-1.26554.1 (Crashdummyy mason registry), .NET SDK 10.0.113.

## Why Roslyn watches files itself

- Neovim 0.12 advertises `workspace.didChangeWatchedFiles.dynamicRegistration` only on macOS and Windows (`runtime/lua/vim/lsp/protocol.lua`, TODO referencing #27807, #28058, #23291, #26520). Installing inotify-tools changes nothing because the capability is off.
- Roslyn then falls back to its own watcher. lsp.log: `DelegatingFileChangeWatcher] We are unable to use LSP file watching; falling back to our in-process watcher.`
- Roslyn 5.4 to 5.7 watched `/` recursively with a single watcher. That used hundreds of thousands of inotify watches, and on WSL it overflowed the stack. See dotnet/roslyn#82857.
  - Fixed by dotnet/roslyn#83101 (merged 2026-04-28). The fix adds a consolidating watcher with `maxWatcherCount = 1000`.
  - On .NET 10 each `FileSystemWatcher` is one inotify instance. That is from the PR description and matches what I measured.
- roslyn.nvim starts the server with `--daemon`. One server is shared by every Neovim instance and stays alive for 900 s after the last client disconnects. Override with `ROSLYN_LANGUAGE_SERVER_DAEMON_KEEPALIVE`. When a client disconnects, its watches are released.

## Measurements (instances / watches while connected)

| Solution | Dirs in repo | Instances | Watches | Load |
| --- | --- | --- | --- | --- |
| VacacionesEvolution (5 projects, built) | 162 | 20 | 10,737 | 4.1 to 6.0 s |
| same + `npm install` in the Vite client | 1,425 | 20 | 12,000 | 4.1 s |
| synthetic, 40 classlibs in a chain | 362 | 48 | 9,243 | 5.5 s |

- **Where the watches go (VacacionesEvolution):**
  - `/usr`: 7,869 of its 9,818 dirs;
  - the whole `~/.nuget/packages`: 1,691 dirs;
  - the whole repo, `node_modules` included.
- On a full desktop install, `/usr` and the NuGet cache are larger. The watch limit is computed from RAM (WSL: 524288), so it isn't the problem. The instance limit is.

## Failure and fix

- `fs.inotify.max_user_instances` is 128, the kernel default. No Fedora `sysctl.d` file changes it.
- **Limit of 60, 40-project solution:** `System.IO.IOException: The configured user limit (60) on the number of inotify instances has been reached`. Lib31 to Lib40 fail to load, and project initialization never completes (waited 300 s).
- **Busy session, simulated:** 85 extra processes hold one instance each, so 107 are in use against a limit of 128. The solution doesn't load within 90 s, with 39 inotify errors.
- **Fix:** `/etc/sysctl.d/90-inotify.conf` with `fs.inotify.max_user_instances = 1024`, then `sysctl --system`. The solution loads in 5.6 s with 0 errors and 151 instances in use.

## Other behaviour seen

- **References:** they span the Application and Tests projects. There were 0 errors after load.
- **New `.cs` file created outside Neovim:**
  - the server knows it after 1.2 s, checked with `workspace/symbol`;
  - a deleted file is dropped after 1.2 s;
  - diagnostics in an already-open buffer update only on the next edit to that buffer.

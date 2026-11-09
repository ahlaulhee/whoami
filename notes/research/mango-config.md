# Mango 0.18.5 config for part 2: notes and verification

Written 2026-11-08. Files: `C:/dev/scratch-mango/mango/`
- `config.conf` → `~/.config/mango/config.conf`
- `mango-idle` → `/usr/local/bin/mango-idle` (replaces `dwl-idle`, same swayidle line)
- `mpd.conf` → `~/.config/mpd/mpd.conf`
- `rmpc/config.ron` → `~/.config/rmpc/config.ron`, `rmpc/themes/paradise.ron` → `~/.config/rmpc/themes/paradise.ron`
- `xdpw-config` → `~/.config/xdg-desktop-portal-wlr/config`
- `scroller.png`, `scroller-half.png`: grim screenshots of the 2560x1440 output from the headless run

Sources. Docs: `github.com/mangowm/mangowm.github.io` `apps/docs/content/v0.18.5/<path>`; I read the same files from the compositor repo's `docs/` at tag `0.18.5` (`/root/mango-src` in WSL, `git describe` = `0.18.5`), so `docs/X.md` below means `v0.18.5/X.md` [ASSUMPTION: the site folder mirrors the repo `docs/` at the tag; the file names match]. Code: `github.com/mangowm/mango` tag `0.18.5`, paths relative to the repo root.

## 1. Option and dispatcher reference (what config.conf uses)

### File handling
| Item | Source | Note |
|---|---|---|
| config path | `src/config/load.c:402` | Uses `$HOME/.config/mango/config.conf`; **`XDG_CONFIG_HOME` is ignored**. Test runs need `-c`. |
| `-p` parse check | `src/main.c` getopt | Prints `[ERROR]` lines with file:line, but **exit code is 0 even with errors** (tested with an unknown keyword and an unknown dispatcher). Check for empty output, not `$?`. |
| `$NAME` in values | `src/config/variable_expand.c:83-144` | Only names defined with `var=` are replaced; unknown `$HOME`, `$(slurp)` pass through untouched, so shell commands in `spawn_shell` are safe. |
| auto reload | `docs/configuration/basics.md` | default on |

### Monitors, VRR
| Item | Source | Note |
|---|---|---|
| `monitor_rule=name:^DP-1$,width,height,refresh,x,y,scale,vrr,primary` | `docs/configuration/monitors.md`; parser `src/config/option_defs.c:1130-1220` | `name` is a regex; rule needs one of name/make/model/serial. `vrr` clamped 0..1. |
| `window_rule=vrr_only_fullscreen:1,app_id:.*` | `docs/window-management/rules.md:42` ("you need to turn `vrr` to `0` in monitor rule first"); logic `src/manage/monitor.c:1448-1480` (`check_vrr_enable`) | VRR is enabled when a *visible fullscreen* client with the flag is on the monitor, and disabled again when it leaves fullscreen and the monitor's global `vrr` is 0. It is a per-window rule, and a window rule must carry `app_id` or `title` (`src/manage/client.c:1056-1061`), so "every fullscreen window" is `app_id:.*`. Narrow it (e.g. `app_id:^(steam_app_.*|gamescope)$`) if fullscreen video should stay at fixed refresh. Not testable headless (no VRR on headless outputs; `is_vrr` reported false). |

### Tags, layouts, scroller
| Item | Source | Note |
|---|---|---|
| `tag_num=9` | `docs/window-management/layouts.md`/`option_defs.c` | clamp 1..31 |
| `tag_rule=id:*,layout_name:scroller` | `docs/window-management/rules.md:179,205`; `option_defs.c:1290-1293` (`id_wildcard`) | **Verified**: `mmsg get all-tags` showed `"layout":"S"` for all 9 tags on both outputs. |
| `circle_layout=scroller,tile,monocle` + `switch_layout` | `docs/window-management/layouts.md` | Super+space cycles |
| `setlayout,scroller/tile/monocle` | `src/config/binding_parse.c:681` | |
| `scroller_default_proportion=0.8` | `docs/window-management/layouts.md:36` (default 0.9) | Verified: windows 2012 px wide on 2560 px output (0.8 of the area inside 10 px outer gaps, minus borders). |
| `scroller_proportion_preset=0.5,0.8,1.0` | layouts.md:42; parser `option_defs.c:306-377` (values clamped 0.1..1.0) | |
| `scroller_ignore_proportion_single=1` | layouts.md:44 | default; lone window gets `scroller_default_proportion_single` (1.0) |
| `scroller_prefer_overspread=0`, `scroller_focus_center=1` | layouts.md:37-48 (priority overspread > focus_center > prefer_center) | Verified: newly focused window placed at x=274 on the output = (2560−2012)/2. After `set_proportion,0.5` the focused column was *not* re-centred until the next focus change (observed: x local 274, width 1257). |
| `set_proportion,1.0` | `binding_parse.c:575` | Super+e |
| `switch_proportion_preset,next` | `binding_parse.c:578`; arg via `parse_circle_direction` (`src/config/value_parse.c:185-202`: `next`, anything else = prev) | Super+r |
| `scroller_stack,<dir>` | `binding_parse.c:846`; shipped `/etc/mango/config.conf` binds it | Super+Ctrl+hjkl |
| `focusdir,<dir>` / `exchange_client,<dir>` | `binding_parse.c:520,541`; `docs/bindings/keys.md:129` | |
| `view,N` / `tag,N` | `binding_parse.c:770-777` | optional 2nd arg = synctag |
| `focusmon,left|right` / `tagmon,left|right` | `binding_parse.c:702-714` | |
| `togglefullscreen`, `togglefloating`, `killclient`, `focuslast`, `togglegaps`, `reload_config`, `quit`, `spawn`, `spawn_shell` | `binding_parse.c:688,686,599,606,718,765,739,725,730`; `docs/bindings/keys.md:127,183,195` | `spawn_shell` runs through the shell (pipes); `spawn` for plain argv. Args after the dispatcher are re-joined (`combine_args_until_empty`, `binding_parse.c:451`). |

### Input, look
| Item | Source | Note |
|---|---|---|
| `xkb_rules_layout=us`, `repeat_rate`, `repeat_delay`, `mouse_accel_profile=1` (flat) | `docs/configuration/input.md` | |
| `cursor_theme`, `cursor_size` | `docs/visuals/theming.md` / `miscellaneous.md` | exported as XCURSOR_* to the activation env |
| `sloppy_focus=1`, `warp_cursor=1` | `docs/configuration/miscellaneous.md:22-23`; defaults `option_defs.c:2428,2508` | both are the defaults; written out because they replace dwl patches |
| `border_px`, `border_radius=0`, gaps, `root_color`/`border_color`/`focus_color`/`urgent_color`/`scratchpad_color`/`global_color`/`overlay_color`/`maximized_screen_color` (0xRRGGBBAA) | `docs/visuals/theming.md:8-16`; shipped config | radius 0 because of NVIDIA jaggies (mango#1387, scenefx#177; see mango-0.18.md §5) |
| `animations=0`, `layer_animations=0`, `blur=0`, `blur_layer=0`, `shadows=0`, `layer_shadows=0` | `docs/visuals/animations.md`, `effects.md` | Decision: animations off. dwl had none; the open NVIDIA rendering bug at 1440p (#1594) is easier to tell apart without moving surfaces. Turn on with `animations=1` if wanted; nothing NVIDIA-specific is documented for it. |

### Binds
| Item | Source |
|---|---|
| `bind=MODS,KEY,dispatcher,args`; `NONE` modifier; `bindl` (works while locked) | `docs/bindings/keys.md:11-25,33` |
| `axisbind=SUPER,UP,...` | `docs/bindings/mouse-gestures.md:43-52` (Super+scroll = volume, as in dwl) |
| `mousebind=SUPER,btn_left,moveresize,curmove` / `btn_right,...,curresize` | shipped config, `binding_parse.c:748` |

Terminal: **Super+Return** (Mango's and most compositors' convention; dwl's default was Super+Shift+Return). Super+p stays the launcher. Super+b runs `qs ipc call bar toggle` (IpcHandler `target: "bar"` in QuickshellBar's shell.qml, per that agent).

### Window rules
| Rule | Source | Note |
|---|---|---|
| `window_rule=is_term:1,app_id:^foot$` | `docs/window-management/rules.md:101-102,151-153`; logic `src/manage/client.c:944-951,1765-1768` | A new window whose PID descends from an `is_term` window's PID replaces it (swallow). Skipped when the new window is itself `is_term`, has `no_swallow`, or is floating / a float type. So foot-in-foot never swallows; no extra `no_swallow` rule needed. Not exercised in the headless run. |
| `window_rule=is_floating:1,app_id:^steam$,title:^(Friends List|Steam Settings)$` | rules.md | Both app_id and title must match (`client.c:1057-1060`). Titles from Steam's current client [UNVERIFIED: not run]. |

### dwl patches → Mango
| dwl patch | Mango | Source |
|---|---|---|
| swallow | built in: `is_term` / `no_swallow` window rules. No runtime toggle dispatcher (dwl's Super+a / Super+Shift+a have no equivalent; no `swallow` dispatcher in `binding_parse.c:511-860`). | rules.md:101-102 |
| swapfocus (Super+s) | `focuslast` dispatcher: focuses the previous window from the focus stack and switches to its tag (`src/dispatch/bind.c:438-476`) | keys.md:127 |
| warpcursor | `warp_cursor=1` (default) | miscellaneous.md:23 |
| alwayscenter | built in: new floating windows are centred unless `no_force_center:1` (`client.c:1013-1015`); `centerwin` dispatcher | `option_defs.c:1531` |
| vanitygaps | built in: `gap_inner_*`/`gap_outer_*`, `smart_gaps`, `incgaps`, `togglegaps` | theming.md:13-16, keys.md:183 |
| bar toggle (Super+b) | the bar's own IPC (`qs ipc call bar toggle`) | — |
| VRR fullscreen toggle (Super+F5) | no runtime toggle; `vrr_only_fullscreen` rule does it automatically | monitor.c:1448-1480 |

### Autostart
`exec_once=` (`docs/configuration/basics.md`): swaybg, mako, lxqt-policykit-agent, `wl-paste --watch cliphist store`, `/usr/local/bin/mango-idle`, `qs`. Left out: any `dbus-update-activation-environment` line (Mango runs it and starts `mango-session.target`, `src/main.c`; xdg-portals.md says to remove it). mpDris2 is not in exec_once: Fedora's `mpdris2` ships `/usr/lib/systemd/user/mpDris2.service` (`WantedBy=default.target`, `BusName=org.mpris.MediaPlayer2.mpd`) → `systemctl --user enable --now mpDris2.service`.

## 2. Verification (WSL FedoraLinux-45, mangowm 0.18.5)

1. `mango -c config.conf -p`: no output (clean). Same check on a file with `foo=1` and `bind=SUPER,x,nosuchfunc` prints two `[ERROR]` blocks, exit code still 0.
2. Headless run with the config (monitor names sed'ed to `HEADLESS-1/2`, refreshes left at 144/240): script `/root/mcfg/run.sh` + `/root/mcfg/inner.sh`.
   - `mmsg get all-monitors`: HEADLESS-1 at 0,0 1920x1080; HEADLESS-2 at 1920,0 2560x1440 (the selected monitor, `primary:1`), `layout_symbol` `S`.
   - `mmsg get all-tags`: all 9 tags `"layout":"S"` on both outputs.
   - pgrep: `swaybg -c 151515`, `mako`, `/usr/libexec/lxqt-policykit-agent`, `wl-paste --watch cliphist store`, `swayidle -w timeout 600 … before-sleep swaylock -f` (started via mango-idle), `qs` all running.
   - Three foot windows on HEADLESS-2: x = −1840 / 177 / 2194 (global), width 2012, focused one centred. Screenshot `scroller.png`. Then `set_proportion,0.5` on two of them → `scroller-half.png` (two half-width columns, third peeking at the left edge).
   - `mmsg dispatch quit` → mango exit 0.
3. **Getting Mango to render in WSL (needed for any screenshot).** Mango always uses scenefx's GLES renderer, so `WLR_RENDERER=pixman` is ignored. WSL's only DRM device is `vgem` (`/sys/class/drm/card0 -> devices/faux/vgem`); with it, gbm buffer allocation fails (`gbm_bo_create failed`, "Swapchain for output 'HEADLESS-n' failed test") and outputs stay unusable; Mango then segfaulted once a layer-shell client (qs) mapped. Nested under WSLg (`WLR_BACKENDS=wayland`) fails with "Cannot create GLES2 renderer: no DRM FD available". What works, inside `unshare -m` after `mount -t tmpfs tmpfs /tmp`:
   ```sh
   mount --bind /dev/dri/card0 /dev/dri/renderD128   # vgem render node can't create dumb buffers; the primary node can
   export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe WLR_RENDERER_ALLOW_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=kms_swrast
   unset WAYLAND_DISPLAY DISPLAY
   export WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2 WLR_LIBINPUT_NO_DEVICES=1
   dbus-run-session -- mango -c <config> -s '<test script>'
   ```
   This is a test-harness workaround only; it says nothing about the NVIDIA desktop.
4. MPD: `mpd --no-daemon` with `mpd.conf` started; `mpc outputs` → `Output 1 (PipeWire) is enabled`; first start logs "Failed to open … database/state" (expected, files are created on exit). Directories must exist first: `mkdir -p ~/Music ~/.local/share/mpd/playlists ~/.local/state/mpd`.
5. rmpc: `dnf install rmpc` → `rmpc-0.11.0-1.fc45` (Terra), `rmpc version` → `rmpc 0.11.0`. There is no `--version` flag and `rmpc config --current` / `theme --current` just print the files without validating. Validation done by running the TUI in a pty (`script -qc rmpc`, needs `util-linux-script`, installed): log `/tmp/rmpc_0.log` shows no "Failed to read config", and the resolved theme contains `text_color: Some(Rgb(232, 227, 227))`, tab bar `fg Rgb(21,21,21) bg Rgb(141,163,185)`. A copy with an invalid colour gives `Error: Failed to read config / Invalid color format 'notacolor' / Using the default values`, so a partial theme is accepted and bad values are caught.
6. Portal: `/usr/share/xdg-desktop-portal/mango-portals.conf` contains
   ```ini
   [preferred]
   default=gtk
   org.freedesktop.impl.portal.ScreenCast=wlr
   org.freedesktop.impl.portal.Screenshot=wlr
   org.freedesktop.impl.portal.Inhibit=none
   ```
   `gtk.portal` lists `org.freedesktop.impl.portal.Settings` (and FileChooser etc.), `wlr.portal` only Screenshot/ScreenCast. `default=gtk` therefore already gives the Settings portal to gtk. **No user override needed**; the dwl article's `~/.config/xdg-desktop-portal/wlroots-portals.conf` isn't read under Mango (`XDG_CURRENT_DESKTOP=mango`, verified in the session env) and can be dropped. xdpw: the article's file plus Paradise colours for wmenu. In the headless run xdpw itself exited ("pipewire: couldn't connect to context"; no PipeWire in that sandbox), so screencast was not exercised.

## 3. Commands for the article
```bash
mkdir -p ~/Music ~/.local/share/mpd/playlists ~/.local/state/mpd
systemctl --user enable --now mpd.socket        # Fedora mpd ships user units: mpd.service + mpd.socket (%t/mpd/socket and port 6600)
systemctl --user enable --now mpDris2.service   # MPRIS bridge for the bar
sudo dnf install rmpc                           # Terra
sudo install -m 755 ~/dotfiles/bin/mango-idle /usr/local/bin/mango-idle
systemctl --user restart xdg-desktop-portal-wlr
```
`rpm -ql mpd`: `/usr/lib/systemd/system/mpd.{service,socket}`, `/usr/lib/systemd/user/mpd.{service,socket}`. The user `mpd.service` runs `/usr/bin/mpd --systemd`, which reads `~/.config/mpd/mpd.conf`.

Packages installed during this work: `rmpc`, `rmpc-bash-completion` (Terra), `util-linux-script` (test only).

## 4. Open points
- Swallow and the Steam float rule weren't exercised.
- The DP-1/DP-2 names are placeholders; on NVIDIA they're usually `DP-n`/`HDMI-A-n` — take them from `mmsg get all-monitors`.
- Super+Shift+i toggle: same pkill/restart approach as in dwl (swayidle#198 still applies).

## 5. Idle inhibit options (follow-up)

Docs: `docs/configuration/miscellaneous.md:57-58`, `docs/window-management/rules.md:41`. Defaults `src/config/option_defs.c:2486-2487` (both 0); rule default 0 (`src/manage/client.c:2185`).

| Option | Docs | What the code does |
|---|---|---|
| `idle_inhibit_ignore_visible` (0) | "Allow invisible clients (e.g., background audio players) to inhibit idle." | `check_idle_inhibitor` (`src/manage/misc.c:330-359`): normally an idle-inhibit-v1 inhibitor only counts if its surface's scene node is enabled (visible, not animating out of the tag). With `=1` any existing inhibitor sets `wlr_idle_notifier_v1_set_inhibited(…, 1)`. Same effect as dwl's `bypass_surface_visibility = 1`. |
| `idle_inhibit_when_fullscreen` (0) | "Keep idle inhibited while a fullscreen window is focused." | Not an inhibitor: a 1 s timer (`idle_keep_inhibit`, `misc.c:842-864`, created `src/main.c:708`) calls `wlr_idle_notifier_v1_notify_activity` every second while the **focused client of the selected monitor** is fullscreen and visible (`client_keep_idle_inhibit`, `misc.c:821-834`). It fakes input activity, so ext-idle-notify clients (swayidle) never reach their timeout, regardless of logind inhibitors. Armed from `client_focus` / `client_set_floating` (`client.c:2984,3526`); stops by itself once the condition is false (also when the session is inactive). Caveat: only while that window has focus; focusing a window on the other monitor ends it. |
| `window_rule=idle_inhibit_when_focus:1,…` | "Automatically keep idle inhibit active when this window is focused" | Same timer, condition is just "this client is focused" (`misc.c:825`), fullscreen or not. |

So `idle_inhibit_when_fullscreen=1` covers controller-only gaming as long as the game is fullscreen and focused, without the Super+Shift+i toggle; the toggle stays useful for windowed games.

Headless test (`/root/mcfg/inner-idle.sh`, config with both options =1, `swayidle timeout 4 'echo … >> idle.log'`, 7–10 s per case):

| Case | Timeout fired? |
|---|---|
| A no window | yes (after 4 s) |
| B tiled foot focused | yes |
| C same foot after `mmsg dispatch togglefullscreen` (`is_fullscreen:true`) | **no** (10 s) |
| D back to tiled | yes |

swayidle printed `Failed to parse get BlockInhibited property: Invalid argument` each start (the swayidle#198 logind bug), which doesn't matter here since Mango feeds activity through ext-idle-notify. `idle_inhibit_ignore_visible` wasn't exercised (no inhibitor client in the sandbox); source only.

Added to config.conf (own "Idle" section): `idle_inhibit_when_fullscreen=1`, `idle_inhibit_ignore_visible=1`. `mango -c config.conf -p`: no output.

# Mango 0.18.5 on Fedora 45: research notes

Researched 2026-11-08. Sources:
- Docs source: <https://github.com/mangowm/mangowm.github.io/tree/main/apps/docs/content/v0.18.5> (rendered at <https://mangowm.github.io>)
- Compositor source: <https://github.com/mangowm/mango>, tag `0.18.5` (commit `faaf4a9`, 2026-11-04). The tag has no `v` prefix.
- Hands-on checks in WSL `FedoraLinux-45` (Fedora 45, dnf5 5.4.6, rpm 6.1.0).

Short version: Mango 0.18.5 is packaged in Terra for F45, and `scenefx` / `wlroots` 0.20.2 come from Fedora's own repos. The source build also compiles cleanly on F45 using only Fedora packages. `monitor_rule` handles mode, refresh, position, scale and VRR for each output, so kanshi isn't needed for a fixed two-monitor desk. A bar talks to Mango through its own JSON IPC socket (`mmsg`) or through ext-workspace-v1. **Mango does not implement dwl-ipc-unstable-v2.**

---

## 1. Installation on Fedora 45

### 1.1 Terra (the route the docs give)

From `installation.md` (<https://github.com/mangowm/mangowm.github.io/blob/main/apps/docs/content/v0.18.5/installation.md>):

```bash
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
sudo dnf install mangowm
```

Things to know when running it:
- Keep the single quotes so dnf expands `$releasever` (giving `terra45`), not the shell. If the variable gets lost, dnf requests `https://repos.fyralabs.com/terra/repodata/repomd.xml`, which returns **404** (I hit this in WSL).
- **Signing.** `--nogpgcheck` only covers the bootstrap transaction. dnf printed `Warning: skipped OpenPGP checks for 2 packages from repository: terra` (`terra-release-45-6`, `terra-gpg-keys-45-3`). After that the repo is fully signature-checked. `terra-release` installs `/usr/share/dnf5/repos.d/terra.repo` with `gpgcheck=1`, `gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra$releasever` and `repo_gpgcheck=0` (metadata is not signed; the file says "Terra currently uses a CDN based on the origin repo, so this is safe"). On the first `dnf install mangowm`, dnf imported key `0xC1C23D8C` "Terra 45 <security@fyralabs.com>", fingerprint `C2AC02124AF114F086592E3C8DDE7D14C1C23D8C`, and the install went through. `rpm -K mangowm-0.18.5-1.fc45.x86_64.rpm` reported `digests signatures OK`. With F45's default enforcement (`%_pkgverify_level` = `all`), Terra packages therefore verify normally. Only the two bootstrap packages skip verification. [INFERENCE] A stricter alternative is to fetch the key first, then `rpm --import` it, and only then install terra-release without `--nogpgcheck`. The docs don't describe that.
- To change repo settings, use `/etc/dnf/repos.override.d/`; the repo file says not to edit it.

WSL results (2026-11-08):

| Query | Result |
|---|---|
| `dnf repoquery --repo=terra mango*` | `mangowm 0.18.5-1.fc45` (x86_64, aarch64), `mangobar 0~20260527git.c0138d9-1.fc45` |
| `dnf install mangowm` | pulled in `mangowm-0.18.5-1.fc45` (terra) + `scenefx-0.5-1.fc45` (**fedora** repo) |
| wlroots | `wlroots-0.20.2-2.fc45` (Fedora) provides `libwlroots-0.20.so` |
| `mango -v` | `mango 0.18.5(release)` |
| Files | `/usr/bin/{mango,mmsg,mangonag}`, `/etc/mango/config.conf`, `/etc/mango/config.toml`, `/usr/share/wayland-sessions/mango.desktop`, `/usr/share/xdg-desktop-portal/mango-portals.conf`, `/usr/lib/systemd/user/mango-session.target`, man pages `mmsg.1`, `mangonag.1` |

Caveat: the RPM's requirements are only the shared libraries. It does **not** depend on `xorg-x11-server-Xwayland`, so install that yourself. Also install `xdg-desktop-portal-wlr` and the rest of the tools listed in §3.

Quickshell is **not** in Terra. Fedora ships it: `quickshell 0.2.1^git20260209.dacfa9d-5.fc45` (repo `fedora`).

### 1.2 Building from source on F45 (verified: it compiles)

`meson.build` (tag 0.18.5) requires: `wlroots-0.20 >=0.20.0`, `scenefx-0.5 >=0.5.0`, `wayland-server >=1.23.1`, `libinput >=1.27.1`, `xkbcommon`, `libdrm`, `libpcre2-8`, `pixman-1`, `libcjson`, `pangocairo`, `wayland-client`, plus `xcb`, `xcb-icccm` and `xcb-randr` when `-Dxwayland` is on. `meson_options.txt` has just `xwayland` (feature, default `enabled`) and `asan` (bool, default false).

The upstream docs tell you to build wlroots 0.20.2 and scenefx 0.5 by hand. **On F45 that's unnecessary**, because both are in Fedora as `-devel` packages. pkg-config names resolved with `dnf repoquery --whatprovides 'pkgconfig(...)'`:

| pkg-config | Fedora package |
|---|---|
| wlroots-0.20 | `wlroots-devel` (0.20.2-2.fc45) |
| scenefx-0.5 | `scenefx-devel` (0.5-1.fc45) |
| libcjson | `cjson-devel` |
| libpcre2-8 | `pcre2-devel` |
| xcb-icccm | `xcb-util-wm-devel` |
| xcb, xcb-randr | `libxcb-devel` |
| pangocairo | `pango-devel` |
| wayland-protocols | `wayland-protocols-devel` |
| wayland-server/client | `wayland-devel` |
| libinput / xkbcommon / pixman-1 / libdrm | `libinput-devel` / `libxkbcommon-devel` / `pixman-devel` / `libdrm-devel` |

Exact commands run in WSL. They succeeded, giving `[147/147] Linking target mango` and `./build/mango -v` → `mango 0.18.5(faaf4a9)`, with xwayland `enabled`:

```bash
sudo dnf install gcc meson ninja-build git wayland-devel wayland-protocols-devel \
  wlroots-devel scenefx-devel libinput-devel libxkbcommon-devel pixman-devel \
  libdrm-devel pcre2-devel cjson-devel pango-devel libxcb-devel xcb-util-wm-devel
git clone -b 0.18.5 https://github.com/mangowm/mango.git
cd mango
meson setup build -Dprefix=/usr      # add -Dxwayland=disabled to drop X11 support
ninja -C build
sudo ninja -C build install
```

Versions found at configure time: wayland-protocols 1.49, wlroots 0.20.2, libinput 1.32.0, pcre2 10.49, scenefx 0.5.0, cjson 1.7.19, pangocairo 1.58.2. Runtime still needs `xorg-x11-server-Xwayland`.

Recommendation: use Terra. It's the documented path, it's at 0.18.5, and it updates with dnf. Building from source buys nothing on F45 unless you want unreleased `main`.

---

## 2. Configuration

Sources: `configuration/basics.md`, `bindings/keys.md`, `window-management/{layouts,rules}.md`, `configuration/{input,monitors,miscellaneous}.md`, `visuals/{theming,effects,animations}.md`.

### 2.1 File, syntax, reload
- User config: `~/.config/mango/config.conf`. If that's missing, `~/.config/mango/config.toml` is used, and after that the system fallback `/etc/mango/config.conf`. Start from `cp /etc/mango/config.conf ~/.config/mango/config.conf`.
- Syntax is `key=value`, one per line, `#` for comments. Includes: `source=~/.config/mango/bind.conf`, relative `source=./theme.conf`, and `source_optional=...`. Variables: `var=term,foot` then `$term` / `${term}`.
- To validate without starting: `mango -c ~/.config/mango/config.conf -p`. Other CLI flags from `getopt "s:c:r:hdvp"` in `src/main.c`: `-c` config, `-s` startup command, `-d` debug log, `-v` version, `-p` parse-check.
- **Hot reload:** `auto_reload_config=1` (the default) watches the main file and every sourced file and reloads as soon as one changes. You can also reload manually with `bind=SUPER,r,reload_config` or `mmsg dispatch reload_config`. Parse errors show up in a `mangonag` bar.
- `env=NAME,value`. These are applied before init and **reset on every reload**. Some (IME, `WLR_*`) only take effect after relogin.
- `exec_once=cmd` runs once at startup (bar, wallpaper, daemons). `exec=cmd` runs again on every reload. Note the underscore: it's `exec_once`, not `exec-once`.

### 2.2 Keybinds
```ini
bind[flags]=MODS,KEY,dispatcher,args
# MODS: SUPER CTRL ALT SHIFT NONE, joined with +; KEY: keysym name or code:NN
# flags: l (works when locked) s (match keysym, not keycode) r (on release) p (pass to client) c (allow conflicts)
bind=SUPER,Return,spawn,foot
bind=SUPER,P,spawn_shell,grim -g "$(slurp)" - | wl-copy
bindl=SUPER,L,spawn,swaylock
key_mode=resize            # submaps; key_mode=common applies in all modes
```
`bind` converts the keysym to a keycode using the `xkb_rules_layout` layouts, so binds keep working when you switch layouts. Use `binds` to match the keysym itself.

### 2.3 Tags
- `tag_num=9` (range 1–31). Tag masks look like `3` or `1|3|5`.
- Dispatchers: `view,N`, `tag,N`, `tagsilent,N`, `toggleview,N`, `toggletag,N`, `viewtoleft`/`viewtoright`, `focusmon,left|right|next|prev|<spec>`, `tagmon,<dir|spec>[,keeptag]`, `viewcrossmon,mask,spec`, `tagcrossmon,mask,spec`.
- Tags belong to each monitor, as in dwl. Pass `synctag` (1) to `view`/`tag` to sync across monitors.
- Tag rules: `tag_rule=id:1,layout_name:scroller`, `tag_rule=id:*,layout_name:scroller`, `tag_rule=id:1,monitor_name:DP-2,no_hide:1,layout_name:scroller`.

### 2.4 Layouts and scroller
Available layouts: `tile scroller monocle grid deck center_tile vertical_tile right_tile vertical_scroller vertical_grid vertical_deck dwindle fair vertical_fair`. Switch with `setlayout,scroller` or cycle through `circle_layout=tile,scroller` with `switch_layout`. The shipped config sets `tag_rule=id:N,layout_name:tile` for tags 1–9.

Scroller options and their defaults per the docs:
```ini
scroller_structs=20                    # side space reserved when proportion = 1
scroller_default_proportion=0.9        # default width of new windows (shipped config.conf uses 0.8)
scroller_focus_center=0                # always centre the focused window
scroller_prefer_center=0               # centre only if it was off-screen
scroller_prefer_overspread=1           # priority: overspread > focus_center > prefer_center
edge_scroller_pointer_focus=1
edge_scroller_focus_allow_speed=0.0
scroller_proportion_preset=0.5,0.8,1.0
scroller_ignore_proportion_single=1
scroller_default_proportion_single=1.0 # needs scroller_ignore_proportion_single=0
```
To get always-centred focus, set `scroller_prefer_overspread=0` **and** `scroller_focus_center=1`.

Scroller dispatchers, with the binds from the shipped config:
```ini
bind=ALT,e,set_proportion,1.0
bind=ALT,x,switch_proportion_preset,
bind=alt+super+ctrl,Left,scroller_stack,left   # also right/up/down: stack windows inside a column
```
Window rules can set `scroller_proportion` and `scroller_proportion_single` per window. Focus and movement work as in the other layouts: `focusdir,left|right|up|down`, `exchange_client,<dir>`, `move_client,<dir>`.

### 2.5 Window rules
```ini
window_rule=Param:Value[,Param:Value...],app_id:REGEX,title:REGEX
window_rule=is_floating:1,app_id:pavucontrol
window_rule=tags:2,monitor:DP-2,app_id:firefox
window_rule=force_tearing:1,title:Counter-Strike 2
window_rule=confine_pointer:1,app_id:steam_app_526870
```
Other keys: `is_fullscreen`, `is_global`, `is_open_silent`, `width`/`height` (a value below 1 means a fraction of the screen), `offset_x`/`offset_y`, `no_border`, `no_blur`, `no_shadow`, `no_animation`, `allow_csd`, `idle_inhibit_when_focus`, `vrr_only_fullscreen`, `is_term`/`no_swallow`, `is_named_scratchpad`, `force_fake_maximize`. Layer rules use `layer_rule=...,layer_name:REGEX`, with `no_blur`, `no_animation`, `no_shadow` and animation types.

### 2.6 Keyboard / XKB
```ini
xkb_rules_layout=us,de
xkb_rules_variant=,nodeadkeys
xkb_rules_options=caps:escape,grp:alt_shift_toggle
repeat_rate=40
repeat_delay=300
numlock_on=1
device_rule=name:<from mmsg get all-devices>,kb_layout:de,accel_speed:0.1
```
Mouse settings: `mouse_accel_profile` (0 none / 1 flat / 2 adaptive) and `mouse_accel_speed`.

### 2.7 Monitors, so kanshi isn't needed
`monitor_rule` sets **mode, refresh, position, scale, transform, VRR, HDR, ICC and primary** for each output:
```ini
monitor_rule=name:^DP-1$,width:1920,height:1080,refresh:144,x:0,y:0,scale:1,vrr:1
monitor_rule=name:^DP-2$,width:2560,height:1440,refresh:240,x:1920,y:0,scale:1,vrr:1,primary:1
```
- `name` is a **regex**, so anchor it with `^...$`. You can match on `make`/`model`/`serial` instead, and if you set several, all of them must match. Get the values from `wlr-randr` or `mmsg get all-monitors`.
- Never use negative coordinates (XWayland input bug). `primary:1` sets the X11 RandR primary output, which matters for fullscreen X11 games. Rules are re-applied at startup, on hotplug and on reload.
- kanshi/wlr-randr do still work, because Mango creates `wlr_output_manager_v1`. But for a static two-monitor setup, `monitor_rule` alone is enough.
- Use the HDR keys (`hdr:1`, `togglehdr`) only with `env=WLR_RENDERER,vulkan`, and the docs say they're for the "wl-only branch" since scenefx doesn't support Vulkan. Treat HDR as unavailable on the normal scenefx build.

### 2.8 VRR and tearing
- VRR is set per monitor with `vrr:1` in `monitor_rule`. There's no global adaptive-sync switch. To get VRR only for fullscreen windows, set `vrr:0` on the monitor and use `window_rule=vrr_only_fullscreen:1,app_id:...`. That came in with v0.15.0 (PR <https://github.com/mangowm/mango/pull/1079>), which issue #748 ("VRR makes monitor flicker", RTX 2060) was pointed to as the fix: <https://github.com/mangowm/mango/issues/748>.
- Tearing: `allow_tearing=0|1|2` (2 = fullscreen only), plus `window_rule=force_tearing:1,...`. Some GPUs need `env=WLR_DRM_NO_ATOMIC,1` (set before start, then relogin).
- `sync_obj_enable=1` (the default) enables linux-drm-syncobj explicit sync and requires a restart. The FAQ recommends it for game stutter. The docs warn that some GPUs crash syncobj clients such as kitty, and the fix they give is `WLR_DRM_NO_ATOMIC=1`.

### 2.9 Cursor, gaps, borders, colours
```ini
cursor_size=24
cursor_theme=Adwaita
border_px=4
gap_inner_horizontal=5
gap_inner_vertical=5
gap_outer_horizontal=10
gap_outer_vertical=10
smart_gaps=0
no_border_when_single=0
border_radius=0
focus_color=0xc66b25ff         # 0xRRGGBBAA
border_color=0x444444ff
urgent_color=0xad401fff
root_color=0x323232ff
```
`cursor_hide_timeout=N` hides an idle cursor. `XCURSOR_THEME`/`XCURSOR_SIZE` are exported to the activation environment (`src/main.c` `env_vars[]`).

### 2.10 Animations, blur, shadows (scenefx)
```ini
animations=0            # 1 = on
layer_animations=0
animation_type_open=zoom   # slide|zoom|fade|none
animation_duration_move=500
blur=0
blur_layer=0
blur_optimized=1        # default; blurs against the cached wallpaper (cheap)
blur_params_radius=5
blur_params_num_passes=1
shadows=0
layer_shadows=0
shadow_only_floating=1
shadows_size=10
shadows_color=0x000000ff
focused_opacity=1.0
unfocused_opacity=1.0
```

---

## 3. Protocols / desktop features

Taken from the `wlr_*_create` calls in `src/` at tag 0.18.5:

| Feature | Present | Notes |
|---|---|---|
| XWayland | yes (`wlr_xwayland_create`, meson `xwayland` feature) | `xwayland_persistence=1`, `xwayland_ignore_scale`. Install `xorg-x11-server-Xwayland` |
| layer-shell | yes | bars, launchers, notifications |
| screencopy (wlr) + ext-image-copy-capture + ext-output/foreign-toplevel image capture source | yes | screen sharing and per-window capture (window casting since v0.15.0) |
| export-dmabuf | yes | |
| idle-notify (`ext-idle-notify-v1`) / idle-inhibit | yes | swayidle works [INFERENCE: protocol present, not run]. Options `idle_inhibit_ignore_visible`, `idle_inhibit_when_fullscreen`, rule `idle_inhibit_when_focus` |
| session-lock (`ext-session-lock-v1`) | yes | swaylock; `bindl=` binds still work while locked; `allow_lock_transparent` |
| wlr-output-power-management | yes | wlopm works [INFERENCE]; built-in: `mmsg dispatch sleep_monitor,DP-1` / `wakeup_monitor` / `sleep_toggle_monitor` (use these rather than `disable_monitor` on NVIDIA, see §5) |
| wlr-output-management | yes | wlr-randr, kanshi |
| foreign-toplevel: wlr + ext-foreign-toplevel-list | yes | taskbars |
| **ext-workspace-v1** | yes (`src/ext-protocol/ext-workspace.c`) | tags exposed as workspaces |
| dwl-ipc-unstable-v2 | **no** | not in `protocols/` and no `zdwl`/`dwl_ipc` anywhere in the tree. Waybar `dwl/tags` will not work |
| text-input-v3 + input-method-v2 | yes | fcitx5/IBus (`env=` set in docs §IME) |
| virtual keyboard/pointer, data-control (wlr + ext), primary selection | yes | wl-clipboard, cliphist, wtype |
| gamma-control | yes | wlsunset / gammastep |
| tearing-control, linux-drm-syncobj, drm-lease, color-management, fractional-scale, cursor-shape, pointer-constraints, relative-pointer, xdg-activation, xdg-decoration, keyboard-shortcuts-inhibit, presentation-time, tablet-v2 | yes | |

### Screen sharing / portals (`configuration/xdg-portals.md`)
- Mango sets `XDG_CURRENT_DESKTOP=mango` itself (`setenv` in `setup()`), and the `.desktop` file has `DesktopNames=mango;wlroots`. On startup it runs `dbus-update-activation-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XCURSOR_THEME XCURSOR_SIZE MANGO_INSTANCE_SIGNATURE`, then `systemctl --user import-environment …; systemctl --user --no-block start mango-session.target`. That target `BindsTo=graphical-session.target`. The docs say to **remove** any manual `dbus-update-activation-environment … XDG_CURRENT_DESKTOP=wlroots` line from old configs.
- The portal config ships at `/usr/share/xdg-desktop-portal/mango-portals.conf`. To override it, use `~/.config/xdg-desktop-portal/mango-portals.conf`:
  ```ini
  [preferred]
  default=gtk
  org.freedesktop.impl.portal.ScreenCast=wlr
  org.freedesktop.impl.portal.Screenshot=wlr
  org.freedesktop.impl.portal.Inhibit=none
  ```
  For gnome-keyring, add `org.freedesktop.impl.portal.Secret=gnome-keyring`.
- Packages to install: `pipewire`, `pipewire-pulseaudio`, `xdg-desktop-portal`, `xdg-desktop-portal-wlr` (F45: 0.8.4-1), `xdg-desktop-portal-gtk`, and a chooser. xdpw tries `slurp`, `wmenu`, `wofi`, `rofi`, `bemenu`, `mew`, `fuzzel` in that order, and if none is installed, sharing fails silently.
- To skip the chooser, put this in `~/.config/xdg-desktop-portal-wlr/config`: `[screencast]` / `output_name=DP-2` / `chooser_type=none`, then run `systemctl --user restart xdg-desktop-portal-wlr`.

F45 package names, all in the `fedora` repo: `greetd 0.10.3`, `tuigreet 0.9.1`, `swayidle 1.9.0`, `swaylock 1.8.6`, `wlopm 1.0.0`, `wlr-randr 0.5.0`, `kanshi 1.9.0`, `xdg-desktop-portal-wlr 0.8.4`, `waybar 0.15.0`, `quickshell 0.2.1^git20260209`.

---

## 4. IPC for a status bar

### 4.1 Mango's own socket (`mmsg`), the richest source
Doc: `ipc.md` (<https://github.com/mangowm/mangowm.github.io/blob/main/apps/docs/content/v0.18.5/ipc.md>). Implementation: `src/ipc/ipc.c` and `mmsg/mmsg.c`.

- **Socket:** a Unix stream socket at `$XDG_RUNTIME_DIR/mango-<pid>.sock`. Its path is exported as **`MANGO_INSTANCE_SIGNATURE`** to children and to the systemd/dbus activation env.
- **Wire format:** the client writes one text line, which is the argv joined by spaces plus `\n`, e.g. `watch all-tags\n`. The server answers with **newline-delimited compact JSON** (`cJSON_PrintUnformatted`). A `get` sends one line and the server closes. A `watch` sends a new line on every change and keeps the connection open. Any language or toolkit that can open a Unix socket and read lines can integrate directly, no `mmsg` process needed [INFERENCE from mmsg.c, which does exactly this].
- Commands:
  - `get`: `version`, `cursorpos`, `keymode`, `keyboardlayout`, `monitor <name>`, `focusing-client`, `client <id>`, `tag <mon> <idx>`, `tags <mon>`, `all-clients`, `all-monitors`, `all-devices`, `all-layers`, `all-tags`, `last_open_surface [<mon>]`
  - `watch`: `monitor <name>`, `focusing-client`, `client <id>`, `tags <mon>`, `all-monitors`, `all-tags`, `all-clients`, `all-devices`, `keymode`, `keyboardlayout`, `last_open_surface [<mon>]`
  - `dispatch <func>,<args> [client,<id>]`, e.g. `mmsg dispatch view,3` (a bar uses this for click-to-switch-tag)
- **Tag data per output** (`build_tags_json`): `watch all-tags` returns `{"all_tags":[{"monitor":"DP-1","tags":[{"index":1,"is_active":true,"is_urgent":false,"layout":"T","client_count":2},…]},…]}`. `get/watch tags <mon>` adds `active_tags`. So focused/visible = `is_active`, occupied = `client_count>0`, urgent = `is_urgent`, and the layout symbol is per tag.
- **Focused window:** `watch focusing-client` streams client JSON (`title`, `appid`, `id`, `is_fullscreen`, `is_floating`, `monitor`, …). Monitor objects have `layout_symbol`, `active_tags` and an `active_client` (`id`/`title`/`appid`, null when nothing is focused). Other events: `keymode` and `keyboardlayout`.

### 4.2 ext-workspace-v1
Tags are published as ext-workspace workspaces (`src/ext-protocol/ext-workspace.c`, re-synced on `tag_num` change). Generic bars can use it: Waybar's `ext/workspaces` module is in F45's waybar 0.15.0 (I checked the strings in the binary). It doesn't carry the window title or layout. For those, use foreign-toplevel or §4.1.

### 4.3 What this means for bar integration
- **Waybar:** native `mango/workspaces`, `mango/window`, `mango/layout`, `mango/language`, `mango/keymode` modules (backend over the IPC socket) are in **Waybar 0.16.0** (released 2026-11-05; `src/modules/mango/` exists at ref `0.16.0` and not at `0.15.0`): <https://github.com/Alexays/Waybar/tree/0.16.0/src/modules/mango>. **Fedora 45 has waybar 0.15.0**, which has no `mango/*` modules (confirmed by `strings /usr/bin/waybar`). Your options on F45 are `ext/workspaces` with `wlr/taskbar`, or waiting for or building 0.16.0. `dwl/tags` and `dwl/window` are compiled in but useless without dwl-ipc.
- **Quickshell:** no built-in Mango module [UNVERIFIED: check Quickshell docs]. Workable approaches: (a) read `MANGO_INSTANCE_SIGNATURE` and connect to the socket with Quickshell's socket/process I/O types, sending `watch all-tags` and `watch focusing-client` and parsing the JSON lines [INFERENCE]; (b) run `mmsg watch …` as a long-lived process and parse its stdout lines; (c) use the wayland ext-workspace / foreign-toplevel bindings if your Quickshell version exposes them [UNVERIFIED]. MPD, volume, mic, clock and tray don't depend on the compositor.

---

## 5. Session, launch, NVIDIA

- **Session file:** `/usr/share/wayland-sessions/mango.desktop`, which contains `Name=Mango`, `Exec=mango`, `DesktopNames=mango;wlroots`, `Type=Application`. GDM/SDDM list it automatically.
- **greetd + tuigreet:** works, since it's just `Exec=mango`. The docs give this greetd config (NixOS example; same semantics in `/etc/greetd/config.toml`):
  ```toml
  [default_session]
  command = "tuigreet --cmd mango"
  user = "greeter"
  ```
  Other documented ways to start it: run `mango` from a TTY, or put `[ "$(tty)" = /dev/tty1 ] && exec mango` in your login shell. Mango handles systemd/dbus env import and `graphical-session.target` itself through `mango-session.target`, so no uwsm or wrapper is required [INFERENCE from `src/main.c`].
- **Env vars from the docs:** `WLR_DRM_NO_ATOMIC=1` (tearing on some GPUs, syncobj crashes), `WLR_DRM_DEVICES=/dev/dri/cardN` (black screen / multi-GPU), `WLR_RENDERER=vulkan` (HDR only, wl-only branch), plus IME vars. Set them with `env=` in the config and relogin.
- **NVIDIA:** the v0.18.5 docs have **no NVIDIA section**. A PR that would have added NVIDIA env-var docs, #1094 <https://github.com/mangowm/mango/pull/1094>, was closed **unmerged**. When asked "how is the NVIDIA support?", the maintainer answered "I can't make any promises. You can give it a try." (<https://github.com/mangowm/mango/issues/1429>). Known NVIDIA reports:
  - #1594 (open, 2026-11-07, **0.18.5**, 2560x1440, driver 615.78.08): "right side of 1 focused window is pixely, glitchy and disappears" when there's a single window. This matches your 27" 1440p setup. <https://github.com/mangowm/mango/issues/1594>
  - #1387 / scenefx#177: jagged rounded corners and borders on the proprietary driver because of `mediump` GLES precision. The maintainer declined to patch it in Mango, and the fix is pending upstream in scenefx (<https://github.com/wlrfx/scenefx/pull/177>). Workaround: `border_radius=0`. Also #1196 (corner blur artifacts, open).
  - #1245: Xwayland randomly exiting on NVIDIA, fixed in commit `82806f7` (closed, before 0.18.5). <https://github.com/mangowm/mango/issues/1245>
  - #1164: `disable_monitor` → `enable_monitor` leaves a black screen on NVIDIA. The maintainer says to use `sleep_monitor`/`wakeup_monitor` for DPMS. <https://github.com/mangowm/mango/issues/1164>
  - #748: VRR flicker on an RTX 2060 (see §2.8). If your monitors flicker, use `vrr_only_fullscreen`.
  - Explicit sync: `sync_obj_enable=1` is the default (linux-drm-syncobj is created). The cursor has no NVIDIA-specific option in the docs. [INFERENCE] The usual wlroots-on-NVIDIA prerequisites apply (`nvidia-drm.modeset=1`, which recent drivers enable by default) but aren't documented by Mango.

---

## 6. Bars the docs recommend

- `visuals/status-bar.md` recommends **mangobar** first (<https://github.com/mangowm/mangobar>): layer-shell, IPC-integrated, with modules for workspaces, layout, window title, keymode, keyboard layout, CPU/memory, brightness, volume, clock, network, battery, tray and `custom/<name>`. Config lives at `~/.config/mangobar/config.jsonc` and `style.css`, and you start it with `exec_once=mangobar`. It's in Terra as `mangobar 0~20260527git.c0138d9`. Not checked: whether it has MPD or microphone modules (anything missing could be done with `custom/`) [UNVERIFIED].
- Waybar with the `mango/*` modules (needs Waybar ≥0.16.0). Example from the docs:
  ```jsonc
  "modules-left": ["mango/workspaces", "mango/layout", "mango/window"],
  "mango/workspaces": { "format": "{icon}", "hide-empty": true, "on-click": "activate", "on-click-right": "toggle" },
  "mango/window": { "format": "{}" }
  ```
  CSS classes: `#workspaces button.active|.urgent|.hidden|.visible|.overview`. The author's full config is at <https://github.com/DreamMaoMao/waybar-config>.
- `quick-start.md` lists these as "Status Bar" options: **waybar, eww, quickshell, ags**, and as desktop shells: Noctalia, DankMaterialShell. Quickshell is listed but has no Mango-specific docs.
- The author's full example config (mango + waybar + rofi): <https://github.com/DreamMaoMao/mango-config>.

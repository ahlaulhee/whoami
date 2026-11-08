# Research: dwl 0.9 desktop on Fedora 45 (part 2)

Collected 2026-11-08. Every claim cites a URL. Tags: **[UNVERIFIED]** means I didn't fetch it this session (stated from man-page knowledge). **[INFERENCE]** means I reasoned it from the sources cited and didn't observe it.
F45 package versions come from the "Fedora 45" row on packages.fedoraproject.org (`https://packages.fedoraproject.org/pkgs/<src>/<sub>/`).

## Corrections to the brief (read first)

1. **Fedora's greeter user is `greetd`, not `greeter`.** The spec runs `sed -i 's/"greeter"/"greetd"/' config.toml`, and the sysusers file creates `u greetd - "greetd daemon" /var/lib/greetd`. Sources: https://src.fedoraproject.org/rpms/greetd/raw/rawhide/f/greetd.spec, https://src.fedoraproject.org/rpms/greetd/raw/rawhide/f/greetd.sysusers
2. **grimpicker is its own binary subpackage, `grimpicker`. Don't install `sway-contrib`.** The `sway-contrib` main package has `Requires: sway` and `python3dist(i3ipc)`. `grimpicker` only requires grim and slurp, and recommends wl-copy and notify-send. Source: https://src.fedoraproject.org/rpms/sway-contrib/raw/rawhide/f/sway-contrib.spec (F45: grimpicker 1.11-3.fc45)
3. **Geist Mono is packaged:** `vercel-geist-mono-fonts` 1.8.0-2.fc45 and `vercel-geist-sans-fonts` (F45 build exists). Source: https://packages.fedoraproject.org/pkgs/vercel-geist-fonts/vercel-geist-mono-fonts/
4. **The Fedora greetd package already handles kmscon.** It carries `kmscon.patch`, which adds `After=`/`Conflicts=kmsconvt@tty1.service` to `greetd.service`. Source: https://src.fedoraproject.org/rpms/greetd/raw/rawhide/f/kmscon.patch
5. **tuigreet's `--remember` files live in `/var/lib/greetd/`** because of a Fedora patch, not in `/var/cache/tuigreet`. The upstream README's `mkdir /var/cache/tuigreet` step isn't needed on Fedora, and SELinux blocks it anyway. Source: https://src.fedoraproject.org/rpms/tuigreet/raw/rawhide/f/tuigreet-0.9.1-Store-persistent-data-in-the-greetd-user-home.patch
6. **`slstatus` is not in Fedora.** packages.fedoraproject.org/pkgs/slstatus/ returns 404, so build it from source (suckless).
7. **`hyprpolkitagent` is not in Fedora** (404). `polkit-gnome` has no F45 build; its only build is EPEL 9: https://packages.fedoraproject.org/pkgs/polkit-gnome/polkit-gnome/

---

## 1. greetd + tuigreet

**Packages (F45):** `greetd` 0.10.3, `greetd-selinux` 0.10.3-12.fc45, `tuigreet` 0.9.1-8.fc45.
- `greetd` pulls in `greetd-selinux` automatically: `Requires: (greetd-selinux = … if selinux-policy-targeted)`. Source: https://src.fedoraproject.org/rpms/greetd/raw/rawhide/f/greetd.spec
- Fedora's `tuigreet` builds from `github.com/apognu/tuigreet` 0.9.1. Source: https://src.fedoraproject.org/rpms/tuigreet/raw/rawhide/f/tuigreet.spec
  - The current upstream README (github.com/apognu/tuigreet → tuigreet/tuigreet fork) documents newer features: TOML config, `[secret]`, and background animations. **Those aren't in 0.9.1**, so the guide should use 0.9.1 flags only. Source for 0.9.1 flags: https://raw.githubusercontent.com/apognu/tuigreet/0.9.1/README.md

```sh
sudo dnf install greetd tuigreet
```

**Config file:** `/etc/greetd/config.toml`, shipped as `%config(noreplace)` (spec, above). Upstream default contents: https://git.sr.ht/~kennylevinsen/greetd/blob/master/config.toml

```toml
[terminal]
# The VT to run the greeter on. Can be "next", "current" or a number
vt = 1

[default_session]
command = "agreety --cmd /bin/sh"
user = "greeter"
```

On Fedora the spec rewrites this to `user = "greetd"`.

- **`[terminal] vt`:** the VT the greeter runs on. Upstream's comment allows `"next"`, `"current"` or a number. The user session takes over the same VT [UNVERIFIED: greetd(5)].
- **What Fedora sets up:**
  - PAM files `/usr/lib/pam.d/greetd` and `greetd-greeter`. The greeter PAM includes `pam_systemd.so`, and the user PAM includes `system-auth` and `postlogin`, plus optional gnome-keyring.
    - https://src.fedoraproject.org/rpms/greetd/raw/rawhide/f/greetd.pam
    - https://src.fedoraproject.org/rpms/greetd/raw/rawhide/f/greetd-greeter.pam
  - `%post` masks `xdg-desktop-portal.service` for the greetd user only (spec).

**Recommended config:**

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --asterisks --sessions /usr/local/share/wayland-sessions --cmd dwl-session"
user = "greetd"
```

tuigreet 0.9.1 flags (from the 0.9.1 README):

| Flag | Effect |
|---|---|
| `-c, --cmd COMMAND` | command to run |
| `-s, --sessions DIRS` | colon-separated Wayland session dirs; default sources are `/usr/share/xsessions` and `/usr/share/wayland-sessions` |
| `-t, --time` | show the date and time |
| `-r, --remember` | remember the last username |
| `--remember-session` | overrides `--cmd` with the last selection |
| `--asterisks` | show asterisks while typing a secret |
| `--user-menu` | pick the user from a menu |
| `--theme SPEC` | colours, ANSI names only |

Hotkeys: F2 edits the command, F3 opens the session list, F12 opens power options.

Session desktop file `/usr/local/share/wayland-sessions/dwl.desktop`. Format: freedesktop desktop entry [UNVERIFIED key list; tuigreet reads `Exec`/`Name`].

```ini
[Desktop Entry]
Name=dwl
Comment=dwl Wayland compositor
Exec=/usr/local/bin/dwl-session
Type=Application
```

**Enable:** a Custom OS install boots to `multi-user.target` [INFERENCE: no display manager in @core/@standard].

```sh
sudo systemctl enable greetd.service
sudo systemctl set-default graphical.target
```

The spec declares `Provides: service(graphical-login) = greetd` (spec, above).

**SELinux:** `greetd-selinux` labels the following (https://src.fedoraproject.org/rpms/greetd/raw/rawhide/f/greetd.fc):

| Path | Label |
|---|---|
| `/etc/greetd` | `xdm_etc_t` |
| `/usr/bin/greetd` | `xdm_exec_t` |
| `/var/lib/greetd` | `xdm_var_lib_t` |
| `/var/run/greetd*.sock` | `xdm_var_run_t` |

So greetd runs in the existing xdm domain. Implications for the guide:
- Keep greeter state in `/var/lib/greetd`, which is why Fedora patches tuigreet.
- A custom config needs no SELinux action.
- If something is denied: `sudo ausearch -m avc -ts recent` [UNVERIFIED command; standard audit tooling].

---

## 2. kmscon (F45) vs greetd

**Facts:**
- F45 installs `kmscon` by default: it's a `default` packagereq in the `core` group of comps-f45 (https://forge.fedoraproject.org/releng/fedora-comps/raw/branch/main/comps-f45.xml.in). The F45 build is kmscon 10.1.1-3.fc45.
- The Change symlinks `/usr/lib/systemd/system/autovt@.service` → `kmsconvt@.service`, "to start kmscon by default when switching VT". If kmscon fails, it falls back to getty/fbcon. https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole
- The Change's caveat: "Starting graphical application from the console (like startx) won't work … work around it by using the script `kmscon-launch-gui startx`" (same URL).
- `kmscon-launch-gui` (https://raw.githubusercontent.com/Aetf/kmscon/main/scripts/kmscon-launch-gui.sh):
  1. Sends kmscon the escape `\x1B]setBackground\a` so kmscon releases the display.
  2. Runs `"$@"`.
  3. Waits until the active VT is back.
  4. Sends `setForeground`.
- greetd conflict: the Fedora greetd unit carries `After=getty@tty1.service kmsconvt@tty1.service` and `Conflicts=getty@tty1.service kmsconvt@tty1.service`. Patch author's rationale: "kmsconvt is a replacement for getty … Add Conflicts= for it like what plasmalogin and gdm have done." https://src.fedoraproject.org/rpms/greetd/raw/rawhide/f/kmscon.patch

**Answers:**
- **Does greetd on vt1 conflict with kmsconvt@tty1?** It's handled: the packaged unit stops kmsconvt@tty1 when greetd starts. Keep `vt = 1`.
- **Does dwl launched by greetd work while kmscon runs on other VTs?** [INFERENCE] Yes.
  - dwl is a child of greetd, not of a kmscon terminal, so kmscon doesn't own tty1's display.
  - kmscon instances on tty2–6 start only when you switch to them (autovt).
  - VT switching between dwl and kmscon goes through logind/libseat device handover, the same as getty.
  - I found no primary source that tests dwl+greetd+kmscon specifically. **Flag this in the guide** and give the fallback below.
- **When is `kmscon-launch-gui` needed?** Only when you start dwl by hand from a kmscon login (e.g. testing dwl on tty2 before enabling greetd):
  ```sh
  kmscon-launch-gui dwl -s 'slstatus -s'
  ```
  It's not needed when greetd launches the session.
- **Fallback if VT handover misbehaves:** revert to getty for one VT, or mask kmscon globally. Both follow the Change's statement that "User can still revert to fbcon".
  ```sh
  sudo systemctl mask kmsconvt@tty2.service   # just tty2
  sudo ln -sf /usr/lib/systemd/system/getty@.service /etc/systemd/system/autovt@.service   # global [INFERENCE: inverse of the Change's how-to]
  ```

---

## 3. Session environment, portals

**What dwl 0.9 sets:** in `dwl.c` v0.9 it sets `WAYLAND_DISPLAY`, `DISPLAY` (when XWayland is up) and `XCURSOR_SIZE=24`. It does **not** set `XDG_CURRENT_DESKTOP`. https://codeberg.org/dwl/dwl/raw/tag/v0.9/dwl.c (`run()`, `setup()`)

`-s CMD` runs CMD through `/bin/sh -c` with dwl's **stdout piped into CMD's stdin**. This is the bar/status hook.

**xdpw requirements** (https://raw.githubusercontent.com/emersion/xdg-desktop-portal-wlr/master/README.md):
- "Make sure `XDG_CURRENT_DESKTOP` is set. Make sure `WAYLAND_DISPLAY` and `XDG_CURRENT_DESKTOP` are imported into D-Bus." Example: `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway`.
- If no `*-portals.conf` for the desktop exists in `/usr/share/xdg-desktop-portal/`, create one under `~/.config/xdg-desktop-portal/`.
- `wlr.portal` has `UseIn=wlroots;sway;Wayfire;river;phosh;Hyprland;`, so `XDG_CURRENT_DESKTOP=wlroots` is the right generic value. https://raw.githubusercontent.com/emersion/xdg-desktop-portal-wlr/master/wlr.portal

**Wrapper `/usr/local/bin/dwl-session`** (author's script; the commands come from the sources above):

```sh
#!/bin/sh
export XDG_CURRENT_DESKTOP=wlroots
export XDG_SESSION_DESKTOP=wlroots
export XDG_SESSION_TYPE=wayland
exec dwl -s "$HOME/.config/dwl/autostart.sh"
```

**`~/.config/dwl/autostart.sh`** (runs inside dwl, so `WAYLAND_DISPLAY` is set):

```sh
#!/bin/sh
dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
kanshi &
swaybg -i ~/.local/share/wallpaper.png -m fill &
mako &
lxqt-policykit-agent &
wl-paste --watch cliphist store &
swayidle -w timeout 300 'swaylock -f' timeout 600 'wlr-randr --output DP-1 --off' before-sleep 'swaylock -f' &
# keep stdin (dwl's status pipe) open for the bar patch; slstatus writes to stdout -> dwl
exec slstatus -s
```

Caveats for this script:
- How the bar patch consumes stdin is the patch owner's call. The last line just shows the shape.
- The wlr-randr idle-off line is illustrative. A safer documented option is plain `swaylock` only.
- `lxqt-policykit-agent` is the binary name in lxqt-policykit [UNVERIFIED].

**Portals config `~/.config/xdg-desktop-portal/wlroots-portals.conf`** (from the xdpw README):

```ini
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
```

- Name it `wlroots-portals.conf` to match `XDG_CURRENT_DESKTOP=wlroots`. `portals.conf` works as a catch-all [UNVERIFIED: xdg-desktop-portal portals.conf(5)].
- Whether Fedora's xdpw package already ships `/usr/share/xdg-desktop-portal/wlroots-portals.conf`: [UNVERIFIED]. Check with `rpm -ql xdg-desktop-portal-wlr`.

**Packages:** `xdg-desktop-portal` (Steam already Requires it), `xdg-desktop-portal-wlr` 0.8.4-1.fc45 (0.8.5 in updates-testing), `xdg-desktop-portal-gtk` 1.15.3-6.fc45.

**ext-image-copy-capture:**
- xdpw **0.8.0** (2025-10-21) added "ext_image_copy_capture_v1: Initial implementation".
- 0.8.2 added "check for capture source manager in ext_register_session_cb()" and "Fix screensharing on pipewire 1.6.x".
- 0.8.3 is flagged by upstream: "will sometimes stall screen recording". F45 ships 0.8.4.
- Source: https://github.com/emersion/xdg-desktop-portal-wlr/releases
- dwl v0.9 includes `wlr_ext_image_capture_source_v1.h`, `wlr_ext_image_copy_capture_v1.h` and `wlr_ext_foreign_toplevel_list_v1.h`, plus `wlr_screencopy_v1.h` (dwl.c above). So output capture works, and per-window capture is plausible [INFERENCE: dwl creates per-client `image_capture_source`; window choice needs a chooser that emits `Window: <id>`].

**xdpw chooser** (`~/.config/xdg-desktop-portal-wlr/config`, or `.../wlroots`; https://raw.githubusercontent.com/emersion/xdg-desktop-portal-wlr/master/xdg-desktop-portal-wlr.5.scd):

```ini
[screencast]
chooser_type=simple
chooser_cmd=slurp -f 'Monitor: %o' -or
max_fps=60
```

- `chooser_type=default` tries slurp, **wmenu**, wofi, rofi, bemenu, mew, fuzzel in order.
- An alternative is `chooser_type=dmenu` with `chooser_cmd=wmenu -l 5`.
- After changing config: `systemctl --user restart xdg-desktop-portal-wlr` [UNVERIFIED unit name].

---

## 4. Audio, polkit, fonts, user dirs

**Audio:**
- comps-f45 `multimedia` group lists `pipewire-pulseaudio`, `wireplumber`, `pipewire-alsa`, `pipewire-gstreamer`, `pipewire-utils`, `alsa-ucm`, `alsa-utils` and `pipewire-config-raop` as **mandatory** (no type attribute).
- `core`, `standard` and `networkmanager-submodules` have no pipewire entries.
- Source: https://forge.fedoraproject.org/releng/fedora-comps/raw/branch/main/comps-f45.xml.in
- **Part 1's `@multimedia` already installed PipeWire.** The user units are socket/preset-activated [UNVERIFIED]. Check with:
  ```sh
  systemctl --user status pipewire wireplumber pipewire-pulse
  ```
- Optional extras: `pavucontrol` (exists in Fedora), or `wpctl` (from wireplumber) for CLI volume [UNVERIFIED binary placement].

**Custom OS environment:** `core` is mandatory; `standard`, `guest-agents` and `networkmanager-submodules` are options (comps-f45, above).

**polkit agents with F45 builds:**

| Package | F45 build | Notes |
|---|---|---|
| `lxqt-policykit` | 2.4.0-2.fc45 | Qt. **Recommended.** |
| `mate-polkit` | 1.28.1-9.fc45 | GTK3. Binary at `/usr/libexec/polkit-mate-authentication-agent-1` [UNVERIFIED path] |
| `polkit-gnome` | none (EPEL 9 only) | |
| `hyprpolkitagent` | not packaged | |
| `xfce-polkit`, `polkit-kde` | source packages exist; F45 builds not checked [UNVERIFIED] | |

**Fonts:**

| Package | F45 build |
|---|---|
| `vercel-geist-mono-fonts` | 1.8.0-2.fc45 (Geist Mono, matches the author's site) |
| `vercel-geist-sans-fonts` | F45 build exists |
| `jetbrains-mono-fonts` | 2.304-11.fc45 (Paradise's foot/zathura configs use "JetBrains Mono") |
| `google-noto-sans-fonts` | 20260601-3.fc45 |
| `google-noto-sans-mono-fonts` | 20260601-3.fc45 |
| `google-noto-color-emoji-fonts` | 20260921-1.fc45 (`google-noto-emoji-fonts` is the source package name) |

- A Nerd Font isn't in Fedora [UNVERIFIED; not checked].
- The comps `fonts` group default members are `default-fonts-core-*` and `default-fonts-cjk-*`, which suits the whole set.

**xdg-user-dirs** 0.20-2.fc45: install it, then run `xdg-user-dirs-update` once. Steam `Recommends: xdg-user-dirs` (rpmfusion steam.spec, §8).

**brightnessctl:** not needed on a desktop.

---

## 5. kanshi

**Packages:** `kanshi` 1.9.0-2.fc45 and `wlr-randr` 0.5.0-4.fc45.

**dwl implements wlr-output-management** (dwl.c v0.9):
- `output_mgr = wlr_output_manager_v1_create(dpy)` with apply/test listeners.
- `outputmgrapplyortest()` builds the state via `wlr_output_configuration_v1_build_state()` and commits via `wlr_backend_commit`.
- That carries mode, position, scale, transform and adaptive_sync from the client [INFERENCE: build_state copies all head state fields].

**Get names and modes:** run `wlr-randr` inside dwl. It lists names (`DP-1`, `DP-2`, `HDMI-A-1` …), "Make Model Serial" descriptions, modes, and `Adaptive Sync:` [UNVERIFIED output format].

**Syntax** (https://git.sr.ht/~emersion/kanshi/blob/master/doc/kanshi.5.scd):
- `profile [name] { … }`
- `output <criteria> <directives>`
- Directives: `enable|disable`, `mode [--custom] WxH[@R[Hz]]`, `position X,Y`, `scale`, `transform`, `adaptive_sync on|off`, `alias $name`, `exec`, `include`.
- Criteria can be a name, or `"Make Model Serial"` (more stable than connector names).

**`~/.config/kanshi/config`** (output names are placeholders; replace them with `wlr-randr` output):

```
profile desk {
	output DP-2 mode 1920x1080@144Hz position 0,0 adaptive_sync on
	output DP-1 mode 2560x1440@240Hz position 1920,0 adaptive_sync on
}
```

- Run it from dwl autostart (`kanshi &`, §3).
- Alternatively, dwl's compiled-in `monrules[]` in `config.h` sets scale and position, but not mode or VRR (MonitorRule struct: name, mfact, nmaster, scale, lt, rr, x, y; dwl.c).

---

## 6. Tools

All packages below are in Fedora F45 main repos (versions from packages.fedoraproject.org).

| Tool | Package (F45) | Usage / config |
|---|---|---|
| foot | `foot` 1.28.0 | `~/.config/foot/foot.ini`. Server mode: `foot --server &` in autostart, then launch windows with `footclient` [UNVERIFIED: foot(1)]. |
| wmenu | `wmenu` 0.2.0 | `wmenu-run` lists `$PATH` and runs the result. Flags: `-f FONT` (Pango), `-l N`, `-o OUTPUT`, `-p PROMPT`, `-i`, `-b`, `-P`. Colours `RRGGBB[AA]`: `-N/-n` normal bg/fg, `-M/-m` prompt bg/fg, `-S/-s` selection bg/fg. Source: https://codeberg.org/adnano/wmenu/raw/branch/main/docs/wmenu.1.scd |
| swaybg | `swaybg` 1.2.2 | `swaybg -i ~/path.png -m fill` [UNVERIFIED flags: swaybg(1)] |
| mako | `mako` 1.11.0 | `~/.config/mako/config`; keys `background-color`, `text-color`, `border-color`, `border-size`, `font`, `default-timeout`; reload with `makoctl reload` [UNVERIFIED: mako(5)] |
| swaylock | `swaylock` 1.8.6 | `~/.config/swaylock/config` takes long options without `--`, e.g. `color=151515`, `inside-color=…`, `ring-color=…`, `key-hl-color=…` [UNVERIFIED: swaylock(1)]. dwl implements ext-session-lock (`wlr_session_lock_v1.h` in dwl.c). |
| swayidle | `swayidle` 1.9.0 | `swayidle -w timeout 300 'swaylock -f' before-sleep 'swaylock -f'` [UNVERIFIED: swayidle(1)]. dwl has idle-notify (`wlr_idle_notify_v1.h`). |
| wl-clipboard | `wl-clipboard` 2.3.0 | `wl-copy` / `wl-paste` |
| cliphist | `cliphist` 0.7.0 | Store: `wl-paste --watch cliphist store`. Pick: `cliphist list \| wmenu -l 10 \| cliphist decode \| wl-copy`. Delete: `cliphist list \| wmenu \| cliphist delete`. Source: https://raw.githubusercontent.com/sentriz/cliphist/master/readme.md. The README notes MIME-type tracking needs wl-clipboard PR #297 (after 2.3.0); F45 ships 2.3.0. |
| grim + slurp | `grim` 1.5.0, `slurp` 1.5.0 | `grim -g "$(slurp)" ~/Pictures/shot.png`; `grim -g "$(slurp)" - \| wl-copy` [UNVERIFIED flags]. dwl has wlr-screencopy and layer-shell. |
| grimpicker | **`grimpicker`** 1.11 (from src `sway-contrib`) | `-p` print, `-d` draw block, `-e` escape sequences, `-c` copy (needs wl-clipboard), `-f` freeze (needs `wayfreeze`, not in the package's Requires), `-n` notify (libnotify + mako). Default is `-p -d`. Example bind: `grimpicker --copy --notify`. Source: https://raw.githubusercontent.com/OctopusET/sway-contrib/master/grimpicker/grimpicker.1.scd |
| nnn | `nnn` 5.3 | `nnn` |
| zathura | `zathura` 2026.07.18 + `zathura-pdf-mupdf` or `zathura-pdf-poppler` (both 2026.07.18) | `~/.config/zathura/zathurarc` |
| imv | `imv` 5.0.1 | `imv file.png` |
| mpv | `mpv` 0.41.0 (Fedora main; uses RPM Fusion ffmpeg libs once swapped) [INFERENCE] | `mpv file` |
| neovim | `neovim` 0.12.6 | install only |
| NetworkManager TUI | **`NetworkManager-tui`** 1.58.1 (provides `nmtui`) | `nmcli` comes with NetworkManager [UNVERIFIED binary split] |
| polkit agent | `lxqt-policykit` | see §4 |

**Install line:**

```sh
sudo dnf install greetd tuigreet kanshi wlr-randr foot wmenu swaybg mako swaylock swayidle \
  wl-clipboard cliphist grim slurp grimpicker libnotify nnn zathura zathura-pdf-mupdf imv mpv neovim \
  NetworkManager-tui xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  lxqt-policykit xdg-user-dirs vercel-geist-mono-fonts vercel-geist-sans-fonts jetbrains-mono-fonts \
  google-noto-sans-fonts google-noto-color-emoji-fonts xorg-x11-server-Xwayland
```

`libnotify` provides `notify-send` [UNVERIFIED package mapping].

---

## 7. Paradise theme

**`cfg/foot/foot.ini`** (https://raw.githubusercontent.com/paradise-theme/paradise/main/cfg/foot/foot.ini), verbatim:

```ini
app-id=foot
title=foot
locked-title=no

font=JetBrains Mono:style=Medium:size=12
font-bold=JetBrains Mono:style=Bold:size=12
font-italic=JetBrains Mono:style=Italic:size=12
font-bold-italic=JetBrains Mono:style=Bold Italic:size=12
box-drawings-uses-font-glyphs=yes
dpi-aware=auto

pad=20x20

[cursor]
style=beam
beam-thickness=1.5

[colors]
background=151515
foreground=E8E3E3

regular0=151515 # black
regular1=B66467 # red
regular2=8C977D # green
regular3=D9BC8C # yellow
regular4=8DA3B9 # blue
regular5=A988B0 # magenta
regular6=8AA6A2 # cyan
regular7=E8E3E3 # white

bright0=424242 # bright black
bright1=B66467 # bright red
bright2=8C977D # bright green
bright3=D9BC8C # bright yellow
bright4=8DA3B9 # bright blue
bright5=A988B0 # bright magenta
bright6=8AA6A2 # bright cyan
bright7=E8E3E3 # bright white
```

Note: newer foot versions moved `dpi-aware`/`[colors]` semantics around. Check foot 1.28's `foot.ini(5)` for deprecation warnings [UNVERIFIED].

**`cfg/zathura/zathurarc`** (https://raw.githubusercontent.com/paradise-theme/paradise/main/cfg/zathura/zathurarc), verbatim:

```
set selection-clipboard clipboard
set window-title-home-tilde true
set statusbar-home-tilde true
set adjust-open "best-fit"

set font "Jetbrains Mono"

set adjust-open width
set recolor true
set recolor-keephue true
map <C-Tab> toggle_statusbar
set guioptions ""

set completion-bg "#151515"
set completion-fg "#424242"
set completion-group-bg "#151515"
set completion-group-fg "#e8e3e3"
set completion-highlight-bg "#151515"
set completion-highlight-fg "#e8e3e3"

set default-bg "#151515"
set default-fg "#e8e3e3"

set highlight-active-color "#A988B0"
set highlight-color "#D9BC8C" 

set index-active-bg "#151515"
set index-active-fg "#e8e3e3"
set index-bg "#151515"
set index-fg "#e8e3e3"

set inputbar-bg "#151515"
set inputbar-fg "#e8e3e3"

set notification-bg "#151515"
set notification-error-bg "#B66467"
set notification-error-fg "#e8e3e3"
set notification-fg "#e8e3e3"
set notification-warning-bg "#D9BC8C" 
set notification-warning-fg "#424242"

set recolor-darkcolor "#e8e3e3"
set recolor-lightcolor "#151515"

set render-loading true
set render-loading-bg "#e8e3e3"
set render-loading-fg "#151515"

set statusbar-bg "#151515"
set statusbar-fg "#e8e3e3"
```

**Palette:**

| Role | Hex |
|---|---|
| bg | `#151515` |
| fg | `#E8E3E3` |
| muted / bright black | `#424242` |
| red | `#B66467` |
| green | `#8C977D` |
| yellow | `#D9BC8C` |
| blue | `#8DA3B9` |
| magenta | `#A988B0` |
| cyan | `#8AA6A2` |

**Author's mapping (my proposal, not from Paradise):** the mappings below use only the hexes above. The option names are [UNVERIFIED] against each man page except wmenu.

mako `~/.config/mako/config`:

```ini
font=Geist Mono 11
background-color=#151515
text-color=#E8E3E3
border-color=#424242
border-size=2
default-timeout=5000

[urgency=low]
text-color=#8C977D

[urgency=critical]
border-color=#B66467
default-timeout=0
```

swaylock `~/.config/swaylock/config`:

```ini
color=151515
inside-color=151515
ring-color=424242
line-color=151515
separator-color=151515
key-hl-color=8DA3B9
bs-hl-color=B66467
inside-ver-color=151515
ring-ver-color=D9BC8C
inside-wrong-color=151515
ring-wrong-color=B66467
text-color=E8E3E3
indicator-radius=80
```

wmenu (flags verified, see §6):

```sh
wmenu-run -f 'Geist Mono 11' -N 151515 -n E8E3E3 -M 151515 -m 8DA3B9 -S 424242 -s E8E3E3
```

---

## 8. Gaming (Steam, gamescope, MangoHud, GameMode)

**Steam** (RPM Fusion nonfree, package `steam` 1.0.0.87-4; spec https://raw.githubusercontent.com/rpmfusion/steam/master/steam.spec):
- It's an `x86_64` package as of 1.0.0.85-7 (2026-05). `steam-arch-transition` handles the migration from i686.
- It Requires the 32-bit `glibc`, `libdrm`, `libglvnd-glx`, `mesa-*`, `vulkan-loader` and `pipewire-libs`.
- **It Requires `xorg-x11-server-Xwayland`**, with the spec comment "The client, Steam Overlay etc. are all X based". So Steam runs through XWayland, and dwl must be built with XWayland enabled (`-DXWAYLAND`, config.mk). Upstream dwl also needs the `xcb`/`xcb-icccm` dev packages for that [UNVERIFIED].
- Requires: `xdg-desktop-portal`, `steam-devices`, `polkit`.
- Recommends: `gamemode`, `gamescope`, `mangohud`, `xdg-user-dirs`, `ntsync-autoload`.
- `rpmfusion.org/Howto/Steam` returns **404** today. Older guides mention a separate `rpmfusion-nonfree-steam` repo [UNVERIFIED for F45]. With nonfree enabled, `sudo dnf install steam` is the documented path in the Fedora gaming doc (https://docs.fedoraproject.org/en-US/gaming/proton/, found by search; not fetched in full).
  - If dnf can't find `steam`, run `dnf repolist --all | grep -i steam` and enable it with `sudo dnf config-manager setopt rpmfusion-nonfree-steam.enabled=1` [UNVERIFIED repo id].

**32-bit NVIDIA libs:** RPM Fusion's NVIDIA howto says: "be sure to install the appropriate 32bit version of the xorg-x11-drv-nvidia-libs package… With Current Fedora (not EL), this is handled automatically by RPM (Boolean dependencies)." https://rpmfusion.org/Howto/NVIDIA?action=raw (line ~312). Verify with `rpm -q xorg-x11-drv-nvidia-libs.i686`.

**Other packages (Fedora main):** `gamescope` 3.16.29, `mangohud` 0.8.3~rc1, `gamemode` 1.8.2.

**Steam launch options:**

```
gamemoderun %command%
mangohud %command%
gamescope -W 2560 -H 1440 -r 240 --adaptive-sync -- %command%
```

- gamescope's README examples include `gamescope -r 30 -- %command%` and `-w/-h` (game resolution) vs `-W/-H` (output resolution). https://raw.githubusercontent.com/ValveSoftware/gamescope/master/README.md
- `--adaptive-sync` [UNVERIFIED flag name: from `gamescope --help`].
- Combined: `gamemoderun mangohud gamescope … -- %command%`. Inside gamescope, use gamescope's `--mangoapp` instead of `mangohud` [UNVERIFIED].

**gamescope on NVIDIA:**
- The README says: "For NVIDIA's proprietary driver, version 515.43.04+ is required (make sure the `nvidia-drm.modeset=1` kernel parameter is set)."
- **On Fedora, don't add that parameter.** RPM Fusion's kernel module package enables modeset by default and says the old `nvidia-drm.modeset=1` cmdline "produces a bad interaction with a Fedora Kernel specific patch… don't use nvidia-drm.modeset=1 parameter from cmdline". https://rpmfusion.org/Howto/NVIDIA?action=raw (lines ~188–200)
- Check that modeset is active: `cat /sys/module/nvidia_drm/parameters/modeset` should print `Y` [UNVERIFIED path].
- Running gamescope nested inside dwl uses gamescope's Wayland backend. There are known NVIDIA issues with nested gamescope [UNVERIFIED; no primary source fetched]. Present it as optional and per-game.

---

## 9. NVIDIA + wlroots 0.20 env vars

**wlroots 0.20 `docs/env_vars.md`** (https://gitlab.freedesktop.org/wlroots/wlroots/-/raw/0.20/docs/env_vars.md) lists, among others:

| Variable | Doc text |
|---|---|
| `WLR_NO_HARDWARE_CURSORS=1` | use software cursors |
| `WLR_RENDERER=gles2\|pixman\|vulkan` | force a renderer |
| `WLR_RENDER_NO_EXPLICIT_SYNC=1` | disable explicit sync in renderers |
| `WLR_RENDER_DRM_DEVICE` | DRM node for hardware renderers |
| `WLR_DRM_DEVICES` | colon list; the first is primary |
| `WLR_DRM_NO_ATOMIC=1` | legacy DRM interface |
| `WLR_DRM_NO_MODIFIERS=1` | "can fix certain modeset failures because of bandwidth restrictions" |
| `WLR_EGL_NO_MODIFIERS=1` | "work around driver bugs" |
| `WLR_SCENE_DISABLE_DIRECT_SCANOUT` | debugging |

The doc says nothing NVIDIA-specific.

**NVIDIA 620.70.06 README, Appendix L "Wayland Known Issues"** (https://download.nvidia.com/XFree86/Linux-x86_64/620.70.06/README/wayland-issues.html). Current `latest.txt` is 620.70.06; I didn't fetch the 615 README.
- If simpledrm and nvidia-drm both expose a DRM node for the same display you can get "black screen, corruption, or flickering". Workaround: the `fbdev=1` module parameter for nvidia-drm.
- Explicit Sync needs kernel ≥ 6.8 fixes (F45 qualifies) [INFERENCE: F45 kernel ≫ 6.8].
- On kernel ≥ 6.19, nvidia-drm supports the DRM color pipeline API. Compositors that mishandle it can show a blank screen; workaround `color_pipeline=0`. That's relevant only to HDR/color-managing compositors; wlroots 0.20 + dwl doesn't enable HDR by default [INFERENCE].
- Front-buffer GLX rendering, indirect GLX and GLX hardware overlays don't work in Xwayland.

**Test plan:**
1. Start dwl with **no** WLR_* variables. dwl v0.9 creates `linux_drm_syncobj` (explicit sync), which NVIDIA supports.
2. Change only one variable at a time, and only on a matching symptom:

| Symptom | Try |
|---|---|
| Invisible, offset or flickering cursor | `WLR_NO_HARDWARE_CURSORS=1` |
| Freezes, flicker or tearing in clients that track to sync, or `drm_syncobj` errors in `dwl -d` logs | `WLR_RENDER_NO_EXPLICIT_SYNC=1` |
| Black screen or modeset failure on the 240 Hz 1440p output (bandwidth) | `WLR_DRM_NO_MODIFIERS=1` |
| GLES2 renderer fails to start | `WLR_RENDERER=vulkan` as a test; pixman is software, diagnostic only |
| Duplicate DRM node (`ls /dev/dri/` shows `card0` + `card1` with only one GPU) | the NVIDIA README's `nvidia-drm fbdev=1`, rather than an env var. Whether RPM Fusion already sets `fbdev=1`: [UNVERIFIED] check `/sys/module/nvidia_drm/parameters/fbdev`. |

3. Put any variable that sticks in `dwl-session` before `exec dwl`, with a comment naming the symptom.
4. Debug logging: `dwl -d 2> ~/dwl.log`, which raises wlroots to `WLR_DEBUG` (`-d` in dwl.c `main()`).

**Not recommended without evidence:** `GBM_BACKEND=nvidia-drm`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `LIBVA_DRIVER_NAME`. No source fetched here supports them for wlroots 0.20.

---

## Open items / uncertainty summary

- **dwl via greetd on tty1 with kmscon on tty2–6:** inferred to work; no primary test found (§2).
- **Steam repo id:** `rpmfusion-nonfree-steam` for F45 is unverified; the Howto page returns 404 (§8).
- **Fedora xdpw `wlroots-portals.conf`:** whether the package ships one is unverified (§3).
- **Man-page details not fetched:** foot server mode, mako/swaylock option names, swayidle syntax, the gamescope `--adaptive-sync` flag name.
- **dwl XWayland build deps on Fedora:** not checked. That's the patch/build owner's area.

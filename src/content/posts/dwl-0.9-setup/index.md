---
slug: dwl-0.9-setup
title: Building a dwl 0.9 desktop on Fedora 45
description: dwl 0.9 from a git subtree with eight patches, slstatus, greetd, kanshi for two VRR monitors, the desktop tools around it, and Steam on NVIDIA.
pubDate: 2026-11-08
tags: [dwl, wayland, fedora, nvidia, gaming]
testedOn: [Fedora 45, dwl 0.9, wlroots 0.20.2, akmod-nvidia 615.78, RTX 5070]
draft: true
---

Part 1 left a Fedora 45 machine at a text console, with RPM Fusion, the codecs and the NVIDIA driver in place. This part turns it into my desktop: [dwl](https://codeberg.org/dwl/dwl) 0.9 with eight patches, a status bar fed by slstatus, a text login screen, both monitors at their full refresh rate, and Steam.

dwl is a port of dwm to Wayland. Like dwm, it has no config file: you change `config.h` and recompile, and extra features come as patches against the source.

## Build dependencies

dwl builds against Fedora's own wlroots 0.20. The bar patch adds `fcft` for font rendering, XWayland support adds two xcb libraries, and slstatus needs Xlib headers even though it never opens an X display:

```bash
sudo dnf install gcc make pkgconf-pkg-config git-subtree stow \
  wlroots-devel wayland-devel wayland-protocols-devel \
  libinput-devel libxkbcommon-devel pixman-devel \
  fcft-devel tllist-devel libxcb-devel xcb-util-wm-devel \
  libX11-devel xorg-x11-server-Xwayland
```

`git subtree` is packaged separately from git on Fedora, hence `git-subtree`.

## Dotfiles with GNU Stow

Everything in this guide lives in one git repository, `~/dotfiles`. Each program's config sits in its own folder, laid out the way it should appear in your home directory, and [GNU Stow](https://www.gnu.org/software/stow/) creates the symlinks:

```txt
~/dotfiles
├── bin/dwl-session                    # copied to /usr/local/bin
├── bin/dwl-idle                       # copied to /usr/local/bin
├── dwl/                               # dwl source tree (git subtree)
├── slstatus/                          # slstatus source tree (git subtree)
├── fonts/.local/share/fonts/maple-mono/
├── foot/.config/foot/foot.ini
├── kanshi/.config/kanshi/config
├── mako/.config/mako/config
├── portal/.config/xdg-desktop-portal/wlroots-portals.conf
├── swaylock/.config/swaylock/config
├── xdpw/.config/xdg-desktop-portal-wlr/config
└── zathura/.config/zathura/zathurarc
```

```bash
git init ~/dotfiles
cd ~/dotfiles
git commit --allow-empty -m "Start dotfiles"
```

Once the config files exist, link them into your home directory by naming the folders:

```bash
stow --no-folding -d ~/dotfiles -t ~ fonts foot kanshi mako portal swaylock xdpw zathura
```

Without `--no-folding`, Stow links whole directories when it can, so `~/.config/foot` itself would point into the repo, and any file a program creates there would show up in `git status`. With it, Stow creates real directories and links only the files.

Leave `dwl`, `slstatus` and `bin` out of that list. They hold source trees and scripts that Stow shouldn't link into your home directory.

## Build dwl 0.9

### Add dwl as a git subtree

A subtree copies dwl's source into a folder of your repository. Your patches and your `config.h` become ordinary commits on top of it, and updating to a new release later is a merge: git only stops where upstream changed the same lines you did. `--squash` keeps dwl's full history out of your log.

```bash
cd ~/dotfiles
git subtree add --prefix=dwl https://codeberg.org/dwl/dwl.git v0.9 --squash
```

### Enable XWayland

dwl builds without XWayland by default. Steam needs it, along with any other X11-only program. Uncomment the two lines in `config.mk`:

```bash
sed -i 's/^#XWAYLAND =/XWAYLAND =/; s/^#XLIBS =/XLIBS =/' dwl/config.mk
git commit -am "dwl: build with XWayland"
```

### Apply the patches

These are the eight patches, all from [dwl-patches](https://codeberg.org/dwl/dwl-patches):

| Patch | What it does | Against v0.9 |
| --- | --- | --- |
| [bar](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/bar) | dwm-style bar with tags, layout, window title and a status text read from stdin | conflicts |
| [autostart](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/autostart) | starts programs listed in `config.h` and stops them when dwl exits | clean |
| [vanitygaps](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/vanitygaps) | gaps between windows and around the screen edge | conflicts |
| [alwayscenter](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/alwayscenter) | centers new floating windows | clean |
| [warpcursor](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/warpcursor) | moves the cursor to the window that gets focus | clean |
| [swapfocus](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/swapfocus) | jumps back to the previously focused window, my replacement for alt-tab | conflicts |
| [swallow](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/swallow) | hides the terminal while a GUI program it started is open | conflicts |
| [fullscreenadaptivesync](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/fullscreenadaptivesync) | enables VRR only while a window is fullscreen | clean alone, conflicts with the others |

Four of them don't apply to the v0.9 tag as published. The bar patch was written against the development branch from before the 0.9 release, and between the two upstream rewrote several of the functions it touches: focus handling, the scene layers (for input-method popups), mouse wheel bindings and click-to-focus for layer surfaces. vanitygaps, swapfocus and swallow conflict with those same upstream changes and with the bar, and fullscreenadaptivesync only conflicts with lines the other patches add next to it.

I ported all eight onto v0.9, one commit per patch with the original author kept, and each one builds without warnings. They're hosted here, under dwl's GPL-3.0 license like the originals:

- [dwl-0.9-patches.mbox](/files/dwl-0.9/dwl-0.9-patches.mbox) has all eight in order.
- Individually: [bar](/files/dwl-0.9/0002-Implement-dwm-bar-clone.patch), [autostart](/files/dwl-0.9/0003-Applied-autostart-patch.patch), [vanitygaps](/files/dwl-0.9/0004-Implement-vanitygaps.patch), [alwayscenter](/files/dwl-0.9/0005-center-floating-windows.patch), [warpcursor](/files/dwl-0.9/0006-warpcursor.patch), [swapfocus](/files/dwl-0.9/0007-swapfocus-patch.patch), [swallow](/files/dwl-0.9/0008-swallow-hide-the-terminal-when-it-spawns-a-client.patch), [fullscreenadaptivesync](/files/dwl-0.9/0009-fullscreenadaptivesync-refactor-for-d16036e.patch).

The paths inside the patches are relative to dwl's root, so `--directory=dwl` points them at the subtree folder:

```bash
curl -LO https://ahlaulhee.pages.dev/files/dwl-0.9/dwl-0.9-patches.mbox
git am -3 --directory=dwl dwl-0.9-patches.mbox
```

What changed while porting, in case you want to port them yourself or check my work:

- **bar.** I kept every upstream change and put the bar on top. One merge went wrong without any conflict marker: git placed the bar's new `click` field in the `Axis` struct that 0.9 added right above `Button`, because the two structs look the same. It belongs in `Button`. The bar also needed a NULL check in `xytonode()`, since the bar is a plain buffer with no surface behind it and clicking it would otherwise crash.
- **autostart.** The `main` version applies cleanly, but it's a bare diff with no author header, so `git am` refuses it. I applied it with `git apply -3` and credited the author of the other autostart patches.
- **vanitygaps.** dwl 0.9 rewrote the key table to use the base keysym of each key (`XKB_KEY_h` instead of `XKB_KEY_H`), so I rewrote the patch's sixteen bindings the same way.
- **swapfocus.** The current version targets a newer `focusclient()` than 0.9 has, so I used the 0.8 file. It also dereferenced a NULL pointer when you pressed the key before any second window had been focused, which crashed dwl. That has a guard now.
- **swallow.** 0.9 removed the `resize` field from `Client` and added an argument to `pointerfocus()`. The patch also read an xdg-shell-only field on X11 windows, which is undefined behaviour; it now skips that check for X11 windows.
- **fullscreenadaptivesync** already targets 0.9. Its conflicts were only lines next to what vanitygaps and swallow added.

### My config.h

`make` creates `config.h` from `config.def.h` when it's missing, and dwl's `.gitignore` lists `config.h`. Copy it, then force-add it so your settings are tracked:

```bash
cp dwl/config.def.h dwl/config.h
git add -f dwl/config.h
```

These are the parts I change. The colors are the [Paradise](https://github.com/paradise-theme/paradise) palette, the same one this site uses:

```c title="dwl/config.h"
static const unsigned int borderpx         = 2;  /* border pixel of windows */
static const char *fonts[]                 = {"Maple Mono:size=11"};
static const float rootcolor[]             = COLOR(0x151515ff);
static uint32_t colors[][3]                = {
	/*               fg          bg          border    */
	[SchemeNorm] = { 0xa39d9dff, 0x151515ff, 0x424242ff },
	[SchemeSel]  = { 0x151515ff, 0xe8e3e3ff, 0x8da3b9ff },
	[SchemeUrg]  = { 0x151515ff, 0xb66467ff, 0xb66467ff },
};
```

The autostart list replaces a separate startup script. Each program ends with a `NULL`, and an extra `NULL` ends the list. The patch's example entry runs `wbg`, which isn't installed, so replace it:

```c title="dwl/config.h"
static const char *const autostart[] = {
	"dbus-update-activation-environment", "--systemd", "WAYLAND_DISPLAY", "DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", NULL,
	"kanshi", NULL,
	"swaybg", "-c", "151515", NULL,
	"mako", NULL,
	"/usr/libexec/lxqt-policykit-agent", NULL,
	"wl-paste", "--watch", "cliphist", "store", NULL,
	"/usr/local/bin/dwl-idle", NULL,
	NULL /* terminate */
};
```

The first line hands dwl's environment to systemd and D-Bus. Without it, the screen-sharing portal doesn't know which display to capture. The command comes from `dbus-tools`, which a Custom Operating System install doesn't include; it's in the package list further down. `swaybg -c` paints a plain Paradise background; use `-i /path/to/image.png -m fill` for a wallpaper. `dwl-idle` is a short swayidle script, covered in [Locking, screens off, and games](#locking-screens-off-and-games).

The swallow patch adds a rule that marks foot as the terminal. Keep it, since it is what tells swallow which windows to hide:

```c title="dwl/config.h"
static const Rule rules[] = {
	/* app_id             title       tags mask     isfloating   isterm   noswallow   monitor */
	{ "foot",             NULL,       0,            0,           1,       1,          -1 },
};
```

### Keybinds

I use Super as the modifier, so it never clashes with shortcuts inside programs:

```c title="dwl/config.h"
#define MODKEY WLR_MODIFIER_LOGO
```

That breaks something in vanitygaps: its bindings use `MODKEY|WLR_MODIFIER_LOGO`, which collapses to plain Super. dwl takes the first match in `keys[]`, so Super+0 would toggle gaps instead of showing all tags. I moved every gap binding from `WLR_MODIFIER_LOGO` to `WLR_MODIFIER_ALT`, which makes them Super+Alt.

Then the commands and the bindings I add on top of dwl's defaults:

```c title="dwl/config.h"
static const char *termcmd[] = { "foot", NULL };
static const char *menucmd[] = { "wmenu-run", "-f", "Maple Mono 11",
	"-N", "151515", "-n", "a39d9d", "-M", "151515", "-m", "8da3b9", "-S", "e8e3e3", "-s", "151515", NULL };
static const char *lockcmd[] = { "swaylock", "-f", NULL };
static const char *filescmd[] = { "foot", "-e", "nnn", NULL };

static const Key keys[] = {
	{ MODKEY,                    XKB_KEY_p,      spawn, {.v = menucmd} },
	{ MODKEY,                    XKB_KEY_n,      spawn, {.v = filescmd} },
	{ MODKEY,                    XKB_KEY_Escape, spawn, {.v = lockcmd} },
	{ MODKEY,                    XKB_KEY_v,      spawn, SHCMD("cliphist list | wmenu -l 10 -f 'Maple Mono 11' | cliphist decode | wl-copy") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_s,      spawn, SHCMD("grim -g \"$(slurp)\" - | wl-copy") },
	{ 0,                         XKB_KEY_Print,  spawn, SHCMD("grim \"$HOME/Pictures/$(date +%F_%H-%M-%S).png\"") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_x,      spawn, SHCMD("grimpicker --copy --notify") },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_i,      spawn, SHCMD("pkill -x swayidle && notify-send 'Idle' 'Lock and screen-off disabled' "
		"|| { /usr/local/bin/dwl-idle & notify-send 'Idle' 'Lock and screen-off enabled'; }") },
	{ 0, XKB_KEY_XF86AudioRaiseVolume, spawn, SHCMD("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+") },
	{ 0, XKB_KEY_XF86AudioLowerVolume, spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
	{ 0, XKB_KEY_XF86AudioMute,        spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
	/* ...dwl's default bindings follow */
```

| Keys | Action |
| --- | --- |
| Super+p | launcher (wmenu) |
| Super+Shift+Return | terminal |
| Super+n | nnn in a terminal |
| Super+v | pick an entry from the clipboard history |
| Super+Shift+s | screenshot of a region, to the clipboard |
| Print | screenshot of everything, to `~/Pictures` |
| Super+Shift+x | pick a color, copy its hex code |
| Super+Escape | lock the screen |
| Super+Shift+i | turn the automatic lock and screen-off off or back on |
| Super+s | back to the previous window (swapfocus) |
| Super+b | show or hide the bar |
| Super+a, Super+Shift+a | swallow the focused window, toggle automatic swallowing |
| Super+F5 | toggle fullscreen VRR |
| Super+Alt+0 | toggle gaps |
| Super+scroll | volume |

The rest are dwl's defaults: Super+j/k to move focus, Super+h/l to resize the master area, Super+1 to 9 for tags, Super+Shift+c to close a window, Super+Shift+q to quit.

Commit the config:

```bash
git add -f dwl/config.h
git commit -m "dwl: my config.h"
```

### Build and install

```bash
make -C dwl
sudo make -C dwl install
```

That installs `/usr/local/bin/dwl`, its man page and a session file. Every time you change `config.h`, run both commands again.

### Updating to the next dwl release

When dwl 0.10 comes out, pull it into the subtree:

```bash
git subtree pull --prefix=dwl https://codeberg.org/dwl/dwl.git v0.10 --squash
```

Git merges the new release with your patch commits and stops only on lines both sides changed. Your `config.h` doesn't update by itself, so compare it against the new `config.def.h` for new options:

```bash
diff dwl/config.def.h dwl/config.h
```

## Status bar with slstatus

The bar patch draws whatever text arrives on dwl's standard input, one line at a time. [slstatus](https://tools.suckless.org/slstatus/) prints exactly that with `-s`. It isn't packaged in Fedora, so it goes into the dotfiles the same way as dwl:

```bash
git subtree add --prefix=slstatus https://git.suckless.org/slstatus 1.1 --squash
cp slstatus/config.def.h slstatus/config.h
```

My bar shows CPU and memory usage and the date:

```c title="slstatus/config.h"
static const struct arg args[] = {
	/* function format          argument */
	{ cpu_perc, "cpu %s%%  ",   NULL },
	{ ram_perc, "ram %s%%  ",   NULL },
	{ datetime, "%s ",          "%a %d %b %H:%M" },
};
```

```bash
git add -f slstatus/config.h
git commit -m "slstatus: my config.h"
make -C slstatus
sudo make -C slstatus install
slstatus -s -1
```

The last command prints one status line and exits. The list of available components is at the top of `config.def.h`.

## Log in with greetd and tuigreet

[greetd](https://git.sr.ht/~kennylevinsen/greetd) is a small login daemon and tuigreet is a text greeter for it:

```bash
sudo dnf install greetd tuigreet
```

dwl doesn't set the desktop name that the portals look for, and something has to start slstatus and connect it to dwl. A short wrapper script does both:

```sh title="~/dotfiles/bin/dwl-session"
#!/bin/sh
export XDG_CURRENT_DESKTOP=wlroots
export XDG_SESSION_DESKTOP=wlroots
export XDG_SESSION_TYPE=wayland

slstatus -s | dwl
```

```bash
sudo install -m 755 ~/dotfiles/bin/dwl-session /usr/local/bin/dwl-session
```

Fedora's `xdg-desktop-portal-wlr` package ships `/usr/share/xdg-desktop-portal/wlroots-portals.conf`, which applies when `XDG_CURRENT_DESKTOP=wlroots`. It sends screenshots and screen sharing to the wlr portal and everything else to the GTK one, except the Settings portal, which it gives to darkman. Nothing installs darkman, so programs that ask the portal for the dark or light preference get no answer. A copy of the file in your home directory takes precedence:

```ini title="~/dotfiles/portal/.config/xdg-desktop-portal/wlroots-portals.conf"
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.Settings=gtk
```

Replace the default session in `/etc/greetd/config.toml`. Fedora runs the greeter as the `greetd` user:

```toml title="/etc/greetd/config.toml"
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd /usr/local/bin/dwl-session"
user = "greetd"
```

Fedora 45 uses kmscon for its text consoles, and Fedora's greetd service already declares a conflict with kmscon on tty1, so kmscon steps aside there and keeps the other consoles. To try dwl by hand from a console before enabling greetd, start it through `kmscon-launch-gui`, which makes kmscon release the screen first:

```bash
kmscon-launch-gui dwl-session
```

When that works, enable greetd and make the system boot into it:

```bash
sudo systemctl enable greetd.service
sudo systemctl set-default graphical.target
```

## Two monitors with kanshi

dwl's `monrules` can set scale and position but not the refresh rate, so without help both monitors come up at whatever mode they prefer. [kanshi](https://git.sr.ht/~emersion/kanshi) sets modes through the output management protocol, which dwl implements. It is already in the autostart list; it needs a config. Get the output names from inside dwl:

```bash
sudo dnf install kanshi wlr-randr
wlr-randr
```

My 24" 1080p monitor is on the left and the 27" 1440p one on the right:

```txt title="~/dotfiles/kanshi/.config/kanshi/config"
profile desk {
	output DP-2 mode 1920x1080@144Hz position 0,0
	output DP-1 mode 2560x1440@240Hz position 1920,0
}
```

Use the names `wlr-randr` printed. If they change between boots, kanshi also accepts the monitor's `"Make Model Serial"` string from the same output. If kanshi doesn't apply a mode, write the refresh rate exactly as `wlr-randr` lists it (for example `239.970Hz`). `adaptive_sync` is left out on purpose; VRR is covered in the gaming section.

## NVIDIA environment variables

I started dwl with no extra environment variables and only add one when it fixes something I can see. dwl 0.9 supports explicit sync (`linux-drm-syncobj`), and the wlroots 0.20 documentation has no NVIDIA-specific advice.

If something looks wrong, these are the [wlroots variables](https://gitlab.freedesktop.org/wlroots/wlroots/-/raw/0.20/docs/env_vars.md) that match the usual symptoms. Try them one at a time:

| Symptom | Variable |
| --- | --- |
| Cursor invisible, offset or flickering | `WLR_NO_HARDWARE_CURSORS=1` |
| Freezes or flicker that look like sync problems, `drm_syncobj` errors in the log | `WLR_RENDER_NO_EXPLICIT_SYNC=1` |
| Black screen or modeset failure on the high refresh rate monitor | `WLR_DRM_NO_MODIFIERS=1` |

To see what dwl is doing, start it with debug logging, `dwl -d 2> ~/dwl.log`. Anything that helps goes into `dwl-session` before the `slstatus -s | dwl` line, with a comment that says what it fixed.

## The rest of the desktop

```bash
sudo dnf install foot wmenu swaybg mako libnotify swaylock swayidle \
  wl-clipboard cliphist grim slurp grimpicker \
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk lxqt-policykit xdg-user-dirs \
  nnn zathura zathura-pdf-mupdf imv mpv neovim NetworkManager-tui \
  wlopm google-noto-color-emoji-fonts dbus-tools
xdg-user-dirs-update
```

| Package | Role |
| --- | --- |
| `foot` | terminal, dwl's default |
| `wmenu` | launcher; `wmenu-run` lists everything in `$PATH` |
| `swaybg` | background |
| `mako`, `libnotify` | notifications, and `notify-send` to test them |
| `swaylock`, `swayidle`, `wlopm` | lock screen after ten minutes idle, monitors off after fifteen |
| `wl-clipboard`, `cliphist` | `wl-copy`/`wl-paste` (Neovim uses them for the system clipboard) and the clipboard history behind Super+v |
| `grim`, `slurp` | screenshots, whole screen or a selected region |
| `grimpicker` | color picker; Fedora builds it from sway-contrib as its own package, without sway |
| `xdg-desktop-portal-wlr`, `-gtk` | screen sharing in browsers, Discord and OBS, plus file pickers |
| `lxqt-policykit` | password prompts for programs that ask polkit for privileges |
| `nnn`, `zathura`, `imv`, `mpv` | files, PDFs, images, video |
| `NetworkManager-tui` | `nmtui`, a menu for Wi-Fi and network connections |

PipeWire and WirePlumber came with `@multimedia` in part 1. `wpctl`, from WirePlumber, is what the volume keys call.

`xdg-user-dirs-update` creates `~/Pictures` and the other standard folders; the Print binding saves there.

### Locking, screens off, and games

swayidle runs from a small script, so the autostart entry and the toggle key start exactly the same thing:

```sh title="~/dotfiles/bin/dwl-idle"
#!/bin/sh
# lock after 10 minutes, monitors off after 15, lock before suspend
exec swayidle -w \
	timeout 600 'swaylock -f' \
	timeout 900 "wlopm --off '*'" resume "wlopm --on '*'" \
	before-sleep 'swaylock -f'
```

```bash
sudo install -m 755 ~/dotfiles/bin/dwl-idle /usr/local/bin/dwl-idle
```

`wlopm` turns the monitors off through the output power protocol, which dwl implements. `wlr-randr --off` looks similar, but dwl treats it as an unplugged monitor and moves its windows to the other screen.

swayidle only counts keyboard and mouse input that goes through dwl as activity. A game played with a controller reads the controller directly, so after ten minutes of only using the gamepad the screen locks in the middle of the game. Video players and browsers avoid this by asking the compositor not to go idle, but dwl only honours that request while the window asking is visible. Turn that off in `config.h`, so a video on another tag or monitor also keeps the screen awake:

```c title="dwl/config.h"
static const int bypass_surface_visibility = 1;  /* 1 means idle inhibitors will disable idle tracking even if it's surface isn't visible  */
```

For games, Super+Shift+i kills swayidle, which stops both the lock and the screen-off, and starts it again on the next press. A notification says which state you're in. `systemd-inhibit --what=idle` would be the obvious tool for this, but swayidle 1.9.0, the version in Fedora 45, fails to read logind's inhibitors ([swayidle#198](https://github.com/swaywm/swayidle/issues/198)), so it ignores them.

### Screen sharing

When a browser, Discord or OBS asks to share the screen, xdg-desktop-portal-wlr needs a way to ask you which monitor or window. I use wmenu for that, and cap the stream at 60 fps so the 240 Hz monitor doesn't send four times what a video call can use:

```ini title="~/dotfiles/xdpw/.config/xdg-desktop-portal-wlr/config"
[screencast]
max_fps=60
chooser_type=dmenu
chooser_cmd=wmenu -p 'Share:' -l 10 -f 'Maple Mono 11'
```

Restart the portal after changing it: `systemctl --user restart xdg-desktop-portal-wlr`.

Fedora 45 ships xdg-desktop-portal-wlr 0.8.4, which has two open regressions: the stream freezing after the first frame ([#411](https://github.com/emersion/xdg-desktop-portal-wlr/issues/411)) and sharing failing with "No supported targets specified" ([#409](https://github.com/emersion/xdg-desktop-portal-wlr/issues/409)). Both reports say 0.8.2 works. If you hit one, those issues are where fixes and workarounds show up.

## A font for the desktop

The site uses Geist, but on the desktop I use [Maple Mono](https://github.com/subframe7536/maple-font): rounded, with a cursive italic, under the OFL license. It isn't packaged in Fedora, so it goes into the dotfiles as a Stow package. The `TTF` archive has the static weights; check it against the published checksum before unpacking:

```bash
mkdir -p ~/dotfiles/fonts/.local/share/fonts/maple-mono
cd /tmp
curl -LO https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-TTF.zip
curl -LO https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-TTF.sha256
echo "$(cat MapleMono-TTF.sha256)  MapleMono-TTF.zip" | sha256sum -c
unzip MapleMono-TTF.zip -d ~/dotfiles/fonts/.local/share/fonts/maple-mono
stow --no-folding -d ~/dotfiles -t ~ fonts
fc-cache -f
fc-match "Maple Mono"
```

The last command should print `MapleMono-Regular.ttf: "Maple Mono" "Regular"`. The bar, foot, wmenu, mako and swaylock all find it by that name through fontconfig. In foot the cursive italic shows up, but the ligatures don't: `->` and `!=` stay as separate characters.

## Paradise everywhere

The bar and the launcher get their colors from `config.h`. The other programs read their own config files, all from the dotfiles through Stow.

foot 1.28 calls the color section `colors-dark`:

```ini title="~/dotfiles/foot/.config/foot/foot.ini"
[main]
font=Maple Mono:size=12
pad=12x12

[cursor]
style=beam

[colors-dark]
background=151515
foreground=e8e3e3
regular0=151515
regular1=b66467
regular2=8c977d
regular3=d9bc8c
regular4=8da3b9
regular5=a988b0
regular6=8aa6a2
regular7=e8e3e3
bright0=424242
bright1=b66467
bright2=8c977d
bright3=d9bc8c
bright4=8da3b9
bright5=a988b0
bright6=8aa6a2
bright7=e8e3e3
```

`foot --check-config` validates the file.

```ini title="~/dotfiles/mako/.config/mako/config"
font=Maple Mono 11
background-color=#151515
text-color=#e8e3e3
border-color=#424242
border-size=2
default-timeout=5000

[urgency=critical]
border-color=#b66467
default-timeout=0
```

```ini title="~/dotfiles/swaylock/.config/swaylock/config"
color=151515
inside-color=151515
ring-color=424242
line-color=151515
separator-color=151515
key-hl-color=8da3b9
bs-hl-color=b66467
ring-ver-color=d9bc8c
ring-wrong-color=b66467
text-color=e8e3e3
indicator-radius=80
font=Maple Mono
```

For zathura I use the [Paradise zathurarc](https://github.com/paradise-theme/paradise/blob/main/cfg/zathura/zathurarc) as it is, with the font line changed to `set font "Maple Mono 11"`.

## Gaming

Steam is in RPM Fusion's nonfree repository, which part 1 enabled. gamescope, MangoHud and GameMode are in Fedora:

```bash
sudo dnf install steam gamescope mangohud gamemode
```

Steam runs through XWayland, which is why dwl was built with it. The 32-bit NVIDIA libraries Steam needs came with the driver in part 1; `rpm -q xorg-x11-drv-nvidia-libs.i686` confirms it.

Steam's launch options for a game take these tools as prefixes before `%command%`:

| Launch option | Effect |
| --- | --- |
| `gamemoderun %command%` | GameMode tunes the CPU governor and scheduling while the game runs |
| `mangohud %command%` | FPS, frame times and GPU temperature overlay |
| `gamescope -W 2560 -H 1440 -r 240 --adaptive-sync -- %command%` | runs the game in its own nested compositor at the 27" monitor's resolution and refresh rate |

Inside gamescope, use its `--mangoapp` flag instead of `mangohud`.

For VRR, the fullscreenadaptivesync patch enables adaptive sync on a monitor when a window goes fullscreen there and disables it when the window leaves fullscreen. Super+F5 turns that behaviour off. On NVIDIA there is a catch: the driver's README says its KMS implementation "forces all VRR capable displays into VRR mode by default", so the monitor may run in VRR mode on the desktop too, whatever dwl asks for. Watch the refresh rate counter in the monitor's on-screen menu: if it moves around on the desktop, the driver is doing it. The `conceal_vrr_caps=1` option of the `nvidia_modeset` module stops that, but it hides VRR from dwl as well, so games lose it too.

## Where this leaves you

dwl starts from greetd with both monitors at their full refresh rate, the bar shows slstatus, and the tools around it share one palette. All of it lives in `~/dotfiles`: dwl and slstatus as subtrees with their patches and `config.h` as commits, and the configs as Stow packages.

Part 3 covers my Neovim config.

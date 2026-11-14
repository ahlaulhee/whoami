---
slug: mango-0.18-setup
title: Building a Mango desktop on Fedora 45
description: Mango 0.18 with the scrolling layout on every tag, a Quickshell bar, menu, lock screen and greeter, kew for music, yazi for files, fish with the pure prompt, both monitors at full refresh, and Steam on NVIDIA.
pubDate: 2026-11-08
updatedDate: 2026-11-14
tags: [mango, wayland, quickshell]
testedOn: [Fedora 45, Mango 0.18.5, Quickshell 0.3.2, fish 4.6, yazi 26.9, akmod-nvidia 615.78, RTX 5070]
series:
  name: Fedora 45 + Mango from scratch
  part: 2
draft: false
---

Part 1 left a Fedora 45 machine at a text console, with RPM Fusion, the codecs and the NVIDIA driver in place. This part turns it into my desktop: [Mango](https://github.com/mangowm/mango) 0.18 with the scrolling layout on every tag, a status bar, a menu, a lock screen and a login screen written in [Quickshell](https://quickshell.org/), kew for music, yazi for files, both monitors at their full refresh rate, and Steam.

Mango started as a fork of dwl and keeps its model: tags instead of workspaces, one set per monitor, nothing around it you didn't install. Unlike dwl it reads a config file that applies as soon as you save it, and it ships layouts dwl doesn't have. The one I use everywhere is the scroller: windows sit side by side in a strip that can be wider than the screen, and moving focus slides the strip.

## Install Mango

Mango isn't in Fedora's repositories. Its documentation installs it from [Terra](https://terra.fyralabs.com/), a third-party repository. The first command installs Terra's repository file and signing key; `--nogpgcheck` applies only to that step, and from then on dnf checks every Terra package against the key it just installed:

```bash
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
sudo dnf install mangowm xorg-x11-server-Xwayland
```

Mango comes from Terra, but wlroots 0.20 and scenefx 0.5, the two libraries it builds on, come from Fedora. The package doesn't depend on XWayland, which is why it's in the same command; Steam and other X11 programs need it.

## Dotfiles with GNU Stow

All the configuration lives in one git repository, `~/dotfiles`. Each program gets a folder laid out the way it should appear in your home directory, and [GNU Stow](https://www.gnu.org/software/stow/) creates the symlinks:

```txt
~/dotfiles
├── bin/mango-{greeter,idle,lock,tag}             # copied to /usr/local/bin
├── firefox/chrome/{userChrome,userContent}.css   # linked by hand, see Firefox
├── fish/.config/fish/{config.fish,fish_plugins}
├── fonts/.local/share/fonts/maple-mono/
├── foot/.config/foot/foot.ini
├── greetd/{config.toml,greeter.qml}              # copied to /etc/greetd
├── grub/                                         # theme, installed by grub/install.sh
├── kew/.config/kew/themes/paradise.theme
├── local-bin/.local/bin/{cliphist-store,keymaps,spotify,stremio}
├── local-bin/.local/share/keymaps/yazi-keymap-default.toml
├── mango/.config/mango/config.conf
├── mime/.config/mimeapps.list
├── mime/.local/share/applications/foot-{nvim,yazi}.desktop
├── quickshell/.config/quickshell/{shell,Menu,Keymaps,lock}.qml
├── wallpaper/.local/share/wallpapers/wallpaper.jpg
├── wireplumber/.config/wireplumber/wireplumber.conf.d/
├── xdpw/.config/xdg-desktop-portal-wlr/config
├── yazi/.config/yazi/theme.toml
└── zathura/.config/zathura/zathurarc
```

```bash
sudo dnf install stow
git init ~/dotfiles
```

Once the files exist, link them by naming the folders:

```bash
stow --no-folding -d ~/dotfiles -t ~ fish fonts foot kew local-bin mango mime quickshell wallpaper wireplumber xdpw yazi zathura
```

Without `--no-folding`, Stow links whole directories when it can, so `~/.config/mango` itself would point into the repo and any file a program creates there would show up in `git status`. With it, Stow creates real directories and links only the files.

Four folders stay out of the list, because their files go outside your home directory or into a folder whose name Stow can't know:

| Folder | Goes to | With |
| --- | --- | --- |
| `bin` | `/usr/local/bin` | `sudo install -m 755 ~/dotfiles/bin/* /usr/local/bin/` |
| `greetd` | `/etc/greetd` | `sudo install -m 644 ~/dotfiles/greetd/* /etc/greetd/` |
| `grub` | `/boot/grub2/themes/paradise` | `sudo ~/dotfiles/grub/install.sh` |
| `firefox` | the Firefox profile | a symlink made by hand |

Each has its own section below. The first three are copies, so run the command again after changing one of those files in the repository.

My repository isn't public. Every file this guide uses is printed in full or linked next to the section that explains it.

## Configure Mango

Mango reads `~/.config/mango/config.conf`, one `key=value` per line, and reapplies it every time you save. I wrote mine from scratch rather than starting from the 200-line example in `/etc/mango/config.conf`; these are its parts, and the whole file is [here](/files/mango-0.18/config.conf).

### Monitors

`monitor_rule` sets the mode, refresh rate, position and VRR for each output. The name is a regular expression, so anchor it. My 24" 1080p monitor is on the left and the 27" 1440p one on the right:

```ini title="~/dotfiles/mango/.config/mango/config.conf"
monitor_rule=name:^DP-1$,width:1920,height:1080,refresh:144,x:0,y:0,scale:1,vrr:0
monitor_rule=name:^DP-2$,width:2560,height:1440,refresh:240,x:1920,y:0,scale:1,vrr:0,primary:1
```

Replace `DP-1` and `DP-2` with the names `mmsg get all-monitors` or `wlr-randr` prints. Keep both coordinates non-negative; negative positions break input in XWayland windows. `primary:1` marks the 27" as the primary output for X11 programs, which is where fullscreen X11 games open. `vrr:0` is deliberate: VRR comes on only for fullscreen windows, through a window rule further down.

### Tags and the scroller

```ini title="~/dotfiles/mango/.config/mango/config.conf"
tag_num=8
tag_rule=id:*,layout_name:scroller
circle_layout=scroller,tile,monocle
monocle_tab_mode=0

# new windows take 80% of the width; Super+r cycles through the presets
scroller_default_proportion=0.8
scroller_proportion_preset=0.5,0.8,1.0
# a lone window fills the screen
scroller_ignore_proportion_single=1
# scroll only as far as needed to show the focused column
scroller_prefer_overspread=0
scroller_focus_center=0
scroller_prefer_center=0
```

`tag_rule=id:*` applies the scroller to every tag on both monitors. New windows open at 80% of the screen width, so the neighbouring window always shows at the edge. With the last three options at 0, the strip scrolls only as far as it takes to show the focused column, so two columns that fit on the screen together, such as two at 50%, stay side by side instead of the focused one moving to the centre. Super+Shift+space still switches a tag to `tile` or `monocle` when a scrolling strip isn't what you want. Monocle normally draws a tab bar over its windows, in Mango's own colors and with rounded corners; `monocle_tab_mode=0` turns it off.

### Tags on each monitor

Each monitor in Mango has its own set of tags, and Super+N normally acts on the monitor that has focus. I want the number to decide the screen instead: tags 1 to 4 on the 27" and 5 to 8 on the 24". `tag_num=8` drops the ninth.

Super+Shift+N uses `tagcrossmon`, which moves the window to that tag on the right monitor and follows it there. Super+N goes through a short script. It shows the tag on its monitor with `viewcrossmon`, and pressing the number of the tag that's already on the focused monitor goes back to the tag that monitor showed before. Mango has an option for that, `view_current_to_back`, but it also remembers the tag 1 every monitor starts on, and would send the 24" to it, a tag that belongs to the other screen. The script keeps the previous tag itself, in one small file per monitor under `$XDG_RUNTIME_DIR`:

```sh title="~/dotfiles/bin/mango-tag"
#!/bin/sh
# Show tag $1 on the monitor that owns it: 1-4 on the 27" (DP-2), 5-8 on the
# 24" (DP-1). The number of the tag already on the focused monitor goes
# back to the tag that monitor showed before. The previous tag is kept here,
# per monitor, instead of with view_current_to_back, which also remembers the
# tag 1 every monitor starts on and would send the 24" there.
case $1 in
[1-4]) mon=DP-2 ;;
[5-8]) mon=DP-1 ;;
*) exit 1 ;;
esac
state="${XDG_RUNTIME_DIR:-/tmp}/mango-tag-$mon"
focused=$(mmsg get all-monitors | jq -r '.monitors[] | select(.active) | .name')
current=$(mmsg get tags "$mon" | jq -r '[.tags[] | select(.is_active) | .index][0]')
target=$1
if [ "$current" = "$1" ] && [ "$focused" = "$mon" ]; then
	target=$(cat "$state" 2>/dev/null)
	[ -n "$target" ] || exit 0
fi
# Remember the tag being left, unless it belongs to the other monitor.
if [ "$target" != "$current" ]; then
	case $mon:$current in
	DP-2:[1-4] | DP-1:[5-8]) echo "$current" >"$state" ;;
	esac
fi
exec mmsg dispatch viewcrossmon,"$target","$mon"
```

```bash
sudo install -m 755 ~/dotfiles/bin/mango-tag /usr/local/bin/
```

Mango starts every monitor on tag 1; a line in [Autostart](#autostart) moves the 24" to tag 5. Replace `DP-1` and `DP-2` there, in the script, in the keybinds and in the Discord rule under [Window rules](#window-rules) with the names from your monitor rules. The greeter's script and the bar name a monitor too; their sections say where.

### Look

```ini title="~/dotfiles/mango/.config/mango/config.conf"
border_px=2
border_radius=0
gap_inner_horizontal=5
gap_inner_vertical=5
gap_outer_horizontal=10
gap_outer_vertical=10
root_color=0x151515ff
border_color=0x424242ff
focus_color=0x8da3b9ff
urgent_color=0xb66467ff
scratchpad_color=0xa988b0ff
global_color=0x8aa6a2ff
overlay_color=0xd9bc8cff
maximized_screen_color=0x8c977dff

jump_label_decorate_fg_color=0xe8e3e3ff
jump_label_decorate_bg_color=0x151515ff
jump_label_decorate_focus_fg_color=0x151515ff
jump_label_decorate_focus_bg_color=0x8da3b9ff
jump_label_decorate_border_color=0x424242ff
jump_label_decorate_border_width=2
jump_label_decorate_corner_radius=0
jump_label_decorate_font_desc=Maple Mono Bold 16

# windows fade, the scroller and tag switches slide, all in 150 ms
animations=1
layer_animations=0
animation_type_open=fade
animation_type_close=fade
animation_duration_move=150
animation_duration_open=150
animation_duration_close=150
animation_duration_tag=150
animation_duration_focus=0
tag_animation_direction=1
blur=0
blur_layer=0
shadows=0
layer_shadows=0
```

The colors are the [Paradise](https://github.com/paradise-theme/paradise) palette, the one this site uses, written as `0xRRGGBBAA`. The four after `urgent_color` are the borders of windows in the scratchpad, pinned to every tag, kept above the rest or maximized, all states the keybinds below put a window in. The `jump_label_decorate_*` lines style the letters that jump mode puts over each window.

Mango draws through scenefx, which can round corners and add blur, shadows and animations. I keep short animations and turn the rest off. Windows fade in and out, and the scroller and the switch between tags slide, all in 150 ms with Mango's default curve; `tag_animation_direction=1` makes tags slide sideways. `layer_animations=0` leaves out layer surfaces, so the bar, the menu, the notifications and slurp's selection appear at once. Rounded corners come out jagged on NVIDIA's driver ([mango#1387](https://github.com/mangowm/mango/issues/1387)), so `border_radius=0` is more than taste.

### Focus and mouse

```ini title="~/dotfiles/mango/.config/mango/config.conf"
sloppy_focus=0
warp_cursor=1
enable_border_resize=0
```

With `sloppy_focus=0`, moving the pointer over a window doesn't give it the focus; a click or the keyboard does. `warp_cursor=1` moves the pointer to the window that takes the focus, so after a keyboard move the two are in the same place. Mango also resizes a window when you drag its border, which I turn off: the border took clicks meant for a scrollbar at the window's edge. Super+right drag and Super+r still resize.

### Autostart

```ini title="~/dotfiles/mango/.config/mango/config.conf"
exec_once=swaybg -c 151515 -i ~/.local/share/wallpapers/wallpaper.jpg -m fill
exec_once=wl-clip-persist --clipboard regular
exec_once=wl-paste --watch ~/.local/bin/cliphist-store
exec_once=/usr/local/bin/mango-idle
exec_once=qs
exec_once=discord
exec_once=mmsg dispatch viewcrossmon,5,DP-1; mmsg dispatch focusmon,DP-2; firefox
```

`exec_once` runs a command once at login, and `exec` runs it again on every reload. Mango exports its environment to systemd and D-Bus and starts a `mango-session.target` by itself, so nothing here does that; the screen-sharing portal finds the session without help.

`swaybg` draws the wallpaper. The image is the only file of the `wallpaper` Stow package, so put any picture at `~/dotfiles/wallpaper/.local/share/wallpapers/wallpaper.jpg`; `-m fill` scales it to cover each monitor, and `-c 151515` is the color you get if the file is missing. `qs` is Quickshell, which draws the status bar, the menu, the volume OSD, the notifications and the polkit password prompt. `wl-clip-persist` keeps what you copied after the program you copied it from closes. `cliphist-store` records every copy in the clipboard history except passwords; it's covered in [Clipboard history](#clipboard-history). `mango-idle` is a short script covered in [Locking, screens off, and games](#locking-screens-off-and-games).

The last line moves the 24" to tag 5, the first of its tags, gives focus back to the 27" and only then starts Firefox, which opens where the focus is: tag 1 of the 27". The `;` instead of `&&` starts Firefox even if `mmsg` fails. Discord gets its place from a window rule instead, so it doesn't matter which of the two opens first.

### Window rules

```ini title="~/dotfiles/mango/.config/mango/config.conf"
window_rule=is_term:1,app_id:^foot$
window_rule=vrr_only_fullscreen:1,app_id:.*
window_rule=is_floating:1,app_id:^steam$,title:^(Friends List|Steam Settings)$
window_rule=confine_pointer:1,app_id:^steam_app_.*$
window_rule=idle_inhibit_when_focus:1,app_id:^(steam_app_.*|gamescope)$
window_rule=no_animation:1,app_id:^(steam_app_.*|gamescope)$
window_rule=is_tag_silent:1,app_id:^(steam|discord)$
window_rule=tags:5,monitor:DP-1,is_open_silent:1,app_id:^discord$

# to try: tearing in fullscreen games
#allow_tearing=2
#window_rule=force_tearing:1,app_id:^steam_app_.*$
#env=WLR_DRM_NO_ATOMIC,1
```

The first rule marks foot as the terminal. When a graphical program started from foot opens, it takes the terminal's place, and the terminal comes back when the program exits. The second turns VRR on for any window while it's fullscreen; Mango requires an `app_id` or `title` in every rule, so `.*` stands for all of them. Narrow it to `^(steam_app_.*|gamescope)$` if you'd rather keep fullscreen video at a fixed refresh rate. The third floats Steam's friends list and settings window instead of giving them a column.

The next four are for games. Steam starts every game with an app id of `steam_app_` followed by the game's number. `confine_pointer` keeps the cursor inside the game while it has focus, so a mouse flick in a shooter doesn't land on the other monitor. `idle_inhibit_when_focus` keeps the screen from locking or turning off while a game is focused, windowed or not; [Locking, screens off, and games](#locking-screens-off-and-games) explains why that needs help. `no_animation` leaves games out of the animations, so a game's window is never drawn at a size in between. `is_tag_silent` stops Steam and Discord from pulling you to their tag when they ask for attention, such as an update window or a message in the middle of a game. Mango marks their window urgent instead, and the bar shows its tag in red.

The last rule always opens Discord on tag 5 of the 24", and `is_open_silent` keeps it from taking the focus, so at login it doesn't pull you away from Firefox.

The commented lines are tearing, which lets a fullscreen game show a frame as soon as it's ready instead of waiting for the monitor's refresh. It lowers latency, at the cost of a visible line where two frames meet. Mango's documentation says some cards also need `WLR_DRM_NO_ATOMIC`, which changes how Mango drives the monitors. Try it with a game you know before keeping it, and log out and back in after adding the `env` line.

### Keyboard layouts

```ini title="~/dotfiles/mango/.config/mango/config.conf"
xkb_rules_layout=us,latam
```

US comes first, so it's the layout Mango starts with. Super+space switches to Latin American Spanish and back; the bar shows the active one, and `mmsg get keyboardlayout` prints it. `bind` matches the physical key, so the bindings below keep working while latam is active.

### Keybinds

Bindings are `bind=MODIFIERS,key,dispatcher,arguments`. `spawn` runs a program directly, `spawn_shell` runs the line through a shell for pipes and `$(...)`, and `bindl` keeps working on the lock screen. A line that starts with `##` is a comment to Mango. The [keymap cheatsheet](#the-keymap-cheatsheet) reads the binds from this file and takes each of those lines as the name of a category for the binds under it:

```ini title="~/dotfiles/mango/.config/mango/config.conf"
## Programs
bind=SUPER,Return,spawn,foot
bind=SUPER,b,spawn,qs ipc call bar toggle
bind=SUPER,o,spawn,qs ipc call audio next
bind=SUPER,p,spawn,qs ipc call menu run
bind=SUPER,n,spawn,foot -e yazi
bind=SUPER,v,spawn,qs ipc call menu clipboard
bind=SUPER+SHIFT,s,spawn_shell,grim -g "$(slurp)" - | wl-copy
bind=NONE,Print,spawn_shell,grim "$HOME/Pictures/$(date +%F_%H-%M-%S).png"
bind=SUPER+SHIFT,x,spawn,grimpicker --copy --notify
bind=SUPER+SHIFT,i,spawn,qs ipc call idle toggle
bind=SUPER+SHIFT,slash,spawn,qs ipc call keymaps toggle
bindl=SUPER,Escape,spawn,/usr/local/bin/mango-lock

bindl=NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
bindl=NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl=NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
axisbind=SUPER,UP,spawn,wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
axisbind=SUPER,DOWN,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-

## Windows
bind=SUPER,w,killclient,
bind=SUPER+SHIFT,c,killclient,
bind=SUPER,h,focusdir,left
bind=SUPER,l,focusdir,right
bind=SUPER,k,focusdir,up
bind=SUPER,j,focusdir,down
bind=SUPER,Left,focusdir,left
bind=SUPER,Right,focusdir,right
bind=SUPER,Up,focusdir,up
bind=SUPER,Down,focusdir,down
bind=SUPER+SHIFT,h,exchange_client,left
bind=SUPER+SHIFT,l,exchange_client,right
bind=SUPER+SHIFT,k,exchange_client,up
bind=SUPER+SHIFT,j,exchange_client,down
bind=SUPER+CTRL,h,scroller_stack,left
bind=SUPER+CTRL,l,scroller_stack,right
bind=SUPER+CTRL,k,scroller_stack,up
bind=SUPER+CTRL,j,scroller_stack,down
bind=SUPER,s,focuslast,
bind=SUPER,r,switch_proportion_preset,next
bind=SUPER,e,set_proportion,1.0
bind=SUPER,f,togglefullscreen,
bind=SUPER+SHIFT,f,togglefloating,
bind=SUPER+SHIFT,e,togglemaximizescreen,
bind=SUPER,g,toggleglobal,
bind=SUPER+SHIFT,g,toggleoverlay,
bind=SUPER,Tab,togglejump,
mousebind=SUPER,btn_left,moveresize,curmove
mousebind=SUPER,btn_right,moveresize,curresize
drag_tile_to_tile=1

bind=SUPER+SHIFT,minus,minimized,
bind=SUPER,minus,toggle_scratchpad,
bind=SUPER+CTRL,minus,restore_minimized,

## Layouts
bind=SUPER,c,setlayout,scroller
bind=SUPER,t,setlayout,tile
bind=SUPER,m,setlayout,monocle
bind=SUPER+SHIFT,space,switch_layout,
bind=SUPER,space,switch_keyboard_layout,
bind=SUPER+ALT,0,togglegaps,

## Tags
bind=SUPER,1,spawn,/usr/local/bin/mango-tag 1
bind=SUPER+SHIFT,1,tagcrossmon,1,DP-2
# ...the same pair for tags 2 to 4, and for 5 to 8 with DP-1

## Monitors
bind=SUPER,period,focusmon,next
bind=SUPER+SHIFT,period,tagmon,next

## Mango itself
bind=SUPER+SHIFT,r,reload_config
bind=SUPER+SHIFT,q,quit
```

| Keys | Action |
| --- | --- |
| Super+Return | terminal |
| Super+p | menu of programs |
| Super+h/j/k/l, or Super+arrows | focus left, down, up, right, without leaving the monitor |
| Super+Shift+h/j/k/l | move the window in that direction |
| Super+Ctrl+h/j/k/l | stack the window into the neighbouring column, or pull it out |
| Super+r | cycle the window width: 50%, 80%, 100% |
| Super+e | full width |
| Super+s | back to the previous window |
| Super+f | fullscreen |
| Super+Shift+f | float the window, or tile it again |
| Super+Shift+e | maximize the window, keeping the bar |
| Super+g | pin the window to every tag of its monitor, or unpin it |
| Super+Shift+g | draw the window above all others, or stop |
| Super+Tab | jump mode: a letter on every window, press one to go there or Escape to stay |
| Super+Shift+minus | hide the window in the scratchpad |
| Super+minus | show the scratchpad over the current tag, or hide it |
| Super+Ctrl+minus | bring the window back from the scratchpad to the tag |
| Super+w, or Super+Shift+c | close the window |
| Super+drag | left button moves a floating window or swaps two tiled ones; right button resizes |
| Super+space | switch between the US and Latin American layouts |
| Super+Shift+space | cycle scroller, tile and monocle |
| Super+1 to 8, Super+Shift+1 to 8 | view a tag, move the window to a tag; 1 to 4 are on the 27", 5 to 8 on the 24", and the number of the tag on screen goes back to the previous one |
| Super+period | focus the other monitor |
| Super+Shift+period | move the window to the other monitor |
| Super+n | yazi in a terminal |
| Super+v | menu of the clipboard history |
| Super+Shift+s | screenshot of a region, to the clipboard |
| Print | screenshot of everything, to `~/Pictures` |
| Super+Shift+x | pick a color, copy its hex code |
| Super+Escape | lock the screen |
| Super+Shift+i | caffeine: keep the screen from locking or turning off, or stop |
| Super+b | show or hide the bar |
| Super+o | switch to the next audio output |
| Super+Shift+/ | keymap cheatsheet |
| Super+scroll | volume |
| Super+Shift+r | reload the config |

### Check the config

```bash
mango -c ~/.config/mango/config.conf -p
```

No output means the file parsed. Errors print as `[ERROR]` lines with the file and line number, but the exit code is 0 either way, so read the output rather than `$?`.

## Log in with greetd

[greetd](https://git.sr.ht/~kennylevinsen/greetd) is a small login daemon that leaves the login screen to another program, the greeter. Mine is one more Quickshell file, in the style of the lock screen: the time, the date, a field for the user and one for the password. A greeter has no desktop to open a window on, so it runs inside [cage](https://github.com/cage-kiosk/cage), a compositor that shows a single program fullscreen:

```bash
sudo dnf install greetd cage wlr-randr
```

The greeter needs Quickshell, which the [next section](#quickshell-bar-menu-osd-notifications-and-polkit) installs, and the copy of the font that [A font for the desktop](#a-font-for-the-desktop) puts in `/usr/local/share/fonts`. Come back to enable greetd once both are in place.

```qml title="~/dotfiles/greetd/greeter.qml"
// greetd greeter in the style of the lock screen (lock.qml). greetd runs it as
// the greetd user inside cage (see mango-greeter), so it's a plain window that
// cage stretches over the monitor, not a layer surface.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Greetd

ShellRoot {
    id: root
    // Installed in /etc/greetd; there's nothing to reload.
    settings.watchFiles: false

    // Paradise palette
    readonly property color bg: "#151515"
    readonly property color fg: "#e8e3e3"
    readonly property color muted: "#a39d9d"
    readonly property color red: "#b66467"
    readonly property color blue: "#8da3b9"
    readonly property color border: "#424242"

    // Filled in at startup; the field can still be changed.
    readonly property string defaultUser: "ahlaulhe"
    // greetd starts it through /bin/sh and /etc/profile, like tuigreet's --cmd.
    readonly property list<string> session: ["mango"]

    component Label: Text {
        font.family: "Maple Mono"
        font.pointSize: 11
        color: "#e8e3e3"
    }

    // A bordered text field like the lock screen's: red after a failed
    // login, blue while it has the keyboard.
    component Field: Rectangle {
        id: field
        property alias input: input
        property alias text: input.text
        property alias echoMode: input.echoMode
        // Tab moves the keyboard to this field.
        property Item next
        implicitWidth: 360
        implicitHeight: 36
        color: root.bg
        border.width: 2
        border.color: root.failed ? root.red
                    : input.activeFocus ? root.blue : root.border

        TextInput {
            id: input
            anchors.fill: parent
            anchors.margins: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: "Maple Mono"
            font.pointSize: 11
            color: root.fg
            readOnly: root.busy
            onTextChanged: if (text !== "") root.failed = false
            onAccepted: root.login()
            KeyNavigation.tab: field.next
            Keys.onEscapePressed: text = ""
        }
    }

    property bool failed: false
    property string message: ""
    readonly property bool busy: Greetd.state !== GreetdState.Inactive

    function login(): void {
        if (busy || user.text === "" || password.text === "")
            return;
        root.failed = false;
        root.message = "";
        Greetd.createSession(user.text);
    }

    Connections {
        target: Greetd
        // PAM asks for the password; anything else it says goes under the field.
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(password.text);
            else if (error)
                root.message = message;
        }
        function onReadyToLaunch() {
            Greetd.launch(root.session, ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=mango"]);
        }
        function onAuthFailure(message) {
            password.text = "";
            root.failed = true;
        }
        function onError(error) {
            root.message = error;
            Greetd.cancelSession();
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FloatingWindow {
        color: root.bg

        // logind lets the active local session reboot or power off without
        // a password.
        Shortcut {
            sequence: "F11"
            onActivated: Quickshell.execDetached(["systemctl", "reboot"])
        }
        Shortcut {
            sequence: "F12"
            onActivated: Quickshell.execDetached(["systemctl", "poweroff"])
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pointSize: 72
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 36
                text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                color: root.muted
            }
            Field {
                id: user
                text: root.defaultUser
                next: password.input
            }
            Field {
                id: password
                echoMode: TextInput.Password
                next: user.input
                Component.onCompleted: input.forceActiveFocus()
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.busy ? "Checking..."
                    : root.message !== "" ? root.message
                    : root.failed ? "Wrong password"
                    : "Enter to log in, Tab to change user"
                color: (root.failed || root.message !== "") && !root.busy ? root.red : root.muted
            }
        }

        Label {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 18
            text: "F11 reboot   F12 power off"
            color: root.muted
        }
    }
}
```

Quickshell's `Greetd` service talks to greetd. `createSession` starts a login for the user, PAM's question arrives as `authMessage` and gets the password as its answer, and once greetd accepts it `launch` starts `mango`. Mango needs no wrapper script: it sets `XDG_CURRENT_DESKTOP=mango` and imports its environment into the systemd user session itself.

Change `defaultUser` to your user name; the field can still be edited, and Tab moves between the two. F11 reboots and F12 powers off, which logind allows from the active local session without a password. The file is also [here](/files/mango-0.18/greeter.qml) to download.

greetd starts the greeter through a short script:

```sh title="~/dotfiles/bin/mango-greeter"
#!/bin/sh
# greetd's greeter, run inside cage. cage stretches its window across every
# monitor, so the 24" (DP-1) stays off until Mango starts.
wlr-randr --output DP-1 --off
exec qs -p /etc/greetd/greeter.qml
```

cage stretches its one window across every connected monitor, which would put the fields on the edge between my two screens. The script turns the 24" off first, and Mango turns it back on when it starts. Replace `DP-1` with the name of your second monitor, or delete the line on a single monitor.

```toml title="~/dotfiles/greetd/config.toml"
[terminal]
vt = 1

[default_session]
command = "cage -s -d -- /usr/local/bin/mango-greeter"
user = "greetd"
```

`-s` lets you switch to another console from the greeter, and `-d` asks programs not to draw their own title bar. Fedora runs the greeter as the `greetd` user, which can't read your home directory, so the three files are copied to system directories instead of linked:

```bash
sudo install -m 755 ~/dotfiles/bin/mango-greeter /usr/local/bin/
sudo install -m 644 ~/dotfiles/greetd/config.toml ~/dotfiles/greetd/greeter.qml /etc/greetd/
```

Fedora 45 uses kmscon for its text consoles, and Fedora's greetd service already declares a conflict with kmscon on tty1, so kmscon steps aside there and keeps the other consoles. To try Mango by hand from a console before enabling greetd, start it through `kmscon-launch-gui`, which makes kmscon release the screen first:

```bash
kmscon-launch-gui mango
```

When that works, enable greetd and boot into it:

```bash
sudo systemctl enable greetd.service
sudo systemctl set-default graphical.target
```

## Quickshell: bar, menu, OSD, notifications and polkit

Quickshell is a toolkit for writing desktop shells in QML, the declarative language Qt uses for interfaces. The shell is one QML file that Quickshell reloads every time you save it, plus a file for each of its two largest windows. These are its parts:

- A bar docked along the top of each monitor, from one corner to the other, made of blocks: the tags and an audio visualizer on the left, the clock in the middle, and volume, microphone, keyboard layout, notification count and the system tray on the right.
- A panel under the visualizer with the cover, the title, the controls and the timeline of the song that's playing.
- A menu that lists the programs you can run or the clipboard history, in `Menu.qml`.
- A keymap cheatsheet that shows the keybinds of Mango and seven other programs, in `Keymaps.qml`.
- A volume OSD, a small box that shows the device, a level bar and the percentage for a moment whenever the volume of the output or the microphone changes.
- Notification popups, a history of them and a do-not-disturb switch.
- The password prompt for programs that ask polkit for privileges.

The lock screen and the greeter are also written in Quickshell, each in a separate file that runs as its own process. The lock screen is covered in [Locking, screens off, and games](#locking-screens-off-and-games).

Fedora 45 has Quickshell, but its package is a February 2026 snapshot from before version 0.3. The [errornointernet/quickshell](https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/) COPR has the current release, 0.3.2, and replaces Fedora's package when enabled. [cava](https://github.com/karlstav/cava), from Fedora, is the audio visualizer the bar gets its spectrum from:

```bash
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell cava
```

Quickshell has modules for the Hyprland and i3 IPC, but none for Mango. It doesn't need one: `mmsg watch tags DP-1` prints the tags of a monitor as one JSON object per line every time they change, and `mmsg watch keyboardlayout` does the same for the keyboard layout. The bar runs both and parses the lines. Volume, microphone and the list of outputs come from Quickshell's PipeWire service, the tray from its StatusNotifier service, and the song from MPRIS, the standard D-Bus interface media players use to report what they're playing. The spectrum comes from cava, started with a config that makes it print one line of numbers per frame instead of drawing bars in a terminal. The notifications come from Quickshell's notification server and the password prompt from its polkit agent, both built into the COPR package.

```qml title="~/dotfiles/quickshell/.config/quickshell/shell.qml"
//@ pragma UseQApplication
// The tray menus are native Qt menus. This platform theme makes Qt follow
// the system's dark preference instead of its light default palette.
//@ pragma Env QT_QPA_PLATFORMTHEME = xdgdesktopportal
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.Polkit
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    // Paradise palette
    readonly property color bg: "#151515"
    readonly property color fg: "#e8e3e3"
    readonly property color muted: "#a39d9d"
    readonly property color blue: "#8da3b9"
    readonly property color red: "#b66467"
    readonly property color border: "#424242"
    readonly property color surface: "#2a2a2a"

    // Text in the bar font. Colors default to fg; callers override.
    component Label: Text {
        font.family: "Maple Mono"
        font.pointSize: 11
        color: "#e8e3e3"
    }

    // A bar module: a block 22 px tall around a row of items, with 10 px of
    // padding on each side. A click, right click or wheel turn anywhere on
    // it emits clicked, rightClicked or scrolled (with the wheel delta);
    // items with their own MouseArea take their clicks first.
    component Block: Rectangle {
        id: block
        default property alias content: row.data
        signal clicked
        signal rightClicked
        signal scrolled(real delta)
        implicitWidth: row.implicitWidth + 20
        implicitHeight: 22
        color: "#2a2a2a"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton
                                ? block.rightClicked() : block.clicked()
            onWheel: wheel => block.scrolled(wheel.angleDelta.y)
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8
        }
    }

    // Media control: a Symbols Nerd Font glyph whose click area reaches 4 px
    // past it on every side. Dimmed and inert while the player can't do the
    // action.
    component MediaButton: Item {
        id: button
        required property string glyph
        property bool available: true
        signal clicked
        implicitWidth: 16
        implicitHeight: 22

        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: 16
            color: button.available ? "#e8e3e3" : "#424242"
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            enabled: button.available
            onClicked: button.clicked()
        }
    }

    // A long-running `mmsg watch ...` that emits one parsed JSON object per
    // line. If mmsg exits (Mango restarted, socket gone), retry after 1 s.
    component MmsgWatch: Process {
        id: watch
        signal message(var data)
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    watch.message(JSON.parse(line));
                } catch (e) {
                    console.warn("mmsg:", line);
                }
            }
        }
        onExited: retry.start()
        property Timer retry: Timer {
            interval: 1000
            onTriggered: watch.running = true
        }
    }

    // Bind the default sink and source so .audio is populated and writable.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // `qs ipc call bar toggle` shows or hides the bar on every monitor.
    property bool barVisible: true
    IpcHandler {
        target: "bar"
        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }

    // The clock shows the time; a click on it switches every bar to the
    // date, and back.
    property bool clockShowsDate: false

    // Active keyboard layout. Mango reports the XKB name ("English (US)");
    // the bar shows the short code, or the full name for a layout not listed.
    property string keyboardLayout: ""
    MmsgWatch {
        command: ["mmsg", "watch", "keyboardlayout"]
        onMessage: k => root.keyboardLayout = k.layout ?? ""
    }
    readonly property var layoutCodes: ({
        "English (US)": "us",
        "Spanish (Latin American)": "latam"
    })

    // Caffeine: while it's on, an idle inhibitor keeps swayidle from locking
    // the screen or turning the monitors off. `qs ipc call idle toggle`
    // switches it (Super+Shift+i).
    property bool caffeine: false
    IpcHandler {
        target: "idle"
        function toggle(): void {
            root.caffeine = !root.caffeine;
        }
    }
    // The inhibitor needs a window. This one is 1x1, transparent and below
    // every window, and lets clicks through, so hiding the bar doesn't drop it.
    LazyLoader {
        active: root.caffeine

        PanelWindow {
            id: awake
            anchors {
                top: true
                left: true
            }
            implicitWidth: 1
            implicitHeight: 1
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Background

            IdleInhibitor {
                window: awake
                enabled: true
            }
        }
    }

    // The music players the bar follows, by MPRIS identity; any other MPRIS
    // player (a browser tab, a video) is ignored.
    readonly property var musicPlayers: Mpris.players.values
        .filter(p => p.identity === "kew" || p.identity === "Spotify")
    // The one the bar shows and controls: the last one that was playing. It
    // changes only when another one is playing and this one isn't, or when
    // this one quits. musicPlaying changes with the players and with what
    // each one is doing, which is when the choice is made again.
    property MprisPlayer music: null
    readonly property var musicPlaying: musicPlayers.map(p => p.isPlaying)
    onMusicPlayingChanged: {
        const current = musicPlayers.includes(music) ? music : null;
        if (!current?.isPlaying)
            music = musicPlayers.find(p => p.isPlaying) ?? current ?? musicPlayers[0] ?? null;
    }

    // Seconds as m:ss, for the track's position and length.
    function trackTime(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // Audio spectrum for the bar's visualizer. cava listens to everything
    // the default output plays and prints one line per frame, 30 a second:
    // one level from 0 to 100 per band, each followed by ";". If it exits,
    // retry after 1 s.
    readonly property int spectrumBands: 12
    property var spectrum: []
    Process {
        id: cava
        running: true
        command: ["sh", "-c", "exec cava -p /dev/stdin <<EOF\n" + [
            "[general]",
            "framerate = 30",
            `bars = ${root.spectrumBands}`,
            "[output]",
            "method = raw",
            "raw_target = /dev/stdout",
            "data_format = ascii",
            "ascii_max_range = 100",
            "bar_delimiter = 59",
            "frame_delimiter = 10",
            "channels = mono"
        ].join("\n") + "\nEOF"]
        stdout: SplitParser {
            onRead: line => root.spectrum = line.split(";", root.spectrumBands).map(Number)
        }
        onExited: cavaRetry.start()
    }
    Timer {
        id: cavaRetry
        interval: 1000
        onTriggered: cava.running = true
    }

    // Volume block for a PipeWire node: click mutes, wheel changes by 5 %,
    // right click is left to the caller (the output list for "vol").
    component Volume: Block {
        id: vol
        required property string label
        property PwNode node
        readonly property PwNodeAudio audio: node?.audio ?? null
        visible: audio !== null
        onClicked: vol.audio.muted = !vol.audio.muted
        onScrolled: delta => {
            const step = delta > 0 ? 0.05 : -0.05;
            vol.audio.volume = Math.max(0, Math.min(1, vol.audio.volume + step));
        }

        Label {
            text: vol.label
            color: "#a39d9d"
        }
        Label {
            text: vol.audio ? `${Math.round(vol.audio.volume * 100)}%` : ""
            color: vol.audio?.muted ? "#a39d9d" : "#e8e3e3"
        }
    }

    // Audio outputs: hardware sinks only, programs' streams are left out.
    // Choosing one sets PipeWire's preferred default; WirePlumber saves it
    // and moves the streams that follow the default.
    readonly property var sinks: Pipewire.nodes.values
        .filter(n => n.isSink && !n.isStream && n.audio !== null)
    function useSink(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }
    // `qs ipc call audio next` switches to the next output (Super+o).
    IpcHandler {
        target: "audio"
        function next(): void {
            if (root.sinks.length === 0)
                return;
            const i = root.sinks.indexOf(Pipewire.defaultAudioSink);
            root.useSink(root.sinks[(i + 1) % root.sinks.length]);
        }
    }

    // Volume OSD: 1.5 s after the volume or mute of the default output or
    // microphone changes, or the default device itself changes. It shows the
    // node that changed last. Changes during the first sync with PipeWire
    // don't count.
    property bool osdVisible: false
    property PwNode osdNode: null
    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }
    function showOsd(node: PwNode): void {
        if (!Pipewire.ready || !node?.ready)
            return;
        root.osdNode = node;
        root.osdVisible = true;
        osdTimer.restart();
    }
    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        function onVolumeChanged() { root.showOsd(Pipewire.defaultAudioSink); }
        function onMutedChanged() { root.showOsd(Pipewire.defaultAudioSink); }
    }
    Connections {
        target: Pipewire.defaultAudioSource?.audio ?? null
        function onVolumeChanged() { root.showOsd(Pipewire.defaultAudioSource); }
        function onMutedChanged() { root.showOsd(Pipewire.defaultAudioSource); }
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { root.showOsd(Pipewire.defaultAudioSink); }
        function onDefaultAudioSourceChanged() { root.showOsd(Pipewire.defaultAudioSource); }
    }

    // LazyLoader creates the window each time it's shown. A layer surface
    // without a screen goes to the monitor Mango has focused.
    LazyLoader {
        active: root.osdVisible

        PanelWindow {
            id: osd
            readonly property PwNode node: root.osdNode
            readonly property real volume: node?.audio?.volume ?? 0
            readonly property bool muted: node?.audio?.muted ?? false
            anchors.bottom: true
            margins.bottom: 120
            exclusiveZone: 0
            implicitWidth: 420
            implicitHeight: 48
            color: root.border
            WlrLayershell.layer: WlrLayer.Overlay
            // Clicks go through to the window underneath.
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: root.bg

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // "vol" or "mic", as in the bar.
                    Label {
                        text: osd.node?.isSink ? "vol" : "mic"
                        color: root.muted
                    }
                    Label {
                        text: osd.node?.description || osd.node?.name || ""
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 6
                        color: root.border
                        Rectangle {
                            width: parent.width * Math.min(1, osd.volume)
                            height: parent.height
                            color: osd.muted ? root.muted : root.fg
                        }
                    }
                    Label {
                        text: osd.muted ? "mute" : `${Math.round(osd.volume * 100)}%`
                        color: osd.muted ? root.muted : root.fg
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 40
                    }
                }
            }
        }
    }

    // Notifications. Each popup closes after the time the program asked for,
    // 5 s by default; critical ones stay until clicked. Left click runs the
    // default action, or dismisses; right click dismisses.
    // Every notification also goes into the history, newest first, up to 50.
    // Do not disturb skips the popup, except for critical ones.
    property bool dnd: false
    property var notificationHistory: []
    NotificationServer {
        id: notifications
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: n => {
            const critical = n.urgency === NotificationUrgency.Critical;
            root.notificationHistory = [{
                app: n.appName,
                summary: n.summary,
                body: n.body,
                time: new Date(),
                critical: critical
            }].concat(root.notificationHistory).slice(0, 50);
            if (!root.dnd || critical)
                n.tracked = true;
        }
    }
    // `qs ipc call notifications dnd` toggles do not disturb; `clear`
    // empties the history.
    IpcHandler {
        target: "notifications"
        function dnd(): void {
            root.dnd = !root.dnd;
        }
        function clear(): void {
            root.notificationHistory = [];
        }
    }
    function notificationIcon(n: Notification): string {
        if (n.image !== "")
            return n.image;
        if (n.appIcon.startsWith("/"))
            return "file://" + n.appIcon;
        if (n.appIcon.startsWith("file://"))
            return n.appIcon;
        return n.appIcon !== "" ? Quickshell.iconPath(n.appIcon, true) : "";
    }

    LazyLoader {
        active: notifications.trackedNotifications.values.length > 0

        PanelWindow {
            // Top right, below the bar (exclusiveZone 0 keeps clear of it).
            anchors {
                top: true
                right: true
            }
            margins {
                top: 10
                right: 10
            }
            exclusiveZone: 0
            implicitWidth: 380
            implicitHeight: list.implicitHeight
            color: "transparent"

            ColumnLayout {
                id: list
                width: parent.width
                spacing: 10

                Repeater {
                    model: notifications.trackedNotifications

                    Rectangle {
                        id: popup
                        required property Notification modelData
                        readonly property bool critical:
                            modelData.urgency === NotificationUrgency.Critical
                        readonly property string icon: root.notificationIcon(modelData)
                        Layout.fillWidth: true
                        implicitHeight: content.implicitHeight + 24
                        color: root.bg
                        border.width: 2
                        border.color: critical ? root.red : root.border

                        RowLayout {
                            id: content
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Image {
                                visible: popup.icon !== ""
                                source: popup.icon
                                sourceSize: Qt.size(48, 48)
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                Layout.alignment: Qt.AlignTop
                                fillMode: Image.PreserveAspectFit
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Label {
                                    text: popup.modelData.summary
                                    textFormat: Text.PlainText
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    visible: text !== ""
                                    text: popup.modelData.body
                                    textFormat: Text.StyledText
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 6
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // expireTimeout arrives in milliseconds as the client
                        // sent it: -1 means "server default", 0 means never.
                        Timer {
                            readonly property real timeout: popup.modelData.expireTimeout
                            interval: timeout > 0 ? timeout : 5000
                            running: timeout !== 0 && !(timeout < 0 && popup.critical)
                            onTriggered: popup.modelData.expire()
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                const n = popup.modelData;
                                const action = n.actions.find(a => a.identifier === "default");
                                if (mouse.button === Qt.LeftButton && action)
                                    action.invoke();
                                else
                                    n.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }

    // Password prompt for programs that ask polkit for privileges.
    // Enter submits, Escape cancels.
    PolkitAgent {
        id: polkit
    }

    LazyLoader {
        active: polkit.isActive

        PanelWindow {
            id: prompt
            readonly property AuthFlow flow: polkit.flow
            // No anchors: centred on the focused monitor, above everything,
            // with the keyboard until it closes.
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 480
            implicitHeight: form.implicitHeight + 40
            color: root.border
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: root.bg

                ColumnLayout {
                    id: form
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Label {
                        text: "Authentication required"
                        font.bold: true
                    }
                    Label {
                        text: prompt.flow?.message ?? ""
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    // polkit itself rarely explains a failed attempt.
                    Label {
                        readonly property AuthFlow flow: prompt.flow
                        visible: text !== ""
                        text: flow?.supplementaryMessage
                              || (flow?.failed ? "Wrong password, try again." : "")
                        color: flow?.supplementaryIsError || flow?.failed ? root.red : root.muted
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Label {
                        text: prompt.flow?.inputPrompt || "Password:"
                        color: root.muted
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        color: root.bg
                        border.width: 2
                        border.color: prompt.flow?.failed ? root.red : root.border

                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.margins: 8
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Maple Mono"
                            font.pointSize: 11
                            color: root.fg
                            echoMode: prompt.flow?.responseVisible
                                      ? TextInput.Normal : TextInput.Password
                            enabled: prompt.flow?.isResponseRequired ?? false
                            focus: true
                            onAccepted: {
                                prompt.flow.submit(text);
                                text = "";
                            }
                            Keys.onEscapePressed: prompt.flow.cancelAuthenticationRequest()
                        }
                    }
                    Label {
                        text: "Enter to confirm, Escape to cancel"
                        color: root.muted
                    }
                }
            }
        }
    }

    // Keymap cheatsheet (Keymaps.qml): `qs ipc call keymaps toggle` shows or
    // hides it (Super+Shift+/).
    Keymaps {}

    // Menu (Menu.qml): `qs ipc call menu run` lists the programs in $PATH
    // (Super+p), `qs ipc call menu clipboard` the clipboard history (Super+v).
    Menu {}

    // One bar per monitor.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData
            visible: root.barVisible

            // The main monitor (DP-2, or the first one while DP-2 isn't
            // connected) gets the complete bar; the others leave out the
            // music player and the tray.
            readonly property bool full: modelData.name ===
                (Quickshell.screens.find(s => s.name === "DP-2") ?? Quickshell.screens[0]).name

            // Docked to the top edge, full width. The default exclusionMode
            // (Auto) reserves an exclusive zone as tall as the bar.
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 30
            color: root.bg

            // Tags of this output: [{index, is_active, is_urgent, client_count, ...}]
            property var tags: []
            MmsgWatch {
                command: ["mmsg", "watch", "tags", bar.modelData.name]
                onMessage: m => bar.tags = m.tags
            }

            // Opens a popup of this bar, or closes it when it's open. The
            // other ones close first: a popup opened while another one holds
            // the pointer becomes its child and lands in the wrong place.
            function togglePopup(popup: PopupWindow): void {
                for (const other of [outputs, history, panel]) {
                    if (other !== popup)
                        other.visible = false;
                }
                popup.visible = !popup.visible;
            }

            // Left: the tags, then, on the main monitor, the visualizer.
            RowLayout {
                id: left
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // One mark per tag, in order: wide for the active one, red
                // for an urgent one, dim for an empty one. A click views the
                // tag on this output.
                Block {
                    visible: bar.tags.length > 0

                    Repeater {
                        model: bar.tags

                        Item {
                            id: tag
                            required property var modelData
                            implicitWidth: modelData.is_active ? 18 : 7
                            implicitHeight: 22

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 7
                                color: tag.modelData.is_urgent ? root.red
                                     : tag.modelData.is_active ? root.fg
                                     : tag.modelData.client_count > 0 ? root.muted : root.border
                            }
                            // Reaches into the gaps so the marks are easy to hit.
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: Quickshell.execDetached(["mmsg", "dispatch",
                                    `viewcrossmon,${tag.modelData.index},${bar.modelData.name}`])
                            }
                        }
                    }
                }

                // Visualizer: one bar per band of the spectrum, 2 to 14 px
                // tall. While a music player is open, a click opens its
                // panel.
                Block {
                    id: music
                    readonly property MprisPlayer player: root.music
                    visible: bar.full
                    onClicked: {
                        if (player)
                            bar.togglePopup(panel);
                    }

                    Row {
                        spacing: 2

                        Repeater {
                            model: root.spectrumBands

                            Item {
                                id: band
                                required property int index
                                width: 4
                                height: 14

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, Math.round((root.spectrum[band.index] ?? 0) * 0.14))
                                    color: root.fg
                                }
                            }
                        }
                    }

                    // The player's panel: cover, track, controls and
                    // timeline. A click anywhere else closes it.
                    PopupWindow {
                        id: panel
                        readonly property MprisPlayer player: music.player
                        onPlayerChanged: {
                            if (!player)
                                visible = false;
                        }
                        // Just below the bar, left edge under the block.
                        anchor.item: music
                        anchor.rect.y: bar.height - left.y - music.y
                        grabFocus: true
                        implicitWidth: 380
                        implicitHeight: sheet.implicitHeight + 28
                        color: root.border

                        // A player doesn't announce its position as it
                        // advances; read it again every second.
                        Timer {
                            interval: 1000
                            repeat: true
                            triggeredOnStart: true
                            running: panel.visible && (panel.player?.isPlaying ?? false)
                            onTriggered: panel.player.positionChanged()
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            color: root.bg

                            ColumnLayout {
                                id: sheet
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                RowLayout {
                                    spacing: 12

                                    // Cover, or a note while there is none.
                                    Rectangle {
                                        Layout.preferredWidth: 96
                                        Layout.preferredHeight: 96
                                        color: root.surface

                                        Text {
                                            anchors.centerIn: parent
                                            visible: cover.status !== Image.Ready
                                            text: "\u{f075a}"
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: 32
                                            color: root.border
                                        }
                                        Image {
                                            id: cover
                                            anchors.fill: parent
                                            source: panel.player?.trackArtUrl ?? ""
                                            sourceSize: Qt.size(192, 192)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 4

                                        Label {
                                            text: panel.player?.trackTitle ?? ""
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Label {
                                            text: panel.player?.trackArtist ?? ""
                                            color: root.muted
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Label {
                                            text: panel.player?.trackAlbum ?? ""
                                            color: root.muted
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Item {
                                            Layout.fillHeight: true
                                        }
                                        // Previous, play/pause (the glyph is
                                        // what a click will do) and next.
                                        RowLayout {
                                            spacing: 20

                                            MediaButton {
                                                glyph: "\u{f04ae}"
                                                available: panel.player?.canGoPrevious ?? false
                                                onClicked: panel.player.previous()
                                            }
                                            MediaButton {
                                                glyph: panel.player?.isPlaying ? "\u{f03e4}" : "\u{f040a}"
                                                available: panel.player?.canTogglePlaying ?? false
                                                onClicked: panel.player.togglePlaying()
                                            }
                                            MediaButton {
                                                glyph: "\u{f04ad}"
                                                available: panel.player?.canGoNext ?? false
                                                onClicked: panel.player.next()
                                            }
                                        }
                                    }
                                }

                                // Timeline; a click jumps to that point of
                                // the track.
                                Rectangle {
                                    id: timeline
                                    readonly property real length: panel.player?.length ?? 0
                                    readonly property real position: panel.player?.position ?? 0
                                    Layout.fillWidth: true
                                    implicitHeight: 6
                                    color: root.border

                                    Rectangle {
                                        width: timeline.length > 0
                                               ? parent.width * Math.min(1, timeline.position / timeline.length) : 0
                                        height: parent.height
                                        color: root.fg
                                    }
                                    // Taller than the line so it's easy to hit.
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.topMargin: -6
                                        anchors.bottomMargin: -6
                                        enabled: (panel.player?.canSeek ?? false) && timeline.length > 0
                                        onClicked: mouse => panel.player.position =
                                            mouse.x / width * timeline.length
                                    }
                                }
                                RowLayout {
                                    Label {
                                        text: root.trackTime(timeline.position)
                                        color: root.muted
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        text: root.trackTime(timeline.length)
                                        color: root.muted
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Middle: the clock, centered on the screen.
            Block {
                anchors.centerIn: parent
                onClicked: root.clockShowsDate = !root.clockShowsDate

                Label {
                    text: Qt.formatDateTime(clock.date,
                                            root.clockShowsDate ? "ddd dd MMM" : "h:mm AP")
                }
            }

            // Right: volume, mic, keyboard layout, caffeine, notifications
            // and, on the main monitor, the tray.
            RowLayout {
                id: right
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Right click lists the outputs; clicking one switches to it.
                // A click anywhere else closes the list.
                Volume {
                    id: volume
                    label: "vol"
                    node: Pipewire.defaultAudioSink
                    onRightClicked: bar.togglePopup(outputs)

                    PopupWindow {
                        id: outputs
                        // Just below the bar, left edge under the block.
                        anchor.item: volume
                        anchor.rect.y: bar.height - right.y - volume.y
                        grabFocus: true
                        implicitWidth: 340
                        implicitHeight: choices.implicitHeight + 4
                        color: root.border

                        Column {
                            id: choices
                            x: 2
                            y: 2
                            width: outputs.width - 4

                            Repeater {
                                model: root.sinks

                                Rectangle {
                                    id: choice
                                    required property PwNode modelData
                                    readonly property bool current:
                                        modelData === Pipewire.defaultAudioSink
                                    width: choices.width
                                    clip: true
                                    height: 28
                                    color: hover.containsMouse ? root.border : root.bg

                                    Label {
                                        id: name
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 12
                                        text: `${choice.current ? "●" : "○"} ${choice.modelData.description || choice.modelData.name}`
                                        color: choice.current ? root.fg : root.muted
                                    }
                                    MouseArea {
                                        id: hover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            root.useSink(choice.modelData);
                                            outputs.visible = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Volume {
                    id: mic
                    label: "mic"
                    node: Pipewire.defaultAudioSource
                }

                // Keyboard layout; a click switches to the next one.
                Block {
                    visible: root.keyboardLayout !== ""
                    onClicked: Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"])

                    Label {
                        text: root.layoutCodes[root.keyboardLayout] ?? root.keyboardLayout
                        color: root.muted
                    }
                }

                // Shown while caffeine is on; a click turns it off.
                Block {
                    visible: root.caffeine
                    onClicked: root.caffeine = false

                    Label {
                        text: "awake"
                        color: root.blue
                    }
                }

                // Notification count. Left click lists the history, right
                // click toggles do not disturb. A click elsewhere closes it.
                Block {
                    id: notif
                    readonly property int count: root.notificationHistory.length
                    onClicked: bar.togglePopup(history)
                    onRightClicked: root.dnd = !root.dnd

                    Label {
                        text: root.dnd ? "dnd" : "notif"
                        color: root.dnd ? root.blue : root.muted
                    }
                    Label {
                        text: notif.count
                        color: root.dnd ? root.blue : notif.count > 0 ? root.fg : root.muted
                    }

                    PopupWindow {
                        id: history
                        // Just below the bar, right edge under the block.
                        anchor.item: notif
                        anchor.rect.x: notif.width - width
                        anchor.rect.y: bar.height - right.y - notif.y
                        grabFocus: true
                        implicitWidth: 400
                        implicitHeight: Math.min(entries.implicitHeight, 600) + 4
                        color: root.border

                        Flickable {
                            x: 2
                            y: 2
                            width: history.width - 4
                            height: history.height - 4
                            contentHeight: entries.implicitHeight
                            clip: true

                            Column {
                                id: entries
                                width: history.width - 4

                                // Header: clears everything.
                                Rectangle {
                                    width: entries.width
                                    height: 28
                                    color: clearHover.containsMouse ? root.border : root.bg
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 12
                                        text: notif.count > 0 ? "clear all" : "no notifications"
                                        color: root.muted
                                    }
                                    MouseArea {
                                        id: clearHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.notificationHistory = []
                                    }
                                }

                                // One entry per notification; a click removes it.
                                Repeater {
                                    model: root.notificationHistory

                                    Rectangle {
                                        id: entry
                                        required property var modelData
                                        required property int index
                                        width: entries.width
                                        height: lines.implicitHeight + 16
                                        color: entryHover.containsMouse ? root.border : root.bg

                                        Column {
                                            id: lines
                                            x: 12
                                            y: 8
                                            width: parent.width - 24
                                            spacing: 2

                                            Label {
                                                width: parent.width
                                                text: `${Qt.formatTime(entry.modelData.time, "HH:mm")} ${entry.modelData.app}`
                                                color: entry.modelData.critical ? root.red : root.muted
                                                elide: Text.ElideRight
                                            }
                                            Label {
                                                width: parent.width
                                                text: entry.modelData.summary
                                                textFormat: Text.PlainText
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                            Label {
                                                width: parent.width
                                                visible: text !== ""
                                                text: entry.modelData.body
                                                textFormat: Text.StyledText
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                            }
                                        }
                                        MouseArea {
                                            id: entryHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: root.notificationHistory = root.notificationHistory
                                                .filter((_, i) => i !== entry.index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // System tray, on the main monitor: left click activates,
                // right click opens the menu.
                Block {
                    visible: bar.full && SystemTray.items.values.length > 0

                    Repeater {
                        model: SystemTray.items

                        Image {
                            id: trayIcon
                            required property SystemTrayItem modelData
                            source: modelData.icon
                            sourceSize: Qt.size(18, 18)
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18

                            QsMenuAnchor {
                                id: menu
                                menu: trayIcon.modelData.menu
                                anchor.item: trayIcon
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    const item = trayIcon.modelData;
                                    if (mouse.button === Qt.LeftButton && !item.onlyMenu)
                                        item.activate();
                                    else if (item.hasMenu)
                                        menu.open();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
```

One monitor gets the complete bar. The others leave out the visualizer and the tray, and keep the tags, the clock and the rest of the blocks on the right. The property `full` names that monitor, `DP-2` here; while no monitor has that name, the first one gets the complete bar.

Each tag is a small mark: a wide one for the tag on screen, a red one for a tag with an urgent window, a light one for a tag with windows and a dark one for an empty tag. Clicking a mark shows that tag on that bar's monitor. Clicking the clock switches every bar to the date, and back. Scrolling over `vol` or `mic` changes the volume, with a click to mute. Clicking the keyboard layout switches to the next one. Right-clicking `vol` lists the audio outputs, and Super+o moves to the next one without opening the list; WirePlumber remembers the choice across reboots. The list only shows separate devices, so headphones in the front jack of the same sound card don't appear there, and WirePlumber switches to them by itself when you plug them in.

The visualizer moves with anything the default output plays. The music panel only follows kew and Spotify, so a video in a browser tab doesn't take it over, and of the two it shows the one that played last. While one of them is open, clicking the visualizer opens the panel, with the cover, the title, artist and album, buttons for previous, play or pause and next, and a timeline that jumps to the point you click.

Clicking `notif` lists the last 50 notifications, newest first; clicking one removes it. Right-clicking `notif` turns on do not disturb, which hides every popup except critical ones while the history keeps recording. The history only keeps the text, and it empties when Quickshell reloads, for example when you save this file. `pkexec true` brings up the polkit prompt if you want to try it.

A few things in the code aren't obvious from the result. `PwObjectTracker` has to bind the default output and input, or PipeWire never sends their volume. The tray menus only open because of the `UseQApplication` pragma on the first line. They are Qt's own menus, and the `QT_QPA_PLATFORMTHEME` pragma under it makes Qt ask the desktop portal whether to be dark, so they turn dark once the preference under [Paradise everywhere](#paradise-everywhere) is set. `expireTimeout` arrives in milliseconds, although Quickshell's documentation says seconds. And `togglePopup` closes a bar's other popups before it opens one, because a popup opened while another holds the pointer becomes its child and lands in the wrong place.

`shell.qml` loads `Menu.qml` and `Keymaps.qml` from its own folder and doesn't start without them. The file is also [here](/files/mango-0.18/shell.qml) to download.

### The menu: programs and the clipboard

`Menu.qml` is a search field over a list of ten rows, in the middle of the focused monitor. Super+p opens it with the programs in `$PATH` and Super+v with the clipboard history. The key of the mode that's open closes it, and the other key switches mode.

```qml title="~/dotfiles/quickshell/.config/quickshell/Menu.qml"
// Menu: a search field over a list of ten rows, in two modes.
// `qs ipc call menu run` (Super+p) lists the programs in $PATH and runs the
// chosen one; `qs ipc call menu clipboard` (Super+v) lists the clipboard
// history and copies the chosen entry. The call of the open mode closes the
// menu, the other one switches mode.
//
// A row shows while it contains every word typed, in any case. Programs come
// in alphabetical order, with the one named exactly as typed first, then
// those that start with the first word; the clipboard keeps its order, newest
// first.
//
// Up and Down, Ctrl+p and Ctrl+n, Ctrl+k and Ctrl+j, Shift+Tab and Tab move
// the selection, around the ends. Enter takes the selected row, or runs what
// was typed as a shell command when no program matches ("foot -e htop");
// Shift+Enter runs what was typed even when one does. Escape closes.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // Paradise palette, as in shell.qml.
    readonly property color bg: "#151515"
    readonly property color fg: "#e8e3e3"
    readonly property color muted: "#a39d9d"
    readonly property color blue: "#8da3b9"
    readonly property color border: "#424242"

    // The bar's height, for the field and for each row.
    readonly property int rowHeight: 28

    // "run" or "clip" while the menu is open, "" while it's closed.
    property string mode: ""
    function toggle(mode: string): void {
        root.mode = root.mode === mode ? "" : mode;
    }
    IpcHandler {
        target: "menu"
        function run(): void {
            root.toggle("run");
        }
        function clipboard(): void {
            root.toggle("clip");
        }
    }

    // Mango starts the shell without ~/.local/bin in PATH. The list of
    // programs and the programs started from it get it in front.
    readonly property string path: `${Quickshell.env("HOME")}/.local/bin:${Quickshell.env("PATH")}`
    function spawn(command: var): void {
        Quickshell.execDetached({
            command: command,
            environment: { PATH: root.path }
        });
    }
    // A program by its name, or a command line for the shell.
    function runProgram(name: string): void {
        root.spawn(["sh", "-c", 'exec "$0"', name]);
    }
    function runCommand(text: string): void {
        root.spawn(["sh", "-c", text]);
    }
    // A line of `cliphist list`.
    function copy(line: string): void {
        root.spawn(["sh", "-c", 'printf "%s\\n" "$0" | cliphist decode | wl-copy', line]);
    }

    // Rows are {text: what the row shows, key: text in lowercase, value:
    // what choosing it takes}.
    function programs(output: string): var {
        const names = new Set(output.split("\n").filter(name => name !== ""));
        return Array.from(names, name => ({ text: name, key: name.toLowerCase(), value: name }))
            .sort((a, b) => a.key < b.key ? -1 : a.key > b.key ? 1 : a.text < b.text ? -1 : 1);
    }
    // `cliphist list` prints "id<Tab>preview"; decode takes the line back.
    function history(output: string): var {
        return output.split("\n").filter(line => line !== "").map(line => {
            const text = line.slice(line.indexOf("\t") + 1);
            return { text: text, key: text.toLowerCase(), value: line };
        });
    }
    // The rows that contain every word of the query, in their order. With
    // ranked, the row equal to the query comes first, then the rows that
    // start with its first word.
    function matches(rows: var, query: string, ranked: bool): var {
        const words = query.toLowerCase().split(" ").filter(word => word !== "");
        if (words.length === 0)
            return rows;
        const found = rows.filter(row => words.every(word => row.key.includes(word)));
        if (!ranked)
            return found;
        const whole = words.join(" ");
        const ranks = [[], [], []];
        for (const row of found)
            ranks[row.key === whole ? 0 : row.key.startsWith(words[0]) ? 1 : 2].push(row);
        return ranks[0].concat(ranks[1], ranks[2]);
    }

    component Label: Text {
        font.family: "Maple Mono"
        font.pointSize: 11
        color: "#a39d9d"
        // The clipboard can hold HTML; show it as it is.
        textFormat: Text.PlainText
    }

    // LazyLoader creates the window each time it's shown, with an empty
    // field.
    LazyLoader {
        active: root.mode !== ""

        PanelWindow {
            id: win
            // No anchors: centred on the focused monitor, above everything,
            // with the keyboard until it closes. The height stays the same
            // with fewer than ten rows, so the window doesn't move while
            // typing.
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 600
            implicitHeight: 4 + root.rowHeight + 2 + 10 * root.rowHeight
            color: root.border
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Both lists are read again each time their mode opens.
            property var programs: []
            property var history: []
            readonly property var rows: root.mode === "run"
                ? root.matches(programs, input.text, true)
                : root.matches(history, input.text, false)
            function load(): void {
                if (root.mode === "run")
                    scan.running = true;
                else
                    clips.running = true;
            }
            Component.onCompleted: win.load()
            Connections {
                target: root
                // From one mode to the other without closing.
                function onModeChanged(): void {
                    if (root.mode === "")
                        return;
                    input.text = "";
                    win.load();
                }
            }

            // Every executable file in the directories of PATH, links
            // included.
            Process {
                id: scan
                command: ["sh", "-c", "IFS=:; set -f; "
                    + "exec find -L $PATH -maxdepth 1 -type f -executable -printf '%f\\n' 2>/dev/null"]
                environment: ({ PATH: root.path })
                stdout: StdioCollector {
                    onStreamFinished: win.programs = root.programs(text)
                }
            }
            Process {
                id: clips
                command: ["cliphist", "list"]
                stdout: StdioCollector {
                    onStreamFinished: win.history = root.history(text)
                }
            }

            function move(rows: int): void {
                if (list.count > 0)
                    list.currentIndex = (list.currentIndex + rows + list.count) % list.count;
            }
            function choose(row: var): void {
                if (root.mode === "run")
                    root.runProgram(row.value);
                else
                    root.copy(row.value);
                root.mode = "";
            }
            // Enter (typed: false) or Shift+Enter (typed: true).
            function accept(typed: bool): void {
                const row = win.rows[list.currentIndex];
                if (row && !(typed && root.mode === "run")) {
                    win.choose(row);
                } else if (root.mode === "run" && input.text.trim() !== "") {
                    root.runCommand(input.text);
                    root.mode = "";
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: root.bg

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        // The input fills the row; the row keeps its height.
                        Layout.fillHeight: false
                        Layout.preferredHeight: root.rowHeight
                        spacing: 10

                        Label {
                            text: root.mode
                            color: root.blue
                        }
                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Maple Mono"
                            font.pointSize: 11
                            color: root.fg
                            clip: true
                            focus: true
                            Keys.onPressed: event => {
                                const ctrl = event.modifiers === Qt.ControlModifier;
                                const key = event.key;
                                event.accepted = true;
                                if (key === Qt.Key_Escape)
                                    root.mode = "";
                                else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                                    win.accept((event.modifiers & Qt.ShiftModifier) !== 0);
                                else if (key === Qt.Key_Down || key === Qt.Key_Tab
                                         || ctrl && (key === Qt.Key_N || key === Qt.Key_J))
                                    win.move(1);
                                else if (key === Qt.Key_Up || key === Qt.Key_Backtab
                                         || ctrl && (key === Qt.Key_P || key === Qt.Key_K))
                                    win.move(-1);
                                else
                                    event.accepted = false;
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 2
                        color: root.border
                    }
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        // The view follows the selection at once.
                        highlightMoveDuration: 0
                        model: win.rows
                        onModelChanged: currentIndex = 0

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            readonly property bool selected: ListView.isCurrentItem
                            width: list.width
                            height: root.rowHeight
                            color: selected ? root.fg : root.bg

                            Label {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                text: row.modelData.text
                                color: row.selected ? root.bg : root.muted
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: win.choose(row.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
```

A row stays while it contains every word you typed, in upper or lower case. Programs are in alphabetical order, with the one named exactly as typed first and then the ones that start with the first word. The clipboard keeps its own order, newest first.

| Keys | Action |
| --- | --- |
| Up / Down, Ctrl+p / Ctrl+n, Ctrl+k / Ctrl+j, Shift+Tab / Tab | move the selection, around the ends |
| Enter | run the selected program, or copy the selected entry |
| Enter with no program left in the list | run what you typed as a shell command, such as `foot -e htop` |
| Shift+Enter | run what you typed even when a program matches |
| Escape | close |

Mango starts Quickshell without `~/.local/bin` in `PATH`, so the menu puts it in front, both for the list and for the programs it starts. The file is also [here](/files/mango-0.18/Menu.qml) to download.

### The keymap cheatsheet

Super+Shift+/ opens a window with one tab per program: Mango, kew, foot, fish, tmux, Neovim, yazi and zathura. A tab draws the keyboard and shows one layer of that program's keybinds on it: hold Super, or Super and Shift, and every key shows what it does with those modifiers. Each key takes the color of its bind's category, and the same binds are listed below the keyboard under their categories. Hovering a key or a bind shows the whole command. A program whose binds are sequences of keys, like Neovim, gets the list without the keyboard.

Every time the window opens it runs `keymaps`, a Python script that reads the binds from each program's own configuration and prints them as JSON, so a bind you change shows up the next time you open it:

| Program | Where its binds come from |
| --- | --- |
| Mango | the `bind`, `mousebind` and `axisbind` lines of `config.conf`, with a category for each `## Name` line |
| kew | the `[key bindings]` section of `kewrc`, where kew writes every default |
| foot | the defaults listed in `/etc/xdg/foot/foot.ini`, then the ones your `foot.ini` changes |
| fish | `bind --user`, which prints the binds of `config.fish` and of the plugins |
| tmux | `tmux list-keys` on a server of its own that only reads `tmux.conf` |
| Neovim | the config, run against a stand-in for `vim` that only records keymaps, so no plugin loads |
| yazi | a copy of yazi's default keymap, then your `keymap.toml` over it |
| zathura | the `map` lines of `zathurarc`, then the key list of the `zathura(1)` manual page |

`Keymaps.qml` and the script are too long to print here. [Keymaps.qml](/files/mango-0.18/Keymaps.qml) goes next to `shell.qml`. [keymaps](/files/mango-0.18/keymaps) goes to `~/dotfiles/local-bin/.local/bin/`, and [yazi-keymap-default.toml](/files/mango-0.18/yazi-keymap-default.toml) to `~/dotfiles/local-bin/.local/share/keymaps/`. yazi keeps its defaults inside its binary, so the script reads them from that file, a copy of the keymap of yazi 26.9.1; replace it when you upgrade yazi.

```bash
chmod +x ~/dotfiles/local-bin/.local/bin/keymaps
stow --no-folding -d ~/dotfiles -t ~ local-bin quickshell
keymaps mango | jq '.binds | length'
```

The last command prints how many binds the script found in Mango's config. A tab whose program isn't installed yet shows the script's error instead of a keyboard; tmux and Neovim arrive in part 3.

The keyboard it draws is mine, a 60% ANSI board. The `board` property at the top of `Keymaps.qml` lists its rows, key by key, if yours is different.

| Keys | Action |
| --- | --- |
| Tab / Shift+Tab, or 1 to 8 | next or previous program, or the one with that number |
| h / l | previous or next mode, in a program that has modes |
| j / k | scroll a list longer than the screen |
| Escape | close |

## Music: kew

[kew](https://kewplayer.com/) is a terminal music player that plays the files in a folder: no daemon, no database to build, and covers, a visualizer and lyrics in the terminal. It's in Terra:

```bash
sudo dnf install kew
kew
```

The first time it starts, kew asks for the music folder and suggests `~/Music`; press Enter to accept or type another path. It then writes `~/.config/kew/kewrc` with every setting and a comment for each, and copies its bundled themes to `~/.config/kew/themes/`. Changes you make inside the app go to a separate `kewstaterc`, so kewrc stays as you edit it.

kew themes are small INI files. This one uses the Paradise colors:

```ini title="~/dotfiles/kew/.config/kew/themes/paradise.theme"
[theme]
name=Paradise

accent=#d9bc8c
text=#e8e3e3
textDim=#e8e3e3
textMuted=#a39d9d

logo=#a39d9d
header=#8da3b9
footer=#a39d9d
help=#e8e3e3
link=#8c977d
nowplaying=#d9bc8c
playbackstatus=#a39d9d

playlist.rownum=#a39d9d
playlist.title=#e8e3e3
playlist.playing=#d9bc8c

trackview.title=#e8e3e3
trackview.artist=#a39d9d
trackview.album=#a39d9d
trackview.year=#a39d9d
trackview.time=#a39d9d
trackview.visualizer=#8da3b9
trackview.lyrics=#a39d9d

library.artist=#8da3b9
library.album=#e8e3e3
library.track=#e8e3e3
library.enqueued=#8c977d
library.playing=#d9bc8c

search.label=#a39d9d
search.query=#8da3b9
search.result=#e8e3e3
search.enqueued=#8c977d
search.playing=#d9bc8c

progress.filled=#d9bc8c
progress.empty=#424242
progress.elapsed=#a39d9d

status.info=-1
status.warning=#d9bc8c
status.error=#b66467
status.success=#8c977d
```

Then select it in the `[colors]` section of the generated kewrc. By default kew takes its colors from the album cover; `colorMode=2` makes it use the theme instead:

```ini title="~/.config/kew/kewrc"
[colors]
theme=paradise
colorMode=2
```

The `i` key cycles through the color modes while kew runs, if you want the album colors back for a while.

| Key | Action |
| --- | --- |
| Space or p | play or pause |
| l / h, or the arrow keys | next or previous track |
| + / - | volume |
| F3 / F5 | library, search |
| Enter | open a folder; Alt+Enter adds it to the queue and plays |
| q | quit |

`kew <name>` from a shell plays the folder, artist or song that matches, without opening the library first.

kew publishes what it's playing over MPRIS under the name `kew`, which is how the bar's music panel finds it, and `playerctl -p kew play-pause` controls it from the command line. Covers need a terminal that can draw images; foot does it through sixel, which kew picks automatically.

The panel follows Spotify too; [Flatpak: Spotify and Stremio](#flatpak-spotify-and-stremio) installs it.

## The rest of the desktop

```bash
sudo dnf install foot wmenu swaybg libnotify swayidle wlopm firefox discord playerctl jq \
  wl-clipboard cliphist grim slurp grimpicker \
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-user-dirs dconf \
  yazi zathura zathura-pdf-mupdf imv mpv neovim NetworkManager-tui xdg-utils gawk \
  google-noto-color-emoji-fonts
xdg-user-dirs-update
```

[wl-clip-persist](https://github.com/Linus789/wl-clip-persist) isn't in Fedora or Terra. The [sassech/packages](https://copr.fedorainfracloud.org/coprs/sassech/packages/) COPR builds 0.5.0, the latest release, for Fedora 45:

```bash
sudo dnf copr enable sassech/packages
sudo dnf install wl-clip-persist
```

| Package | Role |
| --- | --- |
| `foot` | terminal |
| `firefox` | browser |
| `discord` | Discord; Terra and RPM Fusion both package it, and dnf installs Terra's because it's newer |
| `wmenu` | the list the screen-sharing portal shows to pick a monitor or a window |
| `swaybg` | background |
| `libnotify` | `notify-send`, to test the notifications |
| `dconf` | stores what `gsettings` writes, like the dark mode below; without it the settings are lost at logout |
| `playerctl` | play, pause and skip in kew or any other MPRIS player from a shell: `playerctl -p kew play-pause` |
| `jq` | reads the JSON `mmsg` prints; `mango-tag` uses it to find the focused monitor |
| `swayidle`, `wlopm` | lock screen after ten minutes idle, monitors off after fifteen |
| `wl-clipboard`, `cliphist` | `wl-copy`/`wl-paste` (Neovim uses them for the system clipboard) and the clipboard history behind Super+v |
| `wl-clip-persist` | keeps the clipboard when the program you copied from closes; without it, `wl-paste` finds nothing |
| `grim`, `slurp` | screenshots, whole screen or a selected region |
| `grimpicker` | color picker; Fedora builds it from sway-contrib as its own package, without sway |
| `xdg-desktop-portal-wlr`, `-gtk` | screen sharing in browsers, Discord and OBS, plus file pickers |
| `yazi`, `zathura`, `imv`, `mpv` | files, PDFs, images, video; yazi comes from Terra |
| `xdg-utils`, `gawk` | `xdg-open`, which yazi uses to open files; it reads `mimeapps.list` with `awk` but doesn't install it |
| `NetworkManager-tui` | `nmtui`, a menu for Wi-Fi and network connections |

PipeWire and WirePlumber came with `@multimedia` in part 1. `xdg-user-dirs-update` creates `~/Pictures` and the other standard folders; the Print binding saves there.

Quickshell shows the notifications and the polkit prompt, so the list has no notification daemon or polkit agent. Don't add a separate notification daemon either: its D-Bus service file starts it whenever a notification arrives while nothing owns the notification name, for example before `qs` is up at login, and after that it keeps the notifications.

[yazi](https://yazi-rs.github.io/) is the file manager behind Super+n. It shows the parent folder, the current one and a preview of the selected file in three columns, and in foot the preview of an image is the image itself, drawn through sixel.

### Default applications

yazi opens files with `xdg-open`, and Firefox and other GTK programs use GLib's lookup. Both look for the program in `~/.config/mimeapps.list`. Without that file they take whichever installed program claims the file type: PDFs happen to land in zathura, but kew claims folders, so "Open folder" in Firefox starts the music player. Neovim and kew also claim text and audio, and both need a terminal that neither tool opens for them, so nothing shows up.

```ini title="~/dotfiles/mime/.config/mimeapps.list"
[Default Applications]
application/pdf=org.pwmt.zathura-pdf-mupdf.desktop
application/epub+zip=org.pwmt.zathura-pdf-mupdf.desktop

image/png=imv-dir.desktop
image/jpeg=imv-dir.desktop
image/gif=imv-dir.desktop
image/webp=imv-dir.desktop
image/bmp=imv-dir.desktop
image/svg+xml=imv-dir.desktop
image/avif=imv-dir.desktop

video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
video/webm=mpv.desktop
video/quicktime=mpv.desktop
video/x-msvideo=mpv.desktop

audio/mpeg=mpv.desktop
audio/flac=mpv.desktop
audio/ogg=mpv.desktop
audio/opus=mpv.desktop
audio/wav=mpv.desktop
audio/x-wav=mpv.desktop
audio/mp4=mpv.desktop
audio/x-m4a=mpv.desktop

text/plain=foot-nvim.desktop
text/markdown=foot-nvim.desktop
application/json=foot-nvim.desktop
application/x-shellscript=foot-nvim.desktop
text/x-shellscript=foot-nvim.desktop

inode/directory=foot-yazi.desktop

text/html=org.mozilla.firefox.desktop
x-scheme-handler/http=org.mozilla.firefox.desktop
x-scheme-handler/https=org.mozilla.firefox.desktop
```

`imv-dir` opens the image and lets you step through the rest of its folder. A single audio file goes to mpv, and kew stays for the music library. Text and folders go to two desktop files of my own, which open a foot window and run Neovim or yazi inside it:

```ini title="~/dotfiles/mime/.local/share/applications/foot-nvim.desktop"
[Desktop Entry]
Type=Application
Name=Neovim in foot
Exec=foot -e nvim %F
NoDisplay=true
MimeType=text/plain;text/markdown;application/json;application/x-shellscript;text/x-shellscript;
```

```ini title="~/dotfiles/mime/.local/share/applications/foot-yazi.desktop"
[Desktop Entry]
Type=Application
Name=yazi in foot
Exec=foot -e yazi %f
NoDisplay=true
MimeType=inode/directory;
```

Inside yazi, a text file opens in Neovim in the same window instead: yazi hands text files to `$EDITOR`, and Fedora sets `EDITOR` to nano unless something sets it first. Set in Mango's config, the variable reaches every program in the session, including the shell in foot and the yazi behind Super+n:

```ini title="~/dotfiles/mango/.config/mango/config.conf"
env=EDITOR,nvim
```

Log out and back in for the variable to apply. `xdg-open` needs `gawk` to read `mimeapps.list`, which is why it's in the package list; without it, it falls back to the guesses above. Firefox and `xdg-mime default` rewrite `mimeapps.list` when you change a default through them, and that replaces Stow's link with a plain file, so change it in the repository instead.

### Clipboard history

`wl-paste --watch` runs a command every time something is copied, and with `cliphist store` as that command everything goes into the history Super+v shows, passwords included. Mine come from [Spectre](https://spectre.app/), which calculates each site's password from a master password, so they all have the same shape: three made-up words with a digit and a symbol after one of them. A script between `wl-paste` and `cliphist` can tell that shape from anything else:

```python title="~/dotfiles/local-bin/.local/bin/cliphist-store"
#!/usr/bin/python3
"""cliphist-store: `cliphist store`, minus Spectre passwords.

Mango runs this as `wl-paste --watch cliphist-store`, so every copy arrives
on stdin. A copy that is exactly one Spectre "Long Password" (spectre.pw's
default: VafdDiyp2'Lara) is dropped; everything else goes to cliphist
untouched. The password is still in the clipboard to paste, it only stays out
of the history that Super+V shows.

The shape is the 21 Long templates of the Spectre algorithm
(spectre-types.c): three words of Cvcv or Cvcc, with one digit and one
symbol after the first, the second or the third.
"""
import re
import subprocess
import sys

WORD = rb"[B-DF-HJ-NP-TV-Z][aeiou][b-df-hj-np-tv-z][a-z]"
MARK = rb"[0-9][@&%?,=\[\]_:\-+*$#!'^~;()/.]"
PASSWORD = re.compile(
    rb"%(w)s(?:%(m)s%(w)s%(w)s|%(w)s%(m)s%(w)s|%(w)s%(w)s%(m)s)"
    % {b"w": WORD, b"m": MARK}
)

clip = sys.stdin.buffer.read()
if not PASSWORD.fullmatch(clip.strip()):
    sys.exit(subprocess.run(["cliphist", "store"], input=clip).returncode)
```

A copy that is exactly one of those passwords is dropped, and everything else goes to `cliphist store` untouched. The password is still in the clipboard to paste; it only stays out of the history. The script is in the `local-bin` Stow package and needs the executable bit:

```bash
chmod +x ~/dotfiles/local-bin/.local/bin/cliphist-store
stow --no-folding -d ~/dotfiles -t ~ local-bin
```

If your passwords don't have a shape a regular expression can describe, leave the script out and use `exec_once=wl-paste --watch cliphist store` in Mango's config.

### Flatpak: Spotify and Stremio

Spotify and Stremio come from [Flathub](https://flathub.org/):

```bash
sudo dnf install flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.spotify.Client com.stremio.Stremio
```

A Flatpak program starts with `flatpak run` and its ID, and has no command in `$PATH`, so the menu behind Super+p wouldn't list it. Two scripts in the `local-bin` package give each one a command:

```sh title="~/dotfiles/local-bin/.local/bin/spotify"
#!/bin/sh
exec flatpak run com.spotify.Client "$@"
```

```sh title="~/dotfiles/local-bin/.local/bin/stremio"
#!/bin/sh
exec flatpak run com.stremio.Stremio --no-window-decorations "$@"
```

`--no-window-decorations` removes the title bar Stremio draws for itself. Make both executable with `chmod +x` and link them with the same `stow` command as above.

### A microphone with a headphone jack

My microphone, a HyperX QuadCast 2 S, has a headphone jack, and PipeWire lists that jack as one more audio output, next to the real ones in the bar's list and in the rotation of Super+o. I only use the microphone, so a WirePlumber rule keeps that output from being created:

```txt title="~/dotfiles/wireplumber/.config/wireplumber/wireplumber.conf.d/51-quadcast-no-output.conf"
# The HyperX QuadCast 2 S exposes its headphone jack as an output (IEC958),
# which shows up next to the real outputs in the bar. Only its microphone is
# used, so the output node is never created.
monitor.alsa.rules = [
  {
    matches = [
      { node.name = "~alsa_output.usb-HP__Inc_HyperX_QuadCast_2_S_*" }
    ]
    actions = {
      update-props = {
        node.disabled = true
      }
    }
  }
]
```

A second rule makes it the default microphone whenever it's connected, ahead of the motherboard's input:

```txt title="~/dotfiles/wireplumber/.config/wireplumber/wireplumber.conf.d/52-quadcast-default-mic.conf"
# The QuadCast is the microphone whenever it's connected: its priority beats
# the onboard input's (about 2000, higher with a jack plugged in), so
# WirePlumber picks it as the default source unless one was chosen by hand.
monitor.alsa.rules = [
  {
    matches = [
      { node.name = "~alsa_input.usb-HP__Inc_HyperX_QuadCast_2_S_*" }
    ]
    actions = {
      update-props = {
        priority.session = 3000
        priority.driver = 3000
      }
    }
  }
]
```

Both match this one device. For another, `wpctl status` lists the outputs and inputs with a number each, and `wpctl inspect` with that number prints the `node.name` to match. WirePlumber reads the folder when it starts: `systemctl --user restart wireplumber`.

### Locking, screens off, and games

The lock screen is a second Quickshell config, `lock.qml`, next to the bar's `shell.qml`. It runs as its own process, which covers every monitor as soon as it starts and exits after the right password. Each monitor shows the time, the date and a password field.

```qml title="~/dotfiles/quickshell/.config/quickshell/lock.qml"
// Lock screen, one Quickshell process per lock: mango-lock starts it, it
// covers every monitor as soon as it loads and exits after the password.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

ShellRoot {
    id: root
    // A reload replaces the lock with a new one, which Quickshell 0.3.2
    // can't do while locked: it crashes and leaves the session locked.
    settings.watchFiles: false

    // Paradise palette
    readonly property color bg: "#151515"
    readonly property color fg: "#e8e3e3"
    readonly property color muted: "#a39d9d"
    readonly property color red: "#b66467"
    readonly property color blue: "#8da3b9"
    readonly property color border: "#424242"

    component Label: Text {
        font.family: "Maple Mono"
        font.pointSize: 11
        color: "#e8e3e3"
    }

    // Shared by every monitor, so they all show the same field whichever
    // one has the keyboard.
    property string input: ""
    property bool failed: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // No config set: PamContext uses /etc/pam.d/login.
    PamContext {
        id: pam
        onPamMessage: {
            if (responseRequired)
                respond(root.input);
        }
        onCompleted: result => {
            root.input = "";
            if (result === PamResult.Success)
                lock.locked = false;
            else
                root.failed = true;
        }
    }

    WlSessionLock {
        id: lock
        locked: true
        // secure goes false once Mango has released the screens.
        onSecureChanged: {
            if (!secure)
                Qt.quit();
        }

        WlSessionLockSurface {
            color: root.bg

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.pointSize: 72
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 36
                    text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                    color: root.muted
                }
                // Red after a wrong password, blue on the monitor that has
                // the keyboard.
                Rectangle {
                    implicitWidth: 360
                    implicitHeight: 36
                    color: root.bg
                    border.width: 2
                    border.color: root.failed ? root.red
                                : password.activeFocus ? root.blue : root.border

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.margins: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Maple Mono"
                        font.pointSize: 11
                        color: root.fg
                        echoMode: TextInput.Password
                        readOnly: pam.active
                        focus: true
                        onTextChanged: {
                            root.input = text;
                            if (text !== "")
                                root.failed = false;
                        }
                        onAccepted: {
                            if (text !== "" && !pam.active)
                                pam.start();
                        }
                        Keys.onEscapePressed: root.input = ""
                        Connections {
                            target: root
                            function onInputChanged() {
                                password.text = root.input;
                            }
                        }
                    }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: pam.active ? "Checking..."
                        : root.failed ? "Wrong password"
                        : "Enter to unlock, Escape to clear"
                    color: root.failed && !pam.active ? root.red : root.muted
                }
            }
        }
    }

    // `qs -p ~/.config/quickshell/lock.qml ipc call lock secure` prints true
    // once Mango has confirmed every monitor is covered.
    IpcHandler {
        target: "lock"
        function secure(): bool {
            return lock.secure;
        }
    }
}
```

Both monitors show the same field as you type, with a blue border on the one that has the keyboard. A wrong password empties it and turns it red; PAM takes two seconds to reject one, and the field reads "Checking..." meanwhile. `PamContext` without a `config` uses `/etc/pam.d/login`, so there's no PAM file to write.

The lock has its own file because Quickshell reloads a config every time you save it, and Quickshell 0.3.2 crashes when a reload replaces an active lock, which leaves the session locked with no field to type in. `settings.watchFiles: false` turns reloading off for `lock.qml` alone, so changes to it take effect at the next lock. The file is also [here](/files/mango-0.18/lock.qml) to download.

A small script starts it. With `-n`, `qs` exits if that config is already running, so a second lock request does nothing. The loop then waits until Mango confirms every monitor is covered, and swayidle holds off suspend until the script returns:

```sh title="~/dotfiles/bin/mango-lock"
#!/bin/sh
# Lock the screen and return once every monitor is covered, so swayidle -w
# holds off suspend until then. -n: already locked, do nothing.
lock="$HOME/.config/quickshell/lock.qml"
qs -n -d -p "$lock" || exit 1
for _ in $(seq 50); do
  [ "$(qs -p "$lock" ipc call lock secure 2>/dev/null)" = true ] && exit 0
  sleep 0.1
done
exit 1
```

swayidle runs from another script, which keeps its quoting out of Mango's config:

```sh title="~/dotfiles/bin/mango-idle"
#!/bin/sh
# lock after 10 minutes, monitors off after 15, lock before suspend
exec swayidle -w \
  timeout 600 /usr/local/bin/mango-lock \
  timeout 900 "wlopm --off '*'" resume "wlopm --on '*'" \
  before-sleep /usr/local/bin/mango-lock
```

```bash
sudo install -m 755 ~/dotfiles/bin/mango-idle ~/dotfiles/bin/mango-lock /usr/local/bin/
```

Super+Escape locks the screen by hand. It's a `bindl`, so it works while locked too. If the lock process dies, Mango keeps the session locked behind a plain dark gray screen, and Super+Escape starts a new lock that takes over.

`wlopm` turns the monitors off through the output power protocol, which Mango implements.

swayidle only counts keyboard and mouse input as activity. A game played with a controller reads the controller directly, so after ten minutes of only using the gamepad the screen would lock in the middle of the game. Mango has two options for this:

```ini title="~/dotfiles/mango/.config/mango/config.conf"
idle_inhibit_when_fullscreen=1
idle_inhibit_ignore_visible=1
```

With the first, Mango reports activity every second while the focused window is fullscreen, so swayidle never reaches its timeout during a fullscreen game. The second covers video: players and browsers ask the compositor not to go idle, and normally Mango only honours that while their window is visible; with it, a video on another tag or monitor also keeps the screen awake.

A windowed game from Steam is covered by the `idle_inhibit_when_focus` rule in [Window rules](#window-rules). For anything else, Super+Shift+i turns on caffeine: the bar shows `awake`, and swayidle neither locks the screen nor turns the monitors off until you press it again or click `awake`. Caffeine also turns off when Quickshell reloads, for example after you save `shell.qml`.

### Screen sharing

Mango's package ships `/usr/share/xdg-desktop-portal/mango-portals.conf`, which sends screenshots and screen sharing to the wlr portal and everything else, including the dark-mode setting, to the GTK one. There's nothing to change there, but the wlr portal needs a way to ask which monitor or window to share; without one, sharing fails without an error. I use wmenu, with a font size that makes it as tall as the bar it covers, and cap the stream at 60 fps so the 240 Hz monitor doesn't send four times what a video call can use:

```ini title="~/dotfiles/xdpw/.config/xdg-desktop-portal-wlr/config"
[screencast]
max_fps=60
chooser_type=dmenu
chooser_cmd=wmenu -p 'Share:' -l 10 -f 'Maple Mono 14.5' -N 151515 -n a39d9d -M 151515 -m 8da3b9 -S e8e3e3 -s 151515
```

Restart the portal after changing it: `systemctl --user restart xdg-desktop-portal-wlr`.

Fedora 45 ships xdg-desktop-portal-wlr 0.8.4, which has two open regressions: the stream freezing after the first frame ([#411](https://github.com/emersion/xdg-desktop-portal-wlr/issues/411)) and sharing failing with "No supported targets specified" ([#409](https://github.com/emersion/xdg-desktop-portal-wlr/issues/409)). Both reports say 0.8.2 works. If you hit one, those issues are where fixes and workarounds show up.

## A font for the desktop

On the desktop I use [Maple Mono](https://github.com/subframe7536/maple-font). It isn't packaged in Fedora, so it goes into the dotfiles as a Stow package. The `TTF` archive has the static weights; check it against the published checksum before unpacking:

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

The last command should print `MapleMono-Regular.ttf: "Maple Mono" "Regular"`. Quickshell, foot and wmenu all find it by that name. In foot the cursive italic shows up, but the ligatures don't: `->` and `!=` stay as separate characters.

The greeter runs as the `greetd` user, which can't read the fonts in your home directory. It gets a copy in the system's own folder for local fonts:

```bash
sudo install -Dm644 ~/.local/share/fonts/maple-mono/*.ttf -t /usr/local/share/fonts/maple-mono/
```

Maple Mono has no icon glyphs, and eza, yazi, Neovim's file tree and statusline and the buttons of the bar's music panel use them. The symbols-only Nerd Font from Terra fills that gap: foot finds it through fontconfig and uses it for any character Maple Mono lacks, so there's no need for a patched copy of the font:

```bash
sudo dnf install nerdfontssymbolsonly-nerd-fonts
```

## The shell: fish

I use [fish](https://fishshell.com/) with the [pure](https://github.com/pure-fish/pure) prompt, [fzf.fish](https://github.com/PatrickF1/fzf.fish) for fuzzy search, and a few tools that replace the classic commands:

```bash
sudo dnf install fish fzf fd-find bat eza zoxide ripgrep
```

| Package | Role |
| --- | --- |
| `fish` | the shell |
| `fzf`, `fd-find` | the fuzzy finder, and the file search fzf.fish runs |
| `bat` | `cat` with syntax highlighting; fzf.fish previews files with it |
| `eza` | `ls` with icons and git status |
| `zoxide` | `z` jumps to directories you visit often, `zi` picks one with fzf |
| `ripgrep` | `rg`, a faster grep |

The config is a Stow package with two files. `fish_plugins` lists the plugins for [fisher](https://github.com/jorgebucaran/fisher), fish's plugin manager, fisher included:

```txt title="~/dotfiles/fish/.config/fish/fish_plugins"
jorgebucaran/fisher
pure-fish/pure
patrickf1/fzf.fish
```

```fish title="~/dotfiles/fish/.config/fish/config.fish"
# Fedora adds ~/.local/bin to PATH in ~/.bashrc, which fish doesn't read.
# Outside the interactive block so scripts find these programs too.
fish_add_path -g ~/.local/bin

if status is-interactive
    # pure prompt: counts next to the git arrows, background jobs, the
    # duration of commands that take 2 s or more, and a green ❯
    set -g pure_show_numbered_git_indicator true
    set -g pure_show_jobs true
    set -g pure_threshold_command_duration 2
    set -g pure_color_success green

    # z/zi jump to frequent directories; cd stays untouched
    zoxide init fish | source

    # bat and fzf use the terminal's 16 colors, so they follow foot's palette
    set -gx BAT_THEME ansi
    set -gx FZF_DEFAULT_OPTS --color=16

    # bat
    alias cat 'bat --paging=never'

    # eza
    alias ls 'eza --icons --group-directories-first'
    alias ll 'eza --icons --group-directories-first -l --git'
    alias la 'eza --icons --group-directories-first -la --git'
    alias lt 'eza --icons --group-directories-first --tree'

    # git
    alias g git
    alias gs 'git status'
    alias ga 'git add'
    alias gaa 'git add --all'
    alias gc 'git commit'
    alias gcm 'git commit -m'
    alias gp 'git push'
    alias gpl 'git pull'
    alias gl 'git log --oneline --graph --decorate'
    alias gd 'git diff'
    alias gco 'git checkout'
    alias gb 'git branch'

    # nvim
    alias vim nvim
    alias vi nvim
    alias v nvim

    # extras
    alias grep rg
    alias rm 'rm -i'
    alias cp 'cp -i'
    alias mv 'mv -i'
end
```

The first line puts `~/.local/bin` on `PATH`. Fedora does that in `~/.bashrc`, which fish doesn't read, and the line sits outside the interactive block so scripts run by fish find those programs too.

The aliases only exist in interactive shells, so scripts still get the real `cat`, `ls` and `grep`. pure, fish's syntax highlighting and eza use the terminal's named colors, and the two variables do the same for bat and fzf, so all of them take their colors from foot's Paradise palette.

Link the package and make fish your login shell:

```bash
stow --no-folding -d ~/dotfiles -t ~ fish
chsh -s /usr/bin/fish
```

Log out and back in. greetd still starts Mango through `/bin/sh` and `/etc/profile`, so the session's environment stays the same, and foot and tmux open fish because they start your login shell. Then, in fish, fetch fisher and let it install everything in `fish_plugins`:

```fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update
```

fisher puts the plugins' files in `~/.config/fish` as regular files, outside the repo; on another machine the same command installs them again from `fish_plugins`.

The prompt shows the directory and the git branch on one line, with `*` when the tree has uncommitted changes, `⇡2` or `⇣1` when you're ahead of or behind the remote, and how long the last command took if it ran for 2 s or more. `❯` sits on the line below, green after a command that succeeded and red after one that failed, with the number of background jobs in front of it when there are any.

| Keys | Action (fzf.fish) |
| --- | --- |
| Ctrl+R | search the command history |
| Ctrl+Alt+F | search files below the current directory |
| Ctrl+Alt+L | search the git log |
| Ctrl+Alt+S | search `git status` |
| Ctrl+Alt+P | search running processes |
| Ctrl+V | search shell variables |

Ctrl+V replaces fish's own paste binding; in foot, Ctrl+Shift+V pastes.

## Paradise everywhere

Mango's borders and everything Quickshell draws get their colors from the files above. The other programs read their own config files.

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

For zathura I use the [Paradise zathurarc](https://github.com/paradise-theme/paradise/blob/main/cfg/zathura/zathurarc) as it is, with the font line changed to `set font "Maple Mono 11"`.

yazi's own theme has rounded ends on its blocks and uses `gray` as a background, which in this palette is the near-white of the text. Mine squares the ends and names the terminal's colors instead of writing hex codes, so `foot.ini` stays the only file with the palette:

```toml title="~/dotfiles/yazi/.config/yazi/theme.toml"
# Paradise chrome for yazi: square edges instead of rounded powerline caps,
# colours by ANSI name so foot.ini stays the single palette.
# In yazi "gray" is ANSI 7 (#e8e3e3 here) and "darkgray" is ANSI 8 (#424242);
# the stock theme uses "gray" as a background, which is near-white in Paradise.
#:schema https://yazi-rs.github.io/schemas/theme.json

[mgr]
border_style = { fg = "darkgray" }
count_copied = { fg = "black", bg = "green" }
count_cut    = { fg = "black", bg = "red" }

[tabs]
active    = { fg = "black", bg = "blue", bold = true }
inactive  = { fg = "white", bg = "darkgray" }
sep_inner = { open = "", close = "" }
sep_outer = { open = "", close = "" }

# Same blocks as the tmux status line: accent bg with dark bold text,
# secondary segments on #424242.
[mode]
normal_main = { fg = "black", bg = "blue", bold = true }
normal_alt  = { fg = "white", bg = "darkgray" }
select_main = { fg = "black", bg = "yellow", bold = true }
select_alt  = { fg = "white", bg = "darkgray" }
unset_main  = { fg = "black", bg = "red", bold = true }
unset_alt   = { fg = "white", bg = "darkgray" }

# Hovered row: #424242 bar (tmux mode-style) instead of reverse video.
[indicator]
parent  = { bg = "darkgray" }
current = { bg = "darkgray", bold = true }
padding = { open = " ", close = " " }

[status]
sep_left  = { open = "", close = "" }
sep_right = { open = "", close = "" }

# Folder and fallback icons in palette colours. File-type icons (`files`,
# `exts`) keep yazi's devicon colours.
[icon]
dirs = [
	{ name = ".config", text = "", fg = "blue" },
	{ name = ".git", text = "", fg = "blue" },
	{ name = ".github", text = "", fg = "blue" },
	{ name = ".npm", text = "", fg = "blue" },
	{ name = "Desktop", text = "", fg = "blue" },
	{ name = "Development", text = "", fg = "blue" },
	{ name = "Documents", text = "", fg = "blue" },
	{ name = "Downloads", text = "", fg = "blue" },
	{ name = "Library", text = "", fg = "blue" },
	{ name = "Movies", text = "", fg = "blue" },
	{ name = "Music", text = "", fg = "blue" },
	{ name = "Pictures", text = "", fg = "blue" },
	{ name = "Public", text = "", fg = "blue" },
	{ name = "Videos", text = "", fg = "blue" },
]
conds = [
	# Special files
	{ if = "orphan", text = "", fg = "red" },
	{ if = "link", text = "", fg = "cyan" },
	{ if = "block", text = "", fg = "yellow" },
	{ if = "char", text = "", fg = "yellow" },
	{ if = "fifo", text = "", fg = "yellow" },
	{ if = "sock", text = "", fg = "yellow" },
	{ if = "sticky", text = "", fg = "yellow" },
	{ if = "dummy", text = "", fg = "red" },

	# Fallback
	{ if = "dir & hovered", text = "", fg = "blue" },
	{ if = "dir", text = "", fg = "blue" },
	{ if = "exec", text = "", fg = "green" },
	{ if = "!dir", text = "", fg = "white" },
]
```

The icons between the quotes are Nerd Font glyphs. This page's font doesn't have them, so they show as empty boxes here, but they copy as they are.

GTK and Qt programs don't get Paradise. Here that shows mostly in the file picker that Discord and Firefox open through `xdg-desktop-portal-gtk`, which is GTK3 and light by default. Two settings turn it dark, and the portal passes the same preference on to programs that ask for it, such as Firefox with its system theme and websites that follow `prefers-color-scheme`:

```bash
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
```

Run them once from a terminal inside Mango; `gsettings` keeps them in dconf, so they last across logins. The colors are GNOME's dark grays rather than Paradise. The tray menus follow the same preference: they're Qt menus, and the bar tells Qt to ask the portal for it.

### GRUB

The boot menu gets the palette too. GRUB draws its menu from a theme, a text file with positions and colors next to a few PNGs. Mine is a bordered box in the middle of the screen with the entries inside, a blue bar on the selected one, and an icon for Fedora and for Windows:

```txt title="~/dotfiles/grub/theme.txt"
# Paradise, square: GRUB 2.12 theme for a 2560x1440 screen. Sizes are in
# pixels and positions are measured from the centre, so it also fits 1920x1080.
# The PNGs come from render.py; install.sh copies everything to /boot.
#
# The font is Unifont because with Secure Boot GRUB refuses every font file on
# disk ("prohibited by secure boot policy") and only has the one built into its
# signed image. Its glyphs are 8px wide and 16px tall.

title-text: ""
desktop-color: "#151515"

# The frame holds six 32px entries: three kernels, rescue, Windows, firmware.
# height = 6 * item_height + 2 * item_padding + 2 * 2px of border.
# width fits the longest title, the 81 characters of the rescue entry.
+ boot_menu {
  left = 50%-370
  top = 50%-106
  width = 740
  height = 212

  menu_pixmap_style = "menu_*.png"
  selected_item_pixmap_style = "select_*.png"
  scrollbar = false

  item_font = "Unifont Regular 16"
  item_color = "#e8e3e3"
  selected_item_color = "#151515"

  item_height = 32
  item_padding = 8
  item_spacing = 0

  icon_width = 24
  icon_height = 24
  item_icon_space = 12
}

# Countdown, 12px under the frame. GRUB hides it once a key is pressed.
+ label {
  id = "__timeout__"
  text = "%ds"
  left = 50%-370
  top = 50%+118
  width = 740
  height = 20
  align = "left"
  font = "Unifont Regular 16"
  color = "#a39d9d"
}

+ label {
  text = "↑↓ select   enter boot   e edit   c console"
  left = 0
  top = 100%-52
  width = 100%
  height = 20
  align = "center"
  font = "Unifont Regular 16"
  color = "#a39d9d"
}
```

The theme, its images, the script that draws them and the installer are in [grub-paradise.tar.gz](/files/mango-0.18/grub-paradise.tar.gz):

```bash
mkdir -p ~/dotfiles/grub
tar xzf grub-paradise.tar.gz -C ~/dotfiles/grub
sudo ~/dotfiles/grub/install.sh
```

`install.sh` copies the theme to `/boot/grub2/themes/paradise`, sets `GRUB_TERMINAL_OUTPUT`, `GRUB_GFXMODE` and `GRUB_THEME` in `/etc/default/grub`, and regenerates `grub.cfg`. It saves the file it found as `/etc/default/grub.pre-paradise` the first time, and running it again does no harm. `GRUB_GFXMODE` is `2560x1440,auto`; put your monitor's resolution there before running it. The theme measures its positions from the centre of the screen, so it fits other sizes without changes.

With Secure Boot on, GRUB can't load modules from disk, so the theme only works if Fedora's signed GRUB already contains the PNG reader and the graphical menu; the script checks for both and changes nothing when one is missing. GRUB also refuses every font file on disk, Maple Mono included, so the text is in Unifont, the one font built into that image.

`render.py` draws the PNGs: flat squares for the frame and the bar, and the two icons from their SVG files. Run it after changing a color or a size in it; it needs `python3-gobject`.

## Firefox

Firefox reads two stylesheets from the profile: `userChrome.css` for the interface and `userContent.css` for its own pages, like Settings and New Tab. Mine square every corner and use the desktop's palette and font. They assume the tabs are in the sidebar and were written for Firefox 159: [userChrome.css](/files/mango-0.18/firefox/userChrome.css) and [userContent.css](/files/mango-0.18/firefox/userContent.css).

They need four preferences in `about:config`:

```txt title="about:config"
toolkit.legacyUserProfileCustomizations.stylesheets  true
browser.nova.enabled                                 false
browser.compactmode.show                             true
sidebar.verticalTabs                                 true
```

The first makes Firefox load the stylesheets, and the second turns off its newer, rounder look. The third brings back the Compact density; pick it under Density in Customize Toolbar. Use the built-in Dark theme underneath.

Firefox loads the files from a `chrome` folder inside the profile, and the profile folder has a random name that `about:support` shows on the Profile Folder row. Stow can't aim at a name it doesn't know, so the folder stays in the repository and the profile gets a symlink to it:

```bash
ln -s ~/dotfiles/firefox/chrome ~/.config/mozilla/firefox/xxxxxxxx.default-release/chrome
```

Older profiles live in `~/.mozilla/firefox/` instead. Firefox reads the files only at startup, so restart it after every change.

With the files in place:

- Every radius variable Firefox defines goes to 0. Many components define them again on their own element, so the file sets them on `*` rather than `:root`.
- Toolbars, sidebar and menus are `#151515`, hover is `#1c1c1c`, borders are `#424242`, and focus and links are blue.
- The selected tab has a blue edge on the left, like Mango's focused window. A background tab whose title changed, as WhatsApp or Gmail do when a message arrives, gets a green edge in the same place instead of Firefox's dot over the icon.
- Settings, New Tab and the other `about:` pages get the same corners and colors, while websites keep their own.
- The suggestions under a text field of a page, such as form history and saved logins, get light text. Firefox takes their text color from the page, which on a light page left dark text on the dark panel.

All of this relies on Firefox's internal variables, and an update can rename one. The crossword widget on New Tab is the most fragile part: it's a Mozilla web page inside a frame, styled through the variable names of its own stylesheet. When something turns round or purple again, the Browser Toolbox (Ctrl+Alt+Shift+I) shows which variable it uses now; it opens once `devtools.chrome.enabled` and `devtools.debugger.remote-enabled` are `true`.

## NVIDIA

I started Mango with no extra environment variables and only add one when it fixes something I can see. Mango enables explicit sync by default (`sync_obj_enable=1`), and its documentation has no NVIDIA section. Two reports matter for this machine:

- [mango#1594](https://github.com/mangowm/mango/issues/1594), opened against 0.18.5 with driver 615.78 on a 2560x1440 monitor: with a single window on screen, its right edge glitches and partly disappears. That is my 27" monitor's resolution. Check whether you see it, and follow the issue for a fix.
- Rounded corners render jagged on NVIDIA ([mango#1387](https://github.com/mangowm/mango/issues/1387)). The fix is waiting in scenefx; `border_radius=0` avoids it.

If something else looks wrong, these are the [wlroots variables](https://gitlab.freedesktop.org/wlroots/wlroots/-/raw/0.20/docs/env_vars.md) that match the usual symptoms. Set them one at a time with `env=NAME,value` in Mango's config, then log out and back in, since they're read at startup:

| Symptom | Variable |
| --- | --- |
| Cursor invisible, offset or flickering | `WLR_NO_HARDWARE_CURSORS=1` |
| Freezes or flicker that look like sync problems | `WLR_RENDER_NO_EXPLICIT_SYNC=1` |
| Black screen or modeset failure on the high refresh rate monitor | `WLR_DRM_NO_MODIFIERS=1` |

To see what Mango is doing, start it with `mango -d` from a console and read the log it prints.

## Gaming

Steam is in RPM Fusion's nonfree repository, which part 1 enabled. gamescope, MangoHud and GameMode are in Fedora:

```bash
sudo dnf install steam gamescope mangohud gamemode
```

Steam runs through XWayland. The 32-bit NVIDIA libraries it needs came with the driver in part 1; `rpm -q xorg-x11-drv-nvidia-libs.i686` confirms it.

Steam's launch options for a game take these tools as prefixes before `%command%`:

| Launch option | Effect |
| --- | --- |
| `gamemoderun %command%` | GameMode tunes the CPU governor and scheduling while the game runs |
| `mangohud %command%` | FPS, frame times and GPU temperature overlay |
| `gamescope -W 2560 -H 1440 -r 240 --adaptive-sync -- %command%` | runs the game in its own nested compositor at the 27" monitor's resolution and refresh rate |

Inside gamescope, use its `--mangoapp` flag instead of `mangohud`.

For VRR, the `vrr_only_fullscreen` rule enables adaptive sync on a monitor while a window is fullscreen there and disables it when the window leaves fullscreen. On NVIDIA, the driver's README says its KMS implementation "forces all VRR capable displays into VRR mode by default", so the monitor may run in VRR mode on the desktop too, whatever Mango asks for. Watch the refresh rate counter in the monitor's on-screen menu: if it moves around on the desktop, the driver is doing it. The `conceal_vrr_caps=1` option of the `nvidia_modeset` module stops that, but it hides VRR from Mango as well, so games lose it too.

## Where this leaves you

Mango starts from greetd with both monitors at their full refresh rate and every tag scrolling, the Quickshell bar shows tags, the clock, music, volume and the tray, the menu and the keymap cheatsheet are one key away, foot opens fish with the pure prompt, and the tools around it share one palette and one font. All of it lives in `~/dotfiles` as Stow packages, with Mango itself kept up to date by dnf.

Part 3 covers my Neovim config.

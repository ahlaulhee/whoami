---
slug: mango-0.18-setup
title: Building a Mango desktop on Fedora 45
description: Mango 0.18 with the scrolling layout on every tag, a Quickshell status bar, kew for music, greetd, fish with the pure prompt, both monitors at full refresh, and Steam on NVIDIA.
pubDate: 2026-11-08
updatedDate: 2026-11-10
tags: [mango, wayland, quickshell, fish, firefox, fedora, nvidia, gaming]
testedOn: [Fedora 45, Mango 0.18.5, Quickshell 0.3.2, fish 4.6, akmod-nvidia 615.78, RTX 5070]
series:
  name: Fedora 45 + Mango from scratch
  part: 2
draft: false
---

Part 1 left a Fedora 45 machine at a text console, with RPM Fusion, the codecs and the NVIDIA driver in place. This part turns it into my desktop: [Mango](https://github.com/mangowm/mango) 0.18 with the scrolling layout on every tag, a status bar written in [Quickshell](https://quickshell.org/), kew for music, a text login screen, both monitors at their full refresh rate, and Steam.

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
├── bin/{mango-idle,mango-lock}        # copied to /usr/local/bin
├── firefox/chrome/{userChrome,userContent}.css   # linked by hand, see Firefox
├── fish/.config/fish/{config.fish,fish_plugins}
├── fonts/.local/share/fonts/maple-mono/
├── foot/.config/foot/foot.ini
├── kew/.config/kew/themes/paradise.theme
├── mango/.config/mango/config.conf
├── quickshell/.config/quickshell/{shell,lock}.qml
├── xdpw/.config/xdg-desktop-portal-wlr/config
└── zathura/.config/zathura/zathurarc
```

```bash
sudo dnf install stow
git init ~/dotfiles
```

Once the files exist, link them by naming the folders:

```bash
stow --no-folding -d ~/dotfiles -t ~ fish fonts foot kew mango quickshell xdpw zathura
```

Without `--no-folding`, Stow links whole directories when it can, so `~/.config/mango` itself would point into the repo and any file a program creates there would show up in `git status`. With it, Stow creates real directories and links only the files. `bin` and `firefox` stay out of the list: the scripts are copied to `/usr/local/bin`, and the Firefox folder goes into a profile whose name Stow can't know.

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
tag_num=9
tag_rule=id:*,layout_name:scroller
circle_layout=scroller,tile,monocle
monocle_tab_mode=0
view_current_to_back=1

# new windows take 80% of the width; Super+r cycles through the presets
scroller_default_proportion=0.8
scroller_proportion_preset=0.5,0.8,1.0
# a lone window fills the screen
scroller_ignore_proportion_single=1
# keep the focused column centred
scroller_prefer_overspread=0
scroller_focus_center=1
```

`tag_rule=id:*` applies the scroller to every tag on both monitors. New windows open at 80% of the screen width, so the neighbouring window always shows at the edge, and the focused one stays centred while you move through the strip. Super+Shift+space still switches a tag to `tile` or `monocle` when a scrolling strip isn't what you want. Monocle normally draws a tab bar over its windows, in Mango's own colors and with rounded corners; `monocle_tab_mode=0` turns it off. With `view_current_to_back=1`, pressing Super and the number of the tag you're already on goes back to the tag you came from.

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

animations=0
layer_animations=0
blur=0
blur_layer=0
shadows=0
layer_shadows=0
```

The colors are the [Paradise](https://github.com/paradise-theme/paradise) palette, the one this site uses, written as `0xRRGGBBAA`. The four after `urgent_color` are the borders of windows in the scratchpad, pinned to every tag, kept above the rest or maximized, all states the keybinds below put a window in. The `jump_label_decorate_*` lines style the letters that jump mode puts over each window. Mango draws through scenefx, which can round corners and add blur, shadows and animations. I turn all of it off. Rounded corners come out jagged on NVIDIA's driver ([mango#1387](https://github.com/mangowm/mango/issues/1387)), so `border_radius=0` is more than taste, and without animations the [NVIDIA bug](#nvidia) below is easier to tell apart from an effect.

### Autostart

```ini title="~/dotfiles/mango/.config/mango/config.conf"
exec_once=swaybg -c 151515
exec_once=wl-clip-persist --clipboard regular
exec_once=wl-paste --watch cliphist store
exec_once=/usr/local/bin/mango-idle
exec_once=qs
```

`exec_once` runs a command once at login, and `exec` runs it again on every reload. Mango exports its environment to systemd and D-Bus and starts a `mango-session.target` by itself, so nothing here does that; the screen-sharing portal finds the session without help. `qs` is Quickshell, which draws the status bar, the volume OSD, the notifications and the polkit password prompt. `wl-clip-persist` keeps what you copied after the program you copied it from closes. `mango-idle` is a short script covered in [Locking, screens off, and games](#locking-screens-off-and-games).

### Window rules

```ini title="~/dotfiles/mango/.config/mango/config.conf"
window_rule=is_term:1,app_id:^foot$
window_rule=vrr_only_fullscreen:1,app_id:.*
window_rule=is_floating:1,app_id:^steam$,title:^(Friends List|Steam Settings)$
window_rule=confine_pointer:1,app_id:^steam_app_.*$
window_rule=idle_inhibit_when_focus:1,app_id:^(steam_app_.*|gamescope)$
window_rule=is_tag_silent:1,app_id:^(steam|discord)$

# to try: tearing in fullscreen games
#allow_tearing=2
#window_rule=force_tearing:1,app_id:^steam_app_.*$
#env=WLR_DRM_NO_ATOMIC,1
```

The first rule marks foot as the terminal. When a graphical program started from foot opens, it takes the terminal's place, and the terminal comes back when the program exits. The second turns VRR on for any window while it's fullscreen; Mango requires an `app_id` or `title` in every rule, so `.*` stands for all of them. Narrow it to `^(steam_app_.*|gamescope)$` if you'd rather keep fullscreen video at a fixed refresh rate. The third floats Steam's friends list and settings window instead of giving them a column.

The next three are for games. Steam starts every game with an app id of `steam_app_` followed by the game's number. `confine_pointer` keeps the cursor inside the game while it has focus, so a mouse flick in a shooter doesn't land on the other monitor. `idle_inhibit_when_focus` keeps the screen from locking or turning off while a game is focused, windowed or not; [Locking, screens off, and games](#locking-screens-off-and-games) explains why that needs help. `is_tag_silent` stops Steam and Discord from pulling you to their tag when they ask for attention, such as an update window or a message in the middle of a game. Mango marks their window urgent instead, and the bar shows its tag in red.

The commented lines are tearing, which lets a fullscreen game show a frame as soon as it's ready instead of waiting for the monitor's refresh. It lowers latency, at the cost of a visible line where two frames meet. Mango's documentation says some cards also need `WLR_DRM_NO_ATOMIC`, which changes how Mango drives the monitors. Try it with a game you know before keeping it, and log out and back in after adding the `env` line.

### Keyboard layouts

```ini title="~/dotfiles/mango/.config/mango/config.conf"
xkb_rules_layout=us,latam
```

US comes first, so it's the layout Mango starts with. Super+space switches to Latin American Spanish and back; the bar shows the active one, and `mmsg get keyboardlayout` prints it. `bind` matches the physical key, so the bindings below keep working while latam is active.

### Keybinds

Bindings are `bind=MODIFIERS,key,dispatcher,arguments`. `spawn` runs a program directly, `spawn_shell` runs the line through a shell for pipes and `$(...)`, and `bindl` keeps working on the lock screen:

```ini title="~/dotfiles/mango/.config/mango/config.conf"
bind=SUPER,Return,spawn,foot
bind=SUPER,p,spawn_shell,wmenu-run -f 'Maple Mono 11' -N 151515 -n a39d9d -M 151515 -m 8da3b9 -S e8e3e3 -s 151515
bind=SUPER,n,spawn,foot -e nnn
bind=SUPER,v,spawn_shell,cliphist list | wmenu -l 10 -f 'Maple Mono 11' -N 151515 -n a39d9d -M 151515 -m 8da3b9 -S e8e3e3 -s 151515 | cliphist decode | wl-copy
bind=SUPER+SHIFT,s,spawn_shell,grim -g "$(slurp)" - | wl-copy
bind=NONE,Print,spawn_shell,grim "$HOME/Pictures/$(date +%F_%H-%M-%S).png"
bind=SUPER+SHIFT,x,spawn,grimpicker --copy --notify
bind=SUPER+SHIFT,i,spawn,qs ipc call idle toggle
bind=SUPER,b,spawn,qs ipc call bar toggle
bind=SUPER,o,spawn,qs ipc call audio next
bindl=SUPER,Escape,spawn,/usr/local/bin/mango-lock

bindl=NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
bindl=NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl=NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
axisbind=SUPER,UP,spawn,wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
axisbind=SUPER,DOWN,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-

bind=SUPER,h,focusdir,left
bind=SUPER,l,focusdir,right
bind=SUPER,k,focusdir,up
bind=SUPER,j,focusdir,down
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
bind=SUPER,w,killclient,
mousebind=SUPER,btn_left,moveresize,curmove
mousebind=SUPER,btn_right,moveresize,curresize
drag_tile_to_tile=1

bind=SUPER+SHIFT,minus,minimized,
bind=SUPER,minus,toggle_scratchpad,
bind=SUPER+CTRL,minus,restore_minimized,

bind=SUPER,c,setlayout,scroller
bind=SUPER,t,setlayout,tile
bind=SUPER,m,setlayout,monocle
bind=SUPER+SHIFT,space,switch_layout,
bind=SUPER,space,switch_keyboard_layout,
bind=SUPER+ALT,0,togglegaps,

bind=SUPER,1,view,1
bind=SUPER+SHIFT,1,tag,1
# ...the same pair for tags 2 to 9

bind=SUPER,period,focusmon,next
bind=SUPER+SHIFT,period,tagmon,next

bind=SUPER+SHIFT,r,reload_config
bind=SUPER+SHIFT,q,quit
```

| Keys | Action |
| --- | --- |
| Super+Return | terminal |
| Super+p | launcher (wmenu) |
| Super+h/j/k/l | focus left, down, up, right, without leaving the monitor |
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
| Super+w | close the window |
| Super+drag | left button moves a floating window or swaps two tiled ones; right button resizes |
| Super+space | switch between the US and Latin American layouts |
| Super+Shift+space | cycle scroller, tile and monocle |
| Super+1 to 9, Super+Shift+1 to 9 | view a tag, move the window to a tag; the current tag's number goes back to the previous tag |
| Super+period | focus the other monitor |
| Super+Shift+period | move the window to the other monitor |
| Super+n | nnn in a terminal |
| Super+v | pick an entry from the clipboard history |
| Super+Shift+s | screenshot of a region, to the clipboard |
| Print | screenshot of everything, to `~/Pictures` |
| Super+Shift+x | pick a color, copy its hex code |
| Super+Escape | lock the screen |
| Super+Shift+i | caffeine: keep the screen from locking or turning off, or stop |
| Super+b | show or hide the bar |
| Super+o | switch to the next audio output |
| Super+scroll | volume |
| Super+Shift+r | reload the config |

### Check the config

```bash
mango -c ~/.config/mango/config.conf -p
```

No output means the file parsed. Errors print as `[ERROR]` lines with the file and line number, but the exit code is 0 either way, so read the output rather than `$?`.

## Log in with greetd and tuigreet

[greetd](https://git.sr.ht/~kennylevinsen/greetd) is a small login daemon and tuigreet is a text greeter for it:

```bash
sudo dnf install greetd tuigreet
```

Mango needs no wrapper script: it sets `XDG_CURRENT_DESKTOP=mango` and imports its environment into the systemd user session itself. Replace the default session in `/etc/greetd/config.toml`; Fedora runs the greeter as the `greetd` user:

```toml title="/etc/greetd/config.toml"
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd mango"
user = "greetd"
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

## Quickshell: bar, OSD, notifications and polkit

Quickshell is a toolkit for writing desktop shells in QML, the declarative language Qt uses for interfaces. The whole shell is one QML file that Quickshell reloads every time you save it. Mine has four parts:

- A bar docked along the top of each monitor, from one corner to the other, with the tags on the left, the focused window's title in the middle, and the current song, volume, microphone, keyboard layout, notification count, date and the system tray on the right.
- A volume OSD, a small box that shows the output, a level bar and the percentage for a moment whenever the volume changes.
- Notification popups, a history of them and a do-not-disturb switch.
- The password prompt for programs that ask polkit for privileges.

The lock screen is also written in Quickshell, in a separate file that runs as its own process. It's covered in [Locking, screens off, and games](#locking-screens-off-and-games).

Fedora 45 has Quickshell, but its package is a February 2026 snapshot from before version 0.3. The [errornointernet/quickshell](https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/) COPR has the current release, 0.3.2, and replaces Fedora's package when enabled:

```bash
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell
```

Quickshell has modules for the Hyprland and i3 IPC, but none for Mango. It doesn't need one: `mmsg watch tags DP-1` prints the tags of a monitor as one JSON object per line every time they change, and `mmsg watch focusing-client` does the same for the focused window. The bar runs both and parses the lines. Volume, microphone and the list of outputs come from Quickshell's PipeWire service, the tray from its StatusNotifier service, and the song from kew's MPRIS interface, the standard D-Bus interface media players use to report what they're playing. The notifications come from its notification server and the password prompt from its polkit agent, both built into the COPR package.

```qml title="~/dotfiles/quickshell/.config/quickshell/shell.qml"
//@ pragma UseQApplication
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

    // Text in the bar font. Colors default to fg; callers override.
    component Label: Text {
        font.family: "Maple Mono"
        font.pointSize: 11
        color: "#e8e3e3"
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

    // Focused window title (null title when nothing has focus).
    property string windowTitle: ""
    MmsgWatch {
        command: ["mmsg", "watch", "focusing-client"]
        onMessage: c => root.windowTitle = c.title ?? ""
    }

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

    // kew's built-in MPRIS server; any other MPRIS player is ignored.
    readonly property MprisPlayer music: Mpris.players.values
        .find(p => p.identity === "kew") ?? null

    // Volume widget for a PipeWire node: click mutes, wheel changes by 5 %,
    // right click emits rightClicked (the output list for "vol").
    component Volume: Label {
        id: vol
        required property string label
        property PwNode node
        readonly property PwNodeAudio audio: node?.audio ?? null
        signal rightClicked
        visible: audio !== null
        text: audio ? `${label} ${Math.round(audio.volume * 100)}%` : ""
        color: audio?.muted ? "#a39d9d" : "#e8e3e3"
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    vol.rightClicked();
                else
                    vol.audio.muted = !vol.audio.muted;
            }
            onWheel: wheel => {
                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                vol.audio.volume = Math.max(0, Math.min(1, vol.audio.volume + step));
            }
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

    // Volume OSD: 1.5 s after the output's volume, mute or the output itself
    // changes. Changes during the first sync with PipeWire don't count.
    property bool osdVisible: false
    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }
    function showOsd(): void {
        if (!Pipewire.ready || !Pipewire.defaultAudioSink?.ready)
            return;
        root.osdVisible = true;
        osdTimer.restart();
    }
    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        function onVolumeChanged() { root.showOsd(); }
        function onMutedChanged() { root.showOsd(); }
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { root.showOsd(); }
    }

    // LazyLoader creates the window each time it's shown. A layer surface
    // without a screen goes to the monitor Mango has focused.
    LazyLoader {
        active: root.osdVisible

        PanelWindow {
            id: osd
            readonly property PwNode sink: Pipewire.defaultAudioSink
            readonly property real volume: sink?.audio?.volume ?? 0
            readonly property bool muted: sink?.audio?.muted ?? false
            anchors.bottom: true
            margins.bottom: 120
            exclusiveZone: 0
            implicitWidth: 360
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

                    Label {
                        text: osd.sink?.description || osd.sink?.name || ""
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

    // One bar per monitor.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData
            visible: root.barVisible

            // Docked to the top edge, full width. The default exclusionMode
            // (Auto) reserves an exclusive zone as tall as the bar.
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 28
            color: root.bg

            // Tags of this output: [{index, is_active, is_urgent, client_count, ...}]
            property var tags: []
            MmsgWatch {
                command: ["mmsg", "watch", "tags", bar.modelData.name]
                onMessage: m => bar.tags = m.tags
            }

            // Left: active and occupied tags; click views the tag on this output.
            Row {
                id: left
                anchors.left: parent.left
                height: parent.height

                Repeater {
                    model: bar.tags

                    Rectangle {
                        id: tag
                        required property var modelData
                        visible: modelData.is_active || modelData.client_count > 0
                        width: 28
                        height: bar.height
                        color: modelData.is_urgent ? root.red
                             : modelData.is_active ? root.fg : root.bg

                        Label {
                            anchors.centerIn: parent
                            text: tag.modelData.index
                            color: tag.modelData.is_active || tag.modelData.is_urgent
                                   ? root.bg : root.muted
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached(["mmsg", "dispatch",
                                `viewcrossmon,${tag.modelData.index},${bar.modelData.name}`])
                        }
                    }
                }
            }

            // Middle: focused window title, centered on the screen and kept
            // clear of whichever side is wider.
            Label {
                anchors.centerIn: parent
                width: Math.min(implicitWidth,
                                bar.width - 2 * Math.max(left.width, right.width) - 32)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.windowTitle
            }

            // Right: music, volume, mic, keyboard layout, caffeine,
            // notifications, clock, tray.
            RowLayout {
                id: right
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Label {
                    readonly property MprisPlayer player: root.music
                    visible: player !== null
                    text: player ? `${player.isPlaying ? "▶" : "‖"} ${player.trackArtist} - ${player.trackTitle}` : ""
                    color: player?.isPlaying ? root.fg : root.muted
                    Layout.maximumWidth: 400
                    elide: Text.ElideRight
                    MouseArea {
                        anchors.fill: parent
                        onClicked: parent.player.togglePlaying()
                    }
                }

                // Right click lists the outputs; clicking one switches to it.
                // A click anywhere else closes the list.
                Volume {
                    id: volume
                    label: "vol"
                    node: Pipewire.defaultAudioSink
                    onRightClicked: outputs.visible = !outputs.visible

                    PopupWindow {
                        id: outputs
                        // Just below the bar, left edge under the label.
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
                    label: "mic"
                    node: Pipewire.defaultAudioSource
                }

                // Keyboard layout; a click switches to the next one.
                Label {
                    visible: text !== ""
                    text: root.layoutCodes[root.keyboardLayout] ?? root.keyboardLayout
                    color: root.muted
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"])
                    }
                }

                // Shown while caffeine is on; a click turns it off.
                Label {
                    visible: root.caffeine
                    text: "awake"
                    color: root.blue
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.caffeine = false
                    }
                }

                // Notification count. Left click lists the history, right
                // click toggles do not disturb. A click elsewhere closes it.
                Label {
                    id: notif
                    readonly property int count: root.notificationHistory.length
                    text: `${root.dnd ? "dnd" : "notif"} ${count}`
                    color: root.dnd ? root.blue : count > 0 ? root.fg : root.muted
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                root.dnd = !root.dnd;
                            else
                                history.visible = !history.visible;
                        }
                    }

                    PopupWindow {
                        id: history
                        // Just below the bar, right edge under the label.
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

                Label {
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM HH:mm")
                }

                // System tray: left click activates, right click opens the menu.
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
```

Clicking a tag shows it on that bar's monitor, clicking the song pauses or resumes it, and scrolling over `vol` or `mic` changes the volume, with a click to mute. Clicking the keyboard layout switches to the next one. Right-clicking `vol` lists the audio outputs, and Super+o moves to the next one without opening the list; WirePlumber remembers the choice across reboots. The list only shows separate devices, so headphones in the front jack of the same sound card don't appear there, and WirePlumber switches to them by itself when you plug them in.

Clicking `notif` lists the last 50 notifications, newest first; clicking one removes it. Right-clicking `notif` turns on do not disturb, which hides every popup except critical ones while the history keeps recording. The history only keeps the text, and it empties when Quickshell reloads, for example when you save this file. `pkexec true` brings up the polkit prompt if you want to try it.

Three lines in the code aren't obvious from the result. `PwObjectTracker` has to bind the default output and input, or PipeWire never sends their volume. The tray menus only open because of the `UseQApplication` pragma on the first line, and they keep Qt's light style instead of Paradise. And `expireTimeout` arrives in milliseconds, although Quickshell's documentation says seconds.

The file is also [here](/files/mango-0.18/shell.qml) to download.

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

kew publishes what it's playing over MPRIS under the name `kew`, which is how the bar shows the song, and `playerctl -p kew play-pause` controls it from the command line. Covers need a terminal that can draw images; foot does it through sixel, which kew picks automatically.

## The rest of the desktop

```bash
sudo dnf install foot wmenu swaybg libnotify swayidle wlopm firefox discord playerctl jq \
  wl-clipboard cliphist grim slurp grimpicker \
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-user-dirs \
  nnn zathura zathura-pdf-mupdf imv mpv neovim NetworkManager-tui \
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
| `wmenu` | launcher; `wmenu-run` lists everything in `$PATH` |
| `swaybg` | background |
| `libnotify` | `notify-send`, to test the notifications |
| `playerctl` | play, pause and skip in kew or any other MPRIS player from a shell: `playerctl -p kew play-pause` |
| `jq` | reads the JSON `mmsg` prints: `mmsg get focusing-client \| jq -r .title` |
| `swayidle`, `wlopm` | lock screen after ten minutes idle, monitors off after fifteen |
| `wl-clipboard`, `cliphist` | `wl-copy`/`wl-paste` (Neovim uses them for the system clipboard) and the clipboard history behind Super+v |
| `wl-clip-persist` | keeps the clipboard when the program you copied from closes; without it, `wl-paste` finds nothing |
| `grim`, `slurp` | screenshots, whole screen or a selected region |
| `grimpicker` | color picker; Fedora builds it from sway-contrib as its own package, without sway |
| `xdg-desktop-portal-wlr`, `-gtk` | screen sharing in browsers, Discord and OBS, plus file pickers |
| `nnn`, `zathura`, `imv`, `mpv` | files, PDFs, images, video |
| `NetworkManager-tui` | `nmtui`, a menu for Wi-Fi and network connections |

PipeWire and WirePlumber came with `@multimedia` in part 1. `xdg-user-dirs-update` creates `~/Pictures` and the other standard folders; the Print binding saves there.

Quickshell shows the notifications and the polkit prompt, so the list has no notification daemon or polkit agent. Don't add a separate notification daemon either: its D-Bus service file starts it whenever a notification arrives while nothing owns the notification name, for example before `qs` is up at login, and after that it keeps the notifications.

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

Mango's package ships `/usr/share/xdg-desktop-portal/mango-portals.conf`, which sends screenshots and screen sharing to the wlr portal and everything else, including the dark-mode setting, to the GTK one. There's nothing to change there, but the wlr portal needs a way to ask which monitor or window to share; without one, sharing fails without an error. I use wmenu, and cap the stream at 60 fps so the 240 Hz monitor doesn't send four times what a video call can use:

```ini title="~/dotfiles/xdpw/.config/xdg-desktop-portal-wlr/config"
[screencast]
max_fps=60
chooser_type=dmenu
chooser_cmd=wmenu -p 'Share:' -l 10 -f 'Maple Mono 11' -N 151515 -n a39d9d -M 151515 -m 8da3b9 -S e8e3e3 -s 151515
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

Maple Mono has no icon glyphs, and eza, Neovim's file tree and statusline use them. The symbols-only Nerd Font from Terra fills that gap: foot finds it through fontconfig and uses it for any character Maple Mono lacks, so there's no need for a patched copy of the font:

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

Mango's borders, everything Quickshell draws and the launcher get their colors from the files above. The other programs read their own config files.

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

Mango starts from greetd with both monitors at their full refresh rate and every tag scrolling, the Quickshell bar shows tags, the focused window, music, volume and the tray, foot opens fish with the pure prompt, and the tools around it share one palette and one font. All of it lives in `~/dotfiles` as Stow packages, with Mango itself kept up to date by dnf.

Part 3 covers my Neovim config.

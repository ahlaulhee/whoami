---
slug: mango-0.18-setup
title: Building a Mango desktop on Fedora 45
description: Mango 0.18 with the scrolling layout on every tag, a Quickshell status bar, kew for music, greetd, both monitors at full refresh, and Steam on NVIDIA.
pubDate: 2026-11-08
tags: [mango, wayland, quickshell, fedora, nvidia, gaming]
testedOn: [Fedora 45, Mango 0.18.5, Quickshell 0.3.2, akmod-nvidia 615.78, RTX 5070]
series:
  name: Fedora 45 + Mango from scratch
  part: 2
draft: false
---

Part 1 left a Fedora 45 machine at a text console, with RPM Fusion, the codecs and the NVIDIA driver in place. This part turns it into my desktop: [Mango](https://github.com/mangowm/mango) 0.18 with the scrolling layout on every tag, a status bar written in [Quickshell](https://quickshell.org/), kew for music, a text login screen, both monitors at their full refresh rate, and Steam.

Mango started as a fork of dwl and keeps its model: tags instead of workspaces, one set per monitor, nothing around it you didn't install. Unlike dwl it reads a config file that applies as soon as you save it, and it ships layouts dwl doesn't have. The one I use everywhere is the scroller: windows sit side by side in a strip that can be wider than the screen, and moving focus slides the strip.

## Install Mango

Mango isn't in Fedora's repositories. Its documentation installs it from [Terra](https://terra.fyralabs.com/), a third-party repository run by Fyra Labs. The first command installs Terra's repository file and signing key; `--nogpgcheck` applies only to that step, and from then on dnf checks every Terra package against the key it just installed:

```bash
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
sudo dnf install mangowm xorg-x11-server-Xwayland
```

Keep the single quotes: dnf has to expand `$releasever` itself. Mango comes from Terra, but wlroots 0.20 and scenefx 0.5, the two libraries it builds on, come from Fedora. The package doesn't depend on XWayland, which is why it's in the same command; Steam and other X11 programs need it.

The package also installs `mmsg`, the command-line client for Mango's IPC socket that the status bar uses, a session file for login managers, and a portal configuration.

## Dotfiles with GNU Stow

All the configuration lives in one git repository, `~/dotfiles`. Each program gets a folder laid out the way it should appear in your home directory, and [GNU Stow](https://www.gnu.org/software/stow/) creates the symlinks:

```txt
~/dotfiles
├── bin/mango-idle                     # copied to /usr/local/bin
├── fonts/.local/share/fonts/maple-mono/
├── foot/.config/foot/foot.ini
├── kew/.config/kew/themes/paradise.theme
├── mako/.config/mako/config
├── mango/.config/mango/config.conf
├── quickshell/.config/quickshell/shell.qml
├── swaylock/.config/swaylock/config
├── xdpw/.config/xdg-desktop-portal-wlr/config
└── zathura/.config/zathura/zathurarc
```

```bash
sudo dnf install stow
git init ~/dotfiles
```

Once the files exist, link them by naming the folders:

```bash
stow --no-folding -d ~/dotfiles -t ~ fonts foot kew mako mango quickshell swaylock xdpw zathura
```

Without `--no-folding`, Stow links whole directories when it can, so `~/.config/mango` itself would point into the repo and any file a program creates there would show up in `git status`. With it, Stow creates real directories and links only the files. `bin` stays out of the list; its script is copied to `/usr/local/bin`.

## Configure Mango

Mango reads `~/.config/mango/config.conf`, one `key=value` per line, and reapplies it every time you save. I wrote mine from scratch rather than starting from the 200-line example in `/etc/mango/config.conf`; these are its parts, and the whole file is [here](/files/mango-0.18/config.conf).

### Monitors

`monitor_rule` sets the mode, refresh rate, position and VRR for each output, so kanshi isn't needed. The name is a regular expression, so anchor it. My 24" 1080p monitor is on the left and the 27" 1440p one on the right:

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

# new windows take 80% of the width; Super+r cycles through the presets
scroller_default_proportion=0.8
scroller_proportion_preset=0.5,0.8,1.0
# a lone window fills the screen
scroller_ignore_proportion_single=1
# keep the focused column centred
scroller_prefer_overspread=0
scroller_focus_center=1
```

`tag_rule=id:*` applies the scroller to every tag on both monitors. New windows open at 80% of the screen width, so the neighbouring window always shows at the edge, and the focused one stays centred while you move through the strip. Super+space still switches a tag to `tile` or `monocle` when a scrolling strip isn't what you want.

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

animations=0
layer_animations=0
blur=0
blur_layer=0
shadows=0
layer_shadows=0
```

The colors are the [Paradise](https://github.com/paradise-theme/paradise) palette, the one this site uses, written as `0xRRGGBBAA`. Mango draws through scenefx, which can round corners and add blur, shadows and animations. I turn all of it off. Rounded corners come out jagged on NVIDIA's driver ([mango#1387](https://github.com/mangowm/mango/issues/1387)), so `border_radius=0` is more than taste, and without animations the [NVIDIA bug](#nvidia) below is easier to tell apart from an effect.

### Autostart

```ini title="~/dotfiles/mango/.config/mango/config.conf"
exec_once=swaybg -c 151515
exec_once=mako
exec_once=/usr/libexec/lxqt-policykit-agent
exec_once=wl-paste --watch cliphist store
exec_once=/usr/local/bin/mango-idle
exec_once=qs
```

Note the underscore: `exec_once` runs a command once at login, and `exec` runs it again on every reload. Mango exports its environment to systemd and D-Bus and starts a `mango-session.target` by itself, so nothing here does that; the screen-sharing portal finds the session without help. `qs` is Quickshell, the status bar. `mango-idle` is a short script covered in [Locking, screens off, and games](#locking-screens-off-and-games).

### Window rules

```ini title="~/dotfiles/mango/.config/mango/config.conf"
window_rule=is_term:1,app_id:^foot$
window_rule=vrr_only_fullscreen:1,app_id:.*
window_rule=is_floating:1,app_id:^steam$,title:^(Friends List|Steam Settings)$
```

The first rule marks foot as the terminal. When a graphical program started from foot opens, it takes the terminal's place, and the terminal comes back when the program exits. The second turns VRR on for any window while it's fullscreen; Mango requires an `app_id` or `title` in every rule, so `.*` stands for all of them. Narrow it to `^(steam_app_.*|gamescope)$` if you'd rather keep fullscreen video at a fixed refresh rate. The third floats Steam's friends list and settings window instead of giving them a column.

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
bind=SUPER,Escape,spawn,swaylock -f
bind=SUPER+SHIFT,i,spawn_shell,pkill -x swayidle && notify-send 'Idle' 'Lock and screen-off disabled' || { /usr/local/bin/mango-idle & notify-send 'Idle' 'Lock and screen-off enabled'; }
bind=SUPER,b,spawn,qs ipc call bar toggle

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
bind=SUPER+SHIFT,space,togglefloating,
bind=SUPER,q,killclient,
mousebind=SUPER,btn_left,moveresize,curmove
mousebind=SUPER,btn_right,moveresize,curresize

bind=SUPER,c,setlayout,scroller
bind=SUPER,t,setlayout,tile
bind=SUPER,m,setlayout,monocle
bind=SUPER,space,switch_layout,
bind=SUPER+ALT,0,togglegaps,

bind=SUPER,1,view,1
bind=SUPER+SHIFT,1,tag,1
# ...the same pair for tags 2 to 9

bind=SUPER,comma,focusmon,left
bind=SUPER,period,focusmon,right
bind=SUPER+SHIFT,comma,tagmon,left
bind=SUPER+SHIFT,period,tagmon,right

bind=SUPER+SHIFT,r,reload_config
bind=SUPER+SHIFT,q,quit
```

| Keys | Action |
| --- | --- |
| Super+Return | terminal |
| Super+p | launcher (wmenu) |
| Super+h/j/k/l | focus left, down, up, right |
| Super+Shift+h/j/k/l | move the window in that direction |
| Super+Ctrl+h/j/k/l | stack the window into the neighbouring column, or pull it out |
| Super+r | cycle the window width: 50%, 80%, 100% |
| Super+e | full width |
| Super+s | back to the previous window |
| Super+f | fullscreen |
| Super+q | close the window |
| Super+space | cycle scroller, tile and monocle |
| Super+1 to 9, Super+Shift+1 to 9 | view a tag, move the window to a tag |
| Super+comma/period | focus the left or right monitor |
| Super+n | nnn in a terminal |
| Super+v | pick an entry from the clipboard history |
| Super+Shift+s | screenshot of a region, to the clipboard |
| Print | screenshot of everything, to `~/Pictures` |
| Super+Shift+x | pick a color, copy its hex code |
| Super+Escape | lock the screen |
| Super+Shift+i | turn the automatic lock and screen-off off or back on |
| Super+b | show or hide the bar |
| Super+scroll | volume |
| Super+Shift+r | reload the config |

`bind` matches the physical key, so the bindings keep working if you add a second keyboard layout. Mango has built-in equivalents for everything the dwl patches did in the earlier version of this guide: swallowing through `is_term`, `focuslast` instead of swapfocus, `warp_cursor` (on by default) instead of warpcursor, centred floating windows, and gaps.

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

## The status bar in Quickshell

Quickshell is a toolkit for writing desktop shells in QML, the declarative language Qt uses for interfaces. A bar is one QML file that Quickshell reloads every time you save it. Mine sits docked along the top of each monitor, from one corner to the other, with the tags on the left, the focused window's title in the middle, and the current song, volume, microphone, date and the system tray on the right.

Fedora 45 has Quickshell, but its package is a February 2026 snapshot from before version 0.3. The [errornointernet/quickshell](https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/) COPR has the current release, 0.3.2, and replaces Fedora's package when enabled:

```bash
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell
```

Quickshell has modules for the Hyprland and i3 IPC, but none for Mango. It doesn't need one: `mmsg watch tags DP-1` prints the tags of a monitor as one JSON object per line every time they change, and `mmsg watch focusing-client` does the same for the focused window. The bar runs both and parses the lines. Volume and microphone come from Quickshell's PipeWire service, the tray from its StatusNotifier service, and the song from kew's MPRIS interface, the standard D-Bus interface media players use to report what they're playing.

```qml title="~/dotfiles/quickshell/.config/quickshell/shell.qml"
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    // Paradise palette
    readonly property color bg: "#151515"
    readonly property color fg: "#e8e3e3"
    readonly property color muted: "#a39d9d"
    readonly property color red: "#b66467"

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

    // kew's built-in MPRIS server; any other MPRIS player is ignored.
    readonly property MprisPlayer music: Mpris.players.values
        .find(p => p.identity === "kew") ?? null

    // Volume widget for a PipeWire node: click mutes, wheel changes by 5 %.
    component Volume: Label {
        id: vol
        required property string label
        property PwNode node
        readonly property PwNodeAudio audio: node?.audio ?? null
        visible: audio !== null
        text: audio ? `${label} ${Math.round(audio.volume * 100)}%` : ""
        color: audio?.muted ? "#a39d9d" : "#e8e3e3"
        MouseArea {
            anchors.fill: parent
            onClicked: vol.audio.muted = !vol.audio.muted
            onWheel: wheel => {
                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                vol.audio.volume = Math.max(0, Math.min(1, vol.audio.volume + step));
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

            // Right: music, volume, mic, clock, tray.
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

                Volume {
                    label: "vol"
                    node: Pipewire.defaultAudioSink
                }

                Volume {
                    label: "mic"
                    node: Pipewire.defaultAudioSource
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

A few details in it:

- `PanelWindow` with `top`, `left` and `right` anchors is what makes the bar docked and full width. Its default exclusion mode reserves a strip as tall as the bar, so windows never go under it.
- `Variants` creates one bar per monitor, and each bar watches the tags of its own output.
- `PwObjectTracker` keeps the default output and input bound. Without it, PipeWire doesn't send their volume.
- The tray only opens menus because of the `UseQApplication` pragma on the first line.
- `IpcHandler` gives the bar a command, `qs ipc call bar toggle`, which Super+b runs.
- Clicking a tag switches to it on that bar's monitor, clicking the music pauses or resumes it, and scrolling over the volume or microphone changes it, with a click to mute.
- The title is the focused window's, so both monitors show the same one.
- Tray menus use Qt's default light style rather than the Paradise colors.

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
sudo dnf install foot wmenu swaybg mako libnotify swaylock swayidle wlopm \
  wl-clipboard cliphist grim slurp grimpicker \
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk lxqt-policykit xdg-user-dirs \
  nnn zathura zathura-pdf-mupdf imv mpv neovim NetworkManager-tui \
  google-noto-color-emoji-fonts
xdg-user-dirs-update
```

| Package | Role |
| --- | --- |
| `foot` | terminal |
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

PipeWire and WirePlumber came with `@multimedia` in part 1. `xdg-user-dirs-update` creates `~/Pictures` and the other standard folders; the Print binding saves there.

### Locking, screens off, and games

swayidle runs from a small script, so the autostart entry and the toggle key start exactly the same thing:

```sh title="~/dotfiles/bin/mango-idle"
#!/bin/sh
# lock after 10 minutes, monitors off after 15, lock before suspend
exec swayidle -w \
	timeout 600 'swaylock -f' \
	timeout 900 "wlopm --off '*'" resume "wlopm --on '*'" \
	before-sleep 'swaylock -f'
```

```bash
sudo install -m 755 ~/dotfiles/bin/mango-idle /usr/local/bin/mango-idle
```

`wlopm` turns the monitors off through the output power protocol, which Mango implements. Don't use Mango's `disable_monitor` for this on NVIDIA: turning a monitor back on that way can leave it black ([mango#1164](https://github.com/mangowm/mango/issues/1164)).

swayidle only counts keyboard and mouse input as activity. A game played with a controller reads the controller directly, so after ten minutes of only using the gamepad the screen would lock in the middle of the game. Mango has two options for this:

```ini title="~/dotfiles/mango/.config/mango/config.conf"
idle_inhibit_when_fullscreen=1
idle_inhibit_ignore_visible=1
```

With the first, Mango reports activity every second while the focused window is fullscreen, so swayidle never reaches its timeout during a fullscreen game. The second covers video: players and browsers ask the compositor not to go idle, and normally Mango only honours that while their window is visible; with it, a video on another tag or monitor also keeps the screen awake.

For windowed games, Super+Shift+i kills swayidle, which stops both the lock and the screen-off, and starts it again on the next press. A notification says which state you're in. `systemd-inhibit --what=idle` would be the obvious tool for this, but swayidle 1.9.0, the version in Fedora 45, fails to read logind's inhibitors ([swayidle#198](https://github.com/swaywm/swayidle/issues/198)), so it ignores them.

### Screen sharing

Mango's package ships `/usr/share/xdg-desktop-portal/mango-portals.conf`, which sends screenshots and screen sharing to the wlr portal and everything else, including the dark-mode setting, to the GTK one. There's nothing to change there. What the wlr portal does need is a way to ask which monitor or window to share; without one, sharing fails without an error. I use wmenu, and cap the stream at 60 fps so the 240 Hz monitor doesn't send four times what a video call can use:

```ini title="~/dotfiles/xdpw/.config/xdg-desktop-portal-wlr/config"
[screencast]
max_fps=60
chooser_type=dmenu
chooser_cmd=wmenu -p 'Share:' -l 10 -f 'Maple Mono 11' -N 151515 -n a39d9d -M 151515 -m 8da3b9 -S e8e3e3 -s 151515
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

The last command should print `MapleMono-Regular.ttf: "Maple Mono" "Regular"`. The bar, foot, wmenu, mako and swaylock all find it by that name. In foot the cursive italic shows up, but the ligatures don't: `->` and `!=` stay as separate characters.

## Paradise everywhere

Mango's borders, the bar and the launcher get their colors from the files above. The other programs read their own config files.

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

## NVIDIA

I started Mango with no extra environment variables and only add one when it fixes something I can see. Mango enables explicit sync by default (`sync_obj_enable=1`), and its documentation has no NVIDIA section; asked about NVIDIA support, its author said he ["can't make any promises"](https://github.com/mangowm/mango/issues/1429). Two reports matter for this machine:

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

For VRR, the `vrr_only_fullscreen` rule enables adaptive sync on a monitor while a window is fullscreen there and disables it when the window leaves fullscreen. On NVIDIA there is a catch: the driver's README says its KMS implementation "forces all VRR capable displays into VRR mode by default", so the monitor may run in VRR mode on the desktop too, whatever Mango asks for. Watch the refresh rate counter in the monitor's on-screen menu: if it moves around on the desktop, the driver is doing it. The `conceal_vrr_caps=1` option of the `nvidia_modeset` module stops that, but it hides VRR from Mango as well, so games lose it too.

## Where this leaves you

Mango starts from greetd with both monitors at their full refresh rate and every tag scrolling, the Quickshell bar shows tags, the focused window, music, volume and the tray, and the tools around it share one palette and one font. All of it lives in `~/dotfiles` as Stow packages, with Mango itself kept up to date by dnf.

Part 3 covers my Neovim config.

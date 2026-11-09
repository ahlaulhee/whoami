# Status bar for Mango 0.18.5 (Fedora 45): research notes

Researched 2026-11-08. The target bar is docked (exclusive zone, not floating), on the top edge, full width. Modules: **left** tags; **middle** focused window title; **right** MPD, output volume, mic volume, date/time, systray. Theme: Paradise palette with Maple Mono.

Package checks were run in the WSL distro `FedoraLinux-45` (`Fedora release 45 (Forty Five)`) with `dnf repoquery`/`dnf install`. That WSL box now has COPR quickshell 0.3.2, waybar 0.16.0 (updates-testing), yambar and qt6-qtdeclarative-devel installed. It is a scratch box, but the state did change.

---

## TL;DR

- **Mango has no dwl-ipc protocol any more.** The `mangowm/mango` tree has no `dwl_ipc` code. It ships only `wlr-foreign-toplevel`, `wlr-layer-shell` and `wlr-output-power-management` protocol XMLs, and implements **ext-workspace-v1** (`src/ext-protocol/ext-workspace.c`) plus a JSON socket IPC driven by `mmsg`. Waybar's `dwl/tags` and yambar's `dwl` module are out. https://github.com/mangowm/mango/tree/main/protocols
- What a bar can use for tags:
  1. **`mmsg watch tags <output>`**: JSON lines with full tag state (active, urgent, client_count, layout).
  2. **ext-workspace-v1**: Mango exposes one workspace per tag per monitor, sets `active`/`urgent`, hides empty tags, and supports `activate`/`deactivate`.
- **Quickshell**: Fedora 45 ships `quickshell 0.2.1^git20260209.dacfa9d-5.fc45`, a Feb 2026 snapshot. It has every service needed, but not the ext-workspace `Quickshell.WindowManager` module, which arrived in 0.3.0. COPR `errornointernet/quickshell` ships **0.3.2**, the current upstream release. On either version, tags work well through `Process` + `mmsg watch tags`.
- **Waybar**: Fedora 45 stable has `0.15.0-6.fc45`, which has **no** `mango/*` modules. `waybar-0.16.0-1.fc45` (with `mango/workspaces`, `mango/window`, …) is in **updates-testing** as `FEDORA-2026-c33cf46b4f` (submitted 2026-11-07, karma 2, 7 stable-days). It should reach stable around 2026-11-14 [INFERENCE from Bodhi stable_days].
- **Recommendation:** Quickshell is a good fit if the author wants a hand-built, fully themed bar and is fine writing about 200 lines of QML. Waybar 0.16 is the lowest-effort route: every module is native and there is zero glue code. Details in the matrix at the end.

---

## 1. Package verification (WSL Fedora 45)

| Package | Result | Repo |
|---|---|---|
| `quickshell` | `0.2.1^git20260209.dacfa9d-5.fc45` | fedora |
| `quickshell` (Bodhi) | `FEDORA-2026-3f2f595cdf` stable, same snapshot; rawhide also only `-6.fc46` of the same snapshot | — |
| `quickshell` | `0.3.2-1.fc45` (also `0.3.1-2.fc45`) | COPR `errornointernet/quickshell` |
| `quickshell-git` | `0.3.2^879.gitbf6302e-1.fc45` | COPR `errornointernet/quickshell` |
| `quickshell` / `quickshell-git` | **not in Terra** | terra |
| `waybar` | `0.15.0-6.fc45` | fedora |
| `waybar` | `0.16.0-1.fc45` (changelog: "Update to 0.16.0 (#2387223)", 2026-11-05) | updates-testing, Bodhi `FEDORA-2026-c33cf46b4f` |
| `waybar` | `0.16.0-1.fc46` | rawhide |
| `mangowm` | `0.18.5-1.fc45`, ships `/usr/bin/mango`, `/usr/bin/mangonag`, `/usr/bin/mmsg` | terra |
| `mangobar` | `0~20260527git.c0138d9-1.fc45` | terra |
| `mpdris2` | `0.9.1-15.fc45` (provides `/usr/bin/mpDris2`, `/usr/lib/systemd/user/mpDris2.service`, D-Bus name `org.mpris.MediaPlayer2.mpd`) | fedora |
| `mpd-mpris` | not found (Fedora or Terra) | — |
| `mpd` / `mpc` | `0.24.15-1.fc45` / `0.35-9.fc45` | fedora |
| `pipewire` / `wireplumber` | `1.6.11-1.fc45` / `0.5.19-1.fc45` | updates |
| `yambar` | `1.11.0-6.fc45` | fedora |
| `eww`, `eww-wayland` | `v0.6.0^20260717.git~48f5aa8-1.fc45` | terra |
| `ironbar` | not found (Fedora or Terra) | — |

Commands used:

```sh
dnf repoquery --latest-limit=1 --qf "%{name} %{version}-%{release} %{repoid}\n" waybar quickshell ironbar yambar eww mpd-mpris mpDris2 mpc mpd
dnf repoquery --repofrompath=copr,https://download.copr.fedorainfracloud.org/results/errornointernet/quickshell/fedora-45-x86_64/ --repo=copr quickshell quickshell-git
dnf repoquery --repo=terra quickshell quickshell-git waybar ironbar yambar eww mangowm mangobar
dnf repoquery --repofrompath=ut,https://dl.fedoraproject.org/pub/fedora/linux/updates/testing/45/Everything/x86_64/ --repo=ut waybar
curl -s "https://bodhi.fedoraproject.org/updates/?builds=waybar-0.16.0-1.fc45"
```

Installing the newer versions:

```sh
# Quickshell 0.3.2 (replaces Fedora's 0.2.1 snapshot because the version is higher)
sudo dnf copr enable errornointernet/quickshell
sudo dnf install quickshell

# Waybar 0.16 before it goes stable
sudo dnf upgrade --enablerepo=updates-testing --advisory=FEDORA-2026-c33cf46b4f
# (or simply: sudo dnf upgrade --enablerepo=updates-testing waybar)
```

Sources: COPR https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/, Bodhi https://bodhi.fedoraproject.org/updates/FEDORA-2026-c33cf46b4f

---

## 2. Mango-side facts a bar depends on

### 2.1 `mmsg` IPC (verified in source)

Docs: https://mangowm.github.io/ (source `apps/docs/content/v0.18.5/ipc.md` in https://github.com/mangowm/mangowm.github.io)

- Socket path comes from `MANGO_INSTANCE_SIGNATURE`. It is set automatically for processes Mango spawns, so a bar started with `exec_once=` inherits it.
- `mmsg watch …` pushes the initial state right away, then one compact JSON object **per line** on every change. `ipc.c` formats `"%s\n"`, and `mmsg.c` uses a `getline` → `printf` + `fflush` loop. That suits Quickshell's `SplitParser` and Waybar `custom` modules.
- Relevant streams (from `src/ipc/ipc.c`):

```text
mmsg watch tags DP-1
{"monitor":"DP-1","tags":[{"index":1,"is_active":true,"is_urgent":false,"layout":"T","client_count":2}, ... 9 entries],"active_tags":[...]}

mmsg watch focusing-client
{"id":12,"title":"nvim","appid":"foot"}      # or {"id":null,"title":null,"appid":null}
```

(Field names come from `build_tags_json()` / `build_monitor_tags_response()` / `monitor_active_client()` in https://github.com/mangowm/mango/blob/main/src/ipc/ipc.c. The sample values are illustrative.)

- Dispatching from a bar: `mmsg dispatch view,<mask>`, where the tag mask is `3` or `1|3|5` (docs `bindings/keys.md`, "Tag Mask Format"). `view` acts on the focused monitor. A bar on the *other* monitor should use `viewcrossmon,<mask>,<monitor_spec>`; a plain output name such as `DP-1` is a valid monitor_spec (docs `configuration/monitors.md`). Waybar's `mango/workspaces` sends `dispatch view,<idx>` / `dispatch toggleview,<idx>`, and `dispatch overview` / `toggleoverview` for the overview button.

### 2.2 ext-workspace-v1

`src/ext-protocol/ext-workspace.c` creates one ext-workspace per tag per monitor (group = monitor). Behaviour:
- name = the tag name; tag 0 = `"overview"`.
- `set_active` when the tag is in the monitor's active tagset.
- `set_urgent` on urgent clients.
- `set_hidden(true)` for empty tags unless `no_hide` is set for that tag.
- Capabilities `ACTIVATE | DEACTIVATE` map to `view` / `toggleview`.

This gives any ext-workspace client "hide empty tags" behaviour without configuration. Client counts are **not** exposed this way; only `mmsg` has them.

### 2.3 foreign-toplevel

Mango implements wlr-foreign-toplevel-management (`src/ext-protocol/foreign-toplevel.c`), so title/app-id/activated are available to generic toplevel clients.

### 2.4 What Mango's own docs recommend

The `visuals/status-bar.md` page (v0.18.5) recommends **mangobar** first ("integrates directly with mangowm over IPC"). It then documents **Waybar** `mango/workspaces`, `mango/layout`, `mango/window`, `mango/language`, `mango/keymode` modules, and links a complete Waybar config at https://github.com/DreamMaoMao/waybar-config.

---

## 3. Quickshell

- Upstream: https://git.outfoxxed.me/quickshell/quickshell (GitHub mirror https://github.com/quickshell-mirror/quickshell). The latest release is **v0.3.2 (2026-10-08)**, after v0.3.1 (2026-08-21) and v0.3.0 (2026-05-04).
- Fedora's snapshot `dacfa9d` is dated 2026-02-10 and is **80 commits behind v0.3.0**. It lacks:
  - `Quickshell.WindowManager` (ext-workspace). From the v0.3.0 changelog: "Added generic WindowManager interface implementing ext-workspace".
  - The fix "wayland/toplevel: clear activeToplevel on deactivation" (commit `cf1a2ae`, 2026-03-10; listed in the v0.3.0 changelog as "Fixed ToplevelManager not clearing activeToplevel on deactivation"). On the Fedora package, `ToplevelManager.activeToplevel` can therefore keep showing a stale title after unfocus. **Use `mmsg watch focusing-client` for the title**, which also returns `null` cleanly when nothing is focused.
  - Many crash fixes for monitor hot-plug and PipeWire (v0.3.0/0.3.1 changelogs).
- Compositor-specific IPC modules are **Hyprland and I3 only**. Installed QML modules (Fedora pkg) are `Bluetooth DBusMenu Hyprland I3 Io Networking Services Wayland Widgets X11`; with COPR 0.3.2, `WindowManager` is added. There is **no DWL/Mango module**.
- Docs: https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.WindowManager/WindowManager/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwObjectTracker/ , https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.SystemTray/SystemTrayItem/

### 3.1 API per module

| Need | Quickshell API |
|---|---|
| Docked, top, full width | `PanelWindow { anchors { top: true; left: true; right: true }; implicitHeight: N }`. `exclusionMode` defaults to `ExclusionMode.Auto`, which reserves an exclusive zone equal to the height; `exclusiveZone` can be set explicitly. One bar per monitor via `Variants { model: Quickshell.screens }` + `screen: modelData`. |
| Tags | **(a)** `Quickshell.Io` `Process { command: ["mmsg","watch","tags", screen.name]; stdout: SplitParser { onRead: … } }`, which works on Fedora 0.2.1 and 0.3.2. **(b)** COPR 0.3.2 only: `Quickshell.WindowManager`, using `WindowManager.screenProjection(screen).windowsets` → `Windowset { name, active, urgent, shouldDisplay, activate(), deactivate() }`. |
| Window title | `Process` + `mmsg watch focusing-client` (recommended); or `Quickshell.Wayland` `ToplevelManager.activeToplevel?.title` (foreign-toplevel; stale-title bug on Fedora's snapshot). |
| MPD | `Quickshell.Services.Mpris` `Mpris.players.values` → `MprisPlayer { identity, trackTitle, trackArtist, isPlaying, togglePlaying(), next(), previous() }`. This needs an MPRIS bridge: Fedora's `mpdris2` package (identity string `"Music Player Daemon"`, verified at `/usr/bin/mpDris2` line 77). `mpd-mpris` is not packaged. Alternative: `Process { command: ["mpc","idleloop","player"] }` re-running `mpc current` on each line. |
| Output volume | `Quickshell.Services.Pipewire`: `Pipewire.defaultAudioSink.audio.volume` (0–1, writable) / `.audio.muted`. Requires `PwObjectTracker { objects: [Pipewire.defaultAudioSink] }`, otherwise `audio` is not bound. |
| Mic volume | Same, with `Pipewire.defaultAudioSource`. |
| Clock | `SystemClock { precision: SystemClock.Minutes }` + `Qt.formatDateTime(clock.date, "…")`. |
| Tray | `Quickshell.Services.SystemTray`: `Repeater { model: SystemTray.items }` → `SystemTrayItem { icon, hasMenu, onlyMenu, menu, activate(), display(window,x,y) }`. Menus via `QsMenuAnchor { menu: item.menu; anchor.item: … }.open()`. Platform menus **require `//@ pragma UseQApplication`** at the top of the root file; without it Quickshell logs "Cannot call QsMenuAnchor.open() as quickshell was not started in QApplication mode" (`src/core/qsmenuanchor.cpp`). |

The property names above were checked against the installed `.qmltypes` of Fedora's package. `exclusiveZone`, `exclusionMode`, `activeToplevel`, `defaultAudioSink`, `defaultAudioSource`, `audio`, `volume`, `muted`, `objects`, `players`, `identity`, `trackTitle`, `trackArtist`, `isPlaying`, `togglePlaying`, `items`, `hasMenu`, `onlyMenu`, `menu`, `display`, `activate`, `splitMarker`, `precision` and `date` all exist. `QsMenuAnchor` is exported as `Quickshell/QsMenuAnchor`.

### 3.2 Complete minimal bar (`~/.config/quickshell/shell.qml`)

Verification: `qmllint` (qt6-qtdeclarative-devel 6.11.2) against both Fedora's quickshell 0.2.1 snapshot and COPR 0.3.2 reported only two known false positives: "PanelWindow is not creatable" and an unresolved `DBusMenuHandle` type. Running `qs -p shell.qml` under WSLg loaded the config with both versions (`INFO: Configuration Loaded`). WSLg has no layer-shell or PipeWire, so **on-screen behaviour under Mango is [UNVERIFIED]**.

```qml
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray

ShellRoot {
    // Paradise palette
    readonly property color bg: "#151515"
    readonly property color fg: "#e8e3e3"
    readonly property color muted: "#a39d9d"
    readonly property color red: "#b66467"
    readonly property color green: "#8c977d"
    readonly property color yellow: "#d9bc8c"
    readonly property color blue: "#8da3b9"
    readonly property string font: "Maple Mono"

    id: root

    // Keep default sink/source bound so .audio.volume/.muted are valid and writable.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Focused window title, from Mango's IPC (one JSON object per line).
    property string windowTitle: ""
    Process {
        command: ["mmsg", "watch", "focusing-client"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const c = JSON.parse(data);
                root.windowTitle = c.title ?? "";
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData

            // Docked, top edge, corner to corner. exclusionMode defaults to
            // ExclusionMode.Auto => exclusive zone = bar height.
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 28
            color: root.bg

            // ---- per-monitor tags from `mmsg watch tags <output>` ----
            property var tags: []
            Process {
                command: ["mmsg", "watch", "tags", bar.modelData.name]
                running: true
                stdout: SplitParser {
                    onRead: data => bar.tags = JSON.parse(data).tags
                }
            }
            Process {
                id: dispatch
            }

            // Left: tags
            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: bar.tags
                    Rectangle {
                        required property var modelData
                        visible: modelData.is_active || modelData.client_count > 0
                        implicitWidth: 26
                        implicitHeight: bar.implicitHeight
                        color: modelData.is_active ? root.blue : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.index
                            font.family: root.font
                            color: parent.modelData.is_urgent ? root.red
                                 : parent.modelData.is_active ? root.bg : root.muted
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                dispatch.command = ["mmsg", "dispatch",
                                    `viewcrossmon,${parent.modelData.index},${bar.modelData.name}`];
                                dispatch.running = true;
                            }
                        }
                    }
                }
            }

            // Middle: focused window title (true screen center)
            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, bar.width * 0.4)
                elide: Text.ElideRight
                text: root.windowTitle
                font.family: root.font
                color: root.fg
            }

            // Right: MPD, volume, mic, clock, tray
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                // MPD via MPRIS (needs mpDris2 running)
                Text {
                    readonly property MprisPlayer mpd:
                        Mpris.players.values.find(p => p.identity === "Music Player Daemon") ?? null
                    visible: mpd !== null
                    text: mpd ? `${mpd.isPlaying ? "▶" : "⏸"} ${mpd.trackArtist} - ${mpd.trackTitle}` : ""
                    font.family: root.font
                    color: root.yellow
                    MouseArea {
                        anchors.fill: parent
                        onClicked: parent.mpd.togglePlaying()
                    }
                }

                // Output volume
                Text {
                    readonly property PwNode sink: Pipewire.defaultAudioSink
                    text: sink?.audio ? (sink.audio.muted ? "VOL muted"
                          : `VOL ${Math.round(sink.audio.volume * 100)}%`) : ""
                    font.family: root.font
                    color: sink?.audio?.muted ? root.muted : root.green
                    MouseArea {
                        anchors.fill: parent
                        onClicked: parent.sink.audio.muted = !parent.sink.audio.muted
                        onWheel: wheel => {
                            const a = parent.sink.audio;
                            a.volume = Math.max(0, Math.min(1, a.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                        }
                    }
                }

                // Microphone volume
                Text {
                    readonly property PwNode source: Pipewire.defaultAudioSource
                    text: source?.audio ? (source.audio.muted ? "MIC muted"
                          : `MIC ${Math.round(source.audio.volume * 100)}%`) : ""
                    font.family: root.font
                    color: source?.audio?.muted ? root.red : root.fg
                    MouseArea {
                        anchors.fill: parent
                        onClicked: parent.source.audio.muted = !parent.source.audio.muted
                    }
                }

                // Date/time
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
                    font.family: root.font
                    color: root.fg
                }

                // System tray
                Repeater {
                    model: SystemTray.items
                    Image {
                        id: trayIcon
                        required property SystemTrayItem modelData
                        source: modelData.icon
                        sourceSize.width: 16
                        sourceSize.height: 16
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16

                        QsMenuAnchor {
                            id: menuAnchor
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
                                    menuAnchor.open();
                            }
                        }
                    }
                }
            }
        }
    }
}
```

Notes:
- `pragma ComponentBehavior: Bound` (a real QML pragma) is separate from Quickshell's `//@ pragma` comment syntax. qmllint flagged every outer-id access without it.
- The tag filter `is_active || client_count > 0` mirrors Waybar's `hide-empty`.
- `bar.modelData.name` (`ShellScreen.name`) is the wlr output name (`DP-1`, …), the same name `mmsg` expects [INFERENCE: both come from the wlr_output name].
- The wheel handler on the sink is the pattern for the mic too.
- Start it from Mango: `exec_once=qs`. MPRIS bridge: `systemctl --user enable --now mpDris2.service`; the package also drops `/etc/xdg/autostart/mpdris2.desktop`, which Mango does not process [INFERENCE].

### 3.3 Alternative tags block via ext-workspace (COPR 0.3.2 only)

Verification: qmllint clean apart from the PanelWindow false positive, and it loads under `qs` 0.3.2 (WSLg). This needs no external process, but loses client counts. Hiding empty tags comes from Mango's `set_hidden` → `shouldDisplay`.

```qml
import Quickshell.WindowManager
// inside PanelWindow `bar`:
Repeater {
    model: ScriptModel {
        values: WindowManager.screenProjection(bar.modelData).windowsets
            .filter(w => w.shouldDisplay && w.name !== "overview")
    }
    Rectangle {
        id: tag
        required property Windowset modelData
        implicitWidth: 26; implicitHeight: 28
        color: modelData.active ? "#8da3b9" : "transparent"
        Text {
            anchors.centerIn: parent
            text: tag.modelData.name
            font.family: "Maple Mono"
            color: tag.modelData.urgent ? "#b66467" : tag.modelData.active ? "#151515" : "#a39d9d"
        }
        MouseArea { anchors.fill: parent; onClicked: tag.modelData.activate() }
    }
}
```

The mapping of `shouldDisplay` to ext-workspace `hidden` is [INFERENCE] from the Quickshell doc comment ("If false, this windowset should generally be hidden from workspace pickers").

---

## 4. Waybar

- Fedora 45 stable: **0.15.0-6.fc45**. Upstream 0.16.0 was released 2026-11-05 and is packaged as `0.16.0-1.fc45` in updates-testing (§1).
- Module inventory (checked against the source tree at the tags `0.15.0` and `0.16.0` on https://github.com/Alexays/Waybar, and by grepping the installed binaries):

| Module | 0.15.0 (F45 stable) | 0.16.0 | Works with Mango? |
|---|---|---|---|
| `mango/workspaces`, `mango/window`, `mango/layout`, `mango/language`, `mango/keymode` | ✗ | ✓ (PR #5078 "feat: add mango modules", by DreamMaoMao, Mango's author) | ✓ native, uses `MANGO_INSTANCE_SIGNATURE` socket |
| `dwl/tags`, `dwl/window` | ✓ | ✓ | ✗: Mango has no dwl-ipc protocol |
| `ext/workspaces` | ✓ | ✓ | ✓ via ext-workspace-v1 (no client counts; `ignore-hidden` default true hides empty tags) |
| `wlr/taskbar` | ✓ | ✓ | ✓ (all windows, not a title) |
| `mpd` | ✓ | ✓ | ✓ talks to MPD directly, no bridge |
| `wireplumber` (`node-type: "Audio/Source"` for mic) | ✓ | ✓ | ✓ |
| `pulseaudio` (`format-source`, `format-source-muted`) | ✓ | ✓ | ✓ via pipewire-pulse |
| `clock`, `tray` | ✓ | ✓ | ✓ |

- Bar geometry: `position` defaults to `top`, `exclusive` defaults to **true**, and leaving `width` unset gives full width. Set `"layer": "top"`; the default `bottom` sits behind floating windows (`man waybar(5)`).
- `mango/workspaces` options (man page, 0.16.0): `format` (`{value}` `{name}` `{icon}` `{index}` `{output}`), `format-icons` (keys: index, `default`, `active`, `urgent`, `empty`), `hide-empty`, `current-only`, `tag-filter`, `on-click`/`-middle`/`-right` (`activate` | `toggle`), `overview-label`. CSS classes: `button.active`, `.urgent`, `.empty`, `.current_output`, `.overview`.
- `mango/window`: `format` (`{title}`, `{app_id}`), `rewrite`, `icon`, `icon-size`, `max-length`. `.empty` class when nothing is focused.

### 4.1 Waybar 0.16 config (`~/.config/waybar/config.jsonc`)

```jsonc
{
  "layer": "top",
  "position": "top",
  "height": 28,
  "spacing": 14,
  "modules-left": ["mango/workspaces"],
  "modules-center": ["mango/window"],
  "modules-right": ["mpd", "wireplumber", "wireplumber#source", "clock", "tray"],

  "mango/workspaces": {
    "format": "{name}",
    "hide-empty": true,
    "on-click": "activate",
    "on-click-right": "toggle"
  },
  "mango/window": { "format": "{title}", "max-length": 80 },
  "mpd": {
    "format": "{stateIcon} {artist} - {title}",
    "format-stopped": "",
    "format-disconnected": "",
    "state-icons": { "playing": "▶", "paused": "⏸" },
    "on-click": "mpc toggle"
  },
  "wireplumber": {
    "format": "VOL {volume}%",
    "format-muted": "VOL muted",
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "scroll-step": 5
  },
  "wireplumber#source": {
    "node-type": "Audio/Source",
    "format": "MIC {volume}%",
    "format-muted": "MIC muted",
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
    "scroll-step": 5
  },
  "clock": { "format": "{:%a %d %b  %H:%M}" },
  "tray": { "icon-size": 16, "spacing": 8 }
}
```

`style.css` (Paradise):

```css
* { font-family: "Maple Mono"; font-size: 13px; border: none; border-radius: 0; min-height: 0; }
window#waybar { background: #151515; color: #e8e3e3; }
#workspaces button { color: #a39d9d; padding: 0 8px; background: transparent; }
#workspaces button.active { background: #8da3b9; color: #151515; }
#workspaces button.urgent { background: #b66467; color: #151515; }
#mpd { color: #d9bc8c; }
#wireplumber { color: #8c977d; }
#wireplumber.source.muted, #wireplumber.muted { color: #b66467; }
#clock, #window { color: #e8e3e3; }
```

The `wireplumber#source` → CSS selector `#wireplumber.source` follows Waybar's general `name#id` → `#name.id` rule [INFERENCE: not re-checked in 0.16 source]. Neither config was run under Mango [UNVERIFIED]. Module names, option names and the `node-type` example come from the man pages (`waybar-wireplumber(5)` in 0.15.0 contains exactly this `"wireplumber#source"` + `"node-type": "Audio/Source"` example).

### 4.2 Waybar 0.15 (F45 stable today) fallback

Replace `mango/workspaces` with `"ext/workspaces": { "format": "{name}", "on-click": "activate" }`. Replace `mango/window` with a custom module streaming Mango IPC:

```jsonc
"custom/title": {
  "exec": "mmsg watch focusing-client | jq --unbuffered -r '.title // \"\"'",
  "max-length": 80
}
```

[UNVERIFIED at runtime: relies on custom-module continuous mode, where each stdout line replaces the text.]

---

## 5. Other bars (only where Mango tags work)

- **mangobar** (https://github.com/mangowm/mangobar, Terra `mangobar 0~20260527git.c0138d9`; upstream last pushed 2026-11-04, so the Terra snapshot is ~5 months old). Native Mango IPC tags, window, tray, clock and `pulseaudio` volume. Its `pulseaudio` module controls the **default sink only** (wiki "Module: PulseAudio"), there is **no MPD module and no mic module**, so both need `custom/<name>` modules. It uses a Waybar-like JSONC config and a CSS subset (`@define-color`, gradients, `mix()`), with `modules-center` placed at true screen center. Good tag integration, but it misses two of the required modules natively.
- **yambar** (Fedora `1.11.0-6.fc45`). Installed module set: alsa, backlight, battery, clock, cpu, disk-io, dwl, foreign-toplevel, i3, label, mem, mpd, network, pipewire, pulse, removables, river, script, sway, sway-xkb, xkb. There is **no tray module**, which disqualifies it. Its `dwl` module parses dwl's stdout status, and Mango only feeds IPC watchers [INFERENCE from `printstatus()` → `print_status_signal` in `ipc.c`].
- **ironbar** (v0.19.1, 2026-09-20). Compositor clients are hyprland, niri and sway only (`src/clients/compositor`), with no ext-workspace or Mango support. Not packaged in Fedora or Terra. Excluded.
- **eww** (Terra `v0.6.0^20260717.git~48f5aa8`). No WM-specific widgets; tags/title would be `deflisten "mmsg watch tags DP-1"` + `jq`, and there is no native tray in 0.6 [UNVERIFIED]. More glue than Quickshell for no gain. Excluded.

---

## 6. Recommendation matrix

| | Quickshell (Process + mmsg) | Waybar 0.16 (`mango/*`) | mangobar |
|---|---|---|---|
| **Fedora packaging** | Fedora: 0.2.1 Feb-2026 snapshot (works for this bar, older/crashier); COPR `errornointernet/quickshell` 0.3.2 = current upstream | Fedora updates-testing now (`FEDORA-2026-c33cf46b4f`), stable ~a week out; 0.15 stable needs the §4.2 fallback | Terra only, ~5-month-old snapshot |
| **Effort** | ~200 lines QML (§3.2); you own click handling, scroll, layout | ~40 lines JSONC + ~10 lines CSS; zero glue | JSONC + CSS + 2 custom scripts (MPD, mic) |
| **Mango tag integration** | Excellent via `mmsg watch tags` (active/urgent/client_count/per-monitor, `viewcrossmon` clicks); ext-workspace alternative on 0.3.2 | Excellent; written by Mango's author; overview button, tag-filter per output | Excellent (native IPC, first-party) |
| **Title** | `mmsg watch focusing-client` (avoid `ToplevelManager` on the Fedora snapshot) | `mango/window` native | native |
| **MPD** | needs `mpdris2` (Fedora) for Mpris, or `mpc idleloop` | native `mpd` module, no bridge | custom script |
| **Volume + mic** | native PipeWire API, writable volume | `wireplumber` + `wireplumber#source` | sink only; mic via custom |
| **Tray** | native, menus need `//@ pragma UseQApplication` | native | native |
| **Paradise theming / Maple Mono** | Unlimited (QML colours/fonts set directly) | GTK3 CSS; easy, enough for a flat bar | CSS subset; enough |
| **Blog-writing cost** | Best "learn something" content; explains Mango IPC | Shortest section; explains the most standard tool | Niche; readers outside Mango gain nothing |

**Recommendation.**
1. If part 2 is meant to be about getting a working desktop quickly: **Waybar 0.16**. It is the only option with *every* requested module native (including MPD without a bridge and mic via `wireplumber#source`), and it is the bar Mango's docs document in detail. Tell readers to pull it from updates-testing until `FEDORA-2026-c33cf46b4f` goes stable.
2. If the author wants Quickshell (as proposed), it fully meets the spec. Install **0.3.2 from COPR `errornointernet/quickshell`** rather than Fedora's Feb-2026 snapshot: it is current, has the activeToplevel and hot-plug fixes, and adds the ext-workspace `WindowManager`. Drive tags and title from `mmsg watch` (works on either version), add `mpdris2` for MPD, and use the §3.2 file as the starting point. Budget for writing and explaining ~200 lines of QML.
3. Skip yambar (no tray), ironbar (no Mango/ext-workspace) and eww (all glue). Mention mangobar only as Mango's first-party option, which lacks MPD and mic modules.

---

## Sources

- Mango repo: https://github.com/mangowm/mango (`protocols/`, `src/ipc/ipc.c`, `mmsg/mmsg.c`, `src/ext-protocol/ext-workspace.c`, `include/mango/ext-protocol/ext-workspace.h`); release 0.18.5 (2026-11-04)
- Mango docs v0.18.5 source: https://github.com/mangowm/mangowm.github.io/tree/main/apps/docs/content/v0.18.5 (`ipc.md`, `visuals/status-bar.md`, `bindings/keys.md`, `configuration/monitors.md`); site https://mangowm.github.io/
- mangobar: https://github.com/mangowm/mangobar , wiki https://github.com/mangowm/mangobar/wiki (Configuration, Module: PulseAudio)
- Quickshell: https://git.outfoxxed.me/quickshell/quickshell , mirror https://github.com/quickshell-mirror/quickshell (`changelog/v0.3.0.md`–`v0.3.2.md`, `src/windowmanager/module.md`, `src/windowmanager/windowset.hpp`, `src/core/qsmenuanchor.cpp`), docs https://quickshell.org/docs/v0.3.2/
- Quickshell COPR: https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/
- Waybar: https://github.com/Alexays/Waybar (release 0.16.0 notes; `man/waybar-mango-workspaces.5.scd`, `man/waybar-mango-window.5.scd`, `man/waybar-wireplumber.5.scd`, `man/waybar-pulseaudio.5.scd`, `man/waybar-ext-workspaces.5.scd`, `man/waybar.5.scd.in`)
- Bodhi: https://bodhi.fedoraproject.org/updates/FEDORA-2026-c33cf46b4f (waybar 0.16.0-1.fc45), https://bodhi.fedoraproject.org/updates/FEDORA-2026-3f2f595cdf (quickshell snapshot)
- ironbar: https://github.com/JakeStanger/ironbar ; yambar: https://codeberg.org/dnkl/yambar
- Local verification: WSL `FedoraLinux-45`, `dnf repoquery`, installed `.qmltypes` under `/usr/lib64/qt6/qml/Quickshell/`, `qmllint`, `qs -p` under WSLg, `/usr/bin/mpDris2`, `rpm -ql yambar`

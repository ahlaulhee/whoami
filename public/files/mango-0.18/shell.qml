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

    // MPD through mpDris2; any other MPRIS player is ignored.
    readonly property MprisPlayer mpd: Mpris.players.values
        .find(p => p.identity === "Music Player Daemon") ?? null

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

            // Right: MPD, volume, mic, clock, tray.
            RowLayout {
                id: right
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Label {
                    readonly property MprisPlayer player: root.mpd
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

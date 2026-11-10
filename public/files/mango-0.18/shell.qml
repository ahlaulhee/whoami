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

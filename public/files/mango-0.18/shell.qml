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

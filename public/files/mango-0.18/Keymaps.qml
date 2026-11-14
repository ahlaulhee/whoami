// Keymap cheatsheet: a modal with one tab per app that shows the app's
// keybinds, read from its configuration by ~/.local/bin/keymaps every time
// the modal opens. `qs ipc call keymaps toggle` shows or hides it
// (Super+Shift+/).
//
// The keyboard shows one layer at a time: the binds of the modifiers held
// down, or of the app's most used modifiers while none is held. A key takes
// the color of its bind's category. Below the keyboard come the keys that
// aren't on the board, then the binds of the layer under their categories.
// Hovering a key or a bind shows the whole command. An app whose binds are
// sequences of keys (Neovim) gets the list alone, with all its binds.
//
// Tab and Shift+Tab or 1-9 switch apps, h and l switch the modes of an app
// that has them, j and k scroll a list too long for the screen, Escape
// closes. The compositor's own binds keep working while the modal is open.
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
    readonly property color red: "#b66467"
    readonly property color border: "#424242"
    // One per category, in the order the categories appear in the config.
    readonly property var categoryColors:
        ["#8da3b9", "#8c977d", "#d9bc8c", "#a988b0", "#8aa6a2", "#b66467"]

    // Apps `keymaps` can read, one tab each. The tab and the mode of its app
    // stay selected while the shell runs.
    readonly property var apps:
        ["mango", "kew", "foot", "fish", "tmux", "nvim", "yazi", "zathura"]
    property int tab: 0
    property int mode: 0
    property bool open: false
    IpcHandler {
        target: "keymaps"
        function toggle(): void {
            root.open = !root.open;
        }
    }

    // Wooting 60HE (60 %, ANSI), row by row: [legend, XKB key name, width
    // in key units (1 when left out)]. Fn sends no key.
    readonly property var board: {
        const keys = chars => chars.split("").map(c => [c.toUpperCase(), c]);
        return [
            [["Esc", "Escape"], ...keys("1234567890"), ["-", "minus"], ["=", "equal"],
             ["Bksp", "BackSpace", 2]],
            [["Tab", "Tab", 1.5], ...keys("qwertyuiop"), ["[", "bracketleft"],
             ["]", "bracketright"], ["\\", "backslash", 1.5]],
            [["Caps", "Caps_Lock", 1.75], ...keys("asdfghjkl"), [";", "semicolon"],
             ["'", "apostrophe"], ["Enter", "Return", 2.25]],
            [["Shift", "Shift_L", 2.25], ...keys("zxcvbnm"), [",", "comma"], [".", "period"],
             ["/", "slash"], ["Shift", "Shift_R", 2.75]],
            [["Ctrl", "Control_L", 1.25], ["Super", "Super_L", 1.25], ["Alt", "Alt_L", 1.25],
             ["Space", "space", 6.25], ["Alt", "Alt_R", 1.25], ["Menu", "Menu", 1.25],
             ["Ctrl", "Control_R", 1.25], ["Fn", "", 1.25]]
        ];
    }
    // Legend of every key on the board, by lowercase key name.
    readonly property var boardLegends: {
        const legends = {};
        for (const row of board)
            for (const [legend, key] of row)
                legends[key.toLowerCase()] = legend;
        return legends;
    }
    // Legends for keys that aren't on the board; any other shows its name.
    readonly property var extraLegends: ({
        left: "←", right: "→", up: "↑", down: "↓", print: "PrtSc",
        xf86audioraisevolume: "Vol+", xf86audiolowervolume: "Vol-", xf86audiomute: "Mute",
        page_up: "PgUp", page_down: "PgDn", delete: "Del", insert: "Ins", grave: "`",
        wheel_up: "Wheel↑", wheel_down: "Wheel↓",
        btn_left: "LMB", btn_right: "RMB", btn_middle: "MMB"
    })

    // Modifiers, in the order a layer names them ("SUPER+SHIFT").
    readonly property var modifiers: ["SUPER", "CTRL", "ALT", "SHIFT"]
    readonly property var modifierFlags: ({
        SUPER: Qt.MetaModifier, CTRL: Qt.ControlModifier,
        ALT: Qt.AltModifier, SHIFT: Qt.ShiftModifier
    })
    readonly property var modifierKeys: ({
        super_l: "SUPER", control_l: "CTRL", control_r: "CTRL",
        alt_l: "ALT", alt_r: "ALT", shift_l: "SHIFT", shift_r: "SHIFT"
    })
    function modifierOf(key: int): string {
        switch (key) {
        case Qt.Key_Super_L:
        case Qt.Key_Super_R:
        case Qt.Key_Meta:
            return "SUPER";
        case Qt.Key_Control:
            return "CTRL";
        case Qt.Key_Alt:
            return "ALT";
        case Qt.Key_Shift:
            return "SHIFT";
        }
        return "";
    }

    // Text in the bar font, without its ligatures: keys and commands show
    // as they are typed ("<C-->", not an arrow).
    component Label: Text {
        font.family: "Maple Mono"
        font.pointSize: 11
        font.features: ({ calt: 0, liga: 0 })
        color: "#e8e3e3"
    }

    // A key 52 px tall. Keys sit 4 px apart, so one unit of width is 56 px
    // from the left edge of a key to the left edge of the next.
    component Keycap: Rectangle {
        id: cap
        required property string legend
        property real units: 1
        property color ink: "#a39d9d"
        readonly property alias hovered: hover.hovered
        implicitWidth: Math.max(units * 56 - 4, label.implicitWidth + 20)
        implicitHeight: 52
        border.width: 2

        Label {
            id: label
            anchors.centerIn: parent
            text: cap.legend
            color: cap.ink
        }
        HoverHandler {
            id: hover
        }
    }

    // A tab (filled while it's the current one) or, with tab: false, a mode
    // (outlined while it's the current one).
    component Chip: Rectangle {
        id: chip
        required property string text
        required property bool current
        property bool tab: true
        signal clicked
        implicitWidth: label.implicitWidth + 20
        implicitHeight: 22
        color: !tab ? "transparent" : current ? "#e8e3e3" : "#2a2a2a"
        border.width: tab ? 0 : 1
        border.color: current ? "#e8e3e3" : "transparent"

        Label {
            id: label
            anchors.centerIn: parent
            text: chip.text
            color: !chip.current ? "#a39d9d" : chip.tab ? "#151515" : "#e8e3e3"
        }
        MouseArea {
            anchors.fill: parent
            onClicked: chip.clicked()
        }
    }

    // LazyLoader creates the window each time it's shown, so the binds are
    // read again on every open.
    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            // No anchors: centred on the focused monitor, above everything,
            // with the keyboard until it closes.
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 1280
            implicitHeight: Math.min(body.implicitHeight + 40, (screen?.height ?? 1080) - 60)
            color: root.border
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            // Shown once the first binds are in, at its full height. A window
            // that changes height under a still pointer keeps the pointer's
            // old position, and the tooltip comes up for another key; when a
            // tab changes the height, the tooltip goes until the pointer
            // moves.
            visible: loaded
            property bool loaded: false
            onHeightChanged: win.tipOwner = null

            // Binds of the selected app, in every mode: [{mode, chords: how
            // many it takes, id: lowercase name of the first one's key, key,
            // layer: "SUPER+SHIFT" ("" without modifiers), label: all the
            // keys as text, category, color, text: description or command}].
            // A tab shows the binds of the one before it until its own
            // arrive.
            property var allBinds: []
            property string error: ""
            // Unless every bind is a single chord there is no keyboard and
            // no layers, and a list row gives the label: as wide as the
            // longest one, up to 28 characters.
            readonly property bool listOnly: allBinds.some(b => b.chords !== 1)
            readonly property real keysWidth: !listOnly ? 64 : metrics.averageCharacterWidth
                * Math.min(28, binds.reduce((most, b) => Math.max(most, b.label.length), 0))
            FontMetrics {
                id: metrics
                font.family: "Maple Mono"
                font.pointSize: 11
            }
            // Columns of the list: three, or as many as leave each row 24
            // characters for its text beside the keys.
            readonly property int listColumnCount: {
                const text = columns => (win.implicitWidth - 40 + 24) / columns - 24
                                        - win.keysWidth - 8;
                for (let columns = 3; columns > 1; columns--)
                    if (text(columns) >= 24 * metrics.averageCharacterWidth)
                        return columns;
                return 1;
            }
            function show(tab: int): void {
                if (tab !== root.tab)
                    root.mode = 0;
                root.tab = tab;
                extract.exec([Quickshell.env("HOME") + "/.local/bin/keymaps", root.apps[tab]]);
            }
            // The app's modes in its order, [""] when it has none, and the
            // binds of the selected one.
            readonly property var modes: allBinds.reduce(
                (modes, bind) => modes.includes(bind.mode) ? modes : modes.concat(bind.mode), [])
            readonly property int modeIndex: Math.max(0, Math.min(root.mode, modes.length - 1))
            readonly property var binds: allBinds.filter(b => b.mode === modes[modeIndex])
            Component.onCompleted: win.show(root.tab)

            Process {
                id: extract
                stdout: StdioCollector {
                    id: output
                }
                stderr: StdioCollector {
                    id: errors
                }
                // After both streams end, and also when the script can't be
                // run.
                onRunningChanged: {
                    if (!running)
                        win.load(output.text, errors.text.trim());
                }
            }
            function load(text: string, error: string): void {
                const app = root.apps[root.tab];
                const categories = [];
                let binds = [];
                try {
                    const data = JSON.parse(text);
                    // Unless it's the output of a tab left before its run
                    // ended.
                    if (data.app === app) {
                        binds = data.binds.map(bind => {
                            const chord = bind.keys[0] ?? { mods: [], key: "" };
                            if (!categories.includes(bind.category))
                                categories.push(bind.category);
                            return {
                                mode: bind.mode,
                                id: chord.key.toLowerCase(),
                                key: chord.key,
                                chords: bind.keys.length,
                                label: bind.label ?? bind.keys
                                    .map(c => c.mods.concat(c.key).join("+")).join(" "),
                                layer: root.modifiers.filter(m => chord.mods.includes(m)).join("+"),
                                category: bind.category,
                                color: root.categoryColors[categories.indexOf(bind.category)
                                                           % root.categoryColors.length],
                                text: bind.desc ?? bind.command
                            };
                        });
                    }
                } catch (e) {
                    if (text !== "" && error === "")
                        error = `keymaps ${app}: ${e.message}`;
                }
                win.allBinds = binds;
                win.error = error
                    || (binds.length === 0 ? `no binds from ~/.local/bin/keymaps ${app}` : "");
                win.loaded = true;
            }

            // Modifiers held down, and the layer they select.
            property var held: []
            function track(event: KeyEvent, pressed: bool): void {
                const own = root.modifierOf(event.key);
                win.held = root.modifiers.filter(m => m === own
                    ? pressed : (event.modifiers & root.modifierFlags[m]) !== 0);
            }
            readonly property string defaultLayer: {
                const counts = {};
                let most = "";
                for (const bind of win.binds) {
                    counts[bind.layer] = (counts[bind.layer] ?? 0) + 1;
                    if (counts[bind.layer] > (counts[most] ?? 0))
                        most = bind.layer;
                }
                return most;
            }
            readonly property string layer: held.length > 0 ? held.join("+") : defaultLayer
            readonly property var layerModifiers: layer === "" ? [] : layer.split("+")

            // Binds a layer shows: its own and, when the app's main layer
            // takes modifiers, the ones without modifiers on keys the layer
            // leaves free (Mango's media keys show in every layer).
            function bindsOf(layer: string): var {
                if (win.listOnly)
                    return win.binds;
                const own = win.binds.filter(b => b.layer === layer);
                if (win.defaultLayer === "")
                    return own;
                const taken = new Set(own.map(b => b.id));
                return own.concat(win.binds.filter(b => b.layer === "" && !taken.has(b.id)));
            }
            readonly property var byKey: {
                const keys = {};
                for (const bind of win.bindsOf(win.layer))
                    keys[bind.id] = bind;
                return keys;
            }
            // The same binds by category name.
            readonly property var byCategory: {
                const categories = {};
                for (const bind of win.bindsOf(win.layer)) {
                    if (!categories[bind.category])
                        categories[bind.category] = [];
                    categories[bind.category].push(bind);
                }
                return categories;
            }
            // Categories in config order: [{name, color, rows: the most
            // binds any layer shows for it}].
            readonly property var categories: {
                const categories = [];
                for (const bind of win.binds)
                    if (!categories.some(c => c.name === bind.category))
                        categories.push({ name: bind.category, color: bind.color, rows: 0 });
                for (const layer of new Set(win.binds.map(b => b.layer)))
                    for (const category of categories)
                        category.rows = Math.max(category.rows, win.bindsOf(layer)
                            .filter(b => b.category === category.name).length);
                return categories;
            }
            // The list: the categories in order, down listColumnCount columns
            // as short as they can be, from 8 lines up so that a short list
            // stays in one. A category takes a line for its name and one
            // for each of its rows, and a blank line follows it. One that
            // doesn't fit under the last starts the next column; one longer
            // than a column goes on in the next. Each column is a list of
            // {name, color, from, count}: rows from..from+count of a
            // category, under its name when from is 0.
            readonly property var listColumns: {
                const flow = height => {
                    const columns = [];
                    let free = 0;
                    for (const category of win.categories) {
                        const whole = category.rows + 1;
                        if (whole > free && (whole <= height || free < 2)) {
                            columns.push([]);
                            free = height;
                        }
                        for (let from = 0; from < category.rows;) {
                            const name = from === 0 ? 1 : 0;
                            if (free <= name) {
                                columns.push([]);
                                free = height;
                            }
                            const count = Math.min(category.rows - from, free - name);
                            columns[columns.length - 1].push(
                                { name: category.name, color: category.color, from, count });
                            free -= name + count + 1;
                            from += count;
                        }
                    }
                    return columns;
                };
                for (let height = 8;; height++) {
                    const columns = flow(height);
                    if (columns.length <= win.listColumnCount)
                        return columns;
                }
            }
            // Bound keys that aren't on the board, in config order.
            readonly property var extras: {
                const extras = [];
                for (const bind of win.binds)
                    if (!(bind.id in root.boardLegends) && !extras.some(e => e.id === bind.id))
                        extras.push(bind);
                return extras;
            }
            // A key's legend, with the clicks of a mouse button: "btn_left-2"
            // is LMB×2.
            function legendOf(bind: var): string {
                const [, key, clicks] = bind.id.match(/^(.+?)(?:-(\d+))?$/);
                const legend = root.boardLegends[key] ?? root.extraLegends[key];
                return legend === undefined ? bind.key : clicks ? `${legend}×${clicks}` : legend;
            }

            // The key or list row under the pointer; its tipText goes in
            // the tooltip.
            property Item tipOwner: null
            readonly property string tip: tipOwner?.tipText ?? ""
            function hover(item: Item, hovered: bool): void {
                if (hovered)
                    win.tipOwner = item;
                else if (win.tipOwner === item)
                    win.tipOwner = null;
            }

            Rectangle {
                id: frame
                anchors.fill: parent
                anchors.margins: 2
                color: root.bg
                focus: true
                Keys.onPressed: event => {
                    win.track(event, true);
                    const apps = root.apps.length;
                    const modes = win.modes.length;
                    const plain = event.modifiers === Qt.NoModifier;
                    if (event.key === Qt.Key_Escape)
                        root.open = false;
                    else if (event.key === Qt.Key_Tab)
                        win.show((root.tab + 1) % apps);
                    else if (event.key === Qt.Key_Backtab)
                        win.show((root.tab + apps - 1) % apps);
                    else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + Math.min(apps, 9))
                        win.show(event.key - Qt.Key_1);
                    else if (plain && modes > 1 && event.key === Qt.Key_H)
                        root.mode = (win.modeIndex + modes - 1) % modes;
                    else if (plain && modes > 1 && event.key === Qt.Key_L)
                        root.mode = (win.modeIndex + 1) % modes;
                    else if (plain && event.key === Qt.Key_J)
                        scroller.scroll(3);
                    else if (plain && event.key === Qt.Key_K)
                        scroller.scroll(-3);
                }
                Keys.onReleased: event => win.track(event, false)

                HoverHandler {
                    id: pointer
                }

                ColumnLayout {
                    id: body
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    // Tabs, one per app, then the modes of the selected app
                    // when it has more than one.
                    RowLayout {
                        spacing: 6

                        Repeater {
                            model: root.apps

                            Chip {
                                required property string modelData
                                required property int index
                                text: modelData
                                current: index === root.tab
                                onClicked: win.show(index)
                            }
                        }
                        Item {
                            implicitWidth: 18
                        }
                        Repeater {
                            model: win.modes.length > 1 ? win.modes : []

                            Chip {
                                required property string modelData
                                required property int index
                                text: modelData
                                current: index === win.modeIndex
                                tab: false
                                onClicked: root.mode = index
                            }
                        }
                        Label {
                            text: "modifiers: layer   Tab: app   h l: mode   j k: scroll   Esc: close"
                            color: root.muted
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Label {
                        visible: win.error !== ""
                        text: win.error
                        color: root.red
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // The board. A modifier of the shown layer is outlined.
                    Column {
                        visible: !win.listOnly
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Repeater {
                            model: root.board

                            Row {
                                id: boardRow
                                required property var modelData
                                spacing: 4

                                Repeater {
                                    model: boardRow.modelData

                                    Keycap {
                                        id: key
                                        required property var modelData
                                        readonly property string keyId: modelData[1].toLowerCase()
                                        readonly property var bind: win.byKey[keyId] ?? null
                                        readonly property bool held: win.layerModifiers
                                            .includes(root.modifierKeys[keyId] ?? "")
                                        readonly property string tipText: bind?.text ?? ""
                                        legend: modelData[0]
                                        units: modelData[2] ?? 1
                                        color: bind?.color ?? root.bg
                                        border.color: held ? root.fg : bind?.color ?? root.border
                                        ink: bind ? root.bg : held ? root.fg : root.muted
                                        onHoveredChanged: win.hover(key, hovered)
                                    }
                                }
                            }
                        }
                    }

                    // Bound keys that aren't on the board.
                    Row {
                        visible: !win.listOnly
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Repeater {
                            model: win.extras

                            Keycap {
                                id: extra
                                required property var modelData
                                readonly property var bind: win.byKey[modelData.id] ?? null
                                readonly property string tipText: bind?.text ?? ""
                                legend: win.legendOf(modelData)
                                color: bind?.color ?? root.bg
                                border.color: bind?.color ?? root.border
                                ink: bind ? root.bg : root.muted
                                onHoveredChanged: win.hover(extra, hovered)
                            }
                        }
                    }

                    // Binds of the shown layer under their categories. Each
                    // category keeps the room of its longest layer, so
                    // nothing moves as modifiers go down; its name dims while
                    // the layer has no binds for it. A list taller than the
                    // room the screen leaves scrolls, by the wheel or by
                    // three rows with j and k.
                    Flickable {
                        id: scroller
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: list.implicitHeight
                        contentHeight: list.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        function scroll(rows: int): void {
                            contentY = Math.max(0, Math.min(contentHeight - height,
                                                            contentY + rows * 22));
                        }
                        Connections {
                            target: win
                            function onBindsChanged(): void {
                                scroller.contentY = 0;
                            }
                        }

                        // How far down the list the view is, when it scrolls.
                        Rectangle {
                            parent: scroller
                            visible: scroller.visibleArea.heightRatio < 1
                            x: scroller.width - width
                            y: scroller.visibleArea.yPosition * scroller.height
                            width: 2
                            height: scroller.visibleArea.heightRatio * scroller.height
                            color: root.muted
                        }

                        RowLayout {
                            id: list
                            width: scroller.width
                            spacing: 24
                            uniformCellSizes: true

                            Repeater {
                                model: win.listColumns

                                Column {
                                    id: listColumn
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 22

                                    Repeater {
                                        model: listColumn.modelData

                                        // A category, or the rows of it
                                        // that this column holds.
                                        Column {
                                            id: category
                                            required property var modelData
                                            readonly property bool named: modelData.from === 0
                                            readonly property var binds:
                                                win.byCategory[modelData.name] ?? []
                                            width: listColumn.width
                                            height: (modelData.count + (named ? 1 : 0)) * 22

                                            Label {
                                                visible: category.named
                                                width: category.width
                                                height: 22
                                                text: category.modelData.name || "Other"
                                                color: category.binds.length > 0
                                                       ? category.modelData.color : root.border
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                            Repeater {
                                                model: category.binds.slice(
                                                    category.modelData.from,
                                                    category.modelData.from
                                                    + category.modelData.count)

                                                RowLayout {
                                                    id: row
                                                    required property var modelData
                                                    readonly property string tipText:
                                                        modelData.text
                                                    width: category.width
                                                    height: 22
                                                    spacing: 8

                                                    Label {
                                                        text: win.listOnly
                                                              ? row.modelData.label
                                                              : win.legendOf(row.modelData)
                                                        elide: Text.ElideRight
                                                        Layout.preferredWidth: win.keysWidth
                                                    }
                                                    Label {
                                                        text: row.modelData.text
                                                        color: root.muted
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 1
                                                    }
                                                    HoverHandler {
                                                        onHoveredChanged: win.hover(row, hovered)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Tooltip: below the pointer, or above it near the bottom
                // edge, and inside the window.
                Rectangle {
                    visible: win.tip !== ""
                    x: Math.max(0, Math.min(pointer.point.position.x + 14,
                                            frame.width - width))
                    y: pointer.point.position.y + 22 + height <= frame.height
                       ? pointer.point.position.y + 22
                       : pointer.point.position.y - height - 6
                    width: tipLabel.width + 20
                    height: tipLabel.height + 12
                    color: root.bg
                    border.width: 2
                    border.color: root.border

                    Label {
                        id: tipLabel
                        x: 10
                        y: 6
                        width: Math.min(implicitWidth, 640)
                        text: win.tip
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}

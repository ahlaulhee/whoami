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

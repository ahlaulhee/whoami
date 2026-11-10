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

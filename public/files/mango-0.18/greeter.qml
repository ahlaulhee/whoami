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

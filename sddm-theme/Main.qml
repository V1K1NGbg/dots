import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    color: "#191919"

    property color foreground: "#f8f8f2"
    property color muted: "#404040"
    property color accent: "#67ffeb"
    property color error: "#ff025f"
    property string fontName: "Monocraft Nerd Font"

    function authenticate() {
        message.color = accent
        message.text = "Authenticating…"
        sddm.login(username.text, password.text, sessions.currentIndex)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd  hh:mm")
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.72, 460)
        spacing: 18

        Text {
            id: clock
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: root.accent
            font.family: root.fontName
            font.pixelSize: 36
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "VIKING"
            color: root.foreground
            font.family: root.fontName
            font.pixelSize: 20
        }

        TextField {
            id: username
            width: parent.width
            height: 52
            text: userModel.lastUser
            placeholderText: "User"
            selectByMouse: true
            color: root.foreground
            placeholderTextColor: root.muted
            font.family: root.fontName
            font.pixelSize: 16
            background: Rectangle {
                color: "#191919"
                border.color: username.activeFocus ? root.accent : root.muted
                border.width: 2
                radius: 5
            }
            Keys.onReturnPressed: password.forceActiveFocus()
        }

        TextField {
            id: password
            width: parent.width
            height: 52
            placeholderText: "Password"
            echoMode: TextInput.Password
            selectByMouse: true
            color: root.foreground
            placeholderTextColor: root.muted
            font.family: root.fontName
            font.pixelSize: 16
            background: Rectangle {
                color: "#191919"
                border.color: password.activeFocus ? root.accent : root.muted
                border.width: 2
                radius: 5
            }
            Keys.onReturnPressed: root.authenticate()
        }

        ComboBox {
            id: sessions
            width: parent.width
            height: 44
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex
            font.family: root.fontName
        }

        Button {
            width: parent.width
            height: 50
            text: "LOG IN"
            onClicked: root.authenticate()
            contentItem: Text {
                text: parent.text
                color: "#191919"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.fontName
                font.pixelSize: 16
            }
            background: Rectangle {
                color: root.accent
                radius: 5
            }
        }

        Text {
            id: message
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Enter a password, or press Enter and scan your fingerprint"
            color: root.muted
            font.family: root.fontName
            font.pixelSize: 12
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            Button {
                text: "Restart"
                onClicked: sddm.reboot()
                font.family: root.fontName
            }
            Button {
                text: "Power off"
                onClicked: sddm.powerOff()
                font.family: root.fontName
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            message.color = root.error
            message.text = "Authentication failed"
            password.text = ""
            password.forceActiveFocus()
        }
        function onLoginSucceeded() {
            message.color = root.accent
            message.text = "Starting Hyprland…"
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}


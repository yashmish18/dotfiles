import QtQuick
import qs.services

// text input as a single underline. no box.
Item {
    id: root
    property alias text: edit.text
    property alias input: edit
    property string placeholder: ""
    property bool password: false
    property bool mono: false
    property int size: Theme.lg
    property bool captureDelete: false
    signal accepted()
    signal escaped()
    signal upPressed()
    signal downPressed()
    signal tabPressed()
    signal deletePressed()

    implicitWidth: 300
    implicitHeight: edit.implicitHeight + 12

    function focusNow() { edit.forceActiveFocus(); }
    function clear() { edit.text = ""; }

    TextInput {
        id: edit
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.paper
        selectionColor: Theme.accentDim
        selectedTextColor: Theme.paper
        font.family: root.mono ? Theme.mono : Theme.sans
        font.pixelSize: root.size
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "·"
        clip: true
        cursorDelegate: Rectangle {
            width: 1
            color: Theme.accent
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: edit.activeFocus
                NumberAnimation { to: 0; duration: 530; easing.type: Easing.InQuad }
                NumberAnimation { to: 1; duration: 530; easing.type: Easing.OutQuad }
            }
        }
        Keys.onReturnPressed: root.accepted()
        Keys.onEnterPressed: root.accepted()
        Keys.onEscapePressed: root.escaped()
        Keys.onUpPressed: root.upPressed()
        Keys.onDownPressed: root.downPressed()
        Keys.onTabPressed: root.tabPressed()
        Keys.onDeletePressed: e => {
            if (root.captureDelete) root.deletePressed();
            else e.accepted = false;
        }
    }

    Txt {
        anchors.fill: edit
        visible: edit.text === "" && !edit.inputMethodComposing
        text: root.placeholder
        color: Theme.faint
        font.family: Theme.serif
        font.italic: true
        font.pixelSize: root.size
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: edit.activeFocus ? Theme.accentDim : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
}

import QtQuick
import qs.services
import qs.components

// a note on the desktop. click and type; it saves as you go.
Rectangle {
    id: root
    implicitWidth: 260
    implicitHeight: Math.max(120, edit.contentHeight + 44)
    radius: Theme.radius
    color: Theme.glass
    border.width: 1
    border.color: edit.activeFocus ? Theme.primary : Theme.alpha(Theme.surfaceText, 0.08)

    // the strip you drag it by
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 7
        anchors.horizontalCenter: parent.horizontalCenter
        width: 36
        height: 4
        radius: 2
        color: Theme.alpha(Theme.surfaceText, 0.25)
    }
    TextEdit {
        id: edit
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 22
        text: Config.s.noteText
        // a note edited elsewhere (or restored from settings) shows up here too
        Connections {
            target: Config.s
            function onNoteTextChanged() { if (!edit.activeFocus && edit.text !== Config.s.noteText) edit.text = Config.s.noteText; }
        }
        wrapMode: TextEdit.Wrap
        color: Theme.surfaceText
        selectionColor: Theme.primaryContainer
        selectedTextColor: Theme.primaryContainerText
        font.family: Theme.sans
        font.pixelSize: Theme.md + 1
        // save shortly after you stop typing
        onTextChanged: save.restart()
        Timer { id: save; interval: 600; onTriggered: if (Config.s.noteText !== edit.text) Config.s.noteText = edit.text }
    }
}

import QtQuick
import Quickshell
import qs.services
import qs.components

// a note on the desktop: a fixed-size card you type in; longer text scrolls (wheel, or just
// keep typing). it saves as you go. drag it by the strip at the top, resize by its corner dot.
Rectangle {
    id: root
    implicitWidth: 280
    implicitHeight: 200
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

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        anchors.topMargin: 22
        anchors.bottomMargin: 12
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, edit.contentHeight + 6)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        // keep the cursor in view while typing
        function follow(r: rect) {
            if (r.y < contentY) contentY = r.y;
            else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
        }

        // a press anywhere in the note: the desktop takes the keyboard and the cursor goes here
        TapHandler {
            onPressedChanged: if (pressed) root.startTyping()
        }
        TextEdit {
            id: edit
            width: flick.width - 6
            text: Config.s.noteText
            wrapMode: TextEdit.Wrap
            color: Theme.surfaceText
            selectionColor: Theme.primaryContainer
            selectedTextColor: Theme.primaryContainerText
            font.family: Theme.sans
            font.pixelSize: Theme.md + 1
            onCursorRectangleChanged: flick.follow(cursorRectangle)
            onActiveFocusChanged: if (activeFocus) root.startTyping()
            Keys.onEscapePressed: { edit.focus = false; Ui.deskTyping = false; }
            Connections {
                target: Ui
                function onDeskTypingChanged() { if (!Ui.deskTyping && edit.activeFocus) edit.focus = false; }
            }
            // save shortly after you stop typing
            onTextChanged: save.restart()
            Timer { id: save; interval: 600; onTriggered: if (Config.s.noteText !== edit.text) Config.s.noteText = edit.text }
            // a note edited elsewhere (or restored from settings) shows up here too
            Connections {
                target: Config.s
                function onNoteTextChanged() { if (!edit.activeFocus && edit.text !== Config.s.noteText) edit.text = Config.s.noteText; }
            }
        }
    }
    function startTyping() {
        Ui.deskTypingWin = root.QsWindow.window;
        Ui.deskTyping = true;
        edit.forceActiveFocus();
    }
    // a thin scroll bar, only when there's more than fits
    Rectangle {
        visible: flick.contentHeight > flick.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 4
        width: 3
        radius: 1.5
        color: Theme.alpha(Theme.surfaceText, 0.3)
        y: flick.y + (flick.contentY / flick.contentHeight) * flick.height
        height: Math.max(16, flick.height * flick.height / flick.contentHeight)
    }
}

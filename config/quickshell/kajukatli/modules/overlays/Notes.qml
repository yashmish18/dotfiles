import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// quick notes: super + shift + n. one page that's always there, saved as you type to
// ~/Documents/notes.md (open it in anything). esc closes; nothing to press to save.
Item {
    id: root
    focus: true

    readonly property string path: Config.home + "/Documents/notes.md"
    property bool ready: false

    FileView {
        id: file
        path: root.path
        printErrors: false
        onLoaded: { edit.text = text(); root.ready = true; edit.cursorPosition = edit.length; }
        onLoadFailed: root.ready = true
    }
    // write a moment after the last key, not on every one
    Timer {
        id: save
        interval: 600
        onTriggered: {
            saver.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"', "sh", root.path, edit.text];
            saver.running = true;
        }
    }
    Process { id: saver }
    Component.onDestruction: if (save.running) { save.stop(); Quickshell.execDetached(["sh", "-c", 'printf "%s" "$2" > "$1"', "sh", root.path, edit.text]); }

    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(parent.width, 860)
        height: Math.min(parent.height, 640)
        radius: Theme.radius + 10
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.alpha(Theme.surfaceText, 0.08)

        Txt {
            id: head
            x: 34; y: 26
            text: "Notes"
            font.pixelSize: 26
            font.weight: Font.Bold
        }
        Txt {
            anchors.right: parent.right
            anchors.rightMargin: 34
            anchors.verticalCenter: head.verticalCenter
            text: save.running || saver.running ? "saving" : "~/Documents/notes.md"
            font.family: Theme.mono
            font.pixelSize: Theme.xs + 1
            color: Theme.outline
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.topMargin: 78
            anchors.margins: 34
            contentHeight: edit.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            function ensureVisible(r: var) {
                if (contentY >= r.y) contentY = r.y;
                else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
            }
            TextEdit {
                id: edit
                width: flick.width
                wrapMode: TextEdit.Wrap
                font.family: Theme.mono
                font.pixelSize: Theme.md + 1
                color: Theme.surfaceText
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryText
                selectByMouse: true
                focus: true
                Component.onCompleted: forceActiveFocus()
                onTextChanged: if (root.ready) save.restart()
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                Keys.onEscapePressed: Ui.overlay = ""
                Txt {
                    visible: edit.text === "" && root.ready
                    text: "Anything. It saves itself."
                    font.family: Theme.mono
                    font.pixelSize: Theme.md + 1
                    color: Theme.outline
                }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; onClicked: edit.forceActiveFocus() }
    }
}

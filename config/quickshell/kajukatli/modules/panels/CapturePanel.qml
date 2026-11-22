import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// print screen: what to capture. 1–6 or click; d cycles the delay, e toggles "edit after".
// "text" reads the words in an area and copies them (kk-ocr).
Item {
    id: root
    implicitWidth: 560
    implicitHeight: col.implicitHeight
    focus: true

    property int delay: 0
    property bool editAfter: false
    property int index: 0

    readonly property var shots: [
        { key: "region", label: "Region", icon: "screenshot" },
        { key: "window", label: "Window", icon: "grid" },
        { key: "screen", label: "Screen", icon: "image" },
        { key: "text", label: "Text", icon: "clipboard" },
        { key: "rec-region", label: "Record region", icon: "record" },
        { key: "rec-screen", label: "Record screen", icon: "record" }
    ]

    function go(i) {
        const k = shots[i].key;
        Ui.panel = "";
        // let the menu fade before the screen is captured
        const pre = "sleep 0.35; ";
        if (k === "text") {
            Quickshell.execDetached(["sh", "-c", pre + Config.bin + "kk-ocr"]);
        } else if (k.startsWith("rec-")) {
            Quickshell.execDetached(["sh", "-c", pre + Config.bin + "kk-record " + k.slice(4)]);
        } else {
            const args = [k];
            if (delay > 0) args.push(String(delay));
            if (editAfter) args.push("--edit");
            Quickshell.execDetached(["sh", "-c", pre + Config.bin + "kk-shot " + args.join(" ")]);
        }
    }

    Keys.onEscapePressed: Ui.panel = ""
    Keys.onLeftPressed: index = (index + shots.length - 1) % shots.length
    Keys.onRightPressed: index = (index + 1) % shots.length
    Keys.onReturnPressed: go(index)
    Keys.onPressed: e => {
        const n = parseInt(e.text);
        if (n >= 1 && n <= shots.length) { go(n - 1); e.accepted = true; }
        else if (e.text === "d") { delay = delay === 0 ? 3 : delay === 3 ? 5 : delay === 5 ? 10 : 0; e.accepted = true; }
        else if (e.text === "e") { editAfter = !editAfter; e.accepted = true; }
    }
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // recording right now: one big way out
        Btn {
            visible: Ui.recording
            Layout.fillWidth: true
            implicitHeight: 44
            text: "Stop recording"
            icon: "record"
            danger: true
            active: true
            onClicked: { Ui.panel = ""; Quickshell.execDetached([Config.bin + "kk-record"]); }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: root.shots
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool sel: root.index === index
                    readonly property bool rec: modelData.key.startsWith("rec-")
                    Layout.fillWidth: true
                    implicitHeight: 84
                    radius: Theme.radius
                    color: sel ? (rec ? Theme.alpha(Theme.error, 0.22) : Theme.primaryContainer) : area.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    scale: area.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: card.modelData.icon
                            size: 22
                            color: card.rec ? Theme.error : card.sel ? Theme.primaryContainerText : Theme.surfaceText
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.label
                            font.pixelSize: Theme.sm
                            color: card.sel ? Theme.surfaceText : Theme.surfaceTextDim
                        }
                    }
                    Txt {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 7
                        text: card.index + 1
                        font.family: Theme.mono
                        font.pixelSize: Theme.xs
                        color: Theme.outline
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.index = card.index
                        onClicked: root.go(card.index)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Choice {
                Layout.fillWidth: false
                options: [{ value: 0, label: "now" }, { value: 3, label: "3 s" }, { value: 5, label: "5 s" }, { value: 10, label: "10 s" }]
                value: root.delay
                onPicked: v => root.delay = v
            }
            Item { Layout.fillWidth: true }
            Txt { text: "Edit after"; color: Theme.surfaceTextDim; font.pixelSize: Theme.sm }
            Switch { on: root.editAfter; onToggled: root.editAfter = !root.editAfter }
        }
    }
}

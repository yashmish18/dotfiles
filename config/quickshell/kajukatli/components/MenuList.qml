import QtQuick
import qs.services

// a small right-click menu card. items: [{ label, on, danger, sep, run: function }]
// a row with `on` shows a tick; `sep: true` is a divider. `done` fires after any row ran.
Rectangle {
    id: root
    property var items: []
    property int menuWidth: 210
    signal done()

    width: menuWidth
    height: col.implicitHeight + 12
    radius: 14
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.outlineVariant

    Column {
        id: col
        x: 6
        y: 6
        width: parent.width - 12
        Repeater {
            model: root.items
            delegate: Item {
                id: row
                required property var modelData
                width: col.width
                height: modelData.sep ? 9 : 32
                Rectangle {
                    visible: !!row.modelData.sep
                    anchors.centerIn: parent
                    width: parent.width - 12
                    height: 1
                    color: Theme.outlineVariant
                }
                Rectangle {
                    visible: !row.modelData.sep
                    anchors.fill: parent
                    radius: 9
                    color: ma.containsMouse ? (row.modelData.danger ? Theme.alpha(Theme.error, 0.18) : Theme.surfaceHighest) : "transparent"
                    Txt {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: tick.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label || ""
                        elide: Text.ElideRight
                        font.pixelSize: Theme.sm + 1
                        color: row.modelData.danger ? Theme.error : Theme.surfaceText
                    }
                    Txt {
                        id: tick
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!row.modelData.on
                        text: "✓"
                        color: Theme.primary
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (row.modelData.run) row.modelData.run(); root.done(); }
                    }
                }
            }
        }
    }
}

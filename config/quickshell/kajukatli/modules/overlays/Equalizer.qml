import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// the equalizer sheet. only exists while it's open (see Overlay.qml).
Item {
    id: root
    focus: true
    Keys.onEscapePressed: Ui.overlay = ""
    Component.onCompleted: forceActiveFocus()

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, 760)
        height: col.implicitHeight + 40
        radius: Theme.radius + 10
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.alpha(Theme.surfaceText, 0.08)
        MouseArea { anchors.fill: parent }     // a click on the card doesn't close the sheet

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Txt { text: "Equalizer"; font.pixelSize: Theme.lg; font.weight: Font.Medium; Layout.fillWidth: true }
                Btn { text: Eq.on ? "On" : "Off"; active: Eq.on; onClicked: Eq.toggle() }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: Eq.presets
                    delegate: Btn {
                        required property var modelData
                        text: modelData.label
                        active: Eq.on && Eq.presetLabel === modelData.label
                        onClicked: Eq.usePreset(modelData)
                    }
                }
            }
            Row {
                id: bands
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                opacity: Eq.on ? 1 : 0.45
                Repeater {
                    model: 10
                    delegate: Item {
                        id: band
                        required property int index
                        readonly property real db: Eq.gains[index]
                        width: bands.width / 10
                        height: bands.height
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (band.db > 0 ? "+" : "") + band.db
                            font.family: Theme.mono
                            font.pixelSize: Theme.sm
                        }
                        Rectangle {
                            id: track
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 24
                            width: 6
                            height: parent.height - 48
                            radius: 3
                            color: Theme.surfaceHigh
                            readonly property real knobY: (1 - (band.db + 12) / 24) * height
                            Rectangle {      // from the middle to the knob
                                width: parent.width
                                radius: 3
                                y: Math.min(parent.knobY, parent.height / 2)
                                height: Math.abs(parent.knobY - parent.height / 2)
                                color: Theme.primary
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                x: -6
                                y: parent.knobY - 9
                                color: Theme.primary
                            }
                        }
                        // drag or scroll; double-click puts this band back to 0
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function set(y: real) { Eq.setBand(band.index, 12 - 24 * (y - track.y) / track.height); }
                            onPressed: e => set(e.y)
                            onPositionChanged: e => { if (pressed) set(e.y); }
                            onDoubleClicked: Eq.setBand(band.index, 0)
                            onWheel: e => Eq.setBand(band.index, band.db + (e.angleDelta.y > 0 ? 0.5 : -0.5))
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: Eq.freqs[band.index]
                            color: Theme.surfaceTextDim
                            font.pixelSize: Theme.sm
                        }
                    }
                }
            }
            Txt {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.sm
                color: Eq.error !== "" ? Theme.error : Theme.surfaceTextDim
                text: Eq.error !== "" ? Eq.error + "  (switch it off and on to try again)"
                    : "Changes are heard at once, about as loud as with it off. Big boosts can distort very loud tracks. It follows the output you pick."
            }
        }
    }
}

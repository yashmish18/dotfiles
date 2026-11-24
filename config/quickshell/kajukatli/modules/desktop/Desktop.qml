import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// the desktop window: widgets above the wallpaper and below your windows.
// clicks only land on the widgets you can use (calendar, player); the rest of the desktop
// stays click-through. edit mode (super + shift + e) lifts it over everything so you can drag
// widgets around; positions are saved to settings.json.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        // typing in the notepad: lifted and given the keyboard, because
        // a bottom-layer surface is never handed keyboard focus reliably
        readonly property bool typingHere: Ui.deskTyping && Ui.deskTypingWin === win
        WlrLayershell.layer: Ui.editing || typingHere ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.namespace: "kajukatli-desktop"
        WlrLayershell.keyboardFocus: typingHere ? WlrKeyboardFocus.Exclusive : Ui.editing || Config.s.showNote ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // click anywhere else: stop typing
        HyprlandFocusGrab {
            windows: [win]
            active: win.typingHere
            onCleared: Ui.deskTyping = false
        }
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        mask: Ui.editing || Ui.widgetMenu !== "" ? fullRegion : widgetRegion
        Region { id: fullRegion; item: root }
        Region {
            id: widgetRegion
            regions: [
                Region { item: layer.calendarItem },
                Region { item: layer.mediaItem },
                Region { item: layer.noteItem },
                Region { item: layer.timerItem },
                Region { item: layer.clockItem },
                Region { item: layer.barsItem },
                Region { item: layer.statsItem },
                Region { item: layer.weatherItem },
                Region { item: layer.batteryItem },
                Region { item: layer.analogItem },
                Region { item: layer.waveItem.visible ? layer.waveItem : null }
            ]
        }

        Item {
            id: root
            anchors.fill: parent
            focus: Ui.editing
            Keys.onEscapePressed: Ui.editing = false

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha("#000000", 0.35)
                opacity: Ui.editing ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            }

            // focus mode dims the wallpaper
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: Ui.focusMode ? 0.4 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
            }

            DesktopLayer {
                id: layer
                anchors.fill: parent
                behind: false
                monitor: Hyprland.monitorFor(win.modelData)
            }

            // ------------------------------------------------ edit-mode banner
            Rectangle {
                visible: Ui.editing
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: banner.implicitWidth + 36
                implicitHeight: banner.implicitHeight + 24
                radius: Theme.radius
                color: Theme.glassStrong
                border.width: 1
                border.color: Theme.outlineVariant

                ColumnLayout {
                    id: banner
                    anchors.centerIn: parent
                    spacing: 10
                    Txt {
                        Layout.alignment: Qt.AlignHCenter
                        text: "arrange your desktop"
                        font.pixelSize: Theme.lg
                        font.weight: Font.Medium
                    }
                    Txt {
                        Layout.alignment: Qt.AlignHCenter
                        text: "drag any outlined widget. it remembers where you leave it."
                        color: Theme.surfaceTextDim
                        font.pixelSize: Theme.sm
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Btn { text: "Settings"; onClicked: { Ui.editing = false; Ui.open("settings"); } }
                        Btn { text: "Reset"; onClicked: { const p = Looks.presets[Config.s.look]; Config.s.layout = p ? Object.assign({}, p.layout) : ({}); } }
                        Btn { text: "Done"; active: true; onClicked: Ui.editing = false }
                    }
                }
            }
        }
    }
}

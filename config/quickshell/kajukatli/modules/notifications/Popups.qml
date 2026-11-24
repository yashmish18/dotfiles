import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.services
import qs.components

// toasts, top-right of the screen you're on. hover to keep one; urgent ones wait for you.
PanelWindow {
    id: win
    screen: Hypr.activeScreen
    visible: Notifs.popups.length > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kajukatli-notifications"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: Ui.topInset + 12; right: 12 }
    implicitWidth: 372
    implicitHeight: Math.max(1, stack.implicitHeight + 12)
    color: "transparent"
    mask: Region { item: stack }

    Column {
        id: stack
        width: 360
        spacing: 8

        Repeater {
            model: Notifs.popups.filter(n => n)

            delegate: Item {
                id: slot
                required property var modelData
                width: 360
                height: card.implicitHeight
                opacity: 0
                x: 24
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

                function close() { Notifs.dismissPopup(slot.modelData); }

                NotifCard {
                    id: card
                    width: parent.width
                    notif: slot.modelData
                    popup: true
                    onDone: slot.close()
                }

                // the app withdrew it
                Connections {
                    target: slot.modelData
                    function onClosed() { slot.close(); }
                }

                HoverHandler { id: hover }
                Timer {
                    readonly property int ms: slot.modelData && slot.modelData.expireTimeout > 0 ? slot.modelData.expireTimeout * 1000 : Config.s.notificationTimeout
                    interval: ms
                    running: !hover.hovered && slot.modelData && slot.modelData.urgency !== NotificationUrgency.Critical
                    onTriggered: slot.close()
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: slot.close()
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// push the pointer into a corner and hold it there a moment:
//   top left      the workspace overview
//   bottom right  the desktop (an empty workspace); again, back to where you were
Variants {
    model: Config.s.hotCorners ? Quickshell.screens : []

    Scope {
        id: scope
        required property var modelData

        component Corner: PanelWindow {
            id: win
            property bool atLeft: true
            property bool atTop: true
            signal hit()
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kajukatli-corner"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: win.atLeft; right: !win.atLeft; top: win.atTop; bottom: !win.atTop }
            implicitWidth: 2
            implicitHeight: 2
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: dwell.restart()
                onExited: dwell.stop()
            }
            Timer { id: dwell; interval: 140; onTriggered: win.hit() }
        }

        Corner {
            screen: scope.modelData
            atLeft: true; atTop: true
            onHit: Ui.toggleOverlay("overview")
        }
        Corner {
            screen: scope.modelData
            atLeft: false; atTop: false
            property int back: 0
            onHit: {
                if (back > 0 && Hypr.focusedWs && (Hypr.focusedWs.toplevels ? Hypr.focusedWs.toplevels.values.length === 0 : true)) {
                    Hypr.focusWorkspace(back);
                    back = 0;
                } else {
                    back = Hypr.focusedId;
                    Hypr.newWorkspace(false);
                }
            }
        }
    }
}

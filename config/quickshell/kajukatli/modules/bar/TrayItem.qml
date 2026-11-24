import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services

Item {
    id: root
    required property var modelData
    property int menuEdge: Edges.Bottom    // which side the bar's menu opens toward
    implicitWidth: 14
    implicitHeight: 14

    IconImage {
        anchors.fill: parent
        source: root.modelData.icon
        implicitSize: 14
        // tray icons are loud. keep them grey until you reach for one.
        opacity: area.containsMouse ? 1 : 0.6
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    }

    QsMenuAnchor {
        id: menu
        menu: root.modelData.menu
        anchor.item: root
        anchor.edges: root.menuEdge
        anchor.gravity: root.menuEdge
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        // one tap: everything the app offers (its menu). right-click opens the app itself,
        // middle-click its second action. settings → behaviour can swap tap back to "open".
        onClicked: e => {
            const tapMenu = Config.s.trayTapMenu && root.modelData.hasMenu;
            if (e.button === Qt.MiddleButton) root.modelData.secondaryActivate();
            else if (e.button === Qt.RightButton) { if (tapMenu || root.modelData.onlyMenu) root.modelData.activate(); else if (root.modelData.hasMenu) menu.open(); }
            else if (tapMenu || root.modelData.onlyMenu) { if (root.modelData.hasMenu) menu.open(); }
            else root.modelData.activate();
        }
        onWheel: e => root.modelData.scroll(e.angleDelta.y, false)
    }
}

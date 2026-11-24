import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// full-screen sheets: workspace overview, wallpaper contact sheet, keybind cheatsheet.
// created only while open, so they cost nothing the rest of the time.
LazyLoader {
    id: loader
    active: Ui.overlay !== ""

    PanelWindow {
        id: win
        screen: Hypr.activeScreen
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kajukatli-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Rectangle {
            id: dim
            anchors.fill: parent
            color: Theme.alpha("#000000", Ui.overlay === "wallpapers" ? 0.55 : Ui.overlay === "apps" ? 0.6 : 0.72)   // a dark scrim in light mode too: overlay text is white
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }

            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("../../shaders/grain.frag.qsb")
                property real time: 0
                property real amount: 0.05
                property vector2d size: Qt.vector2d(width / 1.5, height / 1.5)
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: Ui.overlay = ""
        }

        Loader {
            id: content
            anchors.fill: parent
            anchors.margins: 56
            focus: true
            opacity: 0
            y: 12
            Component.onCompleted: { opacity = 1; y = 0; }
            Behavior on opacity { NumberAnimation { duration: Theme.slow } }
            Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
            sourceComponent: Ui.overlay === "overview" ? overviewC : Ui.overlay === "wallpapers" ? wallC : Ui.overlay === "cheatsheet" ? cheatC
                           : Ui.overlay === "apps" ? appsC : Ui.overlay === "projection" ? projectionC : Ui.overlay === "packages" ? packagesC
                           : Ui.overlay === "power" ? powerC : Ui.overlay === "notes" ? notesC : Ui.overlay === "system" ? systemC : Ui.overlay === "displays" ? displaysC : null
            Keys.onEscapePressed: Ui.overlay = ""
        }

        Component { id: overviewC; Overview { screen: win.screen } }
        Component { id: wallC; WallpaperPicker {} }
        Component { id: cheatC; Cheatsheet {} }
        Component { id: appsC; AppDrawer {} }
        Component { id: projectionC; ProjectionMenu {} }
        Component { id: packagesC; PackageManager {} }
        Component { id: powerC; PowerMenu {} }
        Component { id: notesC; Notes {} }
        Component { id: systemC; SystemMonitor {} }
        Component { id: displaysC; DisplaySettings {} }
    }
}

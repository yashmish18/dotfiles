import QtQuick
import QtQuick.Shapes
import qs.services

// one of the shell's own line icons (services/Icons.qml), drawn as vector paths in the
// current colour. crisp at any size, recoloured with the wallpaper like everything else.
//
//   Icon { name: "wifi"; level: Net.signal / 100; size: 16 }
Item {
    id: root
    property string name: "spark"
    property real size: 16
    property color color: Theme.surfaceText
    property real level: -1          // meters: wi-fi, volume, battery
    property real weight: size <= 16 ? 2.0 : size <= 22 ? 1.8 : 1.6

    implicitWidth: size
    implicitHeight: size

    readonly property var spec: Icons.path(name, level)

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.spec.dim ? Theme.alpha(root.color, 0.28) : "transparent"
            strokeWidth: root.weight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.spec.dim || "M0 0" }
        }
        ShapePath {
            strokeColor: root.spec.d ? root.color : "transparent"
            strokeWidth: root.weight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.spec.d || "M0 0" }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.spec.solid ? root.color : "transparent"
            PathSvg { path: root.spec.solid || "M0 0" }
        }
    }
}

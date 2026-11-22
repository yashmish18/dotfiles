import QtQuick
import QtQuick.Shapes
import qs.services
import qs.components

// the battery as a ring: how full, and a bolt while charging
Item {
    id: root
    implicitWidth: 120
    implicitHeight: 120
    visible: Power.hasBattery
    readonly property real frac: Power.percent / 100
    readonly property color tint: Power.low ? Theme.error : Power.charging ? Theme.success : Theme.wallText

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.alpha(Theme.wallText, 0.18)
            strokeWidth: 7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 60; centerY: 60; radiusX: 54; radiusY: 54; startAngle: -90; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.tint
            strokeWidth: 7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 60; centerY: 60; radiusX: 54; radiusY: 54; startAngle: -90; sweepAngle: 360 * root.frac }
        }
    }
    Column {
        anchors.centerIn: parent
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Power.charging
            name: "bolt"
            size: 16
            color: root.tint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Power.percent
            font.family: Theme.display
            font.pixelSize: 34
            font.weight: Font.Bold
            color: Theme.wallText
            renderType: Text.QtRendering
        }
    }
}

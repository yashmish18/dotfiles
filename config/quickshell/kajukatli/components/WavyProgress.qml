import QtQuick
import QtQuick.Shapes
import qs.services

// a seek bar that wiggles while the music plays: a sine wave up to the playhead, a flat
// hairline after it. click or drag to seek.
Item {
    id: root
    property real value: 0            // 0..1
    property bool moving: false       // animate the wave
    property color color: Theme.primary
    property color trackColor: Theme.alpha(Theme.surfaceText, 0.25)
    property real amplitude: 3
    property real wavelength: 14
    property real thickness: 2.4
    signal seek(real frac)

    implicitWidth: 200
    implicitHeight: 14

    property real phase: 0
    NumberAnimation on phase {
        running: root.moving && root.visible
        from: 0
        to: Math.PI * 2
        duration: 1400
        loops: Animation.Infinite
    }

    readonly property real headX: Math.max(0, Math.min(1, value)) * width
    readonly property var wave: {
        const pts = [];
        const mid = height / 2;
        const step = 2;
        const amp = moving ? amplitude : amplitude * 0.35;
        for (let x = 0; x <= headX; x += step)
            pts.push(Qt.point(x, mid + Math.sin(x / wavelength * Math.PI * 2 - phase) * amp));
        if (pts.length === 0) pts.push(Qt.point(0, mid));
        return pts;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: root.headX + 4; startY: root.height / 2
            PathLine { x: Math.max(root.headX + 4, root.width); y: root.height / 2 }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root.wave }
        }
    }
    Rectangle {
        x: root.headX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: root.height
        radius: 1.5
        color: root.color
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        cursorShape: Qt.PointingHandCursor
        onPressed: e => root.seek(Math.max(0, Math.min(1, e.x / width)))
        onPositionChanged: e => { if (pressed) root.seek(Math.max(0, Math.min(1, e.x / width))); }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.components

// system numbers written straight onto the wallpaper: a cpu sparkline, a network graph,
// a disk bar, and temperatures / fan / battery when the hardware reports them.
Item {
    id: root
    implicitWidth: 300
    implicitHeight: col.implicitHeight

    property bool live: true
    Uses { service: Sys; active: root.live }

    readonly property color fg: Theme.wallText
    readonly property color dim: Theme.wallTextDim

    component Spark: Shape {
        id: sp
        property var values: []
        property real max: 1
        property color color: Theme.wallText
        preferredRendererType: Shape.CurveRenderer
        readonly property var pts: {
            const v = values, n = v.length, w = width, h = height;
            const out = [Qt.point(0, h)];
            for (let i = 0; i < n; i++)
                out.push(Qt.point(n > 1 ? i / (n - 1) * w : 0, h - Math.min(1, (v[i] || 0) / Math.max(1e-9, max)) * h * 0.92));
            out.push(Qt.point(w, h));
            return out;
        }
        ShapePath {
            strokeColor: sp.color
            strokeWidth: 1.5
            fillColor: Theme.alpha(sp.color, 0.25)
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: sp.pts }
        }
    }

    component Stat: RowLayout {
        property string label: ""
        property string value: ""
        property color tick: "transparent"
        Layout.fillWidth: true
        spacing: 10
        Rectangle { width: 3; height: 15; radius: 1.5; color: parent.tick }
        Txt { text: parent.label; color: Theme.wallText; font.pixelSize: 15; Layout.fillWidth: true }
        Txt { text: parent.value; color: Theme.wallText; font.pixelSize: 15; font.features: ({ "tnum": 1 }) }
    }

    ColumnLayout {
        id: col
        width: root.width
        spacing: 4

        Spark {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            values: Sys.cpuHistory
            max: 1
            color: Theme.primary
        }
        Stat { label: "CPU"; value: (Sys.cpu * 100).toFixed(1) + "%"; tick: Theme.primary }
        Stat { visible: Sys.gpu >= 0; label: "GPU"; value: Math.round(Sys.gpu * 100) + "%"; tick: Theme.tertiary }
        Stat { label: "Memory"; value: Sys.bytes(Sys.memUsed) }

        Item { Layout.preferredHeight: 16 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Column {
                Layout.alignment: Qt.AlignTop
                Repeater {
                    model: 5
                    Txt {
                        required property int index
                        readonly property real top: Math.max(1024, Math.max.apply(null, Sys.netHistory.concat([1])))
                        text: Sys.bytes(top * (4 - index) / 4) + "/s"
                        font.pixelSize: 9
                        color: root.dim
                        height: 14
                    }
                }
            }
            Spark {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                values: Sys.netHistory
                max: Math.max(1024, Math.max.apply(null, Sys.netHistory.concat([1])))
                color: Theme.tertiary
            }
        }
        Stat { label: "Download Rate"; value: Sys.bytes(Sys.rx) + "/s"; tick: Theme.primary }
        Stat { label: "Upload Rate"; value: Sys.bytes(Sys.tx) + "/s"; tick: Theme.tertiary }

        Item { Layout.preferredHeight: 16 }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: Theme.alpha(root.fg, 0.2)
            Rectangle {
                width: parent.width * Sys.disk
                height: parent.height
                radius: 3
                color: Theme.secondary
            }
        }
        Stat { label: "Disk Used"; value: Sys.bytes(Sys.diskUsed) }
        Stat { label: "Total"; value: Sys.bytes(Sys.diskTotal) }

        Item { Layout.preferredHeight: 16 }
        Stat { visible: Sys.cpuTemp >= 0; label: "CPU Temperature"; value: Sys.cpuTemp.toFixed(1) + " °C"; tick: Theme.primary }
        Stat { visible: Sys.gpuTemp >= 0; label: "GPU Temperature"; value: Math.round(Sys.gpuTemp) + " °C"; tick: Theme.tertiary }
        Stat { visible: Sys.power >= 0 && Power.hasBattery; label: Power.charging ? "Charging Rate" : "Power Draw"; value: Sys.power.toFixed(1) + " W"; tick: Theme.secondary }
        Stat { visible: Sys.fan >= 0; label: "Fan Speed"; value: Sys.fan.toLocaleString(Qt.locale(), "f", 0) + " RPM"; tick: Theme.error }
        Stat { visible: Power.hasBattery; label: "Battery"; value: Power.percent + "%"; tick: Theme.success }
    }
}

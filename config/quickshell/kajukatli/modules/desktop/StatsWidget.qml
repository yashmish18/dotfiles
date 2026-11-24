import QtQuick
import QtQuick.Layouts
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

    // Canvas paints on demand instead of binding geometry to width/height. Shape's
    // PathPolyline fed its bounding rect back into the layout, which Qt saw as a
    // binding loop on every stats tick (and rebuilt the path each time).
    component Spark: Canvas {
        id: sp
        property var values: []
        property real max: 1
        property color color: Theme.wallText
        implicitWidth: 0
        implicitHeight: 0
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height, n = values.length;
            ctx.clearRect(0, 0, w, h);
            if (n === 0 || w <= 0 || h <= 0) return;
            ctx.beginPath();
            ctx.moveTo(0, h);
            for (let i = 0; i < n; i++) {
                const x = n > 1 ? i / (n - 1) * w : 0;
                const y = h - Math.min(1, (values[i] || 0) / Math.max(1e-9, max)) * h * 0.92;
                ctx.lineTo(x, y);
            }
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fillStyle = Theme.alpha(color, 0.25);
            ctx.fill();
            ctx.strokeStyle = color;
            ctx.lineWidth = 1.5;
            ctx.lineJoin = "round";
            ctx.stroke();
        }
        onValuesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onMaxChanged: requestPaint()
        onColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
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
                        readonly property real peak: Math.max(1024, Math.max.apply(null, Sys.netHistory.concat([1])))
                        text: Sys.bytes(peak * (4 - index) / 4) + "/s"
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

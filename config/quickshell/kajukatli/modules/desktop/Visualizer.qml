import QtQuick
import QtQuick.Shapes
import qs.services
import qs.components

// the audio visualiser, drawn three ways:
//   wave    a filled, smoothed mountain range (the full-width one along the bottom)
//   bars    thin bars standing on a baseline
//   mirror  bars reflected around the middle, like a recorded waveform
// it asks Cava to run only while it's visible.
Item {
    id: root
    property string style: "bars"
    property int count: Cava.bars         // how many bars to show (resampled from cava)
    property color color: Theme.wallText
    property real fillOpacity: 0.55
    property real gap: 2
    property real minBar: 2
    property bool active: visible

    implicitWidth: 360
    implicitHeight: 64

    Uses { service: Cava; active: root.active && root.width > 0 }

    // cava's bars → `count` values (average when shrinking, interpolate when growing)
    readonly property var vals: {
        const src = Cava.values;
        const n = Math.max(1, count);
        const m = src.length;
        const out = new Array(n);
        if (m === 0) { for (let i = 0; i < n; i++) out[i] = 0; return out; }
        for (let i = 0; i < n; i++) {
            const f = (i + 0.5) / n * m - 0.5;
            const a = Math.max(0, Math.floor(f)), b = Math.min(m - 1, a + 1);
            const t = f - a;
            out[i] = (src[a] || 0) * (1 - t) + (src[b] || 0) * t;
        }
        return out;
    }

    // ---------------------------------------------------------------- bars / mirror
    Row {
        id: barsRow
        visible: root.style === "bars" || root.style === "mirror"
        anchors.fill: parent
        spacing: root.gap
        readonly property real barW: Math.max(1, (root.width - root.gap * (root.count - 1)) / root.count)
        Repeater {
            model: barsRow.visible ? root.count : 0
            delegate: Item {
                required property int index
                width: barsRow.barW
                height: root.height
                readonly property real v: root.vals[index] || 0
                Rectangle {
                    width: parent.width
                    radius: Math.min(width / 2, 2)
                    color: root.color
                    opacity: root.fillOpacity + (1 - root.fillOpacity) * parent.v
                    height: Math.max(root.minBar, parent.v * (root.style === "mirror" ? root.height : root.height))
                    y: root.style === "mirror" ? (root.height - height) / 2 : root.height - height
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }
    }

    // ---------------------------------------------------------------- wave
    readonly property var wavePath: {
        if (style !== "wave") return [];
        const v = vals;
        const n = v.length;
        const w = width, h = height;
        const pts = [Qt.point(0, h)];
        if (n < 2) { pts.push(Qt.point(w, h)); return pts; }
        // catmull-rom through the bar tops, 4 points per segment
        const P = i => Qt.point(i / (n - 1) * w, h - Math.max(0.02, v[Math.max(0, Math.min(n - 1, i))]) * h * 0.95);
        for (let i = 0; i < n - 1; i++) {
            const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
            for (let s = 0; s < 4; s++) {
                const t = s / 4, t2 = t * t, t3 = t2 * t;
                const x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);
                const y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);
                pts.push(Qt.point(x, Math.min(h, y)));
            }
        }
        pts.push(P(n - 1));
        pts.push(Qt.point(w, h));
        return pts;
    }

    Shape {
        visible: root.style === "wave"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.alpha(root.color, 0.9)
            strokeWidth: 2
            joinStyle: ShapePath.RoundJoin
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root.height
                GradientStop { position: 0; color: Theme.alpha(root.color, root.fillOpacity) }
                GradientStop { position: 1; color: Theme.alpha(root.color, root.fillOpacity * 0.35) }
            }
            PathPolyline { path: root.wavePath }
        }
    }
}

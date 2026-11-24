import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.services
import qs.components

// the big clock drawn on the wallpaper. six faces:
//   stack  hours over minutes, huge and centred              (pairs with the depth effect)
//   hero   a heavy hour, minutes and outlined seconds beside it, the date half-hidden
//   serif  a bookish serif time with small seconds and am/pm
//   line   "12:35 am – 09/04" in one long line
//   day    weather · a slanted time chip · the date spaced out · a giant weekday · bars
//   date   a giant day-of-month with the month across it and the time beneath
// sizes follow the screen height, times Config.s.clockScale.
Item {
    id: root
    // "auto": the face kk-prep picked for this wallpaper (stack for a narrow figure or a calm
    // column, hero for a wide one or a calm band)
    property string style: Config.s.clockStyle === "auto"
        ? (Wall.current && Wall.current.clock_auto ? Wall.current.clock_auto.style : "stack")
        : Config.s.clockStyle
    property real screenHeight: 1080
    readonly property real s: (screenHeight / 1080) * Math.max(0.3, Config.s.clockScale)
    readonly property bool h24: Config.s.clock24h
    property bool live: true          // false while windows cover it: no per-second redraws
    readonly property bool needsSeconds: false      // no clock face shows seconds

    implicitWidth: face.item ? face.item.implicitWidth : 0
    transformOrigin: Item.Center
    implicitHeight: face.item ? face.item.implicitHeight : 0

    SystemClock { id: clock; precision: root.needsSeconds ? SystemClock.Seconds : SystemClock.Minutes }
    readonly property date now: clock.date
    // (Qt only counts hours to 12 when the same format also shows am/pm, so "hh" on its own
    // would stay 24-hour: work the 12-hour hour out by hand)
    readonly property int hour12: now.getHours() % 12 === 0 ? 12 : now.getHours() % 12
    readonly property string hh: h24 ? Qt.formatTime(now, "HH") : (hour12 < 10 ? "0" : "") + hour12
    readonly property string hShort: h24 ? Qt.formatTime(now, "HH") : String(hour12)
    readonly property string mm: Qt.formatTime(now, "mm")
    readonly property string ss: Qt.formatTime(now, "ss")
    readonly property string ap: Qt.formatTime(now, "AP")

    Loader {
        id: face
        sourceComponent: {
            switch (root.style) {
            case "stack": return stackC;
            case "hero": return heroC;
            case "serif": return serifC;
            case "line": return lineC;
            case "day": return dayC;
            case "date": return dateC;
            }
            return null;
        }
    }

    // large text: scalable rendering, no eliding, the clock's face
    component Big: Text {
        color: Theme.clockInk
        font.family: Theme.display
        font.weight: Font.Black
        renderType: Text.QtRendering
        textFormat: Text.PlainText
        font.features: ({ "tnum": 1 })
    }

    // hollow letters: a real stroke around each glyph (Text.Outline would fill them in)
    component Outline: Shape {
        id: ol
        property string text: ""
        property real size: 100
        property string family: Theme.display
        property int weight: Font.Black
        property color color: Theme.clockInk
        property real stroke: 2
        preferredRendererType: Shape.CurveRenderer
        implicitWidth: olm.tightBoundingRect.width + stroke * 2 + 2
        implicitHeight: olm.tightBoundingRect.height + stroke * 2 + 2
        TextMetrics {
            id: olm
            text: ol.text
            font.family: ol.family
            font.pixelSize: ol.size
            font.weight: ol.weight
        }
        ShapePath {
            strokeColor: ol.color
            strokeWidth: ol.stroke
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathText {
                x: ol.stroke + 1 - olm.tightBoundingRect.x
                y: ol.stroke + 1
                text: ol.text
                font.family: ol.family
                font.pixelSize: ol.size
                font.weight: ol.weight
            }
        }
    }

    // ------------------------------------------------------------ stack
    Component {
        id: stackC
        Column {
            spacing: -58 * root.s
            Big {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hh
                font.pixelSize: 200 * root.s
                font.weight: Font.Bold
                opacity: 0.92
            }
            Big {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.mm
                font.pixelSize: 200 * root.s
                font.weight: Font.Bold
                opacity: 0.92
            }
        }
    }

    // ------------------------------------------------------------ hero
    Component {
        id: heroC
        Row {
            spacing: 10 * root.s
            Column {
                y: 150 * root.s
                spacing: -12 * root.s
                Big {
                    anchors.right: parent.right
                    text: Qt.formatDate(root.now, "ddd, d").toUpperCase()
                    font.pixelSize: 46 * root.s
                    color: Theme.clockInkDim
                    opacity: 0.85
                }
                Outline {
                    text: Qt.formatDate(root.now, "MMMM").toUpperCase()
                    size: 112 * root.s
                    stroke: 2.2 * root.s
                    opacity: 0.8
                }
            }
            Big {
                text: root.hShort
                font.pixelSize: 330 * root.s
                opacity: 0.82
            }
            Column {
                y: 44 * root.s
                spacing: 6 * root.s
                Big { text: root.mm; font.pixelSize: 130 * root.s; opacity: 0.9; height: implicitHeight * 0.8 }
                Outline {
                    visible: !root.h24
                    text: root.ap
                    size: 130 * root.s
                    stroke: 2.6 * root.s
                    opacity: 0.75
                }
            }
        }
    }

    // ------------------------------------------------------------ serif
    Component {
        id: serifC
        Row {
            spacing: 14 * root.s
            Big {
                text: root.hShort + ":" + root.mm
                font.pixelSize: 260 * root.s
                font.weight: Font.Bold
                font.family: Theme.display
            }
            Column {
                y: 52 * root.s
                spacing: 2 * root.s
                Big {
                    text: root.h24 ? Qt.formatDate(root.now, "ddd").toUpperCase() : root.ap
                    font.pixelSize: 40 * root.s
                    font.weight: Font.Bold
                    font.family: Theme.sans
                    color: Theme.clockInkDim
                    opacity: 0.7
                }
            }
        }
    }

    // ------------------------------------------------------------ line
    Component {
        id: lineC
        Row {
            spacing: 18 * root.s
            Big {
                id: lineTime
                text: root.hShort + ":" + root.mm
                font.pixelSize: 150 * root.s
                font.weight: Font.DemiBold
                opacity: 0.78
            }
            Big {
                visible: !root.h24
                anchors.baseline: lineTime.baseline
                text: root.ap
                font.pixelSize: 44 * root.s
                font.weight: Font.DemiBold
                opacity: 0.78
            }
            Big {
                text: "–"
                font.pixelSize: 150 * root.s
                font.weight: Font.DemiBold
                opacity: 0.6
            }
            Big {
                text: Qt.formatDate(root.now, "MM/dd")
                font.pixelSize: 150 * root.s
                font.weight: Font.DemiBold
                opacity: 0.78
            }
        }
    }

    // ------------------------------------------------------------ day
    Component {
        id: dayC
        Column {
            spacing: 4 * root.s
            Uses { service: Weather }

            Row {
                spacing: 22 * root.s
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon
                    size: 44 * root.s
                    color: Theme.clockInk
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Big {
                        text: Weather.ready ? Weather.temp + "°" : "—"
                        font.pixelSize: 44 * root.s
                        font.weight: Font.Medium
                        font.family: Theme.sans
                    }
                    Big {
                        visible: Weather.ready
                        text: "↑" + Weather.high + "°  ↓" + Weather.low + "°"
                        font.pixelSize: 15 * root.s
                        font.weight: Font.Medium
                        font.family: Theme.sans
                        color: Theme.clockInkDim
                    }
                    Big {
                        text: Weather.desc
                        font.pixelSize: 17 * root.s
                        font.weight: Font.Medium
                        font.family: Theme.sans
                        color: Theme.clockInkDim
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2 * root.s
                    height: 96 * root.s
                    rotation: 22
                    antialiasing: true
                    color: Theme.clockInk
                    opacity: 0.8
                }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 210 * root.s
                    height: 54 * root.s
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.clockInk
                        antialiasing: true
                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.2, 0, 10 * root.s, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    }
                    Big {
                        anchors.centerIn: parent
                        text: root.hShort + ":" + root.mm
                        font.pixelSize: 36 * root.s
                        font.family: Theme.sans
                        font.weight: Font.Black
                        color: Theme.clockShadow
                    }
                }
            }
            Big {
                x: 250 * root.s
                text: Qt.formatDate(root.now, "MMMM d yyyy").toUpperCase()
                font.pixelSize: 14 * root.s
                font.weight: Font.Medium
                font.family: Theme.sans
                font.letterSpacing: 9 * root.s
                color: Theme.clockInkDim
            }
            Item {
                width: dayName.implicitWidth + 160 * root.s
                height: dayName.implicitHeight + 30 * root.s
                Big {
                    id: dayName
                    y: -30 * root.s
                    text: Qt.formatDate(root.now, "ddd").toUpperCase()
                    font.pixelSize: 150 * root.s
                    font.family: Theme.sans
                    font.weight: Font.Black
                }
                Visualizer {
                    x: dayName.implicitWidth * 0.78
                    y: dayName.y + dayName.implicitHeight * 0.78
                    width: 200 * root.s
                    height: 46 * root.s
                    style: "bars"
                    count: 40
                    gap: 1
                    color: Theme.clockInk
                    fillOpacity: 0.7
                }
            }
        }
    }

    // ------------------------------------------------------------ date
    Component {
        id: dateC
        Item {
            implicitWidth: num.implicitWidth
            implicitHeight: num.implicitHeight + 10 * root.s
            Big {
                id: num
                text: Qt.formatDate(root.now, "d")
                font.pixelSize: 250 * root.s
                color: Theme.clockInkDim
                opacity: 0.72
            }
            Big {
                id: month
                anchors.centerIn: num
                anchors.verticalCenterOffset: -12 * root.s
                text: Qt.formatDate(root.now, "MMMM").toUpperCase()
                font.pixelSize: 54 * root.s
                font.family: Theme.sans
                font.weight: Font.Bold
                font.letterSpacing: 2 * root.s
            }
            Big {
                anchors.right: month.left
                anchors.rightMargin: -4 * root.s
                anchors.verticalCenter: month.verticalCenter
                text: Qt.formatDate(root.now, "dddd").toUpperCase()
                rotation: -90
                font.pixelSize: 10 * root.s
                font.family: Theme.sans
                font.weight: Font.Medium
                font.letterSpacing: 3 * root.s
                color: Theme.clockInkDim
                transformOrigin: Item.Right
            }
            Column {
                anchors.horizontalCenter: month.horizontalCenter
                anchors.top: month.bottom
                anchors.topMargin: 6 * root.s
                spacing: 3 * root.s
                Big {
                    id: tm
                    text: root.hShort + ":" + root.mm
                    font.pixelSize: 15 * root.s
                    font.family: Theme.mono
                    font.weight: Font.Medium
                    font.letterSpacing: 2 * root.s
                }
                Rectangle { width: tm.implicitWidth; height: 1; color: Theme.clockInk; opacity: 0.6 }
            }
        }
    }
}

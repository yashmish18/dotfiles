import QtQuick
import qs.services
import qs.components

// every desktop widget, laid out on one screen-sized item. it is used twice per screen:
//
//   behind: false   in the desktop window (above the wallpaper, below your windows)
//   behind: true    inside the wallpaper itself, rendered off-screen and composited by the
//                   wallpaper shader *under* the subject's cut-out — the depth effect
//
// a widget appears in exactly one of the two. the clock and the visualiser can go behind;
// everything you click (calendar, player) is always in front. edit mode brings all of them
// to the front so they can be dragged.
Item {
    id: layer
    property bool behind: false
    property var monitor: null
    // windows over the desktop? then nobody can see the moving parts: pause them (power)
    readonly property bool covered: !Ui.editing && monitor !== null && monitor.activeWorkspace !== null
                                   && monitor.activeWorkspace.toplevels.values.length > 0

    // while you drag or arrange, everything comes to the front so you can see where it goes
    readonly property bool depthOk: Wall.depthReady && !Ui.editing && !Ui.dragging
    readonly property bool clockBehind: Config.s.clockDepth && depthOk
    readonly property bool visBehind: Config.s.visualizerBehind && depthOk
    readonly property string vis: Config.s.visualizer

    readonly property bool hasBars: vis === "bars" || vis === "mirror" || vis === "both"
    readonly property bool hasWave: vis === "wave" || vis === "both"
    // the copy in front is always there to be grabbed; it's only invisible while the one
    // behind the subject is the one you see
    readonly property bool clockHere: Config.s.clockStyle !== "off" && (behind ? clockBehind : true)
    readonly property bool barsHere: hasBars && (behind ? visBehind : true)
    readonly property bool waveHere: hasWave && visBehind === behind
    // anything to draw at all? (the wallpaper skips the composite when not)
    readonly property bool anyHere: clockHere || barsHere || waveHere

    property alias calendarItem: calendar
    property alias mediaItem: media
    property alias noteItem: note
    property alias clockItem: clockM
    property alias barsItem: barsM
    property alias statsItem: statsM
    property alias weatherItem: weatherM
    property alias batteryItem: batteryM
    property alias analogItem: analogM

    // widgets keep clear of the bar (both instances must agree, or the clock would jump
    // when it moves behind the subject)
    readonly property bool barShown: Ui.barVisible && Config.s.barStyle !== "none"
    readonly property int padTop: barShown && Config.s.barStyle !== "rail" && Config.s.barPosition === "top" ? Theme.barHeight + 10 : 0
    readonly property int padBottom: barShown && Config.s.barStyle !== "rail" && Config.s.barPosition === "bottom" ? Theme.barHeight + 10 : 0
    readonly property int padLeft: barShown && Config.s.barStyle === "rail" ? 46 : 0

    // the long wave along the bottom edge
    Visualizer {
        visible: layer.waveHere
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(parent.height * 0.24)
        style: "wave"
        active: visible && !layer.covered
        count: Cava.bars
        color: Theme.wallText
        fillOpacity: 0.5
    }

    Item {
        id: area
        anchors.fill: parent
        anchors.topMargin: layer.padTop
        anchors.bottomMargin: layer.padBottom
        anchors.leftMargin: layer.padLeft

        Movable {
            id: barsM
            name: "bars"
            ghost: !layer.behind && layer.visBehind
            fallback: ({ x: 0.92, y: 0.04 })
            editable: !layer.behind
            shown: layer.barsHere
            Visualizer {
                implicitWidth: layer.vis === "mirror" ? 620 : 320
                implicitHeight: layer.vis === "mirror" ? 160 : 60
                style: layer.vis === "mirror" ? "mirror" : "bars"
            active: visible && !layer.covered
                count: layer.vis === "mirror" ? 96 : 64
                gap: 1
                color: layer.vis === "mirror" ? Theme.primary : Theme.wallText
                fillOpacity: 0.7
            }
        }

        Movable {
            id: clockM
            name: "clock"
            ghost: !layer.behind && layer.clockBehind
            fallback: ({ x: 0.5, y: 0.15 })
            editable: !layer.behind
            shown: layer.clockHere
            DesktopClock { screenHeight: layer.height; live: !layer.covered }
        }

        Movable {
            id: calendar
            name: "calendar"
            fallback: ({ x: 0.02, y: 0.93 })
            shown: !layer.behind && Config.s.showCalendar
            CalendarWidget {}
        }

        Movable {
            id: media
            name: "media"
            fallback: ({ x: 0.5, y: 0.93 })
            shown: !layer.behind && Config.s.mediaWidget !== "off" && Media.active
            MediaWidget { style: Config.s.mediaWidget }
        }

        Movable {
            id: statsM
            name: "stats"
            fallback: ({ x: 0.02, y: 0.7 })
            shown: !layer.behind && Config.s.showStats
            StatsWidget { live: !layer.covered }
        }

        Movable {
            id: weatherM
            name: "weather"
            fallback: ({ x: 0.96, y: 0.1 })
            shown: !layer.behind && Config.s.showWeather
            WeatherWidget {}
        }

        Movable {
            id: batteryM
            name: "battery"
            fallback: ({ x: 0.96, y: 0.4 })
            shown: !layer.behind && Config.s.showBattery && Power.hasBattery
            BatteryWidget {}
        }

        Movable {
            id: analogM
            name: "analog"
            fallback: ({ x: 0.85, y: 0.6 })
            shown: !layer.behind && Config.s.showAnalog
            AnalogClock {}
        }

        Movable {
            id: note
            name: "note"
            fallback: ({ x: 0.96, y: 0.85 })
            shown: !layer.behind && Config.s.showNote
            NoteWidget {}
        }
    }
}

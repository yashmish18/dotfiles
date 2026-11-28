import QtQuick
import qs.services
import qs.components

// right-click on a desktop widget: that widget's own options, in plain words.
// moving and sizing are done by hand: drag the widget, ctrl + scroll over it.
Rectangle {
    id: root
    property string w: ""            // which widget
    signal done()

    readonly property var titles: ({ clock: "Clock", calendar: "Calendar", media: "Now playing", stats: "System stats",
                                     weather: "Weather", battery: "Battery", analog: "Analog clock", note: "Notepad", timer: "Focus timer" })
    readonly property bool autoSpot: { const l = Config.pos(w, null); return !!(l && l.auto); }

    width: 300
    height: col.implicitHeight + 28
    radius: 18
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.outlineVariant

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // clicks stay inside

    function hide() {
        switch (w) {
        case "calendar": Config.s.showCalendar = false; break;
        case "stats": Config.s.showStats = false; break;
        case "weather": Config.s.showWeather = false; break;
        case "battery": Config.s.showBattery = false; break;
        case "analog": Config.s.showAnalog = false; break;
        case "note": Config.s.showNote = false; break;
        case "timer": Config.s.showTimer = false; break;
        case "media": Config.s.mediaWidget = "off"; break;
        case "clock": Config.s.clockStyle = "off"; break;
        }
    }

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 12

        Item {
            width: parent.width
            height: 22
            Txt { anchors.verticalCenter: parent.verticalCenter; text: root.titles[root.w] || "Widget"; font.pixelSize: Theme.md; font.weight: Font.DemiBold }
            Txt {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: Theme.surfaceTextDim
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.done() }
            }
        }

        // ---- clock
        Choice {
            width: parent.width
            visible: root.w === "clock"
            label: "Face"
            options: [{ value: "auto", label: "Picks itself" }, { value: "hero", label: "Big" }, { value: "stack", label: "Stacked" },
                      { value: "serif", label: "Serif" }, { value: "line", label: "One line" }, { value: "day", label: "Day" }, { value: "date", label: "Date" }]
            value: Config.s.clockStyle
            onPicked: v => Config.s.clockStyle = v
        }
        Choice {
            width: parent.width
            visible: root.w === "clock" || root.w === "analog"
            label: "Time"
            options: [{ value: false, label: "12-hour" }, { value: true, label: "24-hour" }]
            value: Config.s.clock24h
            onPicked: v => Config.s.clock24h = v
        }
        Choice {
            width: parent.width
            visible: root.w === "clock"
            label: "Colour"
            options: [{ value: "auto", label: "Whatever reads best" }, { value: "theme", label: "Accent" }]
            value: Config.s.clockColor
            onPicked: v => Config.s.clockColor = v
        }
        Row {
            visible: root.w === "clock"
            width: parent.width
            Txt { width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter; text: "Behind the person in the picture"; font.pixelSize: Theme.sm + 1; wrapMode: Text.WordWrap }
            Switch { on: Config.s.clockDepth; onToggled: Config.s.clockDepth = !Config.s.clockDepth }
        }
        Row {
            visible: root.w === "clock"
            width: parent.width
            Txt { width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter; text: "Find a good spot by itself"; font.pixelSize: Theme.sm + 1; wrapMode: Text.WordWrap }
            Switch {
                on: root.autoSpot
                onToggled: {
                    if (root.autoSpot) { const l = Config.pos("clock", null) || {}; Config.setPos("clock", l.x !== undefined ? l.x : 0.5, l.y !== undefined ? l.y : 0.15); }
                    else Config.setAuto("clock");
                }
            }
        }

        // ---- now playing
        Choice {
            width: parent.width
            visible: root.w === "media"
            label: "Look"
            options: [{ value: "card", label: "Card" }, { value: "lyrics", label: "Lyrics" }, { value: "portrait", label: "Cover" }]
            value: Config.s.mediaWidget
            onPicked: v => Config.s.mediaWidget = v
        }

        // ---- weather
        Choice {
            width: parent.width
            visible: root.w === "weather"
            label: "Temperature in"
            options: [{ value: "c", label: "°C" }, { value: "f", label: "°F" }]
            value: Config.s.tempUnit
            onPicked: v => Config.s.tempUnit = v
        }
        Row {
            visible: root.w === "weather"
            width: parent.width
            Txt { width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter; text: "Rain and snow on the wallpaper"; font.pixelSize: Theme.sm + 1; wrapMode: Text.WordWrap }
            Switch { on: Config.s.weatherFx; onToggled: Config.s.weatherFx = !Config.s.weatherFx }
        }
        Column {
            visible: root.w === "weather"
            width: parent.width
            spacing: 4
            Txt { text: "City"; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
            Field { width: parent.width; size: Theme.md; placeholder: "where you are, e.g. Pune"; text: Config.s.weatherLocation; onAccepted: Config.s.weatherLocation = text.trim() }
        }

        // ---- focus timer
        Choice {
            width: parent.width
            visible: root.w === "timer"
            label: "Focus for"
            options: [15, 25, 45, 60].map(v => ({ value: v, label: v + " min" }))
            value: Config.s.timerMinutes
            onPicked: v => Config.s.timerMinutes = v
        }
        Choice {
            width: parent.width
            visible: root.w === "timer"
            label: "Then a break of"
            options: [5, 10, 15].map(v => ({ value: v, label: v + " min" }))
            value: Config.s.timerBreak
            onPicked: v => Config.s.timerBreak = v
        }

        Txt {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.w === "note" ? "Drag it by the strip at the top. Ctrl + scroll makes it bigger or smaller."
                                    : "Drag it to move it. Ctrl + scroll makes it bigger or smaller."
            font.pixelSize: Theme.sm
            color: Theme.surfaceTextDim
        }

        Row {
            spacing: 8
            Btn { text: "Edit layout"; flat: true; onClicked: { root.done(); Ui.editing = true; } }
            Btn { text: "Hide"; danger: true; flat: true; onClicked: { root.done(); root.hide(); } }
        }
    }
}

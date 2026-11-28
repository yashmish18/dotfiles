import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.modules.panels

// the settings app: a real window, one place for everything. every change applies at once
// and is saved to ~/.config/kajukatli/settings.json.
// open: super + i, right-click the control pill, or `qs -c kajukatli ipc call shell settings`
LazyLoader {
    active: Ui.settingsOpen

    FloatingWindow {
        id: win
        title: "Kajukatli Settings"
        implicitWidth: 1040
        implicitHeight: 720
        color: Theme.background
        onVisibleChanged: if (!visible) Ui.settingsOpen = false

        property string page: Ui.settingsPage || "looks"

        // ------------------------------------------------------------ building blocks
        // a page title with a line under it saying what the page is for
        component Head: ColumnLayout {
            property string title: ""
            property string about: ""
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            spacing: 4
            Txt { text: parent.title; font.pixelSize: 30; font.weight: Font.Bold }
            Txt { visible: parent.about !== ""; text: parent.about; color: Theme.surfaceTextDim; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
        // a group of settings on one card
        component Group: Rectangle {
            id: grp
            property string title: ""
            default property alias rows: body.data
            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + (title !== "" ? 50 : 16)
            radius: Theme.radius + 4
            color: Theme.surfaceLow
            Txt {
                visible: grp.title !== ""
                x: 20; y: 16
                text: grp.title.toUpperCase()
                font.pixelSize: Theme.xs + 1
                font.weight: Font.Bold
                font.letterSpacing: 1.4
                color: Theme.primary
            }
            ColumnLayout {
                id: body
                x: 20
                y: grp.title !== "" ? 42 : 8
                width: grp.width - 40
                spacing: 0
            }
        }
        // one setting: what it is on the left, the control on the right
        component Setting: RowLayout {
            id: row
            property string label: ""
            property string detail: ""
            default property alias control: slot.data
            Layout.fillWidth: true
            Layout.minimumHeight: 56
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt { text: row.label; font.weight: Font.Medium; Layout.fillWidth: true }
                Txt { visible: row.detail !== ""; text: row.detail; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim; wrapMode: Text.WordWrap; Layout.fillWidth: true; elide: Text.ElideNone }
            }
            Item {
                id: slot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            }
        }
        // a slider with its own number, for the right side of a Row
        component Knob: Item {
            id: kn
            property real from: 0
            property real to: 1
            property real value: 0
            property real step: 0.05
            property string suffix: ""
            property int decimals: 2
            signal moved(real v)
            implicitWidth: 260
            implicitHeight: 34
            Slider {
                anchors.fill: parent
                valueText: kn.value.toFixed(kn.step >= 1 ? 0 : kn.step >= 0.1 ? 1 : 2) + kn.suffix
                value: (kn.value - kn.from) / (kn.to - kn.from)
                onMoved: v => {
                    const raw = kn.from + v * (kn.to - kn.from);
                    kn.moved(Math.round(raw / kn.step) * kn.step);
                }
            }
        }

        // ------------------------------------------------------------ layout
        Rectangle {
            anchors.fill: parent
            color: Theme.background

            // sidebar
            Rectangle {
                id: side
                width: 236
                height: parent.height
                color: Theme.surfaceLowest

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    anchors.topMargin: 22
                    spacing: 2

                    RowLayout {
                        Layout.leftMargin: 8
                        Layout.bottomMargin: 18
                        spacing: 10
                        Rectangle {
                            implicitWidth: 34; implicitHeight: 34; radius: 11
                            color: Theme.primary
                            Icon { anchors.centerIn: parent; name: "kitty"; size: 20; color: Theme.primaryText }
                        }
                        ColumnLayout {
                            spacing: 0
                            Txt { text: "Settings"; font.pixelSize: Theme.lg + 1; font.weight: Font.Bold }
                            Txt { text: "kajukatli"; font.family: Theme.mono; font.pixelSize: Theme.xs + 1; color: Theme.outline }
                        }
                    }

                    Repeater {
                        model: [
                            { key: "looks", label: "Looks", icon: "palette" },
                            { key: "bar", label: "Bar", icon: "sliders" },
                            { key: "desktop", label: "Desktop & clock", icon: "grid" },
                            { key: "wallpaper", label: "Wallpaper", icon: "image" },
                            { key: "sep" },
                            { key: "display", label: "Display", icon: "screenshot" },
                            { key: "input", label: "Touchpad & keyboard", icon: "move" },
                            { key: "network", label: "Wi-Fi", icon: "wifi" },
                            { key: "bluetooth", label: "Bluetooth", icon: "bluetooth" },
                            { key: "sound", label: "Sound", icon: "volume" },
                            { key: "power", label: "Power", icon: "bolt" },
                            { key: "notifications", label: "Notifications", icon: "bell" },
                            { key: "behaviour", label: "Behaviour", icon: "grid" },
                            { key: "sep" },
                            { key: "about", label: "About", icon: "kitty" }
                        ]
                        delegate: Item {
                            id: nav
                            required property var modelData
                            readonly property bool on: win.page === modelData.key
                            Layout.fillWidth: true
                            implicitHeight: modelData.key === "sep" ? 18 : 40
                            Rectangle {
                                visible: nav.modelData.key === "sep"
                                anchors.centerIn: parent
                                width: parent.width - 16
                                height: 1
                                color: Theme.alpha(Theme.outlineVariant, 0.6)
                            }
                            Rectangle {
                                visible: nav.modelData.key !== "sep"
                                anchors.fill: parent
                                radius: 20
                                color: nav.on ? Theme.primaryContainer : navArea.containsMouse ? Theme.surfaceContainer : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    Icon { anchors.verticalCenter: parent.verticalCenter; name: nav.modelData.icon || "spark"; size: 16; color: nav.on ? Theme.primaryContainerText : Theme.surfaceTextDim }
                                    Txt { anchors.verticalCenter: parent.verticalCenter; text: nav.modelData.label || ""; font.weight: nav.on ? Font.DemiBold : Font.Normal; color: nav.on ? Theme.primaryContainerText : Theme.surfaceText }
                                }
                                MouseArea {
                                    id: navArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.page = nav.modelData.key
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // the page
            Flickable {
                id: scroller
                anchors.left: side.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                contentWidth: width
                contentHeight: pageLoader.height + 64
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Loader {
                    id: pageLoader
                    x: 40
                    y: 32
                    width: Math.min(scroller.width - 80, 760)
                    sourceComponent: {
                        switch (win.page) {
                        case "looks": return looksP;
                        case "bar": return barP;
                        case "desktop": return desktopP;
                        case "wallpaper": return wallP;
                        case "display": return displayP;
                        case "input": return inputP;
                        case "network": return netP;
                        case "bluetooth": return btP;
                        case "sound": return soundP;
                        case "power": return powerP;
                        case "notifications": return notifP;
                        case "about": return aboutP;
                        case "behaviour": return behaviourP;
                        }
                        return looksP;
                    }
                    onLoaded: scroller.contentY = 0
                }
            }
        }

        // ============================================================ behaviour
        Component {
            id: behaviourP
            ColumnLayout {
                spacing: 18
                Head { title: "Behaviour"; about: "How the desktop reacts. Each of these works the moment you change it." }
                Group {
                    title: "Workspaces"
                    Setting { label: "No gaps"; detail: "Close workspace 3 of 1 2 3 4 and 4 becomes 3. Named workspaces keep their number."
                        Switch { on: Config.s.compactWorkspaces; onToggled: Config.s.compactWorkspaces = !Config.s.compactWorkspaces } }
                    Setting { label: "Go to sign-in pages"; detail: "When a login page (or a link from another app) opens in a browser on another workspace, go there."
                        Switch { on: Config.s.followLogins; onToggled: Config.s.followLogins = !Config.s.followLogins } }
                }
                Group {
                    title: "Keeping things"
                    Setting { label: "Recycle bin"; detail: "Empty what's been there longer than this."
                        Choice { options: [{ value: 7, label: "7 days" }, { value: 30, label: "30 days" }, { value: 0, label: "keep" }]; value: Config.s.trashDays; onPicked: v => Config.s.trashDays = v } }
                    Setting { label: "Screenshots"; detail: "Delete the ones older than this (they're yours: kept by default)."
                        Choice { options: [{ value: 7, label: "7 days" }, { value: 30, label: "30 days" }, { value: 0, label: "keep" }]; value: Config.s.screenshotsDays; onPicked: v => Config.s.screenshotsDays = v } }
                    Setting { label: "Screen recordings"
                        Choice { options: [{ value: 7, label: "7 days" }, { value: 30, label: "30 days" }, { value: 0, label: "keep" }]; value: Config.s.recordingsDays; onPicked: v => Config.s.recordingsDays = v } }
                    Setting { label: "Tidy up now"; detail: "Caches, old packages and logs. Runs by itself every three hours."
                        Btn { text: "Tidy"; onClicked: Quickshell.execDetached([Config.bin + "kk-storage", "tidy"]) } }
                }
                Group {
                    title: "Apps"
                    Setting { label: "One tap on a tray icon opens its menu"; detail: "Everything the app offers, in one tap. Right-click opens the app itself."
                        Switch { on: Config.s.trayTapMenu; onToggled: Config.s.trayTapMenu = !Config.s.trayTapMenu } }
                }
            }
        }

        // ============================================================ looks
        Component {
            id: looksP
            ColumnLayout {
                spacing: 18
                Head { title: "Looks"; about: "A look sets the bar, the clock and the widgets in one go. Change any single piece afterwards; it stays yours." }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: Looks.names
                        delegate: Rectangle {
                            id: tile
                            required property string modelData
                            readonly property bool on: Config.s.look === modelData
                            Layout.fillWidth: true
                            implicitHeight: 92
                            radius: Theme.radius + 2
                            color: on ? Theme.primaryContainer : tileArea.containsMouse ? Theme.surfaceContainer : Theme.surfaceLow
                            border.width: on ? 2 : 0
                            border.color: Theme.primary
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 4
                                Txt { text: tile.modelData.charAt(0).toUpperCase() + tile.modelData.slice(1); font.pixelSize: Theme.lg; font.weight: Font.Bold; color: tile.on ? Theme.primaryContainerText : Theme.surfaceText }
                                Txt { Layout.fillWidth: true; text: Looks.blurbs[tile.modelData] || ""; font.pixelSize: Theme.sm; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; color: tile.on ? Theme.alpha(Theme.primaryContainerText, 0.8) : Theme.surfaceTextDim }
                            }
                            MouseArea { id: tileArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Looks.apply(tile.modelData) }
                        }
                    }
                }
                Group {
                    title: "Colour"
                    Setting {
                        label: "From the wallpaper"
                        detail: "Every colour on the desktop comes from the picture: the shell, borders, terminal, apps."
                        Swatches {}
                    }
                    Setting {
                        label: "Character"
                        detail: "Vibrant follows the picture boldly, tonal softly, mono is black and white with one accent."
                        Choice { options: ["vibrant", "tonal", "mono"]; value: Config.s.themeScheme; onPicked: v => { Config.s.themeScheme = v; Looks.retheme(); } }
                    }
                    Setting {
                        label: "Light or dark"
                        detail: "Auto picks light for bright wallpapers."
                        Choice { options: ["dark", "light", "auto"]; value: Config.s.themeMode; onPicked: v => { Config.s.themeMode = v; Looks.retheme(); } }
                    }
                    Setting {
                        label: "Corner roundness"
                        Knob { from: 4; to: 28; step: 1; value: Config.s.radius; onMoved: v => Config.s.radius = Math.round(v) }
                    }
                }
            }
        }
        component Swatches: Row {
            spacing: 6
            Repeater {
                model: [Theme.primary, Theme.secondary, Theme.tertiary, Theme.primaryContainer, Theme.surfaceHigh]
                Rectangle { required property color modelData; width: 26; height: 26; radius: 13; color: modelData; border.width: 1; border.color: Theme.alpha(Theme.surfaceText, 0.15) }
            }
        }

        // ============================================================ bar
        Component {
            id: barP
            ColumnLayout {
                id: bp
                spacing: 18
                readonly property var all: ["workspaces", "clock", "notifs", "control", "apps", "phone", "tray", "media", "visualizer", "weather", "logo", "volume", "brightness", "network", "bluetooth", "battery", "cpu", "mem", "temp", "power"]
                readonly property var labels: ({ workspaces: "Workspaces", clock: "Clock", notifs: "Notifications", control: "Control pill", apps: "Running apps", phone: "Phone", tray: "Tray", media: "Now playing", visualizer: "Music bars", weather: "Weather", logo: "Logo", volume: "Volume", brightness: "Brightness", network: "Network", bluetooth: "Bluetooth", battery: "Battery", cpu: "CPU", mem: "Memory", temp: "Temperature", power: "Power" })
                property string target: "right"
                function mods(): var { const m = Config.s.barModules || {}; return { left: (m.left || []).slice(), center: (m.center || []).slice(), right: (m.right || []).slice() }; }
                function setMods(m: var) { Config.s.barModules = m; }
                function remove(side: var, i: var) { const m = mods(); m[side].splice(i, 1); setMods(m); }
                function move(side: var, i: var, d: var) { const m = mods(); const a = m[side]; const j = i + d; if (j < 0 || j >= a.length) return; const t = a[i]; a[i] = a[j]; a[j] = t; setMods(m); }
                function add(name: var) { const m = mods(); for (const k of ["left", "center", "right"]) { const i = m[k].indexOf(name); if (i >= 0) m[k].splice(i, 1); } m[target].push(name); setMods(m); }

                Head { title: "Bar"; about: "Its shape, where it sits, and exactly what goes in each part." }
                Group {
                    title: "Shape"
                    Setting { label: "Style"; detail: "Islands: three separate pills. Pill: one capsule. Bar: one long bar. Rail: a strip down the left."
                        Choice { options: ["islands", "pill", "bar", "rail", "none"]; value: Config.s.barStyle; onPicked: v => { Config.s.barStyle = v; Ui.barVisible = v !== "none"; } } }
                    Setting { label: "Edge"; visible: Config.s.barStyle !== "rail" && Config.s.barStyle !== "none"
                        Choice { options: ["top", "bottom"]; value: Config.s.barPosition; onPicked: v => Config.s.barPosition = v } }
                    Setting { label: "Workspaces look like"
                        Choice { options: ["dots", "diamonds", "numbers"]; value: Config.s.workspaceStyle; onPicked: v => Config.s.workspaceStyle = v } }
                }
                Group {
                    title: "What's in it"
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 10
                        Repeater {
                            model: [{ k: "left", t: "Left" }, { k: "center", t: "Middle" }, { k: "right", t: "Right" }]
                            delegate: Rectangle {
                                id: col
                                required property var modelData
                                readonly property bool aim: bp.target === modelData.k
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                implicitHeight: colBody.implicitHeight + 24
                                radius: Theme.radius
                                color: Theme.surfaceContainer
                                border.width: aim ? 2 : 0
                                border.color: Theme.primary
                                ColumnLayout {
                                    id: colBody
                                    x: 12; y: 12
                                    width: parent.width - 24
                                    spacing: 6
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Txt { text: col.modelData.t; font.weight: Font.Bold; Layout.fillWidth: true }
                                        Btn { text: col.aim ? "adding here" : "add here"; active: col.aim; size: Theme.xs + 1; implicitHeight: 24; onClicked: bp.target = col.modelData.k }
                                    }
                                    Repeater {
                                        model: (Config.s.barModules || {})[col.modelData.k] || []
                                        delegate: Rectangle {
                                            id: chip
                                            required property string modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            implicitHeight: 36
                                            radius: 18
                                            color: Theme.surfaceHigh
                                            Txt { x: 14; anchors.verticalCenter: parent.verticalCenter; text: bp.labels[chip.modelData] || chip.modelData; font.pixelSize: Theme.sm }
                                            Row {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                Btn { icon: "left"; flat: true; implicitWidth: 26; implicitHeight: 26; onClicked: bp.move(col.modelData.k, chip.index, -1) }
                                                Btn { icon: "right"; flat: true; implicitWidth: 26; implicitHeight: 26; onClicked: bp.move(col.modelData.k, chip.index, 1) }
                                                Btn { icon: "close"; flat: true; implicitWidth: 26; implicitHeight: 26; onClicked: bp.remove(col.modelData.k, chip.index) }
                                            }
                                        }
                                    }
                                    Txt { visible: ((Config.s.barModules || {})[col.modelData.k] || []).length === 0; text: "empty"; color: Theme.outline; font.pixelSize: Theme.sm }
                                }
                            }
                        }
                    }
                    Txt { Layout.topMargin: 14; text: "Add to the " + (bp.target === "center" ? "middle" : bp.target) + ":"; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 12
                        spacing: 6
                        Repeater {
                            model: bp.all
                            Btn { required property string modelData; text: "+ " + (bp.labels[modelData] || modelData); size: Theme.sm; onClicked: bp.add(modelData) }
                        }
                    }
                }
            }
        }

        // ============================================================ desktop
        Component {
            id: desktopP
            ColumnLayout {
                spacing: 18
                Head { title: "Desktop & clock"; about: "The big clock on the wallpaper, the music visualiser, and the widgets." }
                Group {
                    title: "Clock"
                    Setting { label: "Face"
                        Choice { options: [{ value: "auto", label: "Picks itself" }, { value: "hero", label: "Big" }, { value: "stack", label: "Stacked" }, { value: "serif", label: "Serif" }, { value: "line", label: "One line" }, { value: "day", label: "Day" }, { value: "date", label: "Date" }, { value: "off", label: "Off" }]; value: Config.s.clockStyle; onPicked: v => Config.s.clockStyle = v } }
                    Setting { label: "Typeface"
                        Choice { options: ["Syne", "Unbounded", "Anton", "Fraunces", "Instrument Serif", "Bricolage Grotesque", "DM Mono"]; value: Config.s.clockFont; onPicked: v => Config.s.clockFont = v } }
                    Setting { label: "Time"
                        Choice { options: [{ value: false, label: "12-hour" }, { value: true, label: "24-hour" }]; value: Config.s.clock24h; onPicked: v => Config.s.clock24h = v } }
                    Setting { label: "Colour"
                        Choice { options: [{ value: "auto", label: "Whatever reads best" }, { value: "theme", label: "Accent" }]; value: Config.s.clockColor; onPicked: v => Config.s.clockColor = v } }
                    Setting { label: "Behind the person in the picture"; detail: "Works on pictures with a clear person or object in front."
                        Switch { on: Config.s.clockDepth; onToggled: Config.s.clockDepth = !Config.s.clockDepth } }
                    Setting { label: "Find a good spot by itself"
                        Switch { on: !!Config.pos("clock", {}).auto; onToggled: { const l = Config.pos("clock", { x: 0.5, y: 0.15 }); if (l.auto) Config.setPos("clock", l.x, l.y); else Config.setAuto("clock"); } } }
                }
                Group {
                    title: "Music bars"
                    Setting { label: "Show"; detail: "Right-click the bars on the desktop for their shape, place, number, spacing and roundness."
                        Choice { options: [{ value: "off", label: "Off" }, { value: "bars", label: "Bars" }, { value: "wave", label: "Wave" }, { value: "mirror", label: "Mirrored" }, { value: "both", label: "Wave + bars" }]; value: Config.s.visualizer; onPicked: v => Config.s.visualizer = v } }
                    Setting { label: "Colour"
                        Choice { options: [{ value: "wallpaper", label: "From the wallpaper" }, { value: "accent", label: "Accent" }, { value: "album", label: "From the album" }, { value: "rainbow", label: "Rainbow" }]; value: Config.s.visualizerColor; onPicked: v => Config.s.visualizerColor = v } }
                    Setting { label: "How solid"; detail: "Lower lets the wallpaper show through."
                        Slider { implicitWidth: 220; value: (Config.s.visualizerOpacity - 0.1) / 0.9; valueText: Math.round(Config.s.visualizerOpacity * 100) + "%"; onMoved: v => Config.s.visualizerOpacity = Math.round((0.1 + v * 0.9) * 100) / 100 } }
                    Setting { label: "Movement"
                        Choice { options: [{ value: 20, label: "Snappy" }, { value: 60, label: "Normal" }, { value: 140, label: "Smooth" }]; value: Config.s.visualizerSmooth; onPicked: v => Config.s.visualizerSmooth = v } }
                    Setting { label: "Behind the person in the picture"
                        Switch { on: Config.s.visualizerBehind; onToggled: Config.s.visualizerBehind = !Config.s.visualizerBehind } }
                }
                Group {
                    title: "Music fun"
                    Setting { label: "Bouncing clock"; detail: "The clock kicks on every beat."
                        Switch { on: Config.s.musicPulse; onToggled: Config.s.musicPulse = !Config.s.musicPulse } }
                    Setting { label: "Sparks"; detail: "A burst off the music bars on every beat."
                        Switch { on: Config.s.musicSparks; onToggled: Config.s.musicSparks = !Config.s.musicSparks } }
                    Setting { label: "Edge glow"; detail: "The screen edges flash in the album's colour on the beat."
                        Switch { on: Config.s.musicGlow; onToggled: Config.s.musicGlow = !Config.s.musicGlow } }
                    Setting { label: "Album colours"; detail: "While music plays, the desktop takes the cover's colour."
                        Switch { on: Config.s.musicTint; onToggled: Config.s.musicTint = !Config.s.musicTint } }
                }
                Group {
                    title: "Now playing"
                    Setting { label: "Show"; detail: "Only while something plays."
                        Choice { options: [{ value: "off", label: "Off" }, { value: "card", label: "Card" }, { value: "lyrics", label: "Lyrics" }, { value: "portrait", label: "Cover" }]; value: Config.s.mediaWidget; onPicked: v => Config.s.mediaWidget = v } }
                    Setting { label: "Lyrics"; detail: "From " + Config.s.localLyricsDir + ", and online if you allow it below."
                        Switch { on: Config.s.lyrics; onToggled: Config.s.lyrics = !Config.s.lyrics } }
                    Setting { label: "Find lyrics online"; detail: "Sends the song's title and artist to lrclib.net."
                        Switch { on: Config.s.networkLyrics; onToggled: Config.s.networkLyrics = !Config.s.networkLyrics } }
                }
                Group {
                    title: "Weather"
                    Setting { label: "Show"
                        Switch { on: Config.s.showWeather; onToggled: Config.s.showWeather = !Config.s.showWeather } }
                    Setting { label: "Temperature in"
                        Choice { options: [{ value: "c", label: "°C" }, { value: "f", label: "°F" }]; value: Config.s.tempUnit; onPicked: v => Config.s.tempUnit = v } }
                    Setting { label: "Rain and snow on the wallpaper"; detail: "When it's falling where you are."
                        Switch { on: Config.s.weatherFx; onToggled: Config.s.weatherFx = !Config.s.weatherFx } }
                    Setting { label: "Get the weather online"; detail: "Sends your city (or your rough location) to wttr.in."
                        Switch { on: Config.s.networkWeather; onToggled: Config.s.networkWeather = !Config.s.networkWeather } }
                    Setting { label: "City"; detail: "Leave empty to guess."
                        Field { implicitWidth: 220; size: Theme.md; placeholder: "e.g. Pune"; text: Config.s.weatherLocation; onAccepted: Config.s.weatherLocation = text.trim() } }
                }
                Group {
                    title: "Focus timer"
                    Setting { label: "Show"
                        Switch { on: Config.s.showTimer; onToggled: Config.s.showTimer = !Config.s.showTimer } }
                    Setting { label: "Focus for"
                        Choice { options: [15, 25, 45, 60].map(v => ({ value: v, label: v + " min" })); value: Config.s.timerMinutes; onPicked: v => Config.s.timerMinutes = v } }
                    Setting { label: "Then a break of"
                        Choice { options: [5, 10, 15].map(v => ({ value: v, label: v + " min" })); value: Config.s.timerBreak; onPicked: v => Config.s.timerBreak = v } }
                }
                Group {
                    title: "Notepad"
                    Setting { label: "Show"
                        Switch { on: Config.s.showNote; onToggled: Config.s.showNote = !Config.s.showNote } }
                }
                Group {
                    title: "Calendar"
                    Setting { label: "Show"
                        Switch { on: Config.s.showCalendar; onToggled: Config.s.showCalendar = !Config.s.showCalendar } }
                }
                Group {
                    title: "System stats"
                    Setting { label: "Show"
                        Switch { on: Config.s.showStats; onToggled: Config.s.showStats = !Config.s.showStats } }
                }
                Group {
                    title: "Battery"
                    Setting { label: "Show"
                        Switch { on: Config.s.showBattery; onToggled: Config.s.showBattery = !Config.s.showBattery } }
                }
                Group {
                    title: "Analog clock"
                    Setting { label: "Show"
                        Switch { on: Config.s.showAnalog; onToggled: Config.s.showAnalog = !Config.s.showAnalog } }
                }
                Group {
                    title: "Desktop"
                    Setting { label: "Hot corners"; detail: "Top left: every workspace. Bottom right: the desktop, and back."
                        Switch { on: Config.s.hotCorners; onToggled: Config.s.hotCorners = !Config.s.hotCorners } }
                    Setting { label: "Put every widget back"; detail: "Where and how big they started."
                        Btn { text: "Put back"; onClicked: Config.resetLayout() } }
                }
            }
        }

        // ============================================================ dock
        // ============================================================ wallpaper
        Component {
            id: wallP
            ColumnLayout {
                spacing: 18
                Head { title: "Wallpaper"; about: "Every switch is inked in: traced first, then filled. The subject cut-out is worked out quietly afterwards." }
                Group {
                    Setting { label: "Choose a wallpaper"; detail: Wall.current ? Wall.current.name : ""
                        RowLayout { spacing: 6
                            Btn { text: Wall.fetching ? "Getting…" : "Get anime ones"; icon: "download"; enabled: !Wall.fetching; onClicked: Wall.fetchAnime() }
                            Btn { text: "Surprise me"; icon: "shuffle"; onClicked: Wall.random() }
                            Btn { text: "Browse"; icon: "image"; primary: true; onClicked: { Ui.settingsOpen = false; Ui.toggleOverlay("wallpapers"); } } } }
                    Setting { label: "Folder"
                        Field { implicitWidth: 260; size: Theme.md; text: Config.s.wallpaperDir; onAccepted: { Config.s.wallpaperDir = text.trim(); Wall.refreshLibrary(); } } }
                    Setting { label: "A new one by itself"
                        Choice { options: [{ value: "off", label: "never" }, { value: "hourly", label: "every hour" }, { value: "daily", label: "every day" }]; value: Config.s.wallRotate; onPicked: v => Config.s.wallRotate = v } }
                }
                Group {
                    title: "Depth"
                    Setting { label: "3d parallax"; detail: "Switching workspaces moves the camera through the picture."
                        Switch { on: Config.s.parallax; onToggled: Config.s.parallax = !Config.s.parallax } }
                    Setting { label: "Follow the pointer"; visible: Config.s.parallax
                        Switch { on: Config.s.cursorParallax; onToggled: Config.s.cursorParallax = !Config.s.cursorParallax } }
                    Setting { label: "How much it moves"; visible: Config.s.parallax
                        Knob { from: 0.2; to: 2; step: 0.1; value: Config.s.parallaxStrength; onMoved: v => Config.s.parallaxStrength = v } }
                    Setting { label: "Subject in this wallpaper"; detail: Wall.subjectStatus + (Wall.aiMissing ? " · ./install.sh --ai" : "")
                            + (!Config.s.clockDepth ? " · the clock is set to stay in front" : Ui.editing ? " · arrange mode is on" : Ui.dragging ? " · a widget drag is in progress" : "") }
                    Setting { label: "Find the subject again"; detail: "If the clock hides behind the wrong thing."
                        RowLayout { spacing: 6
                            Btn { text: "Drawn art"; onClicked: Wall.redetect("isnet-anime") }
                            Btn { text: "Photo"; onClicked: Wall.redetect("birefnet-general-lite") } } }
                    Setting { label: "Work on battery too"; detail: "Otherwise the subject detection waits for the charger."
                        Switch { on: Config.s.aiOnBattery; onToggled: Config.s.aiOnBattery = !Config.s.aiOnBattery } }
                    Setting { label: "Live wallpapers on battery"
                        Switch { on: Config.s.videoOnBattery; onToggled: Config.s.videoOnBattery = !Config.s.videoOnBattery } }
                }
            }
        }

        // ============================================================ display
        Component {
            id: displayP
            ColumnLayout {
                spacing: 18
                Head { title: "Display"; about: "Everything is 100% unless you change it here." }
                Repeater {
                    model: Hyprland.monitors.values
                    delegate: Group {
                        id: mon
                        required property var modelData
                        readonly property var info: modelData.lastIpcObject || ({})
                        // the refresh rates this screen really offers at its current size (from the
                        // modes it reports), never a made-up list
                        readonly property var rates: {
                            const seen = {}, out = [];
                            for (const m of (info.availableModes || [])) {
                                const r = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(m);
                                if (!r || +r[1] !== info.width || +r[2] !== info.height) continue;
                                const hz = Math.round(parseFloat(r[3]));
                                if (!seen[hz]) { seen[hz] = true; out.push(hz); }
                            }
                            out.sort((x, y) => y - x);
                            return out;
                        }
                        title: modelData.name
                        Setting {
                            label: "Scale"
                            detail: (mon.info.width ? mon.info.width + " × " + mon.info.height : "") + (mon.info.refreshRate ? " · " + Math.round(mon.info.refreshRate) + " Hz" : "")
                            Choice {
                                options: [{ value: 1, label: "100%" }, { value: 1.25, label: "125%" }, { value: 1.5, label: "150%" }, { value: 1.75, label: "175%" }, { value: 2, label: "200%" }]
                                value: System.scaleOf(mon.modelData.name)
                                onPicked: v => System.setScale(mon.modelData.name, v)
                            }
                        }
                        Setting {
                            label: "Refresh"
                            Choice {
                                options: [{ value: 0, label: "Preferred" }].concat(mon.rates.map(r => ({ value: r, label: r + " Hz" })))
                                value: System.monitorProfile(mon.modelData.name).refresh || 0
                                onPicked: v => System.setMonitorProfile(mon.modelData.name, "refresh", v)
                            }
                        }
                        Setting {
                            label: "Position"
                            Choice {
                                options: [{ value: "auto", label: "Automatic" }, { value: "0x0", label: "Primary" }, { value: "auto-right", label: "Right" }, { value: "auto-left", label: "Left" }]
                                value: System.monitorProfile(mon.modelData.name).position || "auto"
                                onPicked: v => System.setMonitorProfile(mon.modelData.name, "position", v)
                            }
                        }
                    }
                }
                Group {
                    id: gpuGroup
                    title: "Graphics"
                    visible: Gpu.hybrid
                    // which card draws the desktop, the nvidia card on or off, which apps use it
                    readonly property string ports: (Gpu.info.dgpuPorts || []).join(", ")
                    Component.onCompleted: Gpu.refresh()
                    Setting {
                        label: "Desktop runs on"
                        detail: (gpuGroup.ports !== "" ? "Ports wired to the NVIDIA card: " + gpuGroup.ports + ". " : "")
                            + "Integrated only: best battery" + (gpuGroup.ports !== "" ? ", those ports stay dark" : "")
                            + ". Both: every port works. NVIDIA: everything on the fast card, the most power. Applies at the next login."
                        Choice {
                            options: [{ value: "igpu", label: "integrated only" }, { value: "both", label: "integrated + nvidia" }, { value: "nvidia", label: "nvidia only" }]
                            value: Gpu.mode === "all" ? "both" : Gpu.mode
                            enabled: Gpu.powered
                            onPicked: v => Gpu.setMode(v)
                        }
                    }
                    Setting {
                        label: "NVIDIA card"
                        detail: !Gpu.powered ? "Off: no power at all, until you switch it on or reboot."
                              : Gpu.name + " · " + (Gpu.runtime === "suspended" ? "asleep" : "awake")
                              + (Gpu.running !== "igpu" ? ". The desktop itself draws with it: pick integrated only and log out first."
                                 : Gpu.users.length ? ". On it now: " + Gpu.users.join(", ") + ". Switching it off moves them to the integrated graphics (they restart)."
                                 : ". Nothing is using it: it can go off completely.")
                        Switch {
                            on: Gpu.powered
                            enabled: !Gpu.powered || Gpu.running === "igpu"
                            onToggled: Gpu.setPower(!Gpu.powered)
                        }
                    }
                    Setting {
                        visible: Gpu.users.length > 0
                        label: "Apps on the NVIDIA card"
                        detail: Gpu.users.join(", ") + ". Close them all to free the card (save your work first; nothing reopens)."
                        Btn { text: "Close them all"; danger: true; onClicked: Gpu.freeCard() }
                    }
                    Setting {
                        visible: Gpu.message !== ""
                        label: Gpu.message
                    }
                    Setting {
                        visible: Gpu.running !== "" && Gpu.running !== (Gpu.mode === "all" ? "all" : Gpu.mode)
                        label: "Takes effect at the next login"
                        detail: "Saved, but this session still uses " + (Gpu.running === "nvidia" ? "the NVIDIA card." : Gpu.running === "both" ? "both cards." : "the integrated card only.")
                        Btn { text: "Log out now"; icon: "logout"; onClicked: Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null && exec hyprshutdown; exec hyprctl dispatch 'hl.dsp.exit()'"]) }
                    }
                    Setting {
                        label: "Notice heavy apps"
                        detail: "When one opens on the integrated card anyway, offer to restart it on NVIDIA."
                        Switch { on: Config.s.gpuHint; onToggled: Config.s.gpuHint = !Config.s.gpuHint }
                    }
                }
                Group {
                    title: "Night light"
                    Setting { label: "On"; Switch { on: Power.nightLight; onToggled: Power.nightLight = !Power.nightLight } }
                    Setting { label: "By itself"; detail: Config.s.nightLightAuto ? "Warm from " + Config.s.nightLightFrom + " to " + Config.s.nightLightTo + ". Type a time, enter." : "Off."
                        RowLayout { spacing: 6
                            Field { visible: Config.s.nightLightAuto; implicitWidth: 74; size: Theme.md; mono: true; text: Config.s.nightLightFrom; onAccepted: if (/^\d{1,2}:\d\d$/.test(text.trim())) Config.s.nightLightFrom = text.trim() }
                            Field { visible: Config.s.nightLightAuto; implicitWidth: 74; size: Theme.md; mono: true; text: Config.s.nightLightTo; onAccepted: if (/^\d{1,2}:\d\d$/.test(text.trim())) Config.s.nightLightTo = text.trim() }
                            Switch { on: Config.s.nightLightAuto; onToggled: Config.s.nightLightAuto = !Config.s.nightLightAuto } } }
                    Setting { label: "Warmth"; detail: Config.s.nightLightTemp + " K"
                        Knob { from: 2500; to: 6000; step: 100; value: Config.s.nightLightTemp; onMoved: v => Config.s.nightLightTemp = Math.round(v) } }
                }
                Group {
                    title: "Accessibility"
                    Setting { label: "Larger text"; Switch { on: Config.s.largeText; onToggled: Config.s.largeText = !Config.s.largeText } }
                    Setting { label: "Reduced motion"; Switch { on: Config.s.reducedMotion; onToggled: Config.s.reducedMotion = !Config.s.reducedMotion } }
                    Setting { label: "High contrast"; Switch { on: Config.s.highContrast; onToggled: Config.s.highContrast = !Config.s.highContrast } }
                }
            }
        }

        // ============================================================ input
        Component {
            id: inputP
            ColumnLayout {
                spacing: 18
                Head { title: "Touchpad & keyboard"; about: "Applied the moment you change them, and every time you log in." }
                Group {
                    title: "Touchpad"
                    Setting { label: "Tap to click"; Switch { on: Config.s.tapToClick; onToggled: { Config.s.tapToClick = !Config.s.tapToClick; System.applyInput(); } } }
                    Setting { label: "Natural scrolling"; detail: "Content follows your fingers."
                        Switch { on: Config.s.naturalScroll; onToggled: { Config.s.naturalScroll = !Config.s.naturalScroll; System.applyInput(); } } }
                    Setting { label: "Two-finger click is right click"
                        Switch { on: Config.s.clickFinger; onToggled: { Config.s.clickFinger = !Config.s.clickFinger; System.applyInput(); } } }
                    Setting { label: "Ignore the touchpad while typing"
                        Switch { on: Config.s.disableWhileTyping; onToggled: { Config.s.disableWhileTyping = !Config.s.disableWhileTyping; System.applyInput(); } } }
                    Setting { label: "Scroll speed"
                        Knob { from: 0.1; to: 2; step: 0.1; value: Config.s.scrollFactor; onMoved: v => { Config.s.scrollFactor = v; System.applyInput(); } } }
                    Setting { label: "Pointer speed"
                        Knob { from: -1; to: 1; step: 0.05; value: Config.s.pointerSpeed; onMoved: v => { Config.s.pointerSpeed = v; System.applyInput(); } } }
                }
                Group {
                    title: "Gestures"
                    Setting { label: "4 fingers sideways"; detail: "Previous / next workspace." }
                    Setting { label: "4 fingers up"; detail: "Every workspace and its windows. Drag windows between them, or onto “new”." }
                    Setting { label: "4 fingers down"; detail: "Close whatever is open." }
                }
                Group {
                    title: "Keyboard"
                    Setting { label: "Layout"
                        Choice { options: [{ value: "us", label: "English (US)" }, { value: "gb", label: "English (UK)" }, { value: "in", label: "Hindi" }, { value: "de", label: "German" }, { value: "fr", label: "French" }, { value: "es", label: "Spanish" }, { value: "ru", label: "Russian" }]; value: Config.s.kbLayout; onPicked: v => { Config.s.kbLayout = v; System.applyInput(); } } }
                    Setting { label: "Repeat rate"; detail: Config.s.repeatRate + " per second"
                        Knob { from: 10; to: 60; step: 1; value: Config.s.repeatRate; onMoved: v => { Config.s.repeatRate = Math.round(v); System.applyInput(); } } }
                    Setting { label: "Repeat delay"; detail: Config.s.repeatDelay + " ms"
                        Knob { from: 150; to: 700; step: 10; value: Config.s.repeatDelay; onMoved: v => { Config.s.repeatDelay = Math.round(v); System.applyInput(); } } }
                    Setting { label: "Every shortcut"
                        Btn { text: "Show keys"; onClicked: { Ui.settingsOpen = false; Ui.toggleOverlay("cheatsheet"); } } }
                }
            }
        }

        // ============================================================ network · bluetooth · sound (the control center's pages)
        Component { id: netP; ColumnLayout { spacing: 18; Head { title: "Wi-Fi" } Group { ControlPanel { Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 12; page: "wifi" } } } }
        Component { id: btP; ColumnLayout { spacing: 18; Head { title: "Bluetooth" } Group { ControlPanel { Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 12; page: "bluetooth" } } } }
        Component {
            id: soundP
            ColumnLayout {
                id: sp
                spacing: 18
                property string outputName: ""
                property int channels: 0
                property bool passthrough: false   // e-ac-3 / truehd to an hdmi receiver
                property bool haveEffects: false
                Process {
                    running: true
                    command: ["sh", "-c", "d=$(pactl get-default-sink 2>/dev/null); pactl -f json list sinks 2>/dev/null | jq -c --arg d \"$d\" '.[] | select(.name == $d) | { desc: .description, map: .channel_map, formats: ([.formats[]?] | join(\" \")) }'; command -v easyeffects >/dev/null && echo EFFECTS"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            for (const line of text.trim().split("\n")) {
                                if (line === "EFFECTS") { sp.haveEffects = true; continue; }
                                try {
                                    const j = JSON.parse(line);
                                    sp.outputName = j.desc || "";
                                    sp.channels = (j.map || "").split(",").filter(x => x).length;
                                    sp.passthrough = /eac3|truehd/.test(j.formats || "");
                                } catch (e) {}
                            }
                        }
                    }
                }
                Head { title: "Sound" }
                Group { ControlPanel { Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 12; page: "sound" } }
                Group {
                    title: "Desktop sounds"
                    Setting { label: "Little sounds"; detail: "Volume, notifications, lock, screenshots, a new wallpaper."
                        Switch { on: Config.s.sounds; onToggled: { Config.s.sounds = !Config.s.sounds; if (Config.s.sounds) Sounds.play("notify", 0); } } }
                    Setting { label: "How loud"; visible: Config.s.sounds
                        Knob { from: 0.1; to: 1; step: 0.05; value: Config.s.soundVolume; onMoved: v => { Config.s.soundVolume = v; Sounds.play("tick", 120); } } }
                }
                Group {
                    title: "Surround & Dolby Atmos"
                    Setting { label: "This output"; detail: sp.outputName + (sp.channels ? "  ·  " + (sp.channels === 2 ? "stereo" : sp.channels === 6 ? "5.1" : sp.channels === 8 ? "7.1" : sp.channels + " channels") : "") }
                    Setting {
                        label: "Dolby Atmos"
                        detail: sp.passthrough ? "Your receiver can decode it: turn on passthrough (E-AC-3 / TrueHD) for this output in the mixer."
                                               : "Not on this output. Linux has no Atmos decoder."
                        Btn { visible: sp.passthrough; text: "Mixer"; icon: "external"; onClicked: Quickshell.execDetached(["pavucontrol", "-t", "3"]) }
                    }
                    Setting {
                        label: "Equalizer"
                        detail: Eq.on ? Eq.presetLabel + " is on." : "Off."
                        Btn { text: "Open"; icon: "sliders"; onClicked: { Ui.settingsOpen = false; Ui.overlay = "equalizer"; } }
                    }
                }
            }
        }

        // ============================================================ power
        Component {
            id: powerP
            ColumnLayout {
                spacing: 18
                Head { title: "Power"; about: Power.hasBattery ? Power.percent + "% · " + (Power.charging ? "charging" : Power.onBattery ? "on battery" : "plugged in") : "plugged in" }
                Group {
                    Setting { label: "Mode"
                        Choice { options: Power.hasPerformance ? ["saver", "balanced", "performance"] : ["saver", "balanced"]; value: Power.profileName; onPicked: v => Power.setProfile(v) } }
                    Setting { label: "Saver when unplugged"; detail: "Back to balanced on the charger."
                        Switch { on: Config.s.autoPowerProfile; onToggled: Config.s.autoPowerProfile = !Config.s.autoPowerProfile } }
                    Setting { label: "Stay awake"; detail: "Don't dim, lock or sleep."
                        Switch { on: Power.caffeine; onToggled: Power.caffeine = !Power.caffeine } }
                }
                Group {
                    title: "Battery saver"
                    visible: Power.hasBattery
                    Uses { service: Battery }
                    Setting { label: "Right now"; detail: Power.onBattery ? (Battery.watts > 0 ? Battery.watts.toFixed(1) + " W from the battery" : "measuring…") : "on the charger" }
                    Setting { label: "When unplugged"; detail: "60 Hz screen, cached blur, no shadows, a lighter visualizer. Back to normal on the charger."
                        Switch { on: Config.s.batterySaver; onToggled: Config.s.batterySaver = !Config.s.batterySaver } }
                }
                Group {
                    title: "Battery"
                    visible: Power.hasBattery
                    Setting {
                        label: "Charge limit"
                        detail: !Battery.limitSupported ? "This laptop doesn't let the system set one."
                              : "Stops charging at this level. 80% keeps the battery healthy for years."
                        Choice {
                            enabled: Battery.limitSupported
                            options: [{ value: 100, label: "off" }, { value: 90, label: "90%" }, { value: 80, label: "80%" }, { value: 60, label: "60%" }]
                            value: Config.s.chargeLimit
                            onPicked: v => Battery.setLimit(v)
                        }
                    }
                    Setting { label: "Health"; detail: Battery.health < 0 ? "unknown" : Math.round(Battery.health * 100) + "% of its original capacity" + (Battery.cycles >= 0 ? " · " + Battery.cycles + " cycles" : "") }
                    // the last day, one dot every ten minutes
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        Layout.topMargin: 6
                        Layout.bottomMargin: 10
                        visible: Battery.history.length > 1
                        Canvas {
                            id: hist
                            anchors.fill: parent
                            property var pts: Battery.history
                            onPtsChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d");
                                c.reset();
                                const n = pts.length;
                                if (n < 2) return;
                                const t0 = Date.now() - 24 * 3600 * 1000;
                                const X = t => (t - t0) / (24 * 3600 * 1000) * width;
                                const Y = p => height - 4 - p / 100 * (height - 8);
                                c.lineWidth = 2;
                                c.strokeStyle = Theme.primary;
                                c.beginPath();
                                for (let i = 0; i < n; i++) {
                                    const x = X(pts[i].t), y = Y(pts[i].p);
                                    if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
                                }
                                c.stroke();
                                c.lineTo(X(pts[n - 1].t), height);
                                c.lineTo(X(pts[0].t), height);
                                c.closePath();
                                c.fillStyle = Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15);
                                c.fill();
                            }
                        }
                        Txt { anchors.left: parent.left; anchors.bottom: parent.bottom; text: "24 h ago"; font.family: Theme.mono; font.pixelSize: Theme.xs; color: Theme.outline }
                        Txt { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "now"; font.family: Theme.mono; font.pixelSize: Theme.xs; color: Theme.outline }
                    }
                }
            }
        }

        // ============================================================ notifications
        Component {
            id: notifP
            ColumnLayout {
                spacing: 18
                Head { title: "Notifications"; about: Notifs.count + " waiting" }
                Group {
                    Setting { label: "Do not disturb"; detail: "Only urgent ones get through."
                        Switch { on: Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd } }
                    Setting { label: "How long they stay"; detail: (Config.s.notificationTimeout / 1000).toFixed(1) + " s"
                        Knob { from: 2000; to: 15000; step: 500; value: Config.s.notificationTimeout; onMoved: v => Config.s.notificationTimeout = Math.round(v) } }
                    Setting { label: "Clear them all"; Btn { text: "Clear"; icon: "trash"; danger: true; onClicked: Notifs.clearAll() } }
                }
            }
        }

        // ============================================================ about
        Component {
            id: aboutP
            ColumnLayout {
                spacing: 18
                Head { title: "About"; about: "A desktop shell for arch + hyprland. Everything here lives in ~/dotfiles." }
                Group {
                    Setting { label: "Restart the shell"; detail: "Picks up changes you made to its files."
                        Btn { text: "Restart"; icon: "restart"; onClicked: Quickshell.reload(true) } }
                }
            }
        }
    }
}

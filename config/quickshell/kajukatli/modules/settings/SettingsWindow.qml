import QtQuick
import QtQuick.Layouts
import Quickshell
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
                            Icon { anchors.centerIn: parent; name: "spark"; size: 18; color: Theme.primaryText }
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
                            { key: "dock", label: "Dock", icon: "apps" },
                            { key: "wallpaper", label: "Wallpaper", icon: "image" },
                            { key: "sep" },
                            { key: "display", label: "Display", icon: "screenshot" },
                            { key: "input", label: "Touchpad & keyboard", icon: "move" },
                            { key: "network", label: "Wi-Fi", icon: "wifi" },
                            { key: "bluetooth", label: "Bluetooth", icon: "bluetooth" },
                            { key: "sound", label: "Sound", icon: "volume" },
                            { key: "power", label: "Power", icon: "bolt" },
                            { key: "notifications", label: "Notifications", icon: "bell" },
                            { key: "sep" },
                            { key: "about", label: "About", icon: "spark" }
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
                        case "dock": return dockP;
                        case "wallpaper": return wallP;
                        case "display": return displayP;
                        case "input": return inputP;
                        case "network": return netP;
                        case "bluetooth": return btP;
                        case "sound": return soundP;
                        case "power": return powerP;
                        case "notifications": return notifP;
                        case "about": return aboutP;
                        }
                        return looksP;
                    }
                    onLoaded: scroller.contentY = 0
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
                readonly property var all: ["workspaces", "clock", "notifs", "control", "tray", "media", "visualizer", "weather", "logo", "volume", "brightness", "network", "bluetooth", "battery", "cpu", "mem", "temp", "power"]
                readonly property var labels: ({ workspaces: "Workspaces", clock: "Clock", notifs: "Notifications", control: "Control pill", tray: "Tray", media: "Now playing", visualizer: "Music bars", weather: "Weather", logo: "Logo", volume: "Volume", brightness: "Brightness", network: "Network", bluetooth: "Bluetooth", battery: "Battery", cpu: "CPU", mem: "Memory", temp: "Temperature", power: "Power" })
                property string target: "right"
                function mods() { const m = Config.s.barModules || {}; return { left: (m.left || []).slice(), center: (m.center || []).slice(), right: (m.right || []).slice() }; }
                function setMods(m) { Config.s.barModules = m; }
                function remove(side, i) { const m = mods(); m[side].splice(i, 1); setMods(m); }
                function move(side, i, d) { const m = mods(); const a = m[side]; const j = i + d; if (j < 0 || j >= a.length) return; const t = a[i]; a[i] = a[j]; a[j] = t; setMods(m); }
                function add(name) { const m = mods(); for (const k of ["left", "center", "right"]) { const i = m[k].indexOf(name); if (i >= 0) m[k].splice(i, 1); } m[target].push(name); setMods(m); }

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
                        Choice { options: ["hero", "stack", "serif", "line", "day", "date", "off"]; value: Config.s.clockStyle; onPicked: v => Config.s.clockStyle = v } }
                    Setting { label: "Typeface"; detail: "Any font installed on the system works; these come with the shell."
                        Choice { options: ["Syne", "Unbounded", "Anton", "Fraunces", "Instrument Serif", "Bricolage Grotesque", "DM Mono"]; value: Config.s.clockFont; onPicked: v => Config.s.clockFont = v } }
                    Setting { label: "Size"
                        Knob { from: 0.4; to: 1.6; step: 0.05; value: Config.s.clockScale; onMoved: v => Config.s.clockScale = Math.round(v * 100) / 100 } }
                    Setting {
                        label: "Where"
                        detail: "Pick a spot, or drag it anywhere with “arrange”."
                        Grid {
                            columns: 3
                            spacing: 4
                            Repeater {
                                model: [[0.04, 0.06], [0.5, 0.06], [0.96, 0.06], [0.04, 0.5], [0.5, 0.45], [0.96, 0.5], [0.04, 0.94], [0.5, 0.92], [0.96, 0.94]]
                                Rectangle {
                                    required property var modelData
                                    readonly property var cur: Config.pos("clock", { x: 0.05, y: 0.1 })
                                    readonly property bool on: Math.abs(cur.x - modelData[0]) < 0.08 && Math.abs(cur.y - modelData[1]) < 0.1
                                    width: 34; height: 22; radius: 6
                                    color: on ? Theme.primary : spot.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
                                    MouseArea { id: spot; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Config.setPos("clock", parent.modelData[0], parent.modelData[1]) }
                                }
                            }
                        }
                    }
                    Setting { label: "Behind the subject"; detail: Wall.depthReady ? "This wallpaper has a subject, so the clock can tuck behind it." : "Needs the wallpaper ai and a picture with a clear figure."
                        Switch { on: Config.s.clockDepth; onToggled: Config.s.clockDepth = !Config.s.clockDepth } }
                    Setting { label: "24-hour time"
                        Switch { on: Config.s.clock24h; onToggled: Config.s.clock24h = !Config.s.clock24h } }
                    Setting { label: "Arrange everything by hand"; detail: "Drag the clock and widgets anywhere (super + shift + e)."
                        Btn { text: "Arrange"; icon: "move"; primary: true; onClicked: { Ui.settingsOpen = false; Ui.editing = true; } } }
                }
                Group {
                    title: "Music visualiser"
                    Setting { label: "Style"; detail: "Wave runs along the bottom of the screen; bars and mirror are a small block you can move."
                        Choice { options: ["off", "wave", "bars", "mirror"]; value: Config.s.visualizer; onPicked: v => Config.s.visualizer = v } }
                    Setting { label: "Behind the subject"; visible: Config.s.visualizer !== "off"
                        Switch { on: Config.s.visualizerBehind; onToggled: Config.s.visualizerBehind = !Config.s.visualizerBehind } }
                    Setting { label: "Detail"; visible: Config.s.visualizer !== "off"
                        Knob { from: 16; to: 96; step: 4; value: Config.s.visualizerBars; onMoved: v => Config.s.visualizerBars = Math.round(v) } }
                }
                Group {
                    title: "Widgets"
                    Setting { label: "Player"; detail: "Shown only while something plays."
                        Choice { options: ["off", "lyrics", "card", "portrait"]; value: Config.s.mediaWidget; onPicked: v => Config.s.mediaWidget = v } }
                    Setting { label: "Synced lyrics"; detail: "Asks lrclib.net for the words of the playing song."
                        Switch { on: Config.s.lyrics; onToggled: Config.s.lyrics = !Config.s.lyrics } }
                    Setting { label: "Calendar"
                        Switch { on: Config.s.showCalendar; onToggled: Config.s.showCalendar = !Config.s.showCalendar } }
                    Setting { label: "System stats"
                        Switch { on: Config.s.showStats; onToggled: Config.s.showStats = !Config.s.showStats } }
                    Setting { label: "Weather city"; detail: "Empty guesses from your connection (wttr.in)."
                        Field { implicitWidth: 220; size: Theme.md; placeholder: "e.g. Pune"; text: Config.s.weatherLocation; onAccepted: Config.s.weatherLocation = text.trim() } }
                    Setting { label: "Temperature in"
                        Choice { options: [{ value: "c", label: "°C" }, { value: "f", label: "°F" }]; value: Config.s.tempUnit; onPicked: v => Config.s.tempUnit = v } }
                }
            }
        }

        // ============================================================ dock
        Component {
            id: dockP
            ColumnLayout {
                spacing: 18
                Head { title: "Dock"; about: "Pinned and open apps along the bottom. Right-click an icon to pin or unpin it." }
                Group {
                    Setting { label: "Show the dock"; Switch { on: Config.s.dock; onToggled: Config.s.dock = !Config.s.dock } }
                    Setting { label: "Hide while windows are open"; detail: "Touch the bottom edge to bring it back."
                        Switch { on: Config.s.dockAutoHide; onToggled: Config.s.dockAutoHide = !Config.s.dockAutoHide } }
                    Setting { label: "Now playing in the dock"
                        Switch { on: Config.s.dockMedia; onToggled: Config.s.dockMedia = !Config.s.dockMedia } }
                }
            }
        }

        // ============================================================ wallpaper
        Component {
            id: wallP
            ColumnLayout {
                spacing: 18
                Head { title: "Wallpaper"; about: "Switching is instant. The subject cut-out (for the clock behind it) is worked out quietly afterwards." }
                Group {
                    Setting { label: "Choose a wallpaper"; detail: Wall.current ? Wall.current.name : "none yet"
                        RowLayout { spacing: 6
                            Btn { text: "Surprise me"; icon: "shuffle"; onClicked: Wall.random() }
                            Btn { text: "Browse"; icon: "image"; primary: true; onClicked: { Ui.settingsOpen = false; Ui.toggleOverlay("wallpapers"); } } } }
                    Setting { label: "Folder"
                        Field { implicitWidth: 260; size: Theme.md; text: Config.s.wallpaperDir; onAccepted: { Config.s.wallpaperDir = text.trim(); Wall.refreshLibrary(); } } }
                    Setting { label: "Switching"
                        Choice { options: [{ value: "fade", label: "Crossfade" }, { value: "ink", label: "Ink outline" }, { value: "none", label: "Instant" }]; value: Config.s.transition; onPicked: v => Config.s.transition = v } }
                }
                Group {
                    title: "Depth"
                    Setting { label: "3d parallax"; detail: "Switching workspaces moves the camera through the picture."
                        Switch { on: Config.s.parallax; onToggled: Config.s.parallax = !Config.s.parallax } }
                    Setting { label: "Follow the pointer"; visible: Config.s.parallax
                        Switch { on: Config.s.cursorParallax; onToggled: Config.s.cursorParallax = !Config.s.cursorParallax } }
                    Setting { label: "How much it moves"; visible: Config.s.parallax
                        Knob { from: 0.2; to: 2; step: 0.1; value: Config.s.parallaxStrength; onMoved: v => Config.s.parallaxStrength = v } }
                    Setting { label: "Find the subject again"; detail: Wall.aiMissing ? "The wallpaper ai isn't installed (./install.sh --ai)." : Wall.preparing ? "working…" : "If the clock hides behind the wrong thing."
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
                    }
                }
                Group {
                    title: "Night light"
                    Setting { label: "On"; Switch { on: Power.nightLight; onToggled: Power.nightLight = !Power.nightLight } }
                    Setting { label: "Warmth"; detail: Config.s.nightLightTemp + " K"
                        Knob { from: 2500; to: 6000; step: 100; value: Config.s.nightLightTemp; onMoved: v => Config.s.nightLightTemp = Math.round(v) } }
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
                    Setting { label: "3 or 4 fingers sideways"; detail: "Previous / next workspace." }
                    Setting { label: "4 fingers up"; detail: "Every workspace and its windows. Drag windows between them, or onto “new”." }
                    Setting { label: "4 fingers down"; detail: "Close whatever is open." }
                }
                Group {
                    title: "Keyboard"
                    Setting { label: "Layout"; detail: "xkb names, comma separated: us, de, us,ru…"
                        Field { implicitWidth: 180; size: Theme.md; text: Config.s.kbLayout; onAccepted: { Config.s.kbLayout = text.trim() || "us"; System.applyInput(); } } }
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
        Component { id: soundP; ColumnLayout { spacing: 18; Head { title: "Sound" } Group { ControlPanel { Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 12; page: "sound" } } } }

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
                    Setting { label: "Check that everything is in place"
                        Btn { text: "Run doctor"; onClicked: Quickshell.execDetached(["kitty", "-e", "sh", "-c", Config.bin + "kk-doctor; printf '\\npress enter '; read x"]) } }
                    Setting { label: "Settings file"; detail: "~/.config/kajukatli/settings.json"
                        Btn { text: "Open folder"; icon: "external"; onClicked: Quickshell.execDetached(["xdg-open", Config.home + "/.config/kajukatli"]) } }
                    Setting { label: "Restart the shell"; detail: "Picks up changes you made to its files."
                        Btn { text: "Restart"; icon: "restart"; onClicked: Quickshell.reload(true) } }
                }
            }
        }
    }
}

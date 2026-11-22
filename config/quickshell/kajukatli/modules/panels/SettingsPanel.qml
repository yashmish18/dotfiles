import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

Item {
    id: root
    implicitWidth: 640
    implicitHeight: 580
    property string page: "looks"

    RowLayout {
        anchors.fill: parent
        spacing: 14

        ColumnLayout {
            Layout.preferredWidth: 168
            Layout.fillHeight: true
            spacing: 4

            Txt {
                text: "Settings"
                font.pixelSize: Theme.xl
                font.weight: Font.Bold
                Layout.bottomMargin: 8
            }

            Repeater {
                model: [
                    { key: "looks", label: "Looks", icon: "palette" },
                    { key: "wallpaper", label: "Wallpaper", icon: "image" },
                    { key: "desktop", label: "Desktop", icon: "grid" },
                    { key: "touchpad", label: "Trackpad", icon: "move" },
                    { key: "wifi", label: "Wi-Fi", icon: "wifi" },
                    { key: "bluetooth", label: "Bluetooth", icon: "bluetooth" },
                    { key: "sound", label: "Sound", icon: "volume" }
                ]
                delegate: Rectangle {
                    id: navItem
                    required property var modelData
                    readonly property bool on: root.page === modelData.key
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 19
                    color: on ? Theme.primaryContainer : navArea.containsMouse ? Theme.surfaceHigh : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Icon { name: navItem.modelData.icon; size: 16; color: navItem.on ? Theme.primaryContainerText : Theme.surfaceTextDim; anchors.verticalCenter: parent.verticalCenter }
                        Txt { text: navItem.modelData.label; font.weight: navItem.on ? Font.DemiBold : Font.Normal; color: navItem.on ? Theme.primaryContainerText : Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: navArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = navItem.modelData.key }
                }
            }
            Item { Layout.fillHeight: true }
        }

        Hair { Layout.fillHeight: true; width: 1 }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: ["looks", "touchpad", "desktop", "wallpaper", "wifi", "bluetooth", "sound"].indexOf(root.page)
            Layout.leftMargin: 6

            // ---------------------------------------------------------------- looks
            Flickable {
                id: looksPage
                clip: true
                contentWidth: width
                contentHeight: looks.implicitHeight + 12
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: looks
                    width: looksPage.width - 8
                    spacing: 14

                    PageHead { title: "looks"; onBack: Ui.panel = "" }

                    // presets: one click sets everything below
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 6
                        rowSpacing: 6
                        Repeater {
                            model: Looks.names
                            delegate: Rectangle {
                                id: tile
                                required property string modelData
                                readonly property bool on: Config.s.look === modelData
                                Layout.fillWidth: true
                                implicitHeight: 50
                                radius: Theme.radiusSmall
                                color: on ? Theme.primaryContainer : tileArea.containsMouse ? Theme.surfaceHigh : Theme.surfaceContainer
                                border.width: 1
                                border.color: on ? Theme.primary : Theme.outlineVariant
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 10
                                    spacing: 2
                                    Txt {
                                        width: parent.width
                                        text: tile.modelData
                                        font.weight: Font.Medium
                                        color: tile.on ? Theme.primaryContainerText : Theme.surfaceText
                                    }
                                    Txt {
                                        width: parent.width
                                        text: Looks.blurbs[tile.modelData] || ""
                                        font.pixelSize: Theme.xs
                                        color: tile.on ? Theme.primaryContainerText : Theme.surfaceTextDim
                                    }
                                }
                                MouseArea {
                                    id: tileArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Looks.apply(tile.modelData)
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Btn { text: "arrange widgets"; onClicked: { Ui.panel = ""; Ui.editing = true; } }
                        Btn { text: "wallpapers"; onClicked: Ui.toggleOverlay("wallpapers") }
                        Btn { text: "re-detect subject (anime)"; onClicked: Wall.redetect("isnet-anime") }
                    }

                    Hair { Layout.fillWidth: true }
                    Choice {
                        label: "colours"
                        options: ["vibrant", "tonal", "mono"]
                        value: Config.s.themeScheme
                        onPicked: v => { Config.s.themeScheme = v; Looks.retheme(); }
                    }
                    Choice {
                        label: "mode"
                        options: ["dark", "light", "auto"]
                        value: Config.s.themeMode
                        onPicked: v => { Config.s.themeMode = v; Looks.retheme(); }
                    }

                    Hair { Layout.fillWidth: true }
                    Choice {
                        label: "bar"
                        options: ["pill", "bar", "islands", "rail", "none"]
                        value: Config.s.barStyle
                        onPicked: v => { Config.s.barStyle = v; Ui.barVisible = v !== "none"; }
                    }
                    Choice {
                        visible: Config.s.barStyle !== "rail" && Config.s.barStyle !== "none"
                        label: "bar edge"
                        options: ["top", "bottom"]
                        value: Config.s.barPosition
                        onPicked: v => Config.s.barPosition = v
                    }
                    Choice {
                        label: "workspaces"
                        options: ["dots", "diamonds", "numbers"]
                        value: Config.s.workspaceStyle
                        onPicked: v => Config.s.workspaceStyle = v
                    }

                    Hair { Layout.fillWidth: true }
                    Choice {
                        label: "desktop clock"
                        options: ["stack", "hero", "serif", "line", "day", "date", "off"]
                        value: Config.s.clockStyle
                        onPicked: v => Config.s.clockStyle = v
                    }
                    Toggle {
                        Layout.fillWidth: true
                        title: "clock behind the subject"
                        detail: !Config.s.clockDepth ? "off" : Wall.depthReady ? "on · subject found" : "on · waiting for a subject (needs the wallpaper ai)"
                        on: Config.s.clockDepth
                        onToggled: Config.s.clockDepth = !Config.s.clockDepth
                    }
                    Slider {
                        Layout.fillWidth: true
                        label: "clock size"
                        value: (Config.s.clockScale - 0.4) / 1.2
                        onMoved: v => Config.s.clockScale = Math.round((0.4 + v * 1.2) * 100) / 100
                    }

                    Hair { Layout.fillWidth: true }
                    Choice {
                        label: "visualiser"
                        options: ["off", "wave", "bars", "mirror"]
                        value: Config.s.visualizer
                        onPicked: v => Config.s.visualizer = v
                    }
                    Toggle {
                        Layout.fillWidth: true
                        visible: Config.s.visualizer !== "off"
                        title: "visualiser behind the subject"
                        detail: Config.s.visualizerBehind ? "tucked in" : "in front"
                        on: Config.s.visualizerBehind
                        onToggled: Config.s.visualizerBehind = !Config.s.visualizerBehind
                    }

                    Hair { Layout.fillWidth: true }
                    Choice {
                        label: "player on the desktop"
                        options: ["off", "lyrics", "card", "portrait"]
                        value: Config.s.mediaWidget
                        onPicked: v => Config.s.mediaWidget = v
                    }
                    Toggle {
                        Layout.fillWidth: true
                        title: "calendar"
                        detail: Config.s.showCalendar ? "on the desktop" : "hidden"
                        on: Config.s.showCalendar
                        onToggled: Config.s.showCalendar = !Config.s.showCalendar
                    }
                    Toggle {
                        Layout.fillWidth: true
                        title: "system stats"
                        detail: Config.s.showStats ? "on the desktop" : "hidden"
                        on: Config.s.showStats
                        onToggled: Config.s.showStats = !Config.s.showStats
                    }
                    Toggle {
                        Layout.fillWidth: true
                        title: "synced lyrics"
                        detail: Config.s.lyrics ? "fetched from lrclib.net" : "off (nothing leaves your machine)"
                        on: Config.s.lyrics
                        onToggled: Config.s.lyrics = !Config.s.lyrics
                    }

                    Hair { Layout.fillWidth: true }
                    Toggle {
                        Layout.fillWidth: true
                        title: "dock"
                        detail: Config.s.dock ? (Config.s.dockAutoHide ? "hides when a window is open" : "always there") : "off"
                        on: Config.s.dock
                        onToggled: Config.s.dock = !Config.s.dock
                    }
                    Toggle {
                        Layout.fillWidth: true
                        visible: Config.s.dock
                        title: "auto-hide the dock"
                        detail: "touch the bottom edge to bring it back"
                        on: Config.s.dockAutoHide
                        onToggled: Config.s.dockAutoHide = !Config.s.dockAutoHide
                    }

                    Hair { Layout.fillWidth: true }
                    Txt {
                        text: "weather city (empty = guess from your ip)"
                        color: Theme.muted
                        font.family: Theme.mono
                        font.pixelSize: Theme.xs
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Field {
                            Layout.fillWidth: true
                            size: Theme.md
                            placeholder: "e.g. Pune"
                            text: Config.s.weatherLocation
                            onAccepted: Config.s.weatherLocation = text.trim()
                        }
                        Choice {
                            Layout.fillWidth: false
                            options: [{ value: "c", label: "°C" }, { value: "f", label: "°F" }]
                            value: Config.s.tempUnit
                            onPicked: v => Config.s.tempUnit = v
                        }
                    }
                    Toggle {
                        Layout.fillWidth: true
                        title: "24-hour clock"
                        detail: Config.s.clock24h ? "13:45" : "1:45 pm"
                        on: Config.s.clock24h
                        onToggled: Config.s.clock24h = !Config.s.clock24h
                    }
                }
            }

            ColumnLayout {
                spacing: 12
                PageHead { title: "trackpad"; onBack: Ui.panel = "" }
                Toggle {
                    Layout.fillWidth: true
                    title: "natural scrolling"
                    detail: Config.s.naturalScroll ? "swipe down, page down" : "legacy direction"
                    on: Config.s.naturalScroll
                    onToggled: {
                        Config.s.naturalScroll = !Config.s.naturalScroll
                        Quickshell.execDetached(["hyprctl", "keyword", "input:touchpad:natural_scroll", Config.s.naturalScroll ? "true" : "false"])
                    }
                }
                Toggle {
                    Layout.fillWidth: true
                    title: "tap to click"
                    detail: "one-finger click"
                    on: true
                    onToggled: Quickshell.execDetached(["hyprctl", "keyword", "input:touchpad:tap_to_click", on ? "true" : "false"])
                }
            }

            ColumnLayout {
                spacing: 12
                PageHead { title: "desktop"; onBack: Ui.panel = "" }
                Toggle {
                    Layout.fillWidth: true
                    title: "cursor parallax"
                    detail: Config.s.cursorParallax ? "follows pointer" : "disabled"
                    on: Config.s.cursorParallax
                    onToggled: Config.s.cursorParallax = !Config.s.cursorParallax
                }
                Toggle {
                    Layout.fillWidth: true
                    title: "video on battery"
                    detail: Config.s.videoOnBattery ? "allowed" : "use still frame"
                    on: Config.s.videoOnBattery
                    onToggled: Config.s.videoOnBattery = !Config.s.videoOnBattery
                }
                RowLayout {
                    Layout.fillWidth: true
                    Btn { text: "open files"; onClicked: Quickshell.execDetached(["nautilus"]) }
                    Btn { text: "keybinds"; onClicked: Ui.toggleOverlay("cheatsheet") }
                }
            }

            ColumnLayout {
                spacing: 12
                PageHead { title: "wallpaper"; onBack: Ui.panel = "" }
                Choice {
                    label: "switching"
                    options: [{ value: "fade", label: "Crossfade" }, { value: "ink", label: "Ink outline" }, { value: "none", label: "Instant" }]
                    value: Config.s.transition
                    onPicked: v => Config.s.transition = v
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "bolt"
                    title: "Subject detection on battery"
                    detail: Config.s.aiOnBattery ? "runs any time" : "waits for the charger"
                    on: Config.s.aiOnBattery
                    onToggled: Config.s.aiOnBattery = !Config.s.aiOnBattery
                }
                Toggle {
                    Layout.fillWidth: true
                    title: "depth parallax"
                    detail: Config.s.parallax ? "enabled" : "disabled"
                    on: Config.s.parallax
                    onToggled: Config.s.parallax = !Config.s.parallax
                }
                Slider {
                    Layout.fillWidth: true
                    label: "motion strength"
                    value: Config.s.parallaxStrength
                    onMoved: v => Config.s.parallaxStrength = v
                }
                RowLayout {
                    Layout.fillWidth: true
                    Btn { text: "choose wallpaper"; onClicked: Ui.toggleOverlay("wallpapers") }
                    Btn { text: "random"; onClicked: Wall.random() }
                }
            }

            ColumnLayout {
                spacing: 10
                PageHead { title: "wi-fi"; onBack: Ui.panel = "" }
                Toggle {
                    Layout.fillWidth: true
                    title: "wi-fi"
                    detail: Net.ssid !== "" ? Net.ssid : Net.backend
                    on: Net.wifiEnabled
                    onToggled: Net.setWifi(!Net.wifiEnabled)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Btn { text: Net.scanning ? "scanning…" : "scan"; enabled: Net.wifiEnabled && !Net.scanning; onClicked: Net.rescan() }
                    Btn { text: "network manager"; onClicked: Net.openEditor() }
                }
                Txt {
                    visible: Net.error !== ""
                    text: Net.error
                    color: Theme.danger
                    font.family: Theme.mono
                    font.pixelSize: Theme.sm
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: Net.wifiEnabled ? Net.networks : []
                    delegate: ColumnLayout {
                        required property var modelData
                        width: parent ? parent.width : 300
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Txt {
                                text: modelData.ssid
                                Layout.fillWidth: true
                                font.family: Theme.mono
                                font.pixelSize: Theme.sm
                                color: modelData.active ? Theme.accent : Theme.paper
                            }
                            Txt { text: modelData.active ? "connected" : modelData.known ? "saved" : modelData.signal + "%" ; font.pixelSize: Theme.xs; color: Theme.muted }
                            Btn {
                                text: modelData.active ? "disconnect" : "connect"
                                onClicked: modelData.active ? Net.disconnect() : modelData.secure && !modelData.known ? Net.needsPassword = modelData.ssid : Net.connectTo(modelData.ssid, "")
                            }
                        }
                        Field {
                            Layout.fillWidth: true
                            visible: Net.needsPassword === modelData.ssid
                            password: true
                            placeholder: "password"
                            onAccepted: if (text !== "") Net.connectTo(modelData.ssid, text)
                        }
                    }
                }
            }

            ColumnLayout {
                spacing: 10
                PageHead { title: "bluetooth"; onBack: Ui.panel = "" }
                Toggle {
                    Layout.fillWidth: true
                    title: "bluetooth"
                    detail: Bt.available ? Bt.label : "no adapter"
                    on: Bt.enabled
                    enabled: Bt.available
                    onToggled: Bt.setEnabled(!Bt.enabled)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Btn { text: Bt.scanning ? "stop scan" : "scan"; enabled: Bt.enabled; onClicked: Bt.setScanning(!Bt.scanning) }
                    Btn { text: "bluetooth manager"; onClicked: Bt.openManager() }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: Bt.devices
                    delegate: RowLayout {
                        required property var modelData
                        width: parent ? parent.width : 300
                        Txt { text: modelData.name || modelData.address; Layout.fillWidth: true; font.family: Theme.mono; font.pixelSize: Theme.sm }
                        Btn { text: modelData.connected ? "disconnect" : modelData.paired ? "connect" : "pair"; onClicked: Bt.toggleDevice(modelData) }
                    }
                }
            }

            ColumnLayout {
                spacing: 10
                PageHead { title: "sound"; onBack: Ui.panel = "" }
                Slider {
                    Layout.fillWidth: true
                    label: "output"
                    value: Audio.volume
                    muted: Audio.muted
                    onMoved: v => Audio.setVolume(v)
                    onLabelClicked: Audio.toggleMute()
                }
                Slider {
                    Layout.fillWidth: true
                    label: "microphone"
                    value: Audio.micVolume
                    muted: Audio.micMuted
                    onMoved: v => Audio.setMic(v)
                    onLabelClicked: Audio.toggleMic()
                }
                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: Audio.sinks
                        Btn {
                            required property var modelData
                            text: Audio.name(modelData)
                            active: modelData === Audio.sink
                            onClicked: Audio.useSink(modelData)
                        }
                    }
                }
                Btn { text: "audio mixer"; onClicked: Quickshell.execDetached(["pavucontrol"]) }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

Item {
    id: root
    implicitWidth: 520
    implicitHeight: 560
    property string page: "appearance"

    RowLayout {
        anchors.fill: parent
        spacing: 14

        ColumnLayout {
            Layout.preferredWidth: 150
            Layout.fillHeight: true
            spacing: 4

            Txt {
                text: "settings"
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: Theme.xl
            }

            Repeater {
                model: [
                    { key: "appearance", label: "Appearance" },
                    { key: "touchpad", label: "Trackpad" },
                    { key: "desktop", label: "Desktop" },
                    { key: "wallpaper", label: "Wallpaper" },
                    { key: "wifi", label: "Wi-Fi" },
                    { key: "bluetooth", label: "Bluetooth" },
                    { key: "sound", label: "Sound" }
                ]
                Btn {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    active: root.page === modelData.key
                    onClicked: root.page = modelData.key
                }
            }
            Item { Layout.fillHeight: true }
        }

        Hair { Layout.fillHeight: true; width: 1 }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: ["appearance", "touchpad", "desktop", "wallpaper", "wifi", "bluetooth", "sound"].indexOf(root.page)

            ColumnLayout {
                spacing: 12
                PageHead { title: "appearance"; onBack: Ui.panel = "" }
                Toggle {
                    Layout.fillWidth: true
                    title: "desktop clock"
                    detail: Config.s.desktopWidget ? "widget visible" : "widget hidden"
                    on: Config.s.desktopWidget
                    onToggled: Config.s.desktopWidget = !Config.s.desktopWidget
                }
                Slider {
                    Layout.fillWidth: true
                    label: "wallpaper motion"
                    value: Config.s.parallaxStrength
                    onMoved: v => Config.s.parallaxStrength = v
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

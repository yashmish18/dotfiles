import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs.services
import qs.components

// the control center. a front page of sliders and tiles; wi-fi, bluetooth and sound each open
// their own page in place, and every page has a way out to the full app.
Item {
    id: root
    implicitWidth: 380
    implicitHeight: stack.children[stack.currentIndex] ? stack.children[stack.currentIndex].implicitHeight : 200
    focus: true
    Keys.onEscapePressed: page === "main" ? Ui.panel = "" : page = "main"

    property string page: "main"
    Behavior on implicitHeight { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    // a row in a list: icon, name, a little status, and the whole thing clickable
    component Row2: Rectangle {
        id: r
        property string icon: ""
        property real level: -1
        property string title: ""
        property string detail: ""
        property bool on: false
        signal clicked(var mouse)
        Layout.fillWidth: true
        implicitHeight: 48
        radius: Theme.radiusSmall + 4
        color: on ? Theme.alpha(Theme.primary, 0.16) : rArea.containsMouse ? Theme.surfaceHigh : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Icon {
            id: rIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            name: r.icon
            level: r.level
            size: 18
            color: r.on ? Theme.primary : Theme.surfaceTextDim
        }
        Txt {
            anchors.left: rIcon.right
            anchors.leftMargin: 12
            anchors.right: rDetail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: r.title
            font.weight: r.on ? Font.DemiBold : Font.Normal
            color: r.on ? Theme.primary : Theme.surfaceText
        }
        Txt {
            id: rDetail
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: r.detail
            font.pixelSize: Theme.sm
            color: Theme.surfaceTextDim
        }
        MouseArea {
            id: rArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => r.clicked(m)
        }
    }

    component Caption: Txt {
        Layout.topMargin: 4
        font.pixelSize: Theme.xs + 1
        color: Theme.outline
    }

    StackLayout {
        id: stack
        width: parent.width
        currentIndex: ["main", "wifi", "bluetooth", "sound"].indexOf(root.page)

        // ============================================================ front page
        ColumnLayout {
            spacing: 14
            Layout.alignment: Qt.AlignTop

            // battery and the quick actions
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    visible: Power.hasBattery
                    text: Power.percent + "%" + (Power.charging ? "  +" : "")
                    font.family: Theme.mono
                    color: Power.low ? Theme.error : Theme.surfaceTextDim
                }
                Item { Layout.fillWidth: true; visible: !Power.hasBattery }
                Btn { icon: "screenshot"; flat: true; onClicked: { Ui.panel = ""; Quickshell.execDetached(["sh", "-c", "sleep 0.35; " + Config.bin + "kk-shot area"]); } }
                Btn { icon: "record"; flat: true; active: Ui.recording; danger: Ui.recording; onClicked: { Ui.panel = ""; Quickshell.execDetached([Config.bin + "kk-record"]); } }
                Btn { icon: "sliders"; flat: true; onClicked: Ui.open("settings") }
                Btn { icon: "lock"; flat: true; onClicked: { Ui.panel = ""; Quickshell.execDetached([Config.bin + "kk-lock"]); } }
                Btn { icon: "power"; flat: true; danger: true; onClicked: Ui.open("session") }
            }

            // sliders
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Slider {
                        Layout.fillWidth: true
                        icon: Icons.volume(Audio.volume, Audio.muted)
                        value: Audio.volume
                        muted: Audio.muted
                        onMoved: v => Audio.setVolume(v)
                        onLabelClicked: Audio.toggleMute()
                    }
                    Btn { icon: "right"; onClicked: root.page = "sound" }
                }
                Slider {
                    Layout.fillWidth: true
                    visible: Bright.available
                    icon: "sun"
                    value: Bright.value
                    onMoved: v => Bright.set(v)
                }
                Slider {
                    Layout.fillWidth: true
                    icon: Audio.micMuted ? "mic-off" : "mic"
                    value: Audio.micVolume
                    muted: Audio.micMuted
                    onMoved: v => Audio.setMic(v)
                    onLabelClicked: Audio.toggleMic()
                }
            }

            Hair { Layout.fillWidth: true }

            // switches, one per row
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Toggle {
                    Layout.fillWidth: true
                    icon: Icons.net(Net.ethernet, Net.wifiEnabled, Net.ssid)
                    title: Net.ethernet ? "Wired" : "Wi-Fi"
                    level: Net.signal / 25
                    detail: Net.ethernet ? "" : Net.ssid
                    on: Net.wifiEnabled || Net.ethernet
                    more: true
                    onToggled: Net.setWifi(!Net.wifiEnabled)
                    onOpened: { root.page = "wifi"; Net.rescan(); }
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: !Bt.enabled ? "bluetooth-off" : "bluetooth"
                    title: "Bluetooth"
                    detail: Bt.connectedDevices.length > 0 ? Bt.label : ""
                    on: Bt.enabled
                    more: true
                    enabled: Bt.available
                    onToggled: Bt.setEnabled(!Bt.enabled)
                    onOpened: root.page = "bluetooth"
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: Notifs.dnd ? "bell-off" : "bell"
                    title: "Do not disturb"
                    detail: ""
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "night-light"
                    title: "Night light"
                    detail: Power.nightLight ? Config.s.nightLightTemp + " K" : ""
                    on: Power.nightLight
                    onToggled: Power.nightLight = !Power.nightLight
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "coffee"
                    title: "Stay awake"
                    detail: ""
                    on: Power.caffeine
                    onToggled: Power.caffeine = !Power.caffeine
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: Power.profileName === "saver" ? "leaf" : Power.profileName === "performance" ? "gauge" : "balance"
                    title: "Power mode"
                    detail: Power.profileName
                    on: Power.profileName !== "balanced"
                    onToggled: Power.cycleProfile()
                }
            }

            // now playing
            Hair { Layout.fillWidth: true; visible: Media.active }
            Item {
                visible: Media.active
                Layout.fillWidth: true
                implicitHeight: 56
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    spacing: 12
                    ClippingRectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: Theme.radiusSmall
                        color: Theme.surfaceHighest
                        Image {
                            anchors.fill: parent
                            source: Media.art
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(96, 96)
                            asynchronous: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt { Layout.fillWidth: true; text: Media.title; font.weight: Font.DemiBold }
                        Txt { Layout.fillWidth: true; text: Media.artist; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                    }
                    Btn { icon: "prev"; flat: true; onClicked: Media.prev() }
                    Btn { icon: Media.playing ? "pause" : "play"; primary: true; onClicked: Media.toggle() }
                    Btn { icon: "next"; flat: true; onClicked: Media.next() }
                }
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: Ui.open("media")
                }
            }
        }

        // ============================================================ wi-fi
        ColumnLayout {
            spacing: 8
            Layout.alignment: Qt.AlignTop

            PageHead {
                title: "Wi-Fi"
                subtitle: Net.ssid
                onBack: root.page = "main"
                Btn { icon: "restart"; enabled: !Net.scanning && Net.wifiEnabled; onClicked: Net.rescan() }
                Btn { icon: "power"; active: Net.wifiEnabled; onClicked: Net.setWifi(!Net.wifiEnabled) }
            }
            Txt {
                visible: Net.error !== ""
                Layout.fillWidth: true
                text: Net.error
                wrapMode: Text.WordWrap
                color: Theme.error
                font.pixelSize: Theme.sm
            }
            ListView {
                id: nets
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 340)
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: Net.wifiEnabled ? Net.networks : []
                delegate: ColumnLayout {
                    id: netRow
                    required property var modelData
                    readonly property bool asking: Net.needsPassword === modelData.ssid
                    width: nets.width
                    spacing: 4
                    Row2 {
                        icon: "wifi"
                        level: netRow.modelData.signal / 25
                        title: netRow.modelData.ssid
                        on: netRow.modelData.active
                        detail: Net.busySsid === netRow.modelData.ssid ? "joining…"
                              : netRow.modelData.active ? "connected"
                              : netRow.modelData.known ? "saved"
                              : netRow.modelData.secure ? "locked" : "open"
                        onClicked: m => {
                            const n = netRow.modelData;
                            if (m.button === Qt.RightButton) { if (n.known) Net.forget(n.ssid); return; }
                            if (n.active) Net.disconnect();
                            else if (n.secure && !n.known) Net.needsPassword = n.ssid;
                            else Net.connectTo(n.ssid, "");
                        }
                    }
                    Field {
                        visible: netRow.asking
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        password: true
                        size: Theme.md
                        placeholder: "Password"
                        onVisibleChanged: if (visible) focusNow()
                        onAccepted: if (text !== "") Net.connectTo(netRow.modelData.ssid, text)
                        onEscaped: Net.needsPassword = ""
                    }
                }
            }
            Btn { text: "Network settings"; icon: "external"; flat: true; onClicked: { Ui.panel = ""; Net.openEditor(); } }
        }

        // ============================================================ bluetooth
        ColumnLayout {
            spacing: 8
            Layout.alignment: Qt.AlignTop

            PageHead {
                title: "Bluetooth"
                subtitle: Bt.connectedDevices.length > 0 ? Bt.label : ""
                onBack: root.page = "main"
                Btn { icon: "search"; active: Bt.scanning; enabled: Bt.enabled; onClicked: Bt.setScanning(!Bt.scanning) }
                Btn { icon: "power"; active: Bt.enabled; enabled: Bt.available; onClicked: Bt.setEnabled(!Bt.enabled) }
            }
            ListView {
                id: devs
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 340)
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: Bt.enabled ? Bt.devices : []
                delegate: Row2 {
                    id: devRow
                    required property var modelData
                    width: devs.width
                    icon: modelData.connected ? "bluetooth-on" : "bluetooth"
                    title: modelData.name || modelData.address
                    on: modelData.connected
                    detail: modelData.pairing ? "pairing…"
                          : modelData.state === BluetoothDeviceState.Connecting ? "connecting…"
                          : modelData.connected ? ((modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "% · " : "") + "connected")
                          : modelData.paired ? "paired" : "new"
                    onClicked: m => m.button === Qt.RightButton ? devRow.modelData.forget() : Bt.toggleDevice(devRow.modelData)
                }
            }
            Btn { text: "Bluetooth manager"; icon: "external"; flat: true; onClicked: { Ui.panel = ""; Bt.openManager(); } }
        }

        // ============================================================ sound
        ColumnLayout {
            spacing: 8
            Layout.alignment: Qt.AlignTop

            PageHead {
                title: "Sound"
                subtitle: Audio.name(Audio.sink)
                onBack: root.page = "main"
                Btn { icon: "external"; onClicked: { Ui.panel = ""; Quickshell.execDetached(["pavucontrol"]); } }
            }
            Caption { text: "Output" }
            Repeater {
                model: Audio.sinks
                delegate: Row2 {
                    required property var modelData
                    icon: "volume"
                    title: Audio.name(modelData)
                    on: Audio.sink === modelData
                    onClicked: Audio.useSink(modelData)
                }
            }
            Caption { text: "Apps"; visible: Audio.streams.length > 0 }
            Repeater {
                model: Audio.streams
                delegate: Slider {
                    required property var modelData
                    Layout.fillWidth: true
                    label: Audio.streamName(modelData)
                    icon: modelData.audio && modelData.audio.muted ? "volume-mute" : "volume"
                    value: modelData.audio ? modelData.audio.volume : 0
                    muted: modelData.audio ? modelData.audio.muted : false
                    onMoved: v => { if (modelData.audio) modelData.audio.volume = v; }
                    onLabelClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                }
            }
        }
    }
}

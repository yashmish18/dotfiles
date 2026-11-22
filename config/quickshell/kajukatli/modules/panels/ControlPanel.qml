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

    property string page: Ui.controlPage !== "" ? Ui.controlPage : "main"
    function openWifi() {
        if (!Net.wifiEnabled) Net.setWifi(true);
        page = "wifi";
        Net.rescan();
    }
    function openBt() {
        if (Bt.available && !Bt.enabled) Bt.setEnabled(true);
        page = "bluetooth";
        Bt.setScanning(true);
    }
    Component.onCompleted: { if (page === "wifi") Net.rescan(); Ui.controlPage = ""; }
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
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
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

            // header: battery / power state on the left, quick actions on the right
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt {
                        text: Power.hasBattery ? Power.percent + "%" : "Plugged in"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: Power.low ? Theme.error : Theme.surfaceText
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: !Power.hasBattery ? Power.profileName
                            : Power.full ? "full"
                            : Power.charging ? "charging" + (Power.timeLeft ? " · full in " + Power.timeLeft : "")
                            : (Power.timeLeft ? Power.timeLeft + " left" : "on battery")
                        font.pixelSize: Theme.sm
                        color: Theme.surfaceTextDim
                    }
                }
                Btn { icon: "screenshot"; onClicked: Ui.open("capture") }
                Btn { icon: "record"; active: Ui.recording; danger: Ui.recording; onClicked: Ui.recording ? (Ui.panel = "", Quickshell.execDetached([Config.bin + "kk-record"])) : Ui.open("capture") }
                Btn { icon: "sliders"; onClicked: Ui.open("settings") }
                Btn { icon: "lock"; onClicked: { Ui.panel = ""; Quickshell.execDetached([Config.bin + "kk-lock"]); } }
                Btn { icon: "power"; danger: true; onClicked: Ui.toggleOverlay("power") }
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

            // tiles
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Toggle {
                    Layout.fillWidth: true
                    icon: Icons.net(Net.ethernet, Net.wifiEnabled, Net.ssid)
                    title: Net.ethernet ? "Wired" : "Wi-Fi"
                    detail: Net.ethernet ? "connected" : Net.ssid !== "" ? Net.ssid : Net.wifiEnabled ? "not connected" : "off"
                    on: Net.wifiEnabled || Net.ethernet
                    more: true
                    // a click shows the networks (and turns wi-fi on if it was off); it never
                    // switches wi-fi off by surprise. the switch is on the page itself.
                    onToggled: root.openWifi()
                    onOpened: root.openWifi()
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: !Bt.enabled ? "bluetooth-off" : "bluetooth"
                    title: "Bluetooth"
                    detail: Bt.available ? Bt.label : "no adapter"
                    on: Bt.enabled
                    more: true
                    enabled: Bt.available
                    onToggled: root.openBt()
                    onOpened: root.openBt()
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: Notifs.dnd ? "bell-off" : "bell"
                    title: "Do not disturb"
                    detail: Notifs.dnd ? "urgent only" : "off"
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "night-light"
                    title: "Night light"
                    detail: Power.nightLight ? Config.s.nightLightTemp + " K" : "off"
                    on: Power.nightLight
                    onToggled: Power.nightLight = !Power.nightLight
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "coffee"
                    title: "Stay awake"
                    detail: Power.caffeine ? "won't sleep" : "off"
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
            Rectangle {
                visible: Media.active
                Layout.fillWidth: true
                implicitHeight: 64
                radius: Theme.radius
                color: Theme.surfaceHigh
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12
                    ClippingRectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
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
                subtitle: Net.ssid !== "" ? "connected to " + Net.ssid : Net.wifiEnabled ? "not connected" : "off"
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
            Txt {
                visible: Net.wifiEnabled && Net.networks.length === 0
                text: Net.scanning ? "Looking for networks…" : "Nothing nearby. Try scanning again."
                color: Theme.surfaceTextDim
            }
            Txt {
                text: "right-click a saved network to forget it"
                font.pixelSize: Theme.xs + 1
                color: Theme.outline
            }
            Btn { text: "Network settings"; icon: "external"; onClicked: { Ui.panel = ""; Net.openEditor(); } }
        }

        // ============================================================ bluetooth
        ColumnLayout {
            spacing: 8
            Layout.alignment: Qt.AlignTop

            PageHead {
                title: "Bluetooth"
                subtitle: Bt.available ? Bt.label : "no adapter"
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
            Txt {
                visible: Bt.enabled && Bt.devices.length === 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: Bt.scanning ? "Looking for devices…" : "No devices yet. Scan, and put the other device in pairing mode."
                color: Theme.surfaceTextDim
            }
            Txt {
                text: "click to connect · right-click to forget"
                font.pixelSize: Theme.xs + 1
                color: Theme.outline
            }
            Btn { text: "Bluetooth manager"; icon: "external"; onClicked: { Ui.panel = ""; Bt.openManager(); } }
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
            Caption { text: "OUTPUT" }
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
            Caption { text: "APPS"; visible: Audio.streams.length > 0 }
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
            Txt {
                visible: Audio.streams.length === 0
                text: "Nothing is playing."
                color: Theme.surfaceTextDim
            }
        }
    }
}

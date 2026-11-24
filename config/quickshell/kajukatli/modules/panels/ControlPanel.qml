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
    // take the page asked for, then let go of the request (assigning breaks the binding first,
    // so clearing Ui.controlPage doesn't bounce us back to the front page)
    Component.onCompleted: { const p = page; page = p; if (p === "wifi") Net.rescan(); if (p === "bluetooth") Bt.setScanning(true); Ui.controlPage = ""; }
    Behavior on implicitHeight { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    // a row in a list: icon, name, a little status, and the whole thing clickable
    component Row2: Rectangle {
        id: r
        property string icon: ""
        property real level: -1
        property string title: ""
        property string detail: ""
        property bool on: false
        property int rightPad: 0          // room for a button sitting on the row's right end
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
            anchors.rightMargin: 12 + r.rightPad
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
        currentIndex: ["main", "wifi", "bluetooth", "sound", "battery"].indexOf(root.page)

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
                    // tap the percentage: the battery's own page (health, watts, cycles, the last day)
                    Txt {
                        text: Power.hasBattery ? Power.percent + "%" : "Plugged in"
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            enabled: Power.hasBattery
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = "battery"
                        }
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
                        MouseArea {
                            anchors.fill: parent
                            enabled: Power.hasBattery
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = "battery"
                        }
                    }
                }
                Btn { icon: "cpu"; onClicked: Ui.toggleOverlay("system") }
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
                    // the icon switches wi-fi on or off; the rest of the tile shows the networks
                    onToggled: Net.setWifi(!Net.wifiEnabled)
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
                    onToggled: Bt.toggle()
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
                // the nvidia card: the icon switches it (apps on it move over first), the tile opens graphics
                Toggle {
                    Layout.fillWidth: true
                    visible: Gpu.hybrid
                    icon: "gauge"
                    title: "NVIDIA"
                    detail: !Gpu.powered ? "off" : Gpu.running !== "igpu" ? "drawing the desktop" : Gpu.users.length ? Gpu.users.length + " app" + (Gpu.users.length > 1 ? "s" : "") + " on it" : Gpu.runtime === "suspended" ? "asleep" : "on"
                    on: Gpu.powered
                    more: true
                    Component.onCompleted: Gpu.refresh()
                    onToggled: Gpu.setPower(!Gpu.powered)
                    onOpened: Ui.settings("display")
                }
                // sound mode: the icon switches it on (last mode) or off, the tile opens the sound page
                Toggle {
                    Layout.fillWidth: true
                    icon: "music"
                    title: "Sound mode"
                    detail: Sound.label
                    on: Sound.active
                    more: true
                    onToggled: Sound.toggle()
                    onOpened: root.page = "sound"
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
                property string expanded: ""        // the device whose controls are open
                delegate: ColumnLayout {
                    id: devItem
                    required property var modelData
                    readonly property var d: modelData
                    readonly property string trouble: Bt.trouble[d.address] || ""
                    readonly property bool open: devs.expanded === d.address
                    width: devs.width
                    spacing: 4
                    Row2 {
                        icon: devItem.d.connected ? "bluetooth-on" : "bluetooth"
                        title: devItem.d.name || devItem.d.address
                        on: devItem.d.connected
                        rightPad: devItem.d.paired ? 30 : 0
                        detail: devItem.d.pairing ? "pairing…"
                              : devItem.trouble === "connecting" || devItem.d.state === BluetoothDeviceState.Connecting ? "connecting…"
                              : devItem.trouble === "retrying" ? "trying again…"
                              : devItem.trouble === "failed" ? "won't connect"
                              : devItem.d.connected ? ((devItem.d.batteryAvailable ? Math.round(devItem.d.battery * 100) + "% · " : "") + "connected")
                              : devItem.d.paired ? "saved" : "new"
                        // tap: connect / disconnect · right-click (or the arrow): its controls
                        onClicked: m => m.button === Qt.RightButton ? (devs.expanded = devItem.open ? "" : devItem.d.address) : Bt.toggleDevice(devItem.d)
                        Btn {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: devItem.d.paired
                            flat: true
                            icon: devItem.open ? "up" : "down"
                            onClicked: devs.expanded = devItem.open ? "" : devItem.d.address
                        }
                    }
                    // everything about one device
                    Rectangle {
                        visible: devItem.open
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.bottomMargin: 6
                        implicitHeight: ctl.implicitHeight + 20
                        radius: Theme.radiusSmall + 4
                        color: Theme.surfaceHigh
                        ColumnLayout {
                            id: ctl
                            x: 10; y: 10
                            width: parent.width - 20
                            spacing: 8
                            Txt {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.xs + 1
                                font.family: Theme.mono
                                color: Theme.surfaceTextDim
                                text: devItem.d.address
                                    + (devItem.d.batteryAvailable ? "  ·  battery " + Math.round(devItem.d.battery * 100) + "%" : "")
                                    + (devItem.d.bonded ? "  ·  bonded" : "")
                            }
                            Txt {
                                visible: devItem.trouble === "failed"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.sm
                                color: Theme.error
                                text: "It answers but won't connect: it was probably paired with another device since. Put it in pairing mode and pair it again."
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Txt { Layout.fillWidth: true; text: "Connect automatically"; font.pixelSize: Theme.sm }
                                Switch { on: devItem.d.trusted; onToggled: Bt.setTrusted(devItem.d, !devItem.d.trusted) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Txt { Layout.fillWidth: true; text: "Block"; font.pixelSize: Theme.sm }
                                Switch { on: devItem.d.blocked; onToggled: Bt.setBlocked(devItem.d, !devItem.d.blocked) }
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Btn { text: devItem.d.connected ? "Disconnect" : "Connect"; onClicked: Bt.toggleDevice(devItem.d) }
                                Btn { text: "Pair again"; visible: devItem.d.paired; onClicked: { devs.expanded = ""; Bt.repair(devItem.d); } }
                                Btn { text: "Send file"; visible: devItem.d.connected; onClicked: { Ui.panel = ""; Bt.sendFile(devItem.d); } }
                                Btn { text: "Sound"; visible: devItem.d.connected; onClicked: root.page = "sound" }
                                Btn { text: "Forget"; danger: true; onClicked: { devs.expanded = ""; devItem.d.forget(); } }
                            }
                        }
                    }
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
                text: "tap to connect · the arrow for its controls"
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
            Caption { text: "SOUND MODE" }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Btn { text: "Off"; active: !Sound.active; onClicked: Sound.set("off") }
                Repeater {
                    model: Sound.modes
                    delegate: Btn {
                        required property var modelData
                        text: modelData.label
                        active: Sound.mode === modelData.key
                        enabled: modelData.key !== "atmos" || Sound.haveAtmos
                        onClicked: Sound.set(modelData.key)
                    }
                }
            }
            Txt {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.xs + 1
                color: Sound.error !== "" ? Theme.error : Theme.surfaceTextDim
                text: Sound.error !== "" ? Sound.error
                    : Sound.active ? (Sound.modes.find(m => m.key === Sound.mode) || { about: "" }).about
                    : Sound.haveAtmos ? "Pick a mode: everything plays through it."
                    : "Dolby has no Linux driver. Atmos works with your laptop's own Dolby impulse file: put it in the sound folder (Settings → Sound)."
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

        // ============================================================ battery
        ColumnLayout {
            spacing: 10
            Layout.alignment: Qt.AlignTop
            Uses { service: Battery; active: root.page === "battery" }

            PageHead {
                title: "Battery"
                subtitle: Power.percent + "% · " + (Power.full ? "full" : Power.charging ? "charging" : "on battery")
                    + (Power.timeLeft ? " · " + Power.timeLeft + (Power.charging ? " to full" : " left") : "")
                onBack: root.page = "main"
                Btn { icon: "sliders"; onClicked: Ui.settings("power") }
            }

            // the big numbers
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: [
                        { k: "Power", v: Battery.watts > 0 ? Battery.watts.toFixed(1) + " W" : "—", d: Power.charging ? "going in" : "drawn" },
                        { k: "Health", v: Battery.health < 0 ? "—" : Math.round(Battery.health * 100) + "%", d: "of when new" },
                        { k: "Cycles", v: Battery.cycles >= 0 ? String(Battery.cycles) : "—", d: "charge cycles" },
                        { k: "Holds", v: Battery.energyFull > 0 ? Battery.energyFull.toFixed(1) + " Wh" : "—", d: Battery.energyDesign > 0 ? "of " + Battery.energyDesign.toFixed(1) + " Wh" : "" },
                        { k: "Now", v: Battery.energyNow > 0 ? Battery.energyNow.toFixed(1) + " Wh" : "—", d: "stored" },
                        { k: "Voltage", v: Battery.volts > 0 ? Battery.volts.toFixed(2) + " V" : "—", d: Battery.tempC > 0 ? Battery.tempC.toFixed(0) + " °C" : "" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 62
                        radius: Theme.radiusSmall + 4
                        color: Theme.surfaceHigh
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Txt { text: modelData.k.toUpperCase(); font.pixelSize: Theme.xs; font.letterSpacing: 1; color: Theme.outline }
                            Txt { text: modelData.v; font.pixelSize: Theme.lg; font.weight: Font.Bold; font.family: Theme.mono }
                            Txt { text: modelData.d; visible: text !== ""; font.pixelSize: Theme.xs; color: Theme.surfaceTextDim }
                        }
                    }
                }
            }

            // the last day of charge
            Caption { text: "LAST 24 HOURS"; visible: Battery.history.length > 1 }
            Canvas {
                id: graph
                visible: Battery.history.length > 1
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                property var pts: Battery.history
                onPtsChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    if (pts.length < 2) return;
                    const t0 = Date.now() - 24 * 3600 * 1000, W = width, H = height;
                    const X = t => (t - t0) / (24 * 3600 * 1000) * W, Y = p => H - 4 - (p / 100) * (H - 8);
                    c.beginPath();
                    c.moveTo(X(pts[0].t), H);
                    for (const q of pts) c.lineTo(X(q.t), Y(q.p));
                    c.lineTo(X(pts[pts.length - 1].t), H);
                    c.closePath();
                    c.fillStyle = Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18);
                    c.fill();
                    c.beginPath();
                    for (let i = 0; i < pts.length; i++) i === 0 ? c.moveTo(X(pts[i].t), Y(pts[i].p)) : c.lineTo(X(pts[i].t), Y(pts[i].p));
                    c.strokeStyle = Theme.primary;
                    c.lineWidth = 2;
                    c.stroke();
                }
            }

            // what it is
            Txt {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.xs + 1
                font.family: Theme.mono
                color: Theme.surfaceTextDim
                text: [Battery.info.manufacturer, Battery.info.model_name, Battery.info.technology].filter(x => x).join(" · ")
                    + (Battery.info.capacity_level ? "  ·  level: " + String(Battery.info.capacity_level).toLowerCase() : "")
            }

            // stop charging early: keeps the battery young
            RowLayout {
                Layout.fillWidth: true
                visible: Battery.limitSupported
                Txt { Layout.fillWidth: true; text: "Stop charging at"; font.pixelSize: Theme.sm }
                Repeater {
                    model: [60, 80, 100]
                    delegate: Btn {
                        required property int modelData
                        text: modelData === 100 ? "100%" : modelData + "%"
                        active: Config.s.chargeLimit === modelData
                        onClicked: Battery.setLimit(modelData)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Txt { Layout.fillWidth: true; text: "Power mode"; font.pixelSize: Theme.sm }
                Repeater {
                    model: Power.hasPerformance ? ["saver", "balanced", "performance"] : ["saver", "balanced"]
                    delegate: Btn {
                        required property string modelData
                        text: modelData
                        active: Power.profileName === modelData
                        onClicked: Power.setProfile(modelData)
                    }
                }
            }
            Btn { text: "What's using power"; icon: "external"; onClicked: { Ui.panel = ""; Quickshell.execDetached(["kitty", "--hold", "-e", Config.bin + "kk-power-report"]); } }
        }
    }
}

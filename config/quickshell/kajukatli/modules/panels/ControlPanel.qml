import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import qs.services
import qs.components

// the control center. a front page of switches and sliders; wi-fi, bluetooth and sound
// each open their own page in place (and every page has a way out to the full app).
Item {
    id: root
    implicitWidth: 384
    implicitHeight: stack.children[stack.currentIndex] ? stack.children[stack.currentIndex].implicitHeight + 8 : 200
    focus: true
    Keys.onEscapePressed: page === "main" ? Ui.panel = "" : page = "main"

    property string page: "main"
    Behavior on implicitHeight { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    readonly property string greeting: {
        const h = clock.hours;
        const who = (Quickshell.env("USER") || "").toLowerCase();
        const part = h < 5 ? "still up" : h < 12 ? "morning" : h < 18 ? "afternoon" : h < 22 ? "evening" : "late";
        return part + ", " + who + ".";
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    property string uptime: ""
    Process {
        running: true
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = parseFloat(text);
                const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
                root.uptime = "up " + (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m";
            }
        }
    }

    StackLayout {
        id: stack
        width: parent.width
        currentIndex: ["main", "wifi", "bt", "sound"].indexOf(root.page)

        // ============================================================ front page
        ColumnLayout {
            spacing: 12
            Layout.alignment: Qt.AlignTop

            RowLayout {
                Layout.fillWidth: true
                Txt {
                    text: root.greeting
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: Theme.xl - 4
                    Layout.fillWidth: true
                }
                Txt {
                    text: root.uptime
                    font.family: Theme.mono
                    font.pixelSize: Theme.xs
                    color: Theme.faint
                }
            }

            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Layout.fillWidth: true

                Toggle {
                    Layout.fillWidth: true
                    title: "wi-fi"
                    detail: Net.ethernet ? "wired" : Net.ssid !== "" ? Net.ssid : Net.wifiEnabled ? "not connected" : "off"
                    on: Net.wifiEnabled
                    more: true
                    onToggled: Net.setWifi(!Net.wifiEnabled)
                    onOpened: { root.page = "wifi"; Net.rescan(); }
                }
                Toggle {
                    Layout.fillWidth: true
                    title: "bluetooth"
                    detail: Bt.available ? Bt.label : "no adapter"
                    on: Bt.enabled
                    more: true
                    enabled: Bt.available
                    onToggled: Bt.setEnabled(!Bt.enabled)
                    onOpened: root.page = "bt"
                }
                Toggle {
                    Layout.fillWidth: true
                    title: "quiet"
                    detail: Notifs.dnd ? "only urgent things" : "off"
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
                Toggle {
                    Layout.fillWidth: true
                    title: "night light"
                    detail: Power.nightLight ? Config.s.nightLightTemp + "k" : "off"
                    on: Power.nightLight
                    onToggled: Power.nightLight = !Power.nightLight
                }
                Toggle {
                    Layout.fillWidth: true
                    title: "stay awake"
                    detail: Power.caffeine ? "won't sleep" : "off"
                    on: Power.caffeine
                    onToggled: Power.caffeine = !Power.caffeine
                }
                Toggle {
                    Layout.fillWidth: true
                    title: "power"
                    detail: Power.profileName
                    on: Power.profileName !== "balanced"
                    onToggled: Power.cycleProfile()
                }
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Layout.topMargin: 2

                RowLayout {
                    Layout.fillWidth: true
                    Slider {
                        Layout.fillWidth: true
                        label: "sound"
                        value: Audio.volume
                        muted: Audio.muted
                        onMoved: v => Audio.setVolume(v)
                        onLabelClicked: Audio.toggleMute()
                    }
                    Btn {
                        glyph: ""
                        size: 8
                        onClicked: root.page = "sound"
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    Layout.rightMargin: 30
                    label: "mic"
                    value: Audio.micVolume
                    muted: Audio.micMuted
                    onMoved: v => Audio.setMic(v)
                    onLabelClicked: Audio.toggleMic()
                }
                Slider {
                    Layout.fillWidth: true
                    Layout.rightMargin: 30
                    visible: Bright.available
                    label: "light"
                    value: Bright.value
                    onMoved: v => Bright.set(v)
                }
            }

            Hair { Layout.fillWidth: true }

            // battery as a sentence
            Txt {
                Layout.fillWidth: true
                visible: Power.hasBattery
                text: Power.full ? "battery full. you can unplug."
                    : Power.charging ? `${Power.percent}%, charging` + (Power.timeLeft ? ` · full in ${Power.timeLeft}` : "")
                    : `${Power.percent}%` + (Power.timeLeft ? ` · about ${Power.timeLeft} left` : "")
                font.family: Theme.mono
                font.pixelSize: Theme.sm
                color: Power.low ? Theme.danger : Theme.muted
            }

            MediaCard {
                Layout.fillWidth: true
                visible: player !== null
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Btn { text: "screenshot"; onClicked: { Ui.panel = ""; Quickshell.execDetached(["sh", "-c", "sleep 0.35; kk-shot area"]); } }
                Btn { text: Ui.recording ? "stop rec" : "record"; danger: Ui.recording; onClicked: { Ui.panel = ""; Quickshell.execDetached(["kk-record"]); } }
                Btn { text: "settings"; onClicked: Ui.open("settings") }
                Item { Layout.fillWidth: true }
                Btn { text: "lock"; onClicked: { Ui.panel = ""; Quickshell.execDetached(["kk-lock"]); } }
                Btn { glyph: ""; danger: true; onClicked: Ui.open("session") }
            }
        }

        // ============================================================ wi-fi
        ColumnLayout {
            spacing: 10
            Layout.alignment: Qt.AlignTop

            PageHead {
                title: "wi-fi"
                onBack: root.page = "main"
                Btn { text: Net.scanning ? "looking…" : "scan"; enabled: !Net.scanning && Net.wifiEnabled; onClicked: Net.rescan() }
                Btn { text: Net.wifiEnabled ? "turn off" : "turn on"; onClicked: Net.setWifi(!Net.wifiEnabled) }
            }

            Txt {
                visible: Net.error !== ""
                text: Net.error
                color: Theme.danger
                font.family: Theme.mono
                font.pixelSize: Theme.sm
            }

            ListView {
                id: nets
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 320)
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: Net.wifiEnabled ? Net.networks : []

                delegate: Column {
                    id: netRow
                    required property var modelData
                    readonly property bool asking: Net.needsPassword === modelData.ssid
                    width: nets.width

                    Item {
                        width: parent.width
                        height: 38
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: rowArea.containsMouse ? Theme.raised : "transparent"
                        }
                        Txt {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: meta.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: netRow.modelData.ssid
                            font.family: Theme.serif
                            font.italic: netRow.modelData.active
                            font.pixelSize: Theme.md + 1
                            color: netRow.modelData.active ? Theme.accent : Theme.paper
                        }
                        Row {
                            id: meta
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Txt {
                                text: Net.busySsid === netRow.modelData.ssid ? "joining…" : netRow.modelData.active ? "connected" : netRow.modelData.known ? "saved" : ""
                                font.family: Theme.mono
                                font.pixelSize: Theme.xs
                                color: Theme.muted
                            }
                            Glyph {
                                visible: netRow.modelData.secure
                                g: ""
                                font.pixelSize: Theme.xs
                                color: Theme.faint
                            }
                            Txt {
                                text: netRow.modelData.signal
                                width: 22
                                horizontalAlignment: Text.AlignRight
                                font.family: Theme.mono
                                font.pixelSize: Theme.xs
                                color: netRow.modelData.signal > 60 ? Theme.paper : netRow.modelData.signal > 35 ? Theme.muted : Theme.faint
                            }
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: e => {
                                const n = netRow.modelData;
                                if (e.button === Qt.RightButton) {
                                    if (n.known) Net.forget(n.ssid);
                                } else if (n.active) {
                                    Net.disconnect();
                                } else if (n.secure && !n.known) {
                                    Net.needsPassword = n.ssid;
                                } else {
                                    Net.connectTo(n.ssid, "");
                                }
                            }
                        }
                    }

                    Field {
                        visible: netRow.asking
                        width: parent.width - 16
                        x: 8
                        password: true
                        size: Theme.md
                        placeholder: "password for " + netRow.modelData.ssid
                        onVisibleChanged: if (visible) { clear(); focusNow(); }
                        onAccepted: if (text !== "") Net.connectTo(netRow.modelData.ssid, text)
                        onEscaped: Net.needsPassword = ""
                    }
                }
            }

            Txt {
                visible: Net.wifiEnabled && Net.networks.length === 0
                text: Net.scanning ? "listening for networks…" : "nothing around. try scan."
                font.family: Theme.serif
                font.italic: true
                color: Theme.muted
            }

            Txt {
                text: "right-click a saved network to forget it."
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                color: Theme.faint
            }
            Btn { text: "open network settings"; onClicked: { Ui.panel = ""; Net.openEditor(); } }
        }

        // ============================================================ bluetooth
        ColumnLayout {
            spacing: 10
            Layout.alignment: Qt.AlignTop

            PageHead {
                title: "bluetooth"
                onBack: root.page = "main"
                Btn { text: Bt.scanning ? "stop" : "scan"; enabled: Bt.enabled; onClicked: Bt.setScanning(!Bt.scanning) }
                Btn { text: Bt.enabled ? "turn off" : "turn on"; enabled: Bt.available; onClicked: Bt.setEnabled(!Bt.enabled) }
            }

            ListView {
                id: devs
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 320)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Bt.enabled ? Bt.devices : []

                delegate: Item {
                    id: devRow
                    required property var modelData
                    width: devs.width
                    height: 38
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: devArea.containsMouse ? Theme.raised : "transparent"
                    }
                    Txt {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: devMeta.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: devRow.modelData.name || devRow.modelData.address
                        font.family: Theme.serif
                        font.italic: devRow.modelData.connected
                        font.pixelSize: Theme.md + 1
                        color: devRow.modelData.connected ? Theme.accent : Theme.paper
                    }
                    Txt {
                        id: devMeta
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property var d: devRow.modelData
                        text: d.pairing ? "pairing…"
                            : d.state === BluetoothDeviceState.Connecting ? "connecting…"
                            : d.connected ? ((d.batteryAvailable ? Math.round(d.battery * 100) + "% · " : "") + "connected")
                            : d.paired ? "paired" : "new"
                        font.family: Theme.mono
                        font.pixelSize: Theme.xs
                        color: Theme.muted
                    }
                    MouseArea {
                        id: devArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => e.button === Qt.RightButton ? devRow.modelData.forget() : Bt.toggleDevice(devRow.modelData)
                    }
                }
            }

            Txt {
                visible: Bt.enabled && Bt.devices.length === 0
                text: Bt.scanning ? "looking for devices…" : "no devices yet. press scan, and put the other thing in pairing mode."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.family: Theme.serif
                font.italic: true
                color: Theme.muted
            }
            Txt {
                text: "click to connect · right-click to forget"
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                color: Theme.faint
            }
            Btn { text: "open bluetooth manager"; onClicked: { Ui.panel = ""; Bt.openManager(); } }
        }

        // ============================================================ sound
        ColumnLayout {
            spacing: 10
            Layout.alignment: Qt.AlignTop

            PageHead {
                title: "sound"
                onBack: root.page = "main"
                Btn { text: "mixer"; onClicked: { Ui.panel = ""; Quickshell.execDetached(["pavucontrol"]); } }
            }

            Txt {
                text: "output"
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                color: Theme.faint
            }
            Repeater {
                model: Audio.sinks
                delegate: Item {
                    id: sinkRow
                    required property var modelData
                    readonly property bool current: Audio.sink === modelData
                    Layout.fillWidth: true
                    implicitHeight: 32
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        spacing: 10
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7; height: 7; radius: 3.5
                            color: sinkRow.current ? Theme.accent : "transparent"
                            border.width: 1
                            border.color: sinkRow.current ? Theme.accent : Theme.faint
                        }
                        Txt {
                            text: Audio.name(sinkRow.modelData)
                            width: 320
                            color: sinkRow.current ? Theme.paper : Theme.muted
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.useSink(sinkRow.modelData)
                    }
                }
            }

            Txt {
                visible: Audio.streams.length > 0
                text: "playing"
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                color: Theme.faint
                Layout.topMargin: 4
            }
            Repeater {
                model: Audio.streams
                delegate: Slider {
                    required property var modelData
                    Layout.fillWidth: true
                    label: Audio.streamName(modelData).toLowerCase().slice(0, 11)
                    value: modelData.audio ? modelData.audio.volume : 0
                    muted: modelData.audio ? modelData.audio.muted : false
                    onMoved: v => { if (modelData.audio) modelData.audio.volume = v; }
                    onLabelClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                }
            }
            Txt {
                visible: Audio.streams.length === 0
                text: "nothing is playing."
                font.family: Theme.serif
                font.italic: true
                color: Theme.muted
            }
        }
    }
}

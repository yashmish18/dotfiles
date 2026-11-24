import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.services
import qs.components
import qs.modules.desktop

// one thing in the bar, by name. barModules.left / center / right in settings.json list them:
//
//   logo workspaces notifs cpu mem temp clock weather media visualizer
//   volume brightness network bluetooth battery tray power
//   control   one pill: wi-fi · sound · battery, opens the control center
//   apps      every running app (windows, tray, background): one tap to see and control them
//   phone     your phone over kde connect: battery, notifications, files
//
// every module works lying down (pill, bar, islands) and standing up (rail).
Loader {
    id: root
    property string name: ""
    property bool vertical: false
    property var monitor: null
    property int menuEdge: Edges.Bottom

    // a module with nothing to say (no battery, no player…) takes no room at all
    visible: item !== null && (item.shown === undefined || item.shown)

    // open a panel hanging from this module
    function openPanel(panel: string) {
        const p = root.mapToItem(null, root.width / 2, root.height / 2);
        Ui.toggleAt(panel, vertical ? p.y : p.x);
    }

    sourceComponent: {
        switch (name) {
        case "logo": return logoC;
        case "workspaces": return wsC;
        case "notifs": return notifC;
        case "cpu": return cpuC;
        case "mem": return memC;
        case "temp": return tempC;
        case "clock": return clockC;
        case "weather": return weatherC;
        case "media": return mediaC;
        case "visualizer": return visC;
        case "volume": return volC;
        case "brightness": return brightC;
        case "network": return netC;
        case "bluetooth": return btC;
        case "battery": return batC;
        case "tray": return trayC;
        case "power": return powerC;
        case "control": return controlC;
        case "apps": return appsC;
        case "phone": return phoneC;
        }
        return null;
    }

    // ------------------------------------------------------------ an icon and a number
    component Chip: Item {
        id: chip
        // inline components can't see the file's ids: the Loader that holds us is our parent
        readonly property bool vertical: parent ? parent.vertical === true : false
        property string icon: ""
        property real level: -1
        property string label: ""
        property color color: Theme.surfaceText
        property color iconColor: Theme.surfaceTextDim
        property bool shown: true
        property bool wantsWheel: false
        property bool lit: false               // its panel is open
        signal clicked(var mouse)
        signal wheel(var event)
        implicitWidth: vertical ? 28 : row.implicitWidth + 10
        implicitHeight: vertical ? col.implicitHeight + 8 : 24

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.lit ? Theme.alpha(Theme.primary, 0.2) : hover.containsMouse ? Theme.alpha(Theme.surfaceText, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
        Row {
            id: row
            visible: !chip.vertical
            anchors.centerIn: parent
            spacing: 5
            Icon {
                visible: chip.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                level: chip.level
                size: 14
                color: chip.lit ? Theme.primary : chip.iconColor
            }
            Txt {
                visible: chip.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.family: Theme.mono
                font.pixelSize: Theme.sm
                color: chip.color
            }
        }
        Column {
            id: col
            visible: chip.vertical
            anchors.centerIn: parent
            spacing: 2
            Icon {
                visible: chip.icon !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                name: chip.icon
                level: chip.level
                size: 16
                color: chip.lit ? Theme.primary : chip.iconColor
            }
            Txt {
                visible: chip.label !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: chip.label
                font.family: Theme.mono
                font.pixelSize: 9
                color: chip.color
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: m => chip.clicked(m)
            onWheel: w => { if (chip.wantsWheel) chip.wheel(w); else w.accepted = false; }
        }
    }

    // ------------------------------------------------------------ logo
    Component {
        id: logoC
        Chip {
            icon: Config.s.barLogo === "" ? "spark" : ""
            label: Config.s.barLogo
            iconColor: Theme.primary
            color: Theme.primary
            lit: Ui.panel === "launcher"
            onClicked: m => m.button === Qt.RightButton ? root.openPanel("settings") : Ui.toggle("launcher")
        }
    }

    // ------------------------------------------------------------ workspaces
    Component {
        id: wsC
        Row {
          spacing: 8
          // the workspace you just went to, shown as a number for a moment
          readonly property int cur: root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : Hypr.focusedId
          property bool flashing: false
          onCurChanged: { flashing = true; unflash.restart(); }
          Timer { id: unflash; interval: 1300; onTriggered: parent.flashing = false }
        Grid {
            id: ws
            readonly property var real: Hypr.workspacesOn(root.monitor)
            readonly property int curId: parent.cur
            // only the workspaces that exist on this screen (and the one you're on): no empty
            // placeholders for gaps, nothing from the other screen
            readonly property var list: {
                const out = real.slice(0, 20);
                if (curId > 0 && !out.some(w => w.id === curId))
                    out.push({ id: curId, name: String(curId), urgent: false, placeholder: true, toplevels: { values: [] } });
                out.sort((a, b) => a.id - b.id);
                return out;
            }
            readonly property string look: Config.s.workspaceStyle
            columns: root.vertical ? 1 : Math.max(1, list.length)
            rowSpacing: 7
            columnSpacing: ws.look === "numbers" ? 3 : 6
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                model: ws.list
                delegate: Item {
                    id: w
                    required property var modelData
                    readonly property bool active: modelData.id === ws.curId
                    readonly property bool occupied: modelData.toplevels.values.length > 0
                    readonly property bool named: modelData.name !== String(modelData.id)
                    implicitWidth: ws.look === "dots" ? (root.vertical ? 7 : (active ? 20 : 7))
                                 : ws.look === "diamonds" ? 11
                                 : Math.max(20, num.implicitWidth + 12)
                    implicitHeight: ws.look === "dots" ? (root.vertical ? (active ? 20 : 7) : 7)
                                  : ws.look === "diamonds" ? 11 : 20
                    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                    Behavior on implicitHeight { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                    Rectangle {
                        visible: ws.look === "dots"
                        anchors.fill: parent
                        radius: Math.min(width, height) / 2
                        color: w.active ? Theme.primary : w.modelData.urgent ? Theme.error : w.occupied ? Theme.surfaceTextDim : Theme.alpha(Theme.outline, 0.45)
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                    Rectangle {
                        visible: ws.look === "diamonds"
                        anchors.centerIn: parent
                        width: w.active ? 9 : 7
                        height: width
                        rotation: 45
                        radius: 1.5
                        color: w.active ? Theme.primary : "transparent"
                        border.width: w.active ? 0 : 1.3
                        border.color: w.occupied ? Theme.surfaceTextDim : Theme.outline
                    }
                    Rectangle {
                        visible: ws.look === "numbers"
                        anchors.fill: parent
                        radius: height / 2
                        color: w.active ? Theme.primary : "transparent"
                        Txt {
                            id: num
                            anchors.centerIn: parent
                            text: w.named ? w.modelData.name : w.modelData.id
                            font.family: Theme.mono
                            font.pixelSize: Theme.sm
                            color: w.active ? Theme.primaryText : w.occupied ? Theme.surfaceText : Theme.outline
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        // click: every workspace and its windows · middle: just go there · right: rename
                        onClicked: e => {
                            if (e.button === Qt.LeftButton) Ui.toggleOverlay("overview");
                            else if (e.button === Qt.MiddleButton) Hypr.focusWorkspace(w.modelData.id);
                            else { Hypr.focusWorkspace(w.modelData.id); Ui.open("rename"); }
                        }
                    }
                }
            }
        }
          // "3", sliding out beside the dots after a switch
          Txt {
              anchors.verticalCenter: parent.verticalCenter
              visible: ws.look !== "numbers" && !root.vertical
              text: parent.cur
              font.family: Theme.mono
              font.pixelSize: Theme.sm
              font.weight: Font.DemiBold
              color: Theme.primary
              opacity: parent.flashing ? 1 : 0
              width: parent.flashing ? implicitWidth : 0
              clip: true
              Behavior on opacity { NumberAnimation { duration: 220 } }
              Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
          }
        }
    }

    // ------------------------------------------------------------ notifications
    Component {
        id: notifC
        Chip {
            icon: Notifs.dnd ? "bell-off" : "bell"
            label: Notifs.count > 0 ? String(Notifs.count) : ""
            iconColor: Notifs.count > 0 ? Theme.primary : Theme.surfaceTextDim
            lit: Ui.panel === "notifications"
            onClicked: m => m.button === Qt.RightButton ? (Notifs.dnd = !Notifs.dnd) : root.openPanel("notifications")
        }
    }

    // ------------------------------------------------------------ cpu · mem · temp
    Component {
        id: cpuC
        Chip {
            Uses { service: Sys }
            icon: "cpu"
            label: Math.round(Sys.cpu * 100) + "%"
            iconColor: Sys.cpu > 0.85 ? Theme.error : Theme.surfaceTextDim
            onClicked: m => m.button === Qt.RightButton ? Quickshell.execDetached(["kitty", "-e", "btop"]) : Ui.toggleOverlay("system")
        }
    }
    Component {
        id: memC
        Chip {
            Uses { service: Sys }
            icon: "memory"
            label: Math.round(Sys.mem * 100) + "%"
            onClicked: m => m.button === Qt.RightButton ? Quickshell.execDetached(["kitty", "-e", "btop"]) : Ui.toggleOverlay("system")
        }
    }
    Component {
        id: tempC
        Chip {
            Uses { service: Sys }
            shown: Sys.cpuTemp >= 0
            icon: "temp"
            label: Math.round(Sys.cpuTemp) + "°"
            iconColor: Sys.cpuTemp > 85 ? Theme.error : Theme.surfaceTextDim
        }
    }

    // ------------------------------------------------------------ clock: "23:21  sun 30"
    Component {
        id: clockC
        Item {
            id: ck
            SystemClock { id: sc; precision: SystemClock.Minutes }
            implicitWidth: root.vertical ? 28 : hrow.implicitWidth + 12
            implicitHeight: root.vertical ? vcol.implicitHeight + 8 : 24
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Ui.panel === "calendar" ? Theme.alpha(Theme.primary, 0.2) : ckArea.containsMouse ? Theme.alpha(Theme.surfaceText, 0.08) : "transparent"
            }
            Row {
                id: hrow
                visible: !root.vertical
                anchors.centerIn: parent
                spacing: 7
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(sc.date, Config.s.clock24h ? "HH:mm" : "h:mm AP")
                    font.family: Theme.mono
                    font.pixelSize: Theme.md
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(sc.date, "ddd d")
                    font.family: Theme.mono
                    font.pixelSize: Theme.sm
                    color: Theme.outline
                }
            }
            Column {
                id: vcol
                visible: root.vertical
                anchors.centerIn: parent
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Config.s.clock24h ? Qt.formatTime(sc.date, "HH") : String(sc.date.getHours() % 12 || 12).padStart(2, "0")
                    font.family: Theme.mono; font.pixelSize: Theme.md; font.weight: Font.Medium
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(sc.date, "mm")
                    font.family: Theme.mono; font.pixelSize: Theme.md; font.weight: Font.Medium
                    color: Theme.primary
                }
            }
            MouseArea {
                id: ckArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openPanel("calendar")
            }
        }
    }

    // ------------------------------------------------------------ weather
    Component {
        id: weatherC
        Chip {
            Uses { service: Weather }
            shown: Weather.ready
            icon: Weather.icon
            label: Weather.temp + "°"
            onClicked: root.openPanel("calendar")
        }
    }

    // ------------------------------------------------------------ media: prev · play · next  title
    Component {
        id: mediaC
        Item {
            id: md
            property bool shown: Media.active
            implicitWidth: root.vertical ? 28 : mrow.implicitWidth + 12
            implicitHeight: root.vertical ? 28 : 24
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Ui.panel === "media" ? Theme.alpha(Theme.primary, 0.2) : "transparent"
            }
            Row {
                id: mrow
                visible: !root.vertical
                anchors.centerIn: parent
                spacing: 6
                // the cover, small and round-cornered, before the buttons
                ClippingRectangle {
                    visible: Media.art !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    radius: 5
                    color: Theme.surfaceHigh
                    Image {
                        anchors.fill: parent
                        source: Media.art
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPanel("media") }
                }
                Repeater {
                    model: ["prev", "toggle", "next"]
                    Item {
                        id: btn
                        required property string modelData
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        Icon {
                            anchors.centerIn: parent
                            name: btn.modelData === "prev" ? "prev" : btn.modelData === "next" ? "next" : Media.playing ? "pause" : "play"
                            size: btn.modelData === "toggle" ? 13 : 11
                            color: btnArea.containsMouse ? Theme.primary : Theme.surfaceTextDim
                        }
                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btn.modelData === "prev" ? Media.prev() : btn.modelData === "next" ? Media.next() : Media.toggle()
                        }
                    }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 140)
                    text: Media.title
                    font.family: Theme.mono
                    font.pixelSize: Theme.sm
                    color: Theme.surfaceText
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPanel("media") }
                }
            }
            // standing up: the cover, with play / pause over it
            ClippingRectangle {
                visible: root.vertical && Media.art !== ""
                anchors.centerIn: parent
                width: 22; height: 22
                radius: 6
                color: Theme.surfaceHigh
                Image { anchors.fill: parent; source: Media.art; sourceSize: Qt.size(48, 48); fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: 0.75 }
            }
            Icon {
                visible: root.vertical
                anchors.centerIn: parent
                name: Media.playing ? "pause" : "play"
                size: 14
                color: Theme.primary
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => e.button === Qt.RightButton ? root.openPanel("media") : Media.toggle()
                }
            }
        }
    }

    // ------------------------------------------------------------ a few bars of the music
    Component {
        id: visC
        Visualizer {
            property bool shown: Media.playing
            implicitWidth: root.vertical ? 16 : 18
            implicitHeight: root.vertical ? 16 : 12
            style: "bars"
            count: 4
            gap: 1.5
            minBar: 2
            color: Theme.primary
            fillOpacity: 0.9
        }
    }

    // ------------------------------------------------------------ volume · brightness
    Component {
        id: volC
        Chip {
            icon: Icons.volume(Audio.volume, Audio.muted)
            level: Audio.volume
            label: Math.round(Audio.volume * 100) + "%"
            iconColor: Audio.muted ? Theme.outline : Theme.surfaceTextDim
            wantsWheel: true
            lit: Ui.panel === "control"
            onClicked: m => m.button === Qt.RightButton ? Audio.toggleMute() : m.button === Qt.MiddleButton ? Quickshell.execDetached(["pavucontrol"]) : root.openPanel("control")
            onWheel: w => Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    Component {
        id: brightC
        Chip {
            shown: Bright.available
            icon: "sun"
            label: Math.round(Bright.value * 100) + "%"
            wantsWheel: true
            onClicked: root.openPanel("control")
            onWheel: w => w.angleDelta.y > 0 ? Bright.up() : Bright.down()
        }
    }

    // ------------------------------------------------------------ network · bluetooth
    Component {
        id: netC
        Chip {
            icon: Icons.net(Net.ethernet, Net.wifiEnabled, Net.ssid)
            level: Net.signal / 25
            iconColor: Net.connected ? Theme.surfaceTextDim : Theme.outline
            onClicked: { Ui.controlPage = "wifi"; root.openPanel("control"); }
        }
    }
    Component {
        id: btC
        Chip {
            shown: Bt.available
            icon: !Bt.enabled ? "bluetooth-off" : Bt.connectedDevices.length > 0 ? "bluetooth-on" : "bluetooth"
            iconColor: Bt.connectedDevices.length > 0 ? Theme.primary : Theme.surfaceTextDim
            onClicked: m => { if (m.button === Qt.RightButton) Bt.toggle(); else { Ui.controlPage = "bluetooth"; root.openPanel("control"); } }
        }
    }

    // ------------------------------------------------------------ battery
    Component {
        id: batC
        Chip {
            shown: Power.hasBattery
            icon: Icons.battery(Power.charging)
            level: Power.percent / 100
            label: Power.percent + "%"
            iconColor: Power.low ? Theme.error : Power.charging ? Theme.success : Theme.surfaceTextDim
            color: Power.low ? Theme.error : Theme.surfaceText
            onClicked: { Ui.controlPage = "battery"; root.openPanel("control"); }
        }
    }

    // ------------------------------------------------------------ tray
    Component {
        id: trayC
        Grid {
            columns: root.vertical ? 1 : Math.max(1, SystemTray.items.values.length)
            spacing: 8
            verticalItemAlignment: Grid.AlignVCenter
            horizontalItemAlignment: Grid.AlignHCenter
            Repeater {
                model: SystemTray.items
                delegate: TrayItem { menuEdge: root.menuEdge }
            }
        }
    }

    // ------------------------------------------------------------ control: wi-fi · sound · battery, one target
    Component {
        id: controlC
        Item {
            id: cc
            implicitWidth: root.vertical ? 28 : crow.implicitWidth + 16
            implicitHeight: root.vertical ? ccol.implicitHeight + 12 : 24
            readonly property bool lit: Ui.panel === "control"
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: cc.lit ? Theme.alpha(Theme.primary, 0.22) : cArea.containsMouse ? Theme.alpha(Theme.surfaceText, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
            Row {
                id: crow
                visible: !root.vertical
                anchors.centerIn: parent
                spacing: 9
                Icon { anchors.verticalCenter: parent.verticalCenter; size: 14; name: Icons.net(Net.ethernet, Net.wifiEnabled, Net.ssid); level: Net.signal / 25 }
                Icon { anchors.verticalCenter: parent.verticalCenter; size: 14; visible: Bt.connectedDevices.length > 0; name: "bluetooth-on" }
                Icon { anchors.verticalCenter: parent.verticalCenter; size: 14; name: Icons.volume(Audio.volume, Audio.muted); level: Audio.volume }
                Row {
                    visible: Power.hasBattery
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Icon { anchors.verticalCenter: parent.verticalCenter; size: 14; name: Icons.battery(Power.charging); level: Power.percent / 100; color: Power.low ? Theme.error : Theme.surfaceText }
                    Txt { anchors.verticalCenter: parent.verticalCenter; text: Power.percent + "%"; font.family: Theme.mono; font.pixelSize: Theme.sm; color: Power.low ? Theme.error : Theme.surfaceText }
                }
            }
            Column {
                id: ccol
                visible: root.vertical
                anchors.centerIn: parent
                spacing: 8
                Icon { anchors.horizontalCenter: parent.horizontalCenter; size: 15; name: Icons.net(Net.ethernet, Net.wifiEnabled, Net.ssid); level: Net.signal / 25 }
                Icon { anchors.horizontalCenter: parent.horizontalCenter; size: 15; name: Icons.volume(Audio.volume, Audio.muted); level: Audio.volume }
                Icon { anchors.horizontalCenter: parent.horizontalCenter; size: 15; visible: Power.hasBattery; name: Icons.battery(Power.charging); level: Power.percent / 100 }
            }
            MouseArea {
                id: cArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => e.button === Qt.RightButton ? Ui.toggle("settings") : root.openPanel("control")
                onWheel: w => Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
    }

    // ------------------------------------------------------------ apps: everything running
    Component {
        id: appsC
        Chip {
            Uses { service: Apps }
            icon: "grid"
            label: Apps.hiddenCount > 0 ? String(Apps.hiddenCount) : ""
            iconColor: Apps.hiddenCount > 0 ? Theme.primary : Theme.surfaceTextDim
            lit: Ui.panel === "running"
            onClicked: root.openPanel("running")
        }
    }

    // ------------------------------------------------------------ phone (kde connect)
    Component {
        id: phoneC
        Chip {
            shown: Phone.available && Phone.devices.length > 0
            icon: "phone"
            level: -1
            label: Phone.current && Phone.current.battery >= 0 ? Phone.current.battery + "%" : ""
            iconColor: Phone.current && Phone.current.reachable ? Theme.primary : Theme.outline
            lit: Ui.panel === "phone"
            onClicked: root.openPanel("phone")
        }
    }

    // ------------------------------------------------------------ power
    Component {
        id: powerC
        Chip {
            icon: "power"
            iconColor: Ui.panel === "session" ? Theme.error : Theme.surfaceTextDim
            lit: Ui.panel === "session"
            onClicked: root.openPanel("session")
        }
    }
}

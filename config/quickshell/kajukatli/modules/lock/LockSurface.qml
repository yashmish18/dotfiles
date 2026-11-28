import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// the lock screen. your wallpaper, heavily blurred and still, a huge clock, the date, what's
// playing, and a glass pill for the password. type to unlock; esc clears; enter checks.
Item {
    id: root
    required property var ctx
    focus: true

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) ctx.submit();
        else if (e.key === Qt.Key_Backspace) ctx.erase(!!(e.modifiers & Qt.ControlModifier));
        else if (e.key === Qt.Key_Escape) ctx.erase(true);
        else if (e.text && e.text.length > 0 && e.text.charCodeAt(0) >= 32 && !(e.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) ctx.type(e.text);
        e.accepted = true;
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var wall: Wall.current
    readonly property bool unlocking: ctx.phase === "ok"

    // fade in on lock, out on unlock
    property bool shown: false
    Component.onCompleted: { shown = true; forceActiveFocus(); }
    // after sleep (or anything else stealing it) take the keyboard back
    Connections {
        target: root.ctx
        function onWoke() { root.forceActiveFocus(); }
    }
    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: if (!root.activeFocus) root.forceActiveFocus()
    }
    opacity: shown && !unlocking ? 1 : 0
    // unlocking: the whole scene leans towards you as it fades
    scale: unlocking ? 1.06 : 1
    Behavior on scale { enabled: !Config.s.reducedMotion; NumberAnimation { duration: 480; easing.type: Easing.InCubic } }

    Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutCubic } }

    Rectangle { anchors.fill: parent; color: Theme.surfaceLowest }

    // ------------------------------------------------------------ the picture: blurred, still
    // kk-prep blurs it once (lock.jpg), so the lock screen draws one image and nothing moves:
    // no pointer tilt, no slow zoom, no subject cut-out. as light on the battery as a lock gets.
    Item {
        id: stage
        anchors.fill: parent

        Image {
            id: pic
            anchors.fill: parent
            source: root.wall ? "file://" + (root.wall.lock || root.wall.display) : ""
            sourceSize: Qt.size(Math.round(root.width / 2), Math.round(root.height / 2))   // it's blurred: half size is plenty
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
        }
        // not prepared yet (no lock.jpg): blur it here instead, once
        MultiEffect {
            anchors.fill: pic
            source: pic
            visible: root.wall !== null && !root.wall.lock
            blurEnabled: true
            blur: 1
            blurMax: 64
        }
        // a darker floor and ceiling so the text always reads
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.alpha("#000000", 0.35) }
                GradientStop { position: 0.45; color: Theme.alpha("#000000", 0.12) }
                GradientStop { position: 1.0; color: Theme.alpha("#000000", 0.6) }
            }
        }

        // the clock, in the middle
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.12
            spacing: -parent.height * 0.06
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Config.s.clock24h ? Qt.formatTime(clock.date, "HH") : String(clock.date.getHours() % 12 || 12).padStart(2, "0")
                font.family: Theme.display
                font.pixelSize: root.height * 0.3
                font.weight: Font.Black
                color: "#ffffff"
                renderType: Text.QtRendering
                opacity: 0.95
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "mm")
                font.family: Theme.display
                font.pixelSize: root.height * 0.3
                font.weight: Font.Black
                color: Theme.alpha("#ffffff", 0.82)
                renderType: Text.QtRendering
                opacity: 0.95
            }
        }
    }

    // ------------------------------------------------------------ top: the date and what's going on
    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 32
        Txt {
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: "#ffffff"
        }
        Item { Layout.fillWidth: true }
        Row {
            spacing: 16
            Row {
                visible: Notifs.count > 0
                spacing: 6
                Icon { name: "bell"; size: 16; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: Notifs.count; font.family: Theme.mono; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            }
            Icon { name: Icons.net(Net.ethernet, Net.wifiEnabled, Net.ssid); level: Net.signal / 25; size: 16; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            Row {
                visible: Power.hasBattery
                spacing: 6
                Icon { name: Icons.battery(Power.charging); level: Power.percent / 100; size: 16; color: Power.low ? Theme.error : "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: Power.percent + "%"; font.family: Theme.mono; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ------------------------------------------------------------ bottom: player and password
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.08
        spacing: 22

        // what's playing
        Rectangle {
            visible: Media.active
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 380
            implicitHeight: 72
            radius: 36
            color: Theme.alpha("#000000", 0.4)
            border.width: 1
            border.color: Theme.alpha("#ffffff", 0.12)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 14
                spacing: 12
                ClippingRectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: 26
                    color: Theme.surfaceHigh
                    Image { anchors.fill: parent; source: Media.cover; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(104, 104); asynchronous: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt { Layout.fillWidth: true; text: Media.title; font.weight: Font.DemiBold; color: "#ffffff" }
                    Txt { Layout.fillWidth: true; text: Media.artist; font.pixelSize: Theme.sm; color: Theme.alpha("#ffffff", 0.7) }
                }
                Icon { name: "prev"; size: 14; color: "#ffffff"; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: Media.prev() } }
                Rectangle {
                    implicitWidth: 38; implicitHeight: 38; radius: 19
                    color: Media.artColor
                    Icon { anchors.centerIn: parent; name: Media.playing ? "pause" : "play"; size: 16; color: Media.artText }
                    MouseArea { anchors.fill: parent; onClicked: Media.toggle() }
                }
                Icon { name: "next"; size: 14; color: "#ffffff"; MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: Media.next() } }
            }
        }

        // the password pill
        Rectangle {
            id: pill
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 340
            implicitHeight: 56
            radius: 28
            color: Theme.alpha("#000000", 0.45)
            border.width: 1.5
            border.color: root.ctx.phase === "wrong" ? Theme.error : root.ctx.password.length > 0 ? Theme.primary : Theme.alpha("#ffffff", 0.2)
            Behavior on border.color { ColorAnimation { duration: Theme.fast } }

            property real shake: 0
            transform: Translate { x: pill.shake }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: pill; property: "shake"; to: -12; duration: 50 }
                NumberAnimation { target: pill; property: "shake"; to: 10; duration: 70 }
                NumberAnimation { target: pill; property: "shake"; to: -6; duration: 70 }
                NumberAnimation { target: pill; property: "shake"; to: 0; duration: 60 }
            }
            Connections {
                target: root.ctx
                function onPhaseChanged() { if (root.ctx.phase === "wrong") shakeAnim.restart(); }
            }

            Rectangle {
                id: avatar
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: Theme.primary
                Icon { anchors.centerIn: parent; name: "lock"; size: 18; color: Theme.primaryText }
            }
            // the typed characters as dots that pop in
            Row {
                anchors.left: avatar.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                visible: root.ctx.password.length > 0
                Repeater {
                    model: Math.min(root.ctx.password.length, 18)
                    Rectangle {
                        width: 9; height: 9; radius: 4.5
                        color: root.ctx.phase === "checking" ? Theme.primary : "#ffffff"
                        scale: 0
                        Component.onCompleted: scale = 1
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    }
                }
            }
            Txt {
                anchors.left: avatar.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: root.ctx.password.length === 0
                text: root.ctx.phase === "wrong" ? root.ctx.note : "Type your password"
                color: root.ctx.phase === "wrong" ? Theme.error : Theme.alpha("#ffffff", 0.65)
            }
            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                name: root.ctx.phase === "checking" ? "restart" : "right"
                size: 18
                color: "#ffffff"
                opacity: root.ctx.password.length > 0 ? 1 : 0.3
                RotationAnimation on rotation { running: root.ctx.phase === "checking"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
            }
        }

        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: (Quickshell.env("USER") || "") + "  ·  enter to unlock"
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            color: Theme.alpha("#ffffff", 0.5)
        }
    }

    // ------------------------------------------------------------ power, bottom right
    // sleep and hibernate go at once; restart and shut down want a second click
    Row {
        id: powerRow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 36
        spacing: 12
        opacity: root.unlocking ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 300 } }
        property string armed: ""
        Timer { id: disarm; interval: 3000; onTriggered: powerRow.armed = "" }

        Repeater {
            model: [
                { key: "sleep", word: "Sleep", icon: "moon", cmd: ["systemctl", "suspend"], ask: false },
                { key: "hibernate", word: "Hibernate", icon: "snow", cmd: ["systemctl", "hibernate"], ask: false },
                { key: "reboot", word: "Restart", icon: "restart", cmd: ["systemctl", "reboot"], ask: true },
                { key: "off", word: "Shut down", icon: "power", cmd: ["systemctl", "poweroff"], ask: true }
            ]
            delegate: Item {
                id: pb
                required property var modelData
                readonly property bool armedHere: powerRow.armed === modelData.key
                width: 46
                height: 46 + 22
                Rectangle {
                    id: pdisc
                    width: 46; height: 46; radius: 23
                    color: pb.armedHere ? Theme.error : Theme.alpha("#ffffff", parea.containsMouse ? 0.22 : 0.1)
                    border.width: 1
                    border.color: Theme.alpha("#ffffff", 0.16)
                    scale: parea.pressed ? 0.92 : parea.containsMouse ? 1.08 : 1
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    Icon { anchors.centerIn: parent; name: pb.modelData.icon; size: 19; color: pb.armedHere ? Theme.errorText : "#ffffff" }
                }
                Txt {
                    anchors.top: pdisc.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: pdisc.horizontalCenter
                    text: pb.armedHere ? "again" : pb.modelData.word
                    visible: parea.containsMouse || pb.armedHere
                    font.pixelSize: Theme.xs + 1
                    color: Theme.alpha("#ffffff", 0.8)
                }
                MouseArea {
                    id: parea
                    anchors.fill: pdisc
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (pb.modelData.ask && powerRow.armed !== pb.modelData.key) { powerRow.armed = pb.modelData.key; disarm.restart(); return; }
                        Quickshell.execDetached(pb.modelData.cmd);
                    }
                }
            }
        }
    }
}

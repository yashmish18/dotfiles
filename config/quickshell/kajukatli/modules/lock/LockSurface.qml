import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// the lock screen. your wallpaper, slowly drifting, with a huge clock tucked behind its
// subject (when the wallpaper has one), the date, what's playing, and a glass pill for the
// password. type to unlock; esc clears; enter checks.
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
    readonly property bool hasMask: wall !== null && !!wall.mask && maskImg.status === Image.Ready
    readonly property bool unlocking: ctx.phase === "ok"

    // fade in on lock, out on unlock
    property bool shown: false
    Component.onCompleted: { shown = true; forceActiveFocus(); }
    opacity: shown && !unlocking ? 1 : 0
    // unlocking: the whole scene leans towards you as it fades
    scale: unlocking ? 1.06 : 1
    Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.InCubic } }

    // the pointer tilts the scene: the clock floats on its own plane, the picture behind it
    property real mx: 0
    property real my: 0
    Behavior on mx { SmoothedAnimation { velocity: 0.9 } }
    Behavior on my { SmoothedAnimation { velocity: 0.9 } }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: !Power.onBattery
        acceptedButtons: Qt.NoButton
        onPositionChanged: e => { root.mx = e.x / width * 2 - 1; root.my = e.y / height * 2 - 1; }
    }
    // the clock keeps time with the music
    Uses { service: Cava; active: Media.playing && Config.s.clockPulse }
    Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutCubic } }

    Rectangle { anchors.fill: parent; color: Theme.surfaceLowest }

    // ------------------------------------------------------------ the picture, drifting
    Item {
        id: stage
        anchors.fill: parent
        property real drift: 0
        // a slow push-in (stops on battery)
        SequentialAnimation on drift {
            running: !Power.onBattery
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 1; duration: 40000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1; to: 0; duration: 40000; easing.type: Easing.InOutSine }
        }
        scale: 1.04 + stage.drift * 0.05
        transform: Translate { x: root.mx * 10; y: root.my * 7 }
        transformOrigin: Item.Center

        Image {
            id: pic
            anchors.fill: parent
            source: root.wall ? "file://" + root.wall.display : ""
            sourceSize: Qt.size(root.width, root.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        // a darker floor and ceiling so the text always reads
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.alpha("#000000", 0.35) }
                GradientStop { position: 0.45; color: Theme.alpha("#000000", 0.05) }
                GradientStop { position: 1.0; color: Theme.alpha("#000000", 0.6) }
            }
        }

        // the clock, in the middle of the picture: behind the subject when there is one
        Column {
            transform: Translate { x: -root.mx * 26; y: -root.my * 16 }
            scale: 1 + (Media.playing && Config.s.clockPulse ? Cava.level * 0.05 : 0)
            Behavior on scale { NumberAnimation { duration: 90 } }
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.12
            spacing: -parent.height * 0.06
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, Config.s.clock24h ? "HH" : "hh")
                font.family: Theme.display
                font.pixelSize: root.height * 0.3
                font.weight: Font.Black
                color: Theme.wallText
                renderType: Text.QtRendering
                opacity: 0.95
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "mm")
                font.family: Theme.display
                font.pixelSize: root.height * 0.3
                font.weight: Font.Black
                color: Theme.wallText
                renderType: Text.QtRendering
                opacity: 0.95
            }
        }

        // the subject, laid back over the clock
        Image {
            id: maskImg
            anchors.fill: parent
            visible: false
            source: root.wall && root.wall.mask ? "file://" + root.wall.mask : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: pic
            visible: root.hasMask
            source: pic
            maskEnabled: true
            maskSource: maskImg
            maskThresholdMin: 0.2
            maskSpreadAtMin: 0.6
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
                    Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(104, 104); asynchronous: true }
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
}

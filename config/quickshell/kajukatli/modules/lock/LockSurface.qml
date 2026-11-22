import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.services
import qs.components

// a frame of black & white film.
//
//   top edge     sprocket holes and edge print: stock name, frame numbers (+1 each time you lock)
//   picture      your wallpaper, desaturated, a stop under, grain moving at 12 fps,
//                a slow drift and a warm light leak that comes and goes
//   bottom left  a line for the hour, the time, the date, and where you type
//   bottom right what's playing, the battery, who this is
Item {
    id: root
    required property var ctx
    focus: true

    Component.onCompleted: forceActiveFocus()

    // ------------------------------------------------------------------ keys
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) ctx.submit();
        else if (e.key === Qt.Key_Backspace) ctx.erase(!!(e.modifiers & Qt.ControlModifier));
        else if (e.key === Qt.Key_Escape) ctx.erase(true);
        else if (e.text && e.text.length > 0 && e.text.charCodeAt(0) >= 32 && !(e.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) ctx.type(e.text);
        else return;
        e.accepted = true;
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
    readonly property int frameNo: Store.s.frame

    // original lines. one per lock, chosen by the frame number.
    readonly property var lines: [
        "the room is still warm from you.",
        "nothing moves at this hour but the light.",
        "you left the radio on. it's playing to no one.",
        "smoke climbs like it has somewhere to be.",
        "the city hums the same three notes all night.",
        "stay a little. the coffee went cold anyway.",
        "we were always better in black and white.",
        "every streetlight is a small, patient moon.",
        "slow down. nobody's waiting at the end of the song.",
        "it's late in the way that makes everything honest.",
        "the window remembers rain you didn't hear.",
        "somewhere a train is leaving without anyone.",
        "half a song, half asleep, half here.",
        "the ashtray knows more than the diary.",
        "keep the lights low. the night is listening.",
        "your name still sounds like a slow song."
    ]
    readonly property string line: lines[frameNo % lines.length]

    // ------------------------------------------------------------------ the picture
    Image {
        id: pic
        visible: false
        asynchronous: true
        source: Wall.current ? "file://" + Wall.current.display : ""
        sourceSize: Qt.size(root.width, root.height)
    }

    property real t: 0
    Timer {
        // grain moves at projector speed; on battery it holds still
        running: !Power.onBattery
        interval: 83
        repeat: true
        onTriggered: root.t += 0.083
    }
    property real driftX: 0
    SequentialAnimation on driftX {
        loops: Animation.Infinite
        running: !Power.onBattery
        NumberAnimation { from: -0.012; to: 0.012; duration: 38000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.012; to: -0.012; duration: 38000; easing.type: Easing.InOutSine }
    }
    property real leak: 0
    SequentialAnimation on leak {
        loops: Animation.Infinite
        running: !Power.onBattery
        PauseAnimation { duration: 6000 }
        NumberAnimation { to: 1; duration: 9000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.15; duration: 12000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 7000; easing.type: Easing.InOutSine }
    }

    ShaderEffect {
        id: film
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../../shaders/film.frag.qsb")
        property var src: pic
        property real time: root.t
        property real grain: 0.085
        property real exposure: pic.status === Image.Ready ? 0.58 : 0.0
        property real aspect: root.height > 0 ? root.width / root.height : 1.6
        property vector2d cover: {
            if (pic.status !== Image.Ready || pic.implicitHeight === 0) return Qt.vector2d(1, 1);
            const S = root.width / root.height, I = pic.implicitWidth / pic.implicitHeight;
            const z = 0.95;
            return S > I ? Qt.vector2d(z, z * I / S) : Qt.vector2d(z * S / I, z);
        }
        property vector2d drift: Qt.vector2d(root.driftX, root.driftX * -0.4)
        property real leak: root.leak
        // fade up from black, like a projector warming
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 1400; easing.type: Easing.OutQuad } }
    }

    // ------------------------------------------------------------------ edge print
    Item {
        id: edge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 34
        opacity: content.opacity * 0.9

        Rectangle { anchors.fill: parent; color: "#070707" }

        // sprocket holes
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -4
            x: 14
            spacing: 18
            Repeater {
                model: Math.ceil(root.width / 30)
                delegate: Rectangle {
                    width: 12
                    height: 8
                    radius: 2
                    color: "#161514"
                }
            }
        }

        // the print along the rebate, in the faded orange film edges have
        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            x: 22
            spacing: 64
            Repeater {
                model: Math.ceil(root.width / 260)
                delegate: Txt {
                    required property int index
                    readonly property int n: root.frameNo + index
                    text: index === 0 ? "KJK 400  ▸ " + n + "    " + n + "A"
                        : (index % 3 === 2 ? "SAFETY FILM    " : "") + "▸ " + n + "    " + n + "A"
                    font.family: Theme.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1.5
                    color: "#7a5a3c"
                    opacity: 0.85
                }
            }
        }
    }

    // ------------------------------------------------------------------ the words
    Item {
        id: content
        anchors.fill: parent
        opacity: root.ctx.phase === "ok" ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InQuad } }

        ColumnLayout {
            id: left
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 76
            anchors.bottomMargin: 70
            spacing: 0

            Txt {
                visible: Config.s.lockPoetry
                text: root.line
                font.pixelSize: 19
                color: Theme.muted
                Layout.bottomMargin: 6
                Layout.leftMargin: 6
            }

            Row {
                spacing: 0
                Txt {
                    text: Qt.formatTime(clock.date, Config.s.clock24h ? "HH" : "h")
                    font.weight: Font.ExtraLight
                    font.pixelSize: 168
                    font.letterSpacing: -4
                    color: Theme.paper
                }
                // the colon breathes, slower than a second, like someone asleep
                Txt {
                    text: ":"
                    font.weight: Font.ExtraLight
                    font.pixelSize: 168
                    color: Theme.accent
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 2200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutSine }
                    }
                }
                Txt {
                    text: Qt.formatTime(clock.date, "mm")
                    font.weight: Font.ExtraLight
                    font.pixelSize: 168
                    font.letterSpacing: -4
                    color: Theme.paper
                }
                Txt {
                    visible: !Config.s.clock24h
                    text: Qt.formatTime(clock.date, "ap").toLowerCase()
                    font.family: Theme.mono
                    font.pixelSize: Theme.md
                    color: Theme.muted
                    y: 118
                    leftPadding: 10
                }
            }

            Txt {
                text: Qt.formatDate(clock.date, "dddd").toLowerCase() + "  —  " + Qt.formatDate(clock.date, "d MMMM").toLowerCase()
                font.family: Theme.mono
                font.pixelSize: Theme.md
                font.letterSpacing: 1
                color: Theme.muted
                Layout.leftMargin: 8
                Layout.topMargin: -6
            }

            // ------------------------------------------------ where you type
            Item {
                id: entry
                Layout.leftMargin: 8
                Layout.topMargin: 40
                implicitWidth: 300
                implicitHeight: 46

                property real shake: 0
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: entry; property: "shake"; to: -9; duration: 50 }
                    NumberAnimation { target: entry; property: "shake"; to: 7; duration: 70 }
                    NumberAnimation { target: entry; property: "shake"; to: -4; duration: 70 }
                    NumberAnimation { target: entry; property: "shake"; to: 0; duration: 90 }
                }
                Connections {
                    target: root.ctx
                    function onPhaseChanged() { if (root.ctx.phase === "wrong") shakeAnim.restart(); }
                }

                Item {
                    x: entry.shake
                    width: parent.width
                    height: parent.height

                    Txt {
                        id: dots
                        anchors.left: parent.left
                        anchors.bottom: rule.top
                        anchors.bottomMargin: 8
                        visible: root.ctx.password.length > 0
                        text: "·".repeat(Math.min(root.ctx.password.length, 24))
                        font.pixelSize: 30
                        font.letterSpacing: 7
                        color: root.ctx.phase === "checking" ? Theme.accent : Theme.paper
                        SequentialAnimation on opacity {
                            running: root.ctx.phase === "checking"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 380 }
                            NumberAnimation { to: 1; duration: 380 }
                            onRunningChanged: if (!running) dots.opacity = 1
                        }
                    }
                    Txt {
                        anchors.left: parent.left
                        anchors.bottom: rule.top
                        anchors.bottomMargin: 10
                        visible: root.ctx.password.length === 0
                        text: root.ctx.phase === "wrong" ? root.ctx.note : "say the word"
                        font.pixelSize: Theme.lg + 1
                        color: root.ctx.phase === "wrong" ? Theme.danger : Theme.faint
                    }

                    Rectangle {
                        id: rule
                        anchors.bottom: parent.bottom
                        height: 1
                        width: root.ctx.phase === "ok" ? root.width * 0.6 : parent.width
                        color: root.ctx.phase === "wrong" ? Theme.danger : root.ctx.password.length > 0 ? Theme.accent : Theme.line
                        Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                }
            }
        }

        // ------------------------------------------------ right column
        ColumnLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 76
            anchors.bottomMargin: 74
            spacing: 4

            ColumnLayout {
                visible: root.player !== null
                spacing: 2
                Layout.alignment: Qt.AlignRight
                Layout.bottomMargin: 26
                Txt {
                    Layout.alignment: Qt.AlignRight
                    text: "now playing"
                    font.family: Theme.mono
                    font.pixelSize: Theme.xs
                    font.letterSpacing: 1
                    color: Theme.faint
                }
                Txt {
                    Layout.alignment: Qt.AlignRight
                    Layout.maximumWidth: 360
                    text: root.player ? (root.player.trackTitle || "") : ""
                    font.pixelSize: Theme.lg + 2
                    horizontalAlignment: Text.AlignRight
                }
                Txt {
                    Layout.alignment: Qt.AlignRight
                    Layout.maximumWidth: 360
                    text: root.player ? (root.player.trackArtist || "").toLowerCase() : ""
                    color: Theme.muted
                    font.pixelSize: Theme.sm
                    horizontalAlignment: Text.AlignRight
                }
                Row {
                    Layout.alignment: Qt.AlignRight
                    Layout.rightMargin: -6
                    Btn { text: "prev"; enabled: root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
                    Btn { text: "pause"; enabled: root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
                    Btn { text: "next"; enabled: root.player && root.player.canGoNext; onClicked: root.player.next() }
                }
            }

            Txt {
                Layout.alignment: Qt.AlignRight
                visible: Power.hasBattery
                text: Power.batteryLabel + (Power.charging ? " · charging" : Power.timeLeft ? " · " + Power.timeLeft : "")
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                color: Power.low ? Theme.danger : Theme.muted
            }
            Txt {
                Layout.alignment: Qt.AlignRight
                text: (Quickshell.env("USER") || "") + "  ·  frame " + root.frameNo
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                color: Theme.faint
            }
        }
    }

    // clicking anywhere gives the keyboard back to this screen
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.forceActiveFocus()
    }
}

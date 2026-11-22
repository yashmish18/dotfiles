import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// what's playing, on the desktop. three cuts:
//   lyrics    cover, synced lyrics scrolling beside it, a wavy seek bar
//   card      small: cover, a few visualiser bars, title, seek bar
//   portrait  tall: the cover fills it, title over a fade at the bottom
// it hides itself when no player is around.
Item {
    id: root
    property string style: "lyrics"
    readonly property bool show: Media.active

    implicitWidth: show ? body.width : 0
    implicitHeight: show ? body.height : 0
    visible: show

    Uses { service: Media; active: root.show }
    // lyrics are only fetched while the lyrics card is up
    Component.onCompleted: syncLyrics()
    Component.onDestruction: if (lyricsOn) Media.lyricsUsers -= 1
    property bool lyricsOn: false
    readonly property bool wantLyrics: show && style === "lyrics"
    onWantLyricsChanged: syncLyrics()
    function syncLyrics() {
        if (wantLyrics === lyricsOn) return;
        Media.lyricsUsers += wantLyrics ? 1 : -1;
        lyricsOn = wantLyrics;
    }

    component Controls: Row {
        id: ctl
        property color tint: Media.artColor
        property int size: 30
        spacing: 10
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "prev"
            size: 14
            color: Theme.surfaceText
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Media.prev() }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: ctl.size
            height: ctl.size
            radius: ctl.size / 2
            color: Media.artColor
            Icon {
                anchors.centerIn: parent
                name: Media.playing ? "pause" : "play"
                size: ctl.size * 0.48
                color: Media.artText
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.toggle() }
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "next"
            size: 14
            color: Theme.surfaceText
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Media.next() }
        }
    }

    component Cover: Rectangle {
        id: cv
        property int r: Theme.radiusSmall
        radius: r
        color: Theme.surfaceHigh
        clip: true
        Image {
            id: img
            anchors.fill: parent
            source: Media.art
            asynchronous: true
            sourceSize: Qt.size(cv.width * 2, cv.height * 2)
            visible: false
        }
        // cropped to cover and rounded in one pass (shaders/round.frag)
        ShaderEffect {
            anchors.fill: parent
            visible: img.status === Image.Ready
            property var src: img
            property vector2d size: Qt.vector2d(width, height)
            property real radius: cv.r
            readonly property real imgAspect: img.implicitHeight > 0 ? img.implicitWidth / img.implicitHeight : 1
            readonly property real boxAspect: height > 0 ? width / height : 1
            property vector2d cover: boxAspect > imgAspect ? Qt.vector2d(1, imgAspect / boxAspect) : Qt.vector2d(boxAspect / imgAspect, 1)
            fragmentShader: Qt.resolvedUrl("../../shaders/round.frag.qsb")
        }
        Icon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            name: "music"
            size: cv.height * 0.3
            color: Theme.outline
        }
    }

    Loader {
        id: body
        sourceComponent: root.style === "card" ? cardC : root.style === "portrait" ? portraitC : lyricsC
        width: item ? item.implicitWidth : 0
        height: item ? item.implicitHeight : 0
    }

    // ------------------------------------------------------------ lyrics
    Component {
        id: lyricsC
        Rectangle {
            implicitWidth: 470
            implicitHeight: 250
            radius: Theme.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)

            Cover {
                id: art
                x: 14; y: 14
                width: 140; height: 140
                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    visible: Media.playing
                    text: "ılı"
                    font.pixelSize: 13
                    font.bold: true
                    color: "white"
                }
            }

            // lyrics: the current line in the accent, the rest dim; scrolls to keep it in view
            Item {
                id: lyr
                anchors.left: art.right
                anchors.leftMargin: 18
                anchors.right: parent.right
                anchors.rightMargin: 34
                y: 18
                height: 132
                clip: true
                ListView {
                    id: lv
                    anchors.fill: parent
                    model: Media.lines
                    interactive: false
                    spacing: 4
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 22
                    preferredHighlightEnd: 60
                    highlightMoveDuration: 420
                    currentIndex: Math.max(0, Media.lineIndex)
                    delegate: Text {
                        required property var modelData
                        required property int index
                        width: lv.width
                        text: modelData.text || "♪"
                        wrapMode: Text.WordWrap
                        font.family: Theme.sans
                        font.pixelSize: 13
                        font.weight: index === Media.lineIndex ? Font.Bold : Font.Normal
                        color: index === Media.lineIndex ? Media.artColor : Theme.surfaceTextDim
                        opacity: index === Media.lineIndex ? 1 : Media.synced ? Math.max(0.25, 0.8 - Math.abs(index - Media.lineIndex) * 0.18) : 0.8
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                }
                Txt {
                    anchors.centerIn: parent
                    visible: Media.lines.length === 0
                    text: Media.lyricsState === "loading" ? "finding the words…" : Config.s.lyrics ? "no lyrics for this one" : "lyrics are off"
                    font.pixelSize: 12
                    color: Theme.outline
                }
            }
            Icon {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 14
                name: "music"
                size: 12
                color: Theme.outline
            }

            Column {
                x: 16
                y: 168
                width: 300
                Txt { width: parent.width; text: Media.title; font.pixelSize: 17; font.weight: Font.Medium }
                Txt { width: parent.width; text: Media.artist; font.pixelSize: 11; color: Theme.surfaceTextDim }
            }
            Txt {
                anchors.right: parent.right
                anchors.rightMargin: 16
                y: 186
                text: Media.fmt(Media.position) + " / " + Media.fmt(Media.length)
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.surfaceTextDim
            }
            RowLayout {
                x: 16
                y: 212
                width: parent.width - 32
                spacing: 14
                WavyProgress {
                    Layout.fillWidth: true
                    value: Media.progress
                    moving: Media.playing
                    color: Media.artColor
                    onSeek: f => Media.seek(f)
                }
                Controls {}
            }
        }
    }

    // ------------------------------------------------------------ card
    Component {
        id: cardC
        Rectangle {
            implicitWidth: 240
            implicitHeight: 128
            radius: Theme.radiusSmall
            color: Theme.glass
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)
            Cover { id: cart; x: 8; y: 8; width: 72; height: 72 }
            Visualizer {
                anchors.left: cart.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 10
                y: 18
                height: 48
                style: "mirror"
                count: 32
                gap: 1
                color: Theme.primary
                fillOpacity: 0.8
            }
            Txt {
                x: 10; y: 86
                width: parent.width - 20
                text: Media.title + (Media.artist ? " – " + Media.artist : "")
                font.weight: Font.Bold
                font.pixelSize: 10
            }
            RowLayout {
                x: 10; y: 104
                width: parent.width - 20
                spacing: 8
                WavyProgress {
                    Layout.fillWidth: true
                    implicitHeight: 10
                    amplitude: 2
                    wavelength: 7
                    thickness: 1.6
                    value: Media.progress
                    moving: Media.playing
                    color: Media.artColor
                    onSeek: f => Media.seek(f)
                }
                Controls { size: 18; spacing: 6 }
            }
        }
    }

    // ------------------------------------------------------------ portrait
    Component {
        id: portraitC
        Item {
            implicitWidth: 226
            implicitHeight: 398
            Cover {
                anchors.fill: parent
                r: Theme.radiusSmall
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                gradient: Gradient {
                    GradientStop { position: 0.55; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.alpha("#000000", 0.82) }
                }
            }
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                spacing: 6
                Txt {
                    width: parent.width
                    text: Media.title
                    font.weight: Font.Bold
                    font.pixelSize: 14
                    color: "#ffffff"
                }
                Txt {
                    width: parent.width
                    text: Media.artist.toUpperCase()
                    font.family: Theme.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1
                    color: "#d0d0d0"
                }
                RowLayout {
                    width: parent.width
                    spacing: 8
                    WavyProgress {
                        Layout.fillWidth: true
                        implicitHeight: 12
                        amplitude: 2.5
                        wavelength: 9
                        value: Media.progress
                        moving: Media.playing
                        onSeek: f => Media.seek(f)
                    }
                    Controls { size: 26; spacing: 8 }
                }
            }
        }
    }
}

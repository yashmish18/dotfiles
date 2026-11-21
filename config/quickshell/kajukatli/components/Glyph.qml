import QtQuick
import qs.services

// an icon from Symbols Nerd Font. used sparingly: most things here are words.
Text {
    property string g: ""
    text: g
    color: Theme.paper
    font.family: Theme.glyph
    font.pixelSize: Theme.md
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}

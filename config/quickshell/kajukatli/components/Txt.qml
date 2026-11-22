import QtQuick
import qs.services

// default text: the interface face, on-surface colour, one line
Text {
    color: Theme.surfaceText
    font.family: Theme.sans
    font.pixelSize: Theme.md
    font.weight: Font.Normal
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}

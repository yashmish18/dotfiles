import QtQuick
import qs.services

// default text: paper on ink, the sans, no surprises
Text {
    color: Theme.paper
    font.family: Theme.sans
    font.pixelSize: Theme.md
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}

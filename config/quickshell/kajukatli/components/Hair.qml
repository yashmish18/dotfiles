import QtQuick
import qs.services

// a quiet divider
Rectangle {
    property bool vertical: false
    implicitWidth: vertical ? 1 : 10
    implicitHeight: vertical ? 10 : 1
    color: Theme.alpha(Theme.outlineVariant, 0.55)
}

import QtQuick
import qs.services

// a 1px rule
Rectangle {
    property bool vertical: false
    implicitWidth: vertical ? 1 : 10
    implicitHeight: vertical ? 10 : 1
    color: Theme.line
}

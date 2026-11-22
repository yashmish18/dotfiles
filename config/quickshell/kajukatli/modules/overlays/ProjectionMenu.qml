import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.components

Item {
    id: root
    property var monitors: []
    property string status: ""

    Process {
        id: refresh
        command: ["sh", "-c", "hyprctl monitors -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.monitors = JSON.parse(text); root.status = ""; }
                catch (e) { root.status = "Could not read displays"; }
            }
        }
        Component.onCompleted: running = true
    }

    readonly property var externalMonitors: monitors.filter(m => !/^(eDP|LVDS|DSI)/.test(m.name))
    readonly property var internalMonitors: monitors.filter(m => /^(eDP|LVDS|DSI)/.test(m.name))
    readonly property string externalName: externalMonitors.length ? externalMonitors[0].name : ""
    readonly property string internalName: internalMonitors.length ? internalMonitors[0].name : (monitors.length ? monitors[0].name : "")

    function apply(mode) {
        Ui.projectionMode = mode;
        Quickshell.execDetached([Config.bin + "kk-display", mode]);
        statusTimer.restart();
        refreshTimer.restart();
    }

    Timer { id: statusTimer; interval: 700; onTriggered: root.status = "Display mode applied" }
    Timer { id: refreshTimer; interval: 1100; onTriggered: refresh.running = true }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 720)
        height: Math.min(parent.height - 48, 470)
        radius: 22
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 2
                    Txt { text: "Projection"; font.pixelSize: Theme.xl; font.weight: Font.Bold }
                    Txt {
                        text: root.status !== "" ? root.status
                            : root.externalName !== "" ? root.internalName + " + " + root.externalName
                            : "No external display detected"
                        font.pixelSize: Theme.sm
                        color: Theme.surfaceTextDim
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: 17
                    color: Theme.surfaceHigh
                    MouseArea { anchors.fill: parent; onClicked: Ui.overlay = "" }
                    Txt { anchors.centerIn: parent; text: "×"; font.pixelSize: Theme.lg }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                rowSpacing: 12
                columnSpacing: 12

                Repeater {
                    model: [
                        { mode: "internal", icon: "laptop", title: "Laptop", detail: "Only the built-in screen" },
                        { mode: "external", icon: "monitor", title: "External", detail: "Only the HDMI/DP screen" },
                        { mode: "extend", icon: "desktop", title: "Extend", detail: "Add screen to the right" },
                        { mode: "mirror", icon: "copy", title: "Duplicate", detail: "Mirror the laptop screen" },
                        { mode: "left", icon: "arrow-left", title: "Extend left", detail: "Place HDMI/DP on the left" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 16
                        color: Ui.projectionMode === modelData.mode ? Theme.primaryContainer : Theme.surfaceHigh
                        border.width: 1
                        border.color: Ui.projectionMode === modelData.mode ? Theme.primary : Theme.outlineVariant

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 8
                            Icon { Layout.alignment: Qt.AlignHCenter; name: modelData.icon; size: 34; color: Ui.projectionMode === modelData.mode ? Theme.primaryContainerText : Theme.primary }
                            Txt { Layout.alignment: Qt.AlignHCenter; text: modelData.title; font.pixelSize: Theme.md; font.weight: Font.Bold }
                            Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData.detail; font.pixelSize: Theme.xs; color: Theme.surfaceTextDim; wrapMode: Text.Wrap }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.apply(modelData.mode)
                            enabled: modelData.mode === "internal" || root.externalName !== ""
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: Theme.surfaceHigh
                    border.width: 1
                    border.color: Theme.outlineVariant
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 8
                        Icon { Layout.alignment: Qt.AlignHCenter; name: "refresh"; size: 34; color: Theme.primary }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: "Rescan"; font.weight: Font.Bold }
                        Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Detect a newly connected cable"; font.pixelSize: Theme.xs; color: Theme.surfaceTextDim; wrapMode: Text.Wrap }
                    }
                    MouseArea { anchors.fill: parent; onClicked: refresh.running = true }
                }
            }
        }
    }
}

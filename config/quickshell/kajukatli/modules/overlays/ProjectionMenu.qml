import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// super + d: what goes on the external screen. every mode can follow every other one; the
// highlighted card is what the screens are doing right now (read back from hyprland, not
// remembered), and rescan says what it found.
Item {
    id: root
    property var info: ({ internal: "", external: "", mode: "internal", screens: [] })
    property string status: ""
    property bool busy: false          // a mode is being applied
    property bool scanning: false
    property string pending: ""        // the mode just picked, until hyprland confirms it

    readonly property string externalName: info.external || ""
    readonly property string current: pending !== "" ? pending : (info.mode || "internal")

    Process {
        id: read
        command: [Config.bin + "kk-display", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const was = root.info.external || "";
                    root.info = JSON.parse(text.trim());
                    if (root.scanning) {
                        const n = (root.info.screens || []).length;
                        root.status = root.info.external !== ""
                            ? (was === "" ? "Found " + root.info.external : root.info.external + " is connected")
                            : "Only the built-in screen (" + n + " found). Check the cable, or run kk-hdmi.";
                    }
                } catch (e) {
                    root.status = "Could not read the displays";
                }
                root.scanning = false;
                if (!root.busy) root.pending = "";
            }
        }
        Component.onCompleted: running = true
    }
    function rescan() {
        if (scanning) return;
        scanning = true;
        status = "Looking for screens…";
        // a real re-probe of the ports (hyprland notices new cables on its own; this nudges
        // drm to look again), then read the result
        Quickshell.execDetached(["sh", "-c", "for c in /sys/class/drm/card*-*/status; do cat \"$c\" >/dev/null 2>&1; done"]);
        scanTimer.restart();
    }
    Timer { id: scanTimer; interval: 1200; onTriggered: read.running = true }

    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErr }
        onExited: code => {
            root.busy = false;
            root.status = code === 0 ? "" : (applyErr.text.trim() || "That didn't work");
            settle.restart();
        }
    }
    Timer { id: settle; interval: 700; onTriggered: read.running = true }
    function apply(mode: var) {
        if (busy) return;
        busy = true;
        pending = mode;
        Ui.projectionMode = mode;
        System.forgetLayout();
        status = "Switching…";
        applyProc.command = [Config.bin + "kk-display", mode];
        applyProc.running = true;
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 720)
        height: Math.min(parent.height - 48, 440)
        radius: 22
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant
        MouseArea { anchors.fill: parent }       // clicks on the card don't close the overlay

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
                            : root.externalName !== "" ? root.info.internal + " + " + root.externalName
                            : "No external display detected"
                        font.pixelSize: Theme.sm
                        color: root.status.indexOf("Found") === 0 ? Theme.primary : Theme.surfaceTextDim
                    }
                }
                Item { Layout.fillWidth: true }
                Btn { text: "Arrange & tune"; icon: "sliders"; onClicked: Ui.overlay = "displays" }
                Btn { icon: "close"; onClicked: Ui.overlay = "" }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                rowSpacing: 12
                columnSpacing: 12

                Repeater {
                    model: [
                        { mode: "internal", icon: "laptop", title: "Laptop only", detail: "Only the built-in screen" },
                        { mode: "external", icon: "monitor", title: "External only", detail: "Only the HDMI/DP screen" },
                        { mode: "extend", icon: "extend", title: "Extend", detail: "A second desktop of its own" },
                        { mode: "mirror", icon: "mirror", title: "Duplicate", detail: "Both show the same" }
                    ]
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property bool on: root.current === modelData.mode
                        readonly property bool usable: modelData.mode === "internal" || root.externalName !== ""
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 16
                        opacity: usable ? 1 : 0.4
                        color: on ? Theme.primaryContainer : cardArea.containsMouse && usable ? Theme.surfaceHighest : Theme.surfaceHigh
                        border.width: on ? 2 : 1
                        border.color: on ? Theme.primary : Theme.outlineVariant
                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 8
                            Icon { Layout.alignment: Qt.AlignHCenter; name: card.modelData.icon; size: 34; color: card.on ? Theme.primaryContainerText : Theme.primary }
                            Txt { Layout.alignment: Qt.AlignHCenter; text: card.modelData.title; font.pixelSize: Theme.md; font.weight: Font.Bold; color: card.on ? Theme.primaryContainerText : Theme.surfaceText }
                            Txt {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: card.on && root.busy ? "switching…" : card.on ? "now" : card.modelData.detail
                                font.pixelSize: Theme.xs
                                color: card.on ? Theme.primaryContainerText : Theme.surfaceTextDim
                                wrapMode: Text.Wrap
                            }
                        }
                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: card.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: card.usable && !root.busy
                            onClicked: root.apply(card.modelData.mode)
                        }
                    }
                }

                // look for a newly connected cable, and say what turned up
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: scanArea.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
                    border.width: 1
                    border.color: root.scanning ? Theme.primary : Theme.outlineVariant
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 8
                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            name: "restart"
                            size: 34
                            color: Theme.primary
                            RotationAnimation on rotation {
                                running: root.scanning
                                from: 0; to: 360; duration: 900
                                loops: Animation.Infinite
                                onStopped: parent.rotation = 0
                            }
                        }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: root.scanning ? "Scanning…" : "Rescan"; font.weight: Font.Bold }
                        Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Detect a newly connected cable"; font.pixelSize: Theme.xs; color: Theme.surfaceTextDim; wrapMode: Text.Wrap }
                    }
                    MouseArea { id: scanArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.rescan() }
                }

                // the screens, by name, so you know which is which
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: Theme.surfaceHigh
                    border.width: 1
                    border.color: Theme.outlineVariant
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 4
                        Repeater {
                            model: root.info.screens || []
                            delegate: Txt {
                                required property var modelData
                                width: parent.width
                                elide: Text.ElideRight
                                font.family: Theme.mono
                                font.pixelSize: Theme.xs + 1
                                color: Theme.surfaceTextDim
                                text: modelData.name + "  " + (modelData.disabled ? "off" : modelData.mirrorOf !== "none" ? "mirror" : modelData.width + "×" + modelData.height)
                            }
                        }
                    }
                }
            }
        }
    }
}

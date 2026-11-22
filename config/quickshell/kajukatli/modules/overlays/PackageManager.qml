import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

Item {
    id: root
    property var packages: []
    property var installed: []
    property string status: ""

    Process {
        id: installedProc
        command: [Config.bin + "kk-pkg", "installed"]
        stdout: StdioCollector {
            onStreamFinished: root.installed = text.trim().split("\n").filter(l => l)
        }
        Component.onCompleted: running = true
    }
    Process {
        id: searchProc
        property string query: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l);
                const out = [];
                for (let i = 0; i < lines.length; i += 2) {
                    const head = lines[i] || "";
                    const desc = lines[i + 1] ? lines[i + 1].trim() : "";
                    const parts = head.trim().split(/\s+/);
                    const full = parts.shift() || "";
                    const name = full.includes("/") ? full.split("/").pop() : full;
                    if (name) out.push({ name: name, full: full, version: parts.shift() || "", desc: desc });
                }
                root.packages = out.slice(0, 100);
                root.status = out.length ? out.length + " packages" : "No packages found";
            }
        }
    }

    function search(text) {
        if (text.trim() === "") { root.packages = []; root.status = ""; return; }
        root.status = "Searching…";
        searchProc.query = text.trim();
        searchProc.command = [Config.bin + "kk-pkg", "search", text.trim()];
        searchProc.running = true;
    }
    function install(name) {
        root.status = "Installing " + name + "…";
        Quickshell.execDetached(["kitty", "-e", Config.bin + "kk-pkg", "install", name]);
    }
    function remove(name) {
        root.status = "Removing " + name + "…";
        Quickshell.execDetached(["kitty", "-e", Config.bin + "kk-pkg", "remove", name]);
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 760)
        height: Math.min(parent.height - 48, 560)
        radius: 20
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Txt { text: "Packages"; font.pixelSize: Theme.xl; font.weight: Font.Bold }
                Item { Layout.fillWidth: true }
                Txt { text: root.status; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 12
                color: Theme.surfaceHigh
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: Theme.md
                    color: Theme.surfaceText
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: searchTimer.restart()
                    Timer {
                        id: searchTimer
                        interval: 350
                        onTriggered: root.search(searchInput.text)
                    }
                    Keys.onEscapePressed: Ui.overlay = ""
                }
                Txt {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text === ""
                    text: "Search official and AUR packages"
                    color: Theme.surfaceTextDim
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.packages
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 68
                    radius: 12
                    color: area.containsMouse ? Theme.surfaceHigh : Theme.surfaceLow
                    readonly property bool isInstalled: root.installed.indexOf(modelData.name) !== -1
                    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                Txt { text: modelData.name; font.weight: Font.Bold }
                                Txt { text: modelData.full.startsWith("aur/") ? "AUR" : modelData.full.split("/")[0]; font.pixelSize: Theme.xs; color: Theme.primary }
                                Txt { text: modelData.version; font.pixelSize: Theme.xs; color: Theme.surfaceTextDim }
                            }
                            Txt { Layout.fillWidth: true; text: modelData.desc; elide: Text.ElideRight; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                        }
                        Rectangle {
                            implicitWidth: 82
                            implicitHeight: 34
                            radius: 17
                            color: isInstalled ? Theme.surfaceHighest : Theme.primary
                            Txt {
                                anchors.centerIn: parent
                                text: isInstalled ? "Remove" : "Install"
                                font.pixelSize: Theme.sm
                                color: isInstalled ? Theme.surfaceText : Theme.primaryText
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: isInstalled ? root.remove(modelData.name) : root.install(modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }
}

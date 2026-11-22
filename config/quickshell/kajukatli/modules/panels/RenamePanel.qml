import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// name the workspace you're on ("music", "work", "that bug"). empty resets it to its number.
Item {
    id: root
    implicitWidth: 320
    implicitHeight: col.implicitHeight + 6
    readonly property var ws: Hypr.focusedWs

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8
        Txt {
            text: "Rename " + (root.ws ? root.ws.id : "") + "…"
            font.pixelSize: Theme.lg + 2
        }
        Field {
            id: field
            Layout.fillWidth: true
            placeholder: ""
            size: Theme.lg
            Component.onCompleted: {
                if (root.ws && root.ws.name !== String(root.ws.id)) text = root.ws.name;
                focusNow();
            }
            onAccepted: {
                if (root.ws) Hypr.renameWorkspace(root.ws.id, text.trim() === "" ? String(root.ws.id) : text.trim().toLowerCase());
                Ui.panel = "";
            }
            onEscaped: Ui.panel = ""
        }
    }
}

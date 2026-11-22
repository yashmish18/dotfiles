pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// the notification daemon. replaces dunst/mako, so nothing else needs to run.
Singleton {
    id: root

    property bool dnd: false
    property var popups: []           // shown as toasts right now (newest first)
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length

    function dismissPopup(n) {
        popups = popups.filter(p => p && p !== n);
    }
    function clearAll() {
        const all = history.slice();
        for (const n of all) n.dismiss();
        popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;
            if (Ui.panel === "notifications") return; // you're already looking at them
            root.popups = [n].concat(root.popups.filter(p => p)).slice(0, 4);
            Sounds.play("notify", 400);
        }
    }
}

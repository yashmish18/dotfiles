pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// the notification daemon. replaces dunst/mako, so nothing else needs to run.
Singleton {
    id: root

    property bool dnd: false
    Component.onCompleted: dnd = Store.s.dnd
    onDndChanged: Store.s.dnd = dnd
    property var popups: []           // shown as toasts right now (newest first)
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length

    function dismissPopup(n: var) {
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
            // history keeps each notification and its picture in memory: keep the newest 50
            const old = server.trackedNotifications.values;
            for (const x of old.slice(0, Math.max(0, old.length - 50))) x.dismiss();
            if ((root.dnd || Ui.focusMode || Hypr.fullscreen) && n.urgency !== NotificationUrgency.Critical) return;
            if (Ui.panel === "notifications") return; // you're already looking at them
            root.popups = [n].concat(root.popups.filter(p => p)).slice(0, 4);
            Sounds.play("notify", 400);
        }
    }
}

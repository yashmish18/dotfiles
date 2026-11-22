pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// things the shell remembers between sessions (not settings): current wallpaper, film frame.
Singleton {
    id: root

    readonly property alias s: adapter
    property bool ready: false

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/kajukatli/state.json"
        printErrors: false
        blockLoading: true
        onAdapterUpdated: if (root.ready) writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            writeAdapter();
            root.ready = true;
        }

        JsonAdapter {
            id: adapter
            property string wallpaper: ""     // source file of the current wallpaper
            property int frame: 1             // goes up by one every time you lock
            property var batteryLog: []       // a day of battery levels (Battery.qml)
            property var launches: ({})       // how often each app is opened (the launcher's "recent")
            property var clipPins: []         // pinned clipboard texts
            property real rotatedAt: 0        // when the wallpaper last changed by itself
            property var recentEmojis: []     // the emoji picker's first tab
            property var wallMeta: ({})       // the current wallpaper's bundle: back instantly after a restart
        }
    }
}

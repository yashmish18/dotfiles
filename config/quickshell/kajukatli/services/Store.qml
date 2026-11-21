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
        onAdapterUpdated: writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            writeAdapter();
            root.ready = true;
        }

        JsonAdapter {
            id: adapter
            property string wallpaper: ""     // source file of the current wallpaper
            property int frame: 1             // goes up by one every time you lock
        }
    }
}

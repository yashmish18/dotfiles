pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// user settings: ~/.config/kajukatli/settings.json (created with defaults on first run).
// edit the file by hand or from the shell; both stay in sync.
Singleton {
    id: root

    readonly property alias s: adapter
    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperDir: adapter.wallpaperDir.replace(/^~/, home)

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/kajukatli/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property string wallpaperDir: "~/Pictures/wallpapers"
            property bool parallax: true            // depth parallax on workspace switch
            property bool cursorParallax: true      // also follow the cursor over the bare desktop
            property real parallaxStrength: 1.0     // 0.2 … 2.0
            property int transitionMs: 2600         // outline + ink bleed
            property string subjectModel: "birefnet-general-lite"   // or isnet-anime for drawn art
            property bool videoOnBattery: false     // live wallpapers freeze to a still on battery
            property bool autoPowerProfile: true    // power-saver on battery, balanced on ac
            property bool clock24h: true
            property bool desktopWidget: true
            property bool naturalScroll: true
            property int nightLightTemp: 4200
            property bool lockPoetry: true
            property int notificationTimeout: 5000
        }
    }
}

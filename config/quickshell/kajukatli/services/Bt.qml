pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// bluez through quickshell's native bluetooth module. no polling.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool scanning: available && adapter.discovering

    readonly property var devices: {
        if (!available) return [];
        const list = adapter.devices.values.slice();
        // connected first, then paired, then whatever has a real name
        list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
        return list.filter(d => d.paired || d.connected || (d.name && d.name !== d.address.replace(/:/g, "-")));
    }
    readonly property var connectedDevices: available ? adapter.devices.values.filter(d => d.connected) : []
    readonly property string label: {
        if (!enabled) return "off";
        if (connectedDevices.length === 1) return connectedDevices[0].name;
        if (connectedDevices.length > 1) return connectedDevices.length + " devices";
        return "on";
    }

    function setEnabled(on: bool) {
        if (available) adapter.enabled = on;
    }
    function setScanning(on: bool) {
        if (available && adapter.enabled) adapter.discovering = on;
    }
    function toggleDevice(d) {
        if (d.connected) {
            d.disconnect();
        } else if (d.paired) {
            d.connect();
        } else {
            d.trusted = true;
            d.pair();
        }
    }
    function openManager() {
        Quickshell.execDetached(["blueman-manager"]);
    }

    // pairing finished: connect straight away
    Variants {
        model: root.available ? root.adapter.devices.values : []
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() {
                if (modelData.paired && !modelData.connected) modelData.connect();
            }
        }
    }

    // never leave discovery running in the background, it costs battery
    Timer {
        running: root.scanning
        interval: 30000
        onTriggered: root.setScanning(false)
    }
}

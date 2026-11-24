pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// bluez through quickshell's native bluetooth module. no polling.
//
// a device you paired once stays saved (paired + trusted), and comes back by itself:
//   · switching bluetooth off remembers what was connected; switching it on reconnects those
//   · a connect that doesn't take is tried again (bluez sometimes drops the first one right
//     after the adapter powers up), the last time through bluetoothctl
//   · if it still won't, the device's keys are probably gone (it was paired somewhere else
//     since): its row says so and offers to pair it again
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
        list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || ""));
        return list.filter(d => d.paired || d.connected || (d.name && d.name !== d.address.replace(/:/g, "-")));
    }
    readonly property var connectedDevices: available ? adapter.devices.values.filter(d => d.connected) : []
    readonly property string label: {
        if (!enabled) return "off";
        if (connectedDevices.length === 1) return connectedDevices[0].name;
        if (connectedDevices.length > 1) return connectedDevices.length + " devices";
        return "on";
    }

    // per device: "" | "connecting" | "retrying" | "failed"
    property var trouble: ({})
    function setTrouble(address: string, what: string) {
        const t = Object.assign({}, trouble);
        if (what === "") delete t[address]; else t[address] = what;
        trouble = t;
    }

    function setEnabled(on: bool) {
        if (!available) return;
        if (!on) {
            // remember what was connected, so switching it back on brings them back
            Store.s.btRemember = connectedDevices.map(d => d.address);
        }
        adapter.enabled = on;
    }
    function toggle() { setEnabled(!enabled); }
    function setScanning(on: bool) {
        if (available && adapter.enabled) adapter.discovering = on;
    }

    function connectDevice(d) {
        if (!d) return;
        // trusted: bluez lets it reconnect by itself next time, and keeps it saved
        if (d.paired && !d.trusted) d.trusted = true;
        setTrouble(d.address, "connecting");
        attempts[d.address] = (attempts[d.address] || 0) + 1;
        d.connect();
        check.restart();
    }
    function toggleDevice(d) {
        if (d.connected) {
            d.disconnect();
        } else if (d.paired) {
            attempts[d.address] = 0;
            connectDevice(d);
        } else {
            d.trusted = true;
            d.pair();
        }
    }
    // keys lost (paired with another computer, reset): start over
    function repair(d) {
        setTrouble(d.address, "");
        const addr = d.address;
        d.forget();
        // the device comes back in the scan once it's in pairing mode; pair it as soon as it does
        pendingPair = addr;
        setScanning(true);
    }
    function setTrusted(d, on: bool) { d.trusted = on; }
    function setBlocked(d, on: bool) { d.blocked = on; }
    function openManager() {
        Quickshell.execDetached(["blueman-manager"]);
    }
    function sendFile(d) {
        Quickshell.execDetached(["sh", "-c", 'command -v blueman-sendto >/dev/null && exec blueman-sendto --device="$1" || exec blueman-manager', "sh", d.address]);
    }

    property var attempts: ({})
    property string pendingPair: ""

    // see whether the connects we started took; try again, then through bluetoothctl
    Timer {
        id: check
        interval: 7000
        onTriggered: {
            if (!root.available) return;
            for (const d of root.adapter.devices.values) {
                const st = root.trouble[d.address];
                if (st !== "connecting" && st !== "retrying") continue;
                if (d.connected) { root.setTrouble(d.address, ""); root.attempts[d.address] = 0; continue; }
                const n = root.attempts[d.address] || 0;
                if (n < 2) {
                    root.connectDevice(d);
                    root.setTrouble(d.address, "retrying");
                } else if (n === 2) {
                    root.attempts[d.address] = 3;
                    root.setTrouble(d.address, "retrying");
                    Quickshell.execDetached(["bluetoothctl", "connect", d.address]);
                    check.restart();
                } else {
                    root.setTrouble(d.address, "failed");
                }
            }
        }
    }

    // bluetooth just came on: bring back what was connected before
    property bool wasEnabled: false
    onEnabledChanged: {
        if (enabled && !wasEnabled && Config.s.btAutoReconnect) reconnect.restart();
        wasEnabled = enabled;
    }
    Component.onCompleted: wasEnabled = enabled
    Timer {
        id: reconnect
        interval: 1800        // the adapter needs a moment after powering up
        onTriggered: {
            if (!root.enabled) return;
            const want = Store.s.btRemember || [];
            for (const d of root.adapter.devices.values) {
                if (d.connected || !d.paired) continue;
                if (want.indexOf(d.address) !== -1) {
                    root.attempts[d.address] = 0;
                    root.connectDevice(d);
                }
            }
        }
    }

    Variants {
        model: root.available ? root.adapter.devices.values : []
        delegate: Connections {
            required property var modelData
            target: modelData
            // pairing finished: trust it (saved for good) and connect straight away
            function onPairedChanged() {
                if (!modelData.paired) return;
                if (!modelData.trusted) modelData.trusted = true;
                if (!modelData.connected) { root.attempts[modelData.address] = 0; root.connectDevice(modelData); }
            }
            function onConnectedChanged() {
                if (!modelData.connected) return;
                root.setTrouble(modelData.address, "");
                root.attempts[modelData.address] = 0;
                const k = Object.assign({}, Store.s.btKnown || {});
                k[modelData.address] = modelData.name || modelData.address;
                Store.s.btKnown = k;
            }
        }
    }

    // a device we're waiting to pair again turned up in the scan
    Connections {
        target: root.available ? root.adapter.devices : null
        enabled: root.pendingPair !== ""
        function onValuesChanged() {
            const d = root.adapter.devices.values.find(x => x.address === root.pendingPair);
            if (d && !d.paired && !d.pairing) {
                root.pendingPair = "";
                d.trusted = true;
                d.pair();
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

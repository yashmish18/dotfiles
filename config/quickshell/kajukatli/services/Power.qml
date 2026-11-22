pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// battery, power profile, night light, caffeine. also the battery-saver reactions.
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev && dev.ready && dev.isLaptopBattery
    readonly property bool onBattery: UPower.onBattery
    // quickshell reports 0..1; guard against a 0..100 build just in case
    readonly property int percent: hasBattery ? Math.round(dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 100
    readonly property bool charging: hasBattery && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: hasBattery && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool low: hasBattery && !charging && percent <= 15

    readonly property string timeLeft: {
        if (!hasBattery) return "";
        const s = charging ? dev.timeToFull : dev.timeToEmpty;
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
    readonly property string batteryLabel: !hasBattery ? "ac" : full ? "full" : `${percent}%`

    // power profiles (needs power-profiles-daemon)
    readonly property int profile: PowerProfiles.profile
    readonly property string profileName: profile === PowerProfile.PowerSaver ? "saver" : profile === PowerProfile.Performance ? "performance" : "balanced"
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    function setProfile(name: string) {
        PowerProfiles.profile = name === "saver" ? PowerProfile.PowerSaver
                              : name === "performance" && PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance
                              : PowerProfile.Balanced;
    }
    function cycleProfile() {
        if (profile === PowerProfile.PowerSaver) PowerProfiles.profile = PowerProfile.Balanced;
        else if (profile === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile) PowerProfiles.profile = PowerProfile.Performance;
        else PowerProfiles.profile = PowerProfile.PowerSaver;
    }

    // night light: hyprsunset lives only while it's on, and restores gamma when it exits
    property bool nightLight: false
    Process {
        running: root.nightLight
        command: ["hyprsunset", "-t", String(Config.s.nightLightTemp)]
    }

    // caffeine: a logind idle inhibitor that hypridle honours
    property bool caffeine: false
    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=kajukatli", "--why=caffeine", "--mode=block", "sleep", "infinity"]
    }

    // unplugged: quieter profile. plugged in: back to normal.
    onOnBatteryChanged: {
        if (!Config.s.autoPowerProfile) return;
        PowerProfiles.profile = onBattery ? PowerProfile.PowerSaver : PowerProfile.Balanced;
    }

    // warn once when low, and once more when critical
    property int warned: 100
    onPercentChanged: {
        if (charging || !hasBattery) { warned = 100; return; }
        if (percent <= 5 && warned > 5) {
            warned = 5;
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "battery", "5% left", "plug in now, or it sleeps soon."]);
        } else if (percent <= 15 && warned > 15) {
            warned = 15;
            Quickshell.execDetached(["notify-send", "-a", "battery", "15% left", "the charger is probably in the other room."]);
        }
    }
}

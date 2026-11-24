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
    // on a schedule (settings → display): checked once a minute, and it only ever flips the
    // switch at the two edges, so turning it on or off by hand still works in between
    property bool scheduleWas: false
    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: Config.s.nightLightAuto
        onTriggered: {
            const m = s => { const p = s.split(":"); return parseInt(p[0]) * 60 + parseInt(p[1] || 0); };
            const d = new Date(), now = d.getHours() * 60 + d.getMinutes();
            const a = m(Config.s.nightLightFrom), b = m(Config.s.nightLightTo);
            const inside = a <= b ? (now >= a && now < b) : (now >= a || now < b);
            if (inside !== root.scheduleWas) { root.nightLight = inside; root.scheduleWas = inside; }
        }
    }
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

    // unplugged: quieter profile, and the battery saver. plugged in: back to normal.
    // (also once at login: booting on battery is the common case, and there's no "change" then)
    readonly property bool saving: onBattery && Config.s.batterySaver
    // each saving can be turned off on its own (settings → power)
    readonly property bool saveParallax: saving && Config.s.saverParallax
    readonly property bool saveAnimations: saving && Config.s.saverAnimations
    readonly property bool saveFun: saving && Config.s.saverFun
    onSaveAnimationsChanged: applyPower()
    onOnBatteryChanged: applyPower()
    onSavingChanged: applyPower()
    Timer { id: atLogin; interval: 2500; running: true; onTriggered: root.applyPower() }
    function applyPower() {
        if (Config.s.autoPowerProfile)
            PowerProfiles.profile = onBattery ? PowerProfile.PowerSaver : PowerProfile.Balanced;
        // the compositor's two costly effects: blur passes and shadows
        Hypr.hyprEval(saving
            // xray: blur only what's behind the windows on the wallpaper layer, worked out once
            // and reused, instead of re-blurring everything under every glass window each frame
            ? "hl.config({ decoration = { blur = { passes = 1, xray = true }, shadow = { enabled = false } } })"
            : "hl.config({ decoration = { blur = { passes = 2, xray = false }, shadow = { enabled = true } } })");
        // no window animations while saving: every animated frame is gpu work
        Hypr.hyprEval(saveAnimations ? "hl.config({ animations = { enabled = false } })" : "hl.config({ animations = { enabled = true } })");
        System.applyAll();          // the refresh rate (60 hz while saving)
    }

    onChargingChanged: if (charging) Sounds.play("plug", 2000)

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

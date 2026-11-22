pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// weather from wttr.in (no account, no key). checks every 20 minutes, only while something
// on screen shows it. set `weatherLocation` in settings to a city; empty guesses from your ip.
Singleton {
    id: root

    property int consumers: 0
    property bool ready: false
    property int temp: 0
    property int high: 0
    property int low: 0
    property int code: 113
    property string desc: ""
    property bool night: false
    property string place: ""

    readonly property bool fahrenheit: Config.s.tempUnit === "f"
    readonly property string unit: "°"
    readonly property string icon: Icons.weather(code, night)   // an icon name (components/Icon.qml)

    function refresh() {
        if (proc.running) return;
        const loc = encodeURIComponent(Config.s.weatherLocation.trim());
        proc.command = ["curl", "-sfL", "--max-time", "12", "https://wttr.in/" + loc + "?format=j1"];
        proc.running = true;
    }

    onConsumersChanged: if (consumers > 0 && !ready) refresh()
    Connections {
        target: Config.s
        function onWeatherLocationChanged() { root.ready = false; if (root.consumers > 0) root.refresh(); }
        function onTempUnitChanged() { if (root.consumers > 0) root.refresh(); }
    }

    Timer {
        interval: 20 * 60 * 1000
        repeat: true
        running: root.consumers > 0
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const c = j.current_condition[0];
                    const d = j.weather[0];
                    const f = root.fahrenheit;
                    root.temp = parseInt(f ? c.temp_F : c.temp_C);
                    root.high = parseInt(f ? d.maxtempF : d.maxtempC);
                    root.low = parseInt(f ? d.mintempF : d.mintempC);
                    root.code = parseInt(c.weatherCode);
                    root.desc = (c.weatherDesc && c.weatherDesc[0] ? c.weatherDesc[0].value : "").trim();
                    const a = d.astronomy && d.astronomy[0];
                    if (a) {
                        const toMin = s => {
                            const m = /(\d+):(\d+)\s*(AM|PM)/i.exec(s || "");
                            if (!m) return -1;
                            return (parseInt(m[1]) % 12 + (m[3].toUpperCase() === "PM" ? 12 : 0)) * 60 + parseInt(m[2]);
                        };
                        const now = new Date();
                        const t = now.getHours() * 60 + now.getMinutes();
                        const rise = toMin(a.sunrise), set = toMin(a.sunset);
                        root.night = rise >= 0 && set >= 0 ? (t < rise || t > set) : false;
                    }
                    const area = j.nearest_area && j.nearest_area[0];
                    root.place = area && area.areaName && area.areaName[0] ? area.areaName[0].value : "";
                    root.ready = true;
                } catch (e) {
                    // offline or wttr.in is having a moment; keep the last reading
                }
            }
        }
    }
}

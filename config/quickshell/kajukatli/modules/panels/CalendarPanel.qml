import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// a month like a printed desk calendar: mono numbers, today underlined, sundays a shade lighter.
// scroll or use the arrows to page through months.
Item {
    id: root
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 6
    focus: true
    Keys.onEscapePressed: Ui.panel = ""
    Keys.onLeftPressed: shift(-1)
    Keys.onRightPressed: shift(1)

    SystemClock { id: clock; precision: SystemClock.Hours }
    property int year: clock.date.getFullYear()
    property int month: clock.date.getMonth()

    function shift(d) {
        let m = month + d, y = year;
        if (m < 0) { m = 11; y--; }
        if (m > 11) { m = 0; y++; }
        month = m;
        year = y;
    }

    readonly property var cells: {
        // monday-first grid, 6 rows
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;
        const days = new Date(year, month + 1, 0).getDate();
        const prevDays = new Date(year, month, 0).getDate();
        const out = [];
        for (let i = 0; i < 42; i++) {
            const n = i - lead + 1;
            if (n < 1) out.push({ d: prevDays + n, inMonth: false, col: i % 7 });
            else if (n > days) out.push({ d: n - days, inMonth: false, col: i % 7 });
            else out.push({ d: n, inMonth: true, col: i % 7 });
        }
        return out;
    }
    readonly property bool thisMonth: year === clock.date.getFullYear() && month === clock.date.getMonth()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Txt {
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM").toLowerCase()
                font.pixelSize: Theme.xl - 2
            }
            Txt {
                text: root.year
                font.family: Theme.mono
                font.pixelSize: Theme.sm
                color: Theme.faint
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 3
            }
            Btn { icon: "left"; flat: true; onClicked: root.shift(-1) }
            Btn { text: "Today"; visible: !root.thisMonth; onClicked: { root.year = clock.date.getFullYear(); root.month = clock.date.getMonth(); } }
            Btn { icon: "right"; flat: true; onClicked: root.shift(1) }
        }

        GridLayout {
            columns: 7
            columnSpacing: 0
            rowSpacing: 2
            Layout.fillWidth: true

            Repeater {
                model: ["m", "t", "w", "t", "f", "s", "s"]
                delegate: Txt {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: Theme.mono
                    font.pixelSize: Theme.xs
                    color: Theme.faint
                }
            }
            Repeater {
                model: root.cells
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property bool today: root.thisMonth && modelData.inMonth && modelData.d === clock.date.getDate()
                    Layout.fillWidth: true
                    implicitHeight: 30
                    Txt {
                        id: num
                        anchors.centerIn: parent
                        text: cell.modelData.d
                        font.family: Theme.mono
                        font.pixelSize: Theme.sm
                        color: cell.today ? Theme.accent : !cell.modelData.inMonth ? Theme.alpha(Theme.paper, 0.18) : cell.modelData.col >= 5 ? Theme.muted : Theme.paper
                    }
                    Rectangle {
                        visible: cell.today
                        anchors.horizontalCenter: num.horizontalCenter
                        anchors.top: num.bottom
                        width: num.width + 4
                        height: 1
                        color: Theme.accent
                    }
                }
            }
        }

        Hair { Layout.fillWidth: true }
        Txt {
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toLowerCase() + "  ·  week " + weekNumber(clock.date)
            font.family: Theme.mono
            font.pixelSize: Theme.xs
            color: Theme.muted
            function weekNumber(d): int {
                const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
                const day = t.getUTCDay() || 7;
                t.setUTCDate(t.getUTCDate() + 4 - day);
                const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
                return Math.ceil(((t - y0) / 86400000 + 1) / 7);
            }
        }
    }

    WheelHandler {
        onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
    }
}

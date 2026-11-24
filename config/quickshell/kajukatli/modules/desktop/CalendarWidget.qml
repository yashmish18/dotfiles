import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// a month on the desktop: week numbers down the side, today in a ring, sunday first.
// scroll or use the arrows to page through months.
Rectangle {
    id: root
    implicitWidth: 290
    implicitHeight: col.implicitHeight + 30
    radius: Theme.radius
    color: Theme.glass
    border.width: 1
    border.color: Theme.alpha(Theme.outlineVariant, 0.6)

    SystemClock { id: clock; precision: SystemClock.Hours }
    property int year: clock.date.getFullYear()
    property int month: clock.date.getMonth()
    readonly property bool thisMonth: year === clock.date.getFullYear() && month === clock.date.getMonth()

    function shift(d: var) {
        let m = month + d, y = year;
        if (m < 0) { m = 11; y--; }
        if (m > 11) { m = 0; y++; }
        month = m;
        year = y;
    }
    function weekNumber(d: var): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }

    // sunday-first, 6 rows, each with its week number
    readonly property var rows: {
        const first = new Date(year, month, 1);
        const start = new Date(year, month, 1 - first.getDay());
        const out = [];
        for (let r = 0; r < 6; r++) {
            const days = [];
            for (let c = 0; c < 7; c++) {
                const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + r * 7 + c);
                days.push({ d: d.getDate(), inMonth: d.getMonth() === month,
                            today: d.toDateString() === clock.date.toDateString() });
            }
            out.push({ week: weekNumber(new Date(start.getFullYear(), start.getMonth(), start.getDate() + r * 7 + 1)), days: days });
        }
        return out;
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 0
                Txt {
                    text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                    font.pixelSize: 19
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                Txt {
                    text: "WEEK " + root.weekNumber(clock.date) + " · 6 WEEKS"
                    font.family: Theme.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1
                    color: Theme.outline
                }
            }
            Item { Layout.fillWidth: true }
            Btn { icon: "left"; flat: true; onClicked: root.shift(-1) }
            Btn { text: "Today"; flat: true; size: Theme.sm; onClicked: { root.year = clock.date.getFullYear(); root.month = clock.date.getMonth(); } }
            Btn { icon: "right"; flat: true; onClicked: root.shift(1) }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 8
            columnSpacing: 0
            rowSpacing: 2

            Item { implicitWidth: 18 }
            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                delegate: Txt {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: Theme.mono
                    font.pixelSize: 8
                    color: Theme.outline
                }
            }

            Repeater {
                model: root.rows
                delegate: Repeater {
                    id: rowRep
                    required property var modelData
                    model: [{ week: modelData.week }].concat(modelData.days)
                    delegate: Item {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: index > 0
                        implicitWidth: index === 0 ? 18 : 30
                        implicitHeight: 28
                        Rectangle {
                            visible: index > 0 && modelData.today
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: 13
                            color: Theme.alpha(Theme.primary, 0.18)
                            border.width: 1.5
                            border.color: Theme.primary
                        }
                        Txt {
                            anchors.centerIn: parent
                            text: index === 0 ? modelData.week : modelData.d
                            font.family: index === 0 ? Theme.mono : Theme.sans
                            font.pixelSize: index === 0 ? 8 : 11
                            font.weight: index > 0 && modelData.today ? Font.Bold : Font.Normal
                            color: index === 0 ? Theme.outline
                                 : modelData.today ? Theme.primary
                                 : modelData.inMonth ? Theme.surfaceText : Theme.alpha(Theme.surfaceText, 0.3)
                        }
                    }
                }
            }
        }

        Hair { Layout.fillWidth: true; color: Theme.alpha(Theme.outlineVariant, 0.7) }
        Txt {
            text: Qt.formatDate(clock.date, "dddd, MMMM d, yyyy")
            font.family: Theme.mono
            font.pixelSize: 9
            color: Theme.surfaceTextDim
        }
        Txt {
            text: "No holidays or events"
            font.family: Theme.mono
            font.pixelSize: 9
            color: Theme.outline
        }
    }

    WheelHandler {
        onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
    }
}

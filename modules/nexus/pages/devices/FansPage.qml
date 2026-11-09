pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Fans: the board's fan headers (nct6687 driver) and the graphics card's fans
// (NVIDIA's NVML), each automatic (the BIOS's / the card's own curve), a
// preset curve, a fixed speed or a curve drawn here, following the processor's
// or the card's temperature. Applied by the root fan service (caelestia-fans,
// settings in /etc/caelestia/fans.json through caelestia-admin fans-apply);
// when nothing is changed it doesn't run and every fan is automatic.
PageBase {
    id: root

    property var info: null
    readonly property string helper: `${Paths.libdir}/caelestia-devices`
    readonly property string what: Tr.tr("Change the fans")
    readonly property bool busy: Admin.jobs.some(j => j.what === root.what)
    readonly property var conf: info?.config?.fans ?? {}
    // Fans shown: connected (spinning) or set up here, and the card's
    readonly property var fans: {
        const b = (info?.board ?? []).filter(f => f.rpm > 0 || (conf[f.id] && conf[f.id].mode !== "auto"));
        const g = (info?.gpu ?? []).length ? [{
                id: "gpu",
                label: Tr.tr("Graphics card fans"),
                percent: info.gpu[0].percent,
                rpm: 0,
                auto: info.gpu.every(f => f.auto),
                min: info.gpu[0].min
            }] : [];
        return [...b, ...g];
    }
    // The fans' ids, replaced only when the set of fans changes (the readings
    // refresh every 2 s: rebuilding the rows would lose a curve being edited)
    property var fanIds: []
    property string editingId
    onFansChanged: {
        const ids = fans.map(f => f.id);
        if (JSON.stringify(ids) !== JSON.stringify(fanIds))
            fanIds = ids;
    }
    readonly property var empty: (info?.board ?? []).filter(f => f.rpm === 0 && !(conf[f.id] && conf[f.id].mode !== "auto")).map(f => f.label)

    readonly property var presets: ({
            cpu: {
                quiet: [[40, 25], [60, 35], [75, 55], [85, 100]],
                balanced: [[40, 30], [60, 45], [75, 70], [85, 100]],
                performance: [[40, 45], [60, 65], [75, 90], [85, 100]]
            },
            gpu: {
                quiet: [[50, 30], [65, 40], [75, 60], [85, 100]],
                balanced: [[45, 30], [60, 45], [72, 70], [82, 100]],
                performance: [[40, 40], [55, 60], [70, 85], [80, 100]]
            }
        })

    function load(): void {
        if (!proc.running)
            proc.running = true;
    }

    function floorOf(id: string): int {
        return id === "board:1" || id === "board:2" ? 20 : 0;
    }

    function apply(id: string, c: var): void {
        const fans = JSON.parse(JSON.stringify(conf));
        fans[id] = c;
        Admin.exec(["pkexec", Admin.helper, "fans-apply"], root.what, () => root.load(), JSON.stringify({
            fans
        }));
    }

    // The preset a curve matches, else "custom"
    function presetOf(c: var): string {
        if (!c || c.mode === "auto" || !c.mode)
            return "auto";
        if (c.mode === "fixed")
            return "fixed";
        const p = presets[c.source] ?? {};
        for (const k of Object.keys(p))
            if (JSON.stringify(p[k]) === JSON.stringify(c.curve))
                return k;
        return "custom";
    }

    title: Tr.tr("Fans")

    Component.onCompleted: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible
            repeat: true
            interval: 2000
            onTriggered: root.load()
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.info === null
            text: Tr.tr("Reading the fans…")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        SectionHeader {
            first: true
            visible: root.info !== null
            text: Tr.tr("Temperatures")
        }

        InfoRow {
            visible: root.info?.temps?.cpu !== null && root.info?.temps?.cpu !== undefined
            icon: "memory"
            label: Tr.tr("Processor")
            value: `${Math.round(root.info?.temps?.cpu ?? 0)} °C`
        }

        InfoRow {
            visible: root.info?.temps?.gpu !== null && root.info?.temps?.gpu !== undefined
            icon: "developer_board"
            label: Tr.tr("Graphics card")
            value: `${Math.round(root.info?.temps?.gpu ?? 0)} °C`
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: !!root.info && !root.info.boardWritable && (root.info.board ?? []).length > 0
            text: Tr.tr("The board's fans can only be read (its fan driver isn't the writable one).")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3error
            font: Tokens.font.label.small
        }

        Repeater {
            model: root.fanIds

            ColumnLayout {
                id: fan

                required property string modelData
                readonly property var info: root.fans.find(f => f.id === modelData) ?? {
                    id: modelData,
                    label: "",
                    percent: 0,
                    rpm: 0
                }
                readonly property bool editing: root.editingId === modelData

                readonly property var c: root.conf[modelData] ?? {
                    mode: "auto"
                }
                readonly property string kind: root.presetOf(c)
                readonly property string source: c.source ?? (modelData === "gpu" ? "gpu" : "cpu")
                readonly property int floor: root.floorOf(modelData)

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: fan.info.label
                }

                InfoRow {
                    icon: "mode_fan"
                    label: fan.info.id === "gpu" ? Tr.tr("Speed") : Tr.tr("Speed")
                    value: fan.info.rpm ? `${fan.info.rpm} rpm · ${fan.info.percent ?? 0}%` : `${fan.info.percent ?? 0}%`
                    subtext: fan.kind === "auto" ? (fan.info.id === "gpu" ? Tr.tr("Automatic: the card's own curve") : Tr.tr("Automatic: the board's curve (BIOS)")) : fan.kind === "fixed" ? Tr.tr("Fixed at %1%").arg(fan.c.percent) : Tr.tr("Follows the %1's temperature").arg(fan.source === "gpu" ? Tr.tr("graphics card") : Tr.tr("processor"))
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: [["auto", Tr.tr("Automatic")], ["quiet", Tr.tr("Quiet")], ["balanced", Tr.tr("Balanced")], ["performance", Tr.tr("Performance")], ["fixed", Tr.tr("Fixed")], ["custom", Tr.tr("Custom")]]

                        TextButton {
                            required property var modelData

                            enabled: !root.busy && (fan.info.id === "gpu" || !!root.info?.boardWritable)
                            text: modelData[1]
                            isToggle: true
                            followChecked: true
                            checked: fan.editing ? modelData[0] === "custom" : fan.kind === modelData[0]
                            type: TextButton.Tonal
                            onClicked: {
                                const k = modelData[0];
                                if (k !== "custom")
                                    root.editingId = "";
                                if (k === "auto")
                                    root.apply(fan.info.id, {
                                        mode: "auto"
                                    });
                                else if (k === "fixed")
                                    root.apply(fan.info.id, {
                                        mode: "fixed",
                                        percent: Math.max(fan.floor, fan.info.percent ?? 50)
                                    });
                                else if (k === "custom")
                                    root.editingId = fan.modelData;
                                else
                                    root.apply(fan.info.id, {
                                        mode: "curve",
                                        source: fan.source,
                                        curve: root.presets[fan.source][k].map(p => [p[0], Math.max(fan.floor, p[1])])
                                    });
                            }
                        }
                    }
                }

                // Which temperature a curve follows (case fans: often the card's while gaming)
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    visible: fan.c.mode === "curve" || fan.editing
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: Tr.tr("Follows:")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                        topPadding: Tokens.padding.small
                    }

                    Repeater {
                        model: [["cpu", Tr.tr("Processor")], ["gpu", Tr.tr("Graphics card")]]

                        TextButton {
                            required property var modelData

                            enabled: !root.busy
                            text: modelData[1]
                            isToggle: true
                            followChecked: true
                            checked: fan.source === modelData[0]
                            type: TextButton.Tonal
                            onClicked: {
                                const k = fan.kind === "custom" || fan.kind === "auto" || fan.kind === "fixed" ? "balanced" : fan.kind;
                                root.apply(fan.info.id, {
                                    mode: "curve",
                                    source: modelData[0],
                                    curve: fan.kind === "custom" ? fan.c.curve : root.presets[modelData[0]][k].map(p => [p[0], Math.max(fan.floor, p[1])])
                                });
                            }
                        }
                    }
                }

                StepperRow {
                    Layout.topMargin: Tokens.spacing.small
                    visible: fan.kind === "fixed"
                    label: Tr.tr("Speed")
                    subtext: fan.floor ? Tr.tr("Percent (at least %1%: this fan never stops)").arg(fan.floor) : Tr.tr("Percent")
                    from: fan.floor
                    to: 100
                    stepSize: 5
                    value: fan.c.percent ?? 50
                    onMoved: v => root.apply(fan.info.id, {
                        mode: "fixed",
                        percent: v
                    })
                }

                // The curve: drag a point (left-right: temperature, up-down: speed)
                CurveEditor {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    visible: fan.c.mode === "curve" || fan.editing
                    points: fan.c.mode === "curve" ? fan.c.curve : root.presets[fan.source].balanced
                    floor: fan.floor
                    temp: fan.source === "gpu" ? (root.info?.temps?.gpu ?? -1) : (root.info?.temps?.cpu ?? -1)
                    onEdited: pts => {
                        // Stays open (a preset or Automatic closes it)
                        root.apply(fan.info.id, {
                            mode: "curve",
                            source: fan.source,
                            curve: pts
                        });
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.medium
            visible: root.empty.length > 0
            text: Tr.tr("Nothing connected: %1").arg(root.empty.join(", "))
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: root.info !== null
            text: Tr.tr("Safety: a fan following a curve runs at full speed if its temperature can't be read, and every fan does at 95 °C (processor) or 90 °C (graphics card). If the fan service stops, the board and the card take their fans back.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        component CurveEditor: Item {
            id: ed

            property var points: []
            property int floor
            property real temp: -1
            // Being dragged: a copy
            property var work: []
            property int dragging: -1
            signal edited(pts: var)

            readonly property real tMin: 20
            readonly property real tMax: 100
            readonly property real pad: 28

            function px(t: real): real {
                return pad + (t - tMin) / (tMax - tMin) * (width - pad * 2);
            }
            function py(p: real): real {
                return height - pad - p / 100 * (height - pad * 2);
            }

            implicitHeight: 220
            onPointsChanged: if (dragging < 0)
                work = JSON.parse(JSON.stringify(points ?? []))

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer
            }

            Canvas {
                id: cv

                anchors.fill: parent
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    c.strokeStyle = Colours.palette.m3outlineVariant;
                    c.fillStyle = Colours.palette.m3outline;
                    c.lineWidth = 1;
                    c.font = "10px sans-serif";
                    for (let t = 20; t <= 100; t += 20) {
                        c.beginPath();
                        c.moveTo(ed.px(t), ed.py(0));
                        c.lineTo(ed.px(t), ed.py(100));
                        c.stroke();
                        c.fillText(`${t}°`, ed.px(t) - 8, height - 8);
                    }
                    for (let p = 0; p <= 100; p += 25) {
                        c.beginPath();
                        c.moveTo(ed.px(20), ed.py(p));
                        c.lineTo(ed.px(100), ed.py(p));
                        c.stroke();
                        c.fillText(`${p}%`, 2, ed.py(p) + 3);
                    }
                    if (ed.temp >= 0) {
                        c.strokeStyle = Colours.palette.m3tertiary;
                        c.beginPath();
                        c.moveTo(ed.px(ed.temp), ed.py(0));
                        c.lineTo(ed.px(ed.temp), ed.py(100));
                        c.stroke();
                    }
                    const pts = ed.work;
                    if (!pts.length)
                        return;
                    c.strokeStyle = Colours.palette.m3primary;
                    c.lineWidth = 2;
                    c.beginPath();
                    c.moveTo(ed.px(20), ed.py(pts[0][1]));
                    for (const p of pts)
                        c.lineTo(ed.px(p[0]), ed.py(p[1]));
                    c.lineTo(ed.px(100), ed.py(pts[pts.length - 1][1]));
                    c.stroke();
                    c.fillStyle = Colours.palette.m3primary;
                    for (const p of pts) {
                        c.beginPath();
                        c.arc(ed.px(p[0]), ed.py(p[1]), 6, 0, Math.PI * 2);
                        c.fill();
                    }
                }

                Connections {
                    target: ed

                    function onWorkChanged(): void {
                        cv.requestPaint();
                    }
                    function onTempChanged(): void {
                        cv.requestPaint();
                    }
                    function onWidthChanged(): void {
                        cv.requestPaint();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                // The page scrolls with vertical drags: not while a point is dragged
                preventStealing: true
                cursorShape: ed.dragging >= 0 ? Qt.ClosedHandCursor : Qt.CrossCursor
                onPressed: e => {
                    let best = -1, bd = 24 * 24;
                    for (let i = 0; i < ed.work.length; i++) {
                        const dx = ed.px(ed.work[i][0]) - e.x, dy = ed.py(ed.work[i][1]) - e.y;
                        if (dx * dx + dy * dy < bd) {
                            bd = dx * dx + dy * dy;
                            best = i;
                        }
                    }
                    ed.dragging = best;
                }
                onPositionChanged: e => {
                    if (ed.dragging < 0)
                        return;
                    const i = ed.dragging;
                    const w = JSON.parse(JSON.stringify(ed.work));
                    const lo = i > 0 ? w[i - 1][0] + 1 : ed.tMin;
                    const hi = i < w.length - 1 ? w[i + 1][0] - 1 : ed.tMax;
                    const t = ed.tMin + (e.x - ed.pad) / (ed.width - ed.pad * 2) * (ed.tMax - ed.tMin);
                    const p = (ed.height - ed.pad - e.y) / (ed.height - ed.pad * 2) * 100;
                    w[i] = [Math.round(Math.max(lo, Math.min(hi, t))), Math.round(Math.max(ed.floor, Math.min(100, p)))];
                    // Speed never falls as temperature rises
                    for (let j = i + 1; j < w.length; j++)
                        w[j][1] = Math.max(w[j][1], w[i][1]);
                    for (let j = i - 1; j >= 0; j--)
                        w[j][1] = Math.min(w[j][1], w[i][1]);
                    ed.work = w;
                }
                onReleased: {
                    if (ed.dragging >= 0) {
                        ed.dragging = -1;
                        ed.edited(ed.work);
                    }
                }
                onCanceled: {
                    if (ed.dragging >= 0) {
                        ed.dragging = -1;
                        ed.edited(ed.work);
                    }
                }
            }
        }

        Process {
            id: proc

            command: [root.helper, "fans"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.info = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
    }
}

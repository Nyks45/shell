pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// RGB lighting (OpenRGB's server in the background: caelestia-openrgb.service):
// one colour for everything (or the colour scheme's accent), and per device its
// effect, colours (per zone), brightness and speed. Saved choices are applied
// again at login (caelestia-devices.service; the keyboard forgets its colours);
// board effects the board can keep are also saved on it.
PageBase {
    id: root

    property var info: null
    readonly property string helper: `${Paths.libdir}/caelestia-devices`
    readonly property var swatches: ["ffffff", "ffd8a8", "ff2020", "ff7a00", "ffd000", "30e030", "00d0d0", "2060ff", "9040ff", "ff40b0", "000000"]
    readonly property string accent: Colours.palette.m3primary.toString().slice(1, 7)
    // Changes waiting to be sent (sliders move continuously)
    property var pending: null

    function load(): void {
        if (!proc.running)
            proc.running = true;
    }

    function set(change: var): void {
        pending = Object.assign(pending ?? {}, change);
        sendTimer.restart();
    }

    function send(): void {
        if (!pending)
            return;
        const c = pending;
        pending = null;
        Admin.exec([helper, "lighting-set"], Tr.tr("Change the lighting"), () => root.load(), JSON.stringify(c));
    }

    function hex(c: string): string {
        return `#${c}`;
    }

    title: Tr.tr("Lighting")

    Component.onCompleted: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            id: sendTimer

            interval: 250
            onTriggered: root.send()
        }

        // The accent colour changed (a new wallpaper or scheme): follow it
        Timer {
            id: accentTimer

            interval: 1500
            onTriggered: if (root.info?.followAccent)
                root.set({
                    device: "*",
                    color: root.accent
                })
        }

        Connections {
            target: Colours.palette

            function onM3primaryChanged(): void {
                accentTimer.restart();
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.info === null
            text: Tr.tr("Looking for lighting…")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        // Not running yet
        RowButton {
            Layout.fillWidth: true
            visible: !!root.info && !root.info.server
            icon: "light_mode"
            text: Tr.tr("Turn on lighting control")
            subtext: root.info?.installed ? Tr.tr("Starts a small background service that talks to the lighting (OpenRGB, no window)") : Tr.tr("OpenRGB isn't installed")
            disabled: !root.info?.installed
            onClicked: Admin.exec(["systemctl", "--user", "enable", "--now", "caelestia-openrgb.service", "caelestia-devices.service"], Tr.tr("Turn on lighting control"), () => startTimer.start())
        }

        Timer {
            id: startTimer

            interval: 4000
            onTriggered: root.load()
        }

        // Everything at once
        SectionHeader {
            first: true
            visible: (root.info?.devices ?? []).length > 0
            text: Tr.tr("All lighting")
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: (root.info?.devices ?? []).length > 0
            implicitHeight: allL.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: allL

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    text: Tr.tr("One colour for every device")
                    font: Tokens.font.body.small
                }

                Swatches {
                    withAccent: true
                    onPicked: c => root.set({
                        device: "*",
                        color: c,
                        followAccent: false
                    })
                }
            }
        }

        ToggleRow {
            visible: (root.info?.devices ?? []).length > 0
            text: Tr.tr("Follow the colour scheme")
            subtext: Tr.tr("Every device takes the accent colour, and changes with the wallpaper")
            checked: !!root.info?.followAccent
            onToggled: root.set(checked ? {
                device: "*",
                color: root.accent,
                followAccent: true
            } : {
                followAccent: false
            })
        }

        // Each device
        Repeater {
            model: root.info?.devices ?? []

            ColumnLayout {
                id: dev

                required property var modelData

                readonly property var mode: modelData.modes.find(m => m.name === (modelData.saved.mode ?? modelData.mode)) ?? null
                readonly property bool takesColour: !!mode && (mode.perLed || mode.colors)
                readonly property real brightness: modelData.saved.brightness ?? 100
                readonly property real speed: modelData.saved.speed ?? 50
                // Colours per LED, as saved (or one colour for all)
                readonly property var ledColours: {
                    const n = modelData.leds.length;
                    const s = modelData.saved.colors ?? (modelData.saved.color ? [modelData.saved.color] : modelData.colors);
                    const out = [];
                    for (let i = 0; i < n; i++)
                        out.push(s[Math.min(i, s.length - 1)] ?? "ffffff");
                    return out;
                }
                property bool perZone

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                function zoneStart(zi: int): int {
                    let s = 0;
                    for (let i = 0; i < zi; i++)
                        s += modelData.zones[i].leds;
                    return s;
                }

                function setZone(zi: int, c: string): void {
                    const cols = ledColours.slice();
                    const s = zoneStart(zi);
                    for (let i = 0; i < modelData.zones[zi].leds; i++)
                        cols[s + i] = c;
                    root.set({
                        device: modelData.id,
                        mode: mode?.perLed ? mode.name : (modelData.modes.find(m => m.perLed)?.name ?? mode?.name),
                        colors: cols
                    });
                }

                SectionHeader {
                    text: `${dev.modelData.name} · ${dev.modelData.type}`
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    Repeater {
                        // "Direct" is the same as Static here (colours set by software)
                        model: dev.modelData.modes.filter(m => m.name !== "Direct" || !dev.modelData.modes.some(x => x.name === "Static"))

                        TextButton {
                            required property var modelData

                            text: modelData.name === "Direct" ? Tr.tr("Colours") : modelData.name
                            isToggle: true
                            followChecked: true
                            checked: dev.mode?.name === modelData.name
                            type: TextButton.Tonal
                            onClicked: root.set({
                                device: dev.modelData.id,
                                mode: modelData.name
                            })
                        }
                    }
                }

                ConnectedRect {
                    Layout.fillWidth: true
                    visible: dev.takesColour && !dev.perZone
                    implicitHeight: colL.implicitHeight + Tokens.padding.medium * 2

                    ColumnLayout {
                        id: colL

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: Tr.tr("Colour")
                            font: Tokens.font.body.small
                        }

                        Swatches {
                            withAccent: true
                            current: dev.ledColours[0] ?? ""
                            onPicked: c => root.set({
                                device: dev.modelData.id,
                                color: c
                            })
                        }
                    }
                }

                // A colour per zone (headers, the board's own LEDs, the keyboard's parts)
                ToggleRow {
                    visible: dev.takesColour && dev.mode?.perLed && (dev.modelData.zones.length > 1 || dev.modelData.leds.length > 1)
                    text: dev.modelData.zones.length > 1 ? Tr.tr("A colour per zone") : Tr.tr("A colour per part")
                    checked: dev.perZone
                    onToggled: dev.perZone = checked
                }

                Repeater {
                    // Zones, or, for a one-zone device (the keyboard), its parts
                    model: !dev.perZone ? [] : dev.modelData.zones.length > 1 ? dev.modelData.zones.map((z, i) => ({
                                name: z.name,
                                zone: i,
                                led: -1
                            })) : dev.modelData.leds.map((l, i) => ({
                                name: Tr.tr("Part %1").arg(i + 1),
                                zone: -1,
                                led: i
                            }))

                    ConnectedRect {
                        id: zr

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: zL.implicitHeight + Tokens.padding.medium * 2

                        RowLayout {
                            id: zL

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.largeIncreased
                            spacing: Tokens.spacing.medium

                            StyledText {
                                Layout.preferredWidth: 110
                                text: zr.modelData.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            Swatches {
                                Layout.fillWidth: true
                                small: true
                                current: zr.modelData.zone >= 0 ? (dev.ledColours[dev.zoneStart(zr.modelData.zone)] ?? "") : (dev.ledColours[zr.modelData.led] ?? "")
                                onPicked: c => {
                                    if (zr.modelData.zone >= 0) {
                                        dev.setZone(zr.modelData.zone, c);
                                    } else {
                                        const cols = dev.ledColours.slice();
                                        cols[zr.modelData.led] = c;
                                        root.set({
                                            device: dev.modelData.id,
                                            colors: cols
                                        });
                                    }
                                }
                            }
                        }
                    }
                }

                SliderRow {
                    visible: !!dev.mode?.brightness
                    icon: "brightness_6"
                    label: Tr.tr("Brightness")
                    valueLabel: `${Math.round(dev.brightness)}%`
                    value: dev.brightness / 100
                    onMoved: v => root.set({
                        device: dev.modelData.id,
                        mode: dev.mode.name,
                        brightness: Math.round(v * 100)
                    })
                }

                SliderRow {
                    visible: !!dev.mode?.speed
                    icon: "speed"
                    label: Tr.tr("Speed")
                    valueLabel: `${Math.round(dev.speed)}%`
                    value: dev.speed / 100
                    onMoved: v => root.set({
                        device: dev.modelData.id,
                        mode: dev.mode.name,
                        speed: Math.round(v * 100)
                    })
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.small
                    Layout.topMargin: Tokens.spacing.small
                    visible: dev.modelData.emptyZones.length > 0
                    text: Tr.tr("Nothing known on %1").arg(dev.modelData.emptyZones.join(", "))
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.medium
            visible: !!root.info?.server
            text: Tr.tr("Not controllable here: the graphics card's lighting (OpenRGB doesn't know this model).")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        component Swatches: Flow {
            id: sw

            property bool withAccent
            property bool small
            property string current
            signal picked(c: string)

            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: [...(sw.withAccent ? [root.accent] : []), ...root.swatches]

                Rectangle {
                    id: chip

                    required property string modelData
                    required property int index

                    readonly property bool isAccent: sw.withAccent && index === 0

                    implicitWidth: sw.small ? 26 : 32
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: `#${modelData}`
                    border.width: sw.current.toLowerCase() === modelData.toLowerCase() ? 3 : 1
                    border.color: sw.current.toLowerCase() === modelData.toLowerCase() ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: chip.isAccent || chip.modelData === "000000"
                        text: chip.isAccent ? "palette" : "power_settings_new"
                        color: chip.modelData === "000000" ? "white" : "black"
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sw.picked(chip.modelData)
                    }
                }
            }

            // Any colour
            StyledTextField {
                implicitWidth: 110
                verticalPadding: Tokens.padding.small
                horizontalPadding: Tokens.padding.medium
                placeholderText: "#rrggbb"
                onAccepted: {
                    const t = text.trim().replace(/^#/, "");
                    if (/^[0-9a-fA-F]{6}$/.test(t))
                        sw.picked(t.toLowerCase());
                }
            }
        }

        Process {
            id: proc

            command: [root.helper, "lighting"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.info = JSON.parse(text);
                    } catch (e) {
                        root.info = {
                            server: false,
                            installed: true,
                            devices: []
                        };
                    }
                }
            }
        }
    }
}

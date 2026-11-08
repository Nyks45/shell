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
import qs.modules.nexus.common

// The colour scheme (caelestia scheme): light or dark, colours from the
// wallpaper or a ready-made scheme, and the style of wallpaper colours.
PageBase {
    id: root

    // [{ name, flavour, colours }] from `caelestia scheme list`
    property var schemes: []
    property string variant
    readonly property bool dynamic: Colours.scheme === "dynamic"

    readonly property var names: ({
            caelestia: "Caelestia",
            catppuccin: "Catppuccin",
            darkgreen: "Dark Green",
            dracula: "Dracula",
            everblush: "Everblush",
            everforest: "Everforest",
            gruvbox: "Gruvbox",
            nord: "Nord",
            oldworld: "Old World",
            onedark: "One Dark",
            rosepine: "Rosé Pine",
            shadotheme: "Shado",
            solarized: "Solarized",
            tokyonight: "Tokyo Night"
        })

    function prettyName(s: var): string {
        const name = names[s.name] ?? s.name.charAt(0).toUpperCase() + s.name.slice(1);
        if (s.flavour === "default" || s.flavour === "medium" && schemes.filter(x => x.name === s.name).length <= 1)
            return name;
        return `${name} ${s.flavour.charAt(0).toUpperCase()}${s.flavour.slice(1)}`;
    }

    function setScheme(args: list<string>): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", ...args]);
        reloadVariant.restart();
    }

    title: Tr.tr("Colours")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            running: true
            command: ["caelestia", "scheme", "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text);
                        const list = [];
                        for (const [name, flavours] of Object.entries(data))
                            for (const [flavour, colours] of Object.entries(flavours))
                                if (name !== "dynamic" || flavour === "default")
                                    list.push({
                                        name,
                                        flavour,
                                        colours
                                    });
                        // The wallpaper's colours first, then by name (prettyName looks at
                        // the whole list for flavours, so it has to be set first)
                        root.schemes = list;
                        const rest = list.filter(s => s.name !== "dynamic").sort((a, b) => root.prettyName(a).localeCompare(root.prettyName(b)));
                        root.schemes = [...list.filter(s => s.name === "dynamic"), ...rest];
                    } catch (e) {
                        root.schemes = [];
                    }
                }
            }
        }

        Process {
            id: variantProc

            running: true
            command: ["caelestia", "scheme", "get", "-v"]
            stdout: StdioCollector {
                onStreamFinished: root.variant = text.trim()
            }
        }

        // The CLI writes the scheme a moment after it's called
        Timer {
            id: reloadVariant

            interval: 1500
            onTriggered: variantProc.running = true
        }

        SectionHeader {
            first: true
            text: Tr.tr("Mode")
        }

        SelectRow {
            label: Tr.tr("Theme")
            subtext: Tr.tr("Light or dark surfaces, for the shell and apps")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Dark")
                    icon: "dark_mode"
                    value: "dark"
                },
                MenuItem {
                    text: Tr.tr("Light")
                    icon: "light_mode"
                    value: "light"
                }
            ]
            active: menuItems.find(i => i.value === (Colours.light ? "light" : "dark")) ?? null
            onSelected: item => root.setScheme(["-m", item.value])
        }

        ToggleRow {
            text: Tr.tr("Follow the wallpaper")
            subtext: Tr.tr("Picks light or dark, and the style, to suit each new wallpaper")
            checked: GlobalConfig.services.smartScheme
            onToggled: GlobalConfig.services.smartScheme = checked
        }

        SectionHeader {
            text: Tr.tr("Colour scheme")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.schemes.length === 0
            text: Tr.tr("Loading schemes…")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        GridLayout {
            id: grid

            Layout.fillWidth: true
            columns: Math.max(2, Math.floor((width + columnSpacing) / (150 + columnSpacing)))
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Repeater {
                model: root.schemes

                SchemeCard {}
            }
        }

        SectionHeader {
            visible: root.dynamic
            text: Tr.tr("Style")
        }

        SelectRow {
            visible: root.dynamic
            label: Tr.tr("Wallpaper colour style")
            subtext: active?.description ?? ""
            menuOnTop: true
            menuItems: variantItems.instances
            active: variantItems.instances.find(i => i.value === root.variant) ?? null
            fallbackText: root.variant
            onSelected: item => root.setScheme(["-v", item.value])

            Variants {
                id: variantItems

                model: [
                    {
                        value: "tonalspot",
                        text: Tr.trCtx("Tonal Spot", "M3 scheme variant name"),
                        description: Tr.tr("Soft, calm colours (the default)")
                    },
                    {
                        value: "vibrant",
                        text: Tr.trCtx("Vibrant", "M3 scheme variant name"),
                        description: Tr.tr("Strong, saturated colours")
                    },
                    {
                        value: "expressive",
                        text: Tr.trCtx("Expressive", "M3 scheme variant name"),
                        description: Tr.tr("Livelier, with hues shifted from the wallpaper's")
                    },
                    {
                        value: "fidelity",
                        text: Tr.trCtx("Fidelity", "M3 scheme variant name"),
                        description: Tr.tr("As close to the wallpaper's colours as it gets")
                    },
                    {
                        value: "content",
                        text: Tr.trCtx("Content", "M3 scheme variant name"),
                        description: Tr.tr("Close to the wallpaper's colours, like Fidelity")
                    },
                    {
                        value: "fruitsalad",
                        text: Tr.trCtx("Fruit Salad", "M3 scheme variant name"),
                        description: Tr.tr("Playful: hues other than the wallpaper's")
                    },
                    {
                        value: "rainbow",
                        text: Tr.trCtx("Rainbow", "M3 scheme variant name"),
                        description: Tr.tr("Playful and colourful")
                    },
                    {
                        value: "neutral",
                        text: Tr.trCtx("Neutral", "M3 scheme variant name"),
                        description: Tr.tr("Nearly grey, a hint of colour")
                    },
                    {
                        value: "monochrome",
                        text: Tr.trCtx("Monochrome", "M3 scheme variant name"),
                        description: Tr.tr("Greys only")
                    }
                ]

                MenuItem {
                    required property var modelData
                    readonly property string description: modelData.description

                    text: modelData.text
                    value: modelData.value
                }
            }
        }
    }

    component SchemeCard: StyledRect {
        id: card

        required property var modelData
        readonly property var c: modelData.colours ?? {}
        readonly property bool isDynamic: modelData.name === "dynamic"
        readonly property bool current: Colours.scheme === modelData.name && (isDynamic || Colours.flavour === modelData.flavour)

        function hex(name: string, fallback: string): color {
            const v = c[name];
            return v ? `#${v}` : fallback;
        }

        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2

        radius: Tokens.rounding.large
        color: current ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        border.width: current ? 2 : 0
        border.color: Colours.palette.m3primary

        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            onClicked: root.setScheme(card.isDynamic ? ["-n", "dynamic"] : ["-n", card.modelData.name, "-f", card.modelData.flavour])
        }

        ColumnLayout {
            id: cardLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            // The scheme's surface with its accent colours on it
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: Tokens.rounding.medium
                color: card.hex("surface", card.hex("background", "#222222"))

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: ["primary", "secondary", "tertiary"]

                        StyledRect {
                            required property string modelData

                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: card.hex(modelData, "#888888")
                        }
                    }
                }

                MaterialIcon {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    visible: card.isDynamic
                    text: "wallpaper"
                    color: card.hex("onSurface", "#ffffff")
                    fontStyle: Tokens.font.icon.small
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    text: card.isDynamic ? Tr.tr("Wallpaper") : root.prettyName(card.modelData)
                    font: Tokens.font.body.small
                    color: card.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    visible: card.current
                    text: "check_circle"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                    fill: 1
                }
            }
        }
    }
}

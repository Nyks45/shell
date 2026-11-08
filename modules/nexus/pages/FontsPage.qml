pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Fonts: the shell's own, apps' (GTK through gsettings, Qt through qtengine),
// the window title bars' (hyprflow) and how text is drawn.
PageBase {
    id: root

    readonly property string gtkSchema: "org.gnome.desktop.interface"
    readonly property var gtkUi: AppLook.gtkFont("font-name")
    readonly property var gtkDoc: AppLook.gtkFont("document-font-name")
    readonly property var gtkMono: AppLook.gtkFont("monospace-font-name")

    function setShellFont(family: string): void {
        GlobalConfig.appearance.font.headline.family = family;
        GlobalConfig.appearance.font.title.family = family;
        GlobalConfig.appearance.font.body.family = family;
        GlobalConfig.appearance.font.label.family = family;
    }

    title: Tr.tr("Fonts")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Shell")
        }

        FontRow {
            label: Tr.tr("Interface font")
            subtext: Tr.tr("Panels, menus, the launcher and this app")
            family: Config.appearance.font.body.family
            onPicked: f => root.setShellFont(f)
        }

        FontRow {
            label: Tr.tr("Monospace font")
            subtext: Tr.tr("Where the shell shows code or numbers in columns")
            family: Config.appearance.font.mono.family
            monoOnly: true
            onPicked: f => GlobalConfig.appearance.font.mono.family = f
        }

        FontRow {
            label: Tr.tr("Clock font")
            family: Config.appearance.font.clock
            onPicked: f => GlobalConfig.appearance.font.clock = f
        }

        SliderRow {
            icon: "format_size"
            label: Tr.tr("Shell text size")
            valueLabel: `${Math.round(Config.appearance.font.scale * 100)}%`
            // 80% .. 150%
            value: (Config.appearance.font.scale - 0.8) / 0.7
            onMoved: v => GlobalConfig.appearance.font.scale = Math.round((0.8 + v * 0.7) * 20) / 20
        }

        SectionHeader {
            text: Tr.tr("Apps")
        }

        FontRow {
            label: Tr.tr("App font")
            subtext: Tr.tr("GTK and Qt apps' menus, buttons and labels")
            family: root.gtkUi.family
            onPicked: f => {
                AppLook.setGtkFont("font-name", f, root.gtkUi.size);
                AppLook.setQt("font", f);
            }
        }

        StepperRow {
            label: Tr.tr("App font size")
            subtext: Tr.tr("In points")
            value: root.gtkUi.size
            from: 7
            to: 24
            stepSize: 1
            onMoved: v => {
                AppLook.setGtkFont("font-name", root.gtkUi.family, v);
                AppLook.setQt("fontSize", v);
            }
        }

        FontRow {
            label: Tr.tr("Document font")
            subtext: Tr.tr("For reading, in apps that use it")
            family: root.gtkDoc.family
            onPicked: f => AppLook.setGtkFont("document-font-name", f, root.gtkDoc.size)
        }

        FontRow {
            label: Tr.tr("App monospace font")
            subtext: Tr.tr("Terminals and code in apps")
            family: root.gtkMono.family
            monoOnly: true
            onPicked: f => {
                AppLook.setGtkFont("monospace-font-name", f, root.gtkMono.size);
                AppLook.setQt("fontFixed", f);
            }
        }

        StepperRow {
            label: Tr.tr("App monospace font size")
            subtext: Tr.tr("In points")
            value: root.gtkMono.size
            from: 7
            to: 24
            stepSize: 1
            onMoved: v => {
                AppLook.setGtkFont("monospace-font-name", root.gtkMono.family, v);
                AppLook.setQt("fontFixedSize", v);
            }
        }

        SectionHeader {
            text: Tr.tr("Window title bars")
        }

        RequirementRow {
            visible: HyprSettings.values["plugin:hyprflow:bar_font"] === undefined
            text: Tr.tr("Needs the hyprflow plugin")
            subtext: Tr.tr("Window title bars come from hyprflow, which isn't loaded.")
            actionText: Tr.tr("Plugins")
            onAction: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "plugins"),
                path: []
            })
        }

        FontRow {
            visible: HyprSettings.values["plugin:hyprflow:bar_font"] !== undefined
            label: Tr.tr("Title font")
            family: HyprSettings.value("plugin:hyprflow:bar_font", "")
            onPicked: f => HyprSettings.setHyprflow("bar_font", f)
        }

        StepperRow {
            visible: HyprSettings.values["plugin:hyprflow:bar_font"] !== undefined
            label: Tr.tr("Title size")
            subtext: Tr.tr("In points")
            value: HyprSettings.value("plugin:hyprflow:bar_text_size", 10)
            from: 7
            to: 18
            stepSize: 1
            onMoved: v => HyprSettings.setHyprflow("bar_text_size", v)
        }

        SelectRow {
            visible: HyprSettings.values["plugin:hyprflow:bar_font"] !== undefined
            label: Tr.tr("Title weight")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("Regular")
                    value: 400
                },
                MenuItem {
                    text: Tr.tr("Medium")
                    value: 500
                },
                MenuItem {
                    text: Tr.tr("Semi-bold")
                    value: 600
                },
                MenuItem {
                    text: Tr.tr("Bold")
                    value: 700
                }
            ]
            active: menuItems.find(i => i.value === HyprSettings.value("plugin:hyprflow:bar_text_weight", 600)) ?? null
            onSelected: item => HyprSettings.setHyprflow("bar_text_weight", item.value)
        }

        SectionHeader {
            text: Tr.tr("Rendering")
        }

        SelectRow {
            label: Tr.tr("Smoothing")
            subtext: Tr.tr("How the edges of letters are softened")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Greyscale")
                    value: "grayscale"
                },
                MenuItem {
                    text: Tr.tr("Subpixel (sharper on most screens)")
                    value: "rgba"
                },
                MenuItem {
                    text: Tr.tr("None")
                    value: "none"
                }
            ]
            active: menuItems.find(i => i.value === AppLook.get(root.gtkSchema, "font-antialiasing", "grayscale")) ?? null
            onSelected: item => AppLook.set(root.gtkSchema, "font-antialiasing", item.value)
        }

        SelectRow {
            label: Tr.tr("Hinting")
            subtext: Tr.tr("Fitting letters to the pixel grid: crisper, less true to the font")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("None")
                    value: "none"
                },
                MenuItem {
                    text: Tr.tr("Slight")
                    value: "slight"
                },
                MenuItem {
                    text: Tr.tr("Medium")
                    value: "medium"
                },
                MenuItem {
                    text: Tr.tr("Full")
                    value: "full"
                }
            ]
            active: menuItems.find(i => i.value === AppLook.get(root.gtkSchema, "font-hinting", "slight")) ?? null
            onSelected: item => AppLook.set(root.gtkSchema, "font-hinting", item.value)
        }
    }
}

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
import qs.modules.nexus
import qs.modules.nexus.common

// Screenshots (services/Screenshots: the area picker and Print) and screen
// recording (the caelestia CLI's gpu-screen-recorder options in cli.json).
PageBase {
    id: root

    property list<string> editors: []
    // gpu-screen-recorder options in cli.json record.extraArgs: "-q" -> "ultra"
    readonly property list<string> recArgs: AppLook.cli.record?.extraArgs ?? []

    function recArg(flag: string, fallback: string): string {
        const i = recArgs.indexOf(flag);
        return i >= 0 && i + 1 < recArgs.length ? recArgs[i + 1] : fallback;
    }

    function setRecArg(flag: string, value: string): void {
        const args = [...recArgs];
        const i = args.indexOf(flag);
        if (i >= 0)
            args.splice(i, 2);
        if (value)
            args.push(flag, value);
        const record = Object.assign({}, AppLook.cli.record ?? {});
        record.extraArgs = args;
        AppLook.saveCli(Object.assign({}, AppLook.cli, {
            record
        }));
    }

    title: Tr.tr("Screenshots & recording")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            running: true
            command: ["sh", "-c", "for e in swappy satty ksnip gimp krita pinta; do command -v $e >/dev/null && echo $e; done"]
            stdout: StdioCollector {
                onStreamFinished: root.editors = ["caelestia", ...text.split("\n").filter(e => e)]
            }
        }

        SectionHeader {
            text: Tr.tr("After a screenshot")
        }

        ToggleRow {
            text: Tr.tr("Copy to the clipboard")
            subtext: Tr.tr("Ready to paste anywhere")
            checked: Screenshots.copy
            onToggled: Screenshots.set("copy", checked)
        }

        ToggleRow {
            text: Tr.tr("Save to a folder")
            checked: Screenshots.save
            onToggled: Screenshots.set("save", checked)
        }

        FolderPickerRow {
            visible: Screenshots.save
            label: Tr.tr("Save folder")
            value: Screenshots.folder
            defaultValue: Screenshots.defaultFolder
            canReset: true
            onPicked: path => Screenshots.set("folder", path === Screenshots.defaultFolder ? "" : path)
            onResetClicked: Screenshots.set("folder", "")
        }

        ToggleRow {
            text: Tr.tr("Notification")
            subtext: Tr.tr("Click it to draw on the screenshot; with Open and Show in folder")
            checked: Screenshots.showNotification
            onToggled: Screenshots.set("notify", checked)
        }

        SelectRow {
            label: Tr.tr("Editor")
            subtext: Screenshots.editor === "caelestia" ? Tr.tr("The shell's Paint: pen, arrows, shapes, text, crop") : ""
            menuItems: editorItems.instances
            active: editorItems.instances.find(i => i.value === Screenshots.editor) ?? null
            fallbackText: Screenshots.editor
            onSelected: item => Screenshots.set("editor", item.value)

            Variants {
                id: editorItems

                model: root.editors

                MenuItem {
                    required property string modelData

                    text: modelData === "caelestia" ? Tr.tr("Paint (built in)") : modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    value: modelData
                }
            }
        }

        ToggleRow {
            text: Tr.tr("Shutter sound")
            checked: Screenshots.sound
            onToggled: Screenshots.set("sound", checked)
        }

        SectionHeader {
            text: Tr.tr("Keys")
        }

        ToggleRow {
            text: Tr.tr("Print key uses these screenshot settings")
            subtext: Tr.tr("Off: falls back to caelestia's built-in default")
            checked: HyprSettings.saved.screenshotKey ?? true
            onToggled: HyprSettings.update({
                screenshotKey: checked
            })
        }

        NavRow {
            icon: "keyboard_command_key"
            text: Tr.tr("Screenshot shortcuts")
            subtext: Tr.tr("Super+Shift+S: an area (the screen frozen); change them in Keyboard shortcuts")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("shortcuts"),
                tab: "shortcuts",
                path: []
            })
        }

        SectionHeader {
            text: Tr.tr("Screen recording")
        }

        SelectRow {
            label: Tr.tr("Quality")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Medium (smaller files)")
                    value: "medium"
                },
                MenuItem {
                    text: Tr.tr("High")
                    value: "high"
                },
                MenuItem {
                    text: Tr.tr("Very high")
                    value: "very_high"
                },
                MenuItem {
                    text: Tr.tr("Ultra (largest files)")
                    value: "ultra"
                }
            ]
            active: menuItems.find(i => i.value === root.recArg("-q", "very_high")) ?? null
            onSelected: item => root.setRecArg("-q", item.value)
        }

        SelectRow {
            label: Tr.tr("Video format")
            subtext: Tr.tr("H.264 plays everywhere; HEVC and AV1 are smaller")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Automatic")
                    value: ""
                },
                MenuItem {
                    text: "H.264"
                    value: "h264"
                },
                MenuItem {
                    text: "HEVC (H.265)"
                    value: "hevc"
                },
                MenuItem {
                    text: "AV1"
                    value: "av1"
                }
            ]
            active: menuItems.find(i => i.value === root.recArg("-k", "")) ?? null
            onSelected: item => root.setRecArg("-k", item.value)
        }

        SelectRow {
            label: Tr.tr("Frame rate")
            subtext: Tr.tr("Automatic matches the monitor's refresh rate")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Automatic")
                    value: ""
                },
                MenuItem {
                    text: "30 fps"
                    value: "30"
                },
                MenuItem {
                    text: "60 fps"
                    value: "60"
                },
                MenuItem {
                    text: "120 fps"
                    value: "120"
                }
            ]
            active: menuItems.find(i => i.value === root.recArg("-f", "")) ?? null
            onSelected: item => root.setRecArg("-f", item.value)
        }

        SelectRow {
            label: Tr.tr("Audio source")
            subtext: Tr.tr("Always capture audio, or only when using the sound shortcut")
            menuItems: [
                MenuItem {
                    text: Tr.tr("From shortcut (-s)")
                    value: ""
                },
                MenuItem {
                    text: Tr.tr("Desktop audio")
                    value: "default_output"
                },
                MenuItem {
                    text: Tr.tr("Microphone")
                    value: "default_input"
                },
                MenuItem {
                    text: Tr.tr("Desktop audio + Microphone")
                    value: "default_output|default_input"
                }
            ]
            active: menuItems.find(i => i.value === root.recArg("-a", "")) ?? null
            onSelected: item => root.setRecArg("-a", item.value)
        }

        ToggleRow {
            text: Tr.tr("Show the pointer")
            checked: root.recArg("-cursor", "yes") === "yes"
            onToggled: root.setRecArg("-cursor", checked ? "" : "no")
        }

        RowButton {
            icon: "folder_open"
            text: Tr.tr("Recordings folder")
            subtext: Paths.shortenHome(Paths.recsdir)
            trailingIcon: "open_in_new"
            onClicked: Quickshell.execDetached(["xdg-open", Paths.recsdir])
        }
    }
}

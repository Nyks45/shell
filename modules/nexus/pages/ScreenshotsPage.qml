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
                onStreamFinished: root.editors = text.split("\n").filter(e => e)
            }
        }

        SectionHeader {
            first: true
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

        TextFieldRow {
            visible: Screenshots.save
            label: Tr.tr("Folder")
            value: Screenshots.folder
            onEditingFinished: v => Screenshots.set("folder", v.trim() === Screenshots.defaultFolder ? "" : v.trim())
        }

        ToggleRow {
            text: Tr.tr("Notification")
            subtext: Tr.tr("With Edit, Open and Show in folder")
            checked: Screenshots.showNotification
            onToggled: Screenshots.set("notify", checked)
        }

        ToggleRow {
            text: Tr.tr("Open in the editor right away")
            subtext: Tr.tr("Off: only from the notification's Edit")
            checked: Screenshots.openEditor
            onToggled: Screenshots.set("edit", checked)
        }

        SelectRow {
            label: Tr.tr("Editor")
            subtext: root.editors.length === 0 ? Tr.tr("None installed (swappy or satty, for example)") : ""
            menuItems: editorItems.instances
            active: editorItems.instances.find(i => i.value === Screenshots.editor) ?? null
            fallbackText: Screenshots.editor
            onSelected: item => Screenshots.set("editor", item.value)

            Variants {
                id: editorItems

                model: root.editors

                MenuItem {
                    required property string modelData

                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
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
            text: Tr.tr("Print key: the whole screen, as above")
            subtext: Tr.tr("Off: the caelestia command's own screenshot")
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
                page: PageRegistry.pages.findIndex(p => p.id === "shortcuts"),
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

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    property bool showAdvanced: false

    title: Tr.tr("Launcher")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            text: Tr.tr("General")
        }

        ToggleRow {
            text: Tr.trCtx("Enabled", "toggle label")
            checked: Config.launcher.enabled
            onToggled: GlobalConfig.launcher.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.launcher.showOnHover
            onToggled: GlobalConfig.launcher.showOnHover = checked
        }

        SelectRow {
            label: Tr.tr("Style")
            subtext: Tr.tr("Where the launcher opens and how it looks")
            menuItems: [
                MenuItem {
                    text: Tr.tr("App grid in the middle")
                    value: "grid"
                },
                MenuItem {
                    text: Tr.tr("Wallpaper and list in the middle")
                    value: "wallpaper"
                }
            ]
            active: menuItems.find(i => i.value === Config.launcher.style) ?? menuItems[0] // (the old "list": the grid)
            onSelected: item => GlobalConfig.launcher.style = item.value
        }

        // The launcher's actions (after the action prefix): on or off
        SectionHeader {
            text: Tr.tr("Actions")
        }

        Repeater {
            id: actionList

            model: GlobalConfig.launcher.actions.values

            ToggleRow {
                required property var modelData
                required property int index

                text: modelData.name ? Tr.trMarked(modelData.name) : ""
                subtext: modelData.description ? Tr.trMarked(modelData.description) : ""
                checked: modelData.enabled
                onToggled: GlobalConfig.launcher.actions.at(index).enabled = checked
            }
        }

        // Display
        SectionHeader {
            text: Tr.tr("Display")
        }

        StepperRow {
            label: Tr.tr("Max items shown")
            value: Config.launcher.maxShown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.launcher.maxShown = v
        }

        StepperRow {
            label: Tr.tr("Max wallpapers")
            value: Config.launcher.maxWallpapers
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => GlobalConfig.launcher.maxWallpapers = v
        }

        StepperRow {
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Distance dragged up from the bottom edge before the launcher opens")
            value: Config.launcher.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.launcher.dragThreshold = v
        }

        // Advanced
        SectionHeader {
            text: Tr.tr("Advanced")
        }

        RowButton {
            icon: root.showAdvanced ? "expand_less" : "expand_more"
            text: Tr.tr("Advanced options")
            subtext: Tr.tr("Command prefixes, Vim navigation, power actions and fuzzy matching")
            onClicked: root.showAdvanced = !root.showAdvanced
        }

        TextFieldRow {
            id: prefixRow

            visible: root.showAdvanced
            label: Tr.tr("Action prefix")
            subtext: Tr.tr("Symbol typed first to run actions in the launcher")
            errorText: Tr.tr("Prefix must be a symbol (not a letter or number)")
            value: GlobalConfig.launcher.actionPrefix === ">" ? "" : GlobalConfig.launcher.actionPrefix
            placeholderText: ">"
            maximumLength: 1
            smallField: true
            validate: /^[^a-zA-Z0-9\s]$/
            onEditingFinished: value => {
                if (!field.valid)
                    return;
                GlobalConfig.launcher.actionPrefix = value || ">";
                if (GlobalConfig.launcher.actionPrefix === ">")
                    clear();
            }
        }

        TextFieldRow {
            visible: root.showAdvanced
            label: Tr.tr("Special prefix")
            subtext: Tr.tr("Symbol typed first for wallpaper and colour searches")
            errorText: Tr.tr("Prefix must be a symbol (not a letter or number)")
            value: GlobalConfig.launcher.specialPrefix
            placeholderText: "@"
            maximumLength: 1
            smallField: true
            validate: /^[^a-zA-Z0-9\s]$/
            onEditingFinished: value => {
                if (field.valid && value)
                    GlobalConfig.launcher.specialPrefix = value;
            }
        }

        ToggleRow {
            visible: root.showAdvanced
            text: Tr.tr("Vim keybinds")
            subtext: Tr.tr("Navigate results with Ctrl+hjkl")
            checked: GlobalConfig.launcher.vimKeybinds
            onToggled: GlobalConfig.launcher.vimKeybinds = checked
        }

        ToggleRow {
            visible: root.showAdvanced
            text: Tr.tr("Allow shutdown and logout actions")
            subtext: Tr.tr("Include power off, reboot and log out in launcher results")
            checked: GlobalConfig.launcher.enableDangerousActions
            onToggled: GlobalConfig.launcher.enableDangerousActions = checked
        }

        SectionHeader {
            visible: root.showAdvanced
            text: Tr.tr("Fuzzy search")
        }

        ToggleRow {
            visible: root.showAdvanced
            text: Tr.tr("Apps")
            checked: GlobalConfig.launcher.useFuzzy.apps
            onToggled: GlobalConfig.launcher.useFuzzy.apps = checked
        }

        ToggleRow {
            visible: root.showAdvanced
            text: Tr.tr("Actions")
            checked: GlobalConfig.launcher.useFuzzy.actions
            onToggled: GlobalConfig.launcher.useFuzzy.actions = checked
        }

        ToggleRow {
            visible: root.showAdvanced
            text: Tr.tr("Colour schemes")
            checked: GlobalConfig.launcher.useFuzzy.schemes
            onToggled: GlobalConfig.launcher.useFuzzy.schemes = checked
        }

        ToggleRow {
            visible: root.showAdvanced
            text: Tr.tr("Scheme styles")
            checked: GlobalConfig.launcher.useFuzzy.variants
            onToggled: GlobalConfig.launcher.useFuzzy.variants = checked
        }

        ToggleRow {
            visible: root.showAdvanced
            text: Tr.tr("Wallpapers")
            checked: GlobalConfig.launcher.useFuzzy.wallpapers
            onToggled: GlobalConfig.launcher.useFuzzy.wallpapers = checked
        }
    }
}

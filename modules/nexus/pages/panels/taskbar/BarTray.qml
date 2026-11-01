pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Tray")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: Tr.trCtx("Background", "taskbar tray: draw a background behind the tray")
            checked: Config.bar.tray.background
            onToggled: GlobalConfig.bar.tray.background = checked
        }

        ToggleRow {
            // TRANSLATORS: tint system tray icons with the theme accent colour
            text: Tr.tr("Recolour icons")
            checked: Config.bar.tray.recolour
            onToggled: GlobalConfig.bar.tray.recolour = checked
        }

        ToggleRow {
            text: Tr.trCtx("Compact", "taskbar tray layout")
            checked: Config.bar.tray.compact
            onToggled: GlobalConfig.bar.tray.compact = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Popout on hover")
            subtext: Tr.tr("Show the tray menu popout when hovering")
            checked: Config.bar.popouts.tray
            onToggled: GlobalConfig.bar.popouts.tray = checked
        }

        // Which tray icons show (the ones there now, and any hidden before)
        SectionHeader {
            visible: trayList.count > 0
            text: Tr.tr("Icons")
        }

        Repeater {
            id: trayList

            model: {
                const items = SystemTray.items.values.filter(i => i.status !== Status.Passive || GlobalConfig.bar.tray.hiddenIcons.includes(i.id)).map(i => ({
                            id: i.id,
                            title: i.tooltipTitle || i.title || i.id
                        }));
                for (const id of GlobalConfig.bar.tray.hiddenIcons)
                    if (!items.some(i => i.id === id))
                        items.push({
                            id,
                            title: id
                        });
                return items;
            }

            ToggleRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === trayList.count - 1
                text: modelData.title
                subtext: modelData.title !== modelData.id ? modelData.id : ""
                checked: !GlobalConfig.bar.tray.hiddenIcons.includes(modelData.id)
                onToggled: {
                    const hidden = GlobalConfig.bar.tray.hiddenIcons.filter(i => i !== modelData.id);
                    GlobalConfig.bar.tray.hiddenIcons = checked ? hidden : [...hidden, modelData.id];
                }
            }
        }
    }
}

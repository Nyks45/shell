pragma ComponentBehavior: Bound

import "components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.popouts as BarPopouts

ColumnLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large

    // The pill: the launcher, the open apps and the tray, centred (the bar keeps its full
    // height, so the hover menus line up); its shape is drawn around just them
    // (pillTop .. pillBottom)
    // Where the pill sits: centred on where the edge was touched (BarWrapper.pillCenter)
    property real pillCenter: height / 2
    readonly property real pillContentH: {
        void repeater.count;
        let h = 0, n = 0;
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i) as Item;
            if (it && it.entryId !== "spacer" && it.visible) {
                h += it.implicitHeight;
                n++;
            }
        }
        return h + Math.max(0, n - 1) * spacing;
    }
    readonly property real pillLead: Math.max(vPadding * 2, Math.min(height - pillContentH - vPadding * 2, pillCenter - pillContentH / 2)) - spacing

    readonly property real pillTop: {
        void repeater.count;
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i) as Item;
            if (it && it.entryId !== "spacer" && it.visible)
                return it.y - vPadding;
        }
        return height / 2;
    }
    readonly property real pillBottom: {
        void repeater.count;
        for (let i = repeater.count - 1; i >= 0; i--) {
            const it = repeater.itemAt(i) as Item;
            if (it && it.entryId !== "spacer" && it.visible)
                return it.y + it.height + vPadding;
        }
        return height / 2;
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper)?.item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    function checkPopout(y: real): void {
        const ch = childAt(width / 2, y) as EntryWrapper;

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const top = ch.y;

        if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, tray.implicitWidth / 2, y)))) {
                const index = Math.floor(((y - top - tray.lead - tray.padding * 2 + tray.spacing) / tray.layout.implicitHeight) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, 0, trayItem.implicitHeight / 2).y);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        }
    }

    function handleWheel(y: real, angleDelta: point): void {
        if (y < screen.height / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    spacing: Tokens.spacing.medium

    Repeater {
        id: repeater

        model: ScriptModel {
            // (the tray only when something's in it: no empty space in the pill)
            values: [
                {
                    id: "spacer"
                },
                {
                    id: "logo"
                },
                {
                    id: "taskbar"
                },
                ...(SystemTray.items.values.length > 0 ? [
                        {
                            id: "tray"
                        }
                    ] : []),
                {
                    id: "spacer"
                }
            ]
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    // (the pill's first spacer sets its height on the edge)
                    Layout.fillHeight: index !== 0
                    Layout.preferredHeight: index === 0 ? Math.max(0, root.pillLead) : -1
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: EntryWrapper {
                    OsIcon {
                        objectName: "taskbarLogo"
                    }
                }
            }
            DelegateChoice {
                roleValue: "taskbar"
                delegate: EntryWrapper {
                    Taskbar {
                        objectName: "taskbarTaskbar"
                        screen: root.screen
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    Tray {
                        objectName: "taskbarTray"
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.topMargin: index === 0 ? root.vPadding : 0
        Layout.bottomMargin: index === repeater.count - 1 ? root.vPadding : 0
        Layout.alignment: Qt.AlignHCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0
        // An empty entry (no apps open, an empty tray) takes no gap either
        visible: entryId === "spacer" || implicitHeight > 0

        children: item
    }
}

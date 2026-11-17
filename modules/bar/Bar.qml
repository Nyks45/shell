pragma ComponentBehavior: Bound

import "components"
import "components/workspaces"
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
    // The power button (its menu opens from it)
    property Item powerButton

    // The pill (Config.bar.pill): the launcher, the open apps and the tray, centred (the bar
    // keeps its full height, so the hover menus line up as before); its shape is drawn around
    // just them (pillTop .. pillBottom)
    readonly property bool pill: Config.bar.pill
    readonly property var pillIds: ["logo", "taskbar", "tray"]
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
        // The power menu was clicked open: it stays until closed
        if (popouts.hasCurrent && popouts.currentName === "session")
            return;

        const ch = childAt(width / 2, y) as EntryWrapper;

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const top = ch.y;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = items.childAt(items.width / 2, mapToItem(items, 0, y).y);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, 0, icon.implicitHeight / 2).y);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
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
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = (ch.item as Item).mapToItem(root, 0, (ch.item as Item).implicitHeight / 2).y ?? 0;
            popouts.hasCurrent = true;
        }
    }

    function handleWheel(y: real, angleDelta: point): void {
        const ch = childAt(width / 2, y) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = Hypr.monitorFor(screen);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || mon.activeWorkspace?.id > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (y < screen.height / 2 && Config.bar.scrollActions.volume) {
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
            values: {
                const on = root.Config.bar.entries.values.filter(e => e.enabled);
                if (!root.pill)
                    return on;
                const spacer = {
                    id: "spacer",
                    enabled: true
                };
                // (the tray only when something's in it: no empty space in the pill)
                const ids = root.pillIds.filter(id => id !== "tray" || SystemTray.items.values.length > 0);
                return [spacer, ...on.filter(e => ids.includes(e.id)), spacer];
            }
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    // (the pill's first spacer sets its height on the edge)
                    Layout.fillHeight: !(root.pill && index === 0)
                    Layout.preferredHeight: root.pill && index === 0 ? Math.max(0, root.pillLead) : -1
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
                roleValue: "workspaces"
                delegate: EntryWrapper {
                    Workspaces {
                        objectName: "taskbarWorkspaces"
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: EntryWrapper {
                    ActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "desktopMode"
                delegate: EntryWrapper {
                    DesktopMode {
                        objectName: "taskbarDesktopMode"
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
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    Clock {
                        objectName: "taskbarClock"
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    StatusIcons {
                        objectName: "taskbarStatusIcons"
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: EntryWrapper {
                    Power {
                        id: power

                        objectName: "taskbarPowerButton"
                        screenState: root.screenState

                        Component.onCompleted: root.powerButton = power
                        Component.onDestruction: {
                            if (root.powerButton === power)
                                root.powerButton = null;
                        }
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

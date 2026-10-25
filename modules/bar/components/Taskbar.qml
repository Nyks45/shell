pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Windows-style taskbar for the vertical bar: one icon per window on this
// screen's workspace, in the order they were opened. Click focuses a window, clicking the
// focused one minimizes it, minimized windows (dimmed) come back on click.
// Minimizing needs the hyprflow plugin (hl.plugin.hyprflow.*); windows it
// minimized carry the "minimized" tag.
StyledRect {
    id: root

    required property ShellScreen screen
    required property var bar

    readonly property alias items: items
    readonly property int padding: Tokens.padding.small
    readonly property HyprlandWorkspace workspace: Hypr.monitorFor(screen)?.activeWorkspace ?? null
    // In the order they were opened (Hyprland's list order), like Windows: a
    // stable order, unlike screen positions (minimized windows keep stale ones).
    readonly property var toplevels: workspace ? Hypr.toplevelsForWs(workspace.id) : []
    readonly property real nonAnimHeight: items.count > 0 ? layout.implicitHeight + padding * 2 : 0

    // The entry under the pointer, for the bar's hover popout.
    function itemAt(y: real): Item {
        return layout.childAt(layout.width / 2, y - layout.y);
    }

    function isMinimized(t: HyprlandToplevel): bool {
        return t?.lastIpcObject.tags?.includes("minimized") ?? false;
    }

    function hyprflow(fn: string, t: HyprlandToplevel): void {
        Hypr.extras.message(`eval hl.plugin.hyprflow.${fn}("address:0x${t.address}")`);
    }

    function click(t: HyprlandToplevel): void {
        if (t === Hyprland.activeToplevel && !isMinimized(t))
            hyprflow("minimize", t);
        else
            hyprflow("activate", t);
    }

    clip: true
    visible: height > 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: nonAnimHeight

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, items.count > 0 ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Column {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.padding
        spacing: Tokens.spacing.extraSmall

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing: Tokens.anim.standardDecel
            }
        }

        move: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
            }
        }

        Repeater {
            id: items

            model: ScriptModel {
                values: root.toplevels
            }

            TaskbarItem {}
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    component TaskbarItem: Item {
        id: item

        required property HyprlandToplevel modelData
        readonly property bool active: modelData === Hyprland.activeToplevel && !minimized
        readonly property bool minimized: root.isMinimized(modelData)

        implicitWidth: Tokens.sizes.bar.innerWidth - root.padding * 2
        implicitHeight: implicitWidth

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: Colours.palette.m3secondaryContainer
            opacity: item.active ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        StateLayer {
            radius: Tokens.rounding.full
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            // This item tracks hover (for its highlight), so the bar's own hover
            // handling doesn't see it: open the title popout from here.
            onContainsMouseChanged: {
                const popouts = root.bar.popouts;
                if (containsMouse && root.Config.bar.popouts.taskbar) {
                    popouts.currentName = "taskbar";
                    popouts.taskbarToplevel = item.modelData;
                    popouts.currentCenter = Qt.binding(() => item.mapToItem(root.bar, 0, item.implicitHeight / 2).y);
                    popouts.hasCurrent = true;
                } else if (!containsMouse && popouts.currentName === "taskbar" && popouts.taskbarToplevel === item.modelData) {
                    popouts.hasCurrent = false;
                }
            }
            onClicked: event => {
                if (event.button === Qt.MiddleButton)
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${item.modelData.address}" })` : `closewindow address:0x${item.modelData.address}`);
                else
                    root.click(item.modelData);
            }
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: Math.round(parent.implicitWidth * 0.62)
            asynchronous: true
            source: Icons.getAppIcon(item.modelData.lastIpcObject.class ?? "", "image-missing")
            opacity: item.minimized ? 0.4 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}

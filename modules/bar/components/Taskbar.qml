pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Taskbar in the middle of the bar, in the style of the workspaces: a pill of
// app icons (pinned apps, then running ones) with the workspaces' stretchy
// indicator under the focused app. The focused app is in colour, others in
// grey, minimized ones faded too. Click focuses (cycling through several
// windows), minimizes the focused one, restores minimized ones, launches
// pinned apps; middle click opens a new window, right click a menu; hovering
// shows previews. See services/TaskbarApps.qml.
StyledRect {
    id: root

    required property ShellScreen screen
    required property var bar

    readonly property int wsId: Hypr.monitorFor(screen)?.activeWorkspace?.id ?? 1
    readonly property var apps: {
        CUtils.dependency(Hypr.toplevels.values);
        return TaskbarApps.appsFor(wsId, true);
    }
    readonly property Item activeItem: {
        CUtils.dependency(items.count);
        for (let i = 0; i < items.count; i++) {
            const item = items.itemAt(i) as TaskbarApp;
            if (item?.active)
                return item;
        }
        return null;
    }

    // Tell hyprflow where each window's icon is, so minimizing pours the window
    // right into it (its genie animation). Relative to the bar itself, so it's
    // right even while an auto-hiding bar is slid away.
    function reportIcons(): void {
        const msgs = [];
        for (let i = 0; i < items.count; i++) {
            const item = items.itemAt(i) as TaskbarApp;
            if (!item?.modelData)
                continue;
            const p = item.mapToItem(bar, 0, 0);
            for (const t of item.modelData.toplevels)
                msgs.push(`eval hl.plugin.hyprflow.taskbar_icon("address:0x${t.address}", ${screen.x + p.x}, ${screen.y + p.y}, ${item.width}, ${item.height})`);
        }
        if (msgs.length > 0)
            Hypr.extras.batchMessage(msgs);
    }

    clip: true
    visible: height > 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: items.count > 0 ? layout.implicitHeight + Tokens.padding.extraSmall * 2 : 0

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    // The workspaces' indicator: its leading edge moves first, the trailing one
    // follows (stretching on the way), under the focused app.
    StyledRect {
        id: indicator

        property real start
        property real end

        function runAnim(): void {
            const item = root.activeItem;
            if (!item)
                return;
            const newStart = layout.y + item.y;
            const goingUp = newStart < start;
            const leading = Tokens.anim.durations.expressiveDefaultSpatial;
            const trailing = leading * (Config.bar.workspaces.activeTrail ? 1.5 : 1);
            startAnim.stop();
            endAnim.stop();
            startAnim.to = newStart;
            endAnim.to = newStart + item.height;
            startAnim.duration = goingUp ? leading : trailing;
            endAnim.duration = goingUp ? trailing : leading;
            startAnim.start();
            endAnim.start();
        }

        anchors.horizontalCenter: parent.horizontalCenter
        y: start
        implicitWidth: parent.width - Tokens.padding.extraSmall * 2
        implicitHeight: Math.max(0, end - start)
        radius: Tokens.rounding.full
        color: Colours.palette.m3primary
        opacity: root.activeItem ? 1 : 0

        Anim on start {
            id: startAnim
        }

        Anim on end {
            id: endAnim
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Connections {
            function onActiveItemChanged(): void {
                indicator.runAnim();
            }

            target: root
        }

        Connections {
            function onYChanged(): void {
                indicator.runAnim();
            }

            target: root.activeItem
        }

        Component.onCompleted: runAnim()
    }

    Column {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.extraSmall
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
                values: root.apps
                objectProp: "key"
            }

            TaskbarApp {}
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    // Right-click menu, filled for the app it's opened on (and not changed
    // while open).
    Menu {
        id: menu

        property var app: null

        function openFor(app: var, item: Item): void {
            menu.app = app;
            const list = [];
            if (app.entry) {
                list.push(newWindowItem);
                list.push(app.pinned ? unpinItem : pinItem);
            }
            if (app.toplevels.length > 0) {
                list.push(TaskbarApps.allMinimized(app) ? restoreItem : minimizeItem);
                list.push(app.toplevels.length > 1 ? closeAllItem : closeItem);
            }
            menu.items = list;
            menu.attachTo = item;
            menu.expanded = true;
        }

        attachTo: root
        attachSideX: Menu.Right
        attachSideY: Menu.Top
        thisSideX: Menu.Left
        thisSideY: Menu.Top
        marginX: Tokens.spacing.large
        active: null
    }

    MenuItem {
        id: newWindowItem

        text: qsTr("New window")
        icon: "open_in_new"
        onClicked: TaskbarApps.launch(menu.app)
    }
    MenuItem {
        id: pinItem

        text: qsTr("Pin to taskbar")
        icon: "keep"
        onClicked: TaskbarApps.pin(menu.app.key)
    }
    MenuItem {
        id: unpinItem

        text: qsTr("Unpin from taskbar")
        icon: "keep_off"
        onClicked: TaskbarApps.unpin(menu.app.key)
    }
    MenuItem {
        id: minimizeItem

        text: qsTr("Minimize")
        icon: "minimize"
        onClicked: menu.app.toplevels.forEach(t => TaskbarApps.hyprflow("minimize", t))
    }
    MenuItem {
        id: restoreItem

        text: qsTr("Restore")
        icon: "open_in_full"
        onClicked: menu.app.toplevels.forEach(t => TaskbarApps.hyprflow("restore", t))
    }
    MenuItem {
        id: closeItem

        text: qsTr("Close window")
        icon: "close"
        onClicked: menu.app.toplevels.forEach(t => TaskbarApps.close(t))
    }
    MenuItem {
        id: closeAllItem

        text: qsTr("Close all windows")
        icon: "close"
        onClicked: menu.app.toplevels.forEach(t => TaskbarApps.close(t))
    }

    // After the icons settle (they animate in and move).
    Timer {
        id: reportTimer

        interval: 400
        onTriggered: root.reportIcons()
    }

    onAppsChanged: reportTimer.restart()
    onYChanged: reportTimer.restart()
    Component.onCompleted: reportTimer.restart()

    component TaskbarApp: Item {
        id: item

        required property var modelData
        readonly property int count: modelData.toplevels.length
        readonly property bool active: TaskbarApps.isActive(modelData)
        readonly property bool minimized: TaskbarApps.allMinimized(modelData)

        implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.extraSmall * 2
        implicitHeight: implicitWidth

        StateLayer {
            radius: Tokens.rounding.full
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            // This item tracks hover (for its highlight), so the bar's own hover
            // handling doesn't see it: open the previews from here. The drawers
            // close them once the pointer leaves the bar and the popout.
            onContainsMouseChanged: {
                const popouts = root.bar.popouts;
                if (containsMouse && root.Config.bar.popouts.taskbar && !Hypr.windowDragging && !menu.expanded) {
                    popouts.currentName = "taskbar";
                    popouts.taskbarWs = root.wsId;
                    popouts.taskbarKey = item.modelData.key;
                    popouts.currentCenter = Qt.binding(() => item.mapToItem(root.bar, 0, item.implicitHeight / 2).y);
                    popouts.hasCurrent = true;
                }
            }
            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    root.bar.popouts.hasCurrent = false;
                    menu.openFor(item.modelData, item);
                } else if (event.button === Qt.MiddleButton) {
                    TaskbarApps.launch(item.modelData);
                } else {
                    TaskbarApps.click(item.modelData);
                }
            }
        }

        // In colour when focused, grey otherwise; minimized ones fainter and
        // smaller; pinned apps that aren't open fainter still.
        IconImage {
            id: icon

            property real saturation: item.active ? 0 : -1

            anchors.centerIn: parent
            implicitSize: Math.round(parent.implicitWidth * 0.62)
            asynchronous: true
            source: item.modelData.entry?.icon ? Quickshell.iconPath(item.modelData.entry.icon, "application-x-executable") : Icons.getAppIcon(item.modelData.cls, "application-x-executable")
            opacity: item.minimized ? 0.4 : item.count === 0 ? 0.5 : item.active ? 1 : 0.8
            scale: item.minimized ? 0.82 : 1

            layer.enabled: saturation < -0.001 // only while (partly) grey
            layer.effect: MultiEffect {
                saturation: icon.saturation
            }

            Behavior on saturation {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
            Behavior on scale {
                Anim {}
            }
        }

        // Several windows: a dot for each (up to three) on the outer edge.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: item.count > 1

            Repeater {
                model: Math.min(item.count, 3)

                StyledRect {
                    required property int index

                    implicitWidth: 3
                    implicitHeight: 3
                    radius: Tokens.rounding.full
                    color: item.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }
}

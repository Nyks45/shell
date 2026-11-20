pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services

// Searchable app picker modal built on DialogRowButton. Supports installed
// DesktopEntries, live open Hyprland window classes, and optional custom text.
DialogRowButton {
    id: root

    property Item hostFlickable: null
    property string headerText: Tr.tr("Choose an app")
    property bool includeRunning: false
    property bool allowCustom: false
    property var customValidate: null
    property string customHint: Tr.tr('Use "%1" as custom class / pattern')
    property var excludeIds: []
    property var allApps: []
    property string searchQuery: ""
    property var callback: null

    function cleanCommand(app: DesktopEntry): string {
        const args = (app.command ?? []).filter(a => !/^%[a-zA-Z]$/.test(a));
        const base = args.length > 0
            ? args.map(a => /\s/.test(a) ? `"${a}"` : a).join(" ")
            : (app.execString || "").replace(/\s+%[a-zA-Z]/g, "").trim();
        if (!base)
            return "";
        return app.runInTerminal ? `${GlobalConfig.general.apps.terminal.join(" ")} -e ${base}` : base;
    }

    function buildApps(): var {
        const excluded = new Set((root.excludeIds ?? []).map(x => String(x).toLowerCase()));
        const runningById = {};
        const unmatchedRunning = [];

        if (root.includeRunning) {
            const seenCls = new Set();
            for (const t of Hyprland.toplevels.values) {
                const cls = t.lastIpcObject?.class ?? "";
                if (!cls || seenCls.has(cls))
                    continue;
                seenCls.add(cls);
                const match = DesktopEntries.heuristicLookup(cls);
                if (match && !match.noDisplay) {
                    if (!runningById[match.id])
                        runningById[match.id] = cls;
                } else if (!excluded.has(cls.toLowerCase())) {
                    unmatchedRunning.push({
                        id: cls,
                        name: cls,
                        icon: "",
                        wmClass: cls,
                        command: "",
                        comment: Tr.tr("Open window"),
                        desktopEntry: null,
                        running: true,
                        custom: false
                    });
                }
            }
        }

        const out = [...unmatchedRunning];
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay)
                continue;
            const wmClass = runningById[a.id] || a.startupClass || a.id;
            if (excluded.has(a.id.toLowerCase()) || excluded.has(wmClass.toLowerCase()))
                continue;
            out.push({
                id: a.id,
                name: a.name || a.id,
                icon: a.icon || "",
                wmClass,
                command: cleanCommand(a),
                comment: a.comment || a.genericName || "",
                desktopEntry: a,
                running: !!runningById[a.id],
                custom: false
            });
        }

        out.sort((a, b) => {
            if (root.includeRunning && a.running !== b.running)
                return a.running ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return out;
    }

    function openPicker(opts: var): void {
        const o = opts ?? {};
        headerText = o.header ?? Tr.tr("Choose an app");
        includeRunning = !!o.includeRunning;
        allowCustom = !!o.allowCustom;
        customValidate = o.customValidate ?? null;
        customHint = o.customHint ?? Tr.tr('Use "%1" as custom class / pattern');
        excludeIds = o.excludeIds ?? [];
        callback = o.onPicked ?? null;
        searchQuery = "";
        allApps = buildApps();
        open = true;
    }

    function pick(item: var): void {
        const cb = callback;
        callback = null;
        open = false;
        if (typeof cb === "function")
            cb(item);
    }

    visible: false
    rootParent: hostFlickable
    openWidth: Math.min((hostFlickable?.width ?? 600) * 0.85, 480)
    openHeight: Math.min((hostFlickable?.height ?? 600) * 0.85, 560)
    icon: "apps"
    label: ""
    header: headerText
    acceptLabel: ""
    showAccept: false
    showCancel: true
    onCancelled: callback = null
    onOpenChanged: if (!open)
        callback = null

    content: Component {
        ColumnLayout {
            id: modalCol

            readonly property var filtered: {
                const q = root.searchQuery.trim().toLowerCase();
                if (!q)
                    return root.allApps;
                return root.allApps.filter(a => `${a.name} ${a.id} ${a.wmClass} ${a.comment}`.toLowerCase().includes(q));
            }
            readonly property string customText: root.searchQuery.trim()
            readonly property bool customOk: {
                if (!root.allowCustom || !customText)
                    return false;
                if (!root.customValidate)
                    return true;
                return typeof root.customValidate === "function" ? !!root.customValidate(customText) : root.customValidate.test(customText);
            }

            spacing: Tokens.spacing.small

            StyledTextField {
                id: searchField

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.medium
                leadingIcon: "search"
                verticalPadding: Tokens.padding.small
                floatingPlaceholder: false
                placeholderText: Tr.tr("Search apps…")
                text: root.searchQuery
                onTextChanged: root.searchQuery = text
                onAccepted: {
                    if (modalCol.filtered.length === 1)
                        root.pick(modalCol.filtered[0]);
                }
                Keys.onEscapePressed: root.open = false
                Component.onCompleted: forceActiveFocus()
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.bottomMargin: Tokens.spacing.small

                ListView {
                    id: appView

                    anchors.fill: parent
                    clip: true
                    spacing: Tokens.spacing.extraSmall
                    model: modalCol.filtered

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: appView
                    }

                    delegate: StyledRect {
                        id: entryRect

                        required property var modelData

                        width: appView.width
                        implicitHeight: 54
                        radius: Tokens.rounding.medium
                        color: Colours.tPalette.m3surfaceContainerHigh

                        StateLayer {
                            anchors.fill: parent
                            radius: entryRect.radius
                            onClicked: root.pick(entryRect.modelData)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            Item {
                                implicitWidth: 32
                                implicitHeight: 32

                                ThemedIcon {
                                    anchors.fill: parent
                                    asynchronous: true
                                    monochrome: true
                                    visible: entryRect.modelData.icon.length > 0
                                    source: entryRect.modelData.icon ? Quickshell.iconPath(entryRect.modelData.icon, "application-x-executable") : ""
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: entryRect.modelData.icon.length === 0
                                    text: "apps"
                                    color: Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.medium
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: entryRect.modelData.name
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: entryRect.modelData.comment || entryRect.modelData.wmClass || entryRect.modelData.id
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3outline
                                    elide: Text.ElideRight
                                }
                            }

                            StyledRect {
                                visible: entryRect.modelData.running
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: openBadgeText.implicitWidth + Tokens.padding.small * 2
                                implicitHeight: openBadgeText.implicitHeight + Tokens.padding.extraSmall
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3secondaryContainer

                                StyledText {
                                    id: openBadgeText

                                    anchors.centerIn: parent
                                    text: Tr.tr("Open")
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSecondaryContainer
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.large * 2
                    visible: modalCol.filtered.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: modalCol.customOk ? Tr.tr("No matching installed apps") : Tr.tr("No matching apps")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }

            StyledRect {
                Layout.fillWidth: true
                visible: modalCol.customOk
                implicitHeight: customRow.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.medium
                color: Colours.palette.m3secondaryContainer

                StateLayer {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colours.palette.m3onSecondaryContainer
                    onClicked: {
                        const q = modalCol.customText;
                        root.pick({
                            id: q,
                            name: q,
                            icon: "",
                            wmClass: q,
                            command: q,
                            comment: "",
                            desktopEntry: null,
                            running: false,
                            custom: true
                        });
                    }
                }

                RowLayout {
                    id: customRow

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "code"
                        color: Colours.palette.m3onSecondaryContainer
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.customHint.arg(modalCol.customText)
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.label.medium
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}

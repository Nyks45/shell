pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.nexus.common

// Per-app window rules (Hyprland windowRules): float, centre, pin across
// workspaces, target workspace, opacity, keep awake, tearing.
PageBase {
    id: root

    readonly property var rules: HyprSettings.saved.windowRules ?? []
    property int openRule: -1

    function setRule(index: int, changes: var): void {
        const next = rules.map(r => Object.assign({}, r));
        Object.assign(next[index], changes);
        HyprSettings.setWindowRules(next);
    }

    function removeRule(index: int): void {
        const next = [...rules];
        next.splice(index, 1);
        openRule = -1;
        HyprSettings.setWindowRules(next);
    }

    // A picked app (AppPickerDialog item): its exact class, or, when the class
    // is only guessed from the desktop id, any case and the id's last part
    function addRule(item: var): void {
        const esc = c => c.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const names = [item.wmClass || item.id, item.classAlt].filter(x => x).map(esc);
        const index = rules.length;
        HyprSettings.setWindowRules([...rules, {
                class: `${item.classGuessed ? "(?i)" : ""}^(${names.join("|")})$`,
                float: true
            }]);
        openRule = index; // the new one, open to edit
    }

    title: Tr.tr("App rules")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("App rules")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("How an app's windows open: floating, centred, on a workspace, see-through, keeping the screen awake.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            id: ruleList

            model: root.rules

            RuleRow {}
        }

        RowButton {
            icon: "add"
            text: Tr.tr("Add an app rule")
            subtext: Tr.tr("Pick any installed or open app")
            onClicked: appPicker.openPicker({
                header: Tr.tr("Add an app rule"),
                includeRunning: true,
                allowCustom: true,
                onPicked: item => root.addRule(item)
            })
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }

        AppPickerDialog {
            id: appPicker

            hostFlickable: root.flickable
        }
    }

    component RuleRow: ConnectedRect {
        id: rule

        required property var modelData
        required property int index
        readonly property bool open: root.openRule === index
        // ^(org\.gnome\.Nautilus)$ -> org.gnome.Nautilus
        readonly property string app: modelData.class.replace(/^\^\(/, "").replace(/\)\$$/, "").replace(/\\(.)/g, "$1")
        readonly property DesktopEntry desktopEntry: DesktopEntries.heuristicLookup(app) ?? DesktopEntries.byId(app)
        readonly property string displayName: desktopEntry ? desktopEntry.name : app
        property real draftOpacity: -1
        readonly property real shownOpacity: draftOpacity > 0 ? draftOpacity : (modelData.opacity ?? 1)

        Timer {
            id: opacityDebounce

            interval: 150
            onTriggered: {
                if (rule.draftOpacity > 0) {
                    const v = rule.draftOpacity;
                    rule.draftOpacity = -1;
                    root.setRule(rule.index, {
                        opacity: v
                    });
                }
            }
        }

        Layout.fillWidth: true
        implicitHeight: ruleLayout.implicitHeight + Tokens.padding.medium * 2

        Behavior on implicitHeight {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            StateLayer {
                anchors.fill: parent
                topLeftRadius: rule.topLeftRadius
                topRightRadius: rule.topRightRadius
                bottomLeftRadius: rule.bottomLeftRadius
                bottomRightRadius: rule.bottomRightRadius
                disabled: rule.open
                onClicked: root.openRule = rule.index
            }

            ColumnLayout {
                id: ruleLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    Item {
                        implicitWidth: 28
                        implicitHeight: 28

                        ThemedIcon {
                            anchors.fill: parent
                            asynchronous: true
                            monochrome: true
                            visible: !!(rule.desktopEntry?.icon)
                            source: rule.desktopEntry?.icon ? Quickshell.iconPath(rule.desktopEntry.icon, "application-x-executable") : ""
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !(rule.desktopEntry?.icon)
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
                            text: rule.displayName
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const m = rule.modelData;
                                const parts = [];
                                if (m.float)
                                    parts.push(Tr.tr("floating"));
                                if (m.center)
                                    parts.push(Tr.tr("centred"));
                                if (m.pin)
                                    parts.push(Tr.tr("on every workspace"));
                                if (m.workspace)
                                    parts.push(Tr.tr("workspace %1").arg(m.workspace));
                                if (m.opacity && m.opacity < 1)
                                    parts.push(`${Math.round(m.opacity * 100)}%`);
                                if (m.idleInhibit)
                                    parts.push(Tr.tr("keeps awake"));
                                if (m.immediate)
                                    parts.push(Tr.tr("tearing allowed"));
                                return parts.join(", ") || Tr.tr("No changes");
                            }
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        icon: rule.open ? "expand_less" : "expand_more"
                        type: IconButton.Text
                        onClicked: root.openRule = rule.open ? -1 : rule.index
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        onClicked: confirmDialog.ask({
                            header: Tr.tr("Delete rule for %1?").arg(rule.displayName),
                            body: Tr.tr("Removes this app's window opening rules."),
                            confirmLabel: Tr.trCtx("Delete", "button"),
                            onConfirm: () => root.removeRule(rule.index)
                        })
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    visible: rule.open
                    columns: 2
                    columnSpacing: Tokens.spacing.medium
                    rowSpacing: Tokens.spacing.small

                    RuleSwitch {
                        text: Tr.tr("Floating")
                        checked: !!rule.modelData.float
                        onToggled: root.setRule(rule.index, {
                            float: checked
                        })
                    }

                    RuleSwitch {
                        text: Tr.tr("Centred")
                        checked: !!rule.modelData.center
                        onToggled: root.setRule(rule.index, {
                            center: checked
                        })
                    }

                    RuleSwitch {
                        text: Tr.tr("On every workspace")
                        checked: !!rule.modelData.pin
                        onToggled: root.setRule(rule.index, {
                            pin: checked,
                            float: checked || rule.modelData.float
                        })
                    }

                    RuleSwitch {
                        text: Tr.tr("Keep awake while focused")
                        checked: !!rule.modelData.idleInhibit
                        onToggled: root.setRule(rule.index, {
                            idleInhibit: checked ? "focus" : ""
                        })
                    }

                    RuleSwitch {
                        text: Tr.tr("Reduce input latency (allow tearing)")
                        checked: !!rule.modelData.immediate
                        onToggled: root.setRule(rule.index, {
                            immediate: checked
                        })
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: rule.open
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: Tr.tr("Workspace")
                        font: Tokens.font.body.small
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    IconButton {
                        icon: "remove"
                        type: IconButton.Tonal
                        disabled: !(rule.modelData.workspace > 0)
                        onClicked: root.setRule(rule.index, {
                            workspace: Math.max(0, (rule.modelData.workspace ?? 0) - 1)
                        })
                    }

                    StyledText {
                        Layout.minimumWidth: 60
                        horizontalAlignment: Text.AlignHCenter
                        text: rule.modelData.workspace > 0 ? String(rule.modelData.workspace) : Tr.tr("Any")
                        font: Tokens.font.body.small
                    }

                    IconButton {
                        icon: "add"
                        type: IconButton.Tonal
                        disabled: (rule.modelData.workspace ?? 0) >= 10
                        onClicked: root.setRule(rule.index, {
                            workspace: (rule.modelData.workspace ?? 0) + 1
                        })
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: rule.open
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: Tr.tr("Opacity")
                        font: Tokens.font.body.small
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        from: 0.3
                        to: 1
                        value: rule.shownOpacity
                        onMoved: {
                            rule.draftOpacity = Math.round(value * 100) / 100;
                            opacityDebounce.restart();
                        }
                    }

                    StyledText {
                        Layout.minimumWidth: 40
                        text: `${Math.round(rule.shownOpacity * 100)}%`
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: rule.open
                    text: Tr.tr("Window class: %1 · Applies to windows opened from now on.").arg(rule.app)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component RuleSwitch: RowLayout {
        property alias text: switchLabel.text
        property alias checked: sw.checked

        signal toggled

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            id: switchLabel

            Layout.fillWidth: true
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }

        StyledSwitch {
            id: sw

            onToggled: parent.toggled()
        }
    }
}

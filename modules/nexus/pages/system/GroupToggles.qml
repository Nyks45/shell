pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

// A person's memberships of the groups that give access to hardware and
// services (audio, video, input, printers...), one switch each; through the
// root helper (it only changes these groups).
ColumnLayout {
    id: root

    required property var user // { name, groups }
    required property var groups // [{ name, about }]
    property Item hostFlickable: null
    // Called after a change (to read the accounts again)
    property var changed: null
    readonly property var criticalGroups: ["audio", "video", "input", "storage", "network"]

    spacing: Tokens.spacing.extraSmall / 2

    Repeater {
        model: root.groups.filter(g => g.name !== "wheel")

        ToggleRow {
            id: row

            required property var modelData

            text: modelData.about
            subtext: root.criticalGroups.includes(modelData.name) ? Tr.tr("Group %1 · Required for normal desktop use").arg(modelData.name) : Tr.tr("Group %1").arg(modelData.name)
            checked: root.user?.groups.includes(modelData.name) ?? false
            onToggled: {
                const runChange = add => Admin.run("group-member", [root.user.name, modelData.name, add ? "add" : "remove"], add ? Tr.tr("Add %1 to %2").arg(root.user.name).arg(modelData.name) : Tr.tr("Remove %1 from %2").arg(root.user.name).arg(modelData.name), () => {
                    if (typeof root.changed === "function")
                        root.changed();
                });
                if (!checked && root.user?.name === SysInfo.user && root.criticalGroups.includes(modelData.name) && root.hostFlickable) {
                    checked = Qt.binding(() => root.user?.groups.includes(row.modelData.name) ?? false);
                    confirmDialog.ask({
                        header: Tr.tr("Remove yourself from %1?").arg(modelData.name),
                        body: Tr.tr("Takes away %1 access for %2 after your next sign-in.").arg(modelData.about.toLowerCase()).arg(root.user.name),
                        confirmLabel: Tr.tr("Remove"),
                        onConfirm: () => runChange(false)
                    });
                    return;
                }
                runChange(checked);
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.small
        Layout.topMargin: Tokens.spacing.small
        text: Tr.tr("A new group membership counts from the next sign-in.")
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
        wrapMode: Text.WordWrap
    }

    ConfirmDialog {
        id: confirmDialog

        visible: false
        hostFlickable: root.hostFlickable
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// A person's memberships of the groups that give access to hardware and
// services (audio, video, input, printers...), one switch each; through the
// root helper (it only changes these groups).
ColumnLayout {
    id: root

    required property var user // { name, groups }
    required property var groups // [{ name, about }]
    // Called after a change (to read the accounts again)
    property var changed: null

    spacing: Tokens.spacing.extraSmall / 2

    Repeater {
        model: root.groups.filter(g => g.name !== "wheel")

        ToggleRow {
            required property var modelData

            text: modelData.about
            subtext: Tr.tr("Group %1").arg(modelData.name)
            checked: root.user?.groups.includes(modelData.name) ?? false
            onToggled: Admin.run("group-member", [root.user.name, modelData.name, checked ? "add" : "remove"], checked ? Tr.tr("Add %1 to %2").arg(root.user.name).arg(modelData.name) : Tr.tr("Remove %1 from %2").arg(root.user.name).arg(modelData.name), () => {
                if (typeof root.changed === "function")
                    root.changed();
            })
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
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages.disks

// Another person's account: administrator or not, a new password, their
// groups, removing the account (keeping their files or not). Changes go
// through AccountsService (the shell's password prompt).
PageBase {
    id: root

    readonly property var user: Users.find(nState.selectedUser)
    property string newPassword
    property string repeat
    property bool removeFiles

    title: user ? (user.fullName || user.name) : Tr.tr("Account")
    isSubPage: true

    Component.onCompleted: Users.reload()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            visible: !root.user
            text: Tr.tr("This account isn't there any more.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }

        InfoRow {
            visible: !!root.user
            icon: "person"
            label: root.user?.name ?? ""
            subtext: root.user ? Tr.tr("Home folder %1").arg(root.user.home) : ""
            value: root.user?.admin ? Tr.tr("Administrator") : Tr.tr("Standard user")
        }

        SectionHeader {
            visible: !!root.user
            text: Tr.tr("Account")
        }

        ToggleRow {
            visible: !!root.user && !root.user.me
            text: Tr.tr("Administrator")
            subtext: Tr.tr("Can change system settings and install apps (with their password)")
            checked: root.user?.admin ?? false
            onToggled: Users.change(["user-type", root.user.name, checked ? "admin" : "standard"], checked ? Tr.tr("Make %1 an administrator").arg(root.user.name) : Tr.tr("Make %1 a standard user").arg(root.user.name))
        }

        DialogRowButton {
            id: pwDialog

            readonly property string what: Tr.tr("Set a new password for %1").arg(root.user?.name ?? "")

            visible: !!root.user && !root.user.me
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.95, 380)
            icon: "password"
            label: Tr.tr("Set a new password")
            header: pwDialog.what
            acceptLabel: Tr.trCtx("Set", "button")
            acceptAllowed: root.newPassword.length > 0 && root.newPassword === root.repeat
            onOpenChanged: if (!open) {
                root.newPassword = "";
                root.repeat = "";
            }
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledTextField {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("New password")
                        leadingIcon: "key"
                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: root.newPassword = text
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("Repeat it")
                        leadingIcon: "key"
                        supportingText: text.length > 0 && text !== root.newPassword ? Tr.tr("The two don't match yet") : ""
                        onTextChanged: root.repeat = text
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: {
                const pw = root.newPassword;
                root.newPassword = "";
                root.repeat = "";
                Users.change(["user-password", root.user.name], what, null, pw);
            }
        }

        SectionHeader {
            visible: !!root.user
            text: Tr.tr("Groups")
        }

        GroupToggles {
            visible: !!root.user
            Layout.fillWidth: true
            user: root.user
            groups: Users.groups
            changed: () => Users.reload()
        }

        SectionHeader {
            visible: !!root.user && !root.user.me
            text: Tr.tr("Remove")
        }

        ToggleRow {
            visible: !!root.user && !root.user.me
            text: Tr.tr("Delete their files too")
            subtext: root.removeFiles ? Tr.tr("Their home folder %1 is deleted with the account").arg(root.user?.home ?? "") : Tr.tr("Their home folder stays")
            checked: root.removeFiles
            onToggled: root.removeFiles = checked
        }

        ConfirmButton {
            visible: !!root.user && !root.user.me
            rootParent: root.flickable
            icon: "person_remove"
            label: Tr.tr("Remove this account")
            header: Tr.tr("Remove %1?").arg(root.user?.name ?? "")
            message: root.removeFiles ? Tr.tr("The account and all its files (%1) are deleted.").arg(root.user?.home ?? "") : Tr.tr("The account is removed; its home folder %1 stays.").arg(root.user?.home ?? "")
            confirmText: root.user?.name ?? ""
            acceptLabel: Tr.trCtx("Remove", "button")
            onAccepted: Users.change(["user-delete", root.user.name, ...(root.removeFiles ? ["--remove-files"] : [])], Tr.tr("Remove the account %1").arg(root.user.name), ok => {
                if (ok)
                    root.nState.closeSubPage();
            })
        }
    }
}

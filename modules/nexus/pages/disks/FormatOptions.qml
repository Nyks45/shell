pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// What to make a partition into: the filesystem (with what each one is good
// for), a label, encryption (a passphrase, twice) and, when formatting,
// overwriting the old data. Its values live in `spec` (the dialog's, so they
// survive the dialog's content being made again).
ColumnLayout {
    id: root

    required property QtObject spec
    property bool showErase

    readonly property var choices: [
        {
            type: "ext4",
            name: "ext4",
            about: Tr.tr("Linux: the reliable default")
        },
        {
            type: "btrfs",
            name: "Btrfs",
            about: Tr.tr("Linux: snapshots, compression")
        },
        {
            type: "xfs",
            name: "XFS",
            about: Tr.tr("Linux: big files, can't shrink")
        },
        {
            type: "f2fs",
            name: "F2FS",
            about: Tr.tr("Linux: made for flash memory")
        },
        {
            type: "exfat",
            name: "exFAT",
            about: Tr.tr("USB drives: every system reads it")
        },
        {
            type: "ntfs",
            name: "NTFS",
            about: Tr.tr("Shared with Windows")
        },
        {
            type: "vfat",
            name: "FAT32",
            about: Tr.tr("Old devices, files under 4 GB")
        },
        {
            type: "swap",
            name: Tr.tr("Swap"),
            about: Tr.tr("Extra memory on the drive")
        }
    ]
    readonly property bool canEncrypt: spec.fstype !== "swap" && spec.fstype !== "empty"

    spacing: Tokens.spacing.small

    Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.choices

            TextButton {
                required property var modelData

                text: modelData.name
                isToggle: true
                followChecked: true
                checked: root.spec.fstype === modelData.type
                type: TextButton.Tonal
                onClicked: root.spec.fstype = modelData.type
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: root.choices.find(c => c.type === root.spec.fstype)?.about ?? ""
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    StyledTextField {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        visible: root.spec.fstype !== "empty"
        text: root.spec.label
        placeholderText: Tr.tr("Name (optional)")
        leadingIcon: "label"
        maximumLength: root.spec.fstype === "vfat" ? 11 : 32
        onTextChanged: root.spec.label = text
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.canEncrypt

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Encrypt it (asks for a passphrase to open it)")
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledSwitch {
            checked: root.spec.encrypt
            onToggled: root.spec.encrypt = checked
        }
    }

    StyledTextField {
        Layout.fillWidth: true
        visible: root.canEncrypt && root.spec.encrypt
        echoMode: TextInput.Password
        text: root.spec.passphrase
        placeholderText: Tr.tr("Passphrase")
        leadingIcon: "key"
        onTextChanged: root.spec.passphrase = text
    }

    StyledTextField {
        Layout.fillWidth: true
        visible: root.canEncrypt && root.spec.encrypt
        echoMode: TextInput.Password
        text: root.spec.repeat
        placeholderText: Tr.tr("Passphrase again")
        leadingIcon: "key"
        supportingText: text.length > 0 && text !== root.spec.passphrase ? Tr.tr("The two don't match yet") : Tr.tr("Without it the data can't be read: there is no way to recover it.")
        onTextChanged: root.spec.repeat = text
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.showErase

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Overwrite the old data with zeros (slow; so it can't be recovered)")
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledSwitch {
            checked: root.spec.erase
            onToggled: root.spec.erase = checked
        }
    }
}

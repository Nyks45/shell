pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common
import qs.modules.nexus.pages.system

// The user's account: picture (~/.face, shown on the dashboard and the lock
// screen), name and password (AccountsService) and the computer's name
// (hostnamectl). Name, password and computer-name changes ask for the
// password through polkit (the shell's prompt).
PageBase {
    id: root

    property string userName: Quickshell.env("USER")
    property string realName
    property string hostname
    property bool admin
    property int uid: -1
    // Whether there is a picture (no file: the placeholder, without a load error)
    property bool hasFace

    function checkFace(): void {
        faceProc.running = false;
        faceProc.running = true;
    }

    // The password dialog's fields (cleared as soon as it is used)
    property string newPassword
    property string repeatPassword
    property string passwordStatus

    title: Tr.tr("Account")

    Component.onCompleted: Users.reload()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: infoProc

            running: true
            command: ["sh", "-c", "id -u; id -nG; getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1; hostnamectl hostname 2>/dev/null || cat /etc/hostname"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n");
                    root.uid = parseInt(lines[0]);
                    root.admin = (lines[1] ?? "").split(/\s+/).includes("wheel");
                    root.realName = lines[2] ?? "";
                    root.hostname = (lines[3] ?? "").trim();
                }
            }
        }

        Process {
            id: faceProc

            running: true
            command: ["test", "-s", Paths.face]
            onExited: code => root.hasFace = code === 0
        }

        Connections {
            function onFaceSourceChanged(): void {
                if (Paths.faceSource)
                    root.checkFace();
            }

            target: Paths
        }

        FileDialog {
            id: picker

            title: Tr.tr("Select a profile picture")
            filterLabel: Tr.tr("Image files")
            filters: Images.validImageExtensions
            onAccepted: path => {
                if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(Paths.face)))
                    Paths.reloadFace();
            }
        }

        // Picture and name
        Item {
            Layout.fillWidth: true
            implicitHeight: header.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: header

                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 112
                    implicitHeight: 112

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            text: "person"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.extraLarge
                            fill: 1
                        }

                        Image {
                            id: face

                            anchors.fill: parent
                            source: root.hasFace && Paths.faceSource ? `file://${Paths.faceSource}` : ""
                            sourceSize: Qt.size(224, 224)
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            asynchronous: true
                        }
                    }

                    StyledRect {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "edit"
                            color: Colours.palette.m3onPrimary
                            fontStyle: Tokens.font.icon.small
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: picker.open()
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.realName || root.userName
                    font: Tokens.font.title.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.admin ? Tr.tr("%1 · Administrator").arg(root.userName) : Tr.tr("%1 · Standard user").arg(root.userName)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Profile")
        }

        RowButton {
            icon: "add_photo_alternate"
            text: Tr.tr("Change picture")
            subtext: Tr.tr("Shown on the dashboard and the lock screen")
            onClicked: picker.open()
        }

        RowButton {
            visible: root.hasFace
            icon: "hide_image"
            text: Tr.tr("Remove picture")
            onClicked: {
                CUtils.deleteFile(Qt.resolvedUrl(Paths.face));
                Paths.reloadFace();
            }
        }

        TextFieldRow {
            label: Tr.tr("Full name")
            subtext: Tr.tr("Asks for your password")
            value: root.realName
            placeholderText: root.userName
            onEditingFinished: v => {
                if (v === root.realName || root.uid < 0)
                    return;
                root.realName = v;
                Quickshell.execDetached(["busctl", "call", "org.freedesktop.Accounts", `/org/freedesktop/Accounts/User${root.uid}`, "org.freedesktop.Accounts.User", "SetRealName", "s", v]);
                reloadInfo.restart();
            }
        }

        SectionHeader {
            text: Tr.tr("Sign-in")
        }

        DialogRowButton {
            id: passwordDialog

            readonly property string what: Tr.tr("Change your password")

            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.95, 430)
            icon: "password"
            label: root.passwordStatus || Tr.tr("Change password")
            header: Tr.tr("Change password")
            acceptLabel: Tr.trCtx("Change", "button")
            acceptAllowed: root.newPassword.length > 0 && root.newPassword === root.repeatPassword && !Admin.jobs.some(j => j.what === what)

            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        text: Tr.tr("For signing in and unlocking the screen. You'll be asked for the current one.")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    StyledTextField {
                        Layout.fillWidth: true
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
                        onTextChanged: root.repeatPassword = text
                        onAccepted: if (passwordDialog.acceptAllowed) {
                            passwordDialog.accepted();
                            passwordDialog.open = false;
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            onOpenChanged: if (!open) {
                root.repeatPassword = "";
                if (!Admin.jobs.some(j => j.what === what))
                    root.newPassword = "";
            }
            onAccepted: {
                const pw = root.newPassword;
                root.newPassword = "";
                root.repeatPassword = "";
                root.passwordStatus = Tr.tr("Changing the password…");
                Admin.exec([`${Paths.libdir}/caelestia-set-password`], what, (ok, out, cancelled) => {
                    root.passwordStatus = ok ? Tr.tr("Password changed") : "";
                    if (ok)
                        passwordStatusReset.restart();
                }, pw);
            }

            Timer {
                id: passwordStatusReset

                interval: 5000
                onTriggered: root.passwordStatus = ""
            }
        }

        // ---- Your groups ----------------------------------------------------
        SectionHeader {
            visible: !!Users.me
            text: Tr.tr("Your access")
        }

        GroupToggles {
            visible: !!Users.me
            Layout.fillWidth: true
            user: Users.me
            groups: Users.groups
            changed: () => Users.reload()
        }

        // ---- Other people ---------------------------------------------------
        SectionHeader {
            text: Tr.tr("Other people")
        }

        Repeater {
            model: Users.users.filter(u => !u.me)

            NavRow {
                required property var modelData

                icon: "person"
                text: modelData.fullName || modelData.name
                subtext: [modelData.name, modelData.admin ? Tr.tr("administrator") : Tr.tr("standard user")].join(" · ")
                onClicked: {
                    root.nState.selectedUser = modelData.name;
                    root.nState.openSubPage(1);
                }
            }
        }

        DialogRowButton {
            id: addUser

            readonly property string what: Tr.tr("Add an account")
            property string userName
            property string fullName
            property bool admin
            property string pass
            property string repeat
            readonly property bool nameOk: /^[a-z_][a-z0-9_-]{0,31}$/.test(userName) && !Users.find(userName)

            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.95, 560)
            icon: "person_add"
            label: Tr.tr("Add someone")
            header: what
            acceptLabel: Tr.trCtx("Add", "button")
            acceptAllowed: nameOk && pass.length > 0 && pass === repeat
            onOpenChanged: {
                userName = "";
                fullName = "";
                admin = false;
                pass = "";
                repeat = "";
            }
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledTextField {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        placeholderText: Tr.tr("Full name")
                        leadingIcon: "badge"
                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: {
                            addUser.fullName = text;
                            // A user name from it until one is typed
                            if (!userField.edited)
                                userField.text = text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "").slice(0, 32);
                        }
                    }

                    StyledTextField {
                        id: userField

                        property bool edited

                        Layout.fillWidth: true
                        placeholderText: Tr.tr("User name (lowercase, for signing in)")
                        leadingIcon: "person"
                        supportingText: text && !addUser.nameOk ? (Users.find(text) ? Tr.tr("That name is taken") : Tr.tr("Lowercase letters, digits, - and _; starting with a letter")) : ""
                        onTextEdited: edited = true
                        onTextChanged: addUser.userName = text
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("Administrator (can change system settings)")
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                        }

                        StyledSwitch {
                            checked: addUser.admin
                            onToggled: addUser.admin = checked
                        }
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("Password")
                        leadingIcon: "key"
                        onTextChanged: addUser.pass = text
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("Repeat it")
                        leadingIcon: "key"
                        supportingText: text.length > 0 && text !== addUser.pass ? Tr.tr("The two don't match yet") : ""
                        onTextChanged: addUser.repeat = text
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: {
                const pw = pass;
                pass = "";
                repeat = "";
                Users.change(["user-add", userName, fullName, admin ? "admin" : "standard"], what, null, pw);
            }
        }

        SectionHeader {
            text: Tr.tr("This computer")
        }

        TextFieldRow {
            label: Tr.tr("Computer name")
            subtext: Tr.tr("How it shows up on networks and Bluetooth; asks for your password")
            value: root.hostname
            validate: t => /^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(t)
            errorText: Tr.tr("Letters, numbers and dashes only")
            onEditingFinished: v => {
                if (!v || v === root.hostname || !/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(v))
                    return;
                root.hostname = v;
                Quickshell.execDetached(["hostnamectl", "set-hostname", v]);
                reloadInfo.restart();
            }
        }

        // Read back what took (a cancelled password prompt changes nothing)
        Timer {
            id: reloadInfo

            interval: 8000
            onTriggered: infoProc.running = true
        }
    }
}

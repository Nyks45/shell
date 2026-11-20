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
    property bool showGroups: false

    function checkFace(): void {
        faceProc.running = false;
        faceProc.running = true;
    }

    // The password dialog's fields (cleared as soon as it is used)
    property string currentPassword
    property string newPassword
    property string repeatPassword
    property string passwordStatus
    property string passwordWarning
    property bool passwordFailed

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

        Process {
            id: realNameSaveProc

            property string pendingValue
            property string errText

            stderr: StdioCollector {
                onStreamFinished: realNameSaveProc.errText = text.trim()
            }
            onExited: code => {
                if (code === 0) {
                    root.realName = pendingValue;
                    Toaster.toast(Tr.tr("Full name updated"), pendingValue || root.userName, "badge");
                    infoProc.running = true;
                } else {
                    Toaster.toast(Tr.tr("Couldn't change full name"), errText || Tr.tr("The change was cancelled or refused."), "error");
                }
            }
        }

        Process {
            id: hostSaveProc

            property string pendingValue
            property string errText

            stderr: StdioCollector {
                onStreamFinished: hostSaveProc.errText = text.trim()
            }
            onExited: code => {
                if (code === 0) {
                    root.hostname = pendingValue;
                    Toaster.toast(Tr.tr("Computer name updated"), pendingValue, "computer");
                    infoProc.running = true;
                } else {
                    Toaster.toast(Tr.tr("Couldn't change computer name"), errText || Tr.tr("The change was cancelled or refused."), "error");
                }
            }
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
            onClicked: removeFaceDialog.ask({
                header: Tr.tr("Remove profile picture?"),
                body: Tr.tr("Delete your profile picture (~/.face)? You can pick another one at any time."),
                confirmLabel: Tr.tr("Remove"),
                icon: "hide_image",
                onConfirm: () => {
                    CUtils.deleteFile(Qt.resolvedUrl(Paths.face));
                    Paths.reloadFace();
                }
            })
        }

        ConnectedRect {
            readonly property string label: Tr.tr("Full name")

            Layout.fillWidth: true
            implicitHeight: fullNameRow.implicitHeight + Tokens.padding.medium + Math.max(0, Tokens.padding.large - fullNameField.verticalPadding) * 2

            RowLayout {
                id: fullNameRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Full name")
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: realNameSaveProc.running ? Tr.tr("Saving…") : Tr.tr("Asks for your password when you save")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }

                StyledTextField {
                    id: fullNameField

                    Layout.preferredWidth: Tokens.sizes.nexus.textFieldWidth
                    Layout.maximumWidth: parent.width * 0.42
                    Layout.alignment: Qt.AlignVCenter
                    verticalPadding: Tokens.padding.small
                    floatingPlaceholder: false
                    placeholderText: root.userName
                    text: root.realName
                    onAccepted: if (!saveRealNameBtn.disabled)
                        saveRealNameBtn.clicked(null)
                }

                TextButton {
                    id: saveRealNameBtn

                    Layout.alignment: Qt.AlignVCenter
                    text: Tr.trCtx("Save", "button")
                    type: TextButton.Tonal
                    disabled: fullNameField.text === root.realName || root.uid < 0 || realNameSaveProc.running
                    onClicked: {
                        realNameSaveProc.pendingValue = fullNameField.text;
                        realNameSaveProc.errText = "";
                        realNameSaveProc.command = ["busctl", "call", "org.freedesktop.Accounts", `/org/freedesktop/Accounts/User${root.uid}`, "org.freedesktop.Accounts.User", "SetRealName", "s", fullNameField.text];
                        realNameSaveProc.running = true;
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Sign-in")
        }

        DialogRowButton {
            id: passwordDialog

            readonly property string what: Tr.tr("Change your password")

            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.95, 550)
            icon: "password"
            label: root.passwordStatus || Tr.tr("Change password")
            header: Tr.tr("Change password")
            acceptLabel: Tr.trCtx("Change", "button")
            acceptAllowed: root.currentPassword.length > 0 && root.newPassword.length > 0 && root.newPassword === root.repeatPassword && root.newPassword !== root.currentPassword && !Admin.jobs.some(j => j.what === what)

            content: Component {
                ColumnLayout {
                    function syncErrors(): void {
                        newPwField.isError = root.newPassword.length > 0 && root.newPassword === root.currentPassword;
                        repeatPwField.isError = root.repeatPassword.length > 0 && root.repeatPassword !== root.newPassword;
                    }

                    spacing: Tokens.spacing.large

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        text: Tr.tr("Updates your sign-in, screen lock, and saved passwords (keyring).")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    StyledTextField {
                        id: curPwField

                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("Current password")
                        leadingIcon: "lock"
                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: {
                            root.currentPassword = text;
                            Qt.callLater(syncErrors);
                        }
                    }

                    StyledTextField {
                        id: newPwField

                        Layout.fillWidth: true
                        Layout.bottomMargin: isError ? Tokens.spacing.large : 0
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("New password")
                        leadingIcon: "key"
                        errorText: Tr.tr("Must differ from current password")
                        onTextChanged: {
                            root.newPassword = text;
                            Qt.callLater(syncErrors);
                        }
                    }

                    StyledTextField {
                        id: repeatPwField

                        Layout.fillWidth: true
                        Layout.bottomMargin: isError ? Tokens.spacing.small : 0
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("Repeat new password")
                        leadingIcon: "key"
                        errorText: Tr.tr("The two don't match yet")
                        onTextChanged: {
                            root.repeatPassword = text;
                            Qt.callLater(syncErrors);
                        }
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
                root.currentPassword = "";
                root.repeatPassword = "";
                if (!Admin.jobs.some(j => j.what === what))
                    root.newPassword = "";
            }
            onAccepted: {
                const cur = root.currentPassword;
                const pw = root.newPassword;
                root.currentPassword = "";
                root.newPassword = "";
                root.repeatPassword = "";
                root.passwordWarning = "";
                root.passwordFailed = false;
                root.passwordStatus = Tr.tr("Changing the password…");
                Admin.exec([`${Paths.libdir}/caelestia-set-password`], what, (ok, out, cancelled) => {
                    if (ok) {
                        const lines = out.split("\n").map(l => l.trim()).filter(l => l);
                        const warn = lines.find(l => l.startsWith("KEYRING_WARN:"));
                        root.passwordFailed = false;
                        root.passwordWarning = warn ? warn.replace(/^KEYRING_WARN:\s*/, "") : "";
                        root.passwordStatus = Tr.tr("Password changed");
                        passwordStatusReset.restart();
                    } else {
                        root.passwordStatus = "";
                        if (!cancelled) {
                            root.passwordFailed = true;
                            root.passwordWarning = out.trim() || Tr.tr("Couldn't change password.");
                        }
                    }
                }, JSON.stringify({
                    current: cur,
                    new: pw
                }));
            }

            Timer {
                id: passwordStatusReset

                interval: 5000
                onTriggered: root.passwordStatus = ""
            }
        }

        InfoRow {
            visible: root.passwordWarning !== ""
            icon: root.passwordFailed ? "error" : "warning"
            iconColour: root.passwordFailed ? Colours.palette.m3error : Colours.palette.m3primary
            label: root.passwordFailed ? Tr.tr("Password wasn't changed") : Tr.tr("Keyring note")
            subtext: root.passwordWarning
        }

        // ---- Your groups ----------------------------------------------------
        SectionHeader {
            visible: !!Users.me
            text: Tr.tr("Your access")
        }

        RowButton {
            visible: !!Users.me
            icon: "admin_panel_settings"
            text: Tr.tr("Hardware and system groups")
            subtext: Tr.tr("%1 active · Expand to manage device and service permissions").arg((Users.me?.groups ?? []).filter(g => g !== "wheel" && Users.groups.some(ug => ug.name === g)).length)
            trailingIcon: root.showGroups ? "expand_less" : "expand_more"
            onClicked: root.showGroups = !root.showGroups
        }

        GroupToggles {
            visible: !!Users.me && root.showGroups
            Layout.fillWidth: true
            hostFlickable: root.flickable
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

        ConnectedRect {
            readonly property string label: Tr.tr("Computer name")
            readonly property bool validHost: /^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(hostnameField.text)

            Layout.fillWidth: true
            implicitHeight: hostnameRow.implicitHeight + Tokens.padding.medium + Math.max(0, Tokens.padding.large - hostnameField.verticalPadding) * 2

            RowLayout {
                id: hostnameRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Computer name")
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: hostnameField.isError ? Tr.tr("Letters, numbers and dashes only") : hostSaveProc.running ? Tr.tr("Saving…") : Tr.tr("How it shows up on networks and Bluetooth; asks for your password")
                        color: hostnameField.isError ? Colours.palette.m3error : Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }

                StyledTextField {
                    id: hostnameField

                    Layout.preferredWidth: Tokens.sizes.nexus.textFieldWidth
                    Layout.maximumWidth: parent.width * 0.42
                    Layout.alignment: Qt.AlignVCenter
                    verticalPadding: Tokens.padding.small
                    floatingPlaceholder: false
                    text: root.hostname
                    isError: text.length > 0 && !/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(text)
                    onTextChanged: isError = text.length > 0 && !/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(text)
                    onAccepted: if (!saveHostBtn.disabled)
                        saveHostBtn.clicked(null)
                }

                TextButton {
                    id: saveHostBtn

                    Layout.alignment: Qt.AlignVCenter
                    text: Tr.trCtx("Save", "button")
                    type: TextButton.Tonal
                    disabled: !hostnameField.text || hostnameField.text === root.hostname || !/^[A-Za-z0-9][A-Za-z0-9-]{0,62}$/.test(hostnameField.text) || hostSaveProc.running
                    onClicked: {
                        hostSaveProc.pendingValue = hostnameField.text;
                        hostSaveProc.errText = "";
                        hostSaveProc.command = ["hostnamectl", "set-hostname", hostnameField.text];
                        hostSaveProc.running = true;
                    }
                }
            }
        }

        ConfirmDialog {
            id: removeFaceDialog

            hostFlickable: root.flickable
        }

        // Read back what took (a cancelled password prompt changes nothing)
        Timer {
            id: reloadInfo

            interval: 8000
            onTriggered: infoProc.running = true
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

// What starts when you log in or the computer boots, like Windows' Startup apps, by what starts
// it: Hyprland (the optional items of its startup), you (your services) and the system (its
// services). Only what's safe to switch off is listed; the essentials (the shell, sound,
// network, login...) aren't.
Item {
    id: root

    required property var window

    // Hyprland's optional startup items (hyprland/execs.lua runs them unless they're named in
    // ~/.config/caelestia/startup-disabled)
    readonly property var hyprItems: [
        {
            id: "clipboard",
            title: qsTr("Clipboard history"),
            description: qsTr("Remembers what you copy, for the clipboard history"),
            glyph: "content_paste"
        },
        {
            id: "nightlight",
            title: qsTr("Night light (Gammastep)"),
            description: qsTr("Warms the screen's colours in the evening"),
            glyph: "nightlight"
        },
        {
            id: "location",
            title: qsTr("Location for apps"),
            description: qsTr("Lets apps such as the night light find where you are"),
            glyph: "location_on"
        },
        {
            id: "bluetooth-media",
            title: qsTr("Bluetooth media buttons"),
            description: qsTr("Play / pause / skip on Bluetooth headphones control your music"),
            glyph: "bluetooth"
        },
        {
            id: "trash",
            title: qsTr("Empty old trash"),
            description: qsTr("Deletes files that have been in the trash for 30 days"),
            glyph: "delete"
        }
    ]
    property var hyprOff: []

    // Apps started at login: ~/.config/autostart, run by the shell once the boot lock opens
    // (modules/lock/Lock.qml), switched with Hidden=true like Settings > Apps > Startup apps
    readonly property string autostartDir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/autostart`
    property var apps: []

    function setApp(file: string, on: bool): void {
        actor.command = ["sed", "-i", "-e", "/^Hidden=/d", "-e", "/^X-GNOME-Autostart-enabled=false/d", ...(on ? [] : ["-e", "/^\\[Desktop Entry\\]/a Hidden=true"]), file];
        actor.running = true;
    }

    // Plain words for common system services
    readonly property var knownServices: ({
            "ananicy-cpp.service": [qsTr("Process priority tuning (Ananicy)"), qsTr("Keeps games and apps responsive by adjusting priorities")],
            "avahi-daemon.service": [qsTr("Local network discovery"), qsTr("Finds printers and other devices on your network")],
            "bluetooth.service": [qsTr("Bluetooth"), qsTr("Bluetooth devices such as headphones and controllers")],
            "bpftune.service": [qsTr("Automatic network tuning"), qsTr("Tunes system settings as you use the computer")],
            "cups.service": [qsTr("Printing"), qsTr("Lets you print")],
            "sshd.service": [qsTr("Remote login (SSH)"), qsTr("Lets other computers log in to this one")],
            "docker.service": [qsTr("Docker"), qsTr("Runs containers")],
            "libvirtd.service": [qsTr("Virtual machines"), qsTr("Runs virtual machines")],
            "tailscaled.service": [qsTr("Tailscale"), qsTr("Private network between your devices")],
            "cronie.service": [qsTr("Scheduled tasks (cron)"), qsTr("Runs tasks at set times")],
            "ollama.service": [qsTr("Ollama"), qsTr("Runs AI models on this computer")],
            "smb.service": [qsTr("Windows file sharing (Samba)"), qsTr("Shares folders with other computers")],
            "nmb.service": [qsTr("Windows network names (Samba)"), qsTr("Makes this computer visible to Windows computers")],
            "syncthing.service": [qsTr("Syncthing"), qsTr("Keeps folders in sync between devices")],
            "openrgb.service": [qsTr("RGB lighting (OpenRGB)"), qsTr("Controls your devices' lights")],
            "caelestia-openrgb.service": [qsTr("RGB lighting (OpenRGB)"), qsTr("Controls your devices' lights")],
            "ModemManager.service": [qsTr("Mobile broadband"), qsTr("For 4G/5G modems")],
            "gamemoded.service": [qsTr("GameMode"), qsTr("Speeds up the computer while you play")]
        })

    property var userServices: []
    property var systemServices: []
    property var descriptions: ({}) // unit -> {description, active}

    // Essentials: not offered (switching them off breaks sound, network, login, the shell...)
    readonly property var essentialUser: /^(pipewire|wireplumber|dbus|xdg-|gnome-keyring|gcr-|p11-kit|gvfs|at-spi|systemd-|obex|filter-chain|dirmngr|gpg-agent|ssh-agent|caelestia-(?!openrgb))/
    readonly property var essentialSystem: /^(systemd-|dbus|NetworkManager|polkit|getty|serial-getty|autovt|display-manager|sddm|gdm|greetd|lightdm|ly\.|caelestia|plymouth|lvm2|dm-event|udisks2|upower|accounts-daemon|rtkit|wpa_supplicant|iwd|reflector|refind|snapper|grub|nvidia|power-profiles|tlp|irqbalance|lm_sensors|alsa|kmod|modprobe|ufw|firewalld|apparmor|audit|chrony|ntpd|cachyos|scx|zram|swap|fstrim|btrfs|limine|mkinitcpio|pacman|archlinux|ldconfig|keyboard|console|bootloader|uuidd)/

    function reload(): void {
        appLister.running = true;
        hyprReader.reload();
        userLister.running = true;
        systemLister.running = true;
        userDescriber.running = true;
        systemDescriber.running = true;
    }

    function setHyprItem(id: string, on: bool): void {
        const list = on ? hyprOff.filter(x => x !== id) : [...hyprOff, id];
        hyprOff = list;
        hyprReader.setText(list.join("\n") + (list.length ? "\n" : ""));
    }

    function setService(system: bool, unit: string, on: bool): void {
        actor.command = system ? ["systemctl", on ? "enable" : "disable", unit] : ["systemctl", "--user", on ? "enable" : "disable", unit];
        actor.running = true;
    }

    // The readable parts of a service: its description, else its name without ".service"
    function serviceTitle(unit: string): string {
        if (knownServices[unit])
            return knownServices[unit][0];
        const d = descriptions[unit]?.description ?? "";
        return d && d !== unit ? d : unit.replace(/\.service$/, "");
    }

    function serviceSubtitle(unit: string): string {
        return [knownServices[unit]?.[1] ?? "", unit, descriptions[unit]?.active === "active" ? qsTr("running now") : ""].filter(x => x).join(" · ");
    }

    Component.onCompleted: reload()

    FileView {
        id: hyprReader

        path: `${Quickshell.env("HOME")}/.config/caelestia/startup-disabled`
        onLoaded: root.hyprOff = text().split("\n").map(l => l.trim()).filter(l => l)
    }

    Process {
        id: appLister

        command: ["python3", "-c", `
import configparser, glob, json, os, sys
out = []
for p in sorted(glob.glob(os.path.join(sys.argv[1], "*.desktop"))):
    c = configparser.RawConfigParser(strict=False, interpolation=None)
    c.optionxform = str
    try:
        c.read(p, encoding="utf-8")
        e = c["Desktop Entry"]
    except Exception:
        continue
    out.append({"file": p, "name": e.get("Name", os.path.basename(p)), "comment": e.get("Comment", ""), "icon": e.get("Icon", ""),
                "enabled": e.get("Hidden", "false").lower() != "true" and e.get("X-GNOME-Autostart-enabled", "true").lower() != "false"})
print(json.dumps(out))
`, root.autostartDir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apps = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: userLister

        command: ["systemctl", "--user", "list-unit-files", "--type=service", "--state=enabled,disabled", "--output=json", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.userServices = JSON.parse(text).filter(u => !u.unit_file.includes("@") && !root.essentialUser.test(u.unit_file));
                } catch (e) {}
            }
        }
    }

    Process {
        id: systemLister

        command: ["systemctl", "list-unit-files", "--type=service", "--state=enabled,disabled", "--output=json", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // (the ones enabled now, or switched off though they'd normally be on)
                    root.systemServices = JSON.parse(text).filter(u => !u.unit_file.includes("@") && !root.essentialSystem.test(u.unit_file) && (u.state === "enabled" || u.preset === "enabled"));
                } catch (e) {}
            }
        }
    }

    Process {
        id: userDescriber

        command: ["systemctl", "--user", "list-units", "--all", "--type=service", "--output=json", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: root.addDescriptions(text)
        }
    }

    Process {
        id: systemDescriber

        command: ["systemctl", "list-units", "--all", "--type=service", "--output=json", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: root.addDescriptions(text)
        }
    }

    function addDescriptions(text: string): void {
        try {
            const map = Object.assign({}, descriptions);
            for (const u of JSON.parse(text))
                map[u.unit] = {
                    description: u.description,
                    active: u.active
                };
            descriptions = map;
        } catch (e) {}
    }

    Process {
        id: actor

        onExited: root.reload()
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: flick
        }

        ColumnLayout {
            id: content

            width: flick.width - 12
            spacing: Tokens.spacing.small

            Title {
                icon: "apps"
                text: qsTr("Apps")
                hint: qsTr("Apps that start when you log in")
                count: root.apps.filter(a => a.enabled).length
            }

            Repeater {
                model: root.apps

                Entry {
                    required property var modelData

                    iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                    glyph: "apps"
                    title: modelData.name
                    subtitle: modelData.comment
                    on: modelData.enabled
                    onToggled: root.setApp(modelData.file, !on)
                }
            }

            Empty {
                visible: root.apps.length === 0
                text: qsTr("No apps start when you log in")
            }

            Title {
                Layout.topMargin: Tokens.spacing.large
                icon: "desktop_windows"
                text: qsTr("Hyprland")
                hint: qsTr("Started with your desktop · takes effect next login")
                count: root.hyprItems.filter(i => !root.hyprOff.includes(i.id)).length
            }

            Repeater {
                model: root.hyprItems

                Entry {
                    required property var modelData

                    glyph: modelData.glyph
                    title: modelData.title
                    subtitle: modelData.description
                    on: !root.hyprOff.includes(modelData.id)
                    onToggled: root.setHyprItem(modelData.id, !on)
                }
            }

            Title {
                Layout.topMargin: Tokens.spacing.large
                icon: "person"
                text: qsTr("User")
                hint: qsTr("Your background services · start when you log in")
                count: root.userServices.filter(s => s.state === "enabled").length
            }

            Repeater {
                model: root.userServices

                Entry {
                    required property var modelData

                    glyph: "person"
                    title: root.serviceTitle(modelData.unit_file)
                    subtitle: root.serviceSubtitle(modelData.unit_file)
                    on: modelData.state === "enabled"
                    onToggled: root.setService(false, modelData.unit_file, !on)
                }
            }

            Empty {
                visible: root.userServices.length === 0
                text: qsTr("None of your own services start with your session")
            }

            Title {
                Layout.topMargin: Tokens.spacing.large
                icon: "dns"
                text: qsTr("System")
                hint: qsTr("Start when the computer boots · asks for your password")
                count: root.systemServices.filter(s => s.state === "enabled").length
            }

            Repeater {
                model: root.systemServices

                Entry {
                    required property var modelData

                    glyph: "dns"
                    title: root.serviceTitle(modelData.unit_file)
                    subtitle: root.serviceSubtitle(modelData.unit_file)
                    on: modelData.state === "enabled"
                    onToggled: root.setService(true, modelData.unit_file, !on)
                }
            }
        }
    }

    component Title: RowLayout {
        property alias text: titleText.text
        property string icon
        property int count
        property string hint

        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.medium
        Layout.rightMargin: Tokens.padding.medium
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: parent.icon
            color: Colours.palette.m3primary
        }

        StyledText {
            id: titleText

            font: Tokens.font.title.small
            color: Colours.palette.m3primary
        }

        StyledText {
            text: qsTr("%1 on").arg(parent.count)
            font: Tokens.font.label.medium
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: parent.hint
            font: Tokens.font.label.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    component Empty: StyledText {
        Layout.leftMargin: Tokens.padding.large
        font: Tokens.font.body.small
        color: Colours.palette.m3onSurfaceVariant
    }

    component Entry: StyledRect {
        id: entry

        property string iconSource
        property string glyph
        property string title
        property string subtitle
        property bool on

        signal toggled

        Layout.fillWidth: true
        implicitHeight: 58
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer

        StyledRect {
            id: iconBox

            anchors.verticalCenter: parent.verticalCenter
            x: Tokens.padding.medium
            width: 34
            height: 34
            radius: Tokens.rounding.small
            color: entry.on ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest

            MaterialIcon {
                anchors.centerIn: parent
                visible: entry.iconSource === ""
                text: entry.glyph
                color: entry.on ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
            }

            ThemedIcon {
                anchors.fill: parent
                anchors.margins: 2
                visible: entry.iconSource !== ""
                asynchronous: true
                source: entry.iconSource
                opacity: entry.on ? 1 : 0.5
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: iconBox.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: toggle.left
            anchors.rightMargin: Tokens.spacing.medium

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: entry.title
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurface
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                text: entry.subtitle
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        StyledSwitch {
            id: toggle

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.medium
            checked: entry.on
            onToggled: entry.toggled()
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

// Privacy & security: the firewall (ufw), screen lock, recent files (GTK's
// history), the shell's notification history and clipboard history.
PageBase {
    id: root

    property string firewall // "active", "inactive", "" (no ufw)
    property bool firewallPending
    property bool hasCliphist
    property bool checked

    function refresh(): void {
        fwProc.running = true;
    }

    title: Tr.tr("Privacy & security")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: fwProc

            running: true
            command: ["sh", "-c", "command -v ufw >/dev/null || { echo none; exit; }; systemctl is-active ufw; command -v cliphist >/dev/null && echo cliphist"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n").map(l => l.trim());
                    root.firewall = lines[0] === "none" ? "" : lines[0];
                    root.hasCliphist = lines.includes("cliphist");
                    root.firewallPending = false;
                    root.checked = true;
                }
            }
        }

        Timer {
            id: recheck

            property int left

            interval: 3000
            repeat: true
            onTriggered: {
                root.refresh();
                if (--left <= 0)
                    stop();
            }
        }

        SectionHeader {
            first: true
            text: Tr.tr("Security")
        }

        RequirementRow {
            visible: root.checked && root.firewall === ""
            first: true
            icon: "shield"
            text: Tr.tr("No firewall installed")
            subtext: Tr.tr("ufw blocks incoming connections the PC didn't ask for. Installing it asks for your password.")
            actionText: Tr.tr("Install")
            onAction: {
                Term.run("sudo pacman -S --needed ufw && sudo systemctl enable --now ufw && sudo ufw enable");
                recheck.left = 20;
                recheck.restart();
            }
        }

        ToggleRow {
            visible: root.firewall !== ""
            first: true
            text: Tr.tr("Firewall")
            subtext: root.firewallPending ? Tr.tr("Finish in the terminal (it asks for your password)") : root.firewall === "active" ? Tr.tr("Blocks incoming connections the PC didn't ask for") : Tr.tr("Off: anything on the network can reach open ports")
            checked: root.firewall === "active"
            onToggled: {
                root.firewallPending = true;
                Term.run(checked ? "sudo systemctl enable --now ufw && sudo ufw enable" : "sudo ufw disable && sudo systemctl disable --now ufw");
                recheck.left = 10;
                recheck.restart();
            }
        }

        NavRow {
            last: true
            icon: "lock"
            text: Tr.tr("Screen lock")
            subtext: Tr.tr("When the screen locks by itself, on Power & sleep")
            onClicked: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "power"),
                path: [],
                text: Tr.tr("Lock the screen after")
            })
        }

        SectionHeader {
            text: Tr.tr("History")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Remember recently used files")
            subtext: Tr.tr("Apps list them under Recent")
            checked: AppLook.get("org.gnome.desktop.privacy", "remember-recent-files", true)
            onToggled: AppLook.set("org.gnome.desktop.privacy", "remember-recent-files", checked)
        }

        RowButton {
            icon: "history"
            text: Tr.tr("Clear recent files")
            onClicked: Quickshell.execDetached(["sh", "-c", `printf '<?xml version="1.0" encoding="UTF-8"?>\\n<xbel version="1.0"/>\\n' > "\${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel"`])
        }

        RowButton {
            icon: "notifications_off"
            text: Tr.tr("Clear notification history")
            subtext: Tr.trN("%n notification", "%n notifications", Notifs.list.length)
            disabled: Notifs.list.length === 0
            onClicked: {
                for (const n of Notifs.list.slice())
                    n.close();
            }
        }

        RowButton {
            visible: root.hasCliphist
            last: true
            icon: "content_paste_off"
            text: Tr.tr("Clear clipboard history")
            onClicked: Quickshell.execDetached(["cliphist", "wipe"])
        }
    }
}

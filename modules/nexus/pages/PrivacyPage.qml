pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
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
    property string secureBootState: "unknown"
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
            command: ["sh", "-c", "if command -v ufw >/dev/null; then if [ \"$(systemctl is-active ufw)\" = active ] && grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null; then echo active; else echo inactive; fi; else echo none; fi; command -v cliphist >/dev/null && echo cliphist; sb=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -n1); if [ -n \"$sb\" ] && [ \"$(od -An -t u1 -j 4 -N 1 \"$sb\" 2>/dev/null | tr -d ' ')\" = \"1\" ]; then echo sb:enabled; elif [ -d /sys/firmware/efi ]; then echo sb:disabled; else echo sb:bios; fi"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n").map(l => l.trim());
                    root.firewall = lines[0] === "none" ? "" : lines[0];
                    root.hasCliphist = lines.includes("cliphist");
                    root.secureBootState = lines.includes("sb:enabled") ? "enabled" : lines.includes("sb:disabled") ? "disabled" : lines.includes("sb:bios") ? "bios" : "unknown";
                    root.firewallPending = false;
                    root.checked = true;
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Security")
        }

        RequirementRow {
            visible: root.checked && root.firewall === ""
            icon: "shield"
            text: Tr.tr("No firewall installed")
            subtext: Tr.tr("ufw blocks incoming connections the PC didn't ask for. Installing it asks for your password.")
            actionText: root.firewallPending ? "" : Tr.tr("Install")
            onAction: {
                const what = Tr.tr("Install and turn on the firewall");
                root.firewallPending = true;
                Admin.run("install", ["ufw"], what, ok => {
                    if (ok)
                        Admin.run("firewall", ["on"], what, () => root.refresh());
                    else
                        root.refresh();
                });
            }
        }

        ToggleRow {
            visible: root.firewall !== ""
            text: Tr.tr("Firewall")
            subtext: root.firewallPending ? Tr.tr("Applying…") : root.firewall === "active" ? Tr.tr("Blocks incoming connections the PC didn't ask for") : Tr.tr("Off: anything on the network can reach open ports")
            checked: root.firewall === "active"
            onToggled: {
                root.firewallPending = true;
                Admin.run("firewall", [checked ? "on" : "off"], checked ? Tr.tr("Turn the firewall on") : Tr.tr("Turn the firewall off"), () => root.refresh());
            }
        }

        NavRow {
            icon: "lock"
            text: Tr.tr("Screen lock")
            subtext: Tr.tr("When the screen locks by itself, on Power & sleep")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("power"),
                path: [],
                text: Tr.tr("Lock the screen after")
            })
        }

        NavRow {
            icon: "verified_user"
            text: Tr.tr("Secure Boot")
            subtext: root.secureBootState === "enabled" ? Tr.tr("Enabled · Manage keys and boot entries in Recovery & boot") : root.secureBootState === "disabled" ? Tr.tr("Disabled · Manage keys and boot entries in Recovery & boot") : Tr.tr("Not available (legacy BIOS)")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("recovery"),
                tab: "",
                path: []
            })
        }

        NavRow {
            icon: "system_update_alt"
            text: Tr.tr("System updates")
            subtext: Tr.tr("Keep system packages and security patches up to date")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("updates"),
                tab: "",
                path: []
            })
        }

        SectionHeader {
            text: Tr.tr("History")
        }

        ToggleRow {
            text: Tr.tr("Remember recently used files")
            subtext: Tr.tr("Apps list them under Recent")
            checked: AppLook.get("org.gnome.desktop.privacy", "remember-recent-files", true)
            onToggled: AppLook.set("org.gnome.desktop.privacy", "remember-recent-files", checked)
        }

        RowButton {
            icon: "history"
            text: Tr.tr("Clear recent files")
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear recent files?"),
                body: Tr.tr("Removes your GTK/app recently used files list. The files themselves are not deleted."),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    Quickshell.execDetached(["sh", "-c", `printf '<?xml version="1.0" encoding="UTF-8"?>\\n<xbel version="1.0"/>\\n' > "\${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel"`]);
                    Toaster.toast(Tr.tr("Recent files cleared"), "", "history");
                }
            })
        }

        RowButton {
            icon: "notifications_off"
            text: Tr.tr("Clear notification history")
            subtext: Tr.trN("%n notification", "%n notifications", Notifs.list.length)
            disabled: Notifs.list.length === 0
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear notification history?"),
                body: Tr.tr("Dismisses all %1 stored notifications.").arg(Notifs.list.length),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    for (const n of Notifs.list.slice())
                        n.close();
                    Toaster.toast(Tr.tr("Notification history cleared"), "", "notifications_off");
                }
            })
        }

        RowButton {
            visible: root.hasCliphist
            icon: "content_paste_off"
            text: Tr.tr("Clear clipboard history")
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear clipboard history?"),
                body: Tr.tr("Removes all entries saved in your clipboard history."),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    Quickshell.execDetached(["cliphist", "wipe"]);
                    Toaster.toast(Tr.tr("Clipboard history cleared"), "", "content_paste_off");
                }
            })
        }

        RowButton {
            icon: "image"
            text: Tr.tr("Clear thumbnail cache")
            subtext: Tr.tr("Cached previews of images, videos and documents in ~/.cache/thumbnails")
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear thumbnail cache?"),
                body: Tr.tr("Delete all cached image and video preview thumbnails? Apps will recreate them when needed."),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    Quickshell.execDetached(["sh", "-c", "rm -rf \"${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails\"/*"]);
                    Toaster.toast(Tr.tr("Thumbnail cache cleared"), "", "image");
                }
            })
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }
    }
}

pragma Singleton

import QtQuick
import Caelestia.I18n

// The pages of the settings app, in the order of PageCompRegistry (one entry
// per page component there). `id` is for links between pages; `keywords`
// help the search.
QtObject {
    id: root

    readonly property list<var> pages: [
        {
            id: "wallpaper",
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, colours, dark theme"),
            keywords: "background theme colour scheme light dark mode transparency desktop icons live wallpaper engine animated video workshop playlist & style",
            category: "personalise"
        },
        {
            id: "themes",
            label: Tr.tr("Fonts & themes"),
            icon: "text_fields",
            description: Tr.tr("Fonts, icon theme, app style"),
            keywords: "typeface font size text smoothing hinting antialiasing icons theme gtk qt look style papirus fonts app appearance",
            category: "personalise"
        },
        {
            id: "windows",
            label: Tr.tr("Windows"),
            icon: "select_window",
            description: Tr.tr("Look, title bars, snapping"),
            keywords: "border rounding opacity transparency effects hyprflow floating windows like title bar snap minimize maximize corners desktop mode",
            category: "personalise"
        },
        {
            id: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Taskbar, dashboard, launcher, sidebar"),
            keywords: "bar taskbar dashboard launcher sidebar lock screen osd power menu lyrics media player polling volume step panels shell services",
            category: "personalise"
        },
        {
            id: "display",
            label: Tr.tr("Display"),
            icon: "monitor",
            description: Tr.tr("Resolution, refresh rate, scale, brightness"),
            keywords: "screen monitor resolution hz refresh scale brightness night light hdr vrr arrangement mirror icc display",
            category: "system"
        },
        {
            id: "audio",
            label: Tr.tr("Sound"),
            icon: "volume_up",
            description: Tr.tr("Devices, app volumes, sounds"),
            keywords: "sound volume speakers microphone headphones output input notification audio",
            category: "system"
        },
        {
            id: "notifications",
            label: Tr.tr("Notifications"),
            icon: "notifications",
            description: Tr.tr("Popups, per-app settings"),
            keywords: "notifications do not disturb dnd popups toasts apps mute",
            category: "system"
        },
        {
            id: "power",
            label: Tr.tr("Power & sleep"),
            icon: "bedtime",
            description: Tr.tr("Screen lock, sleep, power button"),
            keywords: "power sleep suspend idle lock screen off timeout button mode &",
            category: "system"
        },
        {
            id: "storage",
            label: Tr.tr("Storage"),
            icon: "hard_drive",
            description: Tr.tr("Drives, partitions, clean up, snapshots"),
            keywords: "disk space drives storage cleanup trash cache partition partitions format resize shrink grow gparted manager table gpt mbr drive health smart ssd nvme hdd temperature wear self test mount unmount fstab startup encrypt luks unlock usb eject label filesystem ext4 btrfs ntfs exfat fat32 snapshot snapper restore backup backups",
            category: "system"
        },
        {
            id: "devices",
            label: Tr.tr("Devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, keyboard, mouse"),
            keywords: "bluetooth pair headphones mouse keyboard battery layout language pointer sensitivity scroll touchpad cursor connected devices &",
            category: "devices",
            noFill: true
        },
        {
            id: "network",
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            keywords: "internet wifi wireless ethernet vpn wireguard ip dns network",
            category: "devices"
        },
        {
            id: "apps",
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Updates, default apps, startup apps"),
            keywords: "default applications browser editor file manager open with favourites autostart startup login update upgrade packages pacman aur flatpak apps updates",
            category: "apps"
        },
        {
            id: "workspaces",
            label: Tr.tr("Workspaces & shortcuts"),
            icon: "view_quilt",
            description: Tr.tr("Focus, workspaces, shortcuts, screenshots"),
            keywords: "focus follows mouse workspaces window rules float scrolling layout columns keybinds hotkeys shortcuts binds keys screenshot print capture snip clipboard swappy satty editor recording video record & keyboard screenshots",
            category: "apps"
        },
        {
            id: "account",
            label: Tr.tr("Account"),
            icon: "account_circle",
            description: Tr.tr("You and other people, groups"),
            keywords: "user profile avatar picture password name hostname computer account",
            category: "you"
        },
        {
            id: "time",
            label: Tr.tr("Time & language"),
            icon: "schedule",
            description: Tr.tr("Time zone, clock, language, units"),
            keywords: "date time clock timezone ntp language locale weather units celsius fahrenheit & region",
            category: "you"
        },
        {
            id: "accessibility",
            label: Tr.tr("Accessibility"),
            icon: "accessibility_new",
            description: Tr.tr("Text size, zoom, motion, colour filters"),
            keywords: "a11y zoom magnifier text size larger animations reduce motion greyscale invert colour blind contrast accessibility",
            category: "you"
        },
        {
            id: "privacy",
            label: Tr.tr("Privacy & security"),
            icon: "shield",
            description: Tr.tr("Firewall, history"),
            keywords: "privacy security firewall ufw recent files history clipboard &",
            category: "you"
        },
        {
            id: "gaming",
            label: Tr.tr("Gaming"),
            icon: "sports_esports",
            description: Tr.tr("Game mode, tearing"),
            keywords: "games gaming game mode tearing fullscreen performance",
            category: "you"
        },
        {
            id: "system",
            label: Tr.tr("System"),
            icon: "settings_applications",
            description: Tr.tr("Boot menu, kernels, services, logs"),
            keywords: "refind boot menu bootloader grub theme kernel kernels linux-cachyos lts secure boot sbctl uefi bios firmware fwupd windows dual boot timeout systemd service services daemon unit start stop restart enable disable mask boot startup timer timers scheduled task cron failed journal journalctl log logs error errors warnings previous crash crashes coredump bug report dmesg hyprpm plugins hyprland system",
            category: "advanced"
        },
        {
            id: "about",
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            keywords: "system information version hardware cpu gpu memory about",
            category: "advanced"
        }
    ]
    // Former page ids (pages merged on 2026-11-08) -> the page that holds them now
    readonly property var aliases: ({
            fonts: "themes",
            appearance: "themes",
            desktopmode: "windows",
            services: "panels",
            backups: "storage",
            disks: "storage",
            bluetooth: "devices",
            input: "devices",
            startup: "apps",
            updates: "apps",
            getapps: "apps",
            installed: "apps",
            defaultapps: "apps",
            multitasking: "workspaces",
            shortcuts: "workspaces",
            screenshots: "workspaces",
            datetime: "time",
            language: "time",
            systemd: "system",
            logs: "system",
            plugins: "system",
            boot: "system",
            kernels: "system"
        })

    // A tab to show when a page opens at a former id (createAt "updates" ->
    // Apps, Updates tab): taken by that page's PartTabs (see TabPart.key)
    property string pendingTab

    // A page's index by its id (or a former id)
    function find(id: string): int {
        return pages.findIndex(p => p.id === (aliases[id] ?? id));
    }
}

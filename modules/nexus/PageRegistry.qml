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
            keywords: "background theme colour scheme light dark mode transparency desktop icons live wallpaper engine animated video workshop playlist",
            category: "appearance"
        },
        {
            id: "fonts",
            label: Tr.tr("Fonts"),
            icon: "text_fields",
            description: Tr.tr("Shell and app fonts, text size"),
            keywords: "typeface font size text smoothing hinting antialiasing",
            category: "appearance"
        },
        {
            id: "appearance",
            label: Tr.tr("App appearance"),
            icon: "style",
            description: Tr.tr("Icon theme, Qt style"),
            keywords: "icons theme gtk qt look style papirus",
            category: "appearance"
        },
        {
            id: "windows",
            label: Tr.tr("Windows"),
            icon: "select_window",
            description: Tr.tr("Gaps, corners, blur, shadows, animations"),
            keywords: "border rounding opacity transparency effects",
            category: "appearance"
        },
        {
            id: "desktopmode",
            label: Tr.tr("Desktop mode"),
            icon: "web_asset",
            description: Tr.tr("Title bars, snapping, hot corners"),
            keywords: "hyprflow floating windows like windows title bar snap minimize maximize corners",
            category: "appearance"
        },
        {
            id: "display",
            label: Tr.tr("Display"),
            icon: "monitor",
            description: Tr.tr("Resolution, refresh rate, scale, brightness"),
            keywords: "screen monitor resolution hz refresh scale brightness night light hdr vrr arrangement mirror icc",
            category: "connectivity"
        },
        {
            id: "network",
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            keywords: "internet wifi wireless ethernet vpn wireguard ip dns",
            category: "connectivity"
        },
        {
            id: "bluetooth",
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, device batteries"),
            keywords: "bluetooth pair headphones mouse keyboard battery",
            category: "connectivity",
            noFill: true
        },
        {
            id: "audio",
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("Sound devices, app volumes, sounds"),
            keywords: "sound volume speakers microphone headphones output input notification sound",
            category: "connectivity"
        },
        {
            id: "printers",
            label: Tr.tr("Printers"),
            icon: "print",
            description: Tr.tr("Printers and printing"),
            keywords: "print printer cups scanner",
            category: "connectivity"
        },
        {
            id: "account",
            label: Tr.tr("Account"),
            icon: "account_circle",
            description: Tr.tr("Picture, name, password"),
            keywords: "user profile avatar picture password name hostname computer name",
            category: "system"
        },
        {
            id: "power",
            label: Tr.tr("Power & sleep"),
            icon: "bedtime",
            description: Tr.tr("Screen lock, sleep, power button"),
            keywords: "power sleep suspend idle lock screen off timeout power button power mode",
            category: "system"
        },
        {
            id: "input",
            label: Tr.tr("Keyboard & mouse"),
            icon: "keyboard",
            description: Tr.tr("Layouts, pointer speed, cursor"),
            keywords: "keyboard layout language mouse pointer sensitivity scroll touchpad cursor",
            category: "system"
        },
        {
            id: "multitasking",
            label: Tr.tr("Workspaces & focus"),
            icon: "view_carousel",
            description: Tr.tr("Focus, workspaces, app rules"),
            keywords: "focus follows mouse workspaces window rules float scrolling layout columns",
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
            id: "datetime",
            label: Tr.tr("Date & time"),
            icon: "schedule",
            description: Tr.tr("Time zone, automatic time"),
            keywords: "date time clock timezone ntp",
            category: "system"
        },
        {
            id: "storage",
            label: Tr.tr("Storage"),
            icon: "hard_drive",
            description: Tr.tr("Drives, partitions, clean up"),
            keywords: "disk space drives storage cleanup trash cache partition partitions format resize shrink grow gparted partition manager table gpt mbr drive health smart ssd nvme hdd temperature wear self test mount unmount fstab startup encrypt luks unlock usb eject label filesystem ext4 btrfs ntfs exfat fat32",
            category: "system"
        },
        {
            id: "backups",
            label: Tr.tr("Backups"),
            icon: "history",
            description: Tr.tr("System snapshots"),
            keywords: "snapshot snapper btrfs restore backup",
            category: "system"
        },
        {
            id: "screenshots",
            label: Tr.tr("Screenshots & recording"),
            icon: "screenshot_monitor",
            description: Tr.tr("Clipboard, saving, editor, recording quality"),
            keywords: "screenshot print capture snip clipboard swappy satty editor recording video record",
            category: "system"
        },
        {
            id: "startup",
            label: Tr.tr("Startup apps"),
            icon: "rocket_launch",
            description: Tr.tr("Apps that start at login"),
            keywords: "autostart startup login",
            category: "system"
        },
        {
            id: "shortcuts",
            label: Tr.tr("Keyboard shortcuts"),
            icon: "keyboard_command_key",
            description: Tr.tr("View and change shortcuts"),
            keywords: "keybinds hotkeys shortcuts binds keys",
            category: "system"
        },
        {
            id: "updates",
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            keywords: "update upgrade packages pacman aur flatpak",
            category: "system"
        },
        {
            id: "systemd",
            label: Tr.tr("System services"),
            icon: "settings_applications",
            description: Tr.tr("Start, stop, start at boot, scheduled tasks"),
            keywords: "systemd service services daemon unit start stop restart enable disable mask boot startup timer timers scheduled task cron failed",
            category: "system"
        },
        {
            id: "logs",
            label: Tr.tr("Logs"),
            icon: "receipt_long",
            description: Tr.tr("System messages, errors, crash reports"),
            keywords: "journal journalctl log logs error errors warnings boot previous crash crashes coredump bug report dmesg",
            category: "system"
        },
        {
            id: "plugins",
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Hyprland plugins"),
            keywords: "hyprpm plugins hyprland",
            category: "system"
        },
        {
            id: "accessibility",
            label: Tr.tr("Accessibility"),
            icon: "accessibility_new",
            description: Tr.tr("Text size, zoom, motion, colour filters"),
            keywords: "a11y zoom magnifier text size larger animations reduce motion greyscale invert colour blind contrast",
            category: "access"
        },
        {
            id: "privacy",
            label: Tr.tr("Privacy & security"),
            icon: "shield",
            description: Tr.tr("Firewall, history"),
            keywords: "privacy security firewall ufw recent files history clipboard",
            category: "access"
        },
        {
            id: "gaming",
            label: Tr.tr("Gaming"),
            icon: "sports_esports",
            description: Tr.tr("Game mode, tearing"),
            keywords: "games gaming game mode tearing fullscreen performance",
            category: "access"
        },
        {
            id: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            keywords: "bar taskbar dashboard launcher sidebar lock screen osd power menu",
            category: "shell"
        },
        {
            id: "apps",
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            keywords: "default applications browser editor file manager open with favourites",
            category: "shell"
        },
        {
            id: "services",
            label: Tr.tr("Shell services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics, media"),
            keywords: "lyrics media player polling volume step",
            category: "shell"
        },
        {
            id: "language",
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, units"),
            keywords: "language locale weather units celsius fahrenheit",
            category: "shell"
        },
        {
            id: "about",
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            keywords: "system information version hardware cpu gpu memory",
            category: "about"
        }
    ]
}

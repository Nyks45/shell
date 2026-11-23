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
            id: "display",
            label: Tr.tr("Display"),
            icon: "monitor",
            description: Tr.tr("Resolution, refresh rate, scale, brightness"),
            keywords: "screen monitor resolution hz refresh scale brightness night light hdr vrr arrangement mirror icc display"
        },
        {
            id: "audio",
            label: Tr.tr("Sound"),
            icon: "volume_up",
            description: Tr.tr("Devices, app volumes, sounds, volume step"),
            keywords: "sound volume speakers microphone headphones output input notification audio step max boost"
        },
        {
            id: "notifications",
            label: Tr.tr("Notifications"),
            icon: "notifications",
            description: Tr.tr("Popups, per-app settings"),
            keywords: "notifications do not disturb dnd popups toasts apps mute"
        },
        {
            id: "power",
            label: Tr.tr("Power & sleep"),
            icon: "bedtime",
            description: Tr.tr("Screen lock, sleep, power button"),
            keywords: "power sleep suspend idle lock screen off timeout button mode &"
        },
        {
            id: "storage",
            label: Tr.tr("Storage"),
            icon: "hard_drive",
            description: Tr.tr("Drives, partitions, clean up, snapshots"),
            keywords: "disk space drives storage cleanup trash cache partition partitions format resize shrink grow gparted manager table gpt mbr drive health smart ssd nvme hdd temperature wear self test mount unmount fstab startup encrypt luks unlock usb eject label filesystem ext4 btrfs ntfs exfat fat32 snapshot snapper restore backup backups"
        },
        {
            id: "recovery",
            label: Tr.tr("Recovery & boot"),
            icon: "settings_backup_restore",
            description: Tr.tr("Boot menu, default system, Secure Boot, UEFI"),
            keywords: "refind boot menu bootloader grub theme secure boot sbctl uefi bios firmware fwupd windows dual boot timeout recovery restore &"
        },
        {
            id: "about",
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            keywords: "system information version hardware cpu gpu memory about"
        },
        {
            id: "devices",
            label: Tr.tr("Devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, keyboard, mouse, lighting, fans"),
            keywords: "rgb lighting openrgb mystic light leds colour effect keyboard lighting fans fan curve speed rpm cooling temperature cpu fan pump dpi polling report rate logitech solaar bluetooth pair headphones mouse keyboard battery layout language pointer sensitivity scroll touchpad cursor connected devices &"
        },
        {
            id: "network",
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            keywords: "internet wifi wireless ethernet vpn wireguard ip dns network"
        },
        {
            id: "wallpaper",
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Background, colours, effects, desktop, lock screen"),
            keywords: "background wallpaper theme colour scheme light dark mode transparency blur frosted glass desktop icons widgets visualiser lock screen fingerprint face live animated video workshop playlist & style"
        },
        {
            id: "themes",
            label: Tr.tr("Fonts & themes"),
            icon: "text_fields",
            description: Tr.tr("Fonts, icon theme, app style"),
            keywords: "typeface font size text smoothing hinting antialiasing icons theme gtk qt look style papirus fonts app appearance &"
        },
        {
            id: "windows",
            label: Tr.tr("Windows"),
            icon: "select_window",
            description: Tr.tr("Look, desktop mode, title bars, app rules"),
            keywords: "border rounding opacity transparency effects hyprflow floating windows like title bar font blur buttons snap minimize maximize corners desktop mode app rules window rules"
        },
        {
            id: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Taskbar, dashboard, launcher, media, shell style"),
            keywords: "bar taskbar dashboard launcher osd tray lyrics media player default player shell style compact pill full classic panels"
        },
        {
            id: "workspaces",
            label: Tr.tr("Workspaces & shortcuts"),
            icon: "view_quilt",
            description: Tr.tr("Focus, workspaces, shortcuts, screenshots"),
            keywords: "focus follows mouse workspaces float scrolling layout columns keybinds hotkeys shortcuts binds keys screenshot print capture snip clipboard swappy satty editor recording video record & keyboard screenshots"
        },
        {
            id: "apps",
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Installed apps, get apps, default apps, startup"),
            keywords: "default applications browser editor file manager open with favourites autostart startup login packages pacman aur flatpak apps installed"
        },
        {
            id: "gaming",
            label: Tr.tr("Gaming"),
            icon: "sports_esports",
            description: Tr.tr("Overview, library, graphics, Proton, overlay"),
            keywords: "library my games per game faugus add game launch options games gaming game mode tearing fullscreen performance nvidia nvidia-settings graphics card gpu power limit persistence driver dlss reflex smooth motion frame generation hdr ntsync shader cache proton proton-ge protonplus wine lutris heroic steam compatibility tool mangohud goverlay overlay fps counter frame limit"
        },
        {
            id: "account",
            label: Tr.tr("Account"),
            icon: "account_circle",
            description: Tr.tr("You and other people, groups"),
            keywords: "user profile avatar picture password name hostname computer account"
        },
        {
            id: "time",
            label: Tr.tr("Time & language"),
            icon: "schedule",
            description: Tr.tr("Time zone, clock, language, units"),
            keywords: "date time clock timezone ntp language locale weather units celsius fahrenheit & region"
        },
        {
            id: "accessibility",
            label: Tr.tr("Accessibility"),
            icon: "accessibility_new",
            description: Tr.tr("Text size, zoom, motion, colour filters"),
            keywords: "a11y zoom magnifier text size larger animations reduce motion greyscale invert colour blind contrast accessibility"
        },
        {
            id: "privacy",
            label: Tr.tr("Privacy & security"),
            icon: "shield",
            description: Tr.tr("Firewall, history"),
            keywords: "privacy security firewall ufw recent files history clipboard &"
        },
        {
            id: "updates",
            label: Tr.tr("Updates"),
            icon: "system_update",
            description: Tr.tr("System, AUR and Flatpak updates, news"),
            keywords: "update upgrade updates packages pacman aur flatpak pacnew news restart automatic checks"
        },
        {
            id: "advanced",
            label: Tr.tr("Advanced"),
            icon: "settings_applications",
            description: Tr.tr("Services, logs, kernels, performance, plugins"),
            keywords: "systemd service services daemon unit start stop restart enable disable mask timer timers scheduled task cron failed journal journalctl log logs error errors warnings crash coredump dmesg kernel kernels linux-cachyos lts headers scheduler sched-ext scx lavd bpfland ananicy polling refresh rate gpu monitoring hyprpm plugins hyprland system"
        }
    ]
    // Former and tab-specific page ids -> the top-level page that holds them now
    readonly property var aliases: ({
            "style": "wallpaper",
            background: "wallpaper",
            colours: "wallpaper",
            effects: "wallpaper",
            desktop: "wallpaper",
            lockscreen: "wallpaper",
            fonts: "themes",
            appearance: "themes",
            desktopmode: "windows",
            titlebars: "windows",
            apprules: "windows",
            services: "advanced",
            backups: "storage",
            cleanup: "storage",
            disks: "storage",
            bluetooth: "devices",
            input: "devices",
            lighting: "devices",
            fans: "devices",
            startup: "apps",
            getapps: "apps",
            installed: "apps",
            defaultapps: "apps",
            multitasking: "workspaces",
            shortcuts: "workspaces",
            screenshots: "workspaces",
            datetime: "time",
            language: "time",
            boot: "recovery",
            system: "advanced",
            systemd: "advanced",
            logs: "advanced",
            kernels: "advanced",
            plugins: "advanced",
            scheduler: "advanced",
            performance: "advanced",
            gamemode: "gaming",
            library: "gaming",
            gpu: "gaming",
            games: "gaming",
            proton: "gaming",
            overlay: "gaming"
        })

    // A tab to show when a page opens at a former id (createAt "updates" ->
    // Apps, Updates tab): taken by that page's PartTabs (see TabPart.key).
    // Kept for the opening (a window can build its page more than once):
    // only within a few seconds of pendingTabAt.
    property string pendingTab
    property real pendingTabAt
    // The Settings (NexusState) that asked: only its pages switch tabs (the
    // dashboard's and the window's can show the same page at once)
    property QtObject pendingTabFor: null

    // Where a link to a page id goes: its page, and the tab it's now on (a former page id)
    function target(id: string): var {
        return {
            page: find(id),
            tab: aliases[id] ? id : ""
        };
    }

    // A page's index by its id (or a former id)
    function find(id: string): int {
        return pages.findIndex(p => p.id === (aliases[id] ?? id));
    }
}

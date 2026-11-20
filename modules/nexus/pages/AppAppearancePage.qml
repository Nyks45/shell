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
import qs.components.effects
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// How apps look: icon theme (GTK, Qt, the shell's taskbar), KDE & Qt style, and
// cursor style & size. App colours follow the colour scheme (Wallpaper & style > Colours).
PageBase {
    id: root

    // "a|b": b when the theme has no a
    readonly property list<string> previewIcons: ["folder", "user-home", "text-x-generic", "image-x-generic", "audio-x-generic", "video-x-generic", "application-x-executable", "utilities-terminal", "web-browser|internet-web-browser|firefox", "preferences-system|systemsettings"]
    readonly property string previewTheme: AppLook.iconTheme || `Papirus-${Colours.light ? "Light" : "Dark"}`
    // Icon name -> file in the chosen theme (the shell itself keeps the theme it
    // started with, so it can't show a new one)
    property var previewPaths: ({})
    property list<string> cursorThemes
    property string gsCursorTheme
    property int gsCursorSize: 24
    readonly property string cursorTheme: HyprSettings.varValue("cursorTheme", gsCursorTheme)
    readonly property int cursorSize: HyprSettings.varValue("cursorSize", gsCursorSize)

    function friendlyStyle(s: string): string {
        return ({
                Darkly: Tr.tr("Darkly (modern translucent dark)"),
                Lightly: Tr.tr("Lightly (modern translucent light)"),
                Breeze: Tr.tr("Breeze (KDE classic)"),
                Fusion: Tr.tr("Fusion (built-in standard)"),
                kvantum: Tr.tr("Kvantum (SVG theme engine)"),
                Oxygen: Tr.tr("Oxygen")
            })[s] ?? s;
    }

    function setCursor(theme: string, size: int): void {
        gsCursorTheme = theme;
        gsCursorSize = size;
        HyprSettings.setVar("cursorTheme", theme);
        HyprSettings.setVar("cursorSize", size);
        Hypr.extras.message(`setcursor ${theme} ${size}`);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", String(size)]);
    }

    // After the command binding has the new theme (handlers can run before it)
    onPreviewThemeChanged: Qt.callLater(() => {
        previewProc.running = false;
        previewProc.running = true;
    })

    title: Tr.tr("App appearance")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Icons")
        }

        SelectRow {
            label: Tr.tr("Icon theme")
            subtext: Tr.tr("For apps, the taskbar and the launcher")
            menuItems: [defaultIcons, ...iconItems.instances]
            active: AppLook.iconTheme ? iconItems.instances.find(i => i.value === AppLook.iconTheme) ?? null : defaultIcons
            fallbackText: AppLook.iconTheme
            onSelected: item => AppLook.setIconTheme(item.value)

            MenuItem {
                id: defaultIcons

                text: Tr.tr("Papirus (follows light/dark)")
                value: ""
            }

            Variants {
                id: iconItems

                model: AppLook.iconThemes

                MenuItem {
                    required property var modelData

                    text: modelData.display
                    value: modelData.name
                }
            }
        }

        Process {
            id: previewProc

            running: true
            command: ["python3", "-c", `
import configparser, os, pathlib, re, sys
# Icon theme lookup as desktops do it: the theme's Directories, then the themes it inherits
theme, names = sys.argv[1], sys.argv[2:]
roots = [pathlib.Path(os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local/share")) / "icons", pathlib.Path.home() / ".icons", pathlib.Path("/usr/share/icons")]
def load(n):
    for r in roots:
        if (r / n / "index.theme").is_file():
            c = configparser.ConfigParser(interpolation=None, strict=False)
            c.read(r / n / "index.theme", encoding="utf-8")
            return r / n, c
    return None, None
def chain(n, seen):
    d, c = load(n)
    if not d or n in seen:
        return []
    seen.add(n)
    subs = [x.strip() for x in c.get("Icon Theme", "Directories", fallback="").split(",") if x.strip()]
    out = [(d, subs)]
    for i in c.get("Icon Theme", "Inherits", fallback="").split(","):
        if i.strip():
            out += chain(i.strip(), seen)
    return out
def score(sub):
    if "symbolic" in sub:
        return -1000
    if "scalable" in sub:
        return 100
    sizes = [int(x) for x in re.findall(r"\d+", sub)] or [0]
    return -abs(max(sizes) - 48)
themes = chain(theme, set()) + chain("hicolor", set())
for name in names:
    best = None
    for alt in name.split("|"):
        for d, subs in themes:
            cands = [(score(sub), d / sub / (alt + ext)) for sub in subs for ext in (".svg", ".png") if (d / sub / (alt + ext)).is_file()]
            if cands:
                best = max(cands, key=lambda c: c[0])[1]
                break
        if best:
            break
    print(name + "\\t" + (str(best) if best else ""))
`, root.previewTheme, ...root.previewIcons]
            stdout: StdioCollector {
                onStreamFinished: {
                    const paths = {};
                    for (const line of text.split("\n")) {
                        const [name, path] = line.split("\t");
                        if (path)
                            paths[name] = path;
                    }
                    root.previewPaths = paths;
                }
            }
        }

        // A preview of the theme's icons
        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: previewRow.implicitHeight + Tokens.padding.large * 2

            Row {
                id: previewRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                Repeater {
                    model: root.previewIcons

                    ThemedIcon {
                        required property string modelData

                        implicitSize: 36
                        source: root.previewPaths[modelData] ? `file://${root.previewPaths[modelData]}` : ""
                        opacity: source ? 1 : 0.3
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("App style (KDE & Qt apps)")
        }

        SelectRow {
            label: Tr.tr("Style")
            subtext: Tr.tr("How buttons, menus and controls look in apps like Dolphin and KDE apps")
            segmentedAllowed: false
            menuItems: styleItems.instances
            active: styleItems.instances.find(i => i.value === AppLook.qt("style", "Darkly")) ?? null
            fallbackText: root.friendlyStyle(AppLook.qt("style", "Darkly"))
            onSelected: item => AppLook.setQt("style", item.value)

            Variants {
                id: styleItems

                model: AppLook.qtStyles

                MenuItem {
                    required property string modelData

                    text: root.friendlyStyle(modelData)
                    value: modelData
                }
            }
        }

        ToggleRow {
            text: Tr.tr("Icons in menus")
            checked: AppLook.qt("menusHaveIcons", true)
            onToggled: AppLook.setQt("menusHaveIcons", checked)
        }

        ToggleRow {
            text: Tr.tr("Open files with a single click")
            subtext: Tr.tr("In Qt file managers and dialogs")
            checked: AppLook.qt("singleClickActivate", false)
            onToggled: AppLook.setQt("singleClickActivate", checked)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Apps pick up a new style or font when they're next opened.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        SectionHeader {
            text: Tr.tr("Cursor")
        }

        SelectRow {
            label: Tr.tr("Cursor style")
            menuItems: cursorThemeItems.instances
            active: cursorThemeItems.instances.find(i => i.value === root.cursorTheme) ?? null
            fallbackText: root.cursorTheme.replace(/[-_]/g, " ")
            onSelected: item => root.setCursor(item.value, root.cursorSize)

            Variants {
                id: cursorThemeItems

                model: root.cursorThemes

                MenuItem {
                    required property string modelData

                    text: modelData.replace(/[-_]/g, " ")
                    value: modelData
                }
            }
        }

        StepperRow {
            label: Tr.tr("Cursor size")
            value: root.cursorSize
            from: 16
            to: 96
            stepSize: 8
            onMoved: v => root.setCursor(root.cursorTheme, v)
        }

        SectionHeader {
            text: Tr.tr("More")
        }

        NavRow {
            icon: "palette"
            text: Tr.tr("Colours")
            subtext: Tr.tr("App colours follow the colour scheme")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("colours"),
                tab: "colours",
                path: []
            })
        }

        Process {
            running: true
            command: ["sh", "-c", "for d in \"$HOME/.icons\"/* \"$HOME/.local/share/icons\"/* /usr/share/icons/*; do [ -d \"$d/cursors\" ] && basename \"$d\"; done | sort -u"]
            stdout: StdioCollector {
                onStreamFinished: root.cursorThemes = text.split("\n").filter(s => s && s !== "default")
            }
        }

        Process {
            running: true
            command: ["sh", "-c", "gsettings get org.gnome.desktop.interface cursor-theme; gsettings get org.gnome.desktop.interface cursor-size"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const [theme, size] = text.split("\n");
                    root.gsCursorTheme = (theme ?? "").replace(/'/g, "").trim();
                    root.gsCursorSize = parseInt(size) || 24;
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// How apps look: icon theme (GTK, Qt, the shell's taskbar), Qt style, and the
// cursor (kept on Keyboard & mouse, linked from here). App colours follow the
// colour scheme (Wallpaper & style > Colours).
PageBase {
    id: root

    // "a|b": b when the theme has no a
    readonly property list<string> previewIcons: ["folder", "user-home", "text-x-generic", "image-x-generic", "audio-x-generic", "video-x-generic", "application-x-executable", "utilities-terminal", "web-browser|internet-web-browser|firefox", "preferences-system|systemsettings"]
    readonly property string previewTheme: AppLook.iconTheme || `Papirus-${Colours.light ? "Light" : "Dark"}`
    // Icon name -> file in the chosen theme (the shell itself keeps the theme it
    // started with, so it can't show a new one)
    property var previewPaths: ({})

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
            first: true
            text: Tr.tr("Icons")
        }

        SelectRow {
            first: true
            last: true
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
        StyledRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            implicitHeight: previewRow.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            Row {
                id: previewRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                Repeater {
                    model: root.previewIcons

                    IconImage {
                        required property string modelData

                        implicitSize: 36
                        source: root.previewPaths[modelData] ? `file://${root.previewPaths[modelData]}` : ""
                        opacity: source ? 1 : 0.3
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Qt apps")
        }

        SelectRow {
            first: true
            label: Tr.tr("Style")
            subtext: Tr.tr("How buttons, menus and other controls of Qt apps are drawn")
            menuItems: styleItems.instances
            active: styleItems.instances.find(i => i.value === AppLook.qt("style", "Darkly")) ?? null
            fallbackText: AppLook.qt("style", "Darkly")
            onSelected: item => AppLook.setQt("style", item.value)

            Variants {
                id: styleItems

                model: AppLook.qtStyles

                MenuItem {
                    required property string modelData

                    text: modelData
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
            last: true
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
            text: Tr.tr("More")
        }

        NavRow {
            first: true
            icon: "palette"
            text: Tr.tr("Colours")
            subtext: Tr.tr("App colours follow the colour scheme")
            onClicked: root.nState.goTo({
                page: 0,
                path: [3]
            })
        }

        NavRow {
            icon: "text_fields"
            text: Tr.tr("Fonts")
            subtext: Tr.tr("App and shell fonts")
            onClicked: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "fonts"),
                path: []
            })
        }

        NavRow {
            last: true
            icon: "arrow_selector_tool"
            text: Tr.tr("Cursor")
            subtext: Tr.tr("Style and size, on Keyboard & mouse")
            onClicked: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "input"),
                path: [],
                text: Tr.tr("Cursor style"),
                sectionText: Tr.tr("Cursor")
            })
        }
    }
}

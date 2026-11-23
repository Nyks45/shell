import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    property string sysLang: ""
    property string sysRegional: ""
    property var availableLocales: []
    readonly property string localeBusyWhat: Tr.tr("Change system locale")
    readonly property bool localeBusy: Admin.jobs.some(j => j.what === localeBusyWhat)

    function localeDisplayName(code: string): string {
        const base = String(code ?? "").replace(/\.UTF-8$/i, "");
        const loc = Qt.locale(base);
        const lang = loc.nativeLanguageName || loc.name;
        const country = loc.nativeCountryName || "";
        return country ? `${lang} (${country}) · ${base}` : `${lang} · ${base}`;
    }

    function regionalSample(): string {
        const base = String(root.sysRegional ?? "").replace(/\.UTF-8$/i, "");
        const loc = base ? Qt.locale(base) : Qt.locale();
        return `${loc.nativeCountryName || loc.name} · ${Qt.formatDate(new Date(), loc.dateFormat(Locale.ShortFormat))} · ${(1234.56).toLocaleString(loc, "f", 2)}`;
    }

    function refreshLocales(): void {
        localesProc.running = false;
        localesProc.running = true;
    }

    function applyLocale(nextLang: string, nextRegional: string): void {
        if (!nextLang || !nextRegional)
            return;
        Admin.run("set-locale", [nextLang, nextRegional], localeBusyWhat, ok => {
            if (ok) {
                root.sysLang = nextLang;
                root.sysRegional = nextRegional;
                Toaster.toast(Tr.tr("Locale updated"), Tr.tr("Sign out and back in for all apps to use %1").arg(nextLang), "language");
            }
            root.refreshLocales();
        });
    }

    Component.onCompleted: refreshLocales()

    // Temperature units (there must be one for each value of the TemperatureUnit enum)
    readonly property list<MenuItem> tempItems: [
        MenuItem {
            text: Tr.tr("Auto (°C)")
            value: TemperatureUnit.Auto
        },
        MenuItem {
            text: Tr.tr("°C")
            value: TemperatureUnit.Celsius
        },
        MenuItem {
            text: Tr.tr("°F")
            value: TemperatureUnit.Fahrenheit
        },
        MenuItem {
            text: Tr.tr("Kelvin (K)")
            value: TemperatureUnit.Kelvin
        }
    ]

    // Data size units (there must be one for each value of the DataUnit enum)
    readonly property list<MenuItem> dataItems: [
        MenuItem {
            text: Tr.tr("Binary (KiB, MiB)")
            value: DataUnit.Binary
        },
        MenuItem {
            text: Tr.tr("Decimal (KB, MB)")
            value: DataUnit.Decimal
        }
    ]

    title: Tr.tr("Language & region")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Language
        SectionHeader {
            text: Tr.tr("Language")
        }

        SelectRow {
            label: Tr.tr("UI language")
            subtext: Tr.tr("The language used in the shell UI (apps follow your system locale)")
            active: menuItems.find(i => i.modelData === Tr.language) ?? autoLang
            onSelected: item => {
                Tr.language = item.modelData ?? ""; // qmllint disable missing-property
            }

            menuItems: [autoLang, ...langItems.instances]

            MenuItem {
                id: autoLang

                text: Tr.tr("Auto")
            }

            Variants {
                id: langItems

                model: Tr.supportedLanguages

                MenuItem {
                    required property string modelData

                    text: {
                        const locale = Qt.locale(modelData);
                        return locale.name === "C" ? modelData : locale.nativeLanguageName || locale.name;
                    }
                }
            }
        }

        SelectRow {
            visible: root.availableLocales.length > 0
            label: Tr.tr("System language (apps)")
            subtext: root.localeBusy ? Tr.tr("Generating and saving locale…") : Tr.tr("Default language for apps and system tools (takes effect after signing out)")
            enabled: !root.localeBusy
            segmentedAllowed: false
            menuItems: sysLangItems.instances
            active: sysLangItems.instances.find(i => i.value === root.sysLang) ?? null
            fallbackText: root.sysLang ? root.localeDisplayName(root.sysLang) : ""
            onSelected: item => root.applyLocale(String(item.value), root.sysRegional || String(item.value))

            Variants {
                id: sysLangItems

                model: root.availableLocales

                MenuItem {
                    required property string modelData

                    text: root.localeDisplayName(modelData)
                    value: modelData
                }
            }
        }

        SelectRow {
            visible: root.availableLocales.length > 0
            label: Tr.tr("Regional format")
            subtext: root.regionalSample()
            enabled: !root.localeBusy
            segmentedAllowed: false
            menuItems: sysRegItems.instances
            active: sysRegItems.instances.find(i => i.value === root.sysRegional) ?? null
            fallbackText: root.sysRegional ? root.localeDisplayName(root.sysRegional) : ""
            onSelected: item => root.applyLocale(root.sysLang || String(item.value), String(item.value))

            Variants {
                id: sysRegItems

                model: root.availableLocales

                MenuItem {
                    required property string modelData

                    text: root.localeDisplayName(modelData)
                    value: modelData
                }
            }
        }

        InfoRow {
            visible: root.availableLocales.length === 0
            icon: "calendar_today"
            label: Tr.tr("Regional format")
            value: root.regionalSample()
        }

        NavRow {
            icon: "keyboard"
            text: Tr.tr("Keyboard layouts")
            subtext: Tr.tr("Input languages and layout switching in Devices › Mouse & keyboard")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("devices"),
                tab: "input",
                path: []
            })
        }

        // Weather
        SectionHeader {
            text: Tr.tr("Weather")
        }

        TextFieldRow {
            label: Tr.tr("Location")
            subtext: Tr.tr("A city, or coordinates (lat,lon); empty to guess it from your connection")
            placeholderText: Weather.city || Tr.tr("Automatic")
            value: GlobalConfig.services.weatherLocation
            onEditingFinished: v => GlobalConfig.services.weatherLocation = v.trim()
        }

        // Units
        SectionHeader {
            text: Tr.tr("Units")
        }

        SelectRow {
            label: Tr.tr("Temperature")
            subtext: Tr.tr("Units for weather temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.weatherUnits)
            onSelected: item => GlobalConfig.services.weatherUnits = item.value
        }

        SelectRow {
            label: Tr.tr("System temperatures")
            subtext: Tr.tr("Units for CPU and GPU temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.sensorUnits)
            onSelected: item => GlobalConfig.services.sensorUnits = item.value
        }

        SelectRow {
            label: Tr.tr("Data sizes")
            subtext: Tr.tr("Units for data sizes and network speeds")
            menuItems: root.dataItems
            active: root.dataItems.find(i => i.value === GlobalConfig.services.dataUnits)
            onSelected: item => GlobalConfig.services.dataUnits = item.value
        }

        Process {
            id: localesProc

            command: [`${Paths.libdir}/caelestia-system`, "locales"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(text);
                        root.sysLang = d.lang ?? "";
                        root.sysRegional = d.regional ?? d.lang ?? "";
                        root.availableLocales = d.available ?? [];
                    } catch (e) {}
                }
            }
        }
    }
}

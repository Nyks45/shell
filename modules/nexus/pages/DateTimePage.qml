pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Time zone and network time (systemd-timedated: changing them asks for the
// password), and how the shell shows times.
PageBase {
    id: root

    property string timezone
    property bool ntp
    property bool synced
    property list<string> timezones

    function refresh(): void {
        showProc.running = false;
        showProc.running = true;
    }

    title: Tr.tr("Date & time")

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Now")
        }

        InfoRow {
            first: true
            last: true
            icon: "schedule"
            label: Time.format(Units.twelveHourClock ? "h:mm AP" : "HH:mm")
            subtext: Time.format("dddd, d MMMM yyyy")
            value: root.synced ? Tr.tr("Synced") : ""
        }

        SectionHeader {
            text: Tr.tr("Time")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Set the time automatically")
            subtext: Tr.tr("From the internet (NTP)")
            checked: root.ntp
            onToggled: {
                root.ntp = checked;
                setProc.exec(["timedatectl", "set-ntp", checked ? "true" : "false"]);
            }
        }

        ZoneRow {
            icon: "public"
            label: Tr.tr("Time zone")
            status: root.timezone.replace(/_/g, " ")
        }

        SelectRow {
            last: true
            label: Tr.tr("Clock format")
            subtext: Tr.tr("How times are shown across the shell")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("Auto")
                    value: ClockFormat.Auto
                },
                MenuItem {
                    text: Tr.tr("12-hour")
                    value: ClockFormat.TwelveHour
                },
                MenuItem {
                    text: Tr.tr("24-hour")
                    value: ClockFormat.TwentyFourHour
                }
            ]
            active: menuItems.find(i => i.value === GlobalConfig.services.clockFormat) ?? null
            onSelected: item => GlobalConfig.services.clockFormat = item.value
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            id: showProc

            command: ["timedatectl", "show"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const get = k => text.match(new RegExp(`^${k}=(.*)$`, "m"))?.[1] ?? "";
                    root.timezone = get("Timezone");
                    root.ntp = get("NTP") === "yes";
                    root.synced = get("NTPSynchronized") === "yes";
                }
            }
        }

        Process {
            running: true
            command: ["timedatectl", "list-timezones"]
            stdout: StdioCollector {
                onStreamFinished: root.timezones = text.split("\n").filter(s => s)
            }
        }

        // Changes (polkit asks for the password); read back what took
        Process {
            id: setProc

            onExited: root.refresh()
        }
    }

    // A time zone from timedatectl's list
    component ZoneRow: PopupRow {
        id: row

        readonly property int popupHeight: root.flickable.height - y + root.flickable.contentY - Tokens.padding.large - Tokens.padding.extraExtraLarge

        keepPopupAsChild: {
            if (root.nState.animatingContainer || root.opacity < 1)
                return true;

            let p = root.parent;
            while (p && p.objectName !== "PageContainer")
                p = p.parent;
            return p?.opacity < 1;
        }
        popup.topMovement: Math.max(Tokens.sizes.nexus.minPopupHeight - popupHeight, Tokens.padding.large)

        Loader {
            anchors.centerIn: parent
            active: row.popup.animDriver > 0

            sourceComponent: VerticalFadeListView {
                id: list

                implicitWidth: Tokens.sizes.nexus.popupWidth
                // As tall as its items (a short list doesn't get an empty tail), up to the usual height
                implicitHeight: Math.min(contentHeight + topMargin + bottomMargin, CUtils.clamp(row.popupHeight, Tokens.sizes.nexus.minPopupHeight, Tokens.sizes.nexus.maxPopupHeight))

                model: root.timezones
                Component.onCompleted: positionViewAtIndex(Math.max(0, root.timezones.indexOf(root.timezone)), ListView.Center)

                delegate: StateLayer {
                    id: item

                    required property string modelData

                    anchors.fill: undefined
                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    implicitHeight: zoneText.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.small

                    onClicked: {
                        row.popup.open = false;
                        root.timezone = modelData;
                        setProc.exec(["timedatectl", "set-timezone", modelData]);
                    }

                    StyledText {
                        id: zoneText

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.medium
                        text: item.modelData.replace(/_/g, " ")
                        font: Tokens.font.body.small
                        color: item.modelData === root.timezone ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}

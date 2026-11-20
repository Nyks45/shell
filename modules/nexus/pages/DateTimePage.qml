pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
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
    property var zoneItems: []

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
            text: Tr.tr("Now")
        }

        InfoRow {
            icon: "schedule"
            label: Time.format(Units.twelveHourClock ? "h:mm AP" : "HH:mm")
            subtext: Time.format("dddd, d MMMM yyyy")
            value: root.synced ? Tr.tr("Synced") : ""
        }

        SectionHeader {
            text: Tr.tr("Time")
        }

        ToggleRow {
            text: Tr.tr("Set the time automatically")
            subtext: Tr.tr("From the internet (NTP)")
            checked: root.ntp
            onToggled: {
                const want = checked;
                checked = Qt.binding(() => root.ntp);
                setProc.actionTitle = want ? Tr.tr("Automatic time turned on") : Tr.tr("Automatic time turned off");
                setProc.failTitle = Tr.tr("Couldn't change automatic time");
                setProc.actionDetail = "";
                setProc.actionIcon = "schedule";
                setProc.exec(["timedatectl", "set-ntp", want ? "true" : "false"]);
            }
        }

        RowButton {
            icon: "public"
            text: Tr.tr("Time zone")
            subtext: root.timezone ? root.timezone.replace(/_/g, " ") : Tr.tr("Loading…")
            trailingIcon: "chevron_right"
            onClicked: tzPicker.openPicker()
        }

        SelectRow {
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

        TimeZonePickerDialog {
            id: tzPicker

            hostFlickable: root.flickable
            zones: root.zoneItems
            currentZone: root.timezone
            onPicked: tz => {
                if (!tz || tz === root.timezone)
                    return;
                setProc.actionTitle = Tr.tr("Time zone updated");
                setProc.failTitle = Tr.tr("Couldn't change time zone");
                setProc.actionDetail = tz.replace(/_/g, " ");
                setProc.actionIcon = "public";
                setProc.exec(["timedatectl", "set-timezone", tz]);
            }
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
            command: ["python3", "-c", "import json, os, subprocess\nfrom datetime import datetime, timezone\nfrom zoneinfo import ZoneInfo\ncc_names = {}\niso_p = '/usr/share/iso-codes/json/iso_3166-1.json'\nif os.path.exists(iso_p):\n    for e in json.load(open(iso_p)).get('3166-1', []):\n        cc_names[e['alpha_2']] = e.get('common_name') or e.get('name') or ''\nz_countries = {}\nztab_p = '/usr/share/zoneinfo/zone1970.tab'\nif os.path.exists(ztab_p):\n    for line in open(ztab_p):\n        if not line or line.startswith('#'): continue\n        cols = line.rstrip('\\n').split('\\t')\n        if len(cols) >= 3:\n            z_countries[cols[2]] = ' '.join(cc_names[c] for c in cols[0].split(',') if cc_names.get(c))\nnow = datetime.now(timezone.utc)\nfor z in subprocess.check_output(['timedatectl', 'list-timezones'], text=True).splitlines():\n    if not z: continue\n    try: off = int(now.astimezone(ZoneInfo(z)).utcoffset().total_seconds() // 60)\n    except Exception: off = 0\n    print(f'{z}\\t{off}\\t{z_countries.get(z, \"\")}')"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = [];
                    for (const line of text.split("\n")) {
                        if (!line)
                            continue;
                        const cols = line.split("\t");
                        const id = cols[0];
                        const offsetMin = parseInt(cols[1] ?? "0", 10) || 0;
                        const countries = (cols[2] ?? "").replace(/Türkiye/gi, "Türkiye Turkey");
                        const parts = id.split("/");
                        const city = parts[parts.length - 1].replace(/_/g, " ");
                        const region = parts.slice(0, -1).join(" / ").replace(/_/g, " ");
                        const sign = offsetMin >= 0 ? "+" : "-";
                        const abs = Math.abs(offsetMin);
                        const hh = Math.floor(abs / 60);
                        const mm = abs % 60;
                        const utcStr = offsetMin === 0 ? "utc utc+0" : mm ? `utc${sign}${hh}:${String(mm).padStart(2, "0")} ${sign}${hh}:${String(mm).padStart(2, "0")}` : `utc${sign}${hh} ${sign}${hh}`;
                        const plainCountries = countries.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                        out.push({
                            id,
                            city,
                            region,
                            offsetMin,
                            search: `${city} ${region} ${id} ${countries} ${plainCountries} ${utcStr}`.toLowerCase()
                        });
                    }
                    root.zoneItems = out;
                }
            }
        }

        // Changes (polkit asks for the password); report success or failure cleanly
        Process {
            id: setProc

            property string actionTitle
            property string failTitle
            property string actionDetail
            property string actionIcon: "schedule"

            stderr: StdioCollector {
                id: setErr
            }
            onExited: (code, status) => {
                root.refresh();
                if (code === 0) {
                    Toaster.toast(actionTitle || Tr.tr("Saved"), actionDetail, actionIcon);
                } else {
                    const errLine = setErr.text.trim().split("\n").find(l => l.trim().length > 0) ?? "";
                    Toaster.toast(failTitle || Tr.tr("Change failed"), errLine || Tr.tr("The change was cancelled or refused."), "error");
                }
            }
        }
    }
}

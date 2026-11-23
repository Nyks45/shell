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
    property bool localRtc: false
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
            subtext: Time.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
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
                setProc.queue(["timedatectl", "set-ntp", want ? "true" : "false"], want ? Tr.tr("Automatic time turned on") : Tr.tr("Automatic time turned off"), Tr.tr("Couldn't change automatic time"), "", "schedule");
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
                    text: Qt.locale().timeFormat(Locale.ShortFormat).includes("AP") || Qt.locale().timeFormat(Locale.ShortFormat).includes("ap") ? Tr.tr("Auto (12-hour)") : Tr.tr("Auto (24-hour)")
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

        ToggleRow {
            text: Tr.tr("Keep hardware clock in local time (Windows dual-boot)")
            subtext: Tr.tr("Off (recommended): hardware clock uses UTC; turn on if Windows shows the wrong time after rebooting")
            checked: root.localRtc
            onToggled: {
                const want = checked;
                checked = Qt.binding(() => root.localRtc);
                setProc.queue(["timedatectl", "set-local-rtc", want ? "1" : "0"], Tr.tr("Hardware clock updated"), Tr.tr("Couldn't update hardware clock"), want ? Tr.tr("Local time (Windows dual-boot)") : Tr.tr("UTC (recommended)"), "schedule");
            }
        }

        TimeZonePickerDialog {
            id: tzPicker

            hostFlickable: root.flickable
            zones: root.zoneItems
            currentZone: root.timezone
            onPicked: tz => {
                if (!tz || tz === root.timezone)
                    return;
                setProc.queue(["timedatectl", "set-timezone", tz], Tr.tr("Time zone updated"), Tr.tr("Couldn't change time zone"), tz.replace(/_/g, " "), "public");
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
                    root.localRtc = get("LocalRTC") === "yes";
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

        // Changes (polkit asks for the password), one at a time: a second
        // change while the first one's password prompt is open waits its turn
        // instead of stopping the first (exec() ends a running process).
        // Each reports its own success or failure.
        Process {
            id: setProc

            property var current: null
            property var waiting: []

            function queue(command: var, actionTitle: string, failTitle: string, actionDetail: string, actionIcon: string): void {
                waiting = [...waiting, {
                        command,
                        actionTitle,
                        failTitle,
                        actionDetail,
                        actionIcon
                    }];
                if (!running && !current)
                    next();
            }

            function next(): void {
                if (waiting.length === 0) {
                    current = null;
                    return;
                }
                current = waiting[0];
                waiting = waiting.slice(1);
                exec(current.command);
            }

            stderr: StdioCollector {
                id: setErr
            }
            onExited: (code, status) => {
                const job = current ?? {};
                root.refresh();
                if (code === 0) {
                    Toaster.toast(job.actionTitle || Tr.tr("Saved"), job.actionDetail ?? "", job.actionIcon || "schedule");
                } else {
                    const errLine = setErr.text.trim().split("\n").find(l => l.trim().length > 0) ?? "";
                    Toaster.toast(job.failTitle || Tr.tr("Change failed"), errLine || Tr.tr("The change was cancelled or refused."), "error");
                }
                Qt.callLater(next);
            }
        }
    }
}

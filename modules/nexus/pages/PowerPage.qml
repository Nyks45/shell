pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.utils
import qs.modules.nexus.common

// Like Windows' Power & sleep: when the screen locks, turns off and the PC
// sleeps (general.idle.timeouts), and the power mode (power-profiles-daemon).
PageBase {
    id: root

    // A command list for the sleep action. (A JS array would arrive as a
    // generic list, which the option's string-or-string-list type drops.)
    readonly property list<string> suspendAction: ["suspend"]

    // Minutes; 0 = never
    readonly property list<int> minutes: [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]

    property string powerProfile
    property list<string> powerProfiles

    // The idle timeout doing `kind` (lock, screen, sleep), or null
    function timeoutFor(kind: string): var {
        const list = GlobalConfig.general.idle.timeouts;
        for (let i = 0; i < list.count; i++) {
            if (kindOf(list.at(i).idleAction) === kind)
                return list.at(i);
        }
        return null;
    }

    function kindOf(action: var): string {
        // A string, or a command list (its first word)
        const a = String((typeof action === "string" ? action : action?.[0]) ?? "").toLowerCase();
        if (a === "lock")
            return "lock";
        if (a.startsWith("dpms"))
            return "screen";
        if (a.includes("suspend") || a.includes("hibernate"))
            return "sleep";
        return "";
    }

    function setTimeout(kind: string, mins: int): void {
        const list = GlobalConfig.general.idle.timeouts;
        for (let i = 0; i < list.count; i++) {
            if (kindOf(list.at(i).idleAction) !== kind)
                continue;
            if (mins === 0)
                list.remove(i);
            else {
                list.at(i).timeout = mins * 60;
                // Plain sleep: this setting is "Sleep after"
                if (kind === "sleep")
                    list.at(i).idleAction = root.suspendAction;
            }
            return;
        }
        if (mins === 0)
            return;
        if (kind === "lock")
            list.insert({
                timeout: mins * 60,
                idleAction: "lock"
            });
        else if (kind === "screen")
            list.insert({
                timeout: mins * 60,
                idleAction: "dpms off",
                returnAction: "dpms on"
            });
        else
            list.insert({
                timeout: mins * 60,
                idleAction: root.suspendAction
            });
    }

    function minutesLabel(m: int): string {
        if (m === 0)
            return Tr.tr("Never");
        if (m % 60 === 0)
            return m === 60 ? Tr.tr("1 hour") : Tr.tr("%1 hours").arg(m / 60);
        return m === 1 ? Tr.tr("1 minute") : Tr.tr("%1 minutes").arg(m);
    }

    function profileLabel(p: string): string {
        if (p === "performance")
            return Tr.tr("Best performance");
        if (p === "balanced")
            return Tr.tr("Balanced");
        if (p === "power-saver")
            return Tr.tr("Power saver");
        return p;
    }

    title: Tr.tr("Power & sleep")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("When idle")
        }

        TimeoutRow {
            first: true
            kind: "lock"
            label: Tr.tr("Lock the screen after")
            subtext: Tr.tr("Time without input before the lock screen shows")
        }

        TimeoutRow {
            kind: "screen"
            label: Tr.tr("Turn off the screen after")
            subtext: Tr.tr("It comes back on when you move the mouse or press a key")
        }

        TimeoutRow {
            last: true
            kind: "sleep"
            label: Tr.tr("Sleep after")
            subtext: Tr.tr("The PC goes to sleep; press a key or the power button to wake it")
        }

        SectionHeader {
            text: Tr.tr("Sleep")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Lock before sleeping")
            subtext: Tr.tr("Waking up shows the lock screen")
            checked: GlobalConfig.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Stay awake while audio plays")
            subtext: Tr.tr("Music or a video playing keeps the screen on and the PC awake")
            checked: GlobalConfig.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        SectionHeader {
            visible: root.powerProfiles.length > 0
            text: Tr.tr("Power mode")
        }

        SelectRow {
            visible: root.powerProfiles.length > 0
            first: true
            last: true
            label: Tr.tr("Power mode")
            subtext: Tr.tr("Trade speed against power use and heat")
            menuItems: profileItems.instances
            active: profileItems.instances.find(i => i.value === root.powerProfile) ?? null
            onSelected: item => {
                root.powerProfile = item.value;
                Quickshell.execDetached(["powerprofilesctl", "set", item.value]);
            }

            Variants {
                id: profileItems

                model: root.powerProfiles

                MenuItem {
                    required property string modelData

                    text: root.profileLabel(modelData)
                    value: modelData
                }
            }
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Variants {
            id: minuteItems

            model: root.minutes

            MenuItem {
                required property int modelData

                text: root.minutesLabel(modelData)
                value: modelData
            }
        }

        Process {
            running: true
            command: ["powerprofilesctl", "list"]
            stdout: StdioCollector {
                onStreamFinished: root.powerProfiles = Strings.allMatches(text, /^[ *]+([a-z-]+):\s*$/gm).map(m => m[1])
            }
        }

        Process {
            running: true
            command: ["powerprofilesctl", "get"]
            stdout: StdioCollector {
                onStreamFinished: root.powerProfile = text.trim()
            }
        }
    }

    // (One list for all three: a Variants inside each row's menu broke the
    // menus of the rows after the first.) A time that's not one of these shows
    // as the row's text.
    component TimeoutRow: SelectRow {
        required property string kind
        readonly property int current: Math.round((root.timeoutFor(kind)?.timeout ?? 0) / 60)

        menuItems: minuteItems.instances
        active: minuteItems.instances.find(i => i.value === current) ?? null
        fallbackText: root.minutesLabel(current)
        onSelected: item => root.setTimeout(kind, item.value)
    }
}

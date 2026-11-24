pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// System-wide AdGuard Home ad blocker: live protection toggle, pause timers,
// traffic stats, query log with one-click rules, filter subscriptions, custom
// AdGuard-syntax rules, safe browsing/search/parental toggles, blocked services,
// and encrypted DoH/DoT DNS upstreams.
PageBase {
    id: root

    property string querySearch: ""
    property string queryFilter: "all"
    property bool autoRefreshLog: true
    property bool showAllServices: false
    property string serviceSearch: ""
    property bool addFilterOpen: false
    property bool customDnsSelected: false

    readonly property var _filteredAvailableServices: {
        const q = serviceSearch.trim().toLowerCase();
        const all = AdBlocker.availableServices ?? [];
        const base = q.length > 0 ? all.filter(s => (s.name || "").toLowerCase().includes(q) || (s.id || "").toLowerCase().includes(q)) : all;
        if (q.length > 0 || showAllServices)
            return base;
        // Show top ~18 popular services (plus any currently blocked ones) initially.
        const popularIds = ["tiktok", "instagram", "facebook", "youtube", "reddit", "twitch", "discord", "steam", "snapchat", "twitter", "spotify", "netflix", "telegram", "whatsapp", "roblox", "epic_games", "amazon_streaming", "openai"];
        const chosen = base.filter(s => popularIds.includes(s.id) || AdBlocker.blockedServices.includes(s.id));
        return chosen.length > 0 ? chosen : base.slice(0, 18);
    }

    readonly property var _unaddedCuratedFilters: {
        const existingUrls = (AdBlocker.filters ?? []).map(f => f.url);
        return (AdBlocker.curatedFilters ?? []).filter(c => !existingUrls.includes(c.url));
    }

    function _matchingDnsPreset(): string {
        const cur = (AdBlocker.upstreamDns ?? []).join("|");
        for (const p of AdBlocker.dnsPresets) {
            if (p.servers.join("|") === cur)
                return p.id;
        }
        return "custom";
    }

    function reloadQueryLog(): void {
        if (!AdBlocker.configured)
            return;
        AdBlocker.refreshQueryLog(root.querySearch, root.queryFilter, 120);
    }

    function formatQueryTime(tsMs: real): string {
        if (!tsMs || tsMs <= 0)
            return "";
        return Qt.formatTime(new Date(tsMs), "hh:mm:ss");
    }

    title: Tr.tr("Ad blocker")
    isSubPage: true

    Component.onCompleted: {
        AdBlocker.refresh();
        customDnsSelected = _matchingDnsPreset() === "custom";
    }

    onVisibleChanged: {
        if (visible) {
            AdBlocker.refresh();
            if (queryLogTab.open)
                reloadQueryLog();
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            function onConfiguredChanged(): void {
                if (AdBlocker.configured && queryLogTab.open)
                    root.reloadQueryLog();
            }

            function onUpstreamDnsChanged(): void {
                root.customDnsSelected = root._matchingDnsPreset() === "custom";
            }

            target: AdBlocker
        }

        Timer {
            id: queryDebounce

            interval: 260
            onTriggered: root.reloadQueryLog()
        }

        Timer {
            interval: 5000
            repeat: true
            running: root.visible && queryLogTab.open && root.autoRefreshLog && AdBlocker.configured
            onTriggered: root.reloadQueryLog()
        }

        // ---- Setup / install requirements -----------------------------------
        RequirementRow {
            visible: AdBlocker.loaded && !AdBlocker.installed
            icon: "shield"
            text: Tr.tr("AdGuard Home isn't installed")
            subtext: Tr.tr("Install AdGuard Home (8.7 MiB) so Settings can block ads and trackers across every app without running an external web UI.")
            actionText: AdBlocker.busy ? "" : Tr.tr("Install & set up")
            onAction: AdBlocker.installAndSetup()
        }

        RequirementRow {
            visible: AdBlocker.loaded && AdBlocker.installed && !AdBlocker.configured
            icon: "tune"
            text: Tr.tr("Set up system-wide ad blocker")
            subtext: Tr.tr("Runs a private local AdGuard Home resolver on loopback (127.0.0.55) with encrypted upstream DNS.")
            actionText: AdBlocker.busy ? "" : Tr.tr("Set up")
            onAction: AdBlocker.setup()
        }

        // ---- Hero status card ------------------------------------------------
        ConnectedRect {
            visible: AdBlocker.configured
            standalone: true
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.medium
            implicitHeight: heroCol.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: heroCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.large

                    MaterialIcon {
                        text: AdBlocker.active ? "shield" : AdBlocker.paused ? "pause_circle" : "gpp_maybe"
                        fill: AdBlocker.active ? 1 : 0
                        color: AdBlocker.active ? Colours.palette.m3primary : AdBlocker.paused ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.large
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall / 2

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (AdBlocker.active)
                                    return Tr.tr("Ad blocking active");
                                if (AdBlocker.paused)
                                    return Tr.tr("Paused · %1 left").arg(AdBlocker.formatPauseCountdown(AdBlocker.pauseRemainingSec));
                                return Tr.tr("Ad blocker is off");
                            }
                            font: Tokens.font.title.builders.medium.build()
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (AdBlocker.active)
                                    return Tr.tr("Blocking ads & trackers system-wide · %1 active rules").arg(AdBlocker.formatCompactCount(AdBlocker.totalEnabledRules));
                                if (AdBlocker.paused)
                                    return Tr.tr("DNS filtering is temporarily paused and will resume automatically");
                                return Tr.tr("System DNS is using your normal network resolver");
                            }
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                        }
                    }

                    StyledSwitch {
                        checked: AdBlocker.active
                        disabled: AdBlocker.busy
                        onToggled: AdBlocker.setEnabled(checked)
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    TextButton {
                        visible: !AdBlocker.active
                        isRound: true
                        text: AdBlocker.paused ? Tr.tr("Resume now") : Tr.tr("Turn on")
                        type: TextButton.Filled
                        disabled: AdBlocker.busy
                        onClicked: AdBlocker.resumeProtection()
                    }

                    TextButton {
                        visible: AdBlocker.active
                        isRound: true
                        text: Tr.tr("Pause 5 min")
                        type: TextButton.Tonal
                        disabled: AdBlocker.busy
                        onClicked: AdBlocker.pauseFor(5)
                    }

                    TextButton {
                        visible: AdBlocker.active
                        isRound: true
                        text: Tr.tr("Pause 15 min")
                        type: TextButton.Tonal
                        disabled: AdBlocker.busy
                        onClicked: AdBlocker.pauseFor(15)
                    }

                    TextButton {
                        visible: AdBlocker.active
                        isRound: true
                        text: Tr.tr("Pause 1 hour")
                        type: TextButton.Tonal
                        disabled: AdBlocker.busy
                        onClicked: AdBlocker.pauseFor(60)
                    }

                    TextButton {
                        isRound: true
                        text: Tr.tr("Refresh")
                        type: TextButton.Text
                        disabled: AdBlocker.busy
                        onClicked: {
                            AdBlocker.refresh();
                            if (queryLogTab.open)
                                root.reloadQueryLog();
                        }
                    }
                }
            }
        }

        RequirementRow {
            visible: AdBlocker.configured && AdBlocker.warpActive && AdBlocker.active
            neutral: true
            Layout.bottomMargin: Tokens.spacing.medium
            icon: "info"
            text: Tr.tr("Cloudflare WARP is connected")
            subtext: Tr.tr("System lookups stay filtered through AdGuard Home (with upstream DoH routed over WARP). Apps that read /etc/resolv.conf directly use WARP's resolver.")
        }

        // ---- Tabs ------------------------------------------------------------
        PartTabs {
            visible: AdBlocker.configured
            parts: [overviewTab, queryLogTab, filtersTab, dnsTab]
        }

        // ════ TAB 1: OVERVIEW ════════════════════════════════════════════════
        TabPart {
            id: overviewTab

            key: "overview"
            title: Tr.tr("Overview")
            icon: "analytics"

            ColumnLayout {
                width: root.cappedWidth
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: Tr.tr("Statistics")
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.cappedWidth >= 560 ? 4 : 2
                    columnSpacing: Tokens.spacing.small
                    rowSpacing: Tokens.spacing.small
                    Layout.bottomMargin: Tokens.spacing.small

                    Repeater {
                        model: [
                            {
                                label: Tr.tr("Queries"),
                                value: AdBlocker.formatCompactCount(AdBlocker.stats.numDnsQueries ?? 0),
                                accent: Colours.palette.m3onSurface
                            },
                            {
                                label: Tr.tr("Blocked"),
                                value: `${AdBlocker.formatCompactCount(AdBlocker.stats.numBlockedFiltering ?? 0)} (${(AdBlocker.stats.blockedPercent ?? 0).toFixed(1)}%)`,
                                accent: Colours.palette.m3primary
                            },
                            {
                                label: Tr.tr("Avg latency"),
                                value: Tr.tr("%1 ms").arg(AdBlocker.stats.avgProcessingMs ?? 0),
                                accent: Colours.palette.m3onSurface
                            },
                            {
                                label: Tr.tr("Active rules"),
                                value: AdBlocker.formatCompactCount(AdBlocker.totalEnabledRules),
                                accent: Colours.palette.m3secondary
                            }
                        ]

                        ConnectedRect {
                            required property var modelData

                            standalone: true
                            Layout.fillWidth: true
                            implicitHeight: tileCol.implicitHeight + Tokens.padding.medium * 2

                            ColumnLayout {
                                id: tileCol

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Tokens.padding.medium
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: modelData.accent
                                    font: Tokens.font.title.builders.small.build()
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // 24h bar strip
                ConnectedRect {
                    readonly property var totalSeries: (AdBlocker.stats.dnsQueriesSeries ?? []).slice(-24)
                    readonly property var blockedSeries: (AdBlocker.stats.blockedSeries ?? []).slice(-24)
                    readonly property int maxVal: {
                        let m = 1;
                        for (const v of totalSeries)
                            if (v > m)
                                m = v;
                        return m;
                    }

                    visible: totalSeries.length > 0
                    standalone: true
                    Layout.fillWidth: true
                    implicitHeight: chartCol.implicitHeight + Tokens.padding.medium * 2

                    ColumnLayout {
                        id: chartCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.small

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: Tr.tr("Last 24 hours")
                                font: Tokens.font.body.small
                            }

                            StyledRect {
                                implicitWidth: 8
                                implicitHeight: 8
                                radius: 4
                                color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.35)
                            }
                            StyledText {
                                text: Tr.tr("Allowed")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                            StyledRect {
                                Layout.leftMargin: Tokens.spacing.small
                                implicitWidth: 8
                                implicitHeight: 8
                                radius: 4
                                color: Colours.palette.m3primary
                            }
                            StyledText {
                                text: Tr.tr("Blocked")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 68

                            Row {
                                id: barRow

                                readonly property var totSeries: (AdBlocker.stats.dnsQueriesSeries ?? []).slice(-24)
                                readonly property var blkSeries: (AdBlocker.stats.blockedSeries ?? []).slice(-24)
                                readonly property int maxSample: {
                                    let m = 1;
                                    for (const v of totSeries)
                                        if (v > m)
                                            m = v;
                                    return m;
                                }

                                anchors.fill: parent
                                spacing: 4

                                Repeater {
                                    model: barRow.totSeries.length

                                    Item {
                                        required property int index
                                        readonly property int tot: barRow.totSeries[index] ?? 0
                                        readonly property int blk: barRow.blkSeries[index] ?? 0
                                        readonly property real barW: Math.max(2, (barRow.width - Math.max(0, barRow.totSeries.length - 1) * barRow.spacing) / Math.max(1, barRow.totSeries.length))

                                        width: barW
                                        height: barRow.height

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: parent.tot > 0 ? Math.max(3, Math.round((parent.tot / barRow.maxSample) * parent.height)) : 2
                                            radius: 3
                                            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, parent.tot > 0 ? 0.35 : 0.12)
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: parent.blk > 0 ? Math.max(3, Math.round((parent.blk / barRow.maxSample) * parent.height)) : 0
                                            radius: 3
                                            color: Colours.palette.m3primary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                SectionHeader {
                    visible: (AdBlocker.stats.topBlockedDomains ?? []).length > 0
                    text: Tr.tr("Top blocked domains")
                }

                Repeater {
                    model: (AdBlocker.stats.topBlockedDomains ?? []).slice(0, 8)

                    ConnectedRect {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: topDomRow.implicitHeight + Tokens.padding.medium * 2

                        RowLayout {
                            id: topDomRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: "block"
                                color: Colours.palette.m3error
                                fontStyle: Tokens.font.icon.medium
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.domain ?? ""
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Tr.trN("%n blocked request", "%n blocked requests", modelData.count ?? 0)
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                }
                            }

                            TextButton {
                                text: Tr.tr("Allow")
                                type: TextButton.Tonal
                                disabled: AdBlocker.busy
                                onClicked: AdBlocker.quickAllow(modelData.domain ?? "")
                            }
                        }
                    }
                }

                SectionHeader {
                    text: Tr.tr("Maintenance")
                }

                RowButton {
                    icon: "restart_alt"
                    text: Tr.tr("Reset statistics")
                    subtext: Tr.tr("Clear DNS query counters and top domain rankings")
                    disabled: AdBlocker.busy
                    onClicked: confirmDialog.ask({
                        header: Tr.tr("Reset statistics?"),
                        body: Tr.tr("Clears query counts, block percentages, and hourly charts."),
                        confirmLabel: Tr.tr("Reset"),
                        onConfirm: () => AdBlocker.resetStats()
                    })
                }

                RowButton {
                    icon: "delete_sweep"
                    text: Tr.tr("Clear query log")
                    subtext: Tr.tr("Delete recorded recent DNS lookups")
                    disabled: AdBlocker.busy
                    onClicked: confirmDialog.ask({
                        header: Tr.tr("Clear query log?"),
                        body: Tr.tr("Removes all stored query log entries."),
                        confirmLabel: Tr.tr("Clear"),
                        onConfirm: () => AdBlocker.clearQueryLog()
                    })
                }
            }
        }

        // ════ TAB 2: QUERY LOG ═══════════════════════════════════════════════
        TabPart {
            id: queryLogTab

            key: "querylog"
            title: Tr.tr("Query log")
            icon: "history"

            onOpenChanged: {
                if (open && AdBlocker.configured)
                    root.reloadQueryLog();
            }

            ColumnLayout {
                width: root.cappedWidth
                spacing: Tokens.spacing.extraSmall / 2

                ConnectedRect {
                    standalone: true
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacing.small
                    implicitHeight: logFilterCol.implicitHeight + Tokens.padding.medium * 2

                    ColumnLayout {
                        id: logFilterCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.medium
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledTextField {
                                Layout.fillWidth: true
                                placeholderText: Tr.tr("Search domains (e.g. doubleclick, telemetry)…")
                                leadingIcon: "search"
                                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                                onTextChanged: {
                                    root.querySearch = text;
                                    queryDebounce.restart();
                                }
                            }

                            IconButton {
                                type: IconButton.Tonal
                                isRound: true
                                icon: "refresh"
                                disabled: AdBlocker.loadingLog
                                onClicked: root.reloadQueryLog()
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: [
                                    {
                                        id: "all",
                                        label: Tr.tr("All")
                                    },
                                    {
                                        id: "blocked",
                                        label: Tr.tr("Blocked")
                                    },
                                    {
                                        id: "allowed",
                                        label: Tr.tr("Allowed")
                                    }
                                ]

                                TextButton {
                                    required property var modelData

                                    text: modelData.label
                                    isToggle: true
                                    followChecked: true
                                    checked: root.queryFilter === modelData.id
                                    type: TextButton.Tonal
                                    onClicked: {
                                        root.queryFilter = modelData.id;
                                        root.reloadQueryLog();
                                    }
                                }
                            }

                            TextButton {
                                text: Tr.tr("Auto-refresh")
                                isToggle: true
                                followChecked: true
                                checked: root.autoRefreshLog
                                type: TextButton.Tonal
                                onClicked: root.autoRefreshLog = !root.autoRefreshLog
                            }
                        }
                    }
                }

                InfoRow {
                    visible: AdBlocker.queryLog.length === 0
                    icon: AdBlocker.loadingLog ? "hourglass_empty" : "search_off"
                    label: AdBlocker.loadingLog ? Tr.tr("Loading query log…") : Tr.tr("No matching queries")
                    subtext: AdBlocker.loadingLog ? "" : Tr.tr("DNS lookups from apps and browsers appear here automatically.")
                }

                Repeater {
                    model: AdBlocker.queryLog

                    ConnectedRect {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: qRow.implicitHeight + Tokens.padding.medium * 2

                        RowLayout {
                            id: qRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            StyledRect {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: modelData.blocked ? Colours.palette.m3error : Colours.palette.m3primary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.domain || "-"
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: [modelData.type, root.formatQueryTime(modelData.time), modelData.reason, modelData.rule ? `(${modelData.rule})` : "", modelData.elapsedMs !== undefined ? `${modelData.elapsedMs} ms` : ""].filter(s => s).join(" · ")
                                    color: modelData.blocked ? Colours.palette.m3error : Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                }
                            }

                            TextButton {
                                visible: (modelData.domain ?? "").length > 0
                                text: modelData.blocked ? Tr.tr("Allow") : Tr.tr("Block")
                                type: TextButton.Tonal
                                disabled: AdBlocker.busy
                                onClicked: {
                                    const dom = modelData.domain;
                                    if (modelData.blocked)
                                        AdBlocker.quickAllow(dom, () => root.reloadQueryLog());
                                    else
                                        AdBlocker.quickBlock(dom, () => root.reloadQueryLog());
                                }
                            }
                        }
                    }
                }
            }
        }

        // ════ TAB 3: FILTERS & RULES ═════════════════════════════════════════
        TabPart {
            id: filtersTab

            key: "filters"
            title: Tr.tr("Filters & rules")
            icon: "rule"

            ColumnLayout {
                width: root.cappedWidth
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: Tr.tr("Filter subscriptions")
                }

                RowButton {
                    icon: "sync"
                    text: AdBlocker.refreshingFilters ? Tr.tr("Updating filter lists…") : Tr.tr("Update all filter lists")
                    subtext: Tr.tr("AdGuard DNS rules auto-update daily in the background")
                    disabled: AdBlocker.busy || AdBlocker.refreshingFilters
                    onClicked: AdBlocker.refreshFilters()
                }

                Repeater {
                    model: AdBlocker.filters

                    ConnectedRect {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: fRow.implicitHeight + Tokens.padding.medium * 2

                        RowLayout {
                            id: fRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name || modelData.url
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.rulesCount > 0 ? Tr.tr("%1 rules").arg(AdBlocker.formatCompactCount(modelData.rulesCount)) : modelData.url
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                }
                            }

                            StyledSwitch {
                                checked: !!modelData.enabled
                                disabled: AdBlocker.busy
                                onToggled: AdBlocker.toggleFilter(modelData, checked)
                            }

                            IconButton {
                                type: IconButton.Text
                                isRound: true
                                icon: "delete"
                                disabled: AdBlocker.busy
                                onClicked: confirmDialog.ask({
                                    header: Tr.tr("Remove filter list?"),
                                    body: Tr.tr("Stops blocking rules from %1.").arg(modelData.name || modelData.url),
                                    confirmLabel: Tr.tr("Remove"),
                                    onConfirm: () => AdBlocker.removeFilter(modelData.url)
                                })
                            }
                        }
                    }
                }

                RowButton {
                    icon: root.addFilterOpen ? "expand_less" : "add"
                    text: Tr.tr("Add custom filter list URL…")
                    onClicked: root.addFilterOpen = !root.addFilterOpen
                }

                ConnectedRect {
                    visible: root.addFilterOpen
                    standalone: true
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    implicitHeight: customFilterForm.implicitHeight + Tokens.padding.medium * 2

                    ColumnLayout {
                        id: customFilterForm

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.small

                        StyledTextField {
                            id: customFilterName

                            Layout.fillWidth: true
                            placeholderText: Tr.tr("List name (optional)")
                            leadingIcon: "label"
                        }

                        StyledTextField {
                            id: customFilterUrl

                            Layout.fillWidth: true
                            placeholderText: Tr.tr("https://example.com/blocklist.txt")
                            leadingIcon: "link"
                            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Item {
                                Layout.fillWidth: true
                            }

                            TextButton {
                                text: Tr.trCtx("Cancel", "button")
                                type: TextButton.Text
                                onClicked: root.addFilterOpen = false
                            }

                            TextButton {
                                text: Tr.trCtx("Add", "button")
                                type: TextButton.Filled
                                disabled: AdBlocker.busy || !/^https?:\/\/.+/.test(customFilterUrl.text.trim())
                                onClicked: AdBlocker.addFilter(customFilterUrl.text, customFilterName.text, ok => {
                                    if (ok) {
                                        customFilterUrl.clear();
                                        customFilterName.clear();
                                        root.addFilterOpen = false;
                                    }
                                })
                            }
                        }
                    }
                }

                SectionHeader {
                    visible: root._unaddedCuratedFilters.length > 0
                    text: Tr.tr("Recommended blocklists")
                }

                Repeater {
                    model: root._unaddedCuratedFilters

                    ConnectedRect {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: recRow.implicitHeight + Tokens.padding.medium * 2

                        RowLayout {
                            id: recRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Tr.trMarked(modelData.description)
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    wrapMode: Text.WordWrap
                                }
                            }

                            TextButton {
                                text: Tr.trCtx("Add", "button")
                                type: TextButton.Tonal
                                disabled: AdBlocker.busy
                                onClicked: AdBlocker.addFilter(modelData.url, modelData.name)
                            }
                        }
                    }
                }

                SectionHeader {
                    text: Tr.tr("Custom rules")
                }

                ConnectedRect {
                    standalone: true
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacing.small
                    implicitHeight: ruleAddCol.implicitHeight + Tokens.padding.medium * 2

                    ColumnLayout {
                        id: ruleAddCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.small

                        StyledTextField {
                            id: ruleInput

                            Layout.fillWidth: true
                            placeholderText: Tr.tr("Domain or AdGuard rule (e.g. tracker.example.com or @@||site.com^)")
                            leadingIcon: "edit_note"
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            onAccepted: {
                                const raw = text.trim();
                                if (!raw)
                                    return;
                                if (raw.startsWith("||") || raw.startsWith("@@") || raw.startsWith("/") || raw.includes("$") || raw.startsWith("!"))
                                    AdBlocker.addCustomRule(raw);
                                else
                                    AdBlocker.quickBlock(raw);
                                clear();
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: Tr.tr("Use ||domain^ to block or @@||domain^ to allow.")
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                wrapMode: Text.WordWrap
                            }

                            TextButton {
                                text: Tr.tr("Block")
                                type: TextButton.Tonal
                                disabled: AdBlocker.busy || ruleInput.text.trim().length === 0
                                onClicked: {
                                    const raw = ruleInput.text.trim();
                                    if (raw.startsWith("||") || raw.startsWith("/") || raw.includes("$"))
                                        AdBlocker.addCustomRule(raw);
                                    else
                                        AdBlocker.quickBlock(raw);
                                    ruleInput.clear();
                                }
                            }

                            TextButton {
                                text: Tr.tr("Allow")
                                type: TextButton.Tonal
                                disabled: AdBlocker.busy || ruleInput.text.trim().length === 0
                                onClicked: {
                                    const raw = ruleInput.text.trim();
                                    if (raw.startsWith("@@"))
                                        AdBlocker.addCustomRule(raw);
                                    else
                                        AdBlocker.quickAllow(raw);
                                    ruleInput.clear();
                                }
                            }
                        }
                    }
                }

                InfoRow {
                    visible: AdBlocker.userRules.length === 0
                    icon: "rule"
                    label: Tr.tr("No custom rules")
                    subtext: Tr.tr("Add domain exceptions or extra blocks above, or block/allow directly from the query log.")
                }

                Repeater {
                    model: AdBlocker.userRules

                    ConnectedRect {
                        required property var modelData
                        required property int index
                        readonly property bool isAllow: String(modelData).startsWith("@@")

                        Layout.fillWidth: true
                        implicitHeight: uRuleRow.implicitHeight + Tokens.padding.medium * 2

                        RowLayout {
                            id: uRuleRow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            StyledRect {
                                implicitWidth: badgeTxt.implicitWidth + Tokens.padding.small * 2
                                implicitHeight: badgeTxt.implicitHeight + 4
                                radius: Tokens.rounding.extraSmall
                                color: isAllow ? Colours.palette.m3primaryContainer : Colours.palette.m3errorContainer

                                StyledText {
                                    id: badgeTxt

                                    anchors.centerIn: parent
                                    text: isAllow ? Tr.tr("Allow") : Tr.tr("Block")
                                    color: isAllow ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onErrorContainer
                                    font: Tokens.font.label.small
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: String(modelData)
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            IconButton {
                                type: IconButton.Text
                                isRound: true
                                icon: "delete"
                                disabled: AdBlocker.busy
                                onClicked: AdBlocker.removeCustomRule(index)
                            }
                        }
                    }
                }
            }
        }

        // ════ TAB 4: DNS & PRIVACY ═══════════════════════════════════════════
        TabPart {
            id: dnsTab

            key: "dns"
            title: Tr.tr("DNS & privacy")
            icon: "dns"

            ColumnLayout {
                width: root.cappedWidth
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: Tr.tr("Safe protections")
                }

                ToggleRow {
                    text: Tr.tr("Malware & phishing protection")
                    subtext: Tr.tr("Block known malicious, phishing, and scam domains via AdGuard Safe Browsing")
                    checked: AdBlocker.safeBrowsing
                    disabled: AdBlocker.busy
                    onToggled: AdBlocker.setSafety("safebrowsing", checked)
                }

                ToggleRow {
                    text: Tr.tr("Safe Search")
                    subtext: Tr.tr("Enforce Safe Search across Google, Bing, DuckDuckGo, and YouTube")
                    checked: AdBlocker.safeSearch
                    disabled: AdBlocker.busy
                    onToggled: AdBlocker.setSafety("safesearch", checked)
                }

                ToggleRow {
                    text: Tr.tr("Parental control")
                    subtext: Tr.tr("Block adult domains across all apps")
                    checked: AdBlocker.parental
                    disabled: AdBlocker.busy
                    onToggled: AdBlocker.setSafety("parental", checked)
                }

                SectionHeader {
                    text: Tr.tr("Blocked apps & services")
                }

                ConnectedRect {
                    standalone: true
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacing.small
                    implicitHeight: svcCol.implicitHeight + Tokens.padding.medium * 2

                    ColumnLayout {
                        id: svcCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.medium

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledTextField {
                                Layout.fillWidth: true
                                placeholderText: Tr.tr("Filter services (e.g. TikTok, YouTube, Steam)…")
                                leadingIcon: "search"
                                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                                onTextChanged: root.serviceSearch = text
                            }

                            TextButton {
                                visible: (AdBlocker.availableServices ?? []).length > 18 && root.serviceSearch.trim().length === 0
                                text: root.showAllServices ? Tr.tr("Popular") : Tr.tr("All (%1)").arg(AdBlocker.availableServices.length)
                                type: TextButton.Tonal
                                onClicked: root.showAllServices = !root.showAllServices
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: root._filteredAvailableServices

                                TextButton {
                                    required property var modelData
                                    readonly property bool isBlocked: AdBlocker.blockedServices.includes(modelData.id)

                                    text: modelData.name
                                    isToggle: true
                                    followChecked: true
                                    checked: isBlocked
                                    type: TextButton.Tonal
                                    disabled: AdBlocker.busy
                                    onClicked: AdBlocker.toggleBlockedService(modelData.id)
                                }
                            }
                        }
                    }
                }

                SectionHeader {
                    text: Tr.tr("Encrypted upstream DNS")
                }

                SelectRow {
                    id: dnsPresetRow

                    label: Tr.tr("Upstream DNS provider")
                    subtext: {
                        const cur = root.customDnsSelected ? "custom" : root._matchingDnsPreset();
                        const preset = AdBlocker.dnsPresets.find(p => p.id === cur);
                        return preset ? preset.subtext : ((AdBlocker.upstreamDns ?? []).join(", ") || Tr.tr("Custom DoH / DoT / DoQ servers"));
                    }
                    segmentedAllowed: false
                    menuItems: [dnsCloudflareQuad9, dnsCloudflare, dnsQuad9, dnsMullvad, dnsAdGuard, dnsCustom]
                    active: {
                        const cur = root.customDnsSelected ? "custom" : root._matchingDnsPreset();
                        const map = {
                            "cloudflare-quad9": dnsCloudflareQuad9,
                            "cloudflare": dnsCloudflare,
                            "quad9": dnsQuad9,
                            "mullvad": dnsMullvad,
                            "adguard": dnsAdGuard,
                            "custom": dnsCustom
                        };
                        return map[cur] ?? dnsCustom;
                    }
                    onSelected: item => {
                        const v = String(item.value);
                        if (v === "custom") {
                            root.customDnsSelected = true;
                            customUpstreamField.text = (AdBlocker.upstreamDns ?? []).join(", ");
                        } else {
                            root.customDnsSelected = false;
                            const preset = AdBlocker.dnsPresets.find(p => p.id === v);
                            if (preset)
                                AdBlocker.setDns(preset.servers, AdBlocker.dnssecEnabled, AdBlocker.blockingMode);
                        }
                    }

                    MenuItem {
                        id: dnsCloudflareQuad9

                        text: Tr.tr("Cloudflare + Quad9 (DoH)")
                        value: "cloudflare-quad9"
                    }

                    MenuItem {
                        id: dnsCloudflare

                        text: Tr.tr("Cloudflare (DoH)")
                        value: "cloudflare"
                    }

                    MenuItem {
                        id: dnsQuad9

                        text: Tr.tr("Quad9 Security (DoH)")
                        value: "quad9"
                    }

                    MenuItem {
                        id: dnsMullvad

                        text: Tr.tr("Mullvad Privacy (DoH)")
                        value: "mullvad"
                    }

                    MenuItem {
                        id: dnsAdGuard

                        text: Tr.tr("AdGuard DNS Unfiltered (DoH)")
                        value: "adguard"
                    }

                    MenuItem {
                        id: dnsCustom

                        text: Tr.tr("Custom servers")
                        value: "custom"
                    }
                }

                ConnectedRect {
                    visible: root.customDnsSelected
                    Layout.fillWidth: true
                    implicitHeight: customDnsCol.implicitHeight + Tokens.padding.medium * 2

                    ColumnLayout {
                        id: customDnsCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.small

                        StyledTextField {
                            id: customUpstreamField

                            Layout.fillWidth: true
                            text: (AdBlocker.upstreamDns ?? []).join(", ")
                            placeholderText: Tr.tr("https://..., tls://..., quic://... (comma or newline separated)")
                            leadingIcon: "dns"
                            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: Tr.tr("Supports DoH (https://), DoT (tls://), DoQ (quic://), or IP addresses.")
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                wrapMode: Text.WordWrap
                            }

                            TextButton {
                                text: Tr.trCtx("Save", "button")
                                type: TextButton.Filled
                                disabled: AdBlocker.busy || customUpstreamField.text.trim().length === 0
                                onClicked: {
                                    const list = customUpstreamField.text.split(/[\n,]+/).map(s => s.trim()).filter(s => s.length > 0);
                                    if (list.length > 0)
                                        AdBlocker.setDns(list, AdBlocker.dnssecEnabled, AdBlocker.blockingMode);
                                }
                            }
                        }
                    }
                }

                ToggleRow {
                    text: Tr.tr("DNSSEC validation")
                    subtext: Tr.tr("Verify cryptographic signatures on supported domains")
                    checked: AdBlocker.dnssecEnabled
                    disabled: AdBlocker.busy
                    onToggled: AdBlocker.setDns(AdBlocker.upstreamDns, checked, AdBlocker.blockingMode)
                }

                SelectRow {
                    label: Tr.tr("Blocking response mode")
                    subtext: Tr.tr("How blocked domains answer DNS lookups")
                    segmentedAllowed: false
                    menuItems: [modeDefault, modeNxdomain, modeNullIp]
                    active: AdBlocker.blockingMode === "nxdomain" ? modeNxdomain : AdBlocker.blockingMode === "null_ip" ? modeNullIp : modeDefault
                    onSelected: item => AdBlocker.setDns(AdBlocker.upstreamDns, AdBlocker.dnssecEnabled, String(item.value))

                    MenuItem {
                        id: modeDefault

                        text: Tr.tr("Default (0.0.0.0 / ::)")
                        value: "default"
                    }

                    MenuItem {
                        id: modeNxdomain

                        text: Tr.tr("NXDOMAIN (non-existent domain)")
                        value: "nxdomain"
                    }

                    MenuItem {
                        id: modeNullIp

                        text: Tr.tr("Null IP (0.0.0.0)")
                        value: "null_ip"
                    }
                }
            }
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }
    }
}

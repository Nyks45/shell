pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.I18n
import qs.utils

Singleton {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-adblock`

    property bool loaded: false
    property bool installed: false
    property bool configured: false
    property bool serviceActive: false
    property bool dnsRouted: false
    property bool protectionEnabled: false
    property int pauseRemainingSec: 0
    property string version: ""
    property bool warpActive: false

    readonly property bool paused: configured && serviceActive && dnsRouted && !protectionEnabled && pauseRemainingSec > 0
    readonly property bool active: configured && serviceActive && dnsRouted && protectionEnabled

    property var stats: ({
            numDnsQueries: 0,
            numBlockedFiltering: 0,
            blockedPercent: 0,
            avgProcessingMs: 0,
            numReplacedSafebrowsing: 0,
            numReplacedParental: 0,
            topBlockedDomains: [],
            topQueriedDomains: [],
            dnsQueriesSeries: [],
            blockedSeries: []
        })
    property var filters: []
    property var userRules: []
    property var queryLog: []
    property bool safeBrowsing: false
    property bool safeSearch: false
    property bool parental: false
    property var blockedServices: []
    property var availableServices: []
    property var upstreamDns: []
    property var bootstrapDns: ["1.1.1.1", "9.9.9.9"]
    property bool dnssecEnabled: true
    property string blockingMode: "default"

    property bool refreshingFilters: false
    property bool loadingLog: false
    property string lastError: ""
    property var _actionQueue: []
    property bool _actionRunning: false
    readonly property bool busy: _actionRunning || Admin.busy

    readonly property int totalEnabledRules: {
        let sum = userRules.length;
        for (const f of filters) {
            if (f.enabled)
                sum += (f.rulesCount || 0);
        }
        return sum;
    }

    readonly property var curatedFilters: [
        {
            name: "AdGuard DNS filter",
            description: Tr.mark("Balanced default blocking for ads, trackers and analytics"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
        },
        {
            name: "HaGeZi's Normal Blocklist",
            description: Tr.mark("All-round protection without breaking common sites"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_34.txt"
        },
        {
            name: "HaGeZi's Pro Blocklist",
            description: Tr.mark("Stricter ad, tracking, metrics and telemetry blocking"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_48.txt"
        },
        {
            name: "OISD Blocklist Big",
            description: Tr.mark("Broad curated list tuned to avoid false positives"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_27.txt"
        },
        {
            name: "OISD Blocklist Small",
            description: Tr.mark("Lightweight list for minimal memory and rule count"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_5.txt"
        },
        {
            name: "Steven Black's List",
            description: Tr.mark("Classic unified hosts list for adware and malware"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt"
        },
        {
            name: "Peter Lowe's Blocklist",
            description: Tr.mark("Compact, high-confidence ad and tracking hostnames"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt"
        },
        {
            name: "HaGeZi's Threat Intelligence Feeds",
            description: Tr.mark("Malware, cryptojacking, phishing, scam and spam domains"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_44.txt"
        },
        {
            name: "AdGuard DNS Popup Hosts filter",
            description: Tr.mark("Blocks popup ads, popunders and shady ad networks"),
            url: "https://adguardteam.github.io/HostlistsRegistry/assets/filter_59.txt"
        }
    ]

    readonly property var dnsPresets: [
        {
            id: "cloudflare-quad9",
            label: Tr.mark("Cloudflare + Quad9 (DoH)"),
            subtext: "https://dns.cloudflare.com/dns-query, https://dns.quad9.net/dns-query",
            servers: ["https://dns.cloudflare.com/dns-query", "https://dns.quad9.net/dns-query"]
        },
        {
            id: "cloudflare",
            label: Tr.mark("Cloudflare (DoH)"),
            subtext: "https://dns.cloudflare.com/dns-query",
            servers: ["https://dns.cloudflare.com/dns-query"]
        },
        {
            id: "quad9",
            label: Tr.mark("Quad9 Security (DoH)"),
            subtext: "https://dns.quad9.net/dns-query",
            servers: ["https://dns.quad9.net/dns-query"]
        },
        {
            id: "mullvad",
            label: Tr.mark("Mullvad Privacy (DoH)"),
            subtext: "https://dns.mullvad.net/dns-query",
            servers: ["https://dns.mullvad.net/dns-query"]
        },
        {
            id: "adguard",
            label: Tr.mark("AdGuard DNS Unfiltered (DoH)"),
            subtext: "https://unfiltered.adguard-dns.com/dns-query",
            servers: ["https://unfiltered.adguard-dns.com/dns-query"]
        }
    ]

    function applyStatus(data: var): void {
        if (!data || typeof data !== "object")
            return;
        loaded = true;
        installed = !!data.installed;
        configured = !!data.configured;
        serviceActive = !!data.serviceActive;
        dnsRouted = !!data.dnsRouted;
        protectionEnabled = !!data.protectionEnabled;
        const remMs = Number(data.pauseRemainingMs || 0);
        pauseRemainingSec = (!protectionEnabled && remMs > 0) ? Math.max(1, Math.ceil(remMs / 1000)) : 0;
        version = String(data.version || "");
        warpActive = !!data.warpActive;
        if (data.stats)
            stats = data.stats;
        filters = data.filters ?? [];
        userRules = data.userRules ?? [];
        safeBrowsing = !!data.safeBrowsing;
        safeSearch = !!data.safeSearch;
        parental = !!data.parental;
        blockedServices = data.blockedServices ?? [];
        if (data.availableServices && data.availableServices.length > 0)
            availableServices = data.availableServices;
        upstreamDns = data.upstreamDns ?? [];
        if (data.bootstrapDns && data.bootstrapDns.length > 0)
            bootstrapDns = data.bootstrapDns;
        dnssecEnabled = !!data.dnssecEnabled;
        blockingMode = String(data.blockingMode || "default");
        lastError = "";
    }

    function refresh(): void {
        if (statusProc.running)
            return;
        statusProc.outText = "";
        statusProc.errText = "";
        statusProc.exitCode = 0;
        statusProc.pending = 3;
        statusProc.running = true;
    }

    function refreshQueryLog(search = "", filterMode = "all", limit = 120): void {
        loadingLog = true;
        logProc.running = false;
        logProc.outText = "";
        logProc.errText = "";
        logProc.pending = 3;
        logProc.command = [helper, "querylog", "--search", search || "", "--filter", filterMode || "all", "--limit", String(limit)];
        logProc.running = true;
    }

    function _enqueue(args: list<string>, stdinData = "", onDone = null, toastTitle = "", toastBody = ""): void {
        _actionQueue = [..._actionQueue, {
                args,
                stdinData,
                onDone,
                toastTitle,
                toastBody
            }];
        _pumpQueue();
    }

    function _pumpQueue(): void {
        if (_actionRunning || _actionQueue.length === 0)
            return;
        const item = _actionQueue[0];
        _actionQueue = _actionQueue.slice(1);
        _actionRunning = true;
        actionProc.currentItem = item;
        actionProc.outText = "";
        actionProc.errText = "";
        actionProc.exitCode = -1;
        actionProc.pending = 3;
        actionProc.stdinData = item.stdinData || "";
        actionProc.stdinEnabled = actionProc.stdinData.length > 0;
        actionProc.command = [helper, ...item.args];
        actionProc.running = true;
    }

    function installAndSetup(): void {
        if (installed) {
            setup();
            return;
        }
        Packages.install({
            source: "repo",
            name: "adguardhome"
        }, ok => {
            if (ok)
                setup();
            else
                refresh();
        });
    }

    function setup(): void {
        Admin.run("adblock-setup", [], Tr.tr("Set up system-wide ad blocker"), ok => {
            refresh();
            if (ok)
                Toaster.toast(Tr.tr("Ad blocker active"), Tr.tr("System DNS is now filtered by AdGuard Home"), "shield");
        });
    }

    function setEnabled(on: bool): void {
        if (on) {
            if (!configured) {
                setup();
                return;
            }
            if (!serviceActive || !dnsRouted) {
                Admin.run("adblock-routing", ["on"], Tr.tr("Turn on ad blocker"), ok => {
                    if (ok && !protectionEnabled)
                        _enqueue(["protection", "on"], "", () => refresh());
                    else
                        refresh();
                });
            } else {
                _enqueue(["protection", "on"], "", null, Tr.tr("Ad blocker resumed"), Tr.tr("Blocking ads and trackers"));
            }
        } else {
            Admin.run("adblock-routing", ["off"], Tr.tr("Turn off ad blocker"), () => refresh());
        }
    }

    function pauseFor(minutes: int): void {
        if (minutes <= 0) {
            resumeProtection();
            return;
        }
        const ms = minutes * 60 * 1000;
        const doPause = () => _enqueue(["protection", "off", String(ms)], "", null, Tr.tr("Ad blocker paused"), Tr.trN("Resumes automatically in %n minute", "Resumes automatically in %n minutes", minutes));
        if (!dnsRouted)
            Admin.run("adblock-routing", ["on"], Tr.tr("Enable DNS routing"), ok => {
                if (ok)
                    doPause();
            });
        else
            doPause();
    }

    function resumeProtection(): void {
        if (!dnsRouted)
            setEnabled(true);
        else
            _enqueue(["protection", "on"], "", null, Tr.tr("Ad blocker resumed"), Tr.tr("Blocking ads and trackers"));
    }

    function toggleFilter(flt: var, enabled: bool): void {
        _enqueue(["filter-toggle", flt.url, flt.name || flt.url, enabled ? "on" : "off"]);
    }

    function addFilter(url: string, name: string, onDone = null): void {
        _enqueue(["filter-add", url.trim(), (name || url).trim()], "", onDone, Tr.tr("Filter list added"), name || url);
    }

    function removeFilter(url: string): void {
        _enqueue(["filter-remove", url]);
    }

    function refreshFilters(): void {
        if (refreshingFilters)
            return;
        refreshingFilters = true;
        _enqueue(["filter-refresh"], "", ok => {
            refreshingFilters = false;
            if (ok)
                Toaster.toast(Tr.tr("Filter lists updated"), Tr.tr("Downloaded the latest blocklist rules"), "sync");
        });
    }

    function setUserRules(rules: var): void {
        _enqueue(["rules-set"], JSON.stringify({
            rules: rules
        }));
    }

    function addCustomRule(rule: string): void {
        const clean = rule.trim();
        if (!clean || userRules.includes(clean))
            return;
        setUserRules([...userRules, clean]);
    }

    function removeCustomRule(index: int): void {
        if (index < 0 || index >= userRules.length)
            return;
        setUserRules(userRules.filter((_, i) => i !== index));
    }

    function quickBlock(domain: string, onDone = null): void {
        _enqueue(["quick-rule", "block", domain], "", onDone, Tr.tr("Domain blocked"), domain);
    }

    function quickAllow(domain: string, onDone = null): void {
        _enqueue(["quick-rule", "allow", domain], "", onDone, Tr.tr("Domain allowed"), domain);
    }

    function quickClearRule(domain: string, onDone = null): void {
        _enqueue(["quick-rule", "clear", domain], "", onDone);
    }

    function setSafety(kind: string, enabled: bool): void {
        _enqueue(["safety", kind, enabled ? "on" : "off"]);
    }

    function toggleBlockedService(serviceId: string): void {
        const has = blockedServices.includes(serviceId);
        const next = has ? blockedServices.filter(s => s !== serviceId) : [...blockedServices, serviceId];
        setBlockedServices(next);
    }

    function setBlockedServices(ids: var): void {
        _enqueue(["blocked-services-set"], JSON.stringify({
            ids: ids
        }));
    }

    function setDns(servers: var, dnssec: bool, mode: string, onDone = null): void {
        _enqueue(["dns-set"], JSON.stringify({
            upstream_dns: servers,
            bootstrap_dns: bootstrapDns,
            dnssec_enabled: dnssec,
            blocking_mode: mode
        }), onDone, Tr.tr("DNS settings saved"), servers.join(", "));
    }

    function resetStats(): void {
        _enqueue(["stats-reset"], "", null, Tr.tr("Statistics cleared"), Tr.tr("DNS query counters were reset"));
    }

    function clearQueryLog(): void {
        _enqueue(["querylog-clear"], "", () => {
            queryLog = [];
        }, Tr.tr("Query log cleared"), "");
    }

    function formatPauseCountdown(secs: int): string {
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        const pad = n => n < 10 ? `0${n}` : String(n);
        return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
    }

    function formatCompactCount(n: int): string {
        if (n >= 1000000)
            return `${(n / 1000000).toFixed(1)}M`;
        if (n >= 1000)
            return `${(n / 1000).toFixed(n >= 10000 ? 0 : 1)}k`;
        return String(n);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 1000
        repeat: true
        running: root.pauseRemainingSec > 0
        onTriggered: {
            if (root.pauseRemainingSec > 1) {
                root.pauseRemainingSec--;
            } else {
                root.pauseRemainingSec = 0;
                root.refresh();
            }
        }
    }

    Process {
        id: statusProc

        property string outText: ""
        property string errText: ""
        property int exitCode: 0
        property int pending: 0

        function settle(): void {
            if (--pending > 0)
                return;
            if (exitCode === 0 && outText.trim().length > 0) {
                try {
                    root.applyStatus(JSON.parse(outText));
                } catch (e) {
                    root.lastError = String(e);
                    root.loaded = true;
                }
            } else if (errText.trim().length > 0) {
                root.lastError = errText.trim();
                root.loaded = true;
            }
        }

        command: [root.helper, "status"]
        onExited: code => {
            exitCode = code;
            settle();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                statusProc.outText = text;
                statusProc.settle();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                statusProc.errText = text;
                statusProc.settle();
            }
        }
    }

    Process {
        id: logProc

        property string outText: ""
        property string errText: ""
        property int exitCode: 0
        property int pending: 0

        function settle(): void {
            if (--pending > 0)
                return;
            root.loadingLog = false;
            if (exitCode === 0 && outText.trim().length > 0) {
                try {
                    const data = JSON.parse(outText);
                    root.queryLog = data.items ?? [];
                } catch (e) {}
            }
        }

        onExited: code => {
            exitCode = code;
            settle();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                logProc.outText = text;
                logProc.settle();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                logProc.errText = text;
                logProc.settle();
            }
        }
    }

    Process {
        id: actionProc

        property var currentItem: null
        property string outText: ""
        property string errText: ""
        property string stdinData: ""
        property int exitCode: -1
        property int pending: 0

        function settle(): void {
            if (--pending > 0)
                return;
            const item = currentItem;
            currentItem = null;
            root._actionRunning = false;
            const ok = exitCode === 0;
            if (ok && outText.trim().length > 0) {
                try {
                    const parsed = JSON.parse(outText);
                    if (parsed.filters !== undefined || parsed.protectionEnabled !== undefined)
                        root.applyStatus(parsed);
                } catch (e) {}
            } else if (!ok) {
                const msg = errText.trim() || Tr.tr("Ad blocker command failed");
                root.lastError = msg;
                Toaster.toast(Tr.tr("Ad blocker error"), msg, "error");
            }
            if (ok && item && item.toastTitle)
                Toaster.toast(item.toastTitle, item.toastBody || "", "shield");
            if (item && typeof item.onDone === "function")
                item.onDone(ok);
            root._pumpQueue();
        }

        onStarted: {
            if (stdinData.length > 0) {
                write(stdinData + "\n");
                stdinData = "";
                stdinEnabled = false;
            }
        }
        onExited: code => {
            exitCode = code;
            settle();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                actionProc.outText = text;
                actionProc.settle();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                actionProc.errText = text;
                actionProc.settle();
            }
        }
    }
}

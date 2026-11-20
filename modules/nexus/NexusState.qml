import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    property ShellScreen screen
    property bool isWindow
    property bool animatingContainer
    property int currentPageIdx
    property list<int> subPageIdxStack
    property bool searchOpen
    property string searchText
    // Cross-page navigation history
    property var history: [{
        page: 0,
        path: []
    }]
    property int historyIdx: 0
    property bool _navigatingHistory: false
    property bool _inGoTo: false
    readonly property bool canGoBack: subPageIdxStack.length > 0 || historyIdx > 0
    readonly property bool canGoForward: historyIdx < history.length - 1
    // A setting picked from the search: the page at depth `depth` of the open
    // page scrolls to the row labelled `text` (in `section`) and flashes it
    property var highlight: null

    property string selectedWallpaperCategory
    property BluetoothDevice selectedBtDevice
    property DesktopEntry selectedApp
    property var selectedLiveWallpaper
    property int editingVpnIndex: -1
    property string selectedNetworkSsid
    property string selectedEthernetInterface
    // Disks & drives: the drive and partition (udisks object paths) being looked at
    property string selectedDrive
    property string selectedPartition
    // Backups: the snapshot being looked at
    property int selectedSnapshot
    property string selectedSnapperConfig
    // System services: the unit being looked at (and whether it's the user's)
    property string selectedUnit
    property bool selectedUnitUser
    // Logs: open them filtered to this unit (set by a service's page)
    property string logUnit
    // Account: the other person's account being looked at
    property string selectedUser
    // Settings › Apps: the package a page shows ({ source, name, title })
    property var selectedPackage: null
    // Settings › Gaming: the game a page shows (a Games key, "steam:1086940")
    property string selectedGame
    property bool networkDetailsFromSaved

    signal close
    signal subPageOpened(idx: int)
    signal subPageClosed
    signal highlightRequested

    function _pushHistory(page: int, path: var): void {
        if (_navigatingHistory)
            return;
        const p = Array.from(path ?? []);
        const cur = history[historyIdx];
        if (cur && cur.page === page && cur.path.length === p.length && cur.path.every((v, i) => v === p[i]))
            return;
        const next = history.slice(0, historyIdx + 1);
        next.push({
            page,
            path: p
        });
        if (next.length > 40)
            next.shift();
        history = next;
        historyIdx = next.length - 1;
    }

    function _applyHistory(entry: var): void {
        _navigatingHistory = true;
        backHandler = null;
        searchOpen = false;
        const p = (entry.path ?? []).slice();
        if (currentPageIdx !== entry.page) {
            currentPageIdx = entry.page;
            subPageIdxStack = p;
        } else {
            let common = 0;
            while (common < p.length && common < subPageIdxStack.length && p[common] === subPageIdxStack[common])
                common++;
            while (subPageIdxStack.length > common)
                closeSubPage();
            for (const idx of p.slice(common))
                openSubPage(idx);
        }
        _navigatingHistory = false;
    }

    function startAt(entry: var): void {
        history = [{
            page: entry.page,
            path: (entry.path ?? []).slice()
        }];
        historyIdx = 0;
        _navigatingHistory = true;
        goTo(entry);
        _navigatingHistory = false;
    }

    function openSubPage(idx: int): void {
        subPageIdxStack.push(idx);
        subPageOpened(idx);
        if (!_navigatingHistory && !_inGoTo)
            _pushHistory(currentPageIdx, subPageIdxStack);
    }

    // A page with steps of its own (e.g. the Workshop's item details) handles
    // "back" itself first: a function returning true when it did
    property var backHandler: null

    // The mouse's back button and header back button: step back through history
    function back(): void {
        if (backHandler && backHandler())
            return;
        if (searchOpen) {
            searchOpen = false;
            return;
        }
        if (historyIdx > 0) {
            historyIdx--;
            _applyHistory(history[historyIdx]);
            return;
        }
        if (subPageIdxStack.length > 0)
            closeSubPage();
    }

    function forward(): void {
        if (historyIdx < history.length - 1) {
            historyIdx++;
            _applyHistory(history[historyIdx]);
        }
    }

    function closeSubPage(): void {
        backHandler = null;
        subPageClosed();
        subPageIdxStack.pop();
    }

    // Open a search result: a page (entry.path empty, no label) or a setting
    // (SearchIndex entry: page, sub-page path, label)
    function goTo(entry: var): void {
        const path = entry.path ?? [];
        // A tab of a page (a former page id): the page's tabs pick it up (PartTabs)
        if (entry.tab) {
            PageRegistry.pendingTab = entry.tab;
            PageRegistry.pendingTabAt = Date.now();
        }
        highlight = entry.text ? {
            text: entry.text,
            section: entry.sectionText ?? "",
            depth: path.length
        } : null;

        _inGoTo = true;
        if (currentPageIdx !== entry.page) {
            currentPageIdx = entry.page; // clears the sub-page stack
            subPageIdxStack = path.slice(); // the page opens them as it loads
        } else {
            // Same page: close sub-pages down to the shared part of the path, open the rest
            let common = 0;
            while (common < path.length && common < subPageIdxStack.length && path[common] === subPageIdxStack[common])
                common++;
            while (subPageIdxStack.length > common)
                closeSubPage();
            for (const idx of path.slice(common))
                openSubPage(idx);
            highlightRequested();
        }
        _inGoTo = false;
        if (!_navigatingHistory)
            _pushHistory(entry.page, path);
    }

    onCurrentPageIdxChanged: {
        subPageIdxStack.length = 0;
        if (!_navigatingHistory && !_inGoTo)
            _pushHistory(currentPageIdx, []);
    }
}

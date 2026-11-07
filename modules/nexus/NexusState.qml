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
    property bool networkDetailsFromSaved

    signal close
    signal subPageOpened(idx: int)
    signal subPageClosed
    signal highlightRequested

    function openSubPage(idx: int): void {
        subPageIdxStack.push(idx);
        subPageOpened(idx);
    }

    // A page with steps of its own (e.g. the Workshop's item details) handles
    // "back" itself first: a function returning true when it did
    property var backHandler: null

    // The mouse's back button and the header's back arrow: a step back
    function back(): void {
        if (backHandler && backHandler())
            return;
        if (subPageIdxStack.length > 0)
            closeSubPage();
        else if (searchOpen)
            searchOpen = false;
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
        highlight = entry.text ? {
            text: entry.text,
            section: entry.sectionText ?? "",
            depth: path.length
        } : null;

        if (currentPageIdx !== entry.page) {
            currentPageIdx = entry.page; // clears the sub-page stack
            subPageIdxStack = path.slice(); // the page opens them as it loads
            return;
        }

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

    onCurrentPageIdxChanged: subPageIdxStack.length = 0
}

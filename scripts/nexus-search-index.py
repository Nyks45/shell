#!/usr/bin/env python3
"""Builds modules/nexus/SearchIndex.qml: every setting row of the settings app
(Nexus), so its search can find a setting and open the page it is on.

Run it after changing a page (the index is generated, not hand-edited):

    scripts/nexus-search-index.py

How it reads the pages: PageCompRegistry.qml says which page component is at
which page index and sub-page index; each page's openSubPage(N) calls say which
sub-page opens from which page (so Panels > Taskbar > Workspaces is the path
[1, 6]); the rows' Tr.tr() labels (label:, text:, subtext:) and the section
headers above them give the entries. Rows built from data (Repeaters) have no
literal label and are left out; so are sub-pages that need something selected
first (a network, a device, an app).
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NEXUS = ROOT / "modules/nexus"
OUT = NEXUS / "SearchIndex.qml"

ROW_TYPES = {
    "ToggleRow", "SliderRow", "StepperRow", "SelectRow", "TextFieldRow", "FolderPickerRow", "RowButton", "NavRow", "PopupRow",
    "DialogRowButton", "DialogSelectButton", "InfoRow", "SwitchRow", "ColourRow",
}
# Sub-pages that only make sense with something picked first
NEEDS_SELECTION = {
    "EthernetDetailPage", "NetworkDetailPage", "AddVpnPage", "BtDeviceInfo", "AppInfo", "WallpaperCategory",
    "LiveWallpaperInfo", "DiskPartitionPage", "DiskHealthPage", "SnapshotPage", "ServicePage", "UserPage",
    "PackagePage", "GamePage",
}
# Extra words people search for, by label
SYNONYMS = {
    "Live wallpapers": "animated moving video wallpaper engine background",
    "Dark theme": "dark mode light mode night",
    "Theme": "dark mode light mode dark theme night",
    "Natural scrolling": "reverse scroll direction",
    "Pointer speed": "mouse sensitivity dpi",
    "Scale": "zoom size hidpi",
    "Night light": "blue light warm redshift",
    "Variable refresh rate": "vrr freesync gsync adaptive sync",
    "Resolution": "screen size",
    "Corner rounding": "radius rounded corners",
    "Blur": "frosted glass transparency",
    "Window opacity": "transparency transparent",
    "Lock the screen after": "screen lock timeout idle",
    "Turn off the screen after": "dpms monitor off blank",
    "Sleep after": "suspend",
    "Power mode": "performance power saver profile",
    "Layout": "keyboard language",
    "Brightness": "backlight dim",
    "Time zone": "timezone clock city utc",
    "Save folder": "screenshot folder directory path",
    "Wallpaper folder": "wallpapers directory path",
    "Add an app rule": "window rules class floating",
    "Clock format": "12 24 hour am pm",
    "Do not disturb": "dnd silence mute notifications",
    "Frame rate": "fps live wallpaper",
    "Copy to the clipboard": "screenshot clipboard",
    "Test which wallpapers work": "compatibility live wallpaper engine",
    "Add someone": "add user new user create account",
    "Change password": "passwd keyring login unlock",
    "Empty the Trash": "delete bin clean up",
    "Remove unused packages": "orphans pacman cleanup",
    "Other apps' volume": "app volumes mixer per-app audio",
    "Update frequency": "polling refresh interval stats",
    "GPU monitoring": "gpu type nvidia override",
    "Shell style": "compact pill full classic bar",
    "Visualiser bars": "spectrum analyser bars",
    "Volume step": "audio increment scroll",
    "Brightness step": "backlight increment scroll",
    "Max volume": "volume limit boost",
    "Lyrics source": "lyrics backend lrclib netease",
    "Default media player": "mpris media player auto",
}

EXCLUDE_LABELS = {"Unknown program", "Copy these lines", "Boot", "Name", "Add", "Save", "Cancel"}
EXCLUDE_SECTIONS = {"Add a game", "Entries"}

# List-built / dynamic rows and key tabs that Repeaters don't statically declare:
# (page id, tab, subtext, label, keywords, section). The label and section are
# the row's real text and the section header above it (the search highlights
# the row by them; section "" = anywhere on the page, e.g. a tab's own button).
# One that matches a generated entry only adds its keywords to it.
EXTRA_ENTRIES = [
    # Wallpaper & style / Windows tabs (their tab buttons)
    ("wallpaper", "colours", "Wallpaper & style", "Colours", "colour scheme dark light theme palette accent dynamic", ""),
    ("wallpaper", "effects", "Wallpaper & style", "Effects", "transparency opacity roundness blur frosted glass", ""),
    ("wallpaper", "desktop", "Wallpaper & style", "Desktop", "desktop icons widgets audio visualiser bars", ""),
    ("wallpaper", "lockscreen", "Wallpaper & style", "Lock screen", "lockscreen wallpaper logo notifications power buttons fingerprint face howdy", ""),
    ("windows", "titlebars", "Windows", "Title bars", "window title bar font blur buttons hover double middle click", "Title bars"),
    ("windows", "apprules", "Windows", "App rules", "window rules float centre pin workspace opacity tearing", ""),
    # Workspaces & shortcuts -> Shortcuts (rows built from the key variables)
    ("workspaces", "shortcuts", "Shortcuts", "Close window", "Super+Q window close kill shortcut", "Windows"),
    ("workspaces", "shortcuts", "Shortcuts", "Terminal", "terminal foot kitty alacritty open shortcut", "Apps"),
    ("workspaces", "shortcuts", "Shortcuts", "Launcher", "app launcher dmenu rofi shortcut", "Desktop & shell"),
    ("workspaces", "shortcuts", "Shortcuts", "Lock", "lock screen session shortcut", "Desktop & shell"),
    ("workspaces", "shortcuts", "Shortcuts", "Screenshot", "screenshot capture snip print shortcut", "Screenshots & media"),
    ("workspaces", "shortcuts", "Shortcuts", "Next workspace", "switch workspace focus move shortcut", "Workspaces"),
    ("workspaces", "shortcuts", "Shortcuts", "Add a shortcut", "custom keyboard shortcuts hotkey keybind bind", "Your own shortcuts"),
    # Gaming tabs & generated options
    ("gaming", "gamemode", "Gaming", "Game mode", "gamemode performance cpu governor", "Game mode"),
    ("gaming", "gpu", "Gaming", "NVIDIA Reflex", "reflex low latency nvidia game options", "NVIDIA"),
    ("gaming", "gpu", "Gaming", "Newest DLSS", "dlss frame generation upscaling nvidia", "NVIDIA"),
    ("gaming", "gpu", "Gaming", "HDR", "hdr in games dxvk gamescope", "Proton"),
    ("gaming", "gpu", "Gaming", "NTSync", "ntsync fsync esync wine proton", "Proton"),
    ("gaming", "gpu", "Gaming", "Sharpening strength", "fsr gamescope upscaling sharp", "Game options"),
    ("gaming", "gpu", "Gaming", "Graphics", "graphics card gpu nvidia power limit clocks", ""),
    ("gaming", "overlay", "Gaming", "Overlay", "mangohud fps overlay hud metrics", ""),
    ("gaming", "proton", "Gaming", "Compatibility", "proton versions ge-proton wine compatibility", ""),
    # Recovery & boot (the boot menu itself: the page's own keywords)
    ("recovery", "", "Recovery & boot", "Quiet start", "boot kernel quiet refind", "Linux start options"),
    ("recovery", "", "Recovery & boot", "Splash screen", "plymouth boot splash animation", "Linux start options"),
    ("recovery", "", "Recovery & boot", "Starts by default", "default boot os windows cachyos", "Starting"),
    ("recovery", "", "Recovery & boot", "Secure Boot", "sbctl uefi keys signed", "Firmware"),
    ("recovery", "", "Recovery & boot", "UEFI boot order", "efibootmgr boot priority", "Firmware"),
    ("recovery", "", "Recovery & boot", "Restore previous boot menu", "boot backup undo refind", "Linux start options"),
    # Advanced tabs (their tab buttons) & dynamic service rows
    ("advanced", "systemd", "Advanced", "Services", "system services systemd service unit daemon start stop", ""),
    ("advanced", "systemd", "Advanced", "Scheduled tasks", "systemd timer timers cron schedule", ""),
    ("advanced", "logs", "Advanced", "Logs", "system logs journalctl log error warnings crash coredump", ""),
    ("advanced", "kernels", "Advanced", "Kernels", "linux kernel cachyos lts headers", ""),
    ("advanced", "scheduler", "Advanced", "The kernel's own (EEVDF)", "cpu scheduler scx sched-ext scx_lavd bpfland ananicy gaming", "CPU scheduler"),
    ("advanced", "plugins", "Advanced", "Hyprland plugins", "hyprpm plugin hyprflow hyprscroller", ""),
    # Storage & Account
    ("storage", "backups", "Storage", "Snapshots", "backup backups snapper btrfs restore", ""),
    ("storage", "backups", "Storage", "Home folder isn't included in system snapshots", "home folder snapshots partition backup snapper", "Home folder"),
    ("account", "", "Asks for your password when you save", "Full name", "real name display name profile", "Profile"),
    ("account", "", "How it shows up on networks and Bluetooth", "Computer name", "hostname device name pc name", "This computer"),
    ("account", "", "Account", "Hardware and system groups", "groups permissions access audio video input storage network", "Your access"),
]

TR = re.compile(r'Tr\.(tr|trCtx)\("((?:[^"\\]|\\.)*)"(?:\s*,\s*"((?:[^"\\]|\\.)*)")?')
PROP = re.compile(r'^\s*(label|text|subtext|title)\s*:\s*(.*)$')
OPEN = re.compile(r'^\s*([A-Z][A-Za-z0-9_.]*)\s*\{')
SUB = re.compile(r'openSubPage\((\d+)\)')
# A page embedded in a merged one: `FooPage {` followed by `embedded: true`
EMBEDDED = re.compile(r'^\s*([A-Z][A-Za-z0-9_]*)\s*\{\s*\n(?:\s*[A-Za-z.]+:.*\n)*?\s*embedded:\s*true', re.M)


def strip_comment(line: str) -> str:
    """The line without a // comment (one outside a string)."""
    quote = None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'`":
            quote = c
        elif line.startswith("//", i):
            return line[:i]
        i += 1
    return line


def tr_of(expr: str):
    """The first literal Tr.tr/Tr.trCtx string in an expression (source text, context)."""
    m = TR.search(expr)
    if not m:
        return None
    text = json.loads(f'"{m.group(2)}"')
    if "%" in text:
        return None
    return text, (json.loads(f'"{m.group(3)}"') if m.group(3) else "")


def registry():
    """[(page index, [component name per sub-page index])] from PageCompRegistry.qml."""
    src = (NEXUS / "PageCompRegistry.qml").read_text()
    body = src[src.index("specs:"):src.index("stackPageComp")]
    pages = []
    depth = 0
    for line in body.splitlines():
        stripped = strip_comment(line)
        for c in stripped:
            if c == "[":
                depth += 1
                if depth == 2:
                    pages.append([])
            elif c == "]":
                depth -= 1
        for m in re.finditer(r'"([^"]+\.qml)"', stripped):
            pages[-1].append(Path(m.group(1)).stem)
    return pages


def page_ids():
    """{page id: page index} from PageRegistry.qml."""
    src = (NEXUS / "PageRegistry.qml").read_text()
    ids = {}
    for idx, m in enumerate(re.finditer(r'\bid:\s*"([^"]+)"', src[:src.index("aliases:")])):
        ids[m.group(1)] = idx
    return ids


def page_file(name: str) -> Path | None:
    hits = list((NEXUS / "pages").rglob(f"{name}.qml"))
    return hits[0] if hits else None


def parse_page(path: Path):
    """(title, [entries], [sub-page indices it opens])"""
    title = None
    entries = []
    subs = []
    section = ""
    stack = []  # [type, props dict]
    for raw in path.read_text().splitlines():
        line = strip_comment(raw)
        for m in SUB.finditer(raw):
            subs.append(int(m.group(1)))
            # A row that opens a sub-page: the search opens that page instead
            for el in reversed(stack):
                if el[0] in ROW_TYPES or el[0].endswith("Row"):
                    el[1]["opens"] = int(m.group(1))
                    break
        m = OPEN.match(line)
        if m:
            stack.append([m.group(1), {}])
            rest = line[m.end():]
            # one-line element: Foo { text: ... }
            if rest.strip().endswith("}"):
                pm = PROP.match(rest.strip().rstrip("}").strip())
                if pm:
                    stack[-1][1][pm.group(1)] = tr_of(pm.group(2))
                el = stack.pop()
                section = finish(el, entries, section, any(s[0] == "Repeater" for s in stack))
            continue
        pm = PROP.match(line)
        if pm and stack:
            val = tr_of(pm.group(2))
            if pm.group(1) == "title" and len(stack) == 1 and val and title is None:
                title = val
            elif val and pm.group(1) not in stack[-1][1]:
                # The row's own label: later text: lines (e.g. in a goTo({...})
                # in its click handler) aren't it
                stack[-1][1][pm.group(1)] = val
        for _ in range(line.count("}") - line.count("{")):
            if stack:
                el = stack.pop()
                section = finish(el, entries, section, any(s[0] == "Repeater" for s in stack))
    # The page's own title: a root property (4 spaces in), whatever the brace
    # counting above made of function bodies before it. A conditional one
    # ("Edit playlist" : "Playlists") is the page's resting title: the last.
    if title is None:
        tm = re.search(r"^    title:\s*(.*)$", path.read_text(), re.M)
        if tm:
            exprs = TR.findall(tm.group(1))
            title = tr_of(tm.group(1)) if len(exprs) < 2 else tr_of(tm.group(1)[tm.group(1).rindex("Tr.tr"):])
    return title, entries, subs


def finish(el, entries, section, in_repeater):
    kind, props = el
    if kind == "SectionHeader":
        t = props.get("text")
        return t[0] if t else section
    if in_repeater:
        return section
    if kind in ROW_TYPES or kind.endswith("Row"):
        lab = props.get("label") or props.get("text")
        # Status lines ("No plugins", "Checking for updates…") aren't settings
        if lab and not re.match(r"^No |^Needs |^Search$|.* need |.* is missing$|.*(…|\.\.\.)$", lab[0]):
            sub_txt = props.get("subtext")[0] if props.get("subtext") else ""
            if lab[0] in EXCLUDE_LABELS or section in EXCLUDE_SECTIONS or section.endswith("…"):
                return section
            if lab[0] in {"Temperature", "Power", "Load", "Background"} and not sub_txt:
                return section
            entry = {
                "label": lab[0],
                "ctx": lab[1],
                "sub": sub_txt,
                "section": section,
            }
            if "opens" in props:
                entry["opens"] = props["opens"]
            entries.append(entry)
    return section


def main() -> int:
    pages = registry()
    id_map = page_ids()
    out = []
    # A page that is also reachable as another page's sub-page (Notifications
    # under Services) is indexed once, as its own page
    roots = {comps[0] for comps in pages if comps}
    for pi, comps in enumerate(pages):
        parsed = {}
        for si, name in enumerate(comps):
            f = page_file(name)
            if f:
                src_text = f.read_text()
                title, entries, subs = parse_page(f)
                # Map embedded page name -> enclosing TabPart key using brace depth
                embedded_tabs = {}
                cur_tab = ""
                tab_depth = -1
                depth = 0
                pending_emb = ""
                for raw in src_text.splitlines():
                    s = strip_comment(raw)
                    if re.match(r"^\s*TabPart\s*\{", s):
                        tab_depth = depth
                        cur_tab = ""
                    if tab_depth >= 0:
                        km = re.search(r'^\s*key:\s*"([^"]+)"', s)
                        if km:
                            cur_tab = km.group(1)
                        em = re.match(r"^\s*([A-Z][A-Za-z0-9_]*)\s*\{", s)
                        if em and em.group(1) != "TabPart":
                            pending_emb = em.group(1)
                        if pending_emb and re.search(r"\bembedded:\s*true\b", s):
                            embedded_tabs[pending_emb] = cur_tab
                            pending_emb = ""
                    depth += s.count("{") - s.count("}")
                    if tab_depth >= 0 and depth <= tab_depth:
                        tab_depth = -1
                        cur_tab = ""
                        pending_emb = ""
                # A merged page (pages/merged): its rows are those of the
                # pages embedded in it (shown as its parts or in folds)
                for embedded in EMBEDDED.findall(src_text):
                    ef = page_file(embedded)
                    if ef:
                        _, e_entries, e_subs = parse_page(ef)
                        tab_key = embedded_tabs.get(embedded, "")
                        for ee in e_entries:
                            if tab_key:
                                ee["tab"] = tab_key
                        entries = entries + e_entries
                        subs = subs + e_subs
                parsed[si] = (name, title, entries, subs)
        # Paths to each sub-page: follow openSubPage from the page that calls it
        paths = {0: []}
        changed = True
        while changed:
            changed = False
            for si, (name, title, entries, subs) in parsed.items():
                if si not in paths:
                    continue
                for s in subs:
                    if s not in paths and s in parsed:
                        paths[s] = paths[si] + [s]
                        changed = True
        for si, (name, title, entries, subs) in parsed.items():
            if si not in paths or name in NEEDS_SELECTION or (si > 0 and name in roots):
                continue
            trail = [parsed[s][1][0] for s in paths[si] if parsed[s][1]]
            # The sub-page itself, by its title (one only a button opens, like
            # Wallpaper & style's Live, is otherwise not findable)
            if si > 0 and title and not any(e.get("opens") == si and e["label"] == title[0]
                                            for ps in paths[si][:-1] + [0] for e in parsed[ps][2]):
                out.append({"label": title[0], "ctx": title[1], "sub": "", "section": "", "page": pi,
                            "path": paths[si], "trail": trail[:-1], "keywords": SYNONYMS.get(title[0], "")})
            for e in entries:
                e = dict(e)
                if "opens" in e and (e["opens"] not in parsed or parsed[e["opens"]][0] in NEEDS_SELECTION):
                    del e["opens"]
                e["page"] = pi
                e["path"] = paths[si]
                e["trail"] = trail
                e["keywords"] = SYNONYMS.get(e["label"], "")
                out.append(e)

    # The tabs each page answers to: its TabPart keys/altKeys (in its own file
    # and the pages embedded in it) and the former page ids aliased to it
    tab_keys = {}
    page_text = {}
    for pi, comps in enumerate(pages):
        keys = set()
        f = page_file(comps[0]) if comps else None
        files = [f] if f else []
        if f:
            files += [ef for ef in (page_file(e) for e in EMBEDDED.findall(f.read_text())) if ef]
        for ff in files:
            t = ff.read_text()
            keys.update(re.findall(r'^\s*key:\s*"([^"]+)"', t, re.M))
            for alts in re.findall(r'^\s*altKeys:\s*\[([^\]]*)\]', t, re.M):
                keys.update(re.findall(r'"([^"]+)"', alts))
        tab_keys[pi] = keys
        # Its text (sub-pages too): an extra entry's label must be in it
        page_text[pi] = "".join(ff.read_text() for ff in files) + "".join(
            sf.read_text() for sf in (page_file(c) for c in comps[1:]) if sf)
    reg = (NEXUS / "PageRegistry.qml").read_text()
    for alias, target in re.findall(r'^\s*"?([A-Za-z]+)"?:\s*"([a-z]+)",?$', reg[reg.index("aliases:"):], re.M):
        if target in id_map:
            tab_keys[id_map[target]].add(alias)

    for page_id, tab, sub, label, keywords, section in EXTRA_ENTRIES:
        if page_id not in id_map:
            print(f"warning: extra entry {label!r}: no page {page_id!r}", file=sys.stderr)
            continue
        pi = id_map[page_id]
        if tab and tab not in tab_keys.get(pi, set()):
            print(f"warning: extra entry {label!r}: {page_id} has no tab {tab!r}", file=sys.stderr)
        # (Shortcut rows are named from the key variables at run time: not checked)
        if tab != "shortcuts" and f'"{label}"' not in page_text.get(pi, ""):
            print(f"warning: extra entry {label!r}: no such text on the {page_id} page", file=sys.stderr)
        # Already found on the page: only its keywords are added
        same = next((e for e in out if e["page"] == pi and e["path"] == [] and e.get("tab", "") == tab and e["label"] == label), None)
        if same:
            same["keywords"] = " ".join(x for x in (same.get("keywords", ""), keywords) if x)
            continue
        out.append({
            "label": label,
            "ctx": "",
            "sub": sub,
            "section": section,
            "page": id_map[page_id],
            "path": [],
            "trail": [],
            "tab": tab,
            "keywords": keywords,
        })

    # Same label twice on one page (e.g. a "Muted" for output and input): keep both,
    # they read differently with their sections; the very same entry only once
    seen = set()
    unique = []
    for e in out:
        k = (e["page"], tuple(e["path"]), e.get("tab", ""), e["label"], e["section"])
        if k not in seen:
            seen.add(k)
            unique.append(e)
    out = unique
    body = json.dumps(out, indent=4, ensure_ascii=False)
    body = "\n".join("    " + l for l in body.splitlines()).lstrip()
    OUT.write_text(f"""pragma Singleton

import QtQuick

// GENERATED by scripts/nexus-search-index.py from the pages: do not edit.
// Every setting row: its label (source text + translation context), subtext,
// section, page index, sub-page path and the sub-page titles on the way.
QtObject {{
    readonly property var entries: {body}
}}
""")
    print(f"{len(out)} settings indexed -> {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

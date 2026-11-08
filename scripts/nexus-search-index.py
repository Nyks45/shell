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
    "ToggleRow", "SliderRow", "StepperRow", "SelectRow", "TextFieldRow", "RowButton", "NavRow", "PopupRow",
    "DialogRowButton", "DialogSelectButton", "InfoRow", "SwitchRow", "ColourRow",
}
# Sub-pages that only make sense with something picked first
NEEDS_SELECTION = {
    "EthernetDetailPage", "NetworkDetailPage", "AddVpnPage", "BtDeviceInfo", "AppInfo", "WallpaperCategory",
    "LiveWallpaperInfo", "DiskPartitionPage", "DiskHealthPage", "SnapshotPage",
}
# Extra words people search for, by label
SYNONYMS = {
    "Live wallpapers": "animated moving video wallpaper engine background",
    "Dark theme": "dark mode light mode night",
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
    "Time zone": "timezone clock",
    "Clock format": "12 24 hour am pm",
    "Do not disturb": "dnd silence mute notifications",
    "Frame rate": "fps live wallpaper",
    "Copy to the clipboard": "screenshot clipboard",
    "Test which wallpapers work": "compatibility live wallpaper engine",
}

TR = re.compile(r'Tr\.(tr|trCtx)\("((?:[^"\\]|\\.)*)"(?:\s*,\s*"((?:[^"\\]|\\.)*)")?')
PROP = re.compile(r'^\s*(label|text|subtext|title)\s*:\s*(.*)$')
OPEN = re.compile(r'^\s*([A-Z][A-Za-z0-9_.]*)\s*\{')
SUB = re.compile(r'openSubPage\((\d+)\)')


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
    body = src[src.index("pageComps:"):src.index("placeholderComp")]
    pages = []
    depth = 0
    stack = []  # type names of open elements
    for line in body.splitlines():
        stripped = strip_comment(line)
        m = OPEN.match(stripped)
        if m:
            name = m.group(1)
            stack.append(name)
            if name == "StackPage":
                pages.append([])
            elif len(stack) >= 2 and stack[-2] == "Component" and len(stack) >= 3 and stack[-3] == "StackPage":
                pages[-1].append(name)
            depth += 1
            closes = stripped.count("}") - (stripped.count("{") - 1)
            for _ in range(max(0, closes)):
                stack.pop()
                depth -= 1
            continue
        for _ in range(stripped.count("}")):
            if stack:
                stack.pop()
                depth -= 1
    return pages


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
                section = finish(el, entries, section)
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
                section = finish(el, entries, section)
    # The page's own title: a root property (4 spaces in), whatever the brace
    # counting above made of function bodies before it. A conditional one
    # ("Edit playlist" : "Playlists") is the page's resting title: the last.
    if title is None:
        tm = re.search(r"^    title:\s*(.*)$", path.read_text(), re.M)
        if tm:
            exprs = TR.findall(tm.group(1))
            title = tr_of(tm.group(1)) if len(exprs) < 2 else tr_of(tm.group(1)[tm.group(1).rindex("Tr.tr"):])
    return title, entries, subs


def finish(el, entries, section):
    kind, props = el
    if kind == "SectionHeader":
        t = props.get("text")
        return t[0] if t else section
    if kind in ROW_TYPES or kind.endswith("Row"):
        lab = props.get("label") or props.get("text")
        # Status lines ("No plugins", "Checking for updates…") aren't settings
        if lab and not re.match(r"^No |^Needs |^Search$|.* need |.* is missing$|.*(…|\.\.\.)$", lab[0]):
            sub = props.get("subtext")
            entry = {
                "label": lab[0],
                "ctx": lab[1],
                "sub": sub[0] if sub else "",
                "section": section,
            }
            if "opens" in props:
                entry["opens"] = props["opens"]
            entries.append(entry)
    return section


def main() -> int:
    pages = registry()
    out = []
    # A page that is also reachable as another page's sub-page (Notifications
    # under Services) is indexed once, as its own page
    roots = {comps[0] for comps in pages if comps}
    for pi, comps in enumerate(pages):
        parsed = {}
        for si, name in enumerate(comps):
            f = page_file(name)
            if f:
                parsed[si] = (name, *parse_page(f))
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

    # Same label twice on one page (e.g. a "Muted" for output and input): keep both,
    # they read differently with their sections
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

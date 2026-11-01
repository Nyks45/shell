#!/usr/bin/env python3
"""Wallpaper Engine wallpapers on this PC, as JSON, for the settings app's
live wallpapers (rendered by linux-wallpaperengine).

Looks in every Steam library (libraryfolders.vdf): Workshop items (app
431960), the built-in projects, your own projects and the presets. For each
folder with a project.json: title, type, preview, tags, age rating, the
user properties (general.properties) and when it was added.

    live-wallpaper-scan.py [--extra DIR]...    the list (plus wallpaper folders of your own)
    live-wallpaper-scan.py assets              the assets folder the renderer needs ("" if none)
    live-wallpaper-scan.py test FOLDER...      try each in the renderer (3 at a time, 5 s, a hidden
                                               window); one JSON line per folder: grade + errors
    live-wallpaper-scan.py workshop SORT PAGE [TYPE] [SEARCH]
                                               a page of the Steam Workshop (SORT: trend, popular,
                                               recent; TYPE: Scene, Video, Web or ""), as JSON
    live-wallpaper-scan.py playlists FILE      write the playlists in FILE (the settings app's
                                               live-wallpaper.json) into Wallpaper Engine's config.json
"""

from html import unescape as html_unescape
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

HOME = Path.home()
ROOTS = [
    HOME / ".local/share/Steam",
    HOME / ".steam/steam",
    HOME / ".var/app/com.valvesoftware.Steam/.local/share/Steam",
    HOME / ".var/app/com.valvesoftware.Steam/.data/Steam",
]
RATINGS = {"everyone": "g", "questionable": "pg13", "mature": "r"}
PROPERTY_TYPES = {"bool", "slider", "combo", "color", "textinput"}


def libraries() -> list[Path]:
    """Steam library folders (each has steamapps/), de-duplicated."""
    seen, out = set(), []
    for root in ROOTS:
        if not root.is_dir():
            continue
        candidates = [root]
        vdf = root / "steamapps/libraryfolders.vdf"
        try:
            candidates += [Path(p) for p in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(errors="ignore"))]
        except OSError:
            pass
        for c in candidates:
            try:
                key = c.resolve()
            except OSError:
                continue
            if key not in seen and (c / "steamapps").is_dir():
                seen.add(key)
                out.append(c)
    return out


# Wallpaper Engine's own labels, stored as translation keys
UI_LABELS = {
    "ui_browse_properties_scheme_color": "Colour scheme",
    "ui_browse_properties_alignment": "Alignment",
    "ui_browse_properties_scaling": "Scaling",
    "ui_browse_properties_play_sound": "Play sound",
    "ui_browse_properties_volume": "Volume",
    "ui_browse_properties_rate": "Playback speed",
    "ui_browse_properties_background_color": "Background colour",
}


def clean_label(text: str, name: str) -> str:
    text = re.sub(r"<[^>]+>", "", text or "").strip()
    if text in UI_LABELS:
        return UI_LABELS[text]
    if not text or text.startswith("ui_"):
        text = re.sub(r"[_-]+", " ", name).strip().capitalize()
    return text


def properties(project: dict) -> list[dict]:
    props = (project.get("general") or {}).get("properties") or {}
    out = []
    for i, (name, p) in enumerate(props.items()):
        if not isinstance(p, dict) or p.get("type") not in PROPERTY_TYPES:
            continue
        entry = {
            "name": name,
            "type": p["type"],
            "label": clean_label(p.get("text", ""), name),
            "value": p.get("value"),
            "order": p.get("order", i),
        }
        for k in ("min", "max", "step"):
            if k in p:
                entry[k] = p[k]
        if p["type"] == "combo":
            entry["options"] = [{"label": clean_label(o.get("label", ""), str(o.get("value"))), "value": o.get("value")} for o in p.get("options") or [] if isinstance(o, dict)]
        out.append(entry)
    out.sort(key=lambda e: (e["order"] if isinstance(e["order"], (int, float)) else 0))
    return out


def scan_dir(folder: Path, source: str, seen: set) -> list[dict]:
    out = []
    try:
        entries = sorted(folder.iterdir())
    except OSError:
        return out
    for d in entries:
        pj = d / "project.json"
        if not pj.is_file() or d.name in seen:
            continue
        try:
            project = json.loads(pj.read_text(encoding="utf-8", errors="replace"))
        except (OSError, ValueError):
            continue
        seen.add(d.name)
        preview = project.get("preview") or ""
        prev_path = d / preview if preview else None
        if not prev_path or not prev_path.is_file():
            prev_path = next((d / f for f in ("preview.gif", "preview.jpg", "preview.png", "preview.jpeg") if (d / f).is_file()), None)
        kind = str(project.get("type") or "scene").lower()
        if kind not in ("scene", "video", "web", "application"):
            kind = "scene"
        try:
            added = int(d.stat().st_mtime * 1000)
        except OSError:
            added = 0
        size = 0
        for base, _, files in os.walk(d):
            for f in files:
                try:
                    size += os.path.getsize(os.path.join(base, f))
                except OSError:
                    pass
        out.append({
            "path": str(d),
            "id": d.name,
            "title": str(project.get("title") or d.name),
            "type": kind,
            "preview": str(prev_path) if prev_path else "",
            "tags": [str(t) for t in project.get("tags") or []],
            "rating": RATINGS.get(str(project.get("contentrating") or "").lower(), ""),
            "source": source,
            "added": added,
            "size": size,
            "properties": properties(project),
        })
    return out


def assets_dir() -> str:
    override = os.environ.get("LIVE_WALLPAPER_ASSETS", "")
    if override and Path(override).is_dir():
        return override
    for lib in libraries():
        a = lib / "steamapps/common/wallpaper_engine/assets"
        if a.is_dir():
            return str(a)
    return ""


# Compatibility, as the Linux Wallpaper Engine GUI grades it: run the renderer
# for 5 s in a window (a window rule keeps it hidden and unfocused: title
# "wallpaperengine") and read its errors
BROKEN = re.compile(r"segmentation fault|segfault|failed to initialize glfw|glfw.*error|abort.*core dumped|cannot open display", re.I)
MINOR = re.compile(r"missing texture|missing shader|missing material|scenescript|cannot find|warning|not supported|failed to load", re.I)
IGNORE = re.compile(r"the platform does not (provide|support).*window position", re.I)


def test(folders: list[str]) -> None:
    assets = assets_dir()
    pending = list(folders)
    running = []  # (folder, proc, started)
    while pending or running:
        while pending and len(running) < 3:
            f = pending.pop(0)
            cmd = ["linux-wallpaperengine", "--window", "0x0x1x1", "--silent", "--disable-mouse"]
            if assets:
                cmd += ["--assets-dir", assets]
            cmd.append(f)
            try:
                p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, errors="replace", start_new_session=True)
            except OSError as e:
                print(json.dumps({"path": f, "grade": "broken", "errors": [str(e)]}), flush=True)
                continue
            running.append((f, p, time.monotonic()))
        time.sleep(0.2)
        for item in list(running):
            f, p, t0 = item
            exited = p.poll() is not None
            if not exited and time.monotonic() - t0 < 5:
                continue
            if not exited:
                p.kill()
            try:
                err = p.communicate(timeout=2)[1] or ""
            except Exception:
                err = ""
            lines = [l.strip() for l in err.splitlines() if l.strip() and not IGNORE.search(l)]
            if exited and p.returncode not in (0, -9, -15):
                grade, errors = "broken", ["Process exited unexpectedly"] + [l for l in lines if BROKEN.search(l)][:3]
            elif any(BROKEN.search(l) for l in lines):
                grade, errors = "broken", [l for l in lines if BROKEN.search(l)][:5]
            elif any(MINOR.search(l) for l in lines):
                grade, errors = "minor", list(dict.fromkeys(l for l in lines if MINOR.search(l)))[:5]
            else:
                grade, errors = "perfect", []
            print(json.dumps({"path": f, "grade": grade, "errors": errors}), flush=True)
            running.remove(item)


# A page of the Steam Workshop (its public listing; subscribing happens in Steam)
SORTS = {"trend": "browsesort=trend&actualsort=trend&days=7", "popular": "browsesort=totaluniquesubscribers&actualsort=totaluniquesubscribers&days=-1", "recent": "browsesort=mostrecent&actualsort=mostrecent"}


def workshop(sort: str, page: int, kind: str, search: str) -> None:
    q = f"https://steamcommunity.com/workshop/browse/?appid=431960&section=readytouseitems&{SORTS.get(sort, SORTS['trend'])}&p={page}&requiredtags%5B%5D=Everyone"
    if kind:
        q += "&requiredtags%5B%5D=" + urllib.parse.quote(kind)
    if search:
        q += "&searchtext=" + urllib.parse.quote(search)
    req = urllib.request.Request(q, headers={"User-Agent": "Mozilla/5.0", "Accept-Language": "en"})
    try:
        html = urllib.request.urlopen(req, timeout=20).read().decode("utf-8", "replace")
    except Exception as e:
        json.dump({"error": str(e), "items": []}, sys.stdout)
        return
    items, seen = [], set()
    for m in re.finditer(r'filedetails/\?id=(\d+)"[^>]*>\s*<img src="([^"]+)" alt="([^"]*)"', html):
        if m.group(1) in seen:
            continue
        seen.add(m.group(1))
        # Steam letterboxes the thumbnail in black: ask for it plain, a bit larger
        preview = re.sub(r"\?.*$", "?imw=400&imh=400&ima=fit", m.group(2).replace("&amp;", "&"))
        items.append({"id": m.group(1), "preview": preview, "title": html_unescape(m.group(3))})
    json.dump({"items": items}, sys.stdout)


# Wallpaper Engine's config.json, where the renderer looks for playlists: in
# the Steam install itself (not a custom assets folder). LIVE_WALLPAPER_WE_CONFIG
# points it elsewhere (the sandbox, tests).
def we_config() -> Path | None:
    override = os.environ.get("LIVE_WALLPAPER_WE_CONFIG", "")
    if override:
        return Path(override)
    for lib in libraries():
        d = lib / "steamapps/common/wallpaper_engine"
        if d.is_dir():
            return d / "config.json"
    return None


# The settings app's playlists into Wallpaper Engine's config.json, which the
# renderer reads for --playlist (other keys there are kept)
def write_playlists(settings_file: str) -> None:
    try:
        c = json.load(open(settings_file, encoding="utf-8"))
    except Exception:
        return
    cfg = we_config()
    if not cfg:
        return
    try:
        data = json.loads(cfg.read_text(encoding="utf-8"))
    except Exception:
        data = {}
    general = data.setdefault("steamuser", {}).setdefault("general", {})
    data["steamuser"].setdefault("wallpaperconfig", {}).setdefault("selectedwallpapers", {})
    general["playlists"] = [{
        "name": p["name"],
        "items": p.get("items") or [],
        "settings": {"delay": max(1, int(p.get("delay") or 60)), "mode": "timer", "order": p.get("order") or "sequential",
                     "updateonpause": False, "videosequence": False},
    } for p in c.get("playlists") or [] if p.get("name")]
    if cfg.exists():
        cfg.with_suffix(".json.backup").write_text(cfg.read_text(encoding="utf-8"), encoding="utf-8")
    cfg.write_text(json.dumps(data, indent=4), encoding="utf-8")


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "assets":
        print(assets_dir())
        return 0
    if cmd == "test":
        test(sys.argv[2:])
        return 0
    if cmd == "workshop":
        a = sys.argv[2:] + ["", "", "", ""]
        workshop(a[0] or "trend", int(a[1] or 1), a[2], a[3])
        return 0
    if cmd == "playlists":
        write_playlists(sys.argv[2])
        return 0
    seen: set = set()
    items = []
    extra = [sys.argv[i + 1] for i, a in enumerate(sys.argv[:-1]) if a == "--extra"]
    for d in extra:
        p = Path(os.path.expanduser(d))
        # A folder of wallpapers, or one wallpaper itself
        if (p / "project.json").is_file():
            one = [i for i in scan_dir(p.parent, "folder", set()) if i["path"] == str(p) and i["id"] not in seen]
            seen.update(i["id"] for i in one)
            items += one
        else:
            items += scan_dir(p, "folder", seen)
    for lib in libraries():
        apps = lib / "steamapps"
        items += scan_dir(apps / "workshop/content/431960", "workshop", seen)
        we = apps / "common/wallpaper_engine"
        items += scan_dir(we / "projects/myprojects", "mine", seen)
        items += scan_dir(we / "projects/defaultprojects", "built-in", seen)
        items += scan_dir(we / "assets/presets", "preset", seen)
    json.dump(items, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())

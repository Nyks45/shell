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
    live-wallpaper-scan.py workshop [--sort trend|toprated|recent|updated|subscribed] [--days N]
                                    [--page N] [--search TEXT] [--tag TAG]... [--mature]
                                               a page of the Steam Workshop as JSON: items (rating,
                                               votes, author, tags...), page, pages, total, tagGroups
    live-wallpaper-scan.py workshop-item ID...  details of Workshop items (description, stats)
    live-wallpaper-scan.py playlists FILE      write the playlists in FILE (the settings app's
                                               live-wallpaper.json) into Wallpaper Engine's config.json
"""

from html import unescape as html_unescape
import gzip
import hashlib
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
# The settings app's own library (no Wallpaper Engine install needed): assets/,
# projects/defaultprojects/, workshop/<id>/ (downloaded items). Found first,
# so its copies win over Steam's.
LIBRARY = Path(os.environ.get("LIVE_WALLPAPER_LIBRARY") or HOME / ".local/share/caelestia/wallpaper-engine")
ROOTS = [
    HOME / ".local/share/Steam",
    HOME / ".steam/steam",
    HOME / ".var/app/com.valvesoftware.Steam/.local/share/Steam",
    HOME / ".var/app/com.valvesoftware.Steam/.data/Steam",
]
RATINGS = {"everyone": "g", "questionable": "pg13", "mature": "r"}
PROPERTY_TYPES = {"bool", "slider", "combo", "color", "textinput", "group", "text", "file", "directory", "scenetexture", "usershortcut"}


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


def html_text(text: str) -> str:
    """A label's HTML as plain text: line breaks as spaces, tags out, entities
    decoded (&nbsp; often without its ';'), spaces collapsed."""
    text = re.sub(r"(?i)<br\s*/?>", " ", text or "")
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"(?i)&nbsp;?", " ", text)
    text = html_unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def image_only(text: str) -> bool:
    """A label that's only a picture (authors use them as dividers)."""
    return bool(re.search(r"(?i)<img", text or "")) and not html_text(text)


def clean_label(text: str, name: str, loc: dict | None = None) -> str:
    # The wallpaper's own labels (general.localization, English) first
    if loc and isinstance(text, str) and text in loc:
        text = str(loc[text])
    text = html_text(text)
    if text in UI_LABELS:
        return UI_LABELS[text]
    if not text or text.startswith("ui_"):
        text = re.sub(r"[_-]+", " ", name).strip().capitalize()
    return text


def properties(project: dict) -> list[dict]:
    props = (project.get("general") or {}).get("properties") or {}
    locs = (project.get("general") or {}).get("localization") or {}
    loc = locs.get("en-us") or locs.get("en") or {}
    out = []
    for i, (name, p) in enumerate(props.items()):
        if not isinstance(p, dict):
            continue
        kind = p.get("type") or "text"  # untyped ones are labels (often HTML)
        if kind not in PROPERTY_TYPES:
            continue
        raw = str(p.get("text") or "")
        raw = str(loc.get(raw, raw))
        # A picture for a label: authors use them as dividers (and give the
        # property a name made from the picture's address): a divider line
        if image_only(raw):
            if out and out[-1]["type"] != "divider":
                out.append({"name": name, "type": "divider", "label": "", "value": None, "order": p.get("order", i), "condition": str(p.get("condition") or "")})
            continue
        if kind in ("text", "group") and not html_text(raw):
            continue
        entry = {
            "name": name,
            "type": kind,
            "label": clean_label(p.get("text", ""), name, loc),
            "value": p.get("value"),
            "order": p.get("order", i),
            # Wallpaper Engine's show/hide rule ("a.value && b.value == 2"), evaluated
            # by the settings page (a small safe parser, never as code)
            "condition": str(p.get("condition") or ""),
        }
        if kind == "file":
            entry["fileType"] = str(p.get("fileType") or "")
        for k in ("min", "max", "step"):
            if k in p:
                entry[k] = p[k]
        if kind == "combo":
            entry["options"] = [{"label": clean_label(o.get("label", ""), str(o.get("value")), loc), "value": o.get("value")} for o in p.get("options") or [] if isinstance(o, dict)]
        out.append(entry)
    out.sort(key=lambda e: (e["order"] if isinstance(e["order"], (int, float)) else 0))
    return out


STILLS = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "caelestia/live-stills"


def still(preview: Path) -> str:
    """A still for an animated preview: the first frame that isn't (nearly)
    black. Many GIFs fade in from black, and a still shows only frame 0.
    Cached by path and modification time; "" when the preview's first frame
    is fine as it is (or Pillow isn't there)."""
    if preview.suffix.lower() != ".gif":
        return ""
    try:
        st = preview.stat()
        out = STILLS / (hashlib.sha1(f"{preview}:{st.st_mtime_ns}:{st.st_size}".encode()).hexdigest() + ".jpg")
        if out.is_file():
            return str(out)
        from PIL import Image, ImageStat
        im = Image.open(preview)
        frames = getattr(im, "n_frames", 1)
        best, best_light = 0, -1.0
        for i in range(0, frames, max(1, frames // 12)):  # a dozen samples
            im.seek(i)
            light = sum(ImageStat.Stat(im.convert("L")).mean)
            if light > best_light:
                best, best_light = i, light
            if light > 40:  # bright enough: take the earliest such frame
                best = i
                break
        if best == 0:
            return ""
        im.seek(best)
        STILLS.mkdir(parents=True, exist_ok=True)
        im.convert("RGB").save(out, "JPEG", quality=92)
        return str(out)
    except Exception:
        return ""


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
            updated = int(pj.stat().st_mtime * 1000)
        except OSError:
            added = updated = 0
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
            "still": still(prev_path) if prev_path else "",
            "tags": [str(t) for t in project.get("tags") or []],
            "rating": RATINGS.get(str(project.get("contentrating") or "").lower(), ""),
            "source": source,
            "updated": updated,
            "added": added,
            "size": size,
            "properties": properties(project),
        })
    return out


def assets_dir() -> str:
    override = os.environ.get("LIVE_WALLPAPER_ASSETS", "")
    if override and Path(override).is_dir():
        return override
    if (LIBRARY / "assets").is_dir():
        return str(LIBRARY / "assets")
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


# The Steam Workshop, keyless: the public browse page embeds its results as
# JSON (React SSR data: "valve-ssr-data"), with ratings, authors and tags;
# item details come from ISteamRemoteStorage/GetPublishedFileDetails, which
# needs no Web API key. Subscribing happens in Steam.
SORTS = {
    "trend": "trend",  # with days
    "toprated": "toprated",
    "recent": "mostrecent",
    "updated": "lastupdated",
    "subscribed": "totaluniquesubscribers",
}
UA = {"User-Agent": "Mozilla/5.0", "Accept-Language": "en", "Accept-Encoding": "gzip"}
# Pages and details seen before: shown at once, then refreshed (Steam takes
# ~1.5 s to answer); the next page and the other sorts are fetched ahead.
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "caelestia/workshop"


def _get(req) -> str:
    with urllib.request.urlopen(req, timeout=20) as r:
        data = r.read()
        if r.headers.get("Content-Encoding") == "gzip":
            data = gzip.decompress(data)
    return data.decode("utf-8", "replace")


def _cache_path(key: str) -> Path:
    return CACHE / (hashlib.sha1(key.encode()).hexdigest() + ".json")


def _cache_read(key: str) -> str:
    try:
        return _cache_path(key).read_text()
    except OSError:
        return ""


def _cache_write(key: str, text: str) -> None:
    try:
        CACHE.mkdir(parents=True, exist_ok=True)
        tmp = _cache_path(key).with_suffix(".tmp")
        tmp.write_text(text)
        tmp.replace(_cache_path(key))
    except OSError:
        pass


def _ssr(html: str) -> dict:
    m = re.search(r'<script[^>]*id="valve-ssr-data"[^>]*>(.*?)</script>', html, re.S)
    if not m:
        return {}

    def deep(o):  # values are JSON strings within JSON
        if isinstance(o, str) and o[:1] in "{[":
            try:
                return deep(json.loads(o))
            except ValueError:
                return o
        if isinstance(o, dict):
            return {k: deep(v) for k, v in o.items()}
        if isinstance(o, list):
            return [deep(v) for v in o]
        return o

    return deep(json.loads(m.group(1)))


def _item(r: dict, names: dict) -> dict:
    tags = [t.get("tag", "") for t in r.get("tags", [])]
    preview = r.get("preview_url", "")
    return {
        "id": str(r.get("publishedfileid", "")),
        "title": r.get("title", ""),
        "preview": preview + ("?imw=800&imh=800&ima=fit" if preview and "?" not in preview else ""),
        "previewFull": preview,
        "rating": r.get("star_rating", 0) or 0,
        "votes": r.get("total_votes", 0) or 0,
        "subscriptions": r.get("subscriptions", 0) or 0,
        "favorited": r.get("favorited", 0) or 0,
        "size": int(r.get("file_size", 0) or 0),
        "updated": r.get("time_updated", 0) or 0,
        "created": r.get("time_created", 0) or 0,
        "author": names.get(str(r.get("creator", "")), ""),
        "authorId": str(r.get("creator", "")),
        "description": r.get("short_description", "") or r.get("file_description", ""),
        "tags": tags,
    }


def _browse_url(opt: dict, tags: list[str], mature: bool) -> str:
    q = {
        "appid": "431960",
        "section": "readytouseitems",
        "browsesort": SORTS.get(opt["sort"], "trend"),
        "actualsort": SORTS.get(opt["sort"], "trend"),
        "p": opt["page"] or "1",
    }
    if q["browsesort"] == "trend":
        q["days"] = opt["days"] or "7"
    if opt["search"]:
        q["searchtext"] = opt["search"]
        q["browsesort"] = q["actualsort"] = "textsearch"
    url = "https://steamcommunity.com/workshop/browse/?" + urllib.parse.urlencode(q)
    # Without --mature only "Everyone" (Steam shows the rest only when asked)
    for t in tags + ([] if mature or any(t in ("Questionable", "Mature") for t in tags) else ["Everyone"]):
        url += "&requiredtags%5B%5D=" + urllib.parse.quote(t)
    return url


def _fetch_page(url: str, page: int) -> str:
    """A browse page as our JSON (text), or raises."""
    data = _ssr(_get(urllib.request.Request(url, headers=UA)))
    names, browse, declared = {}, {}, []
    for qd in data.get("renderContext", {}).get("queryData", {}).get("queries", []):
        key = qd.get("queryKey") or [""]
        st = (qd.get("state") or {}).get("data")
        if key[0] == "workshop_browse" and isinstance(st, dict):
            browse = st
        elif key[0] == "PlayerLinkDetails" and isinstance(st, dict):
            pub = st.get("public_data") or {}
            names[str(key[1])] = pub.get("persona_name", "")
        elif key[0] == "declared_tags_v6" and len(key) > 1 and str(key[1]) == "431960" and isinstance(st, dict):
            # Filter groups as the Workshop shows them (assets/scripts left out)
            declared = [{"name": g.get("name", ""), "multi": g.get("htmlelement") == "checkbox",
                         "tags": [t.get("name", "") for t in g.get("tags", []) if not t.get("admin_only")]}
                        for g in st.get("mtx_tags", [])]
    if not browse:
        raise ValueError("Steam changed its Workshop page (no results data found)")
    return json.dumps({
        "items": [_item(r, names) for r in browse.get("results", [])],
        "page": page,
        "pages": browse.get("total_pages", 1),
        "total": browse.get("total_count", 0),
        "tagGroups": declared,
    })


def workshop(args: list[str]) -> None:
    """JSON lines: the cached page at once (if any, "cached": true), then
    Steam's. Then, silently, the next page and the other sorts into the
    cache. --prefetch: only that (no output)."""
    opt = {"sort": "trend", "days": "7", "page": "1", "search": ""}
    tags: list[str] = []
    mature = prefetch = False
    it = iter(args)
    for a in it:
        if a == "--tag":
            tags.append(next(it, ""))
        elif a == "--mature":
            mature = True
        elif a == "--prefetch":
            prefetch = True
        elif a.startswith("--"):
            opt[a[2:]] = next(it, "")
    page = int(opt["page"] or 1)
    url = _browse_url(opt, tags, mature)
    if not prefetch:
        cached = _cache_read(url)
        if cached:
            print(cached[:-1] + ', "cached": true}', flush=True)
        try:
            fresh = _fetch_page(url, page)
            _cache_write(url, fresh)
            if fresh != cached:
                print(fresh, flush=True)
        except Exception as e:
            if not cached:
                print(json.dumps({"error": str(e), "items": []}), flush=True)
            return
        # The rest in the background (detached): the settings app sees this
        # process end now, and opening another page doesn't cut it short
        sys.stdout.flush()
        if os.fork() != 0:
            return
        os.setsid()
        devnull = os.open(os.devnull, os.O_RDWR)
        for fd in (0, 1, 2):
            os.dup2(devnull, fd)
    # Ahead: the next page, and (from the first page) the other sorts
    ahead = [dict(opt, page=str(page + 1))]
    if page == 1 and not opt["search"]:
        ahead += [dict(opt, sort=srt, page="1") for srt in SORTS if srt != opt["sort"]]
    for o in ahead if not prefetch else [opt]:
        u = _browse_url(o, tags, mature)
        if prefetch or not _cache_read(u):
            try:
                _cache_write(u, _fetch_page(u, int(o["page"])))
            except Exception:
                pass
    if not prefetch:
        os._exit(0)


def workshop_item(ids: list[str]) -> None:
    key = "item:" + ",".join(ids)
    cached = _cache_read(key)
    if cached:
        print(cached, flush=True)
    body = {"itemcount": str(len(ids))}
    for i, x in enumerate(ids):
        body[f"publishedfileids[{i}]"] = x
    try:
        req = urllib.request.Request("https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/",
                                     data=urllib.parse.urlencode(body).encode(), headers=UA)
        res = json.loads(_get(req)).get("response", {})
    except Exception as e:
        if not cached:
            print(json.dumps({"error": str(e), "items": []}), flush=True)
        return
    items = []
    for d in res.get("publishedfiledetails", []):
        if d.get("result") != 1:
            continue
        i = _item(d, {})
        i["description"] = d.get("description", "")
        i["views"] = d.get("views", 0)
        # Not in this answer (the browse page has them): don't blank them
        for k in ("rating", "votes", "author", "preview"):
            i.pop(k, None)
        items.append(i)
    fresh = json.dumps({"items": items})
    _cache_write(key, fresh)
    if fresh != cached:
        print(fresh, flush=True)


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
        workshop(sys.argv[2:])
        return 0
    if cmd == "workshop-item":
        workshop_item(sys.argv[2:])
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
    items += scan_dir(LIBRARY / "workshop", "workshop", seen)
    items += scan_dir(LIBRARY / "projects/defaultprojects", "built-in", seen)
    items += scan_dir(LIBRARY / "assets/presets", "preset", seen)
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

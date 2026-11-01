#!/usr/bin/env python3
"""Applies the app look chosen in the settings app (Fonts, App appearance) to
Qt apps: qtengine's config (font, fixed font, style, icon theme, menu icons,
single-click).

The settings app keeps the choices in $XDG_CONFIG_HOME/caelestia/app-look.json
and runs this after a change. The caelestia CLI rewrites qtengine's config
from its template on every colour scheme change, so the settings app also
makes this the CLI's theme postHook (cli.json), which runs it after each one.
"""

import json
import os
import sys
from pathlib import Path

config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
prefs_path = config / "caelestia/app-look.json"
qt_path = config / "qtengine/config.json"


def main() -> int:
    try:
        prefs = json.loads(prefs_path.read_text())
    except (OSError, ValueError):
        return 0
    qt = prefs.get("qt") or {}
    if not qt and not prefs.get("iconTheme"):
        return 0

    try:
        data = json.loads(qt_path.read_text())
    except (OSError, ValueError):
        data = {}
    theme = data.setdefault("theme", {})
    misc = data.setdefault("misc", {})

    if qt.get("font"):
        theme.setdefault("font", {"weight": -1})
        theme["font"]["family"] = qt["font"]
    if qt.get("fontSize"):
        theme.setdefault("font", {"weight": -1})
        theme["font"]["size"] = qt["fontSize"]
    if qt.get("fontFixed"):
        theme.setdefault("fontFixed", {"weight": -1})
        theme["fontFixed"]["family"] = qt["fontFixed"]
    if qt.get("fontFixedSize"):
        theme.setdefault("fontFixed", {"weight": -1})
        theme["fontFixed"]["size"] = qt["fontFixedSize"]
    if qt.get("style"):
        theme["style"] = qt["style"]
    if prefs.get("iconTheme"):
        theme["iconTheme"] = prefs["iconTheme"]
    for key in ("menusHaveIcons", "singleClickActivate"):
        if key in qt:
            misc[key] = bool(qt[key])

    qt_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = qt_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=4) + "\n")
    tmp.replace(qt_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())

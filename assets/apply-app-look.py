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
fc_path = config / "fontconfig/conf.d/99-caelestia-rendering.conf"

HINT_STYLES = {
    "none": "hintnone",
    "slight": "hintslight",
    "medium": "hintmedium",
    "full": "hintfull",
}


def write_fontconfig(rendering: dict) -> None:
    aa = rendering.get("antialiasing", "grayscale")
    hint = rendering.get("hinting", "slight")
    aa_bool = "false" if aa == "none" else "true"
    hint_bool = "false" if hint == "none" else "true"
    hint_style = HINT_STYLES.get(hint, "hintslight")
    rgba = "rgb" if aa == "rgba" else "none"
    xml = f"""<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- Managed by Caelestia Settings (Fonts > Text rendering) -->
<fontconfig>
    <match target="font">
        <edit name="antialias" mode="assign"><bool>{aa_bool}</bool></edit>
        <edit name="hinting" mode="assign"><bool>{hint_bool}</bool></edit>
        <edit name="hintstyle" mode="assign"><const>{hint_style}</const></edit>
        <edit name="rgba" mode="assign"><const>{rgba}</const></edit>
    </match>
</fontconfig>
"""
    fc_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = fc_path.with_suffix(".conf.tmp")
    tmp.write_text(xml)
    tmp.replace(fc_path)


def main() -> int:
    try:
        prefs = json.loads(prefs_path.read_text())
    except (OSError, ValueError):
        return 0
    qt = prefs.get("qt") or {}
    rendering = prefs.get("rendering") or {}
    if rendering:
        write_fontconfig(rendering)
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

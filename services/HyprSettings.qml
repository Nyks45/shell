pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.utils

// Hyprland settings made in the settings app.
//
// What the app changed is kept in hypr-settings.json (its own record) and
// written out as hypr-settings.lua, which the Hyprland config applies:
// hypr-vars.lua merges its `vars` (apps, cursor, window opacity) into the
// Caelestia variables, and hypr-user.lua calls its `apply()` last, so options
// set here win over the config files. Options never changed here keep coming
// from the config files.
//
// Pages read what Hyprland actually uses (getoption), not this record.
Singleton {
    id: root

    // Option name -> value Hyprland reports for it
    property var values: ({})
    // What the app set: config (option -> value), vars, hyprflow (option ->
    // value), monitors (name -> settings), nightLight, autostart
    property var saved: ({})
    property bool loaded

    readonly property string jsonPath: `${Paths.config}/hypr-settings.json`
    readonly property string luaPath: `${Paths.config}/hypr-settings.lua`
    // Where the Startup apps page keeps them (the XDG autostart folder)
    readonly property string autostartDir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/autostart`

    // Options pages show (read on start and after every reload)
    readonly property list<string> watched: [
        // Windows
        "general:gaps_in", "general:gaps_out", "general:border_size", "decoration:rounding", "decoration:dim_inactive", "decoration:dim_strength", "decoration:blur:enabled", "decoration:blur:size", "decoration:blur:passes", "decoration:shadow:enabled", "decoration:shadow:range", "animations:enabled",
        // Keyboard & mouse
        "input:kb_layout", "input:kb_options", "input:repeat_rate", "input:repeat_delay", "input:numlock_by_default", "input:sensitivity", "input:accel_profile", "input:natural_scroll", "input:scroll_factor", "input:left_handed", "input:touchpad:natural_scroll", "input:touchpad:disable_while_typing", "input:touchpad:tap-to-click", "cursor:inactive_timeout",
        // Desktop mode
        "plugin:hyprflow:bar_enabled", "plugin:hyprflow:bar_autohide", "plugin:hyprflow:bar_height", "plugin:hyprflow:bar_text_align", "plugin:hyprflow:bar_buttons_align", "plugin:hyprflow:bar_button_icons_on_hover", "plugin:hyprflow:bar_icon", "plugin:hyprflow:bar_double_click", "plugin:hyprflow:bar_middle_click", "plugin:hyprflow:hot_corners"]

    function value(name: string, fallback: var): var {
        return values[name] ?? fallback;
    }

    // An option set here (applied after the config files).
    function setOption(name: string, val: var): void {
        setValues({
            [name]: val
        });
        const config = Object.assign({}, saved.config ?? {});
        config[name] = val;
        update({
            config
        });
    }

    // A Caelestia variable (variables.lua), e.g. browser, cursorSize.
    function setVar(name: string, val: var): void {
        const vars = Object.assign({}, saved.vars ?? {});
        vars[name] = val;
        update({
            vars
        });
    }

    function varValue(name: string, fallback: var): var {
        return saved.vars?.[name] ?? fallback;
    }

    // A hyprflow option: hyprflow.lua builds its style from these too, so they
    // go in its own table (it only sets what the loaded plugin knows).
    function setHyprflow(name: string, val: var): void {
        setValues({
            [`plugin:hyprflow:${name}`]: val
        });
        const hyprflow = Object.assign({}, saved.hyprflow ?? {});
        hyprflow[name] = val;
        update({
            hyprflow
        });
    }

    function setMonitor(name: string, settings: var): void {
        const monitors = Object.assign({}, saved.monitors ?? {});
        monitors[name] = settings;
        update({
            monitors
        });
    }

    // Back to what the config files say for it
    function forgetMonitor(name: string): void {
        const monitors = Object.assign({}, saved.monitors ?? {});
        delete monitors[name];
        update({
            monitors
        });
    }

    function setNightLight(settings: var): void {
        update({
            nightLight: Object.assign({}, saved.nightLight ?? {}, settings)
        });
    }

    function setAutostart(on: bool): void {
        update({
            autostart: on
        });
    }

    function update(changes: var): void {
        saved = Object.assign({}, saved, changes);
        jsonFile.setText(JSON.stringify(saved, null, 4) + "\n");
        luaFile.setText(toLua(saved));
        reloadTimer.restart();
    }

    // Re-read the Hyprland config (it also reads shell.json, e.g. the screen
    // corners for maximized windows)
    function reloadSoon(): void {
        reloadTimer.restart();
    }

    function setValues(changes: var): void {
        values = Object.assign({}, values, changes);
    }

    function refresh(): void {
        reader.running = false;
        reader.running = true;
    }

    // Lua source for a JS value
    function luaValue(v: var, indent: string): string {
        if (typeof v === "boolean" || typeof v === "number")
            return String(v);
        if (typeof v === "string")
            return JSON.stringify(v); // a JSON string is a valid Lua string
        if (Array.isArray(v))
            return `{ ${v.map(x => luaValue(x, indent)).join(", ")} }`;
        if (v && typeof v === "object") {
            const inner = indent + "    ";
            const keys = Object.keys(v).filter(k => v[k] !== undefined && v[k] !== null);
            if (keys.length === 0)
                return "{}";
            return `{\n${keys.map(k => `${inner}${/^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : `[${JSON.stringify(k)}]`} = ${luaValue(v[k], inner)},`).join("\n")}\n${indent}}`;
        }
        return "nil";
    }

    // "a:b:c" options -> { a = { b = { c = v } } }, as hl.config takes them
    function nest(options: var): var {
        const out = {};
        for (const [name, val] of Object.entries(options ?? {})) {
            const parts = name.split(":");
            let node = out;
            for (const p of parts.slice(0, -1))
                node = node[p] = node[p] ?? {};
            node[parts[parts.length - 1]] = val;
        }
        return out;
    }

    function toLua(s: var): string {
        const monitors = Object.entries(s.monitors ?? {}).map(([name, m]) => {
            const rule = {
                output: m.description ? `desc:${m.description}` : name,
                mode: m.mode,
                position: m.position,
                scale: m.scale,
                vrr: m.vrr,
                transform: m.transform
            };
            if (m.hdr) {
                rule.cm = "hdr";
                rule.bitdepth = 10;
            }
            return rule;
        });
        const night = s.nightLight ?? {};

        return `-- Written by Caelestia's settings app from hypr-settings.json: changes here are overwritten.
-- hypr-vars.lua merges S.vars; hypr-user.lua calls S.apply() last.
local S = {}

S.vars = ${luaValue(s.vars ?? {}, "")}

-- hyprflow options (hyprflow.lua merges them into its style)
S.hyprflow = ${luaValue(s.hyprflow ?? {}, "")}

function S.apply()
    local config = ${luaValue(nest(s.config), "    ")}
    if next(config) then hl.config(config) end

    for _, m in ipairs(${luaValue(monitors, "    ")}) do
        hl.monitor(m)
    end

    -- Night light (hyprsunset, scheduled in ~/.config/hypr/hyprsunset.conf)
    if ${night.enabled ? "true" : "false"} then
        hl.on("hyprland.start", function() hl.exec_cmd("hyprsunset") end)
    end

    -- Apps in ~/.config/autostart (the settings app's Startup apps)
    if ${s.autostart === false ? "false" : "true"} then
        hl.on("hyprland.start", function()
            local dir = ${JSON.stringify(root.autostartDir)}
            local list = io.popen("ls -1 '" .. dir .. "' 2>/dev/null")
            if not list then return end
            for name in list:lines() do
                if name:match("%.desktop$") then
                    local f = io.open(dir .. "/" .. name)
                    if f then
                        local text = f:read("a")
                        f:close()
                        local exec = text:match("\\nExec=([^\\n]+)")
                        local hidden = text:match("\\nHidden=true") or text:match("\\nX%-GNOME%-Autostart%-enabled=false")
                        if exec and not hidden then
                            hl.exec_cmd((exec:gsub("%%[fFuUdDnNickvm]", "")))
                        end
                    end
                end
            end
            list:close()
        end)
    end
end

return S
`;
    }

    Component.onCompleted: refresh()

    Connections {
        function onRawEvent(event: var): void {
            if (event.name === "configreloaded")
                root.refresh();
        }

        target: Hyprland
    }

    Timer {
        id: reloadTimer

        interval: 400
        onTriggered: Hypr.extras.message("reload")
    }

    FileView {
        id: jsonFile

        path: root.jsonPath
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && typeof data === "object")
                    root.saved = data;
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    FileView {
        id: luaFile

        path: root.luaPath
        printErrors: false
        blockLoading: false
    }

    // hyprctl -j getoption for each watched option; it targets the Hyprland
    // this shell runs under (HYPRLAND_INSTANCE_SIGNATURE)
    Process {
        id: reader

        command: ["sh", "-c", "for o in \"$@\"; do hyprctl -j getoption \"$o\"; echo; done", "sh", ...root.watched]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const chunk of text.split(/\n\s*\n/)) {
                    try {
                        const o = JSON.parse(chunk);
                        const key = Object.keys(o).find(k => k !== "option" && k !== "set");
                        // Hyprland reports an empty string as "[[EMPTY]]"
                        if (o.option && key)
                            found[o.option] = o[key] === "[[EMPTY]]" ? "" : o[key];
                    } catch (e) {}
                }
                root.values = found;
            }
        }
    }
}

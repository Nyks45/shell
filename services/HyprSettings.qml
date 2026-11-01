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
        "plugin:hyprflow:bar_enabled", "plugin:hyprflow:bar_autohide", "plugin:hyprflow:bar_height", "plugin:hyprflow:bar_text_align", "plugin:hyprflow:bar_buttons_align", "plugin:hyprflow:bar_button_icons_on_hover", "plugin:hyprflow:bar_icon", "plugin:hyprflow:bar_double_click", "plugin:hyprflow:bar_middle_click", "plugin:hyprflow:hot_corners", "plugin:hyprflow:bar_font", "plugin:hyprflow:bar_text_size", "plugin:hyprflow:keep_alive", "plugin:hyprflow:snap_enabled", "plugin:hyprflow:snap_assist", "plugin:hyprflow:snap_layouts", "plugin:hyprflow:snap_groups", "plugin:hyprflow:minimize_animation", "plugin:hyprflow:bar_buttons", "plugin:hyprflow:bar_menu", "plugin:hyprflow:bar_color_from_window", "plugin:hyprflow:bar_blur", "plugin:hyprflow:bar_csd", "plugin:hyprflow:bar_autohide_position", "plugin:hyprflow:bar_autohide_delay_ms", "plugin:hyprflow:bar_button_size", "plugin:hyprflow:bar_icon_size", "plugin:hyprflow:bar_text_weight",
        // Workspaces & focus
        "input:follow_mouse", "input:float_switch_override_focus", "binds:workspace_back_and_forth", "binds:allow_workspace_cycles", "misc:focus_on_activate", "cursor:no_warps", "misc:new_window_takes_over_fullscreen", "misc:initial_workspace_tracking",
        // Scrolling layout (hyprscroller)
        "plugin:hyprscrolling:column_width", "plugin:hyprscrolling:new_window_placement", "plugin:hyprscrolling:stack_after_columns", "plugin:hyprscrolling:focus_fit_method", "plugin:hyprscrolling:center_active_column", "plugin:hyprscrolling:follow_hover", "plugin:hyprscrolling:hover_delay_ms", "plugin:hyprscrolling:peek_width", "plugin:hyprscrolling:stretch_to_fill", "plugin:hyprscrolling:fullscreen_on_one_column", "plugin:hyprscrolling:column_scroll", "plugin:hyprscrolling:focus_wrap", "plugin:hyprscrolling:explicit_column_widths", "plugin:hyprscrolling:column_widths", "plugin:hyprscrolling:overview_zoom", "plugin:hyprscrolling:overview_titles", "plugin:hyprscrolling:fullscreen_screen_sized",
        // Gaming, accessibility
        "general:allow_tearing", "misc:vrr", "cursor:zoom_factor", "misc:animate_manual_resizes", "decoration:screen_shader",
        // Privacy
        "ecosystem:enforce_permissions"]

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

    // An option for one mode only: "desktop" (hyprflow's desktop mode) or
    // "tiling" (the scrolling layout); applied after the always-on ones
    function setModeOption(mode: string, name: string, val: var): void {
        const key = mode === "desktop" ? "desktopConfig" : "tilingConfig";
        const config = Object.assign({}, saved[key] ?? {});
        if (val === null || val === undefined)
            delete config[name];
        else
            config[name] = val;
        update({
            [key]: config
        });
    }

    function modeValue(mode: string, name: string, fallback: var): var {
        return saved[mode === "desktop" ? "desktopConfig" : "tilingConfig"]?.[name] ?? fallback;
    }

    // Back to what the config files say for a variable
    function unsetVar(name: string): void {
        const vars = Object.assign({}, saved.vars ?? {});
        delete vars[name];
        update({
            vars
        });
    }

    // Shortcuts set in the config with hl.bind, moved to other keys ("" turns
    // one off): the hook S.early() installs catches the config's binds
    function setBindRemap(from: string, to: var): void {
        const remap = Object.assign({}, saved.remap ?? {});
        if (to === null || to === undefined)
            delete remap[from];
        else
            remap[from] = to;
        update({
            remap
        });
    }

    // [{ key, command }]: shortcuts of the user's own that run a command
    function setCustomBinds(list: var): void {
        update({
            customBinds: list
        });
    }

    // "menu": the power button opens the shell's power menu (logind ignores it)
    function setPowerKey(value: string): void {
        update({
            powerKey: value
        });
    }

    // Fullscreen apps (games, videos) keep the screen awake
    function setFullscreenInhibit(on: bool): void {
        update({
            fullscreenInhibit: on
        });
    }

    // [{ class, float, center, opacity, workspace, size, idleInhibit, immediate, pin }]
    function setWindowRules(list: var): void {
        update({
            windowRules: list
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
                if (m.sdrbrightness && m.sdrbrightness !== 1)
                    rule.sdrbrightness = m.sdrbrightness;
            }
            if (m.disabled)
                rule.disabled = true;
            if (m.mirror)
                rule.mirror = m.mirror;
            if (m.icc)
                rule.icc = m.icc;
            return rule;
        });
        const night = s.nightLight ?? {};

        const rules = (s.windowRules ?? []).filter(r => r.class).map(r => {
            const rule = {
                match: {
                    class: r.class
                }
            };
            if (r.float)
                rule.float = true;
            if (r.center)
                rule.center = true;
            if (r.pin)
                rule.pin = true;
            if (r.opacity && r.opacity < 1)
                rule.opacity = `${r.opacity} override`;
            if (r.workspace)
                rule.workspace = String(r.workspace);
            if (r.size)
                rule.size = r.size;
            if (r.idleInhibit)
                rule.idle_inhibit = r.idleInhibit;
            if (r.immediate)
                rule.immediate = true;
            return rule;
        });

        return `-- Written by Caelestia's settings app from hypr-settings.json: changes here are overwritten.
-- hypr-vars.lua merges S.vars and calls S.early(); hypr-user.lua calls S.apply() last.
local S = {}

S.vars = ${luaValue(s.vars ?? {}, "")}

-- Shortcuts moved to other keys ("" = turned off), by the keys the config binds
S.remap = ${luaValue(s.remap ?? {}, "")}

-- "SUPER + SHIFT + d" -> "SHIFT+SUPER+D": modifiers in one order, upper case
local function norm(keys)
    local parts = {}
    for p in tostring(keys):gmatch("[^+]+") do
        parts[#parts + 1] = p:gsub("^%s+", ""):gsub("%s+$", ""):upper()
    end
    local key = table.remove(parts)
    table.sort(parts)
    parts[#parts + 1] = key
    return table.concat(parts, "+")
end

-- Early in the config, before its binds: hl.bind/unbind go through S.remap.
-- Installed once per Lua state; the map is a global, so a reload updates it.
function S.early()
    local map = {}
    for from, to in pairs(S.remap) do map[norm(from)] = to end
    _G.__caelestia_remap = map
    if _G.__caelestia_bind or not (hl and hl.bind) then return end
    local bind, unbind = hl.bind, hl.unbind
    _G.__caelestia_bind = bind
    hl.bind = function(keys, ...)
        local to = _G.__caelestia_remap[norm(keys)]
        if to == "" then return end
        return bind(to or keys, ...)
    end
    if unbind then
        _G.__caelestia_unbind = unbind
        hl.unbind = function(keys, ...)
            local to = _G.__caelestia_remap[norm(keys)]
            if to == "" then return end
            return unbind(to or keys, ...)
        end
    end
end

-- hyprflow options (hyprflow.lua merges them into its style)
S.hyprflow = ${luaValue(s.hyprflow ?? {}, "")}

-- Plugin options only for plugins that are loaded (at the first parse at login
-- hyprpm hasn't loaded them yet; Hyprland re-reads the config after it does),
-- or Hyprland reports unknown options as config errors
local function known(config)
    for plugin, opts in pairs(config.plugin or {}) do
        for k in pairs(opts) do
            if hl.get_config("plugin:" .. plugin .. ":" .. k) == nil then opts[k] = nil end
        end
        if next(opts) == nil then config.plugin[plugin] = nil end
    end
    if config.plugin and next(config.plugin) == nil then config.plugin = nil end
    return config
end

function S.apply()
    local config = known(${luaValue(nest(s.config), "    ")})
    if next(config) then hl.config(config) end

    -- Per mode: desktop mode (hyprflow) or the scrolling layout
    local hf = hl.plugin and hl.plugin.hyprflow
    local desktop = hf and hf.desktop_mode and hf.desktop_mode()
    local modeConfig = known(desktop and ${luaValue(nest(s.desktopConfig), "    ")} or ${luaValue(nest(s.tilingConfig), "    ")})
    if next(modeConfig) then hl.config(modeConfig) end

    for _, m in ipairs(${luaValue(monitors, "    ")}) do
        hl.monitor(m)
    end

    -- Fullscreen windows keep the screen awake (games, videos)
    if ${s.fullscreenInhibit ? "true" : "false"} then
        hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })
    end

    -- Window rules for apps
    for _, r in ipairs(${luaValue(rules, "    ")}) do
        hl.window_rule(r)
    end

    -- The user's own shortcuts (past the remap hook: their keys are theirs)
    local bind = _G.__caelestia_bind or hl.bind
    local unbind = _G.__caelestia_unbind or hl.unbind
    for _, b in ipairs(${luaValue((s.customBinds ?? []).filter(b => b.key && b.command), "    ")}) do
        if unbind then pcall(unbind, b.key) end
        bind(b.key, hl.dsp.exec_cmd(b.command))
    end

    -- The power button opens the power menu (logind is set to ignore it)
    if ${s.powerKey === "menu" ? "true" : "false"} then
        bind("XF86PowerOff", hl.dsp.exec_cmd("caelestia shell drawers toggle session"))
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

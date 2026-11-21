pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import "Geometry.js" as G
import "Tools.js" as Tools

// One Paint window (the app is paint.qml). The picture is a document of objects drawn over
// the opened picture, all in the picture's own pixels: `doc` = {W, H, bg, base, items}.
// Undo/redo keep whole snapshots of `doc`. Pictures and pasted images form the "pixel layer"
// (what redaction and the magnifier work on); drawings go above it in their own order.
Window {
    id: win

    required property var app
    property string source
    property var restoreFrom: null
    property var newPage: null
    property string sessionDir

    // ---- document ----
    property var doc: ({
            W: 1920,
            H: 1080,
            bg: "#ffffff",
            base: null,
            items: []
        })
    property var history: []
    property var future: []
    property var gestureBase: null
    property bool dirty
    property bool ready
    property string loadError
    property int nextId: 1
    property string savePath
    property int saveQuality: 92
    property bool forceClose
    property bool closeAfterSave
    readonly property bool untouched: ready && !doc.base && doc.items.length === 0 && history.length === 0
    readonly property string docName: savePath ? savePath.split("/").pop() : (source ? source.split("/").pop() : Tr.tr("Untitled"))
    readonly property var itemMap: {
        const m = {};
        for (const it of doc.items)
            m[it.id] = it;
        return m;
    }
    property var textSizes: ({})
    property string lastCoalesce
    property real lastCoalesceAt

    // ---- view ----
    property bool fitMode: true
    property real zoomValue: 1
    property real panX
    property real panY
    readonly property real fit: Math.max(0.01, Math.min((viewport.width - 48) / doc.W, (viewport.height - 48) / doc.H, 1))
    readonly property real zoom: fitMode ? fit : zoomValue
    readonly property real stageW: doc.W * zoom
    readonly property real stageH: doc.H * zoom
    readonly property real stageX: stageW + 48 <= viewport.width ? (viewport.width - stageW) / 2 : 24 - panX
    readonly property real stageY: stageH + 48 <= viewport.height ? (viewport.height - stageH) / 2 : 24 - panY
    property point hoverPos: Qt.point(-1, -1)
    property bool hovering
    property bool spaceHeld

    // ---- tools and their settings (defaults for new objects; applied to the selection too) ----
    property string tool: "pen"
    property string prevTool: "pen"
    property color colour: app.prefs.colour ?? "#ff3b30"
    property color second: app.prefs.second ?? "#ffffff"
    property real thickness: app.prefs.thickness ?? 4
    property real penOpacity: app.prefs.penOpacity ?? 1
    property string fill: app.prefs.fill ?? "none"
    property string dash: app.prefs.dash ?? "solid"
    property string head: app.prefs.head ?? "filled"
    property bool both: app.prefs.both ?? false
    property real radius: app.prefs.radius ?? 0
    property real fontSize: app.prefs.fontSize ?? 32
    property string family: app.prefs.family ?? Tokens.font.body.small.family
    property bool bold: app.prefs.bold ?? true
    property bool italic: app.prefs.italic ?? false
    property bool box: app.prefs.box ?? false
    property bool outline: app.prefs.outline ?? false
    property string redactMode: app.prefs.redactMode ?? "pixelate"
    property real redactStrength: app.prefs.redactStrength ?? 14
    property string spotShape: app.prefs.spotShape ?? "rect"
    property real spotDim: app.prefs.spotDim ?? 0.55
    property real magZoom: app.prefs.magZoom ?? 2
    property bool smoothing: app.prefs.smoothing ?? true
    readonly property var swatches: ["#ff3b30", "#ff9500", "#ffcc00", "#34c759", "#0a84ff", "#af52de", "#ffffff", "#000000"]

    // ---- interaction ----
    property var selected: []
    property var area: null
    property var cropRect: null
    property real cropRatio: 0
    property var draft: null
    property var draftPoints: []
    property var editing: null
    property var band: null
    property string drag
    property var dragStart
    property var dragBox
    property int dragHandle: -1
    property var dragSnapshot
    property point panStart
    property point panOrigin
    property var exportOnly: null
    property bool exportPixelsOnly
    property string toast
    readonly property Item dialogsRef: dialogs
    readonly property Item canvasRef: canvasInput
    readonly property var openDialogRef: openDialog
    readonly property var selBox: G.unionBounds(selected.map(id => itemMap[id] ? G.bounds(itemMap[id], measure) : null))
    readonly property var selItem: selected.length === 1 ? itemMap[selected[0]] ?? null : null
    readonly property string propsKind: {
        if (tool === "select" && selItem)
            return selItem.kind;
        if (tool === "select" && selected.length > 1)
            return "multi";
        return tool;
    }

    title: `${dirty ? "● " : ""}${docName} — ${Tr.tr("Paint")}`
    color: Colours.palette.m3surface
    width: 1280
    height: 860
    minimumWidth: 900
    minimumHeight: 600
    visible: true

    onVisibleChanged: if (!visible)
        app.windowClosed(win)

    onClosing: close => {
        if (forceClose)
            return;
        finishText();
        if (dirty) {
            close.accepted = false;
            dialogs.askClose();
            return;
        }
        discardSession();
    }

    onDocChanged: {
        syncModel();
        if (dirty)
            autosave.restart();
    }

    Component.onCompleted: {
        if (restoreFrom) {
            sessionDir = restoreFrom.dir;
            const st = restoreFrom.state;
            source = st.source ?? "";
            savePath = st.savePath ?? "";
            nextId = st.nextId ?? 1;
            doc = st.doc;
            dirty = true;
            ready = true;
            return;
        }
        sessionDir = app.newSessionDir();
        Quickshell.execDetached(["mkdir", "-p", sessionDir]);
        if (source)
            openBase(source);
        else {
            const p = newPage ?? {};
            doc = {
                W: p.w ?? 1920,
                H: p.h ?? 1080,
                bg: p.bg ?? "#ffffff",
                base: null,
                items: []
            };
            ready = true;
        }
    }

    // What the window shows, for `caelestia-paint` IPC (tests, scripts)
    function stateJson(): string {
        const vp = viewport.mapToItem(rootItem, 0, 0);
        return JSON.stringify({
            title: title,
            tool: tool,
            dirty: dirty,
            ready: ready,
            loadError: loadError,
            W: doc.W,
            H: doc.H,
            bg: doc.bg,
            base: doc.base,
            items: doc.items,
            selected: selected,
            selBox: selBox,
            area: area,
            cropRect: cropRect,
            editing: editing,
            history: history.length,
            future: future.length,
            zoom: zoom,
            fitMode: fitMode,
            stageX: stageX,
            stageY: stageY,
            viewportX: vp.x,
            viewportY: vp.y,
            toast: toast,
            savePath: savePath,
            sessionDir: sessionDir,
            dialogs: dialogs.anyOpen,
            colour: colour.toString(),
            second: second.toString(),
            thickness: thickness,
            fontSize: fontSize,
            textSizes: textSizes,
            hintCut: statusBar.hintCut
        });
    }

    // Where a visible control is, in window coordinates ("x,y"), for scripted clicks:
    // "name=btn:<icon>" (a Paint button), "text=<label>" (any visible text), "swatch=<#colour>"
    function locate(query: string): string {
        const eq = query.indexOf("=");
        const k = query.slice(0, eq), v = query.slice(eq + 1);
        const shown = it => {
            for (let p = it; p; p = p.parent)
                if (!p.visible || p.opacity === 0)
                    return false;
            return it.width > 0 && it.height > 0;
        };
        const walk = it => {
            if (!it)
                return null;
            const hit = (k === "name" && it.objectName === v) || (k === "text" && typeof it.text === "string" && it.text === v && it.font !== undefined) || (k === "swatch" && it.objectName === `swatch:${v}`);
            if (hit && shown(it)) {
                const c = it.mapToItem(null, it.width / 2, it.height / 2);
                return `${Math.round(c.x)},${Math.round(c.y)}`;
            }
            const kids = it.children ?? [];
            for (let i = kids.length - 1; i >= 0; i--) {
                const r = walk(kids[i]);
                if (r)
                    return r;
            }
            return null;
        };
        return walk(contentItem) ?? "";
    }

    // ================= document and history =================

    function measure(it: var): var {
        const m = textSizes[it.id];
        return m ? {
            w: m.width,
            h: m.height
        } : null;
    }

    function newId(): int {
        return nextId++;
    }

    function setDoc(nd: var): void {
        history = [...history.slice(-199), doc];
        future = [];
        doc = nd;
        dirty = true;
        autosave.restart();
    }

    function withItems(items: var): var {
        return Object.assign({}, doc, {
            items: items
        });
    }

    function beginGesture(): void {
        gestureBase = doc;
    }

    function endGesture(): void {
        if (gestureBase && gestureBase !== doc) {
            history = [...history.slice(-199), gestureBase];
            future = [];
            dirty = true;
            autosave.restart();
        }
        gestureBase = null;
    }

    function undo(): void {
        if (editing) {
            cancelText();
            return;
        }
        if (history.length === 0)
            return;
        future = [...future, doc];
        doc = history[history.length - 1];
        history = history.slice(0, -1);
        afterHistory();
    }

    function redo(): void {
        if (future.length === 0)
            return;
        history = [...history, doc];
        doc = future[future.length - 1];
        future = future.slice(0, -1);
        afterHistory();
    }

    function afterHistory(): void {
        selected = selected.filter(id => itemMap[id]);
        area = null;
        dirty = true;
        autosave.restart();
    }

    function addItem(it: var, select: bool): void {
        it.id = newId();
        setDoc(withItems([...doc.items, it]));
        if (select) {
            tool = "select";
            selected = [it.id];
        }
    }

    function removeIds(ids: var): void {
        if (!ids.length)
            return;
        const gone = ids.slice();
        setDoc(withItems(doc.items.filter(it => !gone.includes(it.id))));
        selected = selected.filter(id => !gone.includes(id));
    }

    function replaceItems(fn: var, ids: var, coalesceKey: string): void {
        const nd = withItems(doc.items.map(it => ids.includes(it.id) ? fn(it) : it));
        const now = Date.now();
        if (coalesceKey && coalesceKey === lastCoalesce && now - lastCoalesceAt < 900) {
            doc = nd;
            dirty = true;
        } else {
            setDoc(nd);
        }
        lastCoalesce = coalesceKey ?? "";
        lastCoalesceAt = now;
    }

    // Keeps the delegate model (a list of ids) in step with doc.items, so unchanged objects keep their views
    function syncModel(): void {
        const ids = doc.items.map(it => it.id);
        for (let i = itemModel.count - 1; i >= 0; i--)
            if (!itemMap[itemModel.get(i).uid])
                itemModel.remove(i);
        for (let i = 0; i < ids.length; i++) {
            if (i < itemModel.count && itemModel.get(i).uid === ids[i])
                continue;
            let j = -1;
            for (let k = i + 1; k < itemModel.count; k++)
                if (itemModel.get(k).uid === ids[i]) {
                    j = k;
                    break;
                }
            if (j >= 0)
                itemModel.move(j, i, 1);
            else
                itemModel.insert(i, {
                    uid: ids[i]
                });
        }
    }

    // ================= settings =================

    // A setting changed in the toolbar: the default for new objects, and applied to the selection
    function setProp(name: string, value: var): void {
        win[name] = value;
        app.setPref(name, (name === "colour" || name === "second") ? value.toString() : value);
        if (tool !== "select" || selected.length === 0)
            return;
        replaceItems(it => {
            const out = Object.assign({}, it);
            const k = it.kind;
            const points = G.isPointsKind(k);
            switch (name) {
            case "colour":
                if (k === "redact" || k === "patch" || k === "image" || k === "spotlight" || k === "magnifier")
                    return it;
                out.colour = value.toString();
                break;
            case "second":
                if (k === "text" && it.box)
                    out.box = value.toString();
                else if (k === "callout" || k === "rect" || k === "ellipse")
                    out.fillColour = value.toString();
                else
                    return it;
                break;
            case "thickness":
                if (points)
                    out.width = k === "highlighter" ? Math.max(6, value * 4) : value;
                else if (k === "step")
                    out.size = Math.max(10, value * 3 + 12);
                else
                    return it;
                break;
            case "penOpacity":
                if (!points && k !== "image")
                    return it;
                out.opacity = value;
                break;
            case "fill":
                if (k !== "rect" && k !== "ellipse")
                    return it;
                out.fill = value;
                out.fillColour = out.fillColour ?? second.toString();
                break;
            case "dash":
                if (!points || k === "pen" || k === "highlighter")
                    return it;
                out.dash = value;
                break;
            case "head":
            case "both":
                if (k !== "arrow")
                    return it;
                out[name] = value;
                break;
            case "radius":
                if (k !== "rect")
                    return it;
                out.radius = value;
                break;
            case "fontSize":
                if (k !== "text" && k !== "callout")
                    return it;
                out.size = value;
                break;
            case "family":
                if (k !== "text" && k !== "callout")
                    return it;
                out.family = value;
                break;
            case "bold":
            case "italic":
            case "outline":
                if (k !== "text")
                    return it;
                out[name] = value;
                break;
            case "box":
                if (k !== "text")
                    return it;
                out.box = value ? second.toString() : "";
                break;
            case "redactMode":
                if (k !== "redact")
                    return it;
                out.mode = value;
                break;
            case "redactStrength":
                if (k !== "redact")
                    return it;
                out.strength = value;
                break;
            case "spotShape":
                if (k !== "spotlight")
                    return it;
                out.shape = value;
                break;
            case "spotDim":
                if (k !== "spotlight")
                    return it;
                out.dim = value;
                break;
            case "magZoom":
                if (k !== "magnifier")
                    return it;
                out.zoom = value;
                break;
            default:
                return it;
            }
            return out;
        }, selected, `${name}:${selected.join(",")}`);
    }

    function rememberColour(c: color): void {
        const s = c.toString();
        if (swatches.includes(s))
            return;
        const r = [s, ...(app.prefs.recent ?? []).filter(x => x !== s)].slice(0, 6);
        app.setPref("recent", r);
    }

    function setTool(t: string): void {
        finishText();
        if (t !== "select")
            selected = [];
        if (t !== "area")
            area = null;
        cropRect = t === "crop" ? {
            x: 0,
            y: 0,
            w: doc.W,
            h: doc.H
        } : null;
        if (t === "crop")
            cropRatio = 0;
        if (t === "eyedropper" && tool !== "eyedropper")
            prevTool = tool;
        tool = t;
    }

    // ================= coordinates and view =================

    function toImage(vx: real, vy: real): var {
        return G.pt((vx - stageX) / zoom, (vy - stageY) / zoom);
    }

    function clampPan(): void {
        panX = Math.max(0, Math.min(panX, stageW + 48 - viewport.width));
        panY = Math.max(0, Math.min(panY, stageH + 48 - viewport.height));
    }

    function zoomAt(z: real, vx: real, vy: real): void {
        z = Math.max(0.05, Math.min(32, z));
        const ip = toImage(vx, vy);
        fitMode = false;
        zoomValue = z;
        // keep the point under the cursor in place
        panX = 24 + ip.x * z - vx;
        panY = 24 + ip.y * z - vy;
        clampPan();
    }

    function zoomStep(dir: int): void {
        const steps = [0.05, 0.1, 0.125, 0.25, 0.333, 0.5, 0.667, 0.75, 1, 1.25, 1.5, 2, 3, 4, 6, 8, 12, 16, 24, 32];
        const z = zoom;
        const next = dir > 0 ? steps.find(s => s > z * 1.01) : [...steps].reverse().find(s => s < z * 0.99);
        zoomAt(next ?? z, viewport.width / 2, viewport.height / 2);
    }

    function zoomTo(z: real): void {
        zoomAt(z, viewport.width / 2, viewport.height / 2);
    }

    function zoomFit(): void {
        fitMode = true;
        panX = 0;
        panY = 0;
    }

    function visibleRect(): var {
        const a = toImage(0, 0), b = toImage(viewport.width, viewport.height);
        const x = Math.max(0, a.x), y = Math.max(0, a.y);
        return {
            x: x,
            y: y,
            w: Math.max(1, Math.min(doc.W, b.x) - x),
            h: Math.max(1, Math.min(doc.H, b.y) - y)
        };
    }

    // ================= hit testing =================

    function itemAt(p: var): var {
        const tol = 6 / zoom;
        for (let i = doc.items.length - 1; i >= 0; i--) {
            const it = doc.items[i];
            if (it.kind === "image" || it.kind === "patch")
                continue;
            if (G.hit(it, p, tol, measure))
                return it;
        }
        // pictures under the drawings
        for (let i = doc.items.length - 1; i >= 0; i--) {
            const it = doc.items[i];
            if (it.kind === "image" && G.hit(it, p, tol, measure))
                return it;
        }
        return null;
    }

    function handlePoints(b: var): var {
        return [G.pt(b.x, b.y), G.pt(b.x + b.w / 2, b.y), G.pt(b.x + b.w, b.y), G.pt(b.x + b.w, b.y + b.h / 2), G.pt(b.x + b.w, b.y + b.h), G.pt(b.x + b.w / 2, b.y + b.h), G.pt(b.x, b.y + b.h), G.pt(b.x, b.y + b.h / 2)];
    }

    // 0-7: box handles; 100/101: line ends; 200: callout tail
    function handleAt(p: var, b: var, single: var): int {
        const tol = 9 / zoom;
        if (single && (single.kind === "line" || single.kind === "arrow")) {
            const pts = single.points;
            if (Math.hypot(p.x - pts[0].x, p.y - pts[0].y) <= tol)
                return 100;
            if (Math.hypot(p.x - pts[pts.length - 1].x, p.y - pts[pts.length - 1].y) <= tol)
                return 101;
            return -1;
        }
        if (single && single.kind === "callout" && Math.hypot(p.x - single.tx, p.y - single.ty) <= tol)
            return 200;
        if (!b)
            return -1;
        const hs = handlePoints(b);
        for (let i = 0; i < 8; i++)
            if (Math.abs(p.x - hs[i].x) <= tol && Math.abs(p.y - hs[i].y) <= tol)
                return i;
        return -1;
    }

    function resizeBox(b: var, h: int, p: var, keep: bool): var {
        let l = b.x, t = b.y, r = b.x + b.w, bt = b.y + b.h;
        if (h === 0 || h === 6 || h === 7)
            l = p.x;
        if (h === 2 || h === 3 || h === 4)
            r = p.x;
        if (h === 0 || h === 1 || h === 2)
            t = p.y;
        if (h === 4 || h === 5 || h === 6)
            bt = p.y;
        if (keep && b.w > 0 && b.h > 0 && (h === 0 || h === 2 || h === 4 || h === 6)) {
            const s = Math.max(Math.abs(r - l) / b.w, Math.abs(bt - t) / b.h);
            const w = b.w * s, hh = b.h * s;
            if (h === 0) {
                l = r - w;
                t = bt - hh;
            } else if (h === 2) {
                r = l + w;
                t = bt - hh;
            } else if (h === 4) {
                r = l + w;
                bt = t + hh;
            } else {
                l = r - w;
                bt = t + hh;
            }
        }
        return {
            x: Math.min(l, r),
            y: Math.min(t, bt),
            w: Math.max(1, Math.abs(r - l)),
            h: Math.max(1, Math.abs(bt - t))
        };
    }

    // ================= making objects =================

    function nextStep(): int {
        let n = 0;
        for (const it of doc.items)
            if (it.kind === "step")
                n = Math.max(n, it.n);
        return n + 1;
    }

    function makeItem(kind: string, a: var, b: var, useSecond: bool): var {
        const c = (useSecond ? second : colour).toString();
        const r = G.rectOf(a, b);
        switch (kind) {
        case "line":
        case "arrow":
        case "rect":
        case "ellipse":
            return {
                kind: kind,
                points: [a, b],
                colour: c,
                width: thickness,
                opacity: penOpacity,
                dash: dash,
                head: head,
                both: both,
                fill: fill,
                fillColour: second.toString(),
                radius: radius
            };
        case "redact":
            return {
                kind: kind,
                x: r.x,
                y: r.y,
                w: r.w,
                h: r.h,
                mode: redactMode,
                strength: redactStrength,
                colour: "#000000"
            };
        case "spotlight":
            return {
                kind: kind,
                x: r.x,
                y: r.y,
                w: r.w,
                h: r.h,
                shape: spotShape,
                dim: spotDim
            };
        case "callout":
            return {
                kind: kind,
                x: r.x,
                y: r.y,
                w: r.w,
                h: r.h,
                tx: r.x + r.w * 0.2,
                ty: r.y + r.h + Math.max(24, r.h * 0.5),
                text: "",
                colour: c,
                fillColour: second.toString(),
                size: fontSize,
                family: family
            };
        case "magnifier":
            return {
                kind: kind,
                x: a.x,
                y: a.y,
                r: Math.hypot(b.x - a.x, b.y - a.y),
                zoom: magZoom
            };
        }
        return null;
    }

    // ================= text editing =================

    function startText(p: var, existing: var): void {
        finishText();
        if (existing) {
            editing = {
                id: existing.id,
                kind: existing.kind,
                x: existing.x,
                y: existing.y,
                text: existing.text ?? ""
            };
        } else {
            editing = {
                id: -1,
                kind: "text",
                x: p.x,
                y: p.y - fontSize * 0.6,
                text: ""
            };
        }
        textEditor.text = editing.text;
        Qt.callLater(() => {
            textEditor.forceActiveFocus();
            textEditor.cursorPosition = textEditor.text.length;
        });
    }

    function finishText(): void {
        if (!editing)
            return;
        const e = editing;
        const t = textEditor.text;
        editing = null;
        if (e.id >= 0) {
            const it = itemMap[e.id];
            if (it) {
                if (it.kind === "text" && t.trim() === "")
                    removeIds([e.id]);
                else if (t !== it.text)
                    replaceItems(x => Object.assign({}, x, {
                            text: t
                        }), [e.id], "");
            }
        } else if (t.trim() !== "") {
            addItem({
                kind: "text",
                x: e.x,
                y: e.y,
                text: t,
                colour: colour.toString(),
                size: fontSize,
                family: family,
                bold: bold,
                italic: italic,
                box: box ? second.toString() : "",
                outline: outline
            }, false);
        }
        canvasInput.forceActiveFocus();
    }

    function cancelText(): void {
        editing = null;
        canvasInput.forceActiveFocus();
    }

    // ================= picture operations =================

    function crop(r: var): void {
        if (!r)
            return;
        const x = Math.round(Math.max(0, r.x)), y = Math.round(Math.max(0, r.y));
        const w = Math.round(Math.min(doc.W - x, r.w)), h = Math.round(Math.min(doc.H - y, r.h));
        if (w < 2 || h < 2 || (x === 0 && y === 0 && w === doc.W && h === doc.H))
            return;
        setDoc(shifted(-x, -y, w, h));
        selected = [];
        area = null;
    }

    // Everything moved by dx, dy on a page of w × h
    function shifted(dx: real, dy: real, w: real, h: real): var {
        return {
            W: w,
            H: h,
            bg: doc.bg,
            base: doc.base ? Object.assign({}, doc.base, {
                x: doc.base.x + dx,
                y: doc.base.y + dy
            }) : null,
            items: doc.items.map(it => G.translate(it, dx, dy))
        };
    }

    function resizeCanvas(w: int, h: int, ax: real, ay: real, bg: string): void {
        const dx = Math.round((w - doc.W) * ax), dy = Math.round((h - doc.H) * ay);
        const nd = shifted(dx, dy, w, h);
        if (bg)
            nd.bg = bg;
        setDoc(nd);
        zoomFit();
    }

    function scalePicture(w: int, h: int): void {
        const sx = w / doc.W, sy = h / doc.H;
        setDoc({
            W: w,
            H: h,
            bg: doc.bg,
            base: doc.base ? {
                src: doc.base.src,
                x: doc.base.x * sx,
                y: doc.base.y * sy,
                w: doc.base.w * sx,
                h: doc.base.h * sy
            } : null,
            items: doc.items.map(it => {
                const o = G.scaleItem(it, sx, sy);
                if (it.kind === "text")
                    o.size = Math.max(4, it.size * Math.sqrt(sx * sy));
                return o;
            })
        });
        selected = [];
        zoomFit();
    }

    // Rotating or flipping bakes the drawings into a new picture, as a pixel editor does
    function bake(rot: int, flipH: bool, flipV: bool): void {
        finishText();
        renderRegion(fullRect(), {
            rot: rot,
            flipH: flipH,
            flipV: flipV
        }, result => {
            const path = `${sessionDir}/baked-${Date.now()}.png`;
            if (!result.saveToFile(path)) {
                showToast(Tr.tr("Couldn't rotate the picture"));
                return;
            }
            const w = rot % 2 ? doc.H : doc.W, h = rot % 2 ? doc.W : doc.H;
            setDoc({
                W: w,
                H: h,
                bg: doc.bg,
                base: {
                    src: path,
                    x: 0,
                    y: 0,
                    w: w,
                    h: h
                },
                items: []
            });
            selected = [];
            zoomFit();
        });
    }

    // ================= rendering (export) =================

    // Renders a region of the picture at full size; opts: rot (quarter turns clockwise), flipH,
    // flipV, only (ids: just those objects on transparency), pixels (picture layer only)
    function renderRegion(r: var, opts: var, done: var): void {
        finishText();
        opts = opts ?? {};
        exportOnly = opts.only ?? null;
        exportPixelsOnly = opts.pixels ?? false;
        const rot = ((opts.rot ?? 0) % 4 + 4) % 4;
        const w = Math.max(1, Math.round(r.w)), h = Math.max(1, Math.round(r.h));
        const ew = rot % 2 ? h : w, eh = rot % 2 ? w : h;
        // a point (x, y) of the region: flipped, then turned
        const f = [opts.flipH ? -1 : 1, 0, opts.flipH ? w : 0, 0, opts.flipV ? -1 : 1, opts.flipV ? h : 0];
        const R = [[1, 0, 0, 0, 1, 0], [0, -1, h, 1, 0, 0], [-1, 0, w, 0, -1, h], [0, 1, 0, -1, 0, w]][rot];
        const m = [R[0] * f[0] + R[1] * f[3], R[0] * f[1] + R[1] * f[4], R[0] * f[2] + R[1] * f[5] + R[2], R[3] * f[0] + R[4] * f[3], R[3] * f[1] + R[4] * f[4], R[3] * f[2] + R[4] * f[5] + R[5]];
        exporter.width = ew;
        exporter.height = eh;
        exportSrc.width = w;
        exportSrc.height = h;
        exportSrc.sourceRect = Qt.rect(r.x, r.y, w, h);
        exportSrc.textureSize = Qt.size(w, h);
        exportMatrix.matrix = Qt.matrix4x4(m[0], m[1], 0, m[2], m[3], m[4], 0, m[5], 0, 0, 1, 0, 0, 0, 0, 1);
        exporter.visible = true;
        exportTimer.done = done;
        exportTimer.size = Qt.size(ew, eh);
        exportTimer.restart();
    }

    function fullRect(): var {
        return {
            x: 0,
            y: 0,
            w: doc.W,
            h: doc.H
        };
    }

    // Writes the whole picture to `path` (png/jpg/webp); calls done(ok)
    function writeImage(path: string, done: var): void {
        const ext = path.split(".").pop().toLowerCase();
        renderRegion(fullRect(), {}, result => {
            const tmp = `${sessionDir}/out-${Date.now()}.png`;
            if (!result.saveToFile(tmp)) {
                done(false);
                return;
            }
            const p = writeProc.createObject(win, {
                result: result,
                target: path,
                done: done,
                command: ["sh", "-c", `mkdir -p "$(dirname "$2")" || exit 1
case "$3" in
  png) mv -f "$1" "$2" ;;
  jpg|jpeg) command -v magick >/dev/null || exit 3; magick "$1" -background white -alpha remove -alpha off -quality "$4" "$2" && rm -f "$1" ;;
  webp) command -v magick >/dev/null || exit 3; magick "$1" -quality "$4" "$2" && rm -f "$1" ;;
  *) command -v magick >/dev/null || exit 3; magick "$1" "$2" && rm -f "$1" ;;
esac`, "sh", tmp, path, ext, String(saveQuality)]
            });
            p.running = true;
        });
    }

    function save(): void {
        finishText();
        if (savePath) {
            writeImage(savePath, ok => afterSave(ok, savePath));
            return;
        }
        // first save: next to the picture ("name-edited.png"), or Pictures/Paint for a new one
        const dir = source ? source.slice(0, source.lastIndexOf("/")) : `${Paths.pictures}/Paint`;
        const base = source ? `${source.split("/").pop().replace(/\.[^.]+$/, "")}-edited` : `Paint_${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}`;
        freeName.dir = dir;
        freeName.base = base;
        freeName.running = true;
    }

    function saveTo(path: string): void {
        writeImage(path, ok => afterSave(ok, path));
    }

    function afterSave(ok: bool, path: string): void {
        if (!ok) {
            showToast(Tr.tr("Couldn't save the picture"));
            closeAfterSave = false;
            return;
        }
        savePath = path;
        dirty = false;
        writeSession();
        showToast(Tr.tr("Saved to %1").arg(Paths.shortenHome(path)));
        if (closeAfterSave) {
            forceClose = true;
            discardSession();
            win.close();
        }
    }

    function copyToClipboard(r: var, opts: var): void {
        renderRegion(r, opts, result => {
            const tmp = `${sessionDir}/copy-${Date.now()}.png`;
            if (!result.saveToFile(tmp)) {
                showToast(Tr.tr("Couldn't copy"));
                return;
            }
            Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < "$1"; rm -f "$1"`, "sh", tmp]);
            showToast(Tr.tr("Copied"));
        });
    }

    function copy(): void {
        if (area)
            copyToClipboard(area, {});
        else if (selected.length && selBox)
            copyToClipboard(selBox, {
                only: selected
            });
        else
            copyToClipboard(fullRect(), {});
    }

    function cut(): void {
        if (area) {
            copyToClipboard(area, {});
            eraseArea();
        } else if (selected.length && selBox) {
            const ids = selected.slice();
            renderRegion(selBox, {
                only: ids
            }, result => {
                const tmp = `${sessionDir}/copy-${Date.now()}.png`;
                if (result.saveToFile(tmp))
                    Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < "$1"; rm -f "$1"`, "sh", tmp]);
                removeIds(ids);
                showToast(Tr.tr("Cut"));
            });
        }
    }

    // The picture's pixels in the area become the background colour (drawings stay: they're objects)
    function eraseArea(): void {
        if (!area)
            return;
        const bg = Qt.color(doc.bg).a > 0 ? doc.bg : "#ffffff";
        addItem({
            kind: "patch",
            x: area.x,
            y: area.y,
            w: area.w,
            h: area.h,
            colour: bg
        }, false);
        area = null;
    }

    // Area dragged: its picture pixels lifted into a movable image, a background patch left behind
    function liftArea(then: var): void {
        const r = area;
        renderRegion(r, {
            pixels: true
        }, result => {
            const path = `${sessionDir}/lift-${Date.now()}.png`;
            if (!result.saveToFile(path))
                return;
            const bg = Qt.color(doc.bg).a > 0 ? doc.bg : "#ffffff";
            const patch = {
                kind: "patch",
                id: newId(),
                x: r.x,
                y: r.y,
                w: r.w,
                h: r.h,
                colour: bg
            };
            const img = {
                kind: "image",
                id: newId(),
                x: r.x,
                y: r.y,
                w: Math.round(r.w),
                h: Math.round(r.h),
                src: path,
                opacity: 1
            };
            setDoc(withItems([...doc.items, patch, img]));
            area = null;
            tool = "select";
            selected = [img.id];
            if (then)
                then(img);
        });
    }

    function duplicate(): void {
        if (!selected.length)
            return;
        const off = Math.max(8, 16 / zoom);
        const copies = doc.items.filter(it => selected.includes(it.id)).map(it => {
            const c = G.translate(it, off, off);
            c.id = newId();
            return c;
        });
        setDoc(withItems([...doc.items, ...copies]));
        selected = copies.map(c => c.id);
    }

    function reorder(how: string): void {
        if (!selected.length)
            return;
        let items = doc.items.slice();
        const sel = items.filter(it => selected.includes(it.id));
        const rest = items.filter(it => !selected.includes(it.id));
        if (how === "front")
            items = [...rest, ...sel];
        else if (how === "back")
            items = [...sel, ...rest];
        else {
            const dir = how === "forward" ? 1 : -1;
            const idx = items.map((it, i) => selected.includes(it.id) ? i : -1).filter(i => i >= 0);
            const order = dir > 0 ? idx.reverse() : idx;
            for (const i of order) {
                const j = i + dir;
                if (j < 0 || j >= items.length || selected.includes(items[j].id))
                    continue;
                const t = items[i];
                items[i] = items[j];
                items[j] = t;
            }
        }
        setDoc(withItems(items));
    }

    function nudge(dx: real, dy: real): void {
        if (!selected.length)
            return;
        replaceItems(it => G.translate(it, dx, dy), selected, `nudge:${selected.join(",")}`);
    }

    function selectAll(): void {
        setTool("select");
        selected = doc.items.filter(it => it.kind !== "patch").map(it => it.id);
    }

    // ================= open, paste, drop =================

    function isImagePath(p: string): bool {
        return /\.(png|jpe?g|webp|bmp|gif|tiff?|svg|avif|heic|ico)$/i.test(p);
    }

    function openBase(path: string): void {
        loadError = "";
        ready = false;
        baseProbe.path = path;
        baseProbe.source = "";
        baseProbe.sourceSize = path.toLowerCase().endsWith(".svg") ? Qt.size(2048, 2048) : Qt.size(-1, -1);
        baseProbe.source = `file://${path}`;
    }

    function openFile(path: string): void {
        if (untouched || (!ready && loadError)) {
            source = path;
            openBase(path);
        } else {
            app.open(path);
        }
    }

    // An image file (pasted or dropped) of w × h: the picture itself on an untouched page, else a movable object
    function insertImage(path: string, w: real, h: real, at: var): void {
        if (untouched) {
            setDoc({
                W: w,
                H: h,
                bg: "#00000000",
                base: {
                    src: path,
                    x: 0,
                    y: 0,
                    w: w,
                    h: h
                },
                items: []
            });
            zoomFit();
            return;
        }
        if (w > doc.W || h > doc.H) {
            dialogs.askEnlarge(path, w, h, at);
            return;
        }
        placeImage(path, w, h, at);
    }

    function placeImage(path: string, w: real, h: real, at: var): void {
        let x, y;
        if (at) {
            x = at.x - w / 2;
            y = at.y - h / 2;
        } else {
            const v = visibleRect();
            x = v.x;
            y = v.y;
        }
        x = Math.max(0, Math.min(x, doc.W - w));
        y = Math.max(0, Math.min(y, doc.H - h));
        addItem({
            kind: "image",
            x: Math.round(x),
            y: Math.round(y),
            w: w,
            h: h,
            src: path,
            opacity: 1
        }, true);
    }

    function enlargeAndPlace(path: string, w: real, h: real, at: var): void {
        const nd = shifted(0, 0, Math.max(doc.W, w), Math.max(doc.H, h));
        nd.items = [...nd.items, {
                kind: "image",
                id: newId(),
                x: 0,
                y: 0,
                w: w,
                h: h,
                src: path,
                opacity: 1
            }];
        setDoc(nd);
        tool = "select";
        selected = [nd.items[nd.items.length - 1].id];
        zoomFit();
    }

    function probeImage(path: string, done: var): void {
        const p = probeComp.createObject(win, {
            path: path,
            done: done
        });
        p.source = `file://${path}`;
    }

    function paste(): void {
        finishText();
        pasteProc.asNew = false;
        pasteProc.dir = sessionDir;
        pasteProc.running = true;
    }

    // a new window opened for the clipboard's picture: it becomes this page's picture
    function pasteAsNewHere(): void {
        Qt.callLater(paste);
    }

    function pasteAsNew(): void {
        pasteProc.asNew = true;
        pasteProc.dir = sessionDir;
        pasteProc.running = true;
    }

    function handlePaste(out: string, asNew: bool): void {
        const nl = out.indexOf("\n");
        const kind = (nl < 0 ? out : out.slice(0, nl)).trim();
        const rest = nl < 0 ? "" : out.slice(nl + 1);
        if (kind === "image") {
            const path = rest.trim();
            if (asNew) {
                app.open(path);
                return;
            }
            probeImage(path, (w, h) => insertImage(path, w, h, null));
        } else if (kind === "files") {
            const paths = rest.split("\n").map(s => s.trim()).filter(s => s && isImagePath(s));
            if (!paths.length) {
                showToast(Tr.tr("No picture on the clipboard"));
                return;
            }
            for (const p of paths) {
                if (asNew)
                    app.open(p);
                else
                    probeImage(p, (w, h) => insertImage(p, w, h, null));
            }
        } else if (kind === "text" && !asNew) {
            const t = rest.replace(/\n$/, "");
            if (!t.trim()) {
                showToast(Tr.tr("Nothing to paste"));
                return;
            }
            const v = visibleRect();
            addItem({
                kind: "text",
                x: v.x + v.w * 0.1,
                y: v.y + v.h * 0.1,
                text: t,
                colour: colour.toString(),
                size: fontSize,
                family: family,
                bold: bold,
                italic: italic,
                box: box ? second.toString() : "",
                outline: outline
            }, true);
        } else {
            showToast(asNew ? Tr.tr("No picture on the clipboard") : Tr.tr("Nothing to paste"));
        }
    }

    // ================= session (unsaved work survives closing or a crash) =================

    function writeSession(): void {
        if (!sessionDir)
            return;
        sessionFile.setText(JSON.stringify({
            version: 1,
            clean: !dirty,
            time: Date.now(),
            source: source,
            savePath: savePath,
            nextId: nextId,
            doc: doc
        }));
    }

    function discardSession(): void {
        autosave.stop();
        if (sessionDir)
            Quickshell.execDetached(["rm", "-rf", sessionDir]);
        app.releaseSession(sessionDir);
        sessionDir = "";
    }

    function showToast(t: string): void {
        toast = t;
        toastTimer.restart();
    }

    // ================= input =================

    function onPress(m: var): void {
        const vp = Qt.point(m.x, m.y);
        const p = toImage(m.x, m.y);
        if (m.button === Qt.MiddleButton || spaceHeld || (m.button === Qt.LeftButton && tool === "hand")) {
            if (fitMode) {
                zoomValue = zoom;
                panX = 24 - stageX;
                panY = 24 - stageY;
                fitMode = false;
            }
            drag = "pan";
            panStart = vp;
            panOrigin = Qt.point(panX, panY);
            return;
        }
        if (m.button === Qt.RightButton && tool === "select") {
            const hitItem = itemAt(p);
            if (hitItem && !selected.includes(hitItem.id))
                selected = [hitItem.id];
            contextAnchor.x = m.x;
            contextAnchor.y = m.y;
            contextMenu.expanded = true;
            return;
        }
        const useSecond = m.button === Qt.RightButton;
        dragStart = p;
        dragSnapshot = doc;

        switch (tool) {
        case "select":
            {
                const h = handleAt(p, selBox, selItem);
                if (h >= 0) {
                    drag = "resize";
                    dragHandle = h;
                    dragBox = selBox;
                    beginGesture();
                    return;
                }
                const hitItem = itemAt(p);
                if (hitItem) {
                    if (m.modifiers & Qt.ShiftModifier)
                        selected = selected.includes(hitItem.id) ? selected.filter(i => i !== hitItem.id) : [...selected, hitItem.id];
                    else if (!selected.includes(hitItem.id))
                        selected = [hitItem.id];
                    drag = "move";
                    beginGesture();
                    return;
                }
                if (selBox && G.inRect(p, selBox)) {
                    drag = "move";
                    beginGesture();
                    return;
                }
                if (!(m.modifiers & Qt.ShiftModifier))
                    selected = [];
                drag = "band";
                band = {
                    x: p.x,
                    y: p.y,
                    w: 0,
                    h: 0
                };
                return;
            }
        case "area":
            if (area && G.inRect(p, area)) {
                drag = "lifting";
                liftArea(() => {
                    dragSnapshot = doc;
                    if (canvasInput.pressed) {
                        drag = "move";
                        beginGesture();
                    } else {
                        drag = "";
                    }
                });
                return;
            }
            drag = "area";
            area = {
                x: p.x,
                y: p.y,
                w: 0,
                h: 0
            };
            return;
        case "crop":
            {
                const h = handleAt(p, cropRect, null);
                if (h >= 0) {
                    drag = "cropResize";
                    dragHandle = h;
                    dragBox = cropRect;
                } else if (cropRect && G.inRect(p, cropRect) && (cropRect.w < doc.W || cropRect.h < doc.H)) {
                    drag = "cropMove";
                    dragBox = cropRect;
                } else {
                    drag = "crop";
                    cropRect = {
                        x: p.x,
                        y: p.y,
                        w: 0,
                        h: 0
                    };
                }
                return;
            }
        case "eraser":
            drag = "erase";
            beginGesture();
            eraseAt(p);
            return;
        case "text":
            {
                const hitItem = itemAt(p);
                if (hitItem && (hitItem.kind === "text" || hitItem.kind === "callout"))
                    startText(p, hitItem);
                else
                    startText(p, null);
                return;
            }
        case "step":
            addItem({
                kind: "step",
                x: p.x,
                y: p.y,
                n: nextStep(),
                colour: (useSecond ? second : colour).toString(),
                size: Math.max(10, thickness * 3 + 12)
            }, false);
            return;
        case "eyedropper":
            sampleColour(p, useSecond);
            return;
        case "pen":
        case "highlighter":
            {
                finishText();
                const hl = tool === "highlighter";
                drag = "draw";
                draftPoints = [p];
                draft = {
                    kind: tool,
                    colour: (useSecond ? second : colour).toString(),
                    width: hl ? Math.max(6, thickness * 4) : thickness,
                    opacity: hl ? 0.4 : penOpacity,
                    points: [p]
                };
                return;
            }
        default:
            {
                finishText();
                const it = makeItem(tool, p, p, useSecond);
                if (!it)
                    return;
                it.useSecond = useSecond;
                drag = "shape";
                draft = it;
                return;
            }
        }
    }

    function onMove(m: var): void {
        hoverPos = Qt.point(m.x, m.y);
        if (!drag)
            return;
        let p = toImage(m.x, m.y);
        const shift = (m.modifiers & Qt.ShiftModifier) !== 0;
        switch (drag) {
        case "pan":
            panX = panOrigin.x - (m.x - panStart.x);
            panY = panOrigin.y - (m.y - panStart.y);
            clampPan();
            return;
        case "draw":
            {
                const last = draftPoints[draftPoints.length - 1];
                if (Math.hypot(p.x - last.x, p.y - last.y) * zoom < 1.2)
                    return;
                draftPoints.push(p);
                draft = Object.assign({}, draft, {
                    points: draftPoints.slice()
                });
                return;
            }
        case "shape":
            {
                if (shift && tool !== "magnifier")
                    p = G.constrain(tool, dragStart, p);
                const it = makeItem(tool, dragStart, p, draft.useSecond);
                it.useSecond = draft.useSecond;
                draft = it;
                return;
            }
        case "move":
            {
                const dx = p.x - dragStart.x, dy = p.y - dragStart.y;
                doc = Object.assign({}, dragSnapshot, {
                    items: dragSnapshot.items.map(it => selected.includes(it.id) ? G.translate(it, dx, dy) : it)
                });
                return;
            }
        case "resize":
            {
                const snapMap = {};
                for (const it of dragSnapshot.items)
                    snapMap[it.id] = it;
                if (dragHandle === 100 || dragHandle === 101) {
                    const it = snapMap[selected[0]];
                    const other = dragHandle === 100 ? it.points[it.points.length - 1] : it.points[0];
                    if (shift)
                        p = G.constrain(it.kind, other, p);
                    const pts = dragHandle === 100 ? [p, other] : [other, p];
                    doc = Object.assign({}, dragSnapshot, {
                        items: dragSnapshot.items.map(x => x.id === it.id ? Object.assign({}, x, {
                                points: pts
                            }) : x)
                    });
                    return;
                }
                if (dragHandle === 200) {
                    doc = Object.assign({}, dragSnapshot, {
                        items: dragSnapshot.items.map(x => x.id === selected[0] ? Object.assign({}, x, {
                                tx: p.x,
                                ty: p.y
                            }) : x)
                    });
                    return;
                }
                // pictures, text, steps and lenses keep their shape unless Shift is held; others the reverse
                const keepByDefault = selected.some(id => {
                    const k = snapMap[id]?.kind;
                    return k === "image" || k === "text" || k === "step" || k === "magnifier";
                });
                const nb = resizeBox(dragBox, dragHandle, p, keepByDefault !== shift);
                doc = Object.assign({}, dragSnapshot, {
                    items: dragSnapshot.items.map(it => selected.includes(it.id) ? G.transform(it, dragBox, nb) : it)
                });
                return;
            }
        case "band":
            band = G.rectOf(dragStart, p);
            return;
        case "area":
            area = G.rectOf(clampPt(dragStart), clampPt(p));
            return;
        case "crop":
            {
                let q = clampPt(p);
                if (cropRatio > 0) {
                    const dx = q.x - dragStart.x, dy = q.y - dragStart.y;
                    const w = Math.abs(dx);
                    q = clampPt(G.pt(dragStart.x + Math.sign(dx || 1) * w, dragStart.y + Math.sign(dy || 1) * w / cropRatio));
                }
                cropRect = G.rectOf(clampPt(dragStart), q);
                return;
            }
        case "cropMove":
            {
                const dx = p.x - dragStart.x, dy = p.y - dragStart.y;
                cropRect = {
                    x: Math.max(0, Math.min(doc.W - dragBox.w, dragBox.x + dx)),
                    y: Math.max(0, Math.min(doc.H - dragBox.h, dragBox.y + dy)),
                    w: dragBox.w,
                    h: dragBox.h
                };
                return;
            }
        case "cropResize":
            {
                const nb = resizeBox(dragBox, dragHandle, clampPt(p), cropRatio > 0 || shift);
                const x = Math.max(0, nb.x), y = Math.max(0, nb.y);
                cropRect = {
                    x: x,
                    y: y,
                    w: Math.min(doc.W - x, nb.w),
                    h: Math.min(doc.H - y, nb.h)
                };
                return;
            }
        case "erase":
            eraseAt(p);
            return;
        }
    }

    function onRelease(m: var): void {
        const d = drag;
        if (d === "lifting")
            return;
        drag = "";
        switch (d) {
        case "draw":
            {
                let pts = draftPoints.slice();
                if (pts.length === 1)
                    pts.push(G.pt(pts[0].x + 0.01, pts[0].y));
                else if (smoothing && draft.kind === "pen")
                    pts = G.smooth(G.simplify(pts, 1.5 / zoom), 2);
                const it = Object.assign({}, draft, {
                    points: pts
                });
                draft = null;
                draftPoints = [];
                addItem(it, false);
                return;
            }
        case "shape":
            {
                const it = draft;
                draft = null;
                if (!it)
                    return;
                delete it.useSecond;
                const b = G.bounds(it, measure);
                const big = it.kind === "magnifier" ? it.r * zoom > 6 : (!!b && Math.max(b.w, b.h) * zoom > 5);
                if (!big)
                    return;
                addItem(it, false);
                if (it.kind === "callout")
                    startText(null, it);
                return;
            }
        case "move":
        case "resize":
        case "erase":
            endGesture();
            return;
        case "band":
            {
                const r = band;
                band = null;
                if (r && (r.w * zoom > 2 || r.h * zoom > 2)) {
                    const hits = doc.items.filter(it => {
                        if (it.kind === "patch")
                            return false;
                        const b = G.bounds(it, measure);
                        return b && b.x < r.x + r.w && b.x + b.w > r.x && b.y < r.y + r.h && b.y + b.h > r.y;
                    }).map(it => it.id);
                    selected = Array.from(new Set([...selected, ...hits]));
                }
                return;
            }
        case "area":
            if (area && (area.w * zoom < 3 || area.h * zoom < 3))
                area = null;
            return;
        }
    }

    // inside the picture, on whole pixels (areas and crops are pixel-exact)
    function clampPt(p: var): var {
        return G.pt(Math.round(Math.max(0, Math.min(doc.W, p.x))), Math.round(Math.max(0, Math.min(doc.H, p.y))));
    }

    // the eraser's reach in picture pixels: its size, at least 8 screen pixels
    readonly property real eraserReach: Math.max(Math.max(thickness, 6) / 2 + 2, 8 / Math.max(zoom, 0.01))

    function eraseAt(p: var): void {
        const tol = eraserReach;
        const gone = doc.items.filter(it => it.kind !== "patch" && G.hit(it, p, tol, measure)).map(it => it.id);
        if (gone.length)
            doc = withItems(doc.items.filter(it => !gone.includes(it.id)));
    }

    function sampleColour(p: var, toSecond: bool): void {
        if (p.x < 0 || p.y < 0 || p.x >= doc.W || p.y >= doc.H)
            return;
        renderRegion({
            x: Math.floor(p.x),
            y: Math.floor(p.y),
            w: 1,
            h: 1
        }, {}, result => {
            const tmp = `${sessionDir}/pick-${Date.now()}.png`;
            if (!result.saveToFile(tmp))
                return;
            sampler.toSecond = toSecond;
            sampler.file = `file://${tmp}`;
            sampler.loadImage(sampler.file);
        });
    }

    // ================= shortcuts =================

    Shortcut {
        sequences: [StandardKey.Undo]
        enabled: !win.editing
        onActivated: win.undo()
    }
    Shortcut {
        sequences: [StandardKey.Redo, "Ctrl+Y"]
        enabled: !win.editing
        onActivated: win.redo()
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        enabled: !win.editing
        onActivated: win.copy()
    }
    Shortcut {
        sequences: [StandardKey.Cut]
        enabled: !win.editing
        onActivated: win.cut()
    }
    Shortcut {
        sequences: [StandardKey.Paste]
        enabled: !win.editing
        onActivated: win.paste()
    }
    Shortcut {
        sequence: "Ctrl+Shift+V"
        enabled: !win.editing
        onActivated: win.pasteAsNew()
    }
    Shortcut {
        sequence: "Ctrl+Shift+C"
        enabled: !win.editing
        onActivated: win.copyToClipboard(win.fullRect(), {})
    }
    Shortcut {
        sequences: [StandardKey.Save]
        onActivated: win.save()
    }
    Shortcut {
        sequence: "Ctrl+Shift+S"
        onActivated: dialogs.saveAs()
    }
    Shortcut {
        sequences: [StandardKey.Open]
        onActivated: openDialog.open()
    }
    Shortcut {
        sequences: [StandardKey.New]
        onActivated: dialogs.newPicture()
    }
    Shortcut {
        sequence: "Ctrl+W"
        onActivated: win.close()
    }
    Shortcut {
        sequence: "Ctrl+R"
        onActivated: dialogs.resize()
    }
    Shortcut {
        sequence: "Ctrl+Shift+R"
        onActivated: dialogs.canvasSize()
    }
    Shortcut {
        sequences: [StandardKey.SelectAll]
        enabled: !win.editing
        onActivated: win.selectAll()
    }
    Shortcut {
        sequence: "Ctrl+D"
        enabled: !win.editing
        onActivated: win.duplicate()
    }
    Shortcut {
        sequences: [StandardKey.Delete, "Backspace"]
        enabled: !win.editing
        onActivated: {
            if (win.area)
                win.eraseArea();
            else
                win.removeIds(win.selected);
        }
    }
    Shortcut {
        sequence: "Ctrl+]"
        enabled: !win.editing
        onActivated: win.reorder("forward")
    }
    Shortcut {
        sequence: "Ctrl+["
        enabled: !win.editing
        onActivated: win.reorder("backward")
    }
    Shortcut {
        sequences: ["Ctrl+Shift+]", "Ctrl+}"]
        enabled: !win.editing
        onActivated: win.reorder("front")
    }
    Shortcut {
        sequences: ["Ctrl+Shift+[", "Ctrl+{"]
        enabled: !win.editing
        onActivated: win.reorder("back")
    }
    Shortcut {
        sequences: ["Ctrl++", "Ctrl+=", "+", "="]
        enabled: !win.editing
        onActivated: win.zoomStep(1)
    }
    Shortcut {
        sequences: ["Ctrl+-", "-"]
        enabled: !win.editing
        onActivated: win.zoomStep(-1)
    }
    Shortcut {
        sequence: "Ctrl+0"
        onActivated: win.zoomFit()
    }
    Shortcut {
        sequence: "Ctrl+1"
        onActivated: win.zoomTo(1)
    }
    Shortcut {
        sequences: ["F1", "Ctrl+/", "?"]
        enabled: !win.editing
        onActivated: dialogs.shortcuts()
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: !win.editing && win.tool === "crop"
        onActivated: {
            win.crop(win.cropRect);
            win.setTool("select");
        }
    }
    Shortcut {
        sequence: "Escape"
        enabled: !dialogs.anyOpen
        onActivated: {
            if (win.editing)
                win.finishText();
            else if (win.drag) {
                win.drag = "";
                win.draft = null;
                win.band = null;
                if (win.gestureBase) {
                    win.doc = win.gestureBase;
                    win.gestureBase = null;
                }
            } else if (win.tool === "crop")
                win.setTool("select");
            else if (win.area)
                win.area = null;
            else if (win.selected.length)
                win.selected = [];
            else if (win.tool === "eyedropper")
                win.setTool(win.prevTool);
        }
    }
    Shortcut {
        sequence: "Left"
        enabled: !win.editing && win.selected.length > 0
        onActivated: win.nudge(-1, 0)
    }
    Shortcut {
        sequence: "Right"
        enabled: !win.editing && win.selected.length > 0
        onActivated: win.nudge(1, 0)
    }
    Shortcut {
        sequence: "Up"
        enabled: !win.editing && win.selected.length > 0
        onActivated: win.nudge(0, -1)
    }
    Shortcut {
        sequence: "Down"
        enabled: !win.editing && win.selected.length > 0
        onActivated: win.nudge(0, 1)
    }
    Shortcut {
        sequence: "Shift+Left"
        enabled: !win.editing && win.selected.length > 0
        onActivated: win.nudge(-10, 0)
    }
    Shortcut {
        sequence: "Shift+Right"
        enabled: !win.editing && win.selected.length > 0
        onActivated: win.nudge(10, 0)
    }
    Shortcut {
        sequence: "Shift+Up"
        enabled: !win.editing && win.selected.length > 0
        onActivated: win.nudge(0, -10)
    }
    Shortcut {
        sequence: "Shift+Down"
        enabled: !win.editing && win.selected.length > 0
        onActivated: win.nudge(0, 10)
    }

    // One-key tools
    Instantiator {
        model: Tools.list

        delegate: Shortcut {
            required property var modelData

            sequence: modelData.key
            enabled: !win.editing && !dialogs.anyOpen
            onActivated: win.setTool(modelData.id)
        }
    }

    // ================= helpers that aren't visible =================

    ListModel {
        id: itemModel
    }

    Timer {
        id: autosave

        interval: 800
        onTriggered: win.writeSession()
    }

    Timer {
        id: toastTimer

        interval: 2600
        onTriggered: win.toast = ""
    }

    Timer {
        id: exportTimer

        property var done
        property size size

        interval: 50
        onTriggered: {
            exportSrc.scheduleUpdate();
            exporter.grabToImage(result => {
                exporter.visible = false;
                win.exportOnly = null;
                win.exportPixelsOnly = false;
                exportTimer.done(result);
            }, exportTimer.size);
        }
    }

    FileView {
        id: sessionFile

        path: win.sessionDir ? `${win.sessionDir}/doc.json` : ""
        atomicWrites: true
        printErrors: false
        preload: false
    }

    // The base picture's size, before showing it
    Image {
        id: baseProbe

        property string path

        visible: false
        asynchronous: true
        cache: false
        onStatusChanged: {
            if (status === Image.Ready && path) {
                const w = implicitWidth, h = implicitHeight;
                win.doc = {
                    W: w,
                    H: h,
                    bg: "#00000000",
                    base: {
                        src: path,
                        x: 0,
                        y: 0,
                        w: w,
                        h: h
                    },
                    items: []
                };
                win.history = [];
                win.future = [];
                win.ready = true;
                win.loadError = "";
                win.zoomFit();
                // a pen that suits the picture's size
                if (win.app.prefs.thickness === undefined)
                    win.thickness = Math.max(2, Math.min(12, Math.round(Math.max(w, h) / 400)));
                path = "";
            } else if (status === Image.Error && path) {
                win.loadError = Tr.tr("Couldn't open %1").arg(path.split("/").pop());
                win.ready = false;
                path = "";
            }
        }
    }

    Component {
        id: probeComp

        Image {
            property string path
            property var done

            visible: false
            asynchronous: true
            cache: false
            onStatusChanged: {
                if (status === Image.Ready) {
                    done(implicitWidth, implicitHeight);
                    destroy();
                } else if (status === Image.Error) {
                    win.showToast(Tr.tr("Couldn't read that picture"));
                    destroy();
                }
            }
        }
    }

    Component {
        id: writeProc

        Process {
            property var result
            property string target
            property var done

            onExited: code => {
                if (code === 3)
                    done(result.saveToFile(target));
                else
                    done(code === 0);
                destroy();
            }
        }
    }

    // A free file name for the first save
    Process {
        id: freeName

        property string dir
        property string base

        command: ["sh", "-c", 'mkdir -p "$1"; p="$1/$2.png"; n=2; while [ -e "$p" ]; do p="$1/$2-$n.png"; n=$((n+1)); done; printf %s "$p"', "sh", dir, base]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p)
                    win.saveTo(p);
            }
        }
    }

    // Reads the clipboard: a picture (saved into the session), image files, or text
    Process {
        id: pasteProc

        property bool asNew
        property string dir

        command: ["sh", Quickshell.shellPath("assets/paint-paste.sh"), dir]
        stdout: StdioCollector {
            onStreamFinished: win.handlePaste(text, pasteProc.asNew)
        }
    }

    // The eyedropper's one sampled pixel
    Canvas {
        id: sampler

        property bool toSecond
        property string file

        width: 1
        height: 1
        visible: false
        onImageLoaded: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, 1, 1);
            ctx.drawImage(file, 0, 0);
            const px = ctx.getImageData(0, 0, 1, 1).data;
            const c = Qt.rgba(px[0] / 255, px[1] / 255, px[2] / 255, 1);
            unloadImage(file);
            Quickshell.execDetached(["rm", "-f", file.replace("file://", "")]);
            win.setProp(toSecond ? "second" : "colour", c);
            win.rememberColour(c);
            win.setTool(win.prevTool === "eyedropper" ? "pen" : win.prevTool);
        }
    }

    FileDialog {
        id: openDialog

        title: Tr.tr("Open a picture")
        filterLabel: Tr.tr("Image files")
        filters: ["png", "jpg", "jpeg", "webp", "bmp", "gif", "tif", "tiff", "svg", "avif", "heic"]
        onAccepted: path => win.openFile(path)
    }

    // ================= layout =================

    Item {
        id: rootItem

        anchors.fill: parent

        TopBar {
            id: topBar

            win: win
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
        }

        ToolRail {
            id: rail

            win: win
            anchors.top: topBar.bottom
            anchors.left: parent.left
            anchors.bottom: propsBar.top
            anchors.leftMargin: Tokens.padding.small
        }

        // ---- the picture ----
        Item {
            id: viewport

            anchors.top: topBar.bottom
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: propsBar.top
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.small
            clip: true

            onWidthChanged: win.clampPan()
            onHeightChanged: win.clampPan()

            Item {
                id: stage

                x: win.stageX
                y: win.stageY
                width: win.stageW
                height: win.stageH
                visible: win.ready

                // what shows through transparent pixels
                Checker {
                    anchors.fill: parent
                    cell: 10
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    color: "transparent"
                    border.color: Colours.palette.m3outlineVariant
                }

                // The picture at its own size, scaled for the view
                Item {
                    id: page

                    width: win.doc.W
                    height: win.doc.H
                    scale: win.zoom
                    transformOrigin: Item.TopLeft
                    clip: true

                    Item {
                        id: pageRoot

                        width: win.doc.W
                        height: win.doc.H

                        // picture, background and pasted images
                        Item {
                            id: pixelLayer

                            anchors.fill: parent

                            Rectangle {
                                anchors.fill: parent
                                color: win.doc.bg
                                visible: !win.exportOnly
                            }

                            Image {
                                visible: !!win.doc.base && !win.exportOnly
                                x: win.doc.base?.x ?? 0
                                y: win.doc.base?.y ?? 0
                                width: win.doc.base?.w ?? 0
                                height: win.doc.base?.h ?? 0
                                source: win.doc.base ? `file://${win.doc.base.src}` : ""
                                sourceSize: win.doc.base && win.doc.base.src.toLowerCase().endsWith(".svg") ? Qt.size(2048, 2048) : Qt.size(-1, -1)
                                cache: false
                                smooth: win.zoom < 3
                                mipmap: true
                            }

                            Repeater {
                                model: itemModel

                                delegate: Item {
                                    id: pxDelegate

                                    required property int uid
                                    readonly property var d: win.itemMap[uid] ?? null

                                    anchors.fill: parent
                                    visible: !!d && (d.kind === "image" || d.kind === "patch") && (!win.exportOnly || win.exportOnly.includes(uid))

                                    Loader {
                                        anchors.fill: parent
                                        active: pxDelegate.d?.kind === "image"

                                        sourceComponent: PaintItem {
                                            d: pxDelegate.d
                                            docWidth: win.doc.W
                                            docHeight: win.doc.H
                                        }
                                    }

                                    Rectangle {
                                        visible: pxDelegate.d?.kind === "patch"
                                        x: pxDelegate.d?.x ?? 0
                                        y: pxDelegate.d?.y ?? 0
                                        width: pxDelegate.d?.w ?? 0
                                        height: pxDelegate.d?.h ?? 0
                                        color: pxDelegate.d?.colour ?? "white"
                                    }
                                }
                            }
                        }

                        // drawings, in their order
                        Item {
                            id: drawLayer

                            anchors.fill: parent
                            visible: !win.exportPixelsOnly

                            Repeater {
                                model: itemModel

                                delegate: PaintItem {
                                    required property int uid

                                    d: win.itemMap[uid] ?? null
                                    pixels: pixelLayer
                                    docWidth: win.doc.W
                                    docHeight: win.doc.H
                                    visible: !!d && d.kind !== "image" && d.kind !== "patch" && !(win.editing && win.editing.id === uid && d.kind === "text") && (!win.exportOnly || win.exportOnly.includes(uid))
                                    onTextSizeChanged: {
                                        if (d?.kind === "text") {
                                            const m = Object.assign({}, win.textSizes);
                                            m[uid] = textSize;
                                            win.textSizes = m;
                                        }
                                    }
                                }
                            }

                            // what's being drawn
                            PaintItem {
                                d: win.draft
                                pixels: pixelLayer
                                docWidth: win.doc.W
                                docHeight: win.doc.H
                                visible: !!win.draft
                            }

                            // typing: in place, at the text's real size
                            TextEdit {
                                id: textEditor

                                readonly property var target: win.editing && win.editing.id >= 0 ? win.itemMap[win.editing.id] ?? null : null
                                readonly property bool isCallout: win.editing?.kind === "callout"
                                readonly property string boxColour: target ? (target.box ?? "") : (win.box ? win.second.toString() : "")
                                readonly property real pad: isCallout ? Math.max(6, (target?.size ?? 20) * 0.5) : (boxColour !== "" ? Math.round((target?.size ?? win.fontSize) * 0.3) : 0)

                                visible: !!win.editing
                                x: (isCallout ? (target?.x ?? 0) : (win.editing?.x ?? 0)) + pad
                                y: (isCallout ? (target?.y ?? 0) : (win.editing?.y ?? 0)) + pad
                                width: isCallout ? Math.max(10, (target?.w ?? 0) - pad * 2) : Math.max(implicitWidth, 4)
                                height: isCallout ? Math.max(10, (target?.h ?? 0) - pad * 2) : implicitHeight
                                wrapMode: isCallout ? TextEdit.Wrap : TextEdit.NoWrap
                                horizontalAlignment: isCallout ? TextEdit.AlignHCenter : TextEdit.AlignLeft
                                verticalAlignment: isCallout ? TextEdit.AlignVCenter : TextEdit.AlignTop
                                color: isCallout ? G.contrastOn(Qt.color(target?.fillColour ?? "white")) : (target?.colour ?? win.colour)
                                font.family: target?.family ?? win.family
                                font.pixelSize: Math.max(4, Math.round(target?.size ?? win.fontSize))
                                font.bold: isCallout ? false : (target?.bold ?? win.bold)
                                font.italic: isCallout ? false : (target?.italic ?? win.italic)
                                selectByMouse: true
                                cursorDelegate: Rectangle {
                                    width: Math.max(1, 2 / win.zoom)
                                    color: textEditor.color
                                }
                                Keys.onPressed: e => {
                                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) {
                                        win.finishText();
                                        e.accepted = true;
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -textEditor.pad
                                    z: -1
                                    visible: !textEditor.isCallout && textEditor.boxColour !== ""
                                    radius: textEditor.pad
                                    color: textEditor.boxColour || "transparent"
                                }
                            }
                        }
                    }
                }

                // ---- screen-space overlays: selection, area, crop ----
                Item {
                    id: overlays

                    readonly property real zf: win.zoom

                    anchors.fill: parent

                    // text being edited
                    Rectangle {
                        visible: !!win.editing
                        x: (textEditor.x - textEditor.pad) * overlays.zf - 6
                        y: (textEditor.y - textEditor.pad) * overlays.zf - 6
                        width: (textEditor.width + textEditor.pad * 2) * overlays.zf + 12
                        height: (textEditor.height + textEditor.pad * 2) * overlays.zf + 12
                        color: "transparent"
                        radius: 4
                        border.width: 1.5
                        border.color: Colours.palette.m3primary
                    }

                    // selection
                    Item {
                        id: selOverlay

                        readonly property var b: win.selBox ?? {
                            x: 0,
                            y: 0,
                            w: 0,
                            h: 0
                        }
                        readonly property bool lineEnds: !!win.selItem && (win.selItem.kind === "line" || win.selItem.kind === "arrow")

                        anchors.fill: parent
                        visible: win.tool === "select" && !!win.selBox && !win.editing && win.drag !== "move"

                        Rectangle {
                            x: selOverlay.b.x * overlays.zf - 1
                            y: selOverlay.b.y * overlays.zf - 1
                            width: selOverlay.b.w * overlays.zf + 2
                            height: selOverlay.b.h * overlays.zf + 2
                            color: "transparent"
                            border.width: 1
                            border.color: Colours.palette.m3primary
                            visible: !selOverlay.lineEnds
                        }

                        Repeater {
                            model: selOverlay.lineEnds ? [] : win.handlePoints(selOverlay.b)

                            Rectangle {
                                required property var modelData

                                x: modelData.x * overlays.zf - 5
                                y: modelData.y * overlays.zf - 5
                                width: 10
                                height: 10
                                radius: 3
                                color: "white"
                                border.width: 1.5
                                border.color: Colours.palette.m3primary
                            }
                        }

                        Repeater {
                            model: selOverlay.lineEnds ? [win.selItem.points[0], win.selItem.points[win.selItem.points.length - 1]] : (win.selItem?.kind === "callout" ? [G.pt(win.selItem.tx, win.selItem.ty)] : [])

                            Rectangle {
                                required property var modelData

                                x: modelData.x * overlays.zf - 6
                                y: modelData.y * overlays.zf - 6
                                width: 12
                                height: 12
                                radius: 6
                                color: Colours.palette.m3primary
                                border.width: 2
                                border.color: "white"
                            }
                        }
                    }

                    // rubber band
                    Rectangle {
                        visible: !!win.band
                        x: (win.band?.x ?? 0) * overlays.zf
                        y: (win.band?.y ?? 0) * overlays.zf
                        width: (win.band?.w ?? 0) * overlays.zf
                        height: (win.band?.h ?? 0) * overlays.zf
                        color: Qt.alpha(Colours.palette.m3primary, 0.12)
                        border.width: 1
                        border.color: Colours.palette.m3primary
                    }

                    // area selection: a white and a black outline, visible on any picture
                    Item {
                        visible: !!win.area
                        x: (win.area?.x ?? 0) * overlays.zf
                        y: (win.area?.y ?? 0) * overlays.zf
                        width: (win.area?.w ?? 0) * overlays.zf
                        height: (win.area?.h ?? 0) * overlays.zf

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: "white"
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha("black", 0.7)
                        }
                    }

                    // crop
                    Item {
                        id: cropOverlay

                        readonly property rect r: win.cropRect ? Qt.rect(win.cropRect.x * overlays.zf, win.cropRect.y * overlays.zf, win.cropRect.w * overlays.zf, win.cropRect.h * overlays.zf) : Qt.rect(0, 0, 0, 0)

                        anchors.fill: parent
                        visible: win.tool === "crop" && !!win.cropRect

                        Rectangle {
                            width: parent.width
                            height: cropOverlay.r.y
                            color: Qt.alpha("black", 0.55)
                        }
                        Rectangle {
                            y: cropOverlay.r.y + cropOverlay.r.height
                            width: parent.width
                            height: parent.height - y
                            color: Qt.alpha("black", 0.55)
                        }
                        Rectangle {
                            y: cropOverlay.r.y
                            width: cropOverlay.r.x
                            height: cropOverlay.r.height
                            color: Qt.alpha("black", 0.55)
                        }
                        Rectangle {
                            x: cropOverlay.r.x + cropOverlay.r.width
                            y: cropOverlay.r.y
                            width: parent.width - x
                            height: cropOverlay.r.height
                            color: Qt.alpha("black", 0.55)
                        }
                        Rectangle {
                            x: cropOverlay.r.x
                            y: cropOverlay.r.y
                            width: cropOverlay.r.width
                            height: cropOverlay.r.height
                            color: "transparent"
                            border.color: "white"
                            border.width: 2
                        }
                        // rule of thirds
                        Repeater {
                            model: 2

                            Item {
                                id: thirds

                                required property int index

                                Rectangle {
                                    x: cropOverlay.r.x + cropOverlay.r.width * (thirds.index + 1) / 3
                                    y: cropOverlay.r.y
                                    width: 1
                                    height: cropOverlay.r.height
                                    color: Qt.alpha("white", 0.45)
                                }
                                Rectangle {
                                    x: cropOverlay.r.x
                                    y: cropOverlay.r.y + cropOverlay.r.height * (thirds.index + 1) / 3
                                    width: cropOverlay.r.width
                                    height: 1
                                    color: Qt.alpha("white", 0.45)
                                }
                            }
                        }
                        Repeater {
                            model: win.cropRect ? win.handlePoints(win.cropRect) : []

                            Rectangle {
                                required property var modelData

                                x: modelData.x * overlays.zf - 6
                                y: modelData.y * overlays.zf - 6
                                width: 12
                                height: 12
                                radius: 3
                                color: "white"
                                border.width: 1
                                border.color: "black"
                            }
                        }
                    }
                }
            }

            // eraser: its reach as a ring under the pointer (black and white: visible on any picture)
            Rectangle {
                readonly property real r: win.eraserReach * win.zoom

                visible: win.tool === "eraser" && win.hovering
                x: win.hoverPos.x - r
                y: win.hoverPos.y - r
                width: r * 2
                height: r * 2
                radius: r
                color: Qt.alpha("white", 0.2)
                border.width: 1.5
                border.color: "black"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1.5
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "white"
                }
            }

            MouseArea {
                id: canvasInput

                anchors.fill: parent
                enabled: win.ready
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                focus: true
                cursorShape: {
                    if (win.drag === "pan")
                        return Qt.ClosedHandCursor;
                    if (win.spaceHeld || win.tool === "hand")
                        return Qt.OpenHandCursor;
                    switch (win.tool) {
                    case "select":
                        return Qt.ArrowCursor;
                    case "text":
                        return Qt.IBeamCursor;
                    case "eraser":
                        return Qt.BlankCursor;
                    case "eyedropper":
                    case "step":
                        return Qt.PointingHandCursor;
                    default:
                        return Qt.CrossCursor;
                    }
                }
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
                        win.spaceHeld = true;
                        e.accepted = true;
                    }
                }
                Keys.onReleased: e => {
                    if (e.key === Qt.Key_Space && !e.isAutoRepeat) {
                        win.spaceHeld = false;
                        e.accepted = true;
                    }
                }
                onEntered: win.hovering = true
                onExited: win.hovering = false
                onPressed: m => {
                    forceActiveFocus();
                    win.onPress(m);
                }
                onPositionChanged: m => win.onMove(m)
                onReleased: m => win.onRelease(m)
                onDoubleClicked: m => {
                    if (win.tool !== "select")
                        return;
                    const hitItem = win.itemAt(win.toImage(m.x, m.y));
                    if (hitItem && (hitItem.kind === "text" || hitItem.kind === "callout"))
                        win.startText(null, hitItem);
                }
                onWheel: w => {
                    if (w.modifiers & Qt.ControlModifier) {
                        const steps = (w.angleDelta.y || w.pixelDelta.y) / 120;
                        win.zoomAt(win.zoom * Math.pow(1.15, steps), w.x, w.y);
                        return;
                    }
                    if (win.stageW + 48 <= viewport.width && win.stageH + 48 <= viewport.height)
                        return;
                    if (win.fitMode) {
                        win.zoomValue = win.zoom;
                        win.panX = 24 - win.stageX;
                        win.panY = 24 - win.stageY;
                        win.fitMode = false;
                    }
                    // a wheel's notches (multiples of 120) scroll ~96 px each; touchpads scroll by their pixels
                    const notches = (w.angleDelta.x % 120 === 0 && w.angleDelta.y % 120 === 0) && (w.angleDelta.x || w.angleDelta.y);
                    const dx = notches ? w.angleDelta.x * 0.8 : (w.pixelDelta.x || w.angleDelta.x / 2);
                    const dy = notches ? w.angleDelta.y * 0.8 : (w.pixelDelta.y || w.angleDelta.y / 2);
                    if (w.modifiers & Qt.ShiftModifier)
                        win.panX -= dy;
                    else {
                        win.panX -= dx;
                        win.panY -= dy;
                    }
                    win.clampPan();
                }
            }

            PinchHandler {
                property real startZoom: 1

                target: null
                onActiveChanged: if (active)
                    startZoom = win.zoom
                onActiveScaleChanged: win.zoomAt(startZoom * activeScale, centroid.position.x, centroid.position.y)
            }

            DropArea {
                anchors.fill: parent
                onDropped: drop => {
                    if (!drop.hasUrls)
                        return;
                    const paths = drop.urls.map(u => decodeURIComponent(u.toString().replace(/^file:\/\//, ""))).filter(p => win.isImagePath(p));
                    if (!paths.length)
                        return;
                    const at = win.toImage(drop.x, drop.y);
                    if (win.untouched && paths.length === 1) {
                        win.openFile(paths[0]);
                    } else {
                        for (const p of paths)
                            win.probeImage(p, (w, h) => win.insertImage(p, w, h, at));
                    }
                    drop.accept();
                }
            }

            // ---- opening, failed to open ----
            Column {
                anchors.centerIn: parent
                spacing: Tokens.spacing.medium
                visible: !win.ready

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.loadError ? "broken_image" : "image"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.loadError || Tr.tr("Opening…")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                }

                TextButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !!win.loadError
                    type: TextButton.Tonal
                    text: Tr.tr("Open another picture")
                    onClicked: openDialog.open()
                }
            }

            // ---- unsaved pictures from earlier ----
            StyledRect {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Tokens.padding.small
                visible: win.app.unsaved.length > 0
                implicitWidth: restoreRow.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: restoreRow.implicitHeight + Tokens.padding.small * 2
                radius: height / 2
                color: Colours.palette.m3secondaryContainer
                z: 10

                Row {
                    id: restoreRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "history"
                        color: Colours.palette.m3onSecondaryContainer
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.app.unsaved.length === 1 ? Tr.tr("A picture wasn't saved last time") : Tr.tr("%1 pictures weren't saved last time").arg(win.app.unsaved.length)
                        color: Colours.palette.m3onSecondaryContainer
                    }

                    TextButton {
                        anchors.verticalCenter: parent.verticalCenter
                        type: TextButton.Filled
                        text: Tr.tr("Restore")
                        onClicked: win.app.restoreAll(win)
                    }

                    TextButton {
                        anchors.verticalCenter: parent.verticalCenter
                        type: TextButton.Text
                        text: Tr.tr("Discard")
                        onClicked: win.app.discardUnsaved()
                    }
                }
            }

            // ---- short messages ----
            StyledRect {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Tokens.padding.medium
                visible: opacity > 0
                opacity: win.toast ? 1 : 0
                implicitWidth: toastText.implicitWidth + Tokens.padding.large * 2
                implicitHeight: toastText.implicitHeight + Tokens.padding.small * 2
                radius: height / 2
                color: Colours.palette.m3inverseSurface
                z: 10

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                StyledText {
                    id: toastText

                    anchors.centerIn: parent
                    text: win.toast
                    color: Colours.palette.m3inverseOnSurface
                }
            }

            // where the right-click menu opens
            Item {
                id: contextAnchor

                width: 1
                height: 1
            }
        }

        PropsBar {
            id: propsBar

            win: win
            anchors.bottom: statusBar.top
            anchors.left: parent.left
            anchors.right: parent.right
        }

        StatusBar {
            id: statusBar

            win: win
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
        }

        // right-click menu (Select tool)
        Menu {
            id: contextMenu

            parent: rootItem
            attachTo: contextAnchor
            attachSideX: Menu.Left
            attachSideY: Menu.Top
            thisSideX: Menu.Left
            thisSideY: Menu.Top
            active: null
            items: win.selected.length ? [ctxCopy, ctxCut, ctxDuplicate, ctxFront, ctxBack, ctxDelete] : [ctxPaste, ctxSelectAll]
        }

        MenuItem {
            id: ctxCopy

            text: Tr.tr("Copy")
            icon: "content_copy"
            onClicked: win.copy()
        }
        MenuItem {
            id: ctxCut

            text: Tr.tr("Cut")
            icon: "content_cut"
            onClicked: win.cut()
        }
        MenuItem {
            id: ctxDuplicate

            text: Tr.tr("Duplicate")
            icon: "control_point_duplicate"
            onClicked: win.duplicate()
        }
        MenuItem {
            id: ctxFront

            text: Tr.tr("Bring to front")
            icon: "flip_to_front"
            onClicked: win.reorder("front")
        }
        MenuItem {
            id: ctxBack

            text: Tr.tr("Send to back")
            icon: "flip_to_back"
            onClicked: win.reorder("back")
        }
        MenuItem {
            id: ctxDelete

            text: Tr.tr("Delete")
            icon: "delete"
            onClicked: win.removeIds(win.selected)
        }
        MenuItem {
            id: ctxPaste

            text: Tr.tr("Paste")
            icon: "content_paste"
            onClicked: win.paste()
        }
        MenuItem {
            id: ctxSelectAll

            text: Tr.tr("Select all")
            icon: "select_all"
            onClicked: win.selectAll()
        }

        PaintDialogs {
            id: dialogs

            win: win
            anchors.fill: parent
        }

        // renders regions for saving, copying and the eyedropper (off screen)
        Item {
            id: exporter

            x: -100000
            visible: false

            ShaderEffectSource {
                id: exportSrc

                sourceItem: exporter.visible ? (win.exportPixelsOnly ? pixelLayer : pageRoot) : null
                live: true
                hideSource: false
                smooth: false
                transform: Matrix4x4 {
                    id: exportMatrix
                }
            }
        }
    }
}

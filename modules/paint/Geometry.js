.pragma library

// Paint geometry: everything here works in image pixels and is independent of the zoom, so a
// picture looks (and saves) the same at any window size.
//
// Item kinds and their fields (all coordinates in image pixels):
//   pen, highlighter      points[], colour, width, opacity
//   line, arrow           points[a, b], colour, width, opacity, dash, head ("open"|"filled"), both
//   rect, ellipse         points[a, b], colour, width, opacity, dash, fill ("none"|"solid"|"second"),
//                         fillColour, radius (rect corners)
//   text                  x, y, text, colour, size, family, bold, italic, box ("" or a colour), outline
//   image                 x, y, w, h, src, opacity        (drawn under all drawings, with the picture)
//   redact                x, y, w, h, mode ("pixelate"|"blur"|"box"), strength, colour
//   step                  x, y (centre), n, colour, size (radius)
//   callout               x, y, w, h, tx, ty (tail tip), text, colour, fillColour, size, family
//   spotlight             x, y, w, h, shape ("rect"|"ellipse"), dim
//   magnifier             x, y (centre), r, zoom

function pt(x, y) {
    return {
        x: x,
        y: y
    };
}

function rectOf(a, b) {
    return {
        x: Math.min(a.x, b.x),
        y: Math.min(a.y, b.y),
        w: Math.abs(b.x - a.x),
        h: Math.abs(b.y - a.y)
    };
}

function isBoxKind(kind) {
    return kind === "image" || kind === "redact" || kind === "callout" || kind === "spotlight";
}

function isPointsKind(kind) {
    return kind === "pen" || kind === "highlighter" || kind === "line" || kind === "arrow" || kind === "rect" || kind === "ellipse";
}

// The arrowhead in image pixels: a function of the line width only
function arrowHead(a, b, width, filled) {
    const ang = Math.atan2(b.y - a.y, b.x - a.x);
    const full = Math.hypot(b.x - a.x, b.y - a.y);
    const len = Math.min(full * 0.6, width * 3 + 10);
    const spread = filled ? 0.42 : 0.5;
    return [pt(b.x - len * Math.cos(ang - spread), b.y - len * Math.sin(ang - spread)), pt(b.x, b.y), pt(b.x - len * Math.cos(ang + spread), b.y - len * Math.sin(ang + spread))];
}

// Where a line or arrow's shaft should end so a filled head's tip stays sharp
function shaftEnd(a, b, width, filled) {
    if (!filled)
        return b;
    const full = Math.hypot(b.x - a.x, b.y - a.y);
    if (full < 1)
        return b;
    const len = Math.min(full * 0.6, width * 3 + 10) * 0.8;
    return pt(b.x - (b.x - a.x) / full * len, b.y - (b.y - a.y) / full * len);
}

function ellipsePoints(r, n) {
    const pts = [];
    const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
    for (let i = 0; i <= n; i++)
        pts.push(pt(cx + r.w / 2 * Math.cos(i / n * Math.PI * 2), cy + r.h / 2 * Math.sin(i / n * Math.PI * 2)));
    return pts;
}

function roundedRectPoints(r, rad) {
    rad = Math.max(0, Math.min(rad || 0, r.w / 2, r.h / 2));
    if (rad < 0.5)
        return [pt(r.x, r.y), pt(r.x + r.w, r.y), pt(r.x + r.w, r.y + r.h), pt(r.x, r.y + r.h), pt(r.x, r.y)];
    const pts = [];
    const corner = (cx, cy, a0) => {
        for (let i = 0; i <= 8; i++) {
            const a = a0 + i / 8 * Math.PI / 2;
            pts.push(pt(cx + rad * Math.cos(a), cy + rad * Math.sin(a)));
        }
    };
    corner(r.x + r.w - rad, r.y + rad, -Math.PI / 2);
    corner(r.x + r.w - rad, r.y + r.h - rad, 0);
    corner(r.x + rad, r.y + r.h - rad, Math.PI / 2);
    corner(r.x + rad, r.y + rad, Math.PI);
    pts.push(pts[0]);
    return pts;
}

// A speech bubble: rounded box with a tail towards (tx, ty)
function calloutPoints(it) {
    const r = {
        x: it.x,
        y: it.y,
        w: it.w,
        h: it.h
    };
    const box = roundedRectPoints(r, Math.min(18, r.w / 4, r.h / 4));
    const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
    const inside = it.tx >= r.x && it.tx <= r.x + r.w && it.ty >= r.y && it.ty <= r.y + r.h;
    if (inside)
        return box;
    // the tail leaves from the side facing the tip
    const dx = it.tx - cx, dy = it.ty - cy;
    const base = Math.max(10, Math.min(r.w, r.h) * 0.22);
    let p1, p2;
    if (Math.abs(dx) / r.w > Math.abs(dy) / r.h) {
        const x = dx > 0 ? r.x + r.w : r.x;
        const y = Math.max(r.y + base, Math.min(r.y + r.h - base, cy + dy * 0.3));
        p1 = pt(x, y - base / 2);
        p2 = pt(x, y + base / 2);
    } else {
        const y = dy > 0 ? r.y + r.h : r.y;
        const x = Math.max(r.x + base, Math.min(r.x + r.w - base, cx + dx * 0.3));
        p1 = pt(x - base / 2, y);
        p2 = pt(x + base / 2, y);
    }
    // Insert the tail into the outline at the point of the box nearest to p1/p2's middle
    const mid = pt((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
    let best = 0, bd = Infinity;
    for (let i = 0; i < box.length - 1; i++) {
        const d = Math.hypot(box[i].x - mid.x, box[i].y - mid.y);
        if (d < bd) {
            bd = d;
            best = i;
        }
    }
    const before = box.slice(0, best + 1);
    const after = box.slice(best + 1);
    // order p1/p2 along the outline direction (clockwise)
    const cross = (p2.x - p1.x) * (mid.y - cy) - (p2.y - p1.y) * (mid.x - cx);
    const first = cross > 0 ? p2 : p1, second = cross > 0 ? p1 : p2;
    return before.concat([first, pt(it.tx, it.ty), second]).concat(after);
}

// The polylines an item is drawn with: [main, extra] (extra = arrowheads)
function strokesOf(d) {
    if (!d || !d.points)
        return [[], []];
    const p = d.points;
    if (d.kind === "pen" || d.kind === "highlighter")
        return [p, []];
    const a = p[0], b = p[p.length - 1];
    if (!a || !b)
        return [[], []];
    if (d.kind === "line")
        return [[a, b], []];
    if (d.kind === "arrow") {
        const filled = d.head === "filled";
        const extra = [arrowHead(a, b, d.width, filled)];
        let s = a, e = shaftEnd(a, b, d.width, filled);
        if (d.both) {
            extra.push(arrowHead(b, a, d.width, filled));
            s = shaftEnd(b, a, d.width, filled);
        }
        return [[s, e], extra];
    }
    if (d.kind === "rect")
        return [roundedRectPoints(rectOf(a, b), d.radius), []];
    if (d.kind === "ellipse")
        return [ellipsePoints(rectOf(a, b), 120), []];
    return [[], []];
}

// Chaikin smoothing for freehand strokes (keeps both ends)
function smooth(points, passes) {
    let p = points;
    if (p.length < 3)
        return p;
    for (let k = 0; k < passes; k++) {
        const out = [p[0]];
        for (let i = 0; i < p.length - 1; i++) {
            const a = p[i], b = p[i + 1];
            out.push(pt(a.x * 0.75 + b.x * 0.25, a.y * 0.75 + b.y * 0.25));
            out.push(pt(a.x * 0.25 + b.x * 0.75, a.y * 0.25 + b.y * 0.75));
        }
        out.push(p[p.length - 1]);
        p = out;
    }
    return p;
}

// Drops points closer than `minDist` to the previous kept one
function simplify(points, minDist) {
    if (points.length < 3)
        return points;
    const out = [points[0]];
    for (let i = 1; i < points.length - 1; i++) {
        const l = out[out.length - 1];
        if (Math.hypot(points[i].x - l.x, points[i].y - l.y) >= minDist)
            out.push(points[i]);
    }
    out.push(points[points.length - 1]);
    return out;
}

function polyBounds(pts) {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const q of pts) {
        x0 = Math.min(x0, q.x);
        y0 = Math.min(y0, q.y);
        x1 = Math.max(x1, q.x);
        y1 = Math.max(y1, q.y);
    }
    return x0 === Infinity ? null : {
        x: x0,
        y: y0,
        w: x1 - x0,
        h: y1 - y0
    };
}

// The item's box in image pixels. `measure(item)` gives {w, h} of a text item's laid-out text.
function bounds(it, measure) {
    if (!it)
        return null;
    if (isPointsKind(it.kind)) {
        const s = strokesOf(it);
        const b = polyBounds(s[0].concat(...s[1]));
        if (!b)
            return null;
        const pad = (it.kind === "highlighter" ? it.width : it.width / 2);
        return {
            x: b.x - pad,
            y: b.y - pad,
            w: b.w + pad * 2,
            h: b.h + pad * 2
        };
    }
    if (isBoxKind(it.kind)) {
        if (it.kind === "callout") {
            const b = polyBounds([pt(it.x, it.y), pt(it.x + it.w, it.y + it.h), pt(it.tx, it.ty)]);
            return b;
        }
        return {
            x: it.x,
            y: it.y,
            w: it.w,
            h: it.h
        };
    }
    if (it.kind === "text") {
        const m = measure ? measure(it) : {
            w: it.size * Math.max(1, (it.text || "").length) * 0.6,
            h: it.size * 1.3
        };
        return {
            x: it.x,
            y: it.y,
            w: m.w,
            h: m.h
        };
    }
    if (it.kind === "step")
        return {
            x: it.x - it.size,
            y: it.y - it.size,
            w: it.size * 2,
            h: it.size * 2
        };
    if (it.kind === "magnifier")
        return {
            x: it.x - it.r,
            y: it.y - it.r,
            w: it.r * 2,
            h: it.r * 2
        };
    return null;
}

function unionBounds(list) {
    let r = null;
    for (const b of list) {
        if (!b)
            continue;
        if (!r)
            r = Object.assign({}, b);
        else {
            const x1 = Math.max(r.x + r.w, b.x + b.w), y1 = Math.max(r.y + r.h, b.y + b.h);
            r.x = Math.min(r.x, b.x);
            r.y = Math.min(r.y, b.y);
            r.w = x1 - r.x;
            r.h = y1 - r.y;
        }
    }
    return r;
}

function distToSegment(p, a, b) {
    const dx = b.x - a.x, dy = b.y - a.y;
    const l2 = dx * dx + dy * dy;
    let t = l2 === 0 ? 0 : ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2;
    t = Math.max(0, Math.min(1, t));
    return Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
}

function distToPoly(p, pts) {
    let d = Infinity;
    for (let i = 0; i < pts.length - 1; i++)
        d = Math.min(d, distToSegment(p, pts[i], pts[i + 1]));
    if (pts.length === 1)
        d = Math.hypot(p.x - pts[0].x, p.y - pts[0].y);
    return d;
}

function pointInPoly(p, pts) {
    let inside = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
        const a = pts[i], b = pts[j];
        if ((a.y > p.y) !== (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)
            inside = !inside;
    }
    return inside;
}

function inRect(p, r) {
    return p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h;
}

// Does a click at p (image pixels, `tol` = tolerance in image pixels) hit the item?
function hit(it, p, tol, measure) {
    if (isPointsKind(it.kind)) {
        const s = strokesOf(it);
        const reach = (it.kind === "highlighter" ? it.width * 2 : it.width) / 2 + tol;
        if (distToPoly(p, s[0]) <= reach)
            return true;
        for (const e of s[1])
            if (distToPoly(p, e) <= reach)
                return true;
        if ((it.kind === "rect" || it.kind === "ellipse") && it.fill && it.fill !== "none")
            return pointInPoly(p, s[0]);
        return false;
    }
    if (it.kind === "spotlight") {
        // the lit area's edge
        const r = {
            x: it.x,
            y: it.y,
            w: it.w,
            h: it.h
        };
        const outline = it.shape === "ellipse" ? ellipsePoints(r, 60) : roundedRectPoints(r, 0);
        return distToPoly(p, outline) <= tol + 4;
    }
    if (it.kind === "callout")
        return pointInPoly(p, calloutPoints(it)) || distToPoly(p, calloutPoints(it)) <= tol;
    if (it.kind === "step" || it.kind === "magnifier") {
        const r = it.kind === "step" ? it.size : it.r;
        return Math.hypot(p.x - it.x, p.y - it.y) <= r + tol;
    }
    const b = bounds(it, measure);
    return b ? inRect(p, {
        x: b.x - tol,
        y: b.y - tol,
        w: b.w + tol * 2,
        h: b.h + tol * 2
    }) : false;
}

function mapPoint(q, from, to) {
    const sx = from.w > 0 ? to.w / from.w : 1, sy = from.h > 0 ? to.h / from.h : 1;
    return pt(to.x + (q.x - from.x) * sx, to.y + (q.y - from.y) * sy);
}

// The item moved and scaled from box `from` to box `to` (a move is a same-size box)
function transform(it, from, to) {
    const sx = from.w > 0 ? to.w / from.w : 1, sy = from.h > 0 ? to.h / from.h : 1;
    const avg = Math.sqrt(Math.abs(sx * sy)) || 1;
    const out = Object.assign({}, it);
    if (isPointsKind(it.kind)) {
        out.points = it.points.map(q => mapPoint(q, from, to));
        if (Math.abs(sx - 1) > 1e-6 || Math.abs(sy - 1) > 1e-6)
            out.width = Math.max(1, it.width * avg);
        return out;
    }
    if (isBoxKind(it.kind)) {
        const a = mapPoint(pt(it.x, it.y), from, to), b = mapPoint(pt(it.x + it.w, it.y + it.h), from, to);
        const r = rectOf(a, b);
        out.x = r.x;
        out.y = r.y;
        out.w = r.w;
        out.h = r.h;
        if (it.kind === "callout") {
            const t = mapPoint(pt(it.tx, it.ty), from, to);
            out.tx = t.x;
            out.ty = t.y;
            out.size = Math.max(6, it.size * avg);
        }
        return out;
    }
    if (it.kind === "text") {
        const a = mapPoint(pt(it.x, it.y), from, to);
        out.x = a.x;
        out.y = a.y;
        out.size = Math.max(4, it.size * Math.abs(sy));
        return out;
    }
    if (it.kind === "step" || it.kind === "magnifier") {
        const c = mapPoint(pt(it.x, it.y), from, to);
        out.x = c.x;
        out.y = c.y;
        if (it.kind === "step")
            out.size = Math.max(6, it.size * avg);
        else
            out.r = Math.max(8, it.r * avg);
        return out;
    }
    return out;
}

function translate(it, dx, dy) {
    const b = {
        x: 0,
        y: 0,
        w: 1,
        h: 1
    };
    return transform(it, b, {
        x: dx,
        y: dy,
        w: 1,
        h: 1
    });
}

// A scaled copy for "resize the picture" (factor sx, sy around 0,0)
function scaleItem(it, sx, sy) {
    return transform(it, {
        x: 0,
        y: 0,
        w: 1,
        h: 1
    }, {
        x: 0,
        y: 0,
        w: sx,
        h: sy
    });
}

// Snap the end of a drag: 45° steps for lines, squares/circles for boxes
function constrain(kind, start, p) {
    const dx = p.x - start.x, dy = p.y - start.y;
    if (kind === "line" || kind === "arrow") {
        const a = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4);
        const l = Math.hypot(dx, dy);
        return pt(start.x + l * Math.cos(a), start.y + l * Math.sin(a));
    }
    const s = Math.max(Math.abs(dx), Math.abs(dy));
    return pt(start.x + Math.sign(dx || 1) * s, start.y + Math.sign(dy || 1) * s);
}

// Black or white, whichever reads better on `c` (a Qt color)
function contrastOn(c) {
    const l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return l > 0.6 ? "#000000" : "#ffffff";
}

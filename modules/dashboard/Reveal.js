.pragma library

// The island's reveal, a contained overload (p: 0 hidden .. 1 the pill; closing runs it back):
//   0    .. 0.18  a small circle appears at the edge
//   0.08 .. 0.58  a comet spins up round its ring, faster and faster
//   0.30 .. 0.60  the ring heats (brighter, thicker) and shakes
//   0.60 .. 0.70  overload: a flash fills the inside
//   0.60 .. 1     a shockwave races to the ends and pushes the pill's sides out (an elastic
//                 overshoot), sparks bounce off the inner rim and fade, the face comes in
// Everything stays inside the pill's shape.

function clamp(v, a, b) {
    return Math.min(b === undefined ? 1 : b, Math.max(a === undefined ? 0 : a, v));
}
function ease(t) {
    return 1 - Math.pow(1 - t, 3);
}
function easeIn(t) {
    return t * t * t;
}
function backOut(t) {
    const c = 2.2;
    return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2);
}

// The pill's size at p, for circle diameter d and pill width pw, and the face's opacity
function at(p, d, pw) {
    const ring = ease(clamp(p / 0.18));
    const boom = clamp((p - 0.6) / 0.1);
    const out = clamp((p - 0.6) / 0.4);
    const front = ease(clamp(out / 0.55));
    const k = backOut(clamp((out - 0.05) / 0.95));
    const dd = d * ring;
    const w = Math.max(dd + (pw - d) * k, dd + (pw - d) * front * 0.98);
    const h = dd * (1 + Math.max(0, k - 1) * 0.35 + boom * (1 - boom) * 0.18);
    return {
        width: Math.max(0, w),
        height: Math.max(0, h),
        face: clamp((out - 0.55) / 0.4)
    };
}

// Fixed sparks (direction, speed, size, lifetime), replayed by p
const SPARKS = (function () {
    let seed = 7;
    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    const out = [];
    for (let i = 0; i < 46; i++)
        out.push({ a: rnd() * Math.PI * 2, v: 40 + rnd() * 110, s: 0.8 + rnd() * 1.6, f: 0.55 + rnd() * 0.45 });
    return out;
})();

function pillPath(g, x, y, w, h) {
    const r = Math.max(0, Math.min(h / 2, w / 2));
    g.beginPath();
    g.moveTo(x + r, y);
    g.lineTo(x + w - r, y);
    g.arc(x + w - r, y + r, r, -Math.PI / 2, Math.PI / 2);
    g.lineTo(x + r, y + h);
    g.arc(x + r, y + r, r, Math.PI / 2, Math.PI * 1.5);
    g.closePath();
}

function fold(v, m) {
    if (m <= 0)
        return 0;
    const q = ((v % (4 * m)) + 4 * m) % (4 * m);
    return q < 2 * m ? q - m : 3 * m - q;
}

// The light, on a canvas the pill's current size (W x H), in white
function paint(g, W, H, p, d, pw) {
    g.reset();
    if (W < 1 || H < 1 || p <= 0 || p >= 1)
        return;
    const cx = W / 2, cy = H / 2;
    const ring = ease(clamp(p / 0.18));
    const spin = clamp((p - 0.08) / 0.5);
    const heat = easeIn(clamp((p - 0.3) / 0.3));
    const boom = clamp((p - 0.6) / 0.1);
    const out = clamp((p - 0.6) / 0.4);
    const shake = heat * (1 - boom) * 2.2;
    const jx = (Math.random() - 0.5) * shake, jy = (Math.random() - 0.5) * shake;
    const dd = d * ring;

    g.save();
    pillPath(g, 0, 0, W, H);
    g.clip();

    if (boom < 1 && ring > 0.1) {
        const rr = Math.max(0.5, dd / 2 - 5);
        // the ring heating up
        g.globalAlpha = 0.15 + heat * 0.8;
        g.strokeStyle = "white";
        g.lineWidth = 1 + heat * 2.5;
        g.beginPath();
        g.arc(cx + jx, cy + jy, rr, 0, Math.PI * 2);
        g.stroke();
        // the comet, accelerating, its tail stretching into a circle of light
        const turns = 3.6 * spin * spin * spin;
        const head = -Math.PI / 2 + Math.PI * 2 * turns;
        const tail = 22 + Math.floor(spin * 40);
        g.fillStyle = "white";
        for (let i = 0; i < tail; i++) {
            const a = head - i * (0.05 + spin * 0.09), f = 1 - i / tail;
            g.globalAlpha = f * f * (1 - boom);
            g.beginPath();
            g.arc(cx + jx + Math.cos(a) * rr, cy + jy + Math.sin(a) * rr, 2.6 * f + 0.5, 0, Math.PI * 2);
            g.fill();
        }
    }

    if (boom > 0 && out < 1) {
        // the flash, draining
        const fl = clamp(1 - out / 0.35);
        if (fl > 0) {
            g.globalAlpha = 0.85 * fl;
            g.fillStyle = "white";
            g.fillRect(0, 0, W, H);
        }
        // the shockwave: two fronts to the ends, a fainter echo behind
        g.strokeStyle = "white";
        const fronts = [[0, 1], [0.18, 0.5]];
        for (let n = 0; n < fronts.length; n++) {
            const f = ease(clamp((out - fronts[n][0]) / 0.55));
            if (f <= 0 || f >= 1)
                continue;
            const x = (W / 2 - 6) * f, rx = 3 + 4 * (1 - f), ry = Math.max(1, H / 2 - 3);
            g.globalAlpha = (1 - f) * fronts[n][1];
            g.lineWidth = 3 * (1 - f) + 1;
            for (const sgn of [-1, 1]) {
                g.beginPath();
                g.ellipse(cx + sgn * x - rx, cy - ry, rx * 2, ry * 2);
                g.stroke();
            }
        }
        // sparks ricocheting off the rim, slowing and fading
        const st = clamp(out / 0.9);
        const hw = W / 2 - 4, hh = H / 2 - 4;
        g.fillStyle = "white";
        for (const s of SPARKS) {
            const life = clamp(1 - st / s.f);
            if (life <= 0)
                continue;
            const travel = s.v * 1.6 * ease(st);
            const x = fold(Math.cos(s.a) * travel + hw, hw), y = fold(Math.sin(s.a) * travel * 0.9 + hh, hh);
            g.globalAlpha = life;
            g.beginPath();
            g.arc(cx + x, cy + y, s.s * 0.9, 0, Math.PI * 2);
            g.fill();
        }
    }
    g.restore();
}

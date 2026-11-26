#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int effect;
    vec4 crop;
    float aspectRatio;
    float displayWidth;
    float displayHeight;
};
layout(binding = 1) uniform sampler2D snapshot;

float noise(vec2 point) {
    return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float field(vec2 point) {
    vec2 cell = floor(point);
    vec2 weight = smoothstep(0.0, 1.0, fract(point));
    return mix(mix(noise(cell), noise(cell + vec2(1, 0)), weight.x),
        mix(noise(cell + vec2(0, 1)), noise(cell + vec2(1)), weight.x), weight.y);
}

float reveal(float threshold, float edge) {
    return smoothstep(progress - edge, progress + edge, threshold);
}

float wipeMask(float position, float softness) {
    float front = mix(progress, progress * 2.0, softness);
    return 1.0 - smoothstep(0.0, softness, front - position);
}

vec3 sampleSnapshot(vec2 uv) {
    return texture(snapshot, crop.xy + clamp(uv, vec2(0), vec2(1)) * crop.zw).rgb;
}

float square(float value) {
    return value * value;
}

bool outsideImage(vec2 uv) {
    return any(lessThan(uv, vec2(0))) || any(greaterThan(uv, vec2(1)));
}

vec4 crtFrame(vec2 uv) {
    vec2 tube = uv - 0.5;
    float flattening = square(smoothstep(0.2, 0.6, progress));
    float widening = square(smoothstep(0.05, 0.25, progress));
    float shutdown = square(smoothstep(0.4, 0.8, progress));
    tube.y *= 1.0 + flattening * displayHeight * 0.5;
    tube.x *= (1.0 - widening * 0.8) * (1.0 + shutdown * displayWidth * 0.25);
    vec2 raster = tube + 0.5;
    float dark = smoothstep(0.7, 0.81, progress);
    float outside = outsideImage(raster) ? 1.0 : dark;
    float kick = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.1, 0.2, progress));
    float rolling = pow(smoothstep(0.1, 0.4, progress), 1.4);
    raster.y = fract(raster.y + 0.2 * kick - 5.0 * rolling);
    float split = 0.04 * square(smoothstep(0.07, 0.2, progress));
    vec3 rgb = vec3(sampleSnapshot(raster).r,
        sampleSnapshot(raster + vec2(0, split)).g, sampleSnapshot(raster - vec2(0, split)).b);
    rgb = mix(rgb, vec3(0.666), smoothstep(0.1, 0.4, progress));
    float staticLevel = field(uv * vec2(aspectRatio, 1.0) * 100.0 + progress * 11.0);
    staticLevel *= 0.1 * (1.0 - smoothstep(0.4, 0.5, progress))
        * (1.0 - smoothstep(0.0, 0.5, abs(uv.y - 0.5)));
    vec2 distanceFromTube = max(vec2(0), abs(tube) - 0.5) / 14.5;
    vec2 halo = 1.0 - smoothstep(vec2(0), vec2(1), distanceFromTube);
    float haloAmount = square(square(outside * halo.x * halo.y)) * (1.0 - dark);
    rgb = mix(mix(rgb, vec3(staticLevel), outside), vec3(0.25, 0.27, 0.33), haloAmount);
    float mask = 1.0 - smoothstep(0.7, 1.0, progress);
    return vec4(rgb * mask, mask);
}

vec4 blackHoleFrame(vec2 uv) {
    float life = smoothstep(0.0, 0.8, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
    vec2 jitter = vec2(field(vec2(progress * 100.0, 0.31)), field(vec2(progress * 100.0, 0.67))) - 0.5;
    vec2 center = vec2(0.5) + 0.02 * life * (1.0 - smoothstep(0.8, 0.95, progress)) * jitter;
    vec2 delta = uv - center;
    float distance = length(delta * vec2(aspectRatio, 1.0));
    float fieldStrength = square(smoothstep(0.0, 1.0, progress * 0.97));
    float bending = life > 0.0 ? 1.0 - smoothstep(0.0, life * 0.2, distance) : 0.0;
    float rotation = 4.0 * progress * square(bending);
    vec2 stretch = (uv - 0.5) * (1.0 + fieldStrength / max(0.0001, length(delta)));
    mat2 spin = mat2(cos(rotation), sin(rotation), -sin(rotation), cos(rotation));
    vec2 sampleAt = 0.5 + spin * stretch;
    float prism = rotation * 0.04;
    vec3 rgb = vec3(sampleSnapshot(sampleAt).r, sampleSnapshot(sampleAt - prism).g,
        sampleSnapshot(sampleAt + prism).b);
    vec2 shadowVector = sampleAt - 0.5;
    float shadow = abs(shadowVector.x) * sin(6.0 * atan(shadowVector.y, -shadowVector.x + 0.00001));
    float outside = outsideImage(sampleAt) || length(sampleAt - center) > 0.707107 || progress > 0.9 ? 0.0 : 1.0;
    rgb *= outside * (1.0 - square(shadow) * fieldStrength * 4.0);
    float core = life > 0.0 ? 1.0 - smoothstep(life * 0.04, life * 0.05, distance) : 0.0;
    float rim = smoothstep(life * 0.03, max(0.00001, life * 0.05), distance) * core;
    return vec4(mix(rgb * (1.0 - core), rgb * rgb, rim), max(core, outside));
}

vec2 brushStroke(vec2 uv, vec2 from, vec2 to, vec2 interval, vec2 grain) {
    vec2 path = to - from;
    float lengthSquared = dot(path, path);
    vec2 displacement = uv - from;
    float along = dot(displacement, path) / lengthSquared;
    float across = abs(displacement.x * path.y - displacement.y * path.x) / sqrt(lengthSquared);
    float covered = step(0.004, along)
        * step(mix(interval.x, interval.y, clamp(along, 0.0, 1.0)), progress + grain.x * 0.02);
    float stroke = step(across, 0.4 - grain.x * 0.1);
    float shadow = 1.0 - smoothstep(0.0, 0.03, across - (0.4 - grain.y * 0.1));
    return covered * vec2(stroke, max(0.0, shadow - stroke));
}

void main() {
    vec2 uv = qt_TexCoord0;
    if (progress <= 0.0) {
        fragColor = texture(snapshot, crop.xy + uv * crop.zw) * qt_Opacity;
        return;
    }
    if (effect == 21 || effect == 20) {
        fragColor = (effect == 21 ? crtFrame(uv) : blackHoleFrame(uv)) * qt_Opacity;
        return;
    }
    vec2 centered = uv - 0.5;
    float radius = length(centered);
    float pixelRadius = length(centered * vec2(aspectRatio, 1.0));
    float angle = atan(centered.y, centered.x + 0.00001);
    float alpha = 1.0;
    float brightness = 1.0;
    float blurRadius = 0.0;
    bool taper = true;
    if (effect == 0) {
        alpha = 1.0 - progress;
        taper = false;
    } else if (effect == 18) {
        brightness = 1.0 - smoothstep(0.0, 0.5, progress);
        alpha = 1.0 - smoothstep(0.5, 1.0, progress);
        taper = false;
    } else if (effect == 1 || effect == 2) {
        float cells = effect == 1 ? 50.0 : 1000.0;
        float tile = noise(floor(uv * vec2(aspectRatio, 1.0) * cells));
        alpha = wipeMask(tile, 0.5);
        taper = false;
    } else if (effect == 3) {
        uv.x -= progress;
        taper = false;
    } else if (effect == 4) {
        uv.y -= progress;
        taper = false;
    } else if (effect == 5 || effect == 6) {
        alpha = wipeMask(effect == 5 ? uv.x : uv.y, 0.5);
        taper = false;
    } else if (effect == 7) {
        vec2 point = uv * vec2(aspectRatio, 1.0) * 3.0;
        float clouds = 0.55 * field(point) + 0.27 * field(point * 2.0)
            + 0.12 * field(point * 4.0) + 0.06 * field(point * 8.0);
        alpha = wipeMask(clouds, 1.0 / 3.0);
        taper = false;
    } else if (effect == 8) {
        float threshold = (uv.y + 0.38 * field(uv * 22.0)) / 1.38;
        alpha = reveal(threshold, 0.012);
        brightness = mix(0.28, 1.0, smoothstep(progress, progress + 0.045, threshold));
    } else if (effect == 9) {
        alpha = wipeMask(pixelRadius, 0.1);
        taper = aspectRatio > 1.8;
    } else if (effect == 10 || effect == 11) {
        float side = sign(centered.x);
        float split = progress;
        if (effect == 10) {
            float travel = max(0.0, progress * 1.5 - uv.y * 0.5);
            split = smoothstep(0.0, 1.0, square(travel));
        }
        uv.x -= side * split * 0.833;
        float gap = -side * (uv.x - 0.5);
        if (gap > 0.0) {
            alpha = 0.5 * (1.0 - smoothstep(0.0, 0.333, gap));
            brightness = 0.0;
        }
        taper = false;
    } else if (effect == 12) {
        alpha = wipeMask(noise(vec2(0.0, floor(uv.y * 100.0))), 0.2);
        taper = false;
    } else if (effect == 22) {
        float sweep = progress * 1.02;
        alpha = smoothstep(sweep - 0.02, sweep, fract(angle / 6.283185 + 0.25));
        taper = false;
    } else if (effect == 13) {
        float zoom = progress * (1.0 - wipeMask(pixelRadius, 1.0));
        uv = 0.5 + centered * (1.0 - zoom);
        blurRadius = progress * 40.0 / max(1.0, displayHeight);
        alpha = 1.0 - progress;
        taper = false;
    } else if (effect == 19) {
        float spin = 1.0 - wipeMask(pixelRadius, 0.5);
        float twist = progress * spin * 20.0;
        vec2 rotated = mat2(cos(twist), sin(twist), -sin(twist), cos(twist)) * centered;
        uv = 0.5 + rotated / (1.0 + spin);
        alpha = wipeMask(pixelRadius, 0.1);
        taper = aspectRatio > 1.8;
    } else if (effect == 14) {
        float column = uv.x * 10.0;
        float delay = (0.7 * field(vec2(column, 0.0)) + 0.3 * field(vec2(column * 2.0, 0.0))) * 0.2;
        uv.y = uv.y * (1.0 - progress) - max(0.0, progress * 1.2 - delay);
        if (uv.y < 0.0) {
            alpha = (1.0 - progress) * smoothstep(-0.1333, 0.0, uv.y);
            brightness = 0.0;
            uv.y = 0.0;
        }
        taper = false;
    } else if (effect == 15) {
        float density = 1.0 - pow(progress, 0.1);
        vec2 cells = floor(vec2(displayWidth, displayHeight) * density + 10.0 * vec2(aspectRatio, 1.0));
        uv = clamp(0.5 + floor(centered * cells) / cells, vec2(0), vec2(1));
        alpha = 1.0 - smoothstep(0.7, 1.0, progress);
        taper = false;
    } else if (effect == 16) {
        float row = floor(uv.y * 13.0);
        float column = floor(uv.x * 18.0 + fract(row * 0.5));
        alpha = reveal((column / 19.0 + 0.35 * noise(vec2(column, row))) / 1.35, 0.016);
    } else if (effect == 17) {
        vec2 point = uv * vec2(aspectRatio, 1.0) * 10.0;
        float broad = 0.6 * field(point) + 0.3 * field(point * 2.0) + 0.1 * field(point * 4.0);
        vec2 grain = vec2(broad * 0.85 + field(point * 8.0) * 0.15, broad);
        vec2 top = brushStroke(uv, vec2(-1.0, -0.22), vec2(1.0, 0.13), vec2(0.0, 0.25), grain);
        vec2 middle = brushStroke(uv, vec2(1.5, 0.08), vec2(0.0, 0.51), vec2(0.333, 0.583), grain);
        vec2 bottom = brushStroke(uv, vec2(-0.5, 0.58), vec2(1.2, 0.78), vec2(0.666, 0.999), grain);
        alpha = 1.0 - max(top.x, max(middle.x, bottom.x));
        brightness = 1.0 - (2.0 / 3.0) * max(top.y, max(middle.y, bottom.y));
        taper = false;
    } else if (effect == 23) {
        float sector = floor((angle + 3.141593) * 5.0);
        float ring = floor(radius * 12.0 + noise(vec2(sector, 0)));
        uv -= centered * progress * noise(vec2(sector, ring)) * 0.6;
        alpha = reveal(noise(vec2(sector, ring + 7.0)), 0.04);
    } else if (effect == 24) {
        float impact = 1.0;
        for (int i = 0; i < 8; ++i) {
            vec2 seed = vec2(float(i), 13.0);
            vec2 center = vec2(noise(seed), noise(seed.yx + 7.5));
            impact = min(impact, length(uv - center) + float(i) * 0.047);
        }
        alpha = reveal(impact, 0.015);
    } else if (effect == 25) {
        float crystal = min(abs(sin(angle * 9.0)), abs(sin(radius * 50.0)));
        alpha = reveal(radius * 0.95 + 0.4 * crystal, 0.04);
        brightness = mix(1.2, 1.0, smoothstep(progress, progress + 0.08, radius));
    } else if (effect == 26) {
        float bubbles = field(uv * 11.0 + vec2(0.0, progress * 2.0));
        alpha = reveal((bubbles + uv.y * 0.45) / 1.45, 0.046);
    }
    if (progress > 0.997 || outsideImage(uv)) {
        fragColor = vec4(0.0);
    } else {
        float a = alpha * (taper ? 1.0 - smoothstep(0.94, 1.0, progress) : 1.0) * qt_Opacity;
        vec3 rgb = sampleSnapshot(uv);
        if (blurRadius > 0.0) {
            vec2 offset = centered * vec2(aspectRatio, 1.0) * blurRadius;
            rgb = (rgb * 4.0 + sampleSnapshot(uv - offset) * 2.0 + sampleSnapshot(uv + offset) * 2.0
                + sampleSnapshot(uv - offset * 2.0) + sampleSnapshot(uv + offset * 2.0)) / 10.0;
        }
        fragColor = vec4(rgb * brightness * a, a);
    }
}

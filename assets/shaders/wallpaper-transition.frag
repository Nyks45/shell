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
    vec3 seed;
    vec2 snapshotSize;
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

float terrain(vec2 point) {
    float value = 0.0;
    float weight = 0.58;
    for (int octave = 0; octave < 5; ++octave) {
        value += (field(point) - 0.5) * weight;
        point = mat2(1.6, 1.2, -1.2, 1.6) * point + vec2(7.1, 4.8);
        weight *= 0.5;
    }
    return value;
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

vec4 burntPaper(vec2 uv) {
    vec2 point = uv * vec2(aspectRatio, 1.0);
    float paper = clamp(0.53 + terrain(point * 3.5 + seed.xy * 7.0) * 2.2, 0.02, 0.99);
    float flame = progress + 0.13 * smoothstep(0.17, 0.64, progress)
        - 0.03 * smoothstep(0.0, 0.10, progress) * (1.0 - smoothstep(0.10, 0.22, progress));
    float edge = paper - flame;
    float curl = 1.0 - smoothstep(0.0, 0.34 * progress + 0.015, edge);
    vec2 slope = vec2(dFdx(paper), dFdy(paper));
    vec3 rgb = sampleSnapshot(uv - clamp(slope * square(curl) * 22.0, vec2(-0.08), vec2(0.08)));
    float charred = 1.0 - smoothstep(0.015, 0.16 * progress + 0.02, edge);
    float sparks = field(point * 94.0 + vec2(progress * 65.0, -progress * 41.0));
    float ember = 1.0 - smoothstep(0.003, 0.027, abs(edge));
    rgb *= mix(vec3(1.0), vec3(0.08, 0.022, 0.008), charred);
    rgb += vec3(1.0, 0.28, 0.025) * ember * (0.45 + sparks * 0.9);
    float alpha = smoothstep(-0.005, 0.0, edge);
    float shadow = (1.0 - alpha) * (1.0 - smoothstep(0.0, 0.1, -edge)) * 0.42;
    float tail = 1.0 - smoothstep(0.9, 1.0, progress);
    return vec4(rgb * max(alpha, ember * 0.15), max(alpha, shadow)) * tail;
}

vec4 bulletImpact(vec2 uv) {
    vec2 aspect = vec2(aspectRatio, 1.0);
    vec2 center = 0.25 + seed.xy * 0.5;
    vec2 delta = (uv - center) * aspect;
    float kick = smoothstep(0.04, 0.16, progress);
    float recoil = kick * (1.0 - smoothstep(0.12, 0.45, progress));
    float spin = (seed.y - 0.5) * 0.42 * kick + sin(kick * 8.0) * recoil * 0.16;
    mat2 rotation = mat2(cos(spin), sin(spin), -sin(spin), cos(spin));
    float zoom = 1.0 - smoothstep(0.4, 1.0, progress);
    vec2 shake = vec2(field(vec2(progress * 36.0, seed.z)), field(vec2(seed.z, progress * 52.0))) - 0.5;
    vec2 struck = rotation * delta * (0.96 * zoom + 0.04 * (1.0 - kick)) + 0.035 * recoil * shake;
    uv = center + struck / aspect + (center - 0.5) * zoom * (1.0 - zoom);

    float impact = smoothstep(0.0, 0.1, progress);
    float distance = length(struck);
    float angle = atan(struck.y, struck.x + 0.00001);
    float sector = angle * 10.0 + seed.x * 73.0;
    float jagged = field(vec2(sector, distance * 20.0));
    float ringCoordinate = 22.0 * sqrt(distance) + jagged * 2.5;
    float rings = pow(1.0 - abs(2.0 * fract(ringCoordinate) - 1.0), 5.0);
    float rays = pow(field(vec2(sector * 2.0, 0.0)), 4.0);
    float fractures = (rings * 0.45 + rays) * impact * smoothstep(0.012, 0.038, distance)
        * (1.0 - smoothstep(0.04, 0.14 + jagged * 0.16, distance));
    vec2 refraction = vec2(dFdx(fractures), dFdy(fractures)) * 0.18;
    vec3 rgb = sampleSnapshot(uv + refraction);
    float crushed = impact * (1.0 - smoothstep(0.015, 0.021, distance)) * 0.95;
    float flash = impact * (1.0 - impact);
    float flare = max(0.0, 1.0 - length(delta * vec2(0.85, 3.2))) * square(flash * 4.0);
    rgb = mix(rgb, vec3(0.70, 0.77, 0.87), clamp(fractures * 3.0, 0.0, 1.0));
    rgb *= (1.0 - crushed) * (1.0 + vec3(1.0, 0.7, 0.2) * flare);
    float opening = smoothstep(0.7, 0.8, progress) * crushed;
    float alpha = (1.0 - opening) * (1.0 - smoothstep(0.9, 1.0, progress));
    return vec4(rgb * alpha, alpha);
}

vec4 iceFrame(vec2 uv) {
    vec2 point = uv * vec2(aspectRatio, 1.0);
    float radius = length(point - vec2(aspectRatio, 1.0) * 0.5) / max(1.0, aspectRatio);
    float frost = clamp(0.5 + terrain(point * 4.0 + seed.xy * 7.0) * 1.25, 0.0, 1.0);
    float seams = 1.0 - smoothstep(0.01, 0.075, abs(terrain(point * 7.0 + seed.yz * 9.0)));
    float thaw = square(1.0 - smoothstep(0.5, 1.0, progress));
    float buildup = (smoothstep(0.0, 0.20, progress) + 2.0 * smoothstep(0.25, 0.50, progress)) / 3.0;
    float thickness = frost * (0.3 + progress * 0.2 + smoothstep(0.3, 0.6, progress) * 0.2);
    float ice = smoothstep(0.89, 0.91, radius + thickness * 0.5 + seams * 0.05 + buildup * thaw * 1.3);
    vec2 slope = clamp(vec2(dFdx(thickness), dFdy(thickness)) * 58.0, vec2(-0.25), vec2(0.25));
    vec2 sampleAt = uv + slope * abs(slope) * ice;
    float lod = ice * (2.5 + seams * 2.5);
    vec2 texel = 1.0 / max(snapshotSize, vec2(1.0));
    vec2 margin = min(crop.zw * 0.5, texel * exp2(lod));
    vec2 source = clamp(crop.xy + sampleAt * crop.zw, crop.xy + margin, crop.xy + crop.zw - margin);
    vec3 rgb = textureLod(snapshot, source, lod).rgb;
    float sweep = smoothstep(0.45, 0.65, progress) * (1.0 - smoothstep(0.65, 0.82, progress));
    float glint = 1.0 - smoothstep(0.0, 0.21, abs(uv.x - (progress - 0.45) * 4.0 + uv.y * 0.14));
    rgb *= 1.0 + ice * (length(slope) + glint * sweep * abs(uv.y - 0.5));
    rgb += vec3(0.60, 0.65, 1.0) * ice * frost * square(radius + seams * 0.10) * 4.0;
    float alpha = max(ice, 1.0 - smoothstep(0.51, 0.56, progress)) * (1.0 - smoothstep(0.95, 1.0, progress));
    return vec4(rgb * alpha, alpha);
}

vec4 boilover(vec2 uv) {
    vec2 aspect = vec2(aspectRatio, 1.0);
    float tail = square(smoothstep(0.8, 1.0, progress));
    float light = 1.0;
    for (int i = 0; i < 25; ++i) {
        vec2 key = vec2(float(i), float(i) * 3.11) + seed.xy * 47.0;
        vec2 center = vec2(noise(key), noise(key.yx + 15.7)) * 1.10 - 0.05;
        float starts = 0.16 + pow(noise(key + 29.4), 0.8) * 0.75;
        float radius = 0.078 + noise(key - 55.1) * 0.26 * progress + tail * 0.5;
        vec2 delta = uv - center;
        float distance = length(delta * aspect);
        float wave = smoothstep(starts - 0.5, starts + 0.5, progress) - distance;
        float ripple = smoothstep(0.0, 0.10, wave) * (1.0 - smoothstep(0.10, 0.20, wave));
        vec2 rippleOffset = -0.009 * ripple * smoothstep(0.0, 0.1, progress) * delta / max(0.0001, length(delta));
        float age = square(smoothstep(starts, starts + 0.0001 + tail * 0.5, progress));
        float bubble = 0.0;
        if (distance < radius && age > 0.0) {
            float angle = atan(delta.y, delta.x + 0.00001);
            float grain = field(vec2(angle * 2.1, 5.0 * progress) + key);
            bubble = (1.0 - smoothstep(0.0, radius, distance * (1.0 + 0.23 * grain))) * age * 20.0;
            float edge = 0.35 + field(vec2(angle * 3.1, bubble * 0.4) + key) * 1.65;
            if (bubble > edge)
                return vec4(0.0);
        }
        vec2 offset = rippleOffset - delta * min(1.0, bubble);
        uv += offset;
        light += dot(offset, vec2(-7.0, 7.0));
    }
    float alpha = 1.0 - smoothstep(0.9, 1.0, progress);
    return vec4(sampleSnapshot(uv) * max(0.0, light) * alpha, alpha);
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
    vec2 jitter = vec2(field(vec2(progress * 100.0, seed.y)), field(vec2(progress * 100.0, seed.z))) - 0.5;
    vec2 center = vec2(0.5) + 0.02 * life * (1.0 - smoothstep(0.8, 0.95, progress)) * jitter;
    vec2 delta = uv - center;
    float distance = length(delta * vec2(aspectRatio, 1.0));
    float fieldStrength = square(smoothstep(0.0, 1.0, progress * 0.97));
    float bending = life > 0.0 ? 1.0 - smoothstep(0.0, life * 0.2, distance) : 0.0;
    float rotation = (seed.x < 0.5 ? 4.0 : -4.0) * progress * square(bending);
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
    if (effect == 8 || effect >= 24) {
        vec4 result;
        if (effect == 8)
            result = burntPaper(uv);
        else if (effect == 24)
            result = bulletImpact(uv);
        else if (effect == 25)
            result = iceFrame(uv);
        else
            result = boilover(uv);
        fragColor = result * qt_Opacity;
        return;
    }
    vec2 centered = uv - 0.5;
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
        vec2 cell = floor(fract(uv + seed.x) * vec2(aspectRatio, 1.0) * cells);
        float tile = noise(cell + seed.y * 193.0);
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
        vec2 point = uv * vec2(aspectRatio, 1.0) * 3.5;
        float clouds = clamp(0.45 + terrain(point + seed.xy * 7.0) * 2.8, 0.0, 1.0);
        alpha = wipeMask(clouds, 1.0 / 3.0);
        taper = false;
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
        float row = floor(fract(uv.y + seed.x) * 100.0);
        alpha = wipeMask(noise(vec2(seed.y * 193.0, row)), 0.2);
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
        float column = uv.x * 10.0 + seed.x;
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
    } else if (effect == 17) {
        vec2 point = uv * vec2(aspectRatio, 1.0) * 10.0 + seed.xy;
        float broad = 0.6 * field(point) + 0.3 * field(point * 2.0) + 0.1 * field(point * 4.0);
        vec2 grain = vec2(broad * 0.85 + field(point * 8.0) * 0.15, broad);
        vec2 canvas = uv + vec2(0.0, (0.5 - seed.x) * 0.1);
        vec2 top = brushStroke(canvas, vec2(-1.0, -0.22), vec2(1.0, 0.13), vec2(0.0, 0.25), grain);
        vec2 middle = brushStroke(canvas, vec2(1.5, 0.08), vec2(0.0, 0.51), vec2(0.333, 0.583), grain);
        vec2 bottom = brushStroke(canvas, vec2(-0.5, 0.58), vec2(1.2, 0.78), vec2(0.666, 0.999), grain);
        alpha = 1.0 - max(top.x, max(middle.x, bottom.x));
        brightness = 1.0 - (2.0 / 3.0) * max(top.y, max(middle.y, bottom.y));
        taper = false;
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

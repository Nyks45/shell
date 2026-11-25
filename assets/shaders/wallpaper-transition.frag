#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int effect;
    vec4 crop;
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

void main() {
    vec2 uv = qt_TexCoord0;
    if (progress <= 0.0) {
        fragColor = texture(snapshot, crop.xy + uv * crop.zw) * qt_Opacity;
        return;
    }
    vec2 centered = uv - 0.5;
    float radius = length(centered);
    float angle = atan(centered.y, centered.x + 0.00001);
    float alpha = 1.0;
    float brightness = 1.0;
    if (effect == 0) {
        alpha = 1.0 - progress;
    } else if (effect == 18) {
        brightness = max(0.0, 1.0 - 2.0 * progress);
        alpha = min(1.0, 2.0 - 2.0 * progress);
    } else if (effect == 1 || effect == 2) {
        float cells = effect == 1 ? 24.0 : 320.0;
        alpha = reveal(noise(floor(uv * cells)), 0.025);
    } else if (effect == 3) {
        uv.x += progress;
    } else if (effect == 4) {
        uv.y += progress;
    } else if (effect == 5 || effect == 6) {
        alpha = reveal(effect == 5 ? uv.x : uv.y, 0.12);
    } else if (effect == 7) {
        alpha = reveal(field(uv * 7.0) * 0.65 + 0.35 * uv.x, 0.08);
    } else if (effect == 8) {
        float threshold = (uv.y + 0.38 * field(uv * 22.0)) / 1.38;
        alpha = reveal(threshold, 0.012);
        brightness = mix(0.28, 1.0, smoothstep(progress, progress + 0.045, threshold));
    } else if (effect == 9) {
        alpha = reveal(radius * 1.4142, 0.006);
    } else if (effect == 10) {
        float zigzag = abs(fract(uv.y * 24.0) - 0.5);
        alpha = reveal((abs(centered.x) * 2.0 + 0.08 * zigzag) / 1.04, 0.007);
    } else if (effect == 11) {
        uv.x -= sign(centered.x) * progress * 0.5;
        alpha = 1.0 - step(abs(centered.x) * 2.0, progress);
    } else if (effect == 12) {
        alpha = reveal(fract(uv.y * 42.0), 0.035);
    } else if (effect == 22) {
        alpha = reveal(fract(angle / 6.283185 + 0.25), 0.006);
    } else if (effect == 13 || effect == 19 || effect == 20) {
        float scale = effect == 13 ? 1.0 + progress * 0.85 : 1.0 / max(0.04, 1.0 - 0.94 * progress);
        float twist = effect == 13 ? 0.0 : progress * (effect == 19 ? 7.0 : 4.0) * (1.0 - radius);
        vec2 rotated = mat2(cos(twist), sin(twist), -sin(twist), cos(twist)) * centered;
        uv = 0.5 + rotated * scale;
        alpha = effect == 20 ? reveal(1.0 - radius * 1.4142, 0.03) : 1.0 - progress;
    } else if (effect == 14) {
        float delay = 0.28 * field(vec2(uv.x * 27.0, 0.0));
        alpha = reveal((uv.y + delay) / 1.28, 0.012);
    } else if (effect == 15) {
        float cells = mix(420.0, 10.0, progress);
        uv = (floor(uv * cells) + 0.5) / cells;
        alpha = 1.0 - progress;
    } else if (effect == 16) {
        float row = floor(uv.y * 13.0);
        float column = floor(uv.x * 18.0 + fract(row * 0.5));
        alpha = reveal((column / 19.0 + 0.35 * noise(vec2(column, row))) / 1.35, 0.016);
    } else if (effect == 17) {
        float bristle = field(vec2(uv.x * 65.0, uv.y * 6.0));
        alpha = reveal((uv.y + 0.4 * bristle) / 1.4, 0.035);
    } else if (effect == 21) {
        float squeeze = min(progress * 1.8, 0.99);
        uv.y = centered.y / (1.0 - squeeze) + 0.5;
        alpha = 1.0 - progress;
        brightness = 0.9 + 0.35 * sin(uv.y * 540.0) * progress;
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
    if (progress > 0.997 || any(lessThan(uv, vec2(0))) || any(greaterThan(uv, vec2(1)))) {
        fragColor = vec4(0.0);
    } else {
        float a = alpha * (1.0 - smoothstep(0.94, 1.0, progress)) * qt_Opacity;
        fragColor = vec4(texture(snapshot, crop.xy + uv * crop.zw).rgb * brightness * a, a);
    }
}

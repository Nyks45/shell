#version 440

layout(location = 0) in vec2 sourceUv;
layout(location = 1) in vec3 surfaceNormal;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform Params {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int effect;
    vec4 crop;
    float aspectRatio;
    int pieceIndex;
    vec2 viewport;
};
layout(binding = 1) uniform sampler2D snapshot;

vec3 sampleSnapshot(vec2 uv) {
    return texture(snapshot, crop.xy + clamp(uv, vec2(0), vec2(1)) * crop.zw).rgb;
}

void main() {
    if (effect == 16) {
        fragColor = vec4(sampleSnapshot(sourceUv), 1.0) * qt_Opacity;
        return;
    }
    vec3 normal = normalize(surfaceNormal);
    vec3 light = vec3(0.7071, 0.7071, 0.0);
    vec2 split = normal.xy * vec2(0.015 / aspectRatio, 0.015);
    vec3 rgb = vec3(sampleSnapshot(sourceUv + split).r, sampleSnapshot(sourceUv).g,
        sampleSnapshot(sourceUv - split).b);
    float glint = pow(max(0.0, dot(normalize(light + vec3(0, 0, 0.55)), normal)), 8.0);
    rgb = rgb * (1.0 + dot(normal, light) * 0.72) + glint * smoothstep(0.1, 0.48, progress);
    float alpha = (1.0 - smoothstep(0.9, 1.0, progress)) * qt_Opacity;
    fragColor = vec4(rgb * alpha, alpha);
}

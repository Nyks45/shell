#version 440

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 sourceUv;
layout(location = 1) out vec3 surfaceNormal;

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

float randomAt(vec2 point) {
    return fract(sin(dot(point, vec2(81.23, 45.17))) * 17483.27);
}

vec2 gridPoint(vec2 cell) {
    vec2 grid = vec2(8, 5);
    vec2 jitter = vec2(randomAt(cell + vec2(7, 13)), randomAt(cell + vec2(21, 4))) - 0.5;
    vec2 inside = step(vec2(1), cell) * (1.0 - step(grid, cell));
    return (cell + jitter * inside * 0.8) / grid;
}

vec3 turn(vec3 point, vec3 axis, float angle) {
    return point * cos(angle) + cross(axis, point) * sin(angle) + axis * dot(axis, point) * (1.0 - cos(angle));
}

vec2 brickPosition(vec2 corner) {
    float slot = mod(float(pieceIndex), 7.0);
    bool staggered = slot >= 3.0;
    float row = floor(float(pieceIndex) / 7.0) * 2.0 + float(staggered);
    float column = staggered ? slot - 3.0 : slot + 0.5;
    vec2 center = vec2(column / 3.0, (7.5 - row) / 8.0);
    vec2 local = (corner - 0.5) * vec2(1.0 / 3.0, 1.0 / 8.0);
    sourceUv = center + local;
    surfaceNormal = vec3(0, 0, 1);
    float fall = smoothstep(0.0, 0.3, progress * 1.45 - (1.0 - center.y) - center.x * 0.2);
    fall *= fall;
    float angle = fall * (center.x - 0.5) * 6.0;
    mat2 rotation = mat2(cos(angle), sin(angle), -sin(angle), cos(angle));
    vec2 aspect = vec2(aspectRatio, 1.0);
    center += vec2((center.x - 0.5) / 3.0, (1.2 - center.y) * 1.3) * fall;
    return center + rotation * (local * aspect) / aspect;
}

vec2 glassPosition(vec2 corner) {
    float cellIndex = floor(float(pieceIndex) * 0.5);
    vec2 cell = vec2(mod(cellIndex, 8.0), floor(cellIndex / 8.0));
    vec2 a = gridPoint(cell);
    vec2 b = gridPoint(cell + vec2(1, 0));
    vec2 c = gridPoint(cell + vec2(0, 1));
    vec2 d = gridPoint(cell + 1.0);
    bool second = mod(float(pieceIndex), 2.0) > 0.5;
    bool slash = randomAt(cell + 0.5) > 0.5;
    if (slash) {
        if (second)
            a = d;
    } else if (second) {
        b = d;
    } else {
        c = d;
    }
    // Collapse the last corner of the quad onto the third vertex.
    sourceUv = a + (b - a) * min(corner.x, 1.0 - corner.y) + (c - a) * corner.y;
    vec2 center = (a + b + c) / 3.0;
    vec2 aspect = vec2(aspectRatio, 1.0);
    vec2 offset = center - 0.5;
    float distance = length(offset * aspect);
    float creak = 0.06 * smoothstep(0.02, 0.07, progress)
        + 0.08 * smoothstep(0.12, 0.17, progress) + 0.13 * smoothstep(0.27, 0.36, progress);
    creak *= 1.0 - smoothstep(0.0, 0.52, distance);
    float burst = clamp((progress - 0.4) / 0.6, 0.0, 1.0);
    float rotation = sqrt(smoothstep(0.4, 0.8, progress - distance * 0.06)) * progress * 8.0;
    vec2 key = cell + (second ? 0.8 : 0.2);
    vec3 axis = normalize(vec3(randomAt(key), randomAt(key + 14.6), randomAt(key - 23.1)) - 0.5
        + vec3(0.0001));
    vec3 local = vec3((sourceUv - center) * aspect, 0.0) * (1.0 - creak * 0.18);
    vec3 rotated = turn(local, axis, rotation);
    surfaceNormal = turn(vec3(0, 0, 1), axis, rotation + creak * 0.25);
    vec2 travel = offset * (1.0 + 3.7 * burst);
    travel.y += 1.9 * burst - 0.84 * sqrt(burst);
    return 0.5 + travel + rotated.xy / aspect / max(0.6, 1.0 - rotated.z);
}

void main() {
    vec2 corner = qt_MultiTexCoord0;
    vec2 position = effect == 16 ? brickPosition(corner) : glassPosition(corner);
    gl_Position = qt_Matrix * vec4(position * viewport, qt_Vertex.zw);
}

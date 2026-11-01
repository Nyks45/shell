#version 300 es
// Settings > Accessibility > Colour filter: red-green (deuteranopia) correction, daltonize
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;
void main() {
    vec4 c = texture(tex, v_texcoord);
    // RGB -> LMS, simulate deuteranopia, back; shift the lost difference into visible channels
    mat3 rgb2lms = mat3(17.8824, 3.45565, 0.0299566, 43.5161, 27.1554, 0.184309, 4.11935, 3.86714, 1.46709);
    mat3 lms2rgb = inverse(rgb2lms);
    vec3 lms = rgb2lms * c.rgb;
    vec3 sim = vec3(lms.x, 0.494207 * lms.x + 1.24827 * lms.z, lms.z);
    vec3 err = c.rgb - lms2rgb * sim;
    vec3 fix = vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);
    fragColor = vec4(clamp(c.rgb + fix, 0.0, 1.0), c.a);
}

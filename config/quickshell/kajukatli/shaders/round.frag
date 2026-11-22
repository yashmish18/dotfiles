#version 440
// a picture cropped to cover its box, with soft rounded corners. for album art.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // the box, in pixels
    vec2 cover;     // uv scale that makes the picture cover the box
    float radius;
};
layout(binding = 1) uniform sampler2D src;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 h = size * 0.5;
    vec2 q = abs(p - h) - (h - vec2(radius));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float a = 1.0 - smoothstep(-0.75, 0.75, d);
    vec2 uv = (qt_TexCoord0 - 0.5) * cover + 0.5;
    fragColor = texture(src, uv) * a * qt_Opacity;
}

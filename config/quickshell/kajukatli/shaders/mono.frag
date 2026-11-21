#version 440
// black & white with a faint warm tint, for album art and thumbnails
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};
layout(binding = 1) uniform sampler2D src;

void main() {
    vec4 c = texture(src, qt_TexCoord0);
    float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    l = smoothstep(0.02, 0.98, l);
    fragColor = vec4(l * vec3(1.0, 0.975, 0.94) * c.a, c.a) * qt_Opacity;
}

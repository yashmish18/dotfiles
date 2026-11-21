#version 440
// a sheet of film grain to lay over things. static unless `time` changes.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float amount;
    vec2 size;
};

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 px = floor(qt_TexCoord0 * size);
    float g = hash(px + floor(time * 12.0) * vec2(7.31, 1.97));
    float a = abs(g - 0.5) * 2.0 * amount;
    fragColor = vec4(vec3(step(0.5, g)) * a, a) * qt_Opacity;
}

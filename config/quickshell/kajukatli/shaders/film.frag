#version 440
// the lock screen picture: black & white, pushed a stop dark, a vignette that leans to the
// bottom-left where the clock sits, warm paper tint and moving grain (12 fps, like a projector).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float grain;       // 0..0.2
    float exposure;    // 0..1, how dark
    float aspect;
    vec2 cover;
    vec2 drift;        // slow pan, in uv units
    float leak;        // 0..1, a warm light leak in the top-right corner
};

layout(binding = 1) uniform sampler2D src;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 u = (uv - 0.5) * cover + 0.5 + drift;
    vec3 c = texture(src, clamp(u, vec2(0.001), vec2(0.999))).rgb;

    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    l = smoothstep(0.03, 0.97, pow(l, 1.12));   // deeper blacks, a little more bite
    l *= exposure;

    vec2 d = (uv - vec2(0.38, 0.62)) * vec2(aspect * 0.7, 1.0);
    float v = 1.0 - smoothstep(0.25, 1.05, length(d));
    l *= mix(0.3, 1.0, v);

    float frame = floor(time * 12.0);
    float g = hash(uv * vec2(1733.0, 977.0) + frame * vec2(17.13, 3.71)) - 0.5;
    l += g * grain * (0.6 + 0.4 * (1.0 - l));   // grain shows most in the shadows

    vec3 col = clamp(l, 0.0, 1.0) * vec3(1.0, 0.972, 0.935);

    // light leak: warm, soft, from the edge of the frame, the only colour on the screen
    vec2 q = (uv - vec2(1.05, -0.05)) * vec2(aspect, 1.0);
    float glow = exp(-dot(q, q) * 2.2) * leak;
    col += vec3(0.55, 0.24, 0.08) * glow * 0.55;
    col = 1.0 - (1.0 - col) * (1.0 - vec3(0.9, 0.45, 0.2) * glow * 0.12);   // screen blend
    fragColor = vec4(col, 1.0) * qt_Opacity;
}

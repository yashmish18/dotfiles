#version 440
// kajukatli wallpaper: depth parallax + "outline, then ink" transition.
//
// progress 0 → 1:
//   0.00–0.45  the new picture's subject is drawn over the old one, stroke by stroke
//   0.32–1.00  ink bleeds outward from the subject and reveals the new picture
//   0.72–1.00  the drawn lines dry and fade
// at progress 1 only the parallax path runs (one texture fetch per step, nothing else).
//
// depth widgets: overlayTex is the desktop clock (and friends) rendered off-screen. it is
// laid over the picture everywhere except where the subject's soft mask is, so the clock
// sits *behind* the person. the mask is sampled at the same parallax-displaced uv as the
// picture, so the cut-out stays glued to the subject while the camera moves.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float hasFrom;
    float hasFromDepth;
    float hasToDepth;
    float seed;
    float aspect;       // screen width / height
    vec2 offset;        // camera offset in picture uv units
    vec2 coverFrom;     // uv scale that makes each picture cover the screen
    vec2 coverTo;
    vec4 inkDark;       // ink for light ground
    vec4 inkLight;      // ink for dark ground (chalk-ish)
    vec4 baseColor;
    float hasOverlay;
    float hasMask;
    float useInk;       // 1 = outline + ink bleed, 0 = a plain crossfade
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D fromDepth;
layout(binding = 3) uniform sampler2D toTex;
layout(binding = 4) uniform sampler2D toDepth;
layout(binding = 5) uniform sampler2D inkTex;   // r stroke, g draw order, b distance from subject
layout(binding = 6) uniform sampler2D overlayTex; // premultiplied widgets layer, screen space
layout(binding = 7) uniform sampler2D toMask;     // a = subject (soft), picture space

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// ink that reads on whatever it lands on: pale over dark ground, dark over light
vec3 inkFor(vec3 ground, vec4 dark, vec4 light) {
    return mix(light.rgb, dark.rgb, smoothstep(0.32, 0.58, luma(ground)));
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * vnoise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

vec2 coverUV(vec2 uv, vec2 cover) {
    return (uv - 0.5) * cover + 0.5;
}

// inverse displacement: find the picture point that lands on this pixel.
// near things (white in the depth map) move more than far things.
vec2 parallax(sampler2D depth, vec2 uv, vec2 off) {
    vec2 p = uv;
    for (int i = 0; i < 4; i++) {
        float d = texture(depth, p).r;
        p = uv - off * (d - 0.35);
    }
    return clamp(p, vec2(0.001), vec2(0.999));
}

// lay the widgets layer down, then put the subject back on top of it
vec3 behind(vec3 col, vec2 uv, vec2 tp, float weight) {
    vec4 o = texture(overlayTex, uv);
    float m = hasMask > 0.5 ? texture(toMask, tp).a * weight : 0.0;
    float k = 1.0 - m;
    return col * (1.0 - o.a * k) + o.rgb * k;
}

void main() {
    vec2 uv = qt_TexCoord0;

    vec2 tu = coverUV(uv, coverTo);
    vec2 tp = hasToDepth > 0.5 ? parallax(toDepth, tu, offset) : tu;
    vec3 toC = texture(toTex, tp).rgb;

    if (progress >= 0.999) {
        if (hasOverlay > 0.5)
            toC = behind(toC, uv, tp, 1.0);
        fragColor = vec4(toC, 1.0) * qt_Opacity;
        return;
    }

    vec2 fu = coverUV(uv, coverFrom);
    vec2 fp = hasFromDepth > 0.5 ? parallax(fromDepth, fu, offset) : fu;
    vec3 fromC = hasFrom > 0.5 ? texture(fromTex, fp).rgb : baseColor.rgb;

    if (useInk < 0.5) {
        float t = smoothstep(0.0, 1.0, progress);
        vec3 c = mix(fromC, toC, t);
        if (hasOverlay > 0.5)
            c = behind(c, uv, tp, t);
        fragColor = vec4(c, 1.0) * qt_Opacity;
        return;
    }

    vec3 ink = texture(inkTex, tu).rgb;
    float stroke = ink.r;
    float order = ink.g;
    float dist = ink.b;

    // 1 · the outline draws itself (order 0 means "no line here")
    float drawT = smoothstep(0.0, 0.45, progress) * 1.02;
    float drawn = order > 0.002 ? stroke * (1.0 - smoothstep(drawT - 0.025, drawT, order)) : 0.0;
    float dry = 1.0 - smoothstep(0.72, 1.0, progress);
    float tooth = 0.72 + 0.28 * vnoise(uv * vec2(aspect, 1.0) * 700.0);   // paper texture in the line

    // 2 · ink bleeds from the subject outward, along a ragged noisy front
    float bleed = smoothstep(0.32, 1.0, progress);
    vec2 nuv = vec2(uv.x * aspect, uv.y);
    float n = fbm(nuv * 3.2 + seed) * 0.65 + fbm(nuv * 13.0 - seed) * 0.35;
    float field = dist * 0.85 + n * 0.32;
    float front = mix(-0.05, 1.25, bleed);
    float reveal = 1.0 - smoothstep(front - 0.05, front, field);
    // the wet rim just behind the front, darker, like ink soaking into paper
    float wet = smoothstep(front - 0.14, front - 0.03, field) * (1.0 - smoothstep(front - 0.01, front + 0.015, field));

    vec3 col = mix(fromC, toC, reveal);
    col = mix(col, inkFor(col, inkDark, inkLight), wet * 0.85 * (1.0 - bleed * 0.6));
    col = mix(col, inkFor(col, inkDark, inkLight), clamp(drawn * dry * tooth, 0.0, 1.0));
    if (hasOverlay > 0.5)
        col = behind(col, uv, tp, reveal);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}

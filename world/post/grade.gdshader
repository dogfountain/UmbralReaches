shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float sharpen = 1.85;
uniform float sharpen_clamp = 0.11;   // caps halos
uniform float band_lo = 200.0;        // degrees
uniform float band_hi = 290.0;
uniform float hue_pull = 0.28;
uniform float warm_protect = 1.0;
uniform vec3 shadow_tint = vec3(0.02, 0.04, 0.22);
uniform vec3 mid_tint    = vec3(0.22, 0.36, 1.00);
uniform vec3 high_tint   = vec3(0.72, 0.88, 1.00);
uniform float split_amount = 0.22;
uniform float saturation = 1.42;
uniform float black_crush = 0.055;
uniform float vignette = 0.42;
uniform float grain = 0.038;
uniform float chroma = 0.0018;
uniform float gloom : hint_range(0.0, 1.0) = 0.0;   // driven by the player's Gloom meter
uniform float hurt : hint_range(0.0, 1.0) = 0.0;    // flash when an enemy fills the dark (Zone)
uniform vec2 hurt_dir = vec2(0.0);                    // screen-space direction of the attacker, 0 = all round

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
float wrapd(float a) { return a - 360.0 * round(a / 360.0); }

float grain_hash(uvec2 p, uint seed) {
    uint n = (p.x * 374761393u + p.y * 668265263u) ^ seed;
    n = (n ^ (n >> 13u)) * 1274126177u;
    return float(n & 65535u) / 65535.0;
}

void fragment() {
    vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));
    vec2 dir = SCREEN_UV - vec2(0.5);

    // Mild chromatic aberration — cheap retro separation. Centre sampled once.
    vec3 c = texture(screen_tex, SCREEN_UV).rgb;
    float r = texture(screen_tex, SCREEN_UV + dir * chroma).r;
    float b = texture(screen_tex, SCREEN_UV - dir * chroma).b;
    vec3 col = vec3(r, c.g, b);

    // Unsharp mask for crunchy PS2 edge bite.
    vec3 blur = (
        texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb +
        texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb +
        texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb +
        texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb
    ) * 0.25;
    col += clamp((col - blur) * sharpen, -vec3(sharpen_clamp), vec3(sharpen_clamp));

    vec3 hsv = rgb2hsv(max(col, 0.0));
    float h = hsv.x * 360.0;
    float warm = smoothstep(12.0, 18.0, h) * (1.0 - smoothstep(58.0, 66.0, h))
               * smoothstep(0.25, 0.5, hsv.y) * smoothstep(0.12, 0.35, hsv.z);
    float teal = smoothstep(155.0, 168.0, h) * (1.0 - smoothstep(188.0, 200.0, h))
               * smoothstep(0.18, 0.4, hsv.y) * smoothstep(0.18, 0.45, hsv.z);
    float d_lo = wrapd(band_lo - h), d_hi = wrapd(band_hi - h);
    float dh = abs(d_lo) < abs(d_hi) ? d_lo : d_hi;
    dh = (h >= band_lo && h <= band_hi) ? 0.0 : dh;
    h += dh * hue_pull * (1.0 - warm * warm_protect) * (1.0 - teal);
    hsv.x = fract(h / 360.0);
    hsv.y = min(hsv.y * saturation, 1.0);
    col = hsv2rgb(hsv);

    float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
    vec3 tint = mix(shadow_tint, mid_tint, smoothstep(0.0, 0.32, l));
    tint = mix(tint, high_tint, smoothstep(0.42, 0.88, l));
    col = mix(col, l * tint * 2.35, split_amount * (1.0 - warm) * (1.0 - teal));
    col = max(col - black_crush, 0.0) / (1.0 - black_crush);

    col *= 1.0 - smoothstep(0.32, 0.88, distance(SCREEN_UV, vec2(0.5))) * vignette;
    // Gloom: violet dark creeps in from the frame edges as the meter fills
    float gv = smoothstep(0.2, 0.95, distance(SCREEN_UV, vec2(0.5)) * (0.6 + gloom * 0.8)) * gloom;
    col = mix(col, col * vec3(0.35, 0.22, 0.65), gv);
    col *= 1.0 - gv * 0.55;
    // Hurt: a blood-violet bite from the frame edge, biased toward the attacker
    vec2 hd = SCREEN_UV - vec2(0.5);
    float side = length(hurt_dir) > 0.01 ? clamp(dot(normalize(hd + 1e-4), normalize(hurt_dir)) * 0.5 + 0.5, 0.0, 1.0) : 1.0;
    float hv = smoothstep(0.25, 0.75, length(hd) * 1.25) * hurt * (0.35 + 0.65 * side * side);
    col = mix(col, vec3(0.55, 0.04, 0.16), hv * 0.75);
    uint seed = uint(fract(TIME * 17.0) * 65536.0);
    col += (grain_hash(uvec2(FRAGCOORD.xy), seed) - 0.5) * grain;
    COLOR = vec4(col, 1.0);
}

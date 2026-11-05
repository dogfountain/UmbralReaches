shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float sharpen = 1.85;
uniform float sharpen_clamp = 0.11;   // caps halos
uniform float band_lo = 200.0;        // degrees
uniform float band_hi = 290.0;
uniform float hue_pull = 0.28;
uniform float warm_protect = 1.0;
uniform float warm_min_v = 0.12;       // warm hues below this brightness are not protected
uniform float green_lo = 155.0;        // greens/teals from here to 200 deg keep their hue
uniform vec3 shadow_tint = vec3(0.02, 0.04, 0.22);
uniform vec3 mid_tint    = vec3(0.22, 0.36, 1.00);
uniform vec3 high_tint   = vec3(0.72, 0.88, 1.00);
uniform float split_amount = 0.22;
uniform float saturation = 1.42;
uniform float warm_saturation = 1.42;  // protected warm light (fire, candles, gold) gets its own push: warm/cool contrast
uniform float warm_lean = 0.0;          // keep low-saturation pixels lit by warm light (lantern pools); 0 = off
uniform float warm_lean_lo = 1.3;      // red/blue ratio where that starts
uniform float violet_protect = 0.0;    // bright, saturated violet emissives (rift, gloom magic) keep part of their hue
uniform float black_crush = 0.055;
uniform float contrast = 1.0;          // S-curve on luminance about `pivot` (hue kept); 1 = off
uniform float pivot = 0.26;
uniform float highlight_gain = 0.0;    // lifts the top of the range (moonlit stone, foam, the moon)
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
    // warm survives only where it is BRIGHT (fire, candles, lit windows, gold): dim warm-brown
    // stone under blue moonlight goes blue instead of reading magenta
    float warm = smoothstep(8.0, 16.0, h) * (1.0 - smoothstep(58.0, 66.0, h))
               * smoothstep(0.25, 0.5, hsv.y) * smoothstep(warm_min_v, warm_min_v + 0.35, hsv.z);
    // a fire's core clips toward white: too pale for the band test above, so the hue pull and the
    // azure split tone turned every brazier and hearth flame icy blue-white (r29). Bright pixels that
    // still lean warm (red over blue, not green) keep their colour.
    vec3 cw = max(col, 0.0);
    warm = max(warm, smoothstep(0.62, 0.9, hsv.z) * smoothstep(0.015, 0.08, cw.r - cw.b) * step(cw.g, cw.r * 1.08));
    // ENS art pass: lantern and fire light pooling on grey ground mixes with the blue moon into a low-
    // saturation warm grey, which failed the tests above and was pulled blue, so a lantern lit no
    // warm pool at all. Pixels where red clearly leads blue (r > 1.3 b) are lit by a warm source: keep
    // them. Moonlit brown wood and stone sit near r = 1.2 b and still go blue.
    warm = max(warm, smoothstep(warm_lean_lo, warm_lean_lo + 0.3, cw.r / max(cw.b, 1e-3))
               * step(cw.g, cw.r * 1.05) * smoothstep(0.03, 0.09, hsv.z) * warm_lean);
    // strong reds (health bars, telegraphs, blood, hit sparks) sat outside the warm band and were
    // pulled all the way round to blue-violet. Saturated, lit reds (-20..12 deg) keep their hue; dull
    // or dark red-browns (stone, wood, earth) still go blue under the moon (r29, register from A).
    float hr = h > 180.0 ? h - 360.0 : h;
    warm = max(warm, smoothstep(-26.0, -18.0, hr) * (1.0 - smoothstep(10.0, 16.0, hr))
               * smoothstep(0.5, 0.65, hsv.y) * smoothstep(0.28, 0.45, hsv.z));
    // greens and teals (moss, ferns, glow magic) keep their hue
    float teal = smoothstep(green_lo - 12.0, green_lo, h) * (1.0 - smoothstep(188.0, 200.0, h))
               * smoothstep(0.18, 0.4, hsv.y) * smoothstep(0.1, 0.3, hsv.z);
    float d_lo = wrapd(band_lo - h), d_hi = wrapd(band_hi - h);
    float dh = abs(d_lo) < abs(d_hi) ? d_lo : d_hi;
    dh = (h >= band_lo && h <= band_hi) ? 0.0 : dh;
    // Partly protected pixels (fire-lit skin and cloth at the edge of the warm band) blend the
    // kept colour and the fully pulled colour in RGB. Rotating the hue part-way would march red
    // through magenta on its way to blue; an RGB blend goes through a dull neutral instead.
    // bright saturated violet (250-300 deg, S > 0.6, V > 0.5) is magic, not moonlit stone: let part of it
    // through so rift light and gloom spells read apart from the blue world (r30 critique, finding 3b)
    float violet = smoothstep(244.0, 252.0, h) * (1.0 - smoothstep(296.0, 304.0, h))
                 * smoothstep(0.55, 0.7, hsv.y) * smoothstep(0.45, 0.65, hsv.z) * violet_protect;
    float k = (1.0 - warm * warm_protect) * (1.0 - teal) * (1.0 - violet);
    hsv.y = min(hsv.y * mix(saturation, warm_saturation, warm), 1.0);
    vec3 kept = hsv2rgb(vec3(hsv.x, hsv.y, hsv.z));
    vec3 pulled = hsv2rgb(vec3(fract((h + dh * hue_pull) / 360.0), hsv.y, hsv.z));
    col = mix(kept, pulled, k);

    float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
    vec3 tint = mix(shadow_tint, mid_tint, smoothstep(0.0, 0.32, l));
    tint = mix(tint, high_tint, smoothstep(0.42, 0.88, l));
    col = mix(col, l * tint * 2.35, split_amount * (1.0 - warm) * (1.0 - teal) * (1.0 - violet));
    col = max(col - black_crush, 0.0) / (1.0 - black_crush);
    // contrast on luminance only, so the S-curve deepens shadows and lifts lights without
    // shifting hue or clipping colour channels apart
    float lc = max(dot(col, vec3(0.2126, 0.7152, 0.0722)), 1e-5);
    float lt = lc < pivot ? pivot * pow(lc / pivot, contrast)
                          : 1.0 - (1.0 - pivot) * pow(max(1.0 - lc, 0.0) / (1.0 - pivot), contrast);
    lt += highlight_gain * smoothstep(0.35, 0.9, lc) * (1.0 - lc);
    col *= lt / lc;

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

shader_type sky;
render_mode use_half_res_pass;

// Global instead of TIME: TIME flags the whole shader as realtime and QUALITY
// would GGX-filter the cubemap every frame. Cubemap pass does not read this.
global uniform float sky_time;

#include "res://world/sky/sky_stars.gdshaderinc"
#include "res://world/sky/sky_vistas.gdshaderinc"

uniform vec3 col_deep  = vec3(0.024, 0.039, 0.153); // abyss  #060A27
uniform vec3 col_rift  = vec3(0.357, 0.176, 0.839); // rift   #5B2DD6
uniform vec3 col_lilac = vec3(0.663, 0.545, 1.000); // lilac  #A98BFF
uniform vec3 col_hex   = vec3(0.753, 0.302, 1.000); // hex    #C04DFF
uniform vec3 vortex_dir = vec3(0.0, 0.35, -1.0);
uniform vec3 moon_dir   = vec3(0.6, 0.45, -0.4);
uniform float twist = 3.8;          // arm tightness
uniform float arm_scale = 3.4;      // size of the star clouds
uniform float detail_scale = 9.0;   // fine filaments
uniform float spin_speed = 0.015;   // revolutions per second
uniform float spin_phase = 0.0;     // revolutions; keeps the angle continuous when spin_speed changes (reactivity.gd)
uniform float intensity = 1.1;      // halved (Luke, 7 Nov: the vortex washed the night); was 2.2, above 1.0 so glow caught the arms
uniform float vortex_size = 0.6;    // the vortex's extent on the sky, against its first size (1.0)
// The living sky (core/world/night_life/sky_life.gd): the moon's phase and its eclipse, constellations, aurora
// nights, a cloud deck lit from below by the fires on the ground. All default to the old sky.
uniform float moon_phase = 0.5;     // 0 new .. 0.5 full .. 1 new (waxing = lit on the right); tied to the night count
uniform float moon_glow = 1.0;      // the disc, corona and streaks: an eclipse takes them to a tenth
uniform vec3 moon_tint = vec3(1.0); // and turns what is left of it copper
uniform sampler2D constellations : source_color, hint_default_black, filter_linear, repeat_disable;
uniform float const_vis = 1.0;
uniform float aurora = 1.0;         // the veils' strength tonight (0.3 faint .. 1.0 a great night; a surge lifts it)
uniform float dawn = 0.0;           // the grey before the morning, low in the east (the last tenth of the night)
uniform float cloud_speed = 1.0;      // a gale scuds the cloud
uniform float cloud_cover = 0.0;    // 0 clear .. 1 a deck of cloud (the weather's fronts raise it)
uniform vec4 fire_glow[6];          // xyz: the direction to a fire on the ground, w: how strongly it lights the cloud above it
uniform float vistas = 1.0;         // the far ranges and the drain veils (sky_vistas.gdshaderinc); 0 with -- --no-vista-sky (A/B)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
    return v;
}

vec3 vortex(vec3 d) {
    vec3 c = normalize(vortex_dir);
    vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), c));
    vec3 u = cross(c, r);
    float facing = dot(d, c);
    vec2 p = vec2(dot(d, r), dot(d, u)) / max(facing, 0.08) / vortex_size;
    float rad = length(p);
    float ang = atan(p.y, p.x) + twist * log(rad + 0.04) - (sky_time * spin_speed + spin_phase) * TAU;
    vec2 q = vec2(cos(ang), sin(ang)) * rad;
    float clouds = fbm(q * arm_scale + 3.0);
    float fil = 1.0 - abs(2.0 * fbm(q * detail_scale - sky_time * 0.02) - 1.0); // ridged filaments
    float arms = clouds * 0.75 + fil * fil * 0.4;
    float m = smoothstep(0.4, 0.95, arms)
            * smoothstep(1.6, 0.2, rad) * smoothstep(0.0, 0.15, facing);
    float core = smoothstep(0.02, 0.16, rad);              // dark eye
    float rim  = exp(-pow((rad - 0.22) * 9.0, 2.0));       // bright ring round it
    vec3 col = mix(col_deep, col_rift, m);
    col = mix(col, col_lilac, m * m);
    col += col_hex * rim * 0.8 * smoothstep(0.0, 0.15, facing);
    return col * core * intensity;
}

// A deck of cloud on a plane overhead: dark, edged with moonlight, lit warm from below over the fires on the ground.
vec4 cloud_layer(vec3 d, vec3 col) {
    if (cloud_cover < 0.01 || d.y < 0.02) {
        return vec4(col, 1.0);
    }
    vec2 p = d.xz / (d.y + 0.3) * 1.5 + vec2(sky_time * 0.004, sky_time * 0.0017) * cloud_speed;
    float c = fbm(p * 1.4) * 0.7 + fbm(p * 3.1 + 7.0) * 0.3;
    float edge = 1.0 - cloud_cover * 0.85;
    float m = smoothstep(edge, edge + 0.22, c) * smoothstep(0.02, 0.22, d.y);
    vec3 lit = vec3(0.0);
    for (int i = 0; i < 6; i++) {
        float s = fire_glow[i].w;
        lit += vec3(1.0, 0.52, 0.22) * s * pow(max(dot(d, fire_glow[i].xyz), 0.0), 5.0);
    }
    vec3 cc = col_deep * 0.7 + vec3(0.035, 0.05, 0.1) * (0.4 + c) + lit * (0.25 + 0.75 * m);
    return vec4(mix(col, cc, m * 0.85), 1.0 - m * 0.9);   // the alpha carries the cloud: the stars are drawn behind it
}

void sky() {
    if (AT_CUBEMAP_PASS) {
        float facing = dot(EYEDIR, normalize(vortex_dir));
        float k = smoothstep(-0.1, 0.6, facing);
        float ang = atan(EYEDIR.x, EYEDIR.z);
        float arms = 0.5 + 0.5 * sin(ang * 3.0 + EYEDIR.y * 2.2);
        vec3 col = mix(col_deep, col_rift * 0.42, k);
        col = mix(col, col_lilac * 0.28, k * arms * 0.45);
        col += vec3(0.035, 0.04, 0.07) * k;
        // radiance feeds ambient and aerial perspective: a cool silver horizon band lifts the shade
        // sides and the far land, and the ground half bounces a dim blue-green instead of abyss blue
        float below = smoothstep(0.0, -0.45, EYEDIR.y);
        col = mix(col, vec3(0.045, 0.07, 0.095), below * 0.75);
        // the band follows the moon: silver-lilac on its side, a deeper teal-blue away from it, so the far land
        // (fog takes this radiance) goes warm-pale toward the moon and cool-dark the other way; same mean light
        vec2 hd = normalize(EYEDIR.xz + vec2(1e-4));
        vec2 mh = normalize(moon_dir.xz + vec2(1e-4));
        float toward = dot(hd, mh) * 0.5 + 0.5;
        vec3 band = mix(vec3(0.052, 0.098, 0.168), vec3(0.108, 0.122, 0.178), toward);
        // haze is densest low and thins with height: peaks (higher in the sky than the valley floor) take a
        // darker, cooler fog colour, so their tops stay crisp against the lit sky instead of greying out
        col += band * pow(1.0 - abs(EYEDIR.y), 10.0);
        COLOR = col;
    } else if (AT_HALF_RES_PASS) {
        vec3 col = vortex(EYEDIR);
        // Starburst spikes: wider than a pixel, so half resolution still holds them.
        float burst = sky_bursts(EYEDIR, 220.0);
        col += burst * vec3(0.86, 0.93, 1.2) * 0.7;
        if (vistas > 0.5) {
            col += vs_veils(EYEDIR, vortex_dir, sky_time) * aurora;
        }
        vec4 cl = cloud_layer(EYEDIR, col);
        COLOR = cl.rgb;
        ALPHA = cl.a;
    } else {
        vec3 col = HALF_RES_COLOR.rgb;
        float star = sky_stars(EYEDIR, 400.0, 0.022) * HALF_RES_COLOR.a;
        col += star * vec3(0.82, 0.88, 1.12) * 0.75;
        float dust = noise(EYEDIR.xy * 6.0 + EYEDIR.z * 3.0) * noise(EYEDIR.xz * 3.5);
        col += col_rift * dust * 0.12;
        vec3 md = normalize(moon_dir);
        float mu = max(dot(EYEDIR, md), 0.0);
        vec3 right = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
        vec3 bitan = normalize(cross(right, md));
        vec3 off = EYEDIR - md * dot(EYEDIR, md);
        float hx = dot(off, right);
        float hy = dot(off, bitan);
        float disc = smoothstep(0.9985, 0.9997, mu);
        // the phase: the lit part of a sphere seen from the front, the light coming round it by `moon_phase`
        float ph = moon_phase * TAU;
        vec2 pd = vec2(hx, hy) / 0.0424;
        vec3 sph = vec3(pd, sqrt(max(1.0 - dot(pd, pd), 0.0)));
        float lit_part = mix(0.06, 1.0, smoothstep(-0.05, 0.05, dot(sph, vec3(sin(ph), 0.0, -cos(ph)))));
        float bright = 0.35 + 0.65 * (0.5 - 0.5 * cos(ph));
        disc *= lit_part;
        float corona = pow(mu, 180.0);
        float streak = exp(-abs(hx) * 48.0) * exp(-abs(hy) * 5.5) * pow(mu, 10.0);
        float cross = exp(-abs(hx) * 6.0) * exp(-abs(hy) * 48.0) * pow(mu, 10.0);
        // The old four "ghosts" sat at normalize(mix(md, -md, t)) = md for t < 0.5 (three of them, weights
        // 0.264 + 0.2 + 0.136) and -md (under the horizon, faded out) for the fourth: one Gaussian at the
        // moon is the same image without a loop of normalize/exp per full-res sky pixel.
        float dm = length(EYEDIR - md);
        float ghosts = exp(-dm * dm * 720.0) * 0.6;
        // the moon and its flare toned down about 30 % (Luke, 7 Nov: the moon read too bright), with its light
        // and halved twice more (the moon's glow washed the sky pale and the land with it)
        col += vec3(0.72, 0.82, 1.02) * moon_tint * (disc * 0.45 + corona * 0.075 * bright) * moon_glow;
        col += vec3(0.52, 0.68, 1.05) * moon_tint * (streak * 0.14 + cross * 0.06) * bright * moon_glow;
        col += vec3(0.42, 0.52, 0.92) * ghosts * 0.05 * bright * moon_glow;
        // the constellations: baked once into an equirect texture (a texture fetch per sky pixel, nothing computed)
        vec2 cuv = vec2(atan(EYEDIR.x, -EYEDIR.z) / TAU + 0.5, acos(clamp(EYEDIR.y, -1.0, 1.0)) / PI);
        col += texture(constellations, cuv).rgb * const_vis * HALF_RES_COLOR.a * smoothstep(0.03, 0.2, EYEDIR.y);
        col = mix(col_deep * 0.5, col, smoothstep(-0.05, 0.12, EYEDIR.y)); // horizon falloff
        // moon-silvered haze low on the sky: ridges and towers separate from it
        col += vec3(0.11, 0.17, 0.29) * exp(-abs(EYEDIR.y) * 9.0);
        col += vec3(0.16, 0.13, 0.12) * dawn * exp(-abs(EYEDIR.y) * 8.0) * pow(max(dot(normalize(EYEDIR.xz + vec2(1e-4)), vec2(0.95, 0.3)), 0.0), 2.0);   // a thinner, brighter band: the ridges read dark against it
        // far ranges past the Realm's own mountains (sky_vistas.gdshaderinc), paler on the moon's side
        vec2 hz = normalize(EYEDIR.xz + vec2(1e-4));
        float toward = dot(hz, normalize(md.xz + vec2(1e-4))) * 0.5 + 0.5;
        float north_fade = smoothstep(0.9, 0.3, dot(hz, normalize(vortex_dir.xz + vec2(1e-4))));
        if (vistas > 0.5) {
            col = vs_far_ranges(EYEDIR, col, mix(vec3(0.07, 0.11, 0.19), vec3(0.13, 0.17, 0.27), toward), col_deep, north_fade);
        }
        COLOR = col;
    }
}

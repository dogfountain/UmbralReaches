shader_type sky;
render_mode use_half_res_pass;

// Global instead of TIME: TIME flags the whole shader as realtime and QUALITY
// would GGX-filter the cubemap every frame. Cubemap pass does not read this.
global uniform float sky_time;

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
uniform float intensity = 2.2;      // above 1.0 so glow catches the arms

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
    vec2 p = vec2(dot(d, r), dot(d, u)) / max(facing, 0.08);
    float rad = length(p);
    float ang = atan(p.y, p.x) + twist * log(rad + 0.04) - sky_time * spin_speed * TAU;
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

void sky() {
    if (AT_CUBEMAP_PASS) {
        float facing = dot(EYEDIR, normalize(vortex_dir));
        float k = smoothstep(-0.1, 0.6, facing);
        float ang = atan(EYEDIR.x, EYEDIR.z);
        float arms = 0.5 + 0.5 * sin(ang * 3.0 + EYEDIR.y * 2.2);
        vec3 col = mix(col_deep, col_rift * 0.42, k);
        col = mix(col, col_lilac * 0.28, k * arms * 0.45);
        col += vec3(0.035, 0.04, 0.07) * k;
        COLOR = col;
    } else if (AT_HALF_RES_PASS) {
        vec3 col = vortex(EYEDIR);
        // Starburst spikes are wider than a pixel, so half resolution still holds them.
        float burst = 0.0;
        float scale = 220.0;
        vec2 base_id = floor(EYEDIR.xy * scale);
        float zid = floor(EYEDIR.z * scale);
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 id = base_id + vec2(float(i), float(j));
                float key = step(0.998, hash(id + zid));
                vec2 dlt = EYEDIR.xy - (id + 0.5) / scale;
                float spike = exp(-abs(dlt.x) * 160.0) * exp(-abs(dlt.y) * 1400.0)
                            + exp(-abs(dlt.y) * 160.0) * exp(-abs(dlt.x) * 1400.0);
                burst += key * spike;
            }
        }
        col += burst * vec3(0.86, 0.93, 1.2) * 0.7;
        COLOR = col;
        ALPHA = 1.0;
    } else {
        vec3 col = HALF_RES_COLOR.rgb;
        float sh = hash(floor(EYEDIR.xy * 780.0) + floor(EYEDIR.z * 780.0));
        float star = step(0.9938, sh);
        col += star * vec3(0.82, 0.88, 1.12) * 0.7;
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
        float corona = pow(mu, 180.0);
        float streak = exp(-abs(hx) * 48.0) * exp(-abs(hy) * 5.5) * pow(mu, 10.0);
        float cross = exp(-abs(hx) * 6.0) * exp(-abs(hy) * 48.0) * pow(mu, 10.0);
        float ghosts = 0.0;
        for (int g = 0; g < 4; g++) {
            float t = float(g) * 0.16 + 0.14;
            vec3 gp = normalize(mix(md, -md, t));
            float d = length(EYEDIR - gp);
            ghosts += exp(-d * d * 720.0) * (0.32 - t * 0.4);
        }
        col += vec3(0.72, 0.82, 1.02) * (disc * 2.1 + corona * 0.5);
        col += vec3(0.52, 0.68, 1.05) * (streak * 0.9 + cross * 0.4);
        col += vec3(0.42, 0.52, 0.92) * ghosts * 0.35;
        col = mix(col_deep * 0.5, col, smoothstep(-0.05, 0.12, EYEDIR.y)); // horizon falloff
        COLOR = col;
    }
}

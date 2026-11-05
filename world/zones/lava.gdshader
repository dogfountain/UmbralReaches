shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_burley;
// Molten surface for the chasm floor. Dark basalt crust broken by bright cracks, the whole sheet
// crawling on domain-warped value noise. Emission is HDR so the glow blooms and feeds the
// volumetric fog, which is what sells the pit as the one warm thing in a cold zone.
// Self-contained: the noise is generated here, no texture dependency.

uniform vec3 crust_color : source_color = vec3(0.07, 0.025, 0.03);
uniform vec3 hot_color : source_color = vec3(1.0, 0.22, 0.03);
uniform vec3 core_color : source_color = vec3(1.0, 0.62, 0.16);
uniform float emission_energy = 2.2;
uniform float crack_width = 0.42;     // lower = thinner, meaner cracks
uniform float flow_speed = 0.035;
uniform float noise_scale = 0.055;    // world units -> noise units
uniform float warp = 0.9;
// Banks: R = distance to land/piers (0 at the rock, 1 at >= bank_reach m), built at runtime by
// LavaWorks from the real terrain and pier footprints. Without it the sheet is all open river.
uniform sampler2D bank_tex : filter_linear, repeat_disable, hint_default_white;
uniform vec2 bank_origin = vec2(-46.0, -132.0);
uniform vec2 bank_size = vec2(92.0, 130.0);
uniform vec2 flow_dir = vec2(0.15, -1.0);   // the river's current (world xz)
uniform float flow_rate = 0.9;               // m/s of crust drift
uniform float swell = 0.11;

// VERTEX is view-space inside fragment(), which would make the crust swim as the camera moves.
// Carry the world position across explicitly so the pattern stays welded to the world.
varying vec3 world_pos;
varying float bank_v;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * amp;
		p *= 2.07;
		amp *= 0.5;
	}
	return v;
}

float bank_at(vec2 xz) {
	vec2 b = (xz - bank_origin) / bank_size;
	return textureLod(bank_tex, b, 0.0).r;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	bank_v = bank_at(world_pos.xz);
	// slow swells, damped to nothing at the banks so the sheet never lifts off the rock
	float s = sin(world_pos.x * 0.21 + TIME * 0.6) * sin(world_pos.z * 0.17 - TIME * 0.45);
	VERTEX.y += s * swell * smoothstep(0.0, 0.6, bank_v);
	world_pos.y += s * swell * smoothstep(0.0, 0.6, bank_v);
}

void fragment() {
	vec2 uv = world_pos.xz * noise_scale;     // world-space, so the sheet never shows UV seams
	float t = TIME * flow_speed;
	float bank = bank_at(world_pos.xz);

	// Two-phase flow: the crust is advected along the current and re-seeded every cycle; two
	// copies half a cycle apart cross-fade, so plates drift downstream without ever smearing.
	// The current slows to a creep near the banks, as real flows do.
	vec2 fd = normalize(flow_dir) * flow_rate * noise_scale * mix(0.15, 1.0, bank);
	float ph0 = fract(TIME * 0.06);
	float ph1 = fract(TIME * 0.06 + 0.5);
	float mixw = abs(ph0 - 0.5) * 2.0;

	vec2 q = vec2(fbm(uv + vec2(t, -t * 0.6)), fbm(uv + vec2(5.2, 1.3) - t * 0.4));
	float n0 = fbm(uv - fd * ph0 * 16.0 + warp * q);
	float n1 = fbm(uv - fd * ph1 * 16.0 + warp * q + vec2(3.7, 9.1));
	float n = mix(n0, n1, mixw);

	// Cells: ridged noise gives closed shapes, and the gaps between them read as cracks.
	float cell = abs(n - 0.5) * 2.0;
	float crack = 1.0 - smoothstep(0.0, crack_width, cell);
	float vein = 1.0 - smoothstep(0.0, crack_width * 1.8, abs(fbm(uv * 2.4 + q) - 0.5) * 2.0);
	// embers in the cracks: round, sparse and jittered (square hash cells read as pixels)
	vec2 sc = uv * 48.0 + vec2(0.0, t * 3.0);
	vec2 ci = floor(sc);
	vec2 cf = fract(sc) - 0.5 - (vec2(hash(ci + 1.7), hash(ci + 7.3)) - 0.5) * 0.6;
	float speck = step(0.95, hash(ci)) * (1.0 - smoothstep(0.06, 0.18, length(cf)));

	// A slow pulse so the cracks breathe rather than sitting static.
	float pulse = 0.82 + 0.18 * sin(TIME * 0.5 + n * 9.0);
	float heat = max(crack, vein * 0.45) * pulse;
	// the open channel runs hotter (thin crust); near the rock it cools into a dark shelf of
	// crust, with a bright line of magma where it still licks the stone
	heat = mix(heat * 0.25, min(1.0, heat * 1.15 + 0.08), smoothstep(0.08, 0.7, bank));
	float rim = smoothstep(0.0, 0.03, bank) * (1.0 - smoothstep(0.05, 0.13, bank));
	heat = max(heat, rim * (0.75 + 0.25 * sin(TIME * 1.7 + world_pos.x * 0.8)));

	// fine grain on the crust plates so they read as rock, not flat paint
	float grain = 0.65 + 0.7 * vnoise(uv * 22.0 + q * 3.0);
	ALBEDO = mix(crust_color * grain, hot_color, heat * 0.65);
	float sheet = mix(0.08, 0.28, smoothstep(0.1, 0.6, bank)) + heat * 0.72;
	EMISSION = mix(hot_color * 0.45, core_color, smoothstep(0.4, 1.0, heat)) * sheet * emission_energy;
	EMISSION += core_color * speck * heat * emission_energy * 0.8;
	ROUGHNESS = mix(0.96, 0.32, heat);
	METALLIC = 0.0;
}

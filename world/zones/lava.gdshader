shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_burley;
// Molten surface for the chasm floor. Dark basalt crust broken by bright cracks, the whole sheet
// crawling downstream. Emission is HDR so the glow blooms and feeds the volumetric fog, which is
// what sells the pit as the one warm thing in a cold zone.
// Self-contained: the noise is generated here, no texture dependency.
//
// r35 (lane D): plates, not paint, for less ALU.
//   was: four 5-octave fbm (+ a 5-octave vein layer) with a sin() hash, cross-faded between two
//     advected phases: ~107 sin hashes a pixel, and the ridged-noise "cracks" covered ~40 % of the
//     sheet, so the river read as one flat red-orange wash.
//   now: crust plates are a jittered cell pattern (Worley F2-F1, 3x3 cells) whose shared edges are
//     the cracks: real closed plates with thin lines of fire between them. A low-frequency heat field
//     widens the cracks into molten channels in the hot reaches and pinches them shut where the crust
//     has cooled; a domain warp bends the plate edges so they never read as tiles. Heat runs a
//     blackbody ramp (blood red -> orange -> amber -> a white-hot line down the widest cracks), plate
//     middles sit dark. The plates drift with the current by a plain translation, so the two
//     cross-faded phases (and their ghost double cracks) are gone. Hash is sin-free (Hoskins).
//     About half the ALU of the old sheet; peak emission is the old peak (bloom unchanged).
//     The banks keep their dark crust shelf and the bright contact rim (LavaWorks' bank mask).

uniform vec3 crust_color : source_color = vec3(0.07, 0.025, 0.03);
uniform vec3 hot_color : source_color = vec3(1.0, 0.22, 0.03);
uniform vec3 core_color : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 white_hot : source_color = vec3(1.0, 0.84, 0.55);
uniform float emission_energy = 2.2;
uniform float crack_width = 0.42;     // lower = thinner, meaner cracks (plate-cell units x 0.5)
uniform float flow_speed = 0.035;
uniform float noise_scale = 0.055;    // world units -> noise units
uniform float warp = 0.9;
uniform float plate_scale = 6.5;      // plates per noise unit (~2.8 m plates at noise_scale 0.055)
uniform float plate_dark = 0.4;       // emission left at a crust plate's thick middle (open channel)
uniform float plate_stretch = 1.0;    // < 1 draws the plates out along flow_dir (rafts of crust riding the current)
// Banks: R = distance to land/piers (0 at the rock, 1 at >= bank_reach m), built at runtime by
// LavaWorks from the real terrain and pier footprints. Without it the sheet is all open river.
uniform sampler2D bank_tex : filter_linear, repeat_disable, hint_default_white;
uniform vec2 bank_origin = vec2(-46.0, -132.0);
uniform vec2 bank_size = vec2(92.0, 130.0);
uniform vec2 flow_dir = vec2(0.15, -1.0);   // the river's current (world xz)
uniform float flow_rate = 0.9;               // m/s of crust drift
uniform float swell = 0.11;
// Cooling (r39, the Ashen Rift from scratch; Luke, 9 Nov: no fire by the village): one element, cooling towards the village end. North
// of heat_z1 (world z smaller) the lava is molten; south of heat_z0 it has crusted black, thin dim seams between cold plates. LavaWorks
// sets both under the Realm; the defaults keep the whole sheet molten.
uniform float heat_z0 = 1001.0;
uniform float heat_z1 = 1000.0;
uniform int debug_view = 0;           // 1: the cooling (r), the open lava off the rock (g), the rafts (b) as colour (look-dev shots only)

// VERTEX is view-space inside fragment(), which would make the crust swim as the camera moves.
// Carry the world position across explicitly so the pattern stays welded to the world.
varying vec3 world_pos;

// sin-free hashes (Dave Hoskins, "Hash without Sine")
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
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

// three octaves, renormalised to 0..1
float fbm3(vec2 p) {
	float v = vnoise(p) * 0.5;
	p *= 2.07;
	v += vnoise(p) * 0.25;
	p *= 2.07;
	v += vnoise(p) * 0.125;
	return v * 1.1429;
}

// Worley F2 - F1 over a 3x3 neighbourhood: 0 on the edge two plates share, ~0.5 at a plate's middle.
// .y = F1 (distance to the plate's own centre), for the per-plate shading.
// .z = the plate's own id (0..1, the hash of its cell): which plates are crust rafts and which open lava in the molten lake
vec3 plates(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + hash2(i + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash(i + g + 17.3);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	d1 = sqrt(d1);
	return vec3(sqrt(d2) - d1, d1, id);
}

float bank_at(vec2 xz) {
	vec2 b = (xz - bank_origin) / bank_size;
	return textureLod(bank_tex, b, 0.0).r;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bank_v = bank_at(world_pos.xz);
	// slow swells, damped to nothing at the banks so the sheet never lifts off the rock
	float s = sin(world_pos.x * 0.21 + TIME * 0.6) * sin(world_pos.z * 0.17 - TIME * 0.45);
	float still = mix(0.1, 1.0, 1.0 - smoothstep(heat_z1, heat_z0, world_pos.z));   // the crust hardly heaves
	VERTEX.y += s * swell * smoothstep(0.0, 0.6, bank_v) * still;
	world_pos.y += s * swell * smoothstep(0.0, 0.6, bank_v) * still;
}

void fragment() {
	// welded to the sheet (its own middle as the origin), so the sheet never shows UV seams and the patterns stay small numbers where
	// the endgame stands, 310 m east of the world's origin
	vec2 uv = (world_pos.xz - (bank_origin + bank_size * 0.5)) * noise_scale;
	float t = TIME * flow_speed;
	float bank = bank_at(world_pos.xz);
	float heatz = 1.0 - smoothstep(heat_z1, heat_z0, world_pos.z);       // 1 molten .. 0 crusted
	// the deep end, under the Ward Crag and the summit: the hottest and brightest
	float core_z = 1.0 - smoothstep(heat_z1 - 34.0, heat_z1 - 6.0, world_pos.z);
	// the crust shelf along the rock: wide where the lava has cooled, a narrow lip round the rock in the molten lake
	float open = smoothstep(mix(0.08, 0.015, heatz), mix(0.7, 0.2, heatz), bank);

	// the current carries the plates (a plain translation: no shear, so no re-seeding needed);
	// the warp field crawls slowly on its own, so plate edges bend and creep as they drift
	vec2 drift = normalize(flow_dir) * flow_rate * noise_scale * TIME;
	vec2 q = vec2(fbm3(uv + vec2(t, -t * 0.6)), fbm3(uv + vec2(5.2, 1.3) - t * 0.4)) - 0.5;
	float hot = smoothstep(0.3, 0.75, fbm3(uv * 0.6 + q * 0.8 - drift * 0.5 + vec2(2.1, 7.7)));
	// plates drawn out along the current (a river's crust tears into rafts, not honeycomb). Regional variety is in the heat and the crust's
	// coverage only: a plate size or a heading that changed across the sheet sheared the plates into rings and swirls (r39)
	float r1 = fbm3(uv * 0.24 + vec2(3.7, 1.1));
	hot = clamp(hot * mix(0.3, 1.15, heatz) + (r1 - 0.5) * 0.45 + (heatz - 0.5) * 0.35, 0.0, 1.0);
	vec2 fd = normalize(flow_dir);
	vec2 pu = uv - drift + warp * q * 0.8;
	pu = vec2(dot(pu, vec2(fd.y, -fd.x)), dot(pu, fd) * plate_stretch);
	vec3 pl = plates(pu * plate_scale);
	float edge = pl.x;
	// the molten lake: most plates there are open lava, the rest crust rafts drifting on it (all crust where it has cooled, and on the
	// shelf by the rock)
	float raft = max(step(pl.z, mix(1.0, 0.34, heatz) - 0.1 * core_z), 1.0 - smoothstep(0.1, 0.45, open + (1.0 - heatz)));

	// cracks: thin where the crust has cooled, opening into molten channels in the hot reaches;
	// fwidth keeps a far crack a soft line instead of a crawling dotted one
	float w = crack_width * mix(0.45, 3.6, hot * hot) * mix(0.6, 1.0, open) * mix(0.45, 1.0, heatz);
	float aa = fwidth(edge);
	// cooled reaches let some edges go dark entirely, so not every seam is lit (no tiled look)
	float lit = smoothstep(0.15, 0.6, hot + 0.6 * vnoise(uv * plate_scale * 0.5 + 3.3) - 0.3) * mix(0.5, 1.0, heatz);
	float crack = (1.0 - smoothstep(0.0, w + aa, edge)) * mix(0.3, 1.0, lit);
	// hairline fissures across the plates where the crust is thin (one ridged noise, hot reaches only)
	float fn = abs(vnoise((uv - drift) * plate_scale * 2.3 + q * 4.0) - 0.5);
	crack = max(crack, (1.0 - smoothstep(0.0, 0.022 + fwidth(fn), fn)) * hot * hot * hot * 0.4);
	float core = 1.0 - smoothstep(0.0, w * 0.35 + aa, edge);       // the crack's molten middle
	float plate = smoothstep(w, w * 3.5 + 0.12, edge);               // a plate's thick, cooled middle
	// embers in the cracks: round, sparse and jittered (square hash cells read as pixels)
	vec2 sc = uv * 48.0 + vec2(0.0, t * 3.0);
	vec2 ci = floor(sc);
	vec2 cf = fract(sc) - 0.5 - (hash2(ci + 1.7) - 0.5) * 0.6;
	float speck = step(0.95, hash(ci)) * (1.0 - smoothstep(0.06, 0.18, length(cf)));

	// A slow pulse so the cracks breathe rather than sitting static (each plate a little out of step).
	float pulse = 0.82 + 0.18 * sin(TIME * 0.5 + pl.y * 6.0 + hot * 9.0);
	float heat = max(crack, hot * 0.3 * (1.0 - plate)) * pulse;
	// the open channel runs hotter (thin crust); near the rock it cools into a dark shelf of
	// crust, with a bright line of magma where it still licks the stone
	heat = mix(heat * 0.25, min(1.0, heat * 1.15 + 0.08), open);
	float rim = smoothstep(0.0, 0.03, bank) * (1.0 - smoothstep(0.05, 0.13, bank)) * mix(0.35, 1.0, heatz);
	heat = max(heat, rim * (0.75 + 0.25 * sin(TIME * 1.7 + world_pos.x * 0.8)));

	// fine grain on the crust plates so they read as rock, not flat paint
	float grain = 0.65 + 0.7 * vnoise(uv * 22.0 + q * 3.0);
	ALBEDO = mix(crust_color * grain * (1.0 - 0.35 * plate) * mix(0.8, 1.0, heatz), hot_color, heat * 0.65);

	// blackbody ramp: blood red -> orange -> amber, white-hot only down the cracks' middles
	vec3 ramp = mix(hot_color * vec3(0.55, 0.3, 0.4), hot_color, smoothstep(0.0, 0.45, heat));
	ramp = mix(ramp, core_color, smoothstep(0.45, 0.9, heat));
	ramp = mix(ramp, white_hot, core * smoothstep(0.75, 1.0, heat) * open * 0.7 * smoothstep(0.5, 0.95, heatz));
	float sheet = mix(0.08, 0.28, open) * mix(1.0, plate_dark, plate) * (0.75 + 0.5 * hot) + heat * 0.72;
	EMISSION = ramp * sheet * emission_energy * mix(0.2, 1.15, heatz);
	EMISSION += core_color * speck * heat * emission_energy * 0.8 * heatz;
	ROUGHNESS = mix(0.96, 0.32, heat);
	METALLIC = 0.0;

	// --- the open lava between the rafts: bright, swirling with the current, hotter veins and a darker skin that wrinkles and tears.
	// Worked out for every pixel (no branch: a derivative inside one is undefined, and on Metal it drew the lake black)
	float mw = (1.0 - raft) * smoothstep(0.0, 0.35, heatz);
	float flowv = fbm3(uv * 1.3 + q * 1.8 - drift * 1.3);
	float vn = abs(vnoise(uv * 5.0 + q * 3.0 - drift * 2.2 + vec2(4.1, 1.7)) - 0.5);
	float vein = 1.0 - smoothstep(0.0, 0.05 + fwidth(vn) * 1.5, vn);
	float skin = smoothstep(0.6, 0.9, vnoise(uv * 7.0 + q * 2.2 - drift * 3.0 + vec2(9.2, 3.3)));
	float edge_glow = 1.0 - smoothstep(0.0, 0.16 + aa, edge);              // the seam against a raft runs hottest
	vec3 mcol = mix(hot_color, core_color, smoothstep(0.32, 0.82, flowv + 0.25 * core_z));
	mcol = mix(mcol, white_hot, clamp(vein * 0.45 + edge_glow * 0.25, 0.0, 1.0) * (0.35 + 0.65 * core_z));
	float me = mix(0.75, 1.25, flowv) * (1.0 - skin * 0.6) * (1.0 + 0.55 * core_z) + vein * 0.7 + edge_glow * 0.35;
	EMISSION = mix(EMISSION, mcol * me * emission_energy * 0.42 * pulse, mw);
	ALBEDO = mix(ALBEDO, hot_color * 0.45, mw);
	ROUGHNESS = mix(ROUGHNESS, 0.38, mw);
	if (debug_view == 1) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(heatz, open, raft);
	}
}

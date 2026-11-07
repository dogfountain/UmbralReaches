// Shared star field for the night skies (vortex.gdshader, ember_skulls.gdshader).
// The old field hashed floor(EYEDIR.xy * k) + floor(EYEDIR.z * k) with a sin() hash: lattice cells that line up
// into dotted diagonals ("shooting stars") and, at half resolution, thin cross spikes that stair-stepped. Here
// every star sits in a cube-face cell with an integer hash, has a round soft body a few pixels wide, and the
// spikes are wide enough to be resolved at half resolution.

float sky_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Cube-face coordinates of a direction: uv in -1..1 and a face id, so a cell is the same size and shape
// whichever way you look (no streaks where the z cell steps).
vec3 sky_cell(vec3 d) {
	vec3 a = abs(d);
	if (a.x >= a.y && a.x >= a.z) {
		return vec3(d.y / a.x, d.z / a.x, d.x > 0.0 ? 0.0 : 1.0);
	} else if (a.y >= a.z) {
		return vec3(d.x / a.y, d.z / a.y, d.y > 0.0 ? 2.0 : 3.0);
	}
	return vec3(d.x / a.z, d.y / a.z, d.z > 0.0 ? 4.0 : 5.0);
}

// Soft round stars: `scale` cells per face unit, `prob` the share of cells holding one. Brightness 0..1.
float sky_stars(vec3 d, float scale, float prob) {
	vec3 c = sky_cell(d);
	vec2 g = c.xy * scale;
	vec2 id = floor(g);
	vec2 seed = id + c.z * 91.7;
	float on = step(1.0 - prob, sky_hash(seed));
	vec2 jit = vec2(sky_hash(seed + 7.3), sky_hash(seed + 19.1));
	float mag = mix(0.45, 1.0, sky_hash(seed + 3.7));
	float dist = length(fract(g) - (0.25 + 0.5 * jit));
	return on * mag * smoothstep(0.42, 0.04, dist);
}

// The big stars' four-point spikes: arms 1/160 long, 1/450 thick (a pixel at half resolution is about 1/600).
float sky_bursts(vec3 d, float scale) {
	vec3 c = sky_cell(d);
	vec2 base = floor(c.xy * scale);
	float burst = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = base + vec2(float(i), float(j));
			float key = step(0.9993, sky_hash(id + c.z * 91.7 + 0.5));
			vec2 dlt = c.xy - (id + 0.5) / scale;
			float spike = exp(-abs(dlt.x) * 160.0) * exp(-abs(dlt.y) * 450.0)
					+ exp(-abs(dlt.y) * 160.0) * exp(-abs(dlt.x) * 450.0);
			burst += key * spike;
		}
	}
	return burst;
}

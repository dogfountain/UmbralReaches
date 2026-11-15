// The vistas pass's sky (vortex.gdshader): far ranges on the horizon and the drain veils.
//
// Far ranges: two silhouettes painted round the horizon behind the Realm's own mountain ring (RealmRelief.horizon),
// so a view from a ridge has layers past the last mesh: the nearer range darker and sharper, the farther one paler,
// sunk in the haze band, each lighter at its foot where the haze pools. North, where the Crowns are real terrain and
// the vortex hangs, they sink away. They draw only where no mesh does: the sky is behind everything.
//
// The drain veils: thin curtains of cold light low in the southern sky (the vortex is north), their rays drawn
// up and slowly sliding toward the eye of the sky, as if the light were being pulled out of it. Kept well under the
// glow threshold (1.15): they never bloom, they only show.

float vs_hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float vs_noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(vs_hash1(i), vs_hash1(i + 1.0), f);
}
// a ridgeline: sharp crests, broad saddles (1 - |2n - 1| per octave)
float vs_ridge(float x, float seed) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		float n = vs_noise1(x + seed * 17.3);
		v += a * (1.0 - abs(2.0 * n - 1.0));
		x *= 2.13;
		a *= 0.48;
	}
	return v;
}

// col: the sky so far; d: the eye direction; haze: the band colour on that bearing; north_fade: 1 away from the vortex
vec3 vs_far_ranges(vec3 d, vec3 col, vec3 haze, vec3 deep, float north_fade) {
	if (d.y > 0.14 || north_fade <= 0.0) {
		return col;
	}
	float az = atan(d.x, d.z);
	// the farther range: low, long, pale
	float hb = -0.004 + 0.034 * vs_ridge(az * 2.6 + 4.0, 1.0) + 0.006 * vs_noise1(az * 40.0);
	// the nearer range: taller, broken into peaks
	float ha = -0.012 + 0.058 * pow(vs_ridge(az * 3.4 + 1.0, 2.0), 1.6) + 0.004 * vs_noise1(az * 90.0);
	hb *= north_fade;
	ha *= north_fade;
	float px = fwidth(d.y) * 1.2 + 0.0006;
	float in_b = smoothstep(hb + px, hb - px, d.y);
	float in_a = smoothstep(ha + px, ha - px, d.y);
	// each range lighter at its foot (the haze pools in the valleys between them), darker up to the crest
	vec3 far_c = mix(haze * 1.05, mix(col, deep, 0.35) * 0.9 + haze * 0.35, smoothstep(hb - 0.03, hb, d.y));
	vec3 near_c = mix(haze * 0.62, deep * 0.62 + haze * 0.16, smoothstep(ha - 0.05, ha, d.y));
	col = mix(col, far_c, in_b);
	col = mix(col, near_c, in_a);
	return col;
}

// the veils: added to the half-resolution pass (soft by nature). Each curtain is a sheet standing on a line that
// folds across the southern sky (z = vs_line(x), in units of the curtain's foot height). The eye ray's crossing with
// the sheet is solved for (a few fixed-point steps), so the rays stand vertical in the world and narrow into the
// distance, and the light is brighter where the sheet is seen edge-on (the bright folds of a real curtain).
float vs_line(float x, float k, float t) {
	return (3.1 + 1.9 * k) + 0.9 * sin(x * 0.29 + t * 0.017 + k * 2.3) + 0.42 * sin(x * 0.77 - t * 0.026 + k * 1.1)
		+ 0.14 * sin(x * 2.1 + t * 0.05 + k);
}

vec3 vs_curtain(vec3 d, float k, float t) {
	vec2 dh = d.xz;
	float hl = length(dh);
	if (hl < 1e-3 || dh.y < 0.02) {
		return vec3(0.0);
	}
	dh /= hl;
	float s = vs_line(0.0, k, t) / dh.y;
	for (int i = 0; i < 4; i++) {
		s = vs_line(s * dh.x, k, t) / dh.y;
	}
	float x = s * dh.x;
	float hgt = s * d.y / hl;                          // where the ray meets the sheet, in foot heights
	float above = hgt - 1.0;
	if (above < -0.08 || above > 2.2) {
		return vec3(0.0);
	}
	// sharp lower hem, a long fade upward
	float body = smoothstep(-0.08, 0.02, above) * exp(-max(above, 0.0) * 1.6);
	// the sheet seen edge-on glows brighter (a longer path through it)
	float slope = (vs_line(x + 0.01, k, t) - vs_line(x - 0.01, k, t)) / 0.02;
	vec2 n = normalize(vec2(-slope, 1.0));
	float edge = clamp(0.6 / max(abs(dot(dh, n)), 0.15), 0.6, 2.4);
	// folds gather the light; the rays slide along the line toward the eye of the sky
	float gather = 0.2 + 0.8 * smoothstep(0.2, 0.8, vs_noise1(x * 0.5 + k * 7.0 + t * 0.008));
	float ru = x * (11.0 + 6.0 * k) - t * (0.07 + 0.04 * k);
	float rays = vs_noise1(ru) * 0.6 + vs_noise1(ru * 2.9 + 3.0) * 0.4;
	rays = 0.35 + 0.65 * smoothstep(0.25, 0.9, rays);
	vec3 low = mix(vec3(0.14, 0.64, 0.52), vec3(0.2, 0.5, 0.68), k);
	vec3 c = mix(low, vec3(0.42, 0.25, 0.8), smoothstep(0.05, 0.9, above));
	// the farther curtain is fainter
	return c * body * edge * gather * rays * (1.0 - 0.35 * k) / (1.0 + s * 0.06);
}

vec3 vs_veils(vec3 d, vec3 vortex_dir, float t) {
	if (d.y < 0.02 || d.z < 0.05) {
		return vec3(0.0);
	}
	vec3 acc = vs_curtain(d, 0.0, t) + vs_curtain(d, 1.0, t);
	// low on the sky the veils thin into the haze; south-east to south-west (the vortex is north)
	return acc * smoothstep(0.02, 0.1, d.y) * smoothstep(0.05, 0.45, d.z) * 0.36;
}

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

// VERTEX is view-space inside fragment(), which would make the crust swim as the camera moves.
// Carry the world position across explicitly so the pattern stays welded to the world.
varying vec3 world_pos;

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
	for (int i = 0; i < 6; i++) {
		v += vnoise(p) * amp;
		p *= 2.07;
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * noise_scale;     // world-space, so the sheet never shows UV seams
	float t = TIME * flow_speed;

	// Domain warp: the crust drifts and shears instead of sliding as one rigid texture.
	vec2 q = vec2(fbm(uv + vec2(t, -t * 0.6)), fbm(uv + vec2(5.2, 1.3) - t * 0.4));
	float n = fbm(uv + warp * q);

	// Cells: ridged noise gives closed shapes, and the gaps between them read as cracks.
	float cell = abs(n - 0.5) * 2.0;
	float crack = 1.0 - smoothstep(0.0, crack_width, cell);
	float vein = 1.0 - smoothstep(0.0, crack_width * 1.8, abs(fbm(uv * 2.4 + q) - 0.5) * 2.0);
	float speck = step(0.92, hash(floor(uv * 48.0 + t * 3.0)));

	// A slow pulse so the cracks breathe rather than sitting static.
	float pulse = 0.82 + 0.18 * sin(TIME * 0.5 + n * 9.0);
	float heat = max(crack, vein * 0.45) * pulse;

	ALBEDO = mix(crust_color, hot_color, heat * 0.65);
	float sheet = 0.28 + heat * 0.72;
	EMISSION = mix(hot_color * 0.45, core_color, smoothstep(0.4, 1.0, heat)) * sheet * emission_energy;
	EMISSION += core_color * speck * heat * emission_energy * 0.8;
	ROUGHNESS = mix(0.96, 0.32, heat);
	METALLIC = 0.0;
}

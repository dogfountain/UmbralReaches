shader_type spatial;
// The Hollow One's shroud and trailing rags. Near-black cloth that flutters harder toward the
// hem (UV.y 0 = crown, 1 = hem / rag tip), a ragged hem that burns away with ember edges, a
// violet fresnel rim so the silhouette reads against the night, and a per-instance dissolve.
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 cloth : source_color = vec3(0.016, 0.01, 0.03);
uniform vec3 rim_col = vec3(0.32, 0.14, 0.85);
uniform vec3 ember = vec3(3.2, 0.9, 0.25);
uniform float flutter = 1.0;
uniform float rag_start = 0.72;
uniform float holes = 0.12;
instance uniform float dissolve = 0.0;

varying float drop;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	drop = clamp(UV.y, 0.0, 1.0);
	float t = TIME * 1.25;
	float k = drop * drop * flutter;
	VERTEX.x += sin(VERTEX.y * 1.6 + t * 2.1 + UV.x * 37.0) * 0.2 * k;
	VERTEX.z += cos(VERTEX.y * 1.2 + t * 1.7 + UV.x * 23.0) * 0.2 * k;
	VERTEX.y += sin(t * 1.3 + UV.x * 18.85) * 0.12 * k;
}

void fragment() {
	vec2 q = vec2(UV.x * 26.0, UV.y * 7.0 - TIME * 0.15);
	float n = vnoise(q) * 0.65 + vnoise(q * 2.7) * 0.35;
	// tattered hem + moth holes, eaten further by dissolve
	float eat = smoothstep(rag_start, 1.0, drop) * 0.95 + holes * smoothstep(0.35, 1.0, drop) + dissolve * 1.1;
	float edge = n - eat;
	if (edge < 0.0) {
		discard;
	}
	float burn = 1.0 - smoothstep(0.0, 0.06, edge);
	ALBEDO = cloth;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = rim_col * fres * (0.35 + 0.4 * (1.0 - drop)) + ember * burn * step(0.001, eat);
}

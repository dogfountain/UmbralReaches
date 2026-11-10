shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Where the Upward Falls comes down: rain rings widening on the river below the weir, and a skin of foam and
// mist along the weir's foot. Laid over the river's own surface (the plane is clipped by the banks).

uniform vec2 centre = vec2(0.0);              // the middle of the rain, world xz
uniform float wall_z = 0.0;                   // the weir's south face
uniform float reach = 9.0;
uniform vec3 pale : source_color = vec3(0.72, 0.9, 1.0);

varying vec3 wp;

float hs(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ns(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1.0, 0.0)), f.x), mix(hs(i + vec2(0.0, 1.0)), hs(i + vec2(1.0, 1.0)), f.x), f.y);
}

float rain_rings(vec2 p, float scale, float rate, float off) {
	vec2 g = p * scale + off;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float ph = fract(TIME * rate + hs(id));
	vec2 o = (vec2(hs(id + 3.1), hs(id + 7.7)) - 0.5) * 0.5;
	float d = length(f - o);
	float r = ph * 0.62;
	return smoothstep(mix(0.035, 0.012, ph), 0.0, abs(d - r)) * (1.0 - ph) * (1.0 - ph) * step(0.35, hs(id + 11.0));   // fine lines that thin and fade as they spread
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float d = length(p - centre);
	float mask = 1.0 - smoothstep(reach * 0.55, reach, d);
	float rings = rain_rings(p, 1.15, 0.55, 0.0) + rain_rings(p, 1.9, 0.8, 4.3) * 0.7;
	// foam and mist along the weir's foot, torn by the fall
	float dw = abs(p.y - wall_z);
	float foot = 1.0 - smoothstep(0.0, 5.5, dw);
	float fn = ns(vec2(p.x * 1.3 + TIME * 0.3, p.y * 1.7 - TIME * 0.9));
	float fn2 = ns(vec2(p.x * 3.1 - TIME * 0.5, p.y * 3.3 + TIME * 0.7));
	float foam = smoothstep(0.38, 0.85, fn * 0.65 + fn2 * 0.45) * foot;
	float a = rings * mask * 0.32 + foam * 0.85 * (0.4 + 0.6 * mask);
	ALBEDO = mix(pale * 0.55, vec3(1.0), foam);   // the rings are a faint catch of the column's light, the foam stays white
	ALPHA = clamp(a, 0.0, 0.9);
}

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Circular area-of-effect disc on a flat quad. Everything is clipped to r <= 1, so the quad's
// corners never show: the AoE reads as a true circle of the skill's radius.
//   style 0  Umbral Nova: violet front, radial rift cracks behind it, the radius edge held lit
//   style 1  Ember Lance: fire front, licking flame field, ember speckle, cooling to embers
// progress 0→1 over the effect's life (per instance), so one material serves every cast.

uniform vec3 color : source_color = vec3(1.3, 0.55, 3.0);
uniform vec3 hot : source_color = vec3(2.6, 2.0, 3.4);
uniform int style = 0;
uniform float front_time = 0.4;        // fraction of life the front takes to reach the edge
instance uniform float progress = 0.0;

float h1(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return n2(p) * 0.55 + n2(p * 2.07 + 3.1) * 0.3 + n2(p * 4.3 + 7.7) * 0.15; }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	float t = progress;
	float front = 1.0 - pow(1.0 - clamp(t / front_time, 0.0, 1.0), 3.0);
	float fade = 1.0 - smoothstep(front_time, 1.0, t);
	float behind = step(r, front);
	float front_band = smoothstep(front - 0.06, front, r) * (1.0 - smoothstep(front, front + 0.02, r)) * (1.0 - smoothstep(0.85, 1.0, t / front_time));
	float edge = smoothstep(0.955, 0.985, r) * (1.0 - smoothstep(0.985, 1.0, r));     // the radius line
	vec3 c = vec3(0.0);
	float m = 0.0;
	if (style == 0) {
		// radial cracks: jittered spokes that wander with radius, branching near the rim
		float cells = 28.0;
		float wander = (fbm(vec2(a * 3.0, r * 5.0)) - 0.5) * 0.9;
		float u = fract(a / TAU * cells + wander);
		float k = h1(floor(a / TAU * cells + wander));
		float crack = 1.0 - smoothstep(0.0, 0.035 + 0.03 * r, abs(u - 0.5));
		crack *= step(0.25, k) * smoothstep(0.08, 0.3, r);
		float swirl = fbm(vec2(a * 2.0 + r * 6.0 - t * 4.0, r * 3.0)) * (1.0 - r) * 0.5;
		m = (crack * 1.3 + swirl * 0.6) * behind * fade + front_band * 1.3 + edge * (0.6 + 0.6 * fade) * (1.0 - smoothstep(0.7, 1.0, t));
		c = mix(color, hot, front_band + crack * 0.3) * m;
	} else {
		// fire field: licking flames inside the front, speckled embers as it cools
		float fl = fbm(p * 4.0 + vec2(0.0, -t * 6.0)) * fbm(p * 7.0 - vec2(t * 3.0, 0.0));
		float flames = smoothstep(0.18, 0.45, fl) * behind * (1.0 - smoothstep(0.0, 0.7, t)) * (0.4 + 0.6 * r);
		float embers = step(0.9, h2(floor(p * 38.0))) * behind * fade * (0.5 + 0.5 * sin(TIME * 12.0 + h2(floor(p * 38.0)) * 30.0));
		m = flames * 1.5 + embers * 0.8 + front_band * 2.4 + edge * 0.5 * fade;
		c = mix(color, hot, clamp(front_band + flames * 0.4, 0.0, 1.0)) * m;
	}
	ALBEDO = c;
	ALPHA = clamp(m, 0.0, 1.0);
}

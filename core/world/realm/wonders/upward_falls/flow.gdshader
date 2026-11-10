shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// The Upward Falls' river on its way up: the strip over the glacis and the roof (UV.x across, UV.y metres along,
// the water running toward larger UV.y), and the basin (disc = 1: UV is the disc, the water turning in it).

uniform float disc = 0.0;
uniform float speed = 3.6;
uniform float period = 0.0;
uniform float lip_end = 1000.0;                // the strip's length where the steps end (no lip foam on the crest)                 // the length of one step along the strip (0: none)
uniform vec3 deep : source_color = vec3(0.07, 0.22, 0.36);
uniform vec3 pale : source_color = vec3(0.62, 0.84, 0.98);

float hs(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ns(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1.0, 0.0)), f.x), mix(hs(i + vec2(0.0, 1.0)), hs(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 col;
	float a;
	if (disc > 0.5) {
		vec2 c = (UV - 0.5) * 2.0;
		float r = length(c);
		float ang = atan(c.y, c.x);
		float sw = ang * 1.0 + r * 5.0 - TIME * 1.4;
		float tur = ns(vec2(cos(sw) * 3.0 + r * 4.0, sin(sw) * 3.0 - TIME * 0.8));
		float rings = 0.5 + 0.5 * sin(r * 22.0 - TIME * 5.5 + tur * 4.0);
		float foam = smoothstep(0.55, 0.95, tur * 0.7 + rings * 0.4) * (1.0 - smoothstep(0.0, 0.9, r) * 0.4);
		col = mix(deep, pale, tur * 0.6 + foam * 0.5);
		a = (1.0 - smoothstep(0.86, 1.0, r)) * (0.82 + 0.15 * rings);
		col += vec3(0.5, 0.6, 0.6) * (1.0 - smoothstep(0.0, 0.5, r)) * 0.5;      // it lifts at the middle
	} else {
		float u = UV.x;
		float s = UV.y;
		float side = abs(u - 0.5) * 2.0;
		float flow = s - TIME * speed;
		// thin glassy sheeting: long fine streaks along the run, mostly clear so the tread shows through
		float st1 = ns(vec2(u * 34.0, flow * 0.2));
		float st2 = ns(vec2(u * 71.0 + 3.0, flow * 0.38));
		float streak = smoothstep(0.5, 0.95, st1 * 0.6 + st2 * 0.5);
		float ripple = ns(vec2(u * 12.0, flow * 0.9));
		float lipb = 0.0;
		if (period > 0.0 && s < lip_end) {
			float ph = fract((s - 0.4) / period);
			lipb = smoothstep(0.8, 0.97, ph) * (0.35 + 0.65 * ns(vec2(u * 20.0, s * 4.0 - TIME * 3.5)));
		}
		float footz = 1.0 - smoothstep(0.0, 2.6, s);
		float churn = ns(vec2(u * 14.0, s * 3.0 - TIME * 2.5)) * footz;
		col = mix(deep, pale * 0.55, streak * 0.55 + ripple * 0.15);
		col = mix(col, vec3(0.92, 0.98, 1.0), clamp(lipb * 0.8 + churn * 0.6, 0.0, 1.0));
		a = 0.14 + 0.2 * streak + 0.1 * ripple + lipb * 0.55 + churn * 0.4;
		a *= smoothstep(1.0, 0.62, side) * smoothstep(0.0, 0.8, s);
	}
	ALBEDO = col * 0.75;
	ALPHA = clamp(a, 0.0, 0.95);
}

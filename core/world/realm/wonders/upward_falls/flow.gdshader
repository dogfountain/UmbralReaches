shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// The Upward Falls' river on its way up: the strip over the glacis and the roof (UV.x across, UV.y metres along,
// the water running toward larger UV.y), and the basin (disc = 1: UV is the disc, the water turning in it).

uniform float disc = 0.0;
uniform float speed = 3.6;
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
		float st1 = ns(vec2(u * 8.0, flow * 0.5));
		float st2 = ns(vec2(u * 21.0, flow * 0.95));
		float streak = smoothstep(0.35, 0.9, st1 * 0.55 + st2 * 0.55);
		// V-shaped ripples pointing up the slope
		float chev = 0.5 + 0.5 * sin((flow + side * 2.4) * 2.3);
		float band = smoothstep(0.86, 1.0, chev);
		float rim = smoothstep(0.7, 1.0, side);
		float footz = 1.0 - smoothstep(0.0, 3.4, s);
		float churn = ns(vec2(u * 7.0, s * 2.2 - TIME * 2.5)) * footz;
		col = mix(deep, pale, streak * 0.75 + band * 0.35);
		col = mix(col, vec3(0.93, 0.98, 1.0), clamp(rim * 0.5 + churn * 0.9, 0.0, 1.0));
		a = 0.72 + 0.2 * streak + 0.12 * rim;
		a *= smoothstep(0.0, 0.5, s) * (1.0 - smoothstep(0.93, 1.0, side) * 0.7);
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.95);
}

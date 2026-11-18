// the body of oss_glow.gdshader and oss_glow_one.gdshader (the one-sided pane: glass drawn only from outside)

uniform vec3 glass : source_color = vec3(1.0, 0.58, 0.28);
uniform float energy = 1.1;
uniform float quarry = 7.0;          // diamonds per metre along each diagonal

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wn);
	float hot;
	if (n.y > 0.7) {
		vec2 c = wp.xz * 9.0;
		float w = max(fwidth(c.x), fwidth(c.y));
		float h = hash(floor(c));
		hot = mix(mix(0.3, 1.2, h * h), 0.75, smoothstep(0.4, 1.0, w));
	} else {
		vec2 q = n.x > n.z ? wp.zy : wp.xy;
		vec2 d = vec2(q.x + q.y, q.x - q.y) * quarry;
		vec2 f = abs(fract(d) - 0.5);
		float w = max(fwidth(d.x), fwidth(d.y));
		float lead = smoothstep(0.43 - w, 0.43 + w, max(f.x, f.y));
		lead *= 1.0 - smoothstep(0.2, 0.5, w);
		float pane = 0.8 + 0.35 * hash(floor(d)) * (1.0 - smoothstep(0.2, 0.5, w));
		hot = mix(pane, 0.06, lead);
	}
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	hot *= mix(0.45, 1.0, facing);
	ALBEDO = glass * COLOR.rgb * hot * energy;
}

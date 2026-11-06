extends RefCounted
## The world map's shaders (ui/world_map.gd): the parchment, the terrain wash with its shores and pit, the
## fog of war over the ink, and the desk. Each is spliced with the shared noise ahead of fragment().

## value noise, fbm and an alpha-over, shared by the shaders (spliced in ahead of fragment())
const NOISE := """
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5; float s = 0.0; for (int k = 0; k < 5; k++) { s += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; } return s; }
vec4 over(vec4 d, vec4 s) {
	float a = s.a + d.a * (1.0 - s.a);
	vec3 c = a > 0.0001 ? (s.rgb * s.a + d.rgb * d.a * (1.0 - s.a)) / a : vec3(0.0);
	return vec4(c, a);
}
"""

const PAPER_SHADER := """
shader_type canvas_item;
uniform vec2 res;
void fragment() {
	vec2 px = UV * res;
	float n1 = fbm(px / 300.0);
	float n2 = fbm(px / 46.0 + 7.0);
	float fib = vnoise(vec2(px.x / 70.0, px.y / 2.2)) * 0.6 + vnoise(vec2(px.x / 2.4, px.y / 80.0)) * 0.4;
	float grain = h21(floor(px * 0.7));
	vec3 c = mix(vec3(0.86, 0.77, 0.59), vec3(0.70, 0.575, 0.38), smoothstep(0.30, 0.78, n1) * 0.7);
	c *= 0.93 + 0.14 * n2;
	c *= 0.965 + 0.05 * fib + 0.025 * grain;
	float ring = 1.0 - smoothstep(0.0, 0.014, abs(fbm(px / 170.0 + 3.0) - 0.57));
	c = mix(c, c * vec3(0.78, 0.68, 0.52), ring * 0.45);
	float blot = smoothstep(0.62, 0.80, fbm(px / 90.0 + 11.0));
	c = mix(c, vec3(0.50, 0.36, 0.2), blot * 0.22);
	vec2 e = min(px, res - px);
	float d = min(e.x, e.y);
	float wob = fbm(px / 26.0) * 30.0 + fbm(px / 7.0) * 6.0;
	float inner = d - (6.0 + wob * 0.6);
	float burn = 1.0 - smoothstep(0.0, 70.0, d - wob * 0.8);
	c = mix(c, vec3(0.36, 0.22, 0.10), burn * 0.55);
	c *= mix(0.9, 1.0, smoothstep(0.0, 160.0, d));
	COLOR = vec4(c, smoothstep(0.0, 2.0, inner));
}
"""

const TERRAIN_SHADER := """
shader_type canvas_item;
uniform sampler2D wash_tex : filter_linear, repeat_disable;
uniform sampler2D feat_tex : filter_linear, repeat_disable;
uniform vec2 res;
uniform vec4 bounds;
void fragment() {
	vec2 px = UV * res;
	float inb = step(bounds.x, UV.x) * step(UV.x, bounds.z) * step(bounds.y, UV.y) * step(UV.y, bounds.w);
	float n = fbm(px / 8.0);
	float n2 = fbm(px / 60.0 + 4.0);
	vec4 w = texture(wash_tex, UV);
	vec4 col = vec4(w.rgb, w.a * (0.55 + 0.9 * n2) * inb);
	vec2 f = texture(feat_tex, UV).rg;
	float wj = f.r + (n - 0.5) * 0.14;
	float fw = max(fwidth(wj), 0.0004);
	float inw = smoothstep(0.5 - fw, 0.5 + fw, wj);
	col = over(col, vec4(0.46, 0.62, 0.66, 0.78 * inw));
	float shore = 1.0 - smoothstep(0.7, 1.7, abs(wj - 0.5) / fw);
	float inner = (1.0 - smoothstep(0.5, 1.4, abs(wj - 0.8) / fw)) * step(0.42, n2 + n * 0.3);
	float rip = step(0.86, fract(px.y / 11.0 + n * 3.0)) * step(0.52, fbm(px / 16.0 + 2.0)) * smoothstep(0.7, 0.92, wj);
	col = over(col, vec4(0.19, 0.12, 0.075, max(shore * 0.9, max(inner * 0.35, rip * 0.4))));
	float gj = f.g + (n - 0.5) * 0.2;
	float fg = max(fwidth(gj), 0.0004);
	float inc = smoothstep(0.5 - fg, 0.5 + fg, gj);
	float hatch = step(0.62, fract((px.x + px.y) / 5.5 + n));
	col = over(col, vec4(0.30, 0.20, 0.14, 0.5 * inc));
	float pit = 1.0 - smoothstep(0.7, 1.7, abs(gj - 0.5) / fg);
	col = over(col, vec4(0.19, 0.12, 0.075, max(pit * 0.95, hatch * inc * 0.75)));
	COLOR = col;
}
"""

const FOG_SHADER := """
shader_type canvas_item;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 res;
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float m = texture(fog_tex, UV).r;
	vec2 px = UV * res;
	float n = fbm(px / 14.0);
	float x = m + (n - 0.5) * 0.4;
	float k = smoothstep(0.34, 0.6, x);
	vec4 col = vec4(ink.rgb, ink.a * k);
	float mist = (1.0 - k) * 0.24 * (0.55 + 0.9 * fbm(px / 90.0 + 5.0));
	col = over(vec4(0.52, 0.40, 0.26, mist), col);
	float fwx = max(fwidth(x), 0.0004);
	float edge = (1.0 - smoothstep(0.8, 2.0, abs(x - 0.47) / fwx)) * step(0.45, fbm(px / 20.0 + 9.0)) * step(0.01, 1.0 - m);
	col = over(col, vec4(0.30, 0.20, 0.11, edge * 0.42));
	COLOR = col;
}
"""

const DESK_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float v = 1.0 - 0.55 * dot(p, p) * 0.5;
	COLOR = vec4(vec3(0.075, 0.052, 0.042) * v, 1.0);
}
"""


static func make(body: String) -> Shader:
	var s := Shader.new()
	var at := body.find("void fragment()")
	s.code = body.substr(0, at) + NOISE + body.substr(at)
	return s

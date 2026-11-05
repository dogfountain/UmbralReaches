shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The spitter's throat sac (r30): glow through a membrane, not an unshaded sticker. Lit skin over a
// light inside: the thin rim glows, the thick middle stays darker, dark veins web across it, and it
// breathes. spitter.gd swells the node on the windup; `swell` (0..1, set with it) thins the skin.

uniform vec3 skin : source_color = vec3(0.42, 0.5, 0.44);
uniform vec3 glow : source_color = vec3(0.2, 1.0, 0.72);
uniform float energy = 2.2;
instance uniform float swell = 0.0;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float cell(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	float d = 1.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = o + vec3(hash(i + o), hash(i + o + 7.1), hash(i + o + 3.7)) - f;
		d = min(d, dot(r, r));
	}
	return sqrt(d);
}

varying vec3 opos;
void vertex() { opos = VERTEX; }

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float c1 = cell(opos * 26.0);
	float c2 = cell(opos * 26.0 + 0.37);
	float vein = 1.0 - smoothstep(0.02, 0.09, abs(c1 - c2));
	float thin = mix(0.3, 1.0, pow(1.0 - ndv, 1.4)) + swell * 0.6;
	float beat = 0.8 + 0.2 * sin(TIME * 3.0 + opos.y * 8.0);
	ALBEDO = mix(skin, skin * 0.25, vein);
	ROUGHNESS = 0.32;
	SPECULAR = 0.5;
	EMISSION = glow * energy * thin * beat * (1.0 - vein * 0.85);
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Boss eruption spikes (BossKit.spikes, r30): CreatureMesh vertex colour as albedo, its bone channel
// (COLOR.a: 0 = bone) a little glossier, its glow channel (UV2.x) lit in the boss's accent -- the
// tips of the shards and brambles burn, the dirty base does not.
uniform vec3 accent : source_color = vec3(1.0, 0.6, 0.2);
uniform float energy = 2.5;
uniform float rough = 0.7;

float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
varying vec3 opos;
void vertex() { opos = VERTEX; }

void fragment() {
	float grain = h(floor(opos * 90.0)) * 0.15 + 0.85;
	ALBEDO = COLOR.rgb * grain;
	ROUGHNESS = mix(rough - 0.2, rough, COLOR.a);
	SPECULAR = 0.35;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = accent * energy * UV2.x * (0.6 + 0.4 * pow(1.0 - ndv, 2.0));
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// The wanderer's hard gear in ONE skinned surface (wanderer_body.gd): leather, stitched straps,
// iron, wood, wool wraps, the carved staff and the lantern's horn glass. Textures are the layers of
// one Texture2DArray (WandererTex.GEAR_LAYERS; albedo alpha = roughness, < 0.1 = a carved rune).
//   CUSTOM0 = tint rgb, metallic     CUSTOM1 = layer, glass glow, rune glow     COLOR = occlusion

uniform sampler2DArray albedo_arr : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_arr : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 rune_color : source_color = vec3(1.0, 0.58, 0.24);   // amber, like the embroidery
uniform float rune_energy = 1.0;
uniform vec3 glass_color : source_color = vec3(1.0, 0.6, 0.26);
uniform float glass_energy = 1.15;

instance uniform float lantern_glow : instance_index(8) = 1.0;   // the lantern's flicker
instance uniform float rune_boost : instance_index(9) = 0.0;     // casting wakes the staff's runes

// The wanderer's violet rim key (it used to be an OmniLight3D on the rig, see CharacterRig
// _add_rim_light): the same light worked out here, on the wanderer only, so it costs no clustered
// light over the ground round him. Rig-space position, colour x energy, range.
uniform vec3 rim_key_pos = vec3(0.5, 2.1, 1.4);
uniform vec3 rim_key_color = vec3(0.92, 0.8, 0.86);
uniform float rim_key_range = 3.0;

vec3 rim_key(vec3 albedo, vec3 n_view, vec3 p_view, mat4 view_m, mat4 model_m) {
	vec3 lp = (view_m * model_m * vec4(rim_key_pos, 1.0)).xyz;
	vec3 l = lp - p_view;
	float d = length(l);
	float a = clamp(1.0 - pow(d / rim_key_range, 4.0), 0.0, 1.0);
	a = a * a * pow(max(d, 0.05), -1.1);               // Godot omni falloff, attenuation 1.1
	return albedo * rim_key_color * max(dot(n_view, l / max(d, 1e-4)), 0.0) * a;
}

varying vec4 g0;
varying vec4 g1;
varying vec3 opos;

void vertex() {
	g0 = CUSTOM0;
	g1 = CUSTOM1;
	opos = VERTEX;
}

void fragment() {
	vec3 uvw = vec3(UV, g1.x);
	vec4 a = texture(albedo_arr, uvw);
	float rune = smoothstep(0.12, 0.05, a.a) * g1.z;
	ALBEDO = a.rgb * g0.rgb * COLOR.rgb;
	METALLIC = g0.a;
	ROUGHNESS = mix(clamp(a.a, 0.25, 1.0), 0.5, rune);
	SPECULAR = 0.45;
	NORMAL_MAP = texture(normal_arr, uvw).rgb;
	NORMAL_MAP_DEPTH = 1.15;
	RIM = 0.25;
	RIM_TINT = 0.7;
	float creep = 0.6 + 0.4 * sin(TIME * 1.2 - opos.y * 9.0);     // a slow pulse climbing the shaft
	EMISSION = rim_key(ALBEDO, NORMAL, VERTEX, VIEW_MATRIX, MODEL_MATRIX) * (1.0 - METALLIC * 0.6)
		+ glass_color * g1.y * glass_energy * lantern_glow
		+ rune_color * rune * rune_energy * creep * (1.0 + rune_boost * 2.5);
}

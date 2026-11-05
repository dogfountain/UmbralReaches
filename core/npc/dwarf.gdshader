shader_type spatial;
// The tavern dwarves (core/npc/dwarf_rig.gd, built by dwarf_mesh.gd).
//   COLOR.rgb  the part's tint, authored in sRGB (converted here, so a "deep red" stays deep)
//   COLOR.a    baked ambient occlusion (crevices, under the beard, between arm and flank)
//   UV         metres around / along the part; UV2.x = material layer (0..9, see DwarfMesh.MAT_*)
// Detail maps are a Texture2DArray per channel (dwarf_look.gd: generated with Image +
// FastNoiseLite): albedo variation (rgb about 0.5 = neutral, a = roughness variation) and a normal
// map, one layer per material. AO darkens only ambient light (that is how Godot applies AO), which
// keeps the cool sky ambient from washing the warm cloth and skin out under the azure grade.
render_mode diffuse_burley, specular_schlick_ggx;
// r35: the shared character finish (detail maps already break the surface up: a small share)
#define CL_CAVITY 0.25
#define CL_BREAKUP 0.05
#define CL_WEAR 0.6
#include "res://core/vfx/char_look.gdshaderinc"

uniform sampler2DArray detail_albedo : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ambient_floor = 0.42;      // AO never drops ambient below this
uniform float ambient_keep = 0.9;        // overall ambient share (the room's warm lights do the rest)
uniform float detail_mix = 1.0;
uniform float skin_relief = 0.0005;      // models pass: wrinkle / pore depth (metres)
uniform float hair_relief = 0.0012;      // models pass: strand ridges (metres)
uniform float cloth_relief = 0.012;      // models pass: fold depth (metres)
// the room's warm bounce (hearth, candles) on the dwarves: without it their cloth falls under the
// grade's brightness floor for warm hues and is pulled into the azure band (they read blue-grey)
uniform vec3 warm_bounce = vec3(1.0, 0.56, 0.3);
uniform float bounce = 0.12;
// colour strength of the albedo: candlelight and the grade's x1.42 saturation both push warm cloth
// and skin toward neon; a little less chroma here keeps them reading as dyed wool and skin
uniform float chroma = 0.88;
// skin under strong warm light: a red-shifted lit skin falls below the grade's warm band (8-16 deg)
// and is pulled to magenta; less skin chroma and an orange (not red) translucency keep it skin
uniform float skin_chroma = 1.0;
uniform vec3 skin_back = vec3(0.2, 0.11, 0.07);       // r35: was (0.32, 0.15, 0.07): faces flattened to one orange
// skin's own share of the warm bounce: keeps dim skin bright and saturated enough to stay in the
// grade's protected warm band instead of drifting to magenta between moon-blue and fire-orange
uniform float skin_bounce = 0.05;    // r35: skin's own warm self-glow (was the cloth's 0.12): the hearth already lights it

varying vec3 opos;
varying flat int mat_id;
varying flat vec4 mat_p;       // tile u, tile v, roughness, normal depth (per material layer)
varying flat float mat_spec;

// Per-layer constants, looked up once per vertex. Global const arrays leaked their shader at quit
// (Godot keeps the arrays' names: "2 RID allocations of type DummyShader were leaked at exit").
//            skin  cloth linen leath hair  metal wood  foam  eye   fur
// tile u     9     24    30    9     18    10    5     16    1     14
// tile v     9     24    30    9     5     10    2     16    1     6
// rough      .62   .93   .86   .58   .7    .36   .72   .8    .08   .9
// ndepth     .55   .7    .6    1     1     .6    .8    .9    0     1.2
// spec       .45   .25   .3    .45   .28   .5    .35   .4    .9    .25
void layer_params(int m, out vec4 p, out float spec) {
	if (m == 0) { p = vec4(9.0, 9.0, 0.62, 0.55); spec = 0.45; }
	else if (m == 1) { p = vec4(24.0, 24.0, 0.93, 0.7); spec = 0.25; }
	else if (m == 2) { p = vec4(30.0, 30.0, 0.86, 0.6); spec = 0.3; }
	else if (m == 3) { p = vec4(9.0, 9.0, 0.58, 1.0); spec = 0.45; }
	else if (m == 4) { p = vec4(10.0, 3.0, 0.64, 0.45); spec = 0.3; }   // r35 hair: coarser, shallower detail (it crawled at 960p)
	else if (m == 5) { p = vec4(10.0, 10.0, 0.36, 0.6); spec = 0.5; }
	else if (m == 6) { p = vec4(5.0, 2.0, 0.72, 0.8); spec = 0.35; }
	else if (m == 7) { p = vec4(16.0, 16.0, 0.8, 0.9); spec = 0.4; }
	else if (m == 8) { p = vec4(1.0, 1.0, 0.08, 0.0); spec = 0.9; }
	else { p = vec4(14.0, 6.0, 0.9, 1.2); spec = 0.25; }
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	opos = VERTEX;
	mat_id = clamp(int(UV2.x + 0.5), 0, 9);
	vec4 p;
	float sp;
	layer_params(mat_id, p, sp);
	mat_p = p;
	mat_spec = sp;
}

void fragment() {
	int m = clamp(mat_id, 0, 9);
	vec3 uvw = vec3(UV.x * mat_p.x, UV.y * mat_p.y, float(m));
	vec4 d = texture(detail_albedo, uvw);
	vec3 base = to_linear(COLOR.rgb);
	if (m != 8 && m != 5) {
		base = mix(vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))), base, chroma * (m == 0 ? skin_chroma : 1.0));
	}
	// r36: worn edges, matte creases (not the eyes: their curvature is all edge)
	vec2 wear = m == 8 ? vec2(0.0) : cl_wear_mask(NORMAL, VERTEX, COLOR.a);
	// models pass: skin that is not one tone, wrinkles and pores; cloth that hangs in folds; leather
	// that has creased (char_look: object-space, faded by footprint, no tangents)
	if (m == 0) {
		base = cl_skin_albedo(base, opos, 0.0);
		NORMAL = cl_bump(NORMAL, VERTEX, cl_skin_height(opos, 1.0), skin_relief);
	} else if (m == 1 || m == 2 || m == 9) {
		NORMAL = cl_bump(NORMAL, VERTEX, cl_cloth_height(opos), cloth_relief);
	} else if (m == 3) {
		NORMAL = cl_bump(NORMAL, VERTEX, cl_skin_height(opos, 0.6), skin_relief * 1.6);
	} else if (m == 4 || m == 9) {
		// hair and fur: strands run along v (UV.y, metres along the lock); each strand its own shade,
		// the roots darker, a fine ridge per strand for the light to catch (faded by footprint)
		vec3 sp = vec3(UV.x * 520.0, UV.y * 9.0, 0.0);
		float strand = cl_noise(sp);
		float f = cl_fade(sp);
		base *= mix(1.0, 0.72 + 0.5 * strand, f) * mix(0.82, 1.0, smoothstep(0.0, 0.06, UV.y));
		NORMAL = cl_bump(NORMAL, VERTEX, (strand - 0.5) * f, hair_relief);
	}
	ALBEDO = cl_wear_albedo(cl_albedo(base * mix(vec3(1.0), d.rgb * 2.0, detail_mix), m == 8 ? 1.0 : COLOR.a, opos), wear);
	NORMAL_MAP = texture(detail_normal, uvw).rgb;
	NORMAL_MAP_DEPTH = mat_p.w;
	ROUGHNESS = cl_wear_rough(clamp(mat_p.z + (d.a - 0.5) * 0.5, 0.04, 1.0), wear);
	if (m == 0) {
		ROUGHNESS = cl_skin_rough(ROUGHNESS, opos);
	}
	METALLIC = m == 5 ? 0.82 : 0.0;
	SPECULAR = cl_wear_spec(mat_spec, wear);
	float ao = COLOR.a;
	AO = mix(ambient_floor, 1.0, ao) * ambient_keep;
	AO_LIGHT_AFFECT = 0.35 * (1.0 - ao);
	float bn = (m == 0 && skin_bounce >= 0.0) ? skin_bounce : bounce;
	EMISSION = ALBEDO * warm_bounce * bn * mix(0.35, 1.0, ao) + cl_rim(NORMAL, VIEW, VIEW_MATRIX);
	if (m == 0) {
		// skin: a little warm light through thin parts (nose, ears), cheap wrap
		BACKLIGHT = skin_back * ao;
	}
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
// Enemy skin for CreatureMesh bodies. Pale corpse-flesh with dark veins that flow along limbs,
// wet sheen in the folds, bone that reads as bone, glowing eyes/glands, a violet rim so bodies
// separate from the blue night, and three per-instance channels driven by Enemy.gd:
//   hit_flash  white-hot pop on damage     glint  eyes flare on a strike windup
//   dissolve   0..1 death burn-away (alpha scissor, so the depth prepass is kept)

uniform vec3 skin : source_color = vec3(0.62, 0.58, 0.6);
uniform vec3 skin_deep : source_color = vec3(0.24, 0.16, 0.22);   // folds, cavities
uniform vec3 vein : source_color = vec3(0.16, 0.05, 0.12);
uniform vec3 bone_col : source_color = vec3(0.82, 0.78, 0.66);
uniform vec3 rag_col : source_color = vec3(0.1, 0.08, 0.09);
uniform vec3 eye_col : source_color = vec3(1.0, 0.36, 0.12);
uniform float eye_energy = 5.0;
uniform vec3 rim_col : source_color = vec3(0.45, 0.32, 0.9);
uniform float rim_amount = 0.55;
uniform float vein_amount = 0.6;
uniform float vein_scale = 7.0;
uniform vec3 burn_col : source_color = vec3(1.2, 0.45, 2.2);

instance uniform float hit_flash = 0.0;
instance uniform float glint = 0.0;
instance uniform float dissolve = 0.0;

varying vec3 opos;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	opos = VERTEX;
}

void fragment() {
	float flesh = COLOR.a;
	float rag = UV2.y;
	// veins: ridged noise stretched along the tube (UV.y = metres along)
	float n = vnoise(vec3(UV.x * 6.0, UV.y * vein_scale, 0.0) + opos * 3.0);
	float ridge = 1.0 - abs(n * 2.0 - 1.0);
	float veins = smoothstep(0.86, 0.98, ridge) * vein_amount * flesh * (1.0 - rag);
	float mottle = vnoise(opos * 11.0);
	vec3 base = mix(skin_deep, skin, smoothstep(0.15, 0.85, mottle * 0.6 + 0.4)) * COLOR.rgb;
	base = mix(base, vein, veins);
	vec3 albedo = mix(bone_col * COLOR.rgb, base, flesh);
	albedo = mix(albedo, rag_col * COLOR.rgb, rag);

	ALBEDO = albedo;
	ROUGHNESS = mix(0.32, mix(0.48, 0.95, rag), flesh) - veins * 0.15;
	SPECULAR = mix(0.55, 0.42, flesh) * (1.0 - rag);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 3.0) * rim_amount * (1.0 - rag * 0.6);

	// death: burn away from the noise field, with a hot violet edge
	float d = vnoise(opos * 9.0) * 0.7 + vnoise(opos * 23.0) * 0.3;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (dissolve > 0.001) {
		ALPHA = step(dissolve * 1.08, d);
	}
	float edge = (1.0 - smoothstep(0.0, 0.06, d - dissolve * 1.08)) * step(0.001, dissolve);

	EMISSION = eye_col * UV2.x * eye_energy * (1.0 + glint * 2.5)
		+ rim_col * rim
		+ vec3(1.4, 1.25, 1.6) * hit_flash * (0.35 + 0.65 * pow(1.0 - ndv, 1.5))
		+ burn_col * edge * 3.0;
}

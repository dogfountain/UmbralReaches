shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, world_vertex_coords;
// Alpha-cut foliage card. Two sway sources: a coordinated wave that sweeps the whole field along
// wind_dir (the Ghost-of-Tsushima "wind reveals the field" look) with local per-blade jitter
// layered inside it, and a global push_pos -- broadcast every physics frame by the player -- that
// bends the top of each card away as something walks through, so grass parts rather than clips.

global uniform vec3 push_pos;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.45;
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.3;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wave_length = 7.0;       // metres between wind-wave crests sweeping the field
uniform float wave_speed = 2.6;        // metres/second the wave travels along wind_dir
uniform float wave_amount = 0.55;      // 0..1: how much sway is the big coordinated wave vs. local jitter
uniform float push_radius = 1.6;
uniform float push_strength = 0.85;
uniform float backlight = 0.45;
uniform float rim_strength = 0.15;
uniform vec3 rim_color = vec3(0.45, 0.75, 1.0);

varying vec3 wpos;

void vertex() {
	// world_vertex_coords: VERTEX is already in world space, so the sway is added directly and
	// the per-vertex inverse(MODEL_MATRIX) this used to need is gone -- it ran on every grass,
	// fern and leaf vertex in view.
	// UV.y = 0 at the card top, 1 at its root: only the top sways/parts, the root stays planted.
	float sway = (1.0 - UV.y);
	sway *= sway;
	wpos = VERTEX;
	vec2 wind_n = normalize(wind_dir);

	// Coordinated wave: every blade shares the same travelling crest, so gusts read as moving
	// bands crossing the field instead of blades twitching independently.
	float along = dot(wpos.xz, wind_n);
	float wave = sin((along - TIME * wave_speed) * TAU / wave_length);
	// Local jitter keeps texture inside a gust so it doesn't look like a single rigid sheet.
	float phase = dot(wpos.xz, vec2(0.21, 0.17));
	float gust = sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3;
	float blend = mix(gust, wave, wave_amount);
	vec3 offset = vec3(wind_dir.x, 0.0, wind_dir.y) * blend * wind_strength * sway;

	// Push grass aside around push_pos (the player's feet), falling off to nothing at push_radius.
	vec2 to_blade = wpos.xz - push_pos.xz;
	float dist = length(to_blade);
	if (dist < push_radius && dist > 0.0001) {
		float fall = pow(1.0 - dist / push_radius, 2.0);
		offset += vec3(to_blade.x, 0.0, to_blade.y) / dist * fall * push_strength * sway;
	}

	VERTEX += offset;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;   // scissor keeps the depth prepass, unlike discard
	float vein = 0.88 + 0.12 * sin(UV.y * 28.0 + wpos.x * 3.0);
	vec3 leaf = t.rgb * tint * COLOR.rgb * vein;
	float mottling = 0.92 + 0.08 * sin(wpos.x * 11.0 + wpos.z * 9.0);
	ALBEDO = leaf * mottling;
	ROUGHNESS = 0.86;
	BACKLIGHT = vec3(backlight) * ALBEDO * (1.15 - UV.y * 0.35);
	EMISSION = rim_color * rim_strength * pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0) * ALBEDO * 4.0;
}

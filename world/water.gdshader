shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
// Dark mirror water. World-space ripples (the river mesh has no tangents), opaque so
// sky / probes / SSR can catch. Emission is a faint deep glow, not the body of the water.

uniform vec4 shallow_color : source_color = vec4(0.16, 0.04, 0.055, 1.0);
uniform vec4 deep_color : source_color = vec4(0.015, 0.008, 0.014, 1.0);
uniform vec4 foam_color : source_color = vec4(0.42, 0.22, 0.20, 1.0);
uniform vec3 glow_color : source_color = vec3(0.28, 0.05, 0.07);
uniform float depth_distance : hint_range(0.1, 8.0) = 1.6;
uniform float foam_width : hint_range(0.0, 1.5) = 0.16;
uniform float wave_height : hint_range(0.0, 0.5) = 0.045;
uniform float wave_length : hint_range(0.5, 20.0) = 6.5;
uniform float wave_speed : hint_range(0.0, 2.0, 0.01) = 0.22;
uniform sampler2D normal_map_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(0.0, 2.0) = 0.38;
uniform float normal_tile_size : hint_range(0.5, 50.0) = 4.2;
uniform float roughness : hint_range(0.0, 1.0) = 0.04;
uniform float metallic : hint_range(0.0, 1.0) = 0.55;
uniform float glow_strength = 0.05;
uniform float refract_strength : hint_range(0.0, 0.08) = 0.012;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

const vec2 WAVE_DIR[4] = vec2[4](
	vec2(0.958, 0.287), vec2(-0.447, 0.894), vec2(0.6, -0.8), vec2(-0.894, -0.447)
);
const float WAVE_LENGTH[4] = float[4](1.0, 0.71, 0.53, 0.37);
const float WAVE_SHARE[4] = float[4](0.4, 0.27, 0.2, 0.13);
const float WAVE_HALF_TURNS[4] = float[4](1.0, 2.0, 2.0, 3.0);

varying vec2 world_xz;
varying vec3 world_n;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 waves(vec2 xz, float t) {
	float height = 0.0;
	vec2 slope = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		float k = TAU / (wave_length * WAVE_LENGTH[i]);
		float phase = k * dot(WAVE_DIR[i], xz) - PI * WAVE_HALF_TURNS[i] * t;
		float amplitude = wave_height * WAVE_SHARE[i];
		height += amplitude * sin(phase);
		slope += amplitude * cos(phase) * k * WAVE_DIR[i];
	}
	return vec3(height, slope);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world.xz;
	vec3 wave = waves(world.xz, TIME * wave_speed);
	VERTEX.y += wave.x;
	world_n = normalize(vec3(-wave.y, 1.0, -wave.z));
	NORMAL = normalize((MODEL_NORMAL_MATRIX * world_n));
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 uv = world_xz / max(normal_tile_size, 0.01);
	vec2 n1 = vec2(noise(uv * 3.4 + vec2(t * 0.7, -t * 0.4)), noise(uv * 3.4 + vec2(4.1, t * 0.55))) * 2.0 - 1.0;
	vec2 n2 = vec2(noise(uv * 7.8 - vec2(t * 0.9, t * 0.2)), noise(uv * 7.8 + vec2(-2.6, -t * 0.7))) * 2.0 - 1.0;
	vec2 ripple = n1 * 0.65 + n2 * 0.35;
	ripple /= max(1.0, length(ripple) / 0.9);

	// Opaque sheet: the depth and screen textures are this surface, so sampling them
	// smears the brazier and crystals across the river. Shore comes from the mesh UV.
	float shore = smoothstep(0.62, 0.94, abs(UV.y * 2.0 - 1.0));
	vec3 body = mix(deep_color.rgb, shallow_color.rgb, shore * 0.55);
	float foam = shore * smoothstep(0.2, 0.75, abs(ripple.x)) * foam_width;

	vec3 wn = normalize(world_n + vec3(ripple.x, 0.0, ripple.y) * normal_scale);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.2);
	body = mix(body, foam_color.rgb, clamp(foam, 0.0, 0.45));

	ALBEDO = body;
	ALPHA = 1.0;
	METALLIC = mix(metallic, 0.05, foam);
	ROUGHNESS = mix(roughness, 0.72, foam);
	SPECULAR = 0.45;
	float pulse = 0.82 + 0.18 * sin(TIME * 1.15 + world_xz.x * 0.07);
	float spark = pow(max(fres * (0.55 + ripple.x * 0.45), 0.0), 8.0);
	EMISSION = glow_color * glow_strength * pulse * (0.55 + fres * 0.7 + (1.0 - shore) * 0.22) * (1.0 - foam * 0.4);
	EMISSION += glow_color * spark * glow_strength * 1.8;
}

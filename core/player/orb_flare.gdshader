shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// The staff orb's starburst. world/flare.gdshader's star and halo, but:
//  - no depth texture (sampling it made the renderer copy the depth buffer every frame: ~0.3 ms
//    at 4x pixels); the billboard is pulled toward the camera instead so the claws don't slice it
//  - small and blue-violet at rest, growing and whitening with a cast (instance flare_boost 0..1)
//  - sized in the world but capped on screen (max_screen of the view height), and faded out when
//    the camera is right at the orb

uniform vec3 idle_color = vec3(0.45, 0.4, 1.5);
uniform vec3 cast_color = vec3(1.0, 0.75, 2.6);
uniform float idle_size = 0.32;      // metres across at rest (the quad is 0.7 m)
uniform float cast_size = 0.7;
uniform float max_screen = 0.06;
uniform float idle_energy = 0.45;
instance uniform float flare_boost = 0.0;
varying float far;

void vertex() {
	vec3 vp = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float d = length(vp);
	float world_w = mix(idle_size, cast_size, flare_boost);
	float screen_w = max_screen * 2.0 * d / PROJECTION_MATRIX[1][1];
	float k = min(world_w, screen_w) / 0.7;
	far = smoothstep(0.9, 2.2, d);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * k, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * k, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * k, 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[3].xyz += normalize(-MODELVIEW_MATRIX[3].xyz) * 0.14;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float soft = mix(10.0, 18.0, flare_boost);           // softer spikes at rest
	float spike_x = exp(-abs(p.x) * soft) * exp(-abs(p.y) * 2.8);
	float spike_y = exp(-abs(p.y) * soft) * exp(-abs(p.x) * 2.8);
	float halo = exp(-r * r * 4.0);
	float a = (spike_x + spike_y) * smoothstep(0.08, 0.3, r) + halo * 0.35;
	a *= (0.8 + 0.2 * sin(TIME * 2.1)) * far * mix(idle_energy, 1.0, flare_boost);
	EMISSION = mix(idle_color, cast_color, flare_boost) * a;
	ALPHA = clamp(a, 0.0, 1.0);
}

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The rift surging (phenomena.gd): the sky's vortex (world/sky/vortex.gdshader) flares. This is an
// additive overlay on the vortex, built from the same spiral (same twist, same spin from the shared
// `sky_time`), so its own arms brighten, the dark eye kindles and a ring runs outward from it.
// Sky layer (behind everything); a subdivided plane whose UV spans the vortex's tangent plane.

global uniform float sky_time;
uniform vec3 vortex_dir = vec3(0.0, 0.35, -1.0);
uniform float twist = 3.8;
uniform float arm_scale = 3.4;
uniform float spin_speed = 0.015;
uniform float span = 1.5;
uniform float sky_r = 60.0;
uniform float surge = 0.0;          // 0..1
uniform float ring = 0.0;           // the shock ring's radius (tangent-plane units)
uniform vec3 col_rift : source_color = vec3(0.357, 0.176, 0.839);
uniform vec3 col_lilac : source_color = vec3(0.663, 0.545, 1.0);
uniform vec3 col_hex : source_color = vec3(0.753, 0.302, 1.0);

varying vec2 v_p;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 3; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	vec3 c = normalize(vortex_dir);
	vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), c));
	vec3 u = cross(c, r);
	vec2 p = (UV * 2.0 - 1.0) * span;
	p.y = -p.y;
	v_p = p;
	vec3 d = normalize(c + r * p.x + u * p.y);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + d * sky_r, 1.0));
	POSITION.z = POSITION.w * 0.000001;
}

void fragment() {
	vec2 p = v_p;
	float rad = length(p);
	float ang = atan(p.y, p.x) + twist * log(rad + 0.04) - sky_time * spin_speed * 6.2832 - surge * 0.6;
	vec2 q = vec2(cos(ang), sin(ang)) * rad;
	float arms = smoothstep(0.45, 0.95, fbm(q * arm_scale + 3.0)) * smoothstep(1.5, 0.15, rad);
	float eye = smoothstep(0.22, 0.0, rad) * (0.75 + 0.25 * sin(sky_time * 9.0));
	float rim = exp(-pow((rad - 0.22) * 9.0, 2.0));
	float shock = exp(-pow((rad - ring) * 7.0, 2.0)) * smoothstep(1.5, 0.3, ring);
	float edge = smoothstep(span, span * 0.7, rad);
	vec3 col = col_lilac * arms * 0.8 + col_hex * (rim * 0.75 + eye * 0.95) + mix(col_hex, col_lilac, 0.5) * shock * 0.9;
	ALBEDO = col * surge * edge;
}

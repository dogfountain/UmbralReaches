shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_burley, specular_disabled;
// Signs left on the ground (tracks.gd): one MultiMesh of flat quads lying on the terrain.
// INSTANCE_CUSTOM: x kind (0 cloven hoof, 1 paw, 2 the white hart's hoof (glows), 3 feather,
// 4 owl pellet), y laid at (seconds on the director's clock), z life (s), w seed.
// The shapes are drawn here; `now` comes from the director at 4 Hz; prints fade with age and with
// distance from the camera.

uniform float now = 0.0;
uniform float rain = 0.0;               // rain washes prints out faster
varying vec4 v_c;
varying float v_cam_d;

void vertex() {
	v_c = INSTANCE_CUSTOM;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_cam_d = distance(w, CAMERA_POSITION_WORLD);
}

float ell(vec2 p, vec2 c, vec2 r) {
	vec2 q = (p - c) / r;
	return 1.0 - smoothstep(0.75, 1.0, dot(q, q));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;             // -1..1, +y is the animal's forward
	p.y = -p.y;
	int kind = int(v_c.x + 0.5);
	float age = now - v_c.y;
	float life = max(v_c.z, 0.01) * (1.0 - 0.6 * rain);
	float keep = 1.0 - smoothstep(life * 0.6, life, age);
	keep *= 1.0 - smoothstep(18.0, 30.0, v_cam_d);
	float a = 0.0;
	vec3 col = vec3(0.07, 0.055, 0.04);
	float emit = 0.0;
	if (kind == 0 || kind == 2) {
		// two cloven halves, pointed forward, a dew-claw mark behind
		a = max(ell(p, vec2(-0.3, 0.05), vec2(0.27, 0.7)), ell(p, vec2(0.3, 0.05), vec2(0.27, 0.7)));
		a *= smoothstep(0.95, 0.55, p.y + abs(p.x) * 0.6);
		a = max(a, 0.5 * max(ell(p, vec2(-0.32, -0.85), vec2(0.12, 0.1)), ell(p, vec2(0.32, -0.85), vec2(0.12, 0.1))));
		if (kind == 2) {
			col = vec3(0.6, 0.8, 1.0);
			emit = 0.9;
		}
	} else if (kind == 1) {
		a = ell(p, vec2(0.0, -0.35), vec2(0.42, 0.36));
		a = max(a, ell(p, vec2(-0.45, 0.25), vec2(0.16, 0.2)));
		a = max(a, ell(p, vec2(0.45, 0.25), vec2(0.16, 0.2)));
		a = max(a, ell(p, vec2(-0.16, 0.62), vec2(0.15, 0.2)));
		a = max(a, ell(p, vec2(0.16, 0.62), vec2(0.15, 0.2)));
	} else if (kind == 3) {
		// a feather: shaft along y, a vane that tapers, barbs
		float shaft = 1.0 - smoothstep(0.02, 0.05, abs(p.x));
		float w = 0.32 * (1.0 - p.y * p.y) * (1.0 - smoothstep(0.7, 1.0, p.y));
		float vane = 1.0 - smoothstep(w - 0.04, w, abs(p.x - 0.03 * p.y));
		float barbs = 0.75 + 0.25 * sin((p.y - abs(p.x) * 0.8) * 70.0);
		a = max(vane * barbs * 0.85, shaft) * step(-0.95, p.y);
		col = mix(vec3(0.55, 0.5, 0.42), vec3(0.18, 0.15, 0.12), smoothstep(-0.2, 0.9, p.y + fract(v_c.w * 7.0) * 0.4));
	} else {
		a = ell(p, vec2(0.0), vec2(0.45, 0.8));
		col = vec3(0.22, 0.2, 0.18);
	}
	// a pressed print: dark in the hollow, a lighter lip of pushed-up soil round it
	if (kind <= 2) {
		float lip = smoothstep(0.0, 0.5, a) * (1.0 - smoothstep(0.5, 1.0, a));
		col = mix(col, vec3(0.32, 0.29, 0.25), lip * 0.6);
	}
	ALBEDO = col;
	EMISSION = col * emit;
	ROUGHNESS = 0.95;
	ALPHA = clamp(a * keep * (kind <= 2 ? 0.92 : 1.0), 0.0, 1.0);
}

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Meteors (phenomena.gd): one MultiMesh of thin quads, every streak placed and timed here from its
// instance seed, so a shower costs no script time. Each slot re-rolls per cycle (period custom.x):
// whether it fires (against `rate`, the shower's strength), where (round the radiant, all streaks
// running away from it), how long and how bright. Sky layer: drawn at SKY_R round the camera and
// pushed to the far end of the depth range (behind everything, past the 82 m far plane).
// INSTANCE_CUSTOM: x period (s), y phase (s), z seed, w brightness.
// `manual` >= 0: a single CPU-driven fireball (the bolide), progress = manual, wide and slow.

uniform float rate = 0.0;
uniform vec3 radiant = vec3(-0.35, 0.8, -0.45);
uniform float sky_r = 60.0;
uniform float manual = -1.0;
uniform vec3 bolide_from = vec3(0.6, 0.6, -0.5);
uniform vec3 bolide_dir = vec3(-0.8, -0.35, 0.1);
uniform vec3 tint : source_color = vec3(0.85, 0.95, 1.0);

varying float v_a;
varying vec2 v_uv;

float h1(float n) { return fract(sin(n * 127.1 + 0.37) * 43758.5453); }

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 head;
	vec3 tail;
	float width;
	float on;
	if (manual >= 0.0) {
		float k = clamp(manual, 0.0, 1.0);
		head = normalize(bolide_from + bolide_dir * 0.7 * k);
		tail = normalize(bolide_from + bolide_dir * 0.7 * max(k - 0.32, 0.0));
		width = 0.55;
		on = smoothstep(0.0, 0.05, k) * (1.0 - smoothstep(0.85, 1.0, k)) * (0.85 + 0.15 * sin(TIME * 40.0));
	} else {
		float per = c.x;
		float tt = TIME + c.y;
		float cyc = floor(tt / per);
		float lt = tt - cyc * per;
		float s = c.z * 13.7 + cyc * 7.31;
		float live = step(h1(s + 0.5), rate);
		float dur = mix(0.35, 0.95, h1(s + 1.0));
		float k = clamp(lt / dur, 0.0, 1.0);
		vec3 r = normalize(radiant);
		vec3 t1 = normalize(cross(r, vec3(0.0, 1.0, 0.001)));
		vec3 t2 = cross(r, t1);
		float az = h1(s + 2.0) * 6.2832;
		float off = mix(0.2, 1.1, h1(s + 3.0));
		vec3 start = normalize(r + (cos(az) * t1 + sin(az) * t2) * off);
		vec3 away = normalize(start - r * dot(start, r) + vec3(0.0001));
		float travel = mix(0.12, 0.38, h1(s + 4.0));
		head = normalize(start + away * travel * k);
		tail = normalize(start + away * travel * max(k - 0.3, 0.0));
		width = mix(0.05, 0.12, c.w);
		on = live * step(lt, dur) * smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.75, 1.0, k)) * c.w;
		on *= step(0.04, head.y);
	}
	vec3 H = head * sky_r;
	vec3 T = tail * sky_r;
	vec3 along = H - T + vec3(0.00001, 0.0, 0.0);
	vec3 side = normalize(cross(along, head)) * width;
	vec3 P = mix(T, H, UV.x) + side * (UV.y - 0.5);
	v_a = on;
	v_uv = UV;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + P, 1.0));
	POSITION.z = POSITION.w * 0.000001;
	if (on <= 0.0) {
		POSITION = vec4(0.0, 0.0, -2.0, 1.0);      // nothing to draw: off the clip volume
	}
}

void fragment() {
	float across = abs(v_uv.y * 2.0 - 1.0);
	float core = exp(-across * across * 6.0);
	float trail = pow(v_uv.x, 2.2);
	float head = exp(-(1.0 - v_uv.x) * 30.0);
	vec3 col = mix(vec3(0.55, 0.75, 1.0), tint, trail) * (trail * 0.9 + head * 1.4) * core;
	if (manual >= 0.0) {
		col = mix(vec3(1.0, 0.55, 0.25), vec3(0.9, 1.0, 0.8), head) * (trail * 1.1 + head * 2.0) * core;
	}
	ALBEDO = col * v_a;
}

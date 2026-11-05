// Wildlife rig (core/life/wildlife): every limb animated from per-instance custom data. Shared by
// creature.gdshader (the living) and ghost.gdshader (the white hart). See creature.gdshader for the
// mesh channels and INSTANCE_CUSTOM layout.

uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 9.0;
uniform float detail = 0.55;
uniform float streak = 1.0;              // stretch the detail along UV.y (feathers, fur lie)
uniform float roughness = 0.82;
uniform vec3 head_pivot = vec3(0.0, 0.3, -0.1);
uniform vec3 wing_hinge = vec3(0.05, 0.25, 0.0);   // x = half shoulder width, y = shoulder height
uniform float wing_amp = 0.9;
uniform float wing_fold = 1.4;          // folded: swept back along the body...
uniform float wing_roll = 1.2;          // ...and rolled so the trailing edge hangs down the flank
uniform float wing_glide = 0.15;
uniform float flap_hz = 7.0;
uniform vec2 hip_front = vec2(0.6, -0.3);           // (y, z) of the front shoulder joint
uniform vec2 hip_back = vec2(0.6, 0.3);
uniform float leg_amp = 0.45;
uniform vec3 throat_c = vec3(0.0, 0.02, -0.04);
uniform float tail_sway = 0.12;
uniform vec3 eye_col : source_color = vec3(0.9, 0.55, 0.15);
uniform float eye_energy = 0.0;
uniform vec3 rim_col : source_color = vec3(0.35, 0.55, 1.0);
uniform float rim_amount = 0.25;
uniform float throat_auto = 0.0;         // frogs: the throat pulses on the GPU (c.x = the chorus gate)
uniform float wet = 0.0;                 // drizzle: the director darkens and glosses fur/feathers

varying float v_eye;
varying float v_blink;

mat3 rot_x(float a) { float c = cos(a), s = sin(a); return mat3(vec3(1, 0, 0), vec3(0, c, s), vec3(0, -s, c)); }
mat3 rot_y(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, 0, -s), vec3(0, 1, 0), vec3(s, 0, c)); }
mat3 rot_z(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0), vec3(-s, c, 0), vec3(0, 0, 1)); }

void rig_vertex(inout vec3 VERT, inout vec3 NORM, vec4 c, vec2 uv2, int iid, float time, out float o_eye, out float o_blink) {
	int part = int(uv2.x + 0.5);
	float seed = fract(float(iid) * 0.61803);
	vec3 p = VERT;
	vec3 n = NORM;
	if (part == 1) {
		mat3 r = rot_y(c.y) * rot_x(c.w);
		p = head_pivot + r * (p - head_pivot);
		n = r * n;
	} else if (part == 2 || part == 3) {
		float side = part == 2 ? 1.0 : -1.0;
		float beat = sin(time * flap_hz * (0.9 + 0.2 * seed) + seed * 6.2831);
		// folded: the spread wing swings back along the body (about Y) and droops a little;
		// flying: it beats about the body's long axis
		float fl = clamp(c.x, 0.0, 1.0);
		float a = mix(-0.12, beat * wing_amp + wing_glide, fl);
		vec3 h = vec3(side * wing_hinge.x, wing_hinge.y, wing_hinge.z);
		mat3 r = rot_z(side * wing_roll * (1.0 - fl)) * rot_y(-side * wing_fold * (1.0 - fl)) * rot_z(side * a);
		// a folded wing is compact: span and chord drawn in toward the shoulder
		vec3 q = p - h;
		q.x *= mix(0.55, 1.0, fl);
		q.z *= mix(0.75, 1.0, fl);
		p = h + r * q;
		n = r * n;
	} else if (part >= 4 && part <= 7) {
		bool front = part <= 5;
		float off = (part == 4 || part == 7) ? 0.0 : 3.14159;
		vec2 hp = front ? hip_front : hip_back;
		vec3 h = vec3(0.0, hp.x, hp.y);
		mat3 r = rot_x(sin(c.z + off) * leg_amp);
		p = h + r * (p - h);
		n = r * n;
	} else if (part == 8) {
		float a = sin(time * 2.1 + seed * 9.0) * tail_sway;
		mat3 r = rot_y(a);
		vec3 h = vec3(0.0, p.y, hip_back.y);
		p = h + r * (p - h);
		n = r * n;
	} else if (part == 9) {
		float pulse = clamp(c.x, 0.0, 1.0);
		if (throat_auto > 0.5) {
			// frogs (r29): c.x is the chorus' gate; each frog calls in bursts of ~5 s in every 9 at its
			// own rate, here on the GPU (script time and a buffer write per frame before)
			float m = mod(time + fract(seed * 7.13) * 9.0, 9.0);
			float on = smoothstep(0.0, 0.25, m) * (1.0 - smoothstep(5.25, 5.5, m));
			float s = max(0.0, sin(time * (4.5 + 2.5 * fract(seed * 13.7)) * 3.14159 + seed * 6.2831));
			pulse = pulse * on * s * s;
		}
		p = throat_c + (p - throat_c) * (1.0 + pulse * 1.6);
	}
	VERT = p;
	NORM = n;
	o_eye = uv2.y;
	// owls and deer blink: eyes shut for ~0.15 s every few seconds
	o_blink = step(0.035, fract(time * 0.21 + seed * 7.3));
}


shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque, cull_disabled;
// Flyers that need no CPU at all (core/life/wildlife): moths round lanterns and braziers, bats over
// the Ashen Rift. Each MultiMesh instance's origin is the centre it circles; INSTANCE_CUSTOM holds
// x = radius (m), y = angular speed (rad/s, sign = direction), z = height swing (m), w = phase.
// The path is an ellipse with a vertical wobble and jinks; the body is turned along it, banked into
// the turn, and its wings (UV2.x 2 / 3, hinged at wing_hinge) beat. Creatures face -Z.

uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 4.0;
uniform float detail = 0.6;
uniform vec3 wing_hinge = vec3(0.004, 0.0, 0.0);
uniform float wing_amp = 1.0;
uniform float flap_hz = 22.0;
uniform float jink = 0.12;               // erratic sideways darts (moths high, bats medium)
uniform float ellipse = 0.75;
uniform float bank = 0.45;
uniform float roughness = 0.8;
uniform float translucency = 0.0;        // moth wings glow when the lamp is behind them
uniform float activity = 1.0;            // director: rain / dawn thin the swarm (instances beyond it hide)
uniform vec3 rim_col : source_color = vec3(1.0, 0.75, 0.4);
uniform float rim_amount = 0.0;
uniform float size_mul = 1.0;
uniform float excite = 0.0;              // phenomena: the rift surges and the bats boil up and out
instance uniform float arrive = 1.0;     // per swarm: 0 -> 1 as moths find a newly kindled flame

mat3 rot_z(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0), vec3(-s, c, 0), vec3(0, 0, 1)); }

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float seed = fract(float(INSTANCE_ID) * 0.61803 + c.w * 0.1);
	float a = TIME * c.y + c.w;
	float k = 1.7 + seed * 1.3;
	float r = c.x * (1.0 + 0.18 * sin(TIME * 0.7 + seed * 11.0)) * (1.0 + 0.6 * excite) * mix(5.0, 1.0, arrive);
	vec3 pos = vec3(cos(a) * r, sin(a * k + seed * 5.0) * c.z, sin(a) * r * ellipse);
	vec3 vel = vec3(-sin(a) * r, cos(a * k + seed * 5.0) * c.z * k, cos(a) * r * ellipse) * sign(c.y);
	// jinks: a fast wobble across the path
	float j1 = sin(TIME * 5.3 + seed * 31.0) * sin(TIME * 1.7 + seed * 7.0);
	float j2 = cos(TIME * 4.1 + seed * 17.0);
	pos += vec3(j1, j2 * 0.6, -j1) * jink * c.x * (1.0 + 2.0 * excite);
	pos.y += excite * c.z * 2.5 * (0.5 + 0.5 * sin(TIME * 0.9 + seed * 5.0));
	// arriving: they come in from upwind and out of the dark, a few at a time
	pos += vec3(1.0, 0.4, 0.6) * (1.0 - arrive) * (4.0 + seed * 6.0);
	vec3 fwd = normalize(vel + vec3(0.0001, 0.0, 0.0));
	vec3 back = -fwd;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), back));
	vec3 up = cross(back, right);
	mat3 b = mat3(right, up, back);
	b = b * rot_z(-bank * sign(c.y));
	int part = int(UV2.x + 0.5);
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	if (part == 2 || part == 3) {
		float side = part == 2 ? 1.0 : -1.0;
		float beat = sin(TIME * flap_hz * (0.85 + 0.3 * seed) + seed * 40.0);
		float ang = side * (beat * wing_amp + 0.1);
		vec3 h = vec3(side * wing_hinge.x, wing_hinge.y, wing_hinge.z);
		p = h + rot_z(ang) * (p - h);
		n = rot_z(ang) * n;
	}
	float scale = (0.8 + 0.4 * fract(seed * 13.7)) * size_mul;
	float alive = step(seed, activity) * step(seed, arrive * 1.15);
	VERTEX = pos + b * (p * scale * alive);
	NORMAL = b * n;
}

void fragment() {
	float d = texture(detail_tex, UV * detail_scale).r;
	ALBEDO = COLOR.rgb * mix(1.0, 0.5 + d, detail);
	ROUGHNESS = roughness;
	BACKLIGHT = COLOR.rgb * translucency;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	EMISSION = rim_col * fres * rim_amount;
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Cloth for the wanderer: the arcane fleck look plus vertex motion driven per piece by CharacterRig.
// Weight runs from 0 at the anchor (where cloth is held: shoulders, waist, arm) to 1 at the free edge.

uniform vec3 base_color : source_color = vec3(0.24, 0.09, 0.58);
uniform vec3 glow_color : source_color = vec3(0.62, 0.30, 1.0);
uniform vec3 glow_hot : source_color = vec3(0.95, 0.40, 1.0);
uniform float glow_energy = 4.5;  // per-material override; see character_rig.gd
uniform float fleck_scale = 16.0;
uniform float drift = 0.12;
uniform vec3 rim_color = vec3(0.7, 0.5, 1.0);
uniform float rim_strength = 0.45;

instance uniform vec3 cloth_lag = vec3(0.0);     // spring offset in this mesh's local space (m)
instance uniform float walk_phase = 0.0;         // stride phase (rad); left leg forward at sin > 0
instance uniform float stride = 0.0;             // 0 idle .. ~1.3 sprint
instance uniform float flare = 0.0;              // hem opening (speed, falling)
instance uniform float anchor_y = 0.7;           // local y where the cloth is held
instance uniform float cloth_len = 1.4;          // anchor to free edge (m)
instance uniform float leg_push = 0.0;           // 1 on the robe, 0 elsewhere

varying vec3 lpos;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void vertex() {
	lpos = VERTEX;   // pattern sampled before deformation so flecks ride the cloth instead of swimming
	float w = clamp((anchor_y - VERTEX.y) / cloth_len, 0.0, 1.0);
	float w2 = w * w;
	vec2 radial = VERTEX.xz / max(length(VERTEX.xz), 1e-4);

	// Legs push the robe: the forward leg presses the front panel out, the trailing leg drags the back.
	float leg_l = sin(walk_phase);
	float side = smoothstep(-0.2, 0.2, VERTEX.x);      // 0 left half .. 1 right half
	float leg = mix(leg_l, -leg_l, side);              // + means that half's leg is forward
	float front = clamp(-radial.y, 0.0, 1.0);           // forward is -Z
	float back = clamp(radial.y, 0.0, 1.0);
	float push = leg * stride * leg_push * w;
	VERTEX.z -= push * (0.27 * front + 0.1 * back);
	VERTEX.x += radial.x * abs(leg) * stride * leg_push * w * 0.04;
	float near_slit = smoothstep(0.75, 0.97, front) * leg_push * w;
	VERTEX.x += sign(VERTEX.x) * near_slit * (0.05 + abs(leg) * stride * 0.12);

	// Inertia: free edge trails behind motion and overshoots when the body stops.
	VERTEX.xz += cloth_lag.xz * w2;
	VERTEX.y += cloth_lag.y * w2 * 0.6;

	// Flare with speed or when falling, plus a travelling ripple so the hem never looks rigid.
	VERTEX.xz += radial * flare * w2 * 0.14;
	float ang = atan(VERTEX.z, VERTEX.x);
	float ripple = sin(ang * 7.0 + TIME * (1.8 + stride * 7.0) + VERTEX.y * 6.0) * 0.5
	             + sin(ang * 3.0 - TIME * 1.3 + VERTEX.y * 2.0) * 0.5;
	VERTEX.xz += radial * ripple * 0.022 * w * (0.4 + stride);
	// Slow, large-amplitude billow so the cloak keeps moving like real fabric even at rest.
	float billow = sin(ang * 1.5 + TIME * 0.7) * 0.6 + sin(ang * 2.3 - TIME * 0.5 + 1.3) * 0.4;
	VERTEX.xz += radial * billow * 0.05 * w2;
}

void fragment() {
	vec3 p = lpos * fleck_scale + vec3(0.0, -TIME * drift, 0.0);
	float n = fbm(p);
	float fine = noise(p * 4.0);
	float flecks = smoothstep(0.73, 0.82, n) * (0.5 + 0.5 * fine);
	float sparks = step(0.96, fine) * smoothstep(0.55, 0.68, n);
	float veins = smoothstep(0.485, 0.5, n) - smoothstep(0.5, 0.515, n);
	ALBEDO = base_color * (0.8 + 0.3 * n);
	ROUGHNESS = 0.85;
	BACKLIGHT = ALBEDO * 0.35;   // thin fabric lets light through at the edges
	vec3 g = mix(glow_color, glow_hot, smoothstep(0.66, 0.8, n));
	float pulse = 0.75 + 0.25 * sin(TIME * 1.6 + n * 14.0);
	EMISSION = g * (flecks + sparks * 1.5 + veins * 0.25) * glow_energy * pulse
	         + rim_color * rim_strength * pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
}

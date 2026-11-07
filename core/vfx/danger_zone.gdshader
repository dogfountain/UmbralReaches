shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// Mix blending, not additive: overlapping zones (crossing lanes, a boss's spikes, a pack's cones)
// deepen toward the colour instead of stacking to a blown-out white.
// r29 readability (zz/critA_color_shot): the fill is drawn at the colour's saturated peak, not in
// HDR -- HDR fills tonemapped to a pale cream and the night grade then pulled their hue to lilac.
// Hue survives; only the outline and the moving front stay hot. And the zone is never lost in
// grass or under a slope: it tests depth itself, so a little of whatever stands in front (grass,
// a shrub, the uphill ground) still shows the outline and the front through it; anything more
// than HIDE_M in front (a wall, a rise) hides it as before.
// Attack telegraph on the ground: the exact area that will be hit, outlined at once, filling
// from the attacker outward as the windup runs (progress 0 -> 1). When the fill reaches the edge
// the attack lands -- so "the red has filled" is the dodge cue, for every enemy and boss move.
//   shape 0  disc or sector (half_angle < PI): a strike cone, a slam, a spike ring
//   shape 1  rectangle (a charge lane, a line of thorns): fills from its back edge (+z) to -z
// The quad is 2x2 in local space; the node scales it to the real size in metres (size_m).

uniform vec3 color : source_color = vec3(2.6, 0.55, 0.1);
uniform int shape = 0;
uniform float half_angle = 3.1416;
instance uniform float progress = 0.0;
instance uniform float fade = 1.0;
instance uniform float soft = 0.0;   // 1 for a zone that is not the one landing next: outline only, dim
instance uniform vec2 size_m = vec2(1.0, 1.0);   // half-extents in metres (x, z)
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
const float HIDE_M = 1.4;       // more than this in front of the zone hides it

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;            // x -> +X, y -> +Z; forward is -Z
	vec2 m = p * size_m;                // metres
	float edge_m;                       // distance to the outline, metres
	float t;                            // 0 at the attacker, 1 at the far edge
	if (shape == 0) {
		float r = length(p);
		if (r > 1.0) {
			discard;
		}
		float a = abs(atan(p.x, -p.y));
		if (a > half_angle) {
			discard;
		}
		float rm = length(m);
		edge_m = size_m.x - rm;
		if (half_angle < 3.1) {
			// distance to the cone's straight sides
			float side = rm * sin(half_angle - a);
			edge_m = min(edge_m, side);
		}
		t = r;
	} else {
		if (abs(p.x) > 1.0 || abs(p.y) > 1.0) {
			discard;
		}
		edge_m = min(size_m.x - abs(m.x), size_m.y - abs(m.y));
		t = (1.0 - p.y) * 0.5;
	}
	float pr = clamp(progress, 0.0, 1.0);
	float outline = 1.0 - smoothstep(0.0, 0.07, edge_m);
	// r30: read by FORM, not hue (ember is also the lava's and the lanterns' colour): a second, thin
	// ring just inside the outline that pulses inward, dashed and marching round the edge
	float ring_at = 0.22 + 0.1 * fract(TIME * 1.6);
	float ring2 = (1.0 - smoothstep(0.0, 0.035, abs(edge_m - ring_at))) * (1.0 - fract(TIME * 1.6));
	float dash = step(0.5, fract((atan(p.x, -p.y) * length(m) + edge_m) * 2.2 - TIME * 1.5));
	ring2 *= mix(1.0, dash, step(edge_m, 9.0)) * 0.8;
	float filled = 1.0 - smoothstep(pr - 0.015, pr, t);
	float front = exp(-pow((t - pr) * 18.0, 2.0)) * step(pr, 0.995);
	// grain so the fill reads as scorched ground rather than a flat decal
	float g = n2(m * 3.2 + vec2(TIME * 0.3, 0.0)) * 0.5 + n2(m * 7.0) * 0.5;
	float calm = mix(1.0, 0.22, soft);
	float base = (0.025 + 0.02 * g) * calm;
	float fill = filled * (0.07 + 0.07 * g + 0.14 * pr * pr) * calm;
	// the last 12 % of the windup pulses: it is about to land
	float urgent = smoothstep(0.88, 1.0, pr) * (0.5 + 0.5 * sin(TIME * 40.0));
	// what stands in front of this pixel of the zone, in metres along the view
	float scene_z = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_z, 1.0);
	float in_front = (-VERTEX.z) - (-sv.z / sv.w);
	if (in_front > HIDE_M) {
		discard;
	}
	float through = smoothstep(0.03, 0.12, in_front);   // 0 in the open, 1 seen through grass
	float edge = clamp(outline + front + ring2, 0.0, 1.0);
	// seen through something: only the outline and the travelling front (no fill over the
	// wanderer's robe when you stand in it, just the lines that say where and when)
	float k = (base + fill + urgent * 0.16 * filled * calm) * (1.0 - through) + (outline * (0.8 + 0.5 * pr) * mix(1.0, 0.6, soft) + front * 0.7 * calm + ring2 * 0.45 * calm) * (1.0 - 0.45 * through);
	k *= fade;
	float cmax = max(max(color.r, max(color.g, color.b)), 0.001);
	vec3 peak = color / cmax;
	// a pale colour (bone, salt, holy white) would wash to a flat sheet and vanish on pale stone:
	// keep its hue, calm the fill a little, and draw a dark contour just inside the bright line
	float pale = 1.0 - smoothstep(0.3, 0.62, 1.0 - min(color.r, min(color.g, color.b)) / cmax);
	float rim = smoothstep(0.05, 0.1, edge_m) * (1.0 - smoothstep(0.17, 0.26, edge_m)) * pale;
	vec3 inner = peak * (0.5 + 0.2 * g + 0.25 * urgent) * mix(1.0, 0.8, pale);
	vec3 hot = color * (0.55 + 0.6 * edge + 0.3 * urgent);
	// the travelling front burns white-hot at its leading edge: nothing in the set dressing does that
	hot = mix(hot, vec3(1.9, 1.6, 1.2) * max(max(color.r, color.g), color.b) * 0.4, clamp(front * 0.3 + urgent * outline * 0.2, 0.0, 1.0));
	vec3 col_out = mix(inner, hot, edge);
	float rim_a = rim * 0.5 * fade * mix(1.0, 0.5, soft) * (1.0 - through);
	col_out = mix(col_out, vec3(0.03, 0.025, 0.02), rim * (1.0 - edge));
	ALBEDO = col_out;
	ALPHA = clamp(max(k, rim_a), 0.0, 0.8);
}

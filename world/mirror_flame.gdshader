shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
// Keeps the modeled flame silhouette. Vertex color is the heat; the zone tints it.
// A small lick along the tips is the warp. Tips soften, the body stays.

uniform vec3 fire_hot : source_color = vec3(1.0, 0.72, 0.28);
uniform vec3 fire_mid : source_color = vec3(1.0, 0.32, 0.06);
uniform vec3 fire_cool : source_color = vec3(0.45, 0.05, 0.02);
uniform float intensity = 1.05;

varying vec3 graded;
varying float tip;

void vertex() {
	// Move in the plane of the arch. Normals point at the camera, so pushing
	// along them never changes the outline you see.
	vec2 radial = VERTEX.xy - vec2(0.0, 2.4);
	float span = length(radial);
	vec2 outward = span > 0.001 ? radial / span : vec2(0.0, 1.0);
	vec2 along = vec2(-outward.y, outward.x);
	float edge = smoothstep(0.18, 0.75, UV.y);
	float travel = sin(UV.x * 16.0 + TIME * 2.2);
	float swell = sin(UV.x * 5.0 - TIME * 1.15);
	VERTEX.xy += outward * (travel * 0.16 + swell * 0.07) * edge;
	VERTEX.xy += along * sin(UV.x * 9.0 + TIME * 1.6) * 0.07 * edge;
	VERTEX.z += sin(UV.x * 11.0 + TIME * 1.8) * 0.035 * edge;
	float heat = clamp(max(COLOR.r, max(COLOR.g, COLOR.b)), 0.0, 1.0);
	vec3 col = mix(fire_cool, fire_mid, smoothstep(0.2, 0.55, heat));
	graded = mix(col, fire_hot, smoothstep(0.55, 0.92, heat));
	tip = UV.y;
}

void fragment() {
	float flicker = 0.86 + 0.14 * sin(TIME * 6.0 + UV.x * 14.0 + tip * 8.0);
	ALBEDO = graded * intensity * flicker;
	ALPHA = 1.0 - smoothstep(0.84, 1.0, tip);
}

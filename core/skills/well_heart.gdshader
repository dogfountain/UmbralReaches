shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
// Umbral Well's heart (skills, r28): a sphere of black with a violet event-horizon rim and bands
// of light winding into it. `heat` (instance) turns the rim to ember when a Lance lights a
// Maelstrom; `life` (instance) swells the rim as the collapse nears. One draw, opaque.

instance uniform float heat = 0.0;
instance uniform float life = 0.0;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.2);
	vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float ang = atan(n.z, n.x);
	float band = sin(ang * 3.0 + n.y * 6.0 - TIME * 5.0 + rim * 7.0);
	band = smoothstep(0.55, 1.0, band) * rim;
	vec3 violet = vec3(1.3, 0.5, 3.2);
	vec3 ember = vec3(3.2, 1.0, 0.3);
	vec3 hue = mix(violet, ember, heat);
	vec3 c = hue * (rim * (1.4 + life * 1.6) + band * 1.6);
	ALBEDO = c * (0.9 + 0.1 * sin(TIME * 13.0));
}

shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Pilgrims' cloths tied to the Sky Chain's iron: faded dye, sways from the knot (UV.y 0) to the tail (1).
// Per instance, the wind phase comes from where the cloth hangs, so no two move alike.

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = o.x * 0.37 + o.z * 0.29 + o.y * 0.11;
	float k = UV.y * UV.y;
	VERTEX.x += (sin(TIME * 1.7 + ph) * 0.16 + sin(TIME * 3.1 + ph * 2.0) * 0.05) * k;
	VERTEX.z += (cos(TIME * 1.3 + ph * 1.3) * 0.12) * k;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

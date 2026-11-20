extends MeshInstance3D
## A fire's far read (polish, 21 Nov: Hearthward's fire at 230 m was a tiny warm dot): a soft column of lit smoke standing over a
## lit brazier, warm from below, thin and tall, fading out towards the top. Unshaded additive card turning about the vertical
## (no light, no shadow, no fog), clear within 35 m (the fire's own flames and light take over) and full from 90 m. Hidden while the
## brazier is unlit. Load by path (no class_name).

const H := 60.0
const W := 12.0
const SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.5, 0.2);
uniform float strength = 0.95;
void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - centre;
	to_cam.y = 0.0;
	vec3 f = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), f));
	vec3 world = centre + r * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	float h = 1.0 - UV.y;
	float w = mix(1.0, 0.3, h);
	float e = clamp(1.0 - abs(UV.x - 0.5) * 2.0 / w, 0.0, 1.0);
	float a = e * e * (3.0 - 2.0 * e) * pow(1.0 - h, 1.5);
	a *= 0.8 + 0.2 * sin(h * 13.0 - TIME * 0.7 + UV.x * 3.0);
	float d = length(CAMERA_POSITION_WORLD - NODE_POSITION_WORLD);
	float near = smoothstep(35.0, 90.0, d) * (1.0 - smoothstep(420.0, 560.0, d));
	ALBEDO = tint * a * strength * near * (0.9 + 0.1 * sin(TIME * 2.3));
}"""

var brazier: Node
var _said := false


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(W, H)
	q.center_offset = Vector3(0.0, H * 0.5, 0.0)
	mesh = q
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	extra_cull_margin = 60.0
	ignore_occlusion_culling = true
	visibility_range_end = 0.0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	if brazier != null and is_instance_valid(brazier):
		visible = bool(brazier.get("lit"))
		if not _said:
			_said = true
			print("FAR_PLUME %s lit %s at %s" % [brazier.name, visible, global_position])

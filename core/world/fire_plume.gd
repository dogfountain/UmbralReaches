extends MeshInstance3D
## A fire's far read (polish, 21 Nov: Hearthward's fire at 230 m was a tiny warm dot): a soft column of lit smoke standing over a
## lit brazier, warm from below, thin and tall, fading out towards the top. Unshaded additive card turning about the vertical
## (no light, no shadow, no fog), clear within 35 m (the fire's own flames and light take over) and full from 90 m. Hidden while the
## brazier is unlit. Load by path (no class_name).

const H := 90.0
const W := 26.0
const SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 warm : source_color = vec3(1.0, 0.52, 0.10);
uniform vec3 smoke : source_color = vec3(0.34, 0.27, 0.27);
uniform float strength = 0.30;
void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - centre;
	to_cam.y = 0.0;
	vec3 f = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), f));
	vec3 world = centre + r * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.15; }
void fragment() {
	float h = 1.0 - UV.y;                                   // 0 at the fire, 1 at the top
	// the column widens as it rises and leans away down the wind, its curl slow
	float wid = mix(0.10, 0.34, pow(h, 0.65));
	float lean = (0.10 * h + 0.07 * sin(h * 4.2 + TIME * 0.11)) * 1.0;
	float x = (UV.x - 0.5 - lean) / wid;                    // -1 .. 1 across the column
	// billows: noise that climbs with time, stretched along the column, drifting sideways as it rises
	vec2 np = vec2(x * 1.7 + sin(h * 3.0 - TIME * 0.2) * 0.5, h * 2.4 - TIME * 0.16);
	float n = fbm(np);
	float n2 = fbm(np * 1.9 + vec2(4.0, -TIME * 0.11));
	float core = 1.0 - abs(x) * 0.85;
	float d = clamp(core + (n - 0.5) * 1.15 + (n2 - 0.5) * 0.5, 0.0, 1.0);
	d = smoothstep(0.12, 0.85, d);
	d *= smoothstep(0.0, 0.14, h) * (1.0 - smoothstep(0.42, 1.0, h));
	// lit from below by the fire: strong warm only in the lowest third, then an ember-grey smoke
	float lit = 1.0 - smoothstep(0.02, 0.30, h);
	vec3 col = mix(smoke, warm, lit);
	float glow = mix(0.5, 1.35, lit);
	float dist = length(CAMERA_POSITION_WORLD - NODE_POSITION_WORLD);
	float near = smoothstep(35.0, 90.0, dist) * (1.0 - smoothstep(420.0, 560.0, dist));
	ALBEDO = col * d * glow * strength * near * (0.92 + 0.08 * sin(TIME * 2.1 + n * 6.0));
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

class_name MotionBlur
extends MeshInstance3D
## Subtle camera motion blur. A full-screen quad under the camera reprojects every pixel with last
## frame's camera (depth -> world -> previous screen position) and smears along that screen motion.
## - drawn FIRST in the transparent pass (render_priority -128): the screen copy holds the opaque
##   scene, and flames, glimmers and particles draw over the blurred result, crisp
## - nothing within ~5 m of the camera blurs, so the wanderer and the ground at his feet stay sharp
## - the length is normalised to a 60 fps shutter, so the look doesn't change with frame rate
## - strength 0 hides the node (no screen copy, no cost). Settings.motion_blur drives it.
## - a camera at rest (or drifting under half a pixel of smear) hides it too: the screen copy and
##   8 taps per pixel were ~1.3 ms at 4x pixels for nothing; moving, pixels that move under half a
##   pixel are dropped before any tap and short smears take fewer taps (one per ~2.5 px, 3..8)
## - only the owning camera blurs: the quad is in the world, so mirrors, portals and free cameras
##   would otherwise be smeared with the player camera's history

const SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform mat4 prev_view;              // last frame's world -> view
uniform float strength = 0.25;       // 0..1
uniform float frame_scale = 1.0;     // (1/60 s) / frame time
uniform float max_len = 0.02;        // longest smear, in screen widths
uniform vec3 owner_pos;              // the camera this blur belongs to; any other camera is skipped

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	if (distance(INV_VIEW_MATRIX[3].xyz, owner_pos) > 0.75) {
		discard;                     // a mirror, portal or free camera: prev_view is not its history
	}
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, max(depth, 1e-6));
	vec4 vpos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vpos.xyz /= vpos.w;
	vec4 world = INV_VIEW_MATRIX * vec4(vpos.xyz, 1.0);
	vec4 prev = PROJECTION_MATRIX * prev_view * world;
	vec2 prev_uv = (prev.xy / prev.w) * 0.5 + 0.5;
	vec2 vel = (SCREEN_UV - prev_uv) * strength * frame_scale;
	float len = length(vel);
	if (len > max_len) {
		vel *= max_len / len;
		len = max_len;
	}
	float near_mask = smoothstep(4.5, 7.0, -vpos.z);
	vel *= near_mask;
	// still pixels add nothing (alpha 0): no softening when the camera is at rest
	float alpha = clamp(len * near_mask * 300.0, 0.0, 1.0);
	float len_px = length(vel * VIEWPORT_SIZE);
	if (alpha < 0.002 || len_px < 0.5) {
		discard;                     // a smear under half a pixel shows nothing: no taps for it
	}
	// one tap per ~2.5 px of smear (3..8): the jitter hides the spacing either way
	int n = clamp(int(ceil(len_px / 2.5)), 3, 8);
	vec3 acc = vec3(0.0);
	// interleaved-gradient jitter per pixel: a smooth smear instead of N ghost copies
	float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float inv_n = 1.0 / float(n);
	for (int i = 0; i < n; i++) {
		float t = ((float(i) + ign) * inv_n) - 0.5;
		acc += texture(screen_tex, SCREEN_UV + vel * t).rgb;
	}
	ALBEDO = acc * inv_n;
	ALPHA = alpha;
}
"""

var strength := 0.25:
	set(v):
		strength = clampf(v, 0.0, 1.0)
		visible = strength > 0.001 and _moving
		if _mat:
			_mat.set_shader_parameter("strength", strength)

## Below this the longest smear on screen (pixels, with a 2x margin for the wide-angle edges) shows
## nothing: the quad is left out of the frame (no screen copy, no taps). The shader drops pixels under
## half a pixel of smear the same way.
const STILL_PX := 0.5
var _moving := true

var _mat: ShaderMaterial
var _cam: Camera3D
var _prev := Transform3D.IDENTITY
var _have_prev := false


static func attach(cam: Camera3D) -> MotionBlur:
	if cam == null:
		return null
	var existing := cam.get_node_or_null("MotionBlur") as MotionBlur
	if existing:
		return existing
	var mb := MotionBlur.new()
	mb.name = "MotionBlur"
	cam.add_child(mb)
	return mb


func _ready() -> void:
	_cam = get_parent() as Camera3D
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	mesh = q
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.render_priority = Material.RENDER_PRIORITY_MIN
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	ignore_occlusion_culling = true
	position = Vector3(0, 0, -0.5)
	strength = strength
	process_priority = 1000              # after the camera has moved this frame


func _process(delta: float) -> void:
	if _cam == null or strength <= 0.001:
		_have_prev = false
		return
	var now := _cam.get_camera_transform()
	if not _have_prev or get_tree().paused:
		_prev = now
		_have_prev = true
	var frame_scale := clampf((1.0 / 60.0) / maxf(delta, 0.0001), 0.25, 2.0)
	# the largest screen motion this frame, as an angle: the turn plus the move seen from 4.5 m
	# (the shader's near mask starts there), in screen heights
	# (axis deltas, not a quaternion angle: acos near 1 in single precision reads 7e-4 rad of noise)
	var turn := maxf((now.basis.z - _prev.basis.z).length(), (now.basis.x - _prev.basis.x).length())
	var ang := turn + _prev.origin.distance_to(now.origin) / 4.5
	var screen := ang / deg_to_rad(maxf(_cam.fov, 1.0))
	var rows := float(get_viewport().get_visible_rect().size.y) * get_viewport().scaling_3d_scale
	var moving := screen * strength * frame_scale * rows * 2.0 > STILL_PX
	if moving != _moving:
		_moving = moving
		visible = moving
	_mat.set_shader_parameter("prev_view", Projection(_prev.affine_inverse()))
	_mat.set_shader_parameter("owner_pos", now.origin)
	_mat.set_shader_parameter("frame_scale", frame_scale)
	_prev = now

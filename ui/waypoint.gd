extends Control
## The guide's waypoint (core/story/guide.gd): a painted mark hung over the place the next step is (the Keg's door, a
## cold brazier, a seal, a keeper's ring), its distance in metres under it, after WoW's tracked-quest arrow and
## Enshrouded's marker. Small and quiet: it fades out in the last few metres (the place's own mark or prompt takes
## over), never draws while the place is behind the camera or off the screen's middle (the compass strip carries the
## bearing then), and steps aside for a menu, a conversation, the loading screen and a locked-on fight. Added by ui/hud.gd (one line); polls the guide every frame (one group lookup).

const Guide := preload("res://core/story/guide.gd")
const Forge := preload("res://ui/hud_forge.gd")
const INK := Color(0.96, 0.9, 0.78)
const SIZE := 42.0
const MARGIN := Vector2(90.0, 120.0)        ## kept off the screen's edges: x, and y under the compass strip
const FOOT := 230.0                         ## and above the hotbar and the cast bar
const NEAR_OUT := 3.5                       ## gone this close (metres, flat)
const NEAR_IN := 8.0                        ## whole from here

var _alpha := 0.0
var _at := Vector2.ZERO
var _art := ""
var _dist := 0.0
var _font: Font
var _t := 0.0
var _edge := false
var _drawn := 0.0


func _ready() -> void:
	name = "Waypoint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://ui/fonts/Cinzel.ttf")


func _process(delta: float) -> void:
	_t += delta
	var want := 0.0
	var tree := get_tree()
	var g := tree.get_first_node_in_group("guide") as Guide
	var cam := get_viewport().get_camera_3d()
	var p := tree.get_first_node_in_group(Groups.PLAYER) as Player
	var zone := tree.current_scene
	var hidden := tree.paused or (zone != null and zone.get_node_or_null("LoadingScreen") != null)
	if g != null and cam != null and p != null and not hidden and p.lock_target() == null:
		var st := g.step()
		var t: Vector3 = st.get("target", Vector3.INF)
		if t != Vector3.INF and not cam.is_position_behind(t):
			_art = String(st.get("art", "quest_target"))
			_dist = Vector2(t.x - p.global_position.x, t.z - p.global_position.z).length()
			var vp := get_viewport_rect().size
			var cam_vp := Vector2(cam.get_viewport().get_visible_rect().size)
			var at := cam.unproject_position(t) * (vp / cam_vp if cam_vp.x > 0.0 else Vector2.ONE)
			var lo := Vector2(MARGIN.x, MARGIN.y)
			var hi := Vector2(vp.x - MARGIN.x, vp.y - FOOT)
			var clamped := at.clamp(lo, hi)
			_edge = not clamped.is_equal_approx(at)
			_at = clamped
			# off the screen's middle the mark goes (the compass strip carries the bearing): pinned to an edge it sat
			# under the unit frames and the tracker
			want = 0.0 if _edge else smoothstep(NEAR_OUT, NEAR_IN, _dist)
	_alpha = move_toward(_alpha, want, delta * (3.0 if want > _alpha else 5.0))
	if _alpha > 0.0 or _drawn > 0.0:
		_drawn = _alpha
		queue_redraw()                         # an unseen waypoint is not redrawn


func _draw() -> void:
	if _alpha <= 0.01 or _art == "":
		return
	var bob := sin(_t * 2.2) * 2.0
	var c := _at + Vector2(0.0, bob)
	# a soft dark pool behind the mark, so it reads on a lit wall and on the night sky alike, and a slow lantern breath round it
	draw_circle(c, SIZE * 0.66, Color(0.02, 0.015, 0.01, 0.32 * _alpha))
	var glow := 0.5 + 0.5 * sin(_t * 2.2 + 1.2)
	draw_arc(c, SIZE * 0.58 + 2.0 * glow, 0.0, TAU, 40, Color(1.0, 0.7, 0.32, (0.22 + 0.18 * glow) * _alpha), 2.0, true)
	if not IconArt.draw_mark(self, "mark", _art, c, SIZE, Color(1, 1, 1, _alpha)):
		draw_circle(c, SIZE * 0.3, Color(1.0, 0.72, 0.3, _alpha))
	var text := "%d m" % roundi(_dist)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	Forge.label(self, _font, c + Vector2(-w * 0.5, SIZE * 0.5 + 18.0), text, 17, Color(INK.r, INK.g, INK.b, _alpha), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)

extends Control
## The tracked task's one waypoint (core/story/quest_track.gd), Destiny 2's way (Luke, 17 Nov): a single painted mark,
## the same one the whole way, with the metres to the place under it (as the compass strip counts them). While the way bends it hangs over the next bend
## (core/story/quest_trail.gd says where, from the route along the roads and the navigation mesh) and moves on as you
## round it; on the last straight it hangs over the place itself (the Keg's door, a cold brazier, a seal, a keeper's
## ring, the person or the thing a task wants). It reads from a few metres to the far side of the Realm (~500 m), and
## goes in the last few metres (the place's own mark or prompt takes over). Behind the camera or off the screen it is
## not drawn (the compass strip carries the bearing); on the screen it is kept inside the HUD's frame. It steps aside
## for a menu, a conversation, the loading screen and a locked-on fight, never for a banner (it draws over one). Added by ui/hud.gd (one line); polls the
## tracker and the trail every frame (two group lookups).

const QuestTrack := preload("res://core/story/quest_track.gd")
const QuestTrail := preload("res://core/story/quest_trail.gd")
const Forge := preload("res://ui/hud_forge.gd")
const INK := Color(0.96, 0.9, 0.78)
const SIZE := 50.0                          ## 42 read small at 100 m and past (walk stills)
const SAFE := Vector2(70.0, 96.0)           ## kept this far inside the screen's edges: x, and y under the compass strip
const FOOT := 170.0                         ## and above the hotbar and the cast bar
const NEAR_OUT := 3.5                       ## gone this close to the place (metres, flat)
const NEAR_IN := 7.0                        ## whole from here
const UPDOWN := 4.0                         ## an arrow above or below the mark when its point is this far over or under you
const HOP := 1.5                            ## the point moved this far (the next bend): the mark dips out and back

var _alpha := 0.0
var _at := Vector2.ZERO
var _art := ""
var _dist := 0.0
var _font: Font
var _t := 0.0
var _drawn := 0.0
var _pt := Vector3.INF                      ## the world point the mark is drawn over
var _next := Vector3.INF                    ## the point it is moving to (after a dip)
var _dy := 0.0                              ## the point's height over the wanderer's eyes


func _ready() -> void:
	name = "Waypoint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5                                 # over the "Next" banner and the prompts, under the menus (their own layers)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://ui/fonts/Cinzel.ttf")


func _process(delta: float) -> void:
	_t += delta
	var want := 0.0
	var tree := get_tree()
	var tr := tree.get_first_node_in_group("quest_track") as QuestTrack
	var trail := tree.get_first_node_in_group("quest_trail") as QuestTrail
	var cam := get_viewport().get_camera_3d()
	var p := tree.get_first_node_in_group(Groups.PLAYER) as Player
	var zone := tree.current_scene
	var hidden := tree.paused or (zone != null and zone.get_node_or_null("LoadingScreen") != null) or (trail != null and trail.quiet)
	if tr != null and cam != null and p != null and not hidden and p.lock_target() == null:
		var st := tr.current()
		var t: Vector3 = st.get("target", Vector3.INF)
		if t != Vector3.INF:
			_art = String(st.get("art", "followed"))
			var straight := Vector2(t.x - p.global_position.x, t.z - p.global_position.z).length()
			var g: Vector3 = trail.guide if trail != null else Vector3.INF
			_next = t if g == Vector3.INF else g
			_dist = straight                        # to the place, as the compass strip counts it (one number on the HUD)
			if _pt == Vector3.INF or _alpha <= 0.02:
				_pt = _next                         # unseen: it moves at once
			want = smoothstep(NEAR_OUT, NEAR_IN, straight)
			if _pt.distance_to(_next) > HOP:
				want = 0.0                          # on to the next bend: out here, in there
			elif _pt != _next:
				_pt = _next                         # a small shift (the place's own mark drifting) follows quietly
			_dy = _pt.y - (p.global_position.y + 1.6)
			if cam.is_position_behind(_pt):
				want = 0.0
			else:
				var vp := get_viewport_rect().size
				var cam_vp := Vector2(cam.get_viewport().get_visible_rect().size)
				var at := cam.unproject_position(_pt) * (vp / cam_vp if cam_vp.x > 0.0 else Vector2.ONE)
				if at.x < 0.0 or at.y < 0.0 or at.x > vp.x or at.y > vp.y:
					want = 0.0                      # off the screen: the compass strip carries the bearing
				else:
					_at = at.clamp(SAFE, Vector2(vp.x - SAFE.x, vp.y - FOOT))   # on it: kept inside the HUD's frame
				# (it no longer waits under a "Next" banner: straight ahead is where the banner is, and the mark hid
				# there for the banner's whole stay; it draws over the banner instead, z_index)
	_alpha = move_toward(_alpha, want, delta * (3.0 if want > _alpha else 6.0))
	if _alpha > 0.0 or _drawn > 0.0:
		_drawn = _alpha
		queue_redraw()                         # an unseen waypoint is not redrawn


func _draw() -> void:
	if _alpha <= 0.01 or _art == "":
		return
	var bob := sin(_t * 2.2) * 2.0
	var c := _at + Vector2(0.0, bob)
	var glow := 0.5 + 0.5 * sin(_t * 2.2 + 1.2)
	# a soft dark pool behind the mark, so it reads on a lit wall and on the night sky alike, and a slow lantern breath round it
	draw_circle(c, SIZE * 0.66, Color(0.02, 0.015, 0.01, 0.45 * _alpha))
	draw_arc(c, SIZE * 0.7 + 3.0 * glow, 0.0, TAU, 40, Color(1.0, 0.7, 0.3, 0.18 * _alpha), 6.0, true)
	draw_arc(c, SIZE * 0.58 + 2.0 * glow, 0.0, TAU, 40, Color(1.0, 0.8, 0.42, (0.7 + 0.3 * glow) * _alpha), 3.0, true)
	if not IconArt.draw_mark(self, "mark", _art, c, SIZE, Color(1, 1, 1, _alpha)):
		draw_circle(c, SIZE * 0.3, Color(1.0, 0.72, 0.3, _alpha))
	if absf(_dy) > UPDOWN:                      # Destiny's inset arrow: the point is well above or below
		var s := SIZE * 0.2
		var dir := -1.0 if _dy > 0.0 else 1.0
		var tip := c + Vector2(0.0, dir * (SIZE * 0.66 + s * 1.4))
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s, -dir * s), tip + Vector2(s, -dir * s)]), Color(1.0, 0.82, 0.45, _alpha))
	var text := "%d m" % roundi(_dist)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	Forge.label(self, _font, c + Vector2(-w * 0.5, SIZE * 0.5 + 18.0), text, 17, Color(INK.r, INK.g, INK.b, _alpha), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)

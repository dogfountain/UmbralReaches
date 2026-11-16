extends Node3D
## The trail (docs/quest_trail.md): a few painted diamonds floating over the way to the tracked task's place, a handful
## ahead of the wanderer, never a line. Like Destiny 2's waypoint diamonds (Luke, 16 Nov: "ground markers make no sense,
## you can't see them at all"): drawn on the HUD over points of the route, seen through walls, grass and hills, the
## nearest with its distance, a chevron when the point is well above or below. One per night, a child of the story director (story.gd), group "quest_trail".
##   - the route: from the wanderer to the tracked step's foot point (quest_track.gd). The ways first: on to the nearest
##     road or lane, along it (TrailRoute: an A* over RealmLayout.PATHS and the walkway lanes), off at the one nearest
##     the place; the legs on and off by the navigation mesh (asked asynchronously, one query each) or straight, and the
##     mesh's own path (or a straight line, with the mesh still baking) where the ways would not help. Rebuilt only when
##     the followed step or its place changes, the place moves more than MOVED m, the wanderer strays STRAY m off the
##     route, or the mesh came in; at most every REBUILD_GAP seconds. Nothing searches per frame.
##   - the marks: every SPACING m along it and at its turns; AHEAD m of them shown at most MAX_SHOWN at a time, each a
##     pooled slot (POOL of them) that fades in as it comes into reach and out once passed. A mark is seated once, on
##     the surface under it nearest the height of the way (terrain, floors, decks: the rays pick among the hits), and
##     hangs HOVER m over it; one Control on its own CanvasLayer under the HUD draws them all (painted icon, a soft dark
##     pool behind it, a slow lantern breath, a gentle bob), redrawn only while one shows.
##   - quiet: nothing in a fight, a lock-on, a conversation, narration, a menu, the loading screen or the staged
##     opening; none in the last few metres (the waypoint and the place's own prompt take over).
## Load by path: const QuestTrail := preload("res://core/story/quest_trail.gd")

const TrailRoute := preload("res://core/story/trail_route.gd")
const TextDirector := preload("res://ui/text_director.gd")
const Hud := preload("res://ui/hud.gd")
const RealmLayout := preload("res://core/world/realm/realm_layout.gd")
const QuestTrack := preload("res://core/story/quest_track.gd")
const Forge := preload("res://ui/hud_forge.gd")

const SPACING := 13.0              ## metres between two marks
const TURN := 0.6                  ## a bend sharper than this (radians over ~12 m) gets a mark of its own
const AHEAD := 46.0                ## marks this far along the route from the wanderer are shown
const AHEAD_FAST := 72.0           ## ... a rider's (or a sprinter's) reach
const MAX_SHOWN := 4
const POOL := 6
const DENSE := 3.0                 ## the route resampled this finely (progress, turns, marks)
const STRAY := 14.0                ## further than this off the route, it is made again
const MOVED := 8.0                 ## the place moved this much: made again
const REBUILD_GAP := 1.5
const END_QUIET := 7.0             ## no mark this close to the place
const HOVER := 1.6                 ## the diamond's point over the seat (chest height)
const PX_NEAR := 40.0              ## its size on screen near ... (30/16 read small and dim at night: walk stills)
const PX_FAR := 24.0               ## ... and AHEAD m out
const UPDOWN := 3.0                ## a chevron when the point is this far above or below the wanderer
const INK := Color(0.96, 0.9, 0.78)
const FADE_IN := 2.2
const FADE_OUT := 1.6
const MAX_A := 0.95

var _track: QuestTrack
var _ways := TrailRoute.new()
var _pos: Array[Vector3] = []                            ## slot -> the diamond's world point
var _slot: PackedInt32Array = PackedInt32Array()         ## slot -> mark index (-1: free)
var _layer: CanvasLayer
var _ink: Control
var _font: Font
var _t := 0.0
var _drawn := false
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _want: PackedFloat32Array = PackedFloat32Array()     ## the alpha each slot is heading for
# the route, resampled every DENSE metres (xz, height or NAN, arc length)
var _rp := PackedVector2Array()
var _ry := PackedFloat32Array()
var _rs := PackedFloat32Array()
# its marks
var _ms := PackedFloat32Array()                          ## arc length
var _mp := PackedVector2Array()
var _my := PackedFloat32Array()                          ## seated height (NAN: not yet)
var _idx := -1                                           ## the dense point nearest the wanderer
var _sp := 0.0                                           ## the wanderer's progress along the route (m)
var _off := 0.0                                          ## and how far off it
var _poll := 0.0
var _gap := 0.0
var _dirty := true
var _goal := Vector3.INF                                 ## the place the route was made for
var _key := ""
var _req := 0                                            ## the route being made (async legs answer to it)
var _legs: Array = []                                    ## [{type, a, b, pts}] while the route is being made
var _pending := 0
var _wait := 0.0
var _wants_nav := false                                  ## made without the mesh: made again when it is in
var _hidden := true
var shown := 0                                           ## marks showing now (tests)


func _ready() -> void:
	name = "QuestTrail"
	add_to_group("quest_trail")
	top_level = true
	_font = load("res://ui/fonts/Cinzel.ttf")
	_layer = CanvasLayer.new()
	_layer.name = "TrailMarks"
	_layer.layer = 9                               # under the HUD (10): its panels and banners draw over a diamond
	add_child(_layer)
	_ink = Control.new()
	_ink.name = "Ink"
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ink.draw.connect(_draw_marks)
	_layer.add_child(_ink)
	for i in POOL:
		_pos.append(Vector3.ZERO)
		_slot.append(-1)
		_alpha.append(0.0)
		_want.append(0.0)


func _find_track() -> void:
	if _track == null or not is_instance_valid(_track):
		_track = get_tree().get_first_node_in_group("quest_track") as QuestTrack
		if _track != null:
			_track.changed.connect(func() -> void: _dirty = true)


func _process(delta: float) -> void:
	_t += delta
	_poll -= delta
	_gap -= delta
	if _pending > 0:
		_wait += delta
	if _poll <= 0.0:
		_poll = 0.2
		_tick()
	# fade the slots toward what the poll set; redraw only while a diamond shows (or the last one just went)
	var any := false
	for i in POOL:
		if absf(_alpha[i] - _want[i]) > 0.002:
			_alpha[i] = move_toward(_alpha[i], _want[i], delta * (FADE_IN if _want[i] > _alpha[i] else FADE_OUT) * MAX_A)
		if _alpha[i] <= 0.002 and _want[i] <= 0.0:
			_slot[i] = -1
		elif _slot[i] >= 0:
			any = true
	if any or _drawn:
		_drawn = any
		_ink.queue_redraw()


## The diamonds, on the HUD over their points (Destiny 2's waypoint diamonds): the painted trail icon on a soft dark
## pool with a slow lantern breath, sized by distance, the nearest with its distance, a chevron when the point is well
## above or below the wanderer. Off-screen and behind-camera points are not drawn (the compass carries the bearing).
func _draw_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if cam == null or p == null:
		return
	var vp := _ink.get_viewport_rect().size
	var cam_vp := Vector2(cam.get_viewport().get_visible_rect().size)
	var k := vp / cam_vp if cam_vp.x > 0.0 else Vector2.ONE
	var nearest := -1
	var nearest_d := INF
	var label_at := Vector2.ZERO
	var label_size := 0.0
	for i in POOL:
		var a := _alpha[i]
		if _slot[i] < 0 or a <= 0.01 or cam.is_position_behind(_pos[i]):
			continue
		var at := cam.unproject_position(_pos[i]) * k
		if at.x < -40.0 or at.y < -40.0 or at.x > vp.x + 40.0 or at.y > vp.y + 40.0:
			continue
		var d := cam.global_position.distance_to(_pos[i])
		var size := lerpf(PX_NEAR, PX_FAR, clampf((d - 6.0) / AHEAD, 0.0, 1.0))
		var c := at + Vector2(0.0, sin(_t * 2.2 + float(i)) * 2.0)
		_ink.draw_circle(c, size * 0.64, Color(0.02, 0.015, 0.01, 0.42 * a))
		var glow := 0.5 + 0.5 * sin(_t * 2.2 + float(i) + 1.2)
		_ink.draw_arc(c, size * 0.58 + 1.5 * glow, 0.0, TAU, 36, Color(1.0, 0.76, 0.36, (0.55 + 0.3 * glow) * a), 2.5, true)
		if not IconArt.draw_mark(_ink, "trail", "step", c, size, Color(1, 1, 1, a)):
			_ink.draw_circle(c, size * 0.28, Color(1.0, 0.72, 0.3, a))
		var dy := _pos[i].y - HOVER - p.global_position.y
		if absf(dy) > UPDOWN:
			var s := size * 0.22
			var tip := c + Vector2(0.0, (-size * 0.62 - s) if dy > 0.0 else (size * 0.62 + s))
			var dir := -1.0 if dy > 0.0 else 1.0
			_ink.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, dir * s), tip + Vector2(-s, -dir * s * 0.4), tip + Vector2(s, -dir * s * 0.4)]), Color(1.0, 0.78, 0.4, a))
		var fd := Vector2(_pos[i].x - p.global_position.x, _pos[i].z - p.global_position.z).length()
		if fd < nearest_d:                          # the nearest diamond actually drawn carries the distance
			nearest_d = fd
			nearest = i
			label_at = c
			label_size = size
	if nearest >= 0:
		var text := "%d m" % roundi(nearest_d)
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		Forge.label(_ink, _font, label_at + Vector2(-w * 0.5, label_size * 0.5 + 15.0), text, 14, Color(INK.r, INK.g, INK.b, _alpha[nearest] * 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)


# --- the poll ---------------------------------------------------------------------------------------------------

func _tick() -> void:
	_find_track()
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if _track == null or p == null:
		_release_all()
		return
	var c := _track.current()
	var foot: Vector3 = c.get("foot", Vector3.INF)
	_hidden = _quiet(p)
	if foot == Vector3.INF:
		_clear()
		_release_all()
		return
	var here := p.global_position
	# is the route still the right one?
	var stale := _dirty or _goal == Vector3.INF or Vector2(foot.x - _goal.x, foot.z - _goal.z).length() > MOVED
	if not stale and not _rp.is_empty() and _off > STRAY:
		stale = true
	if not stale and _wants_nav and NavAssist.ready():
		stale = true
	if not stale and _rp.is_empty() and _pending == 0 and Vector2(foot.x - here.x, foot.z - here.z).length() > END_QUIET + 8.0:
		stale = true                                # it was there; the wanderer has walked off from it
	if _pending > 0 and _wait > 3.0:
		_finish_legs(true)                          # the mesh did not answer: the legs go straight
	if stale and _gap <= 0.0 and _pending == 0:
		_build(here, foot)
	if _rp.is_empty():
		_release_all()
		return
	_progress(here)
	_assign(here, p)


## Quiet while anything else has the screen (or the wanderer's mind).
func _quiet(p: Player) -> bool:
	var tree := get_tree()
	if tree.paused or p.lock_target() != null:
		return true
	var zone := tree.current_scene
	if zone != null and zone.get_node_or_null("LoadingScreen") != null:
		return true
	var hud := tree.get_first_node_in_group(&"hud") as Hud
	if hud != null and not hud.staged_in():
		return true
	var td := TextDirector.of(self)
	return td != null and (td.in_combat() or td.narration_or_dialogue())


# --- the route --------------------------------------------------------------------------------------------------

func _clear() -> void:
	_req += 1
	_pending = 0
	_legs.clear()
	_rp = PackedVector2Array()
	_ry = PackedFloat32Array()
	_rs = PackedFloat32Array()
	_ms = PackedFloat32Array()
	_mp = PackedVector2Array()
	_my = PackedFloat32Array()
	_goal = Vector3.INF
	_idx = -1
	_off = 0.0
	_dirty = false


func _build(here: Vector3, foot: Vector3) -> void:
	_clear()
	_gap = REBUILD_GAP
	_goal = foot
	_wants_nav = false
	var from := Vector2(here.x, here.z)
	var to := Vector2(foot.x, foot.z)
	var straight := from.distance_to(to)
	if straight < END_QUIET + 4.0:
		return                                      # there
	var legs: Array = []
	var r: Dictionary = _ways.route(from, to) if straight > 40.0 else {}
	if not r.is_empty():
		var total := float(r.entry) + float(r.length) + float(r.exit)
		if float(r.entry) > 120.0 or float(r.exit) > 150.0 or total > straight * 2.0 + 80.0:
			r = {}
	if r.is_empty():
		legs.append({"type": "nav", "a": here, "b": foot})
	else:
		var way: PackedVector2Array = r.pts
		if float(r.entry) > 4.0:
			legs.append({"type": "nav" if float(r.entry) > 14.0 else "line", "a": here, "b": Vector3(way[0].x, NAN, way[0].y)})
		var wp := PackedVector3Array()
		for q in way:
			wp.append(Vector3(q.x, NAN, q.y))
		legs.append({"type": "ways", "pts": wp})
		if float(r.exit) > 4.0:
			var last := way[way.size() - 1]
			legs.append({"type": "nav" if float(r.exit) > 14.0 else "line", "a": Vector3(last.x, NAN, last.y), "b": foot})
	_legs = legs
	_pending = 0
	_wait = 0.0
	var req := _req
	for i in legs.size():
		var leg: Dictionary = legs[i]
		if String(leg.type) != "nav":
			continue
		if not NavAssist.ready():
			_wants_nav = true
			leg["type"] = "line"
			continue
		var a: Vector3 = leg.a
		var b: Vector3 = leg.b
		var q := NavigationPathQueryParameters3D.new()
		q.map = NavAssist.map
		q.start_position = Vector3(a.x, RealmLayout.macro_height(a.x, a.z) if is_nan(a.y) else a.y, a.z)
		q.target_position = Vector3(b.x, RealmLayout.macro_height(b.x, b.z) if is_nan(b.y) else b.y, b.z)
		q.path_search_max_polygons = NavAssist.MAX_POLYS
		var res := NavigationPathQueryResult3D.new()
		_pending += 1
		NavigationServer3D.query_path(q, res, func() -> void: _leg_done.call_deferred(req, i, res))
	if _pending == 0:
		_finish_legs(false)


func _leg_done(req: int, i: int, res: NavigationPathQueryResult3D) -> void:
	if req != _req or i >= _legs.size():
		return
	(_legs[i] as Dictionary)["pts"] = res.path
	_pending -= 1
	if _pending <= 0:
		_finish_legs(false)


## Every leg is in: join them, resample, lay the marks.
func _finish_legs(timed_out: bool) -> void:
	_pending = 0
	var pts := PackedVector3Array()
	for leg: Dictionary in _legs:
		var seg := PackedVector3Array()
		match String(leg.type):
			"ways":
				seg = leg.pts
			"nav":
				var np: PackedVector3Array = leg.get("pts", PackedVector3Array()) if not timed_out else PackedVector3Array()
				var b: Vector3 = leg.b
				# the mesh's answer is used when it got there; else the leg goes straight
				if np.size() >= 2 and Vector2(np[np.size() - 1].x - b.x, np[np.size() - 1].z - b.z).length() < 18.0:
					seg = np
				else:
					seg = PackedVector3Array([leg.a, b])
			_:
				seg = PackedVector3Array([leg.a, leg.b])
		for q in seg:
			if pts.is_empty() or Vector2(pts[pts.size() - 1].x - q.x, pts[pts.size() - 1].z - q.z).length() > 0.5:
				pts.append(q)
	_legs.clear()
	_dirty = false
	if pts.size() < 2:
		return
	_resample(pts)
	_lay_marks()
	_idx = -1
	_off = 0.0


func _resample(pts: PackedVector3Array) -> void:
	_rp = PackedVector2Array()
	_ry = PackedFloat32Array()
	_rs = PackedFloat32Array()
	var s := 0.0
	_rp.append(Vector2(pts[0].x, pts[0].z))
	_ry.append(pts[0].y)
	_rs.append(0.0)
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := Vector2(b.x - a.x, b.z - a.z).length()
		var n := maxi(1, int(ceilf(seg / DENSE)))
		for k in range(1, n + 1):
			var t := float(k) / float(n)
			_rp.append(Vector2(lerpf(a.x, b.x, t), lerpf(a.z, b.z, t)))
			_ry.append(lerpf(a.y, b.y, t) if not is_nan(a.y) and not is_nan(b.y) else (b.y if k == n else a.y))
			_rs.append(s + seg * t)
		s += seg


func _lay_marks() -> void:
	_ms = PackedFloat32Array()
	_mp = PackedVector2Array()
	_my = PackedFloat32Array()
	var total := _rs[_rs.size() - 1]
	var next_s := 8.0
	var last_s := -99.0
	for i in _rp.size():
		var s := _rs[i]
		if s > total - END_QUIET:
			break
		var turn := false
		if i >= 2 and i < _rp.size() - 2 and s - last_s >= 6.0:
			var d1 := (_rp[i] - _rp[i - 2]).normalized()
			var d2 := (_rp[i + 2] - _rp[i]).normalized()
			turn = absf(d1.angle_to(d2)) > TURN
		if s >= next_s or turn:
			_ms.append(s)
			_mp.append(_rp[i])
			_my.append(NAN)
			last_s = s
			next_s = s + SPACING


## Where the wanderer is along the route: the dense point nearest, looked for near the last one.
func _progress(here: Vector3) -> void:
	var at := Vector2(here.x, here.z)
	var lo := 0
	var hi := _rp.size() - 1
	if _idx >= 0:
		lo = maxi(0, _idx - 8)
		hi = mini(_rp.size() - 1, _idx + 40)
	var best := INF
	var bi := maxi(_idx, 0)
	for i in range(lo, hi + 1):
		var d := at.distance_squared_to(_rp[i])
		if d < best:
			best = d
			bi = i
	_idx = bi
	_sp = _rs[bi]
	_off = sqrt(best)


# --- the marks ---------------------------------------------------------------------------------------------------

func _assign(here: Vector3, p: Player) -> void:
	var reach := AHEAD_FAST if p.velocity.length() > 7.0 else AHEAD
	var wanted: Array[int] = []
	if not _hidden:
		for m in _ms.size():
			if _ms[m] < _sp - 2.5:
				continue
			if _ms[m] > _sp + reach or wanted.size() >= MAX_SHOWN:
				break
			wanted.append(m)
	# a slot showing a mark no longer wanted lets it go; wanted marks without one take a free slot
	var have := {}
	for i in POOL:
		var m := _slot[i]
		if m >= 0 and m in wanted:
			_want[i] = MAX_A
			have[m] = true
		elif m >= 0:
			_want[i] = 0.0
	shown = have.size()
	for m: int in wanted:
		if have.has(m):
			continue
		var free := -1
		for i in POOL:
			if _slot[i] < 0:
				free = i
				break
		if free < 0:
			break
		_put(free, m, here)
		have[m] = true
		shown += 1


func _put(i: int, m: int, here: Vector3) -> void:
	if is_nan(_my[m]):
		_my[m] = _seat(m, here)
	_slot[i] = m
	_pos[i] = Vector3(_mp[m].x, _my[m] + HOVER, _mp[m].y)
	_alpha[i] = 0.0
	_want[i] = MAX_A


## The surface a mark stands on: of the WORLD hits straight down at its place, the walkable one nearest the height of the
## way (the one before it, the mesh's own height, else the wanderer's): terrain in the open, the deck of a bridge, the
## floor under a roof.
func _seat(m: int, here: Vector3) -> float:
	var ref := here.y
	var k := RealmLayout.macro_height(_mp[m].x, _mp[m].y)
	var ry := _ry[_dense_of(m)]
	if not is_nan(ry):
		ref = ry
	else:
		for j in range(m - 1, -1, -1):
			if not is_nan(_my[j]):
				ref = _my[j]
				break
		if absf(ref - here.y) > 40.0:
			ref = k
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return ref
	var best := NAN
	var best_d := INF
	var first := NAN
	var top := 80.0
	var skip: Array[RID] = []
	for _n in 5:
		var q := PhysicsRayQueryParameters3D.create(Vector3(_mp[m].x, top, _mp[m].y), Vector3(_mp[m].x, -50.0, _mp[m].y), Layers.WORLD)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var y: float = (hit.position as Vector3).y
		if is_nan(first):
			first = y
		if (hit.normal as Vector3).y > 0.55 and absf(y - ref) < best_d:
			best_d = absf(y - ref)
			best = y
		skip.append(hit.rid)
		top = y - 0.05
	if not is_nan(best):
		return best
	return first if not is_nan(first) else (ref if not is_nan(ry) else k)


func _dense_of(m: int) -> int:
	var lo := 0
	var hi := _rs.size() - 1
	while lo < hi:
		var mid := (lo + hi) >> 1
		if _rs[mid] < _ms[m]:
			lo = mid + 1
		else:
			hi = mid
	return lo


## Let every mark go (nothing to follow, or quiet): they fade out and the slots are free again.
func _release_all() -> void:
	shown = 0
	for i in POOL:
		_want[i] = 0.0

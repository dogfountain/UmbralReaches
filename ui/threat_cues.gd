extends Control
## Off-screen threat cues (God of War 2018's edge marks, in the game's own painted kit): a foe that is winding up on
## the wanderer OUT OF VIEW gets a small painted coin at the edge of the screen, turned toward it on the ground's
## compass (up is ahead, down is behind you), swelling and brightening as its tell fills, gone the moment the blow
## lands or breaks. The ground's red is the truth for a tell you can see; this is for the flanker at your back, the
## Gaunt on your off-side, the leaper coiling behind, the caster out to the side.
##   ember   (ui/icons/hud/threat_melee)   a rake, a slam, a pounce, a charge or a dart coming in
##   teal    (ui/icons/hud/threat_ranged)  a spit, a thrown rib, a lob or a working cast from a foe that never closes
## Nothing shows while every threat is on screen. At most MAX marks, the most urgent first. Foes within REACH only.
## Reads the awake foes (FoeIndex, no scan of the whole group); no per-frame allocation once warm. Added by ui/hud.gd.

const FoeIndex := preload("res://core/enemy/foe_index.gd")
const Access := preload("res://ui/access.gd")
const REACH := 20.0
const MAX := 4
const SIZE := 44.0
const EDGE := Vector2(0.43, 0.40)       ## the ellipse the marks ride on, as a share of the screen's width and height
const MELEE_COL := Color(1.0, 0.86, 0.78)
const RANGED_COL := Color(0.86, 1.0, 0.96)

var _tex_melee: Texture2D
var _tex_ranged: Texture2D
var _n := 0                              ## marks this frame
var _pos := PackedVector2Array()
var _ang := PackedFloat32Array()
var _k := PackedFloat32Array()           ## how far its tell has filled (0..1)
var _ranged := PackedByteArray()
var _was := 0
var _t := 0.0


func _ready() -> void:
	name = "ThreatCues"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_melee = IconArt.art("hud", "threat_melee")
	_tex_ranged = IconArt.art("hud", "threat_ranged")
	_pos.resize(MAX)
	_ang.resize(MAX)
	_k.resize(MAX)
	_ranged.resize(MAX)


func _process(delta: float) -> void:
	_t += delta
	_was = _n
	_n = 0
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	var cam := get_viewport().get_camera_3d()
	if p != null and cam != null and is_visible_in_tree() and not p.is_hollowing():
		_gather(p, cam)
	if _n > 0 or _was > 0:
		queue_redraw()


## Every awake foe near the wanderer whose tell is filling and who stands outside the view.
func _gather(p: Player, cam: Camera3D) -> void:
	var fi := FoeIndex.of(get_tree()) as FoeIndex
	var at := p.global_position
	var view := get_viewport_rect().size
	for i in fi.near(get_tree(), at, REACH):
		var e := fi.node(i) as Enemy
		if e == null or not is_instance_valid(e) or not e.is_alive() or e.is_evading() or e.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var k := _tell(e)
		if k < 0.0:
			continue
		var c := e.global_position + Vector3.UP * minf(e.hp_bar_y * 0.5, 2.0)
		if c.distance_to(at) > REACH:
			continue
		if not cam.is_position_behind(c):
			var sp := cam.unproject_position(c)
			if sp.x >= 0.0 and sp.y >= 0.0 and sp.x <= view.x and sp.y <= view.y:
				continue                          # in view: the foe and its red speak for themselves
		var local := cam.global_basis.inverse() * (c - cam.global_position)
		var dir := Vector2(local.x, local.z)      # the ground's compass: ahead is up the screen, behind is down
		if dir.length_squared() < 0.0001:
			continue
		dir = dir.normalized()
		_add(view * 0.5 + dir * view * EDGE, atan2(dir.y, dir.x) + PI * 0.5, k, e.strike_range <= 0.0)


## How far a foe's tell aimed at the wanderer has filled (0..1), or -1 when it has none: a windup, a coiled pounce or
## the flight, a move of its own with a tell on the ground (a slam, a charge's lane, a dart), a ranged foe's draw.
func _tell(e: Enemy) -> float:
	match e._state:
		Enemy.WINDUP:
			return clampf(e._state_t / maxf(e._cur_windup, 0.05), 0.0, 1.0)
		Enemy.LEAP_PREP:
			return clampf(e._state_t / maxf(e.leap_prep, 0.05), 0.0, 1.0)
		Enemy.AIRBORNE:
			return 1.0
		Enemy.SPECIAL:
			return clampf(0.5 + e._state_t, 0.5, 1.0) if not e._moves.is_empty() else -1.0
	if e.casting() and not e._moves.is_empty():
		return e.cast_progress()
	return -1.0


func _add(pos: Vector2, ang: float, k: float, ranged: bool) -> void:
	var slot := _n
	if _n >= MAX:
		# full: the least filled gives way
		slot = 0
		for j in range(1, MAX):
			if _k[j] < _k[slot]:
				slot = j
		if _k[slot] >= k:
			return
	else:
		_n += 1
	_pos[slot] = pos
	_ang[slot] = ang
	_k[slot] = k
	_ranged[slot] = 1 if ranged else 0


func _draw() -> void:
	for i in _n:
		var tex := _tex_ranged if _ranged[i] == 1 else _tex_melee
		if tex == null:
			continue
		var k := _k[i]
		var urgent := smoothstep(0.75, 1.0, k)
		var beat := 0.5 + 0.5 * sin(_t * 26.0)
		var s := SIZE * (0.82 + 0.32 * k + 0.1 * urgent * beat * Access.flash())
		var col := RANGED_COL if _ranged[i] == 1 else MELEE_COL
		col.a = clampf(0.55 + 0.45 * k, 0.0, 1.0)
		draw_set_transform(_pos[i], _ang[i], Vector2.ONE)
		draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

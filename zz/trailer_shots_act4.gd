extends RefCounted
## Act IV shots (descend) and the finale: the five bosses in their real arenas (reveal, a signature move, a phase
## change each), the killing blow, the last card. `d` is the director (zz/trailer.gd). The bosses are the game's own:
## kit.begin() finds the BossArena, warms the boss (BossKit.warm / warm_rig) and holds its pull; kit.pull() is the
## arena's own _begin (room, gate, intro, bar), and a move is a call to the boss's own method. Boss shots are data
## (BOSS below) plus a short event script per shot (_events).

const Cam := preload("res://zz/trailer_cam.gd")
const Kit := preload("res://zz/trailer_act4_kit.gd")
## id -> {boss, W: wanderer's distance from the boss (towards the arena's middle), pre: boss already up and ready,
##        cam: [d0, d1, side0, side1, h0, h1, look height] relative to the boss on the wanderer's side,
##        fov, lit: [energy, range] of the fill light, top: top-down height (TOP shots)}
const BOSS := {
	"thorn_reveal": {"boss": "thornwarden", "W": 11.0, "pre": false, "cam": [9.5, 0, 4.5, 0, 3.4, 0, 3.4], "push": 3.0, "fov": 55.0, "lit": [5.0, 40.0]},
	"thorn_move": {"boss": "thornwarden", "W": 12.0, "pre": true, "cam": [13.0, 0, 11.0, 0, 6.0, 0, 1.5], "push": 1.5, "fov": 60.0, "lit": [5.0, 40.0]},
	"thorn_knots": {"boss": "thornwarden", "W": 8.0, "pre": true, "knot": 60.0, "cam": [9.0, 0, -4.5, 0, 4.2, 0, 3.4], "push": 2.0, "fov": 55.0, "lit": [7.0, 40.0]},
	"boss_reveal": {"boss": "bone_abbot", "W": 9.0, "pre": false, "cam": [11.0, 0, 3.0, 0, 2.4, 0, 3.0], "ring": [70.0, 13.0], "fov": 46.0, "lit": [1.6, 24.0, 1]},
	"boss_wide": {"boss": "bone_abbot", "W": 8.0, "pre": true, "cam": [17.0, 0, 7.0, 0, 6.0, 0, 1.5], "ring": [70.0, 12.0], "push": 1.0, "fov": 60.0, "lit": [1.6, 30.0, 1]},
	"abbot_phase": {"boss": "bone_abbot", "W": 8.0, "pre": true, "cam": [15.0, 0, -5.0, 0, 3.8, 0, 3.0], "ring": [-70.0, 12.0], "push": 1.5, "fov": 58.0, "lit": [1.6, 30.0, 1]},
	"warden": {"boss": "ascended_warden", "W": 13.0, "pre": false, "cam": [19.0, 0, 4.0, 0, 1.0, 0, 6.0], "push": 3.0, "fov": 62.0, "lit": [6.0, 50.0]},
	"warden_move": {"boss": "ascended_warden", "W": 13.0, "pre": true, "cam": [21.0, 0, -8.0, 0, 9.0, 0, 5.0], "push": 2.0, "fov": 62.0, "lit": [6.0, 50.0]},
	"warden_phase": {"boss": "ascended_warden", "W": 12.0, "pre": true, "cam": [20.0, 0, 5.0, 0, 1.2, 0, 8.0], "push": 2.0, "fov": 64.0, "lit": [6.0, 50.0]},
	"anchoress": {"boss": "r37_anchoress", "W": 9.0, "pre": false, "cam": [-8.0, 0, 3.0, 0, 1.6, 0, 2.6], "push": 2.5, "fov": 52.0, "lit": [8.0, 32.0]},
	"anchoress_move": {"boss": "r37_anchoress", "W": 10.0, "pre": true, "cam": [9.0, 0, 7.5, 0, 5.0, 0, 1.0], "push": 1.5, "fov": 58.0, "lit": [8.0, 32.0]},
	"anchoress_phase": {"boss": "r37_anchoress", "W": 9.0, "pre": true, "cam": [-8.0, 0, 4.0, 0, 1.6, 0, 2.8], "push": 2.0, "fov": 56.0, "lit": [8.0, 32.0]},
	"hierarch_voice": {"boss": "r37_hierarch", "W": 11.0, "pre": true, "cam": [17.0, 0, 7.0, 0, 8.0, 0, 1.2], "push": 2.0, "fov": 58.0, "lit": [8.0, 40.0]},
	"hierarch_edict": {"boss": "r37_hierarch", "W": 12.0, "pre": true, "cam": [10.5, 0, 3.5, 0, 1.2, 0, 4.5], "push": 2.5, "fov": 56.0, "lit": [5.0, 40.0]},
	"hierarch_phase": {"boss": "r37_hierarch", "W": 12.0, "pre": true, "cam": [9.5, 0, 3.0, 0, 1.8, 0, 4.2], "push": 1.5, "fov": 52.0, "lit": [9.0, 40.0]},
	"final_blow": {"boss": "thornwarden", "W": 11.0, "pre": true, "cam": [11.0, 0, 5.0, 0, 5.0, 0, 2.8], "push": 1.5, "fov": 55.0, "lit": [5.0, 40.0]},
}

var d
var cam
var kit
var _lit_was := Vector2(3.0, 24.0)


func _init(director: Object) -> void:
	d = director
	cam = Cam.new(director)
	kit = Kit.new(director)


func handles(id: String) -> bool:
	return BOSS.has(id)


# --- cards and the finale --------------------------------------------------------------------------

func _s_card_depths() -> void:
	d._card("DESCEND", 1.0)
	d.clear_spawned()
	kit.reset_arenas()
	d.boom("lance_hit", -3.0)


func _u_card_depths(tt: float) -> void:
	d.title.modulate.a = clampf(tt / 0.2, 0.0, 1.0)


# --- the whole Realm from the air, before the title ------------------------------------------------------

const PAN_C := Vector3(0.0, 0.0, 45.0)                  ## the Realm's middle (BOUNDS x -260..260, z -150..240)
const PAN_RANGE := 3.0                                  ## every LOD and fade distance pushed out this far for the flight

var _pan_env: Environment
var _pan_fog := {}
var _pan_ranges := {}
var _pan_lod := 1.0


func _s_realm_pan() -> void:
	kit.reset_arenas()
	d.clear_spawned()
	d.put_player(d.GREEN, 0.0, 0.05)
	d.use_free_cam()
	d.cam.fov = 58.0
	d.cam.far = 1500.0                                    # the far edge is 500 m and more from the lens
	# eye-level haze (depth fog to 1 km, aerial perspective) washes 300-500 m of land to one blue-grey: thinned for the
	# flight. The weather offsets fog_depth_begin and the volumetrics each frame, not these.
	var we: Array = d.get_tree().root.find_children("*", "WorldEnvironment", true, false)
	_pan_env = (we[0] as WorldEnvironment).environment if not we.is_empty() else null
	if _pan_env:
		for k: String in ["fog_depth_end", "fog_density", "fog_aerial_perspective", "fog_depth_curve"]:
			_pan_fog[k] = _pan_env.get(k)
		_pan_env.fog_depth_end = 2600.0
		_pan_env.fog_density = 0.55
		_pan_env.fog_aerial_perspective = 0.35
		_pan_env.fog_depth_curve = 1.4
	# from 300 m every tree and roof had dropped to its far card: each instance's LOD band moves out together
	_pan_ranges.clear()
	for n in d.get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.visibility_range_end > 0.0 or g.visibility_range_begin > 0.0:
			_pan_ranges[g] = Vector2(g.visibility_range_begin, g.visibility_range_end)
			g.visibility_range_begin *= PAN_RANGE
			g.visibility_range_end *= PAN_RANGE
	_pan_lod = d.get_viewport().mesh_lod_threshold
	d.get_viewport().mesh_lod_threshold = 0.0
	# the landmark sparks grow with distance to stay a steady point from the ground; from the air they bloom into blobs
	for b in d.get_tree().get_nodes_in_group(&"landmark_beacon"):
		(b as Node3D).visible = false
	print("TRAILER realm_pan: %d ranges pushed out" % _pan_ranges.size())


## A slow arc high over the south of the Realm: the March Wall, the Crowns, the Spire, the Downs and the abbey's peak
## all in one frame, the lens swinging from the south-west to the south-east as it looks across to the mountain.
func _u_realm_pan(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 5.0, 0.0, 1.0))
	var a := lerpf(deg_to_rad(-38.0), deg_to_rad(38.0), k)
	var from := PAN_C + Vector3(sin(a) * 285.0, lerpf(135.0, 120.0, k), cos(a) * 285.0)
	d.hold_cam(from, PAN_C + Vector3(0.0, 0.0, -40.0))      # no occlusion pull: a hill between would jerk the lens


func _e_realm_pan() -> void:
	d.cam.far = 500.0
	d.cam.fov = 62.0
	if _pan_env:
		for k: String in _pan_fog:
			_pan_env.set(k, _pan_fog[k])
	for g: Variant in _pan_ranges:
		if is_instance_valid(g):
			var r: Vector2 = _pan_ranges[g]
			(g as GeometryInstance3D).visibility_range_begin = r.x
			(g as GeometryInstance3D).visibility_range_end = r.y
	_pan_ranges.clear()
	d.get_viewport().mesh_lod_threshold = _pan_lod
	for b in d.get_tree().get_nodes_in_group(&"landmark_beacon"):
		(b as Node3D).visible = true


func _s_finale() -> void:
	kit.reset_arenas()
	d.clear_spawned()
	# six metres up the green: from the old mark the near brazier blurred into an orange dome across the corner and a
	# cottage wall filled the right third as the lens tilted up
	d.put_player(d.GREEN + Vector3(0.0, 0.0, -6.0), 0.0, 0.05)
	d.use_free_cam()
	d.cam.fov = 62.0
	var ph: Node = d.life.get("phenomena") if d.life else null
	if ph:
		ph.call("trigger", "shower")
		ph.call("trigger", "bolide")


func _u_finale(tt: float) -> void:
	# the wanderer small against the valley, the camera tilting up into the vortex; the title
	var k: float = d.sm(clampf(tt / 2.2, 0.0, 1.0))
	# the lens left of the wanderer and turned a little left: the cottage on the green's east side stays out of frame
	d.frame_cam(d.pp() + Vector3(-1.0, 1.7, 3.8), d.pp() + Vector3(-lerpf(1.0, 14.0, k), lerpf(1.6, 40.0, k), -lerpf(4.0, 60.0, k)))
	d.light_at(d.pp(), 4.0)
	if tt > 1.8 and d.once("title_in"):
		d.boom("lance_hit", 0.0)
		d._card("UMBRAL REACHES", 0.0)
		d.title.modulate.a = 0.0
	if tt > 1.8:
		d.title.modulate.a = clampf((tt - 1.8) / 0.5, 0.0, 1.0)
		d.black.color.a = clampf((tt - 3.8) / 0.7, 0.0, 1.0)


# --- the Abbot on the game's own camera -------------------------------------------------------------

func _s_boss_game() -> void:
	var ar: BossArena = kit.begin("bone_abbot")
	if ar == null:
		return
	var cen := ar.global_position
	_home = cen + Cam.flat(ar.boss_at - cen).rotated(Vector3.UP, deg_to_rad(70.0)) * 13.0
	kit.stand(_home, Cam.yaw_dir(Cam.flat(ar.boss_at - _home)))
	d.use_player_cam()
	_lit_was = Vector2(3.0, 24.0)
	d.key.light_energy = 1.2
	d.key.light_color = Color(1.0, 0.78, 0.5)
	kit.pre_pull()


func _u_boss_game(tt: float) -> void:
	var b: Enemy = kit.boss()
	if b:
		d.aim_at(b.global_position)
		# round him, out of his reach, pulled back toward the middle of the hall
		var bp := b.global_position
		var away: Vector3 = d.p.global_position - bp
		away.y = 0.0
		var dist := away.length()
		away = away.normalized()
		var wish := away.cross(Vector3.UP) * 0.45
		if dist < 7.0:
			wish += away * 0.35
		var home: Vector3 = _home - d.p.global_position
		home.y = 0.0
		if home.length() > 4.0:
			wish += home.normalized() * 0.4
		d.drive(wish.limit_length(0.7))
	d.light_at(d.pp(), 5.0)
	if tt > 0.15 and d.once("bg_bolts"):
		d.press(d.slot_action(0))
	if tt > 1.5 and d.once("bg_lance"):
		d.release(d.slot_action(0))
		d.press(d.slot_action(1))
	if tt > 2.6 and d.once("bg_lance_go"):
		d.release(d.slot_action(1))


func _e_boss_game() -> void:
	kit.finish()
	d.key.light_energy = _lit_was.x
	d.key.light_color = Color(0.62, 0.72, 1.0)


# --- the boss shots --------------------------------------------------------------------------------

func _s_any(id: String) -> void:
	var cf: Dictionary = BOSS[id]
	var ar: BossArena = kit.begin(String(cf.boss))
	if ar == null:
		return
	var bat := ar.boss_at
	var to_mid := Cam.flat(ar.global_position - bat)
	if (ar.global_position - bat).length() < 2.0:
		to_mid = Vector3.BACK
	to_mid = to_mid.rotated(Vector3.UP, deg_to_rad(float(cf.get("rot", 0.0))))
	var at := bat + to_mid * float(cf.W)
	if cf.has("ring"):
		var rg: Array = cf.ring
		var cen := ar.global_position
		at = cen + Cam.flat(bat - cen).rotated(Vector3.UP, deg_to_rad(float(rg[0]))) * float(rg[1])
	print("GEOM ", id, " C=", ar.global_position, " gate=", (ar.gate.global_position if ar.gate else "-"), " boss=", bat, " stand=", at)
	kit.stand(at, Cam.yaw_dir(-to_mid))
	d.use_free_cam()
	d.cam.fov = float(cf.fov)
	_lit_was = Vector2(d.key.light_energy, d.key.omni_range)
	var lit: Array = cf.lit
	d.key.light_energy = float(lit[0])
	d.key.omni_range = float(lit[1])
	d.key.light_color = Color(1.0, 0.78, 0.5) if lit.size() > 2 else Color(0.62, 0.72, 1.0)
	if bool(cf.pre):
		var b: Enemy = kit.pre_pull()
		if b == null:
			print("TRAILER no boss for ", id)
	d.flags.erase("a4_%s" % id)
	d.flags.erase("a4_knot_hit")
	if cf.has("knot"):
		_kp = ar.room.at_polar(float(cf.knot), 25.5)
		_solve_path(id, _kp, ar.global_position)
	elif cf.has("cam"):
		_solve_path(id, bat, at)


var _kp := Vector3.ZERO
var _home := Vector3.ZERO
var _p0 := Vector3.ZERO
var _p1 := Vector3.ZERO


## The lens path, solved once at setup: a start and an end clear of stones and walls, each seeing the boss and the wanderer.
func _solve_path(id: String, bp: Vector3, wp: Vector3) -> void:
	var cf: Dictionary = BOSS[id]
	var c: Array = cf.cam
	var fw := Cam.flat(wp - bp)
	var sd := fw.cross(Vector3.UP)
	var look: Array = [bp + Vector3.UP * (float(c[6]) + 0.5), bp + Vector3.UP * float(c[6]) * 1.6, wp + Vector3.UP * 1.2]
	var v := fw * float(c[0]) + sd * float(c[2])
	if cf.has("look_c"):
		var cen: Vector3 = kit.ar.global_position
		_p0 = cen + Cam.flat(wp - cen) * float(cf.look_c) + Vector3.UP * float(c[4])
		_p1 = _p0 + (cen + Vector3.UP * 3.0 - _p0).normalized() * float(cf.get("push", 1.5))
		return
	_p0 = d.solve_cam(look, bp, atan2(v.x, v.z), Vector2(v.x, v.z).length(), float(c[4]))
	_p1 = _p0 + ((bp + Vector3.UP * float(c[6])) - _p0).normalized() * float(cf.get("push", 2.5))


func _boss_cam(id: String, tt: float) -> void:
	var cf: Dictionary = BOSS[id]
	var k: float = d.sm(clampf(tt / float(d.SHOTS[d.si][1]), 0.0, 1.0))
	var bp: Vector3 = _kp if cf.has("knot") else kit.boss_pos()
	var c: Array = cf.cam
	var from := _p0.lerp(_p1, k)
	var at := bp + Vector3.UP * float(c[6])
	if cf.has("look_c"):
		at = kit.ar.global_position + Vector3.UP * 4.0
	d.frame_cam(from, at)
	d.light_at((from + bp) * 0.5, 4.0)


func _u_any(tt: float, id: String) -> void:
	var cf: Dictionary = BOSS[id]
	var b: Enemy = kit.boss()
	if cf.has("top"):
		var c: Vector3 = kit.ar.global_position
		if id == "thorn_knots" and kit.ar.room != null and not kit.ar.room.knots.is_empty() and is_instance_valid(kit.ar.room.knots[0]):
			c = (kit.ar.room.knots[0] as Node3D).global_position.lerp(c, 0.55)
		if id == "hierarch_voice":
			c = (b.global_position if b else kit.ar.boss_at).lerp(d.pp(), 0.45)
		d.top_down(c, float(cf.top))
		d.light_at(c, 10.0)
	else:
		_boss_cam(id, tt)
	if b and id == "hierarch_phase":
		b._face_dir = Cam.flat(d.pp() - b.global_position)      # the front (the faceless disc) to the lens, not its back
		if d.once("a4_hp_face"):
			b._face.rotation.y = atan2(-b._face_dir.x, -b._face_dir.z)
	if b:
		d.aim_at(b.global_position)
		for l in d.get_tree().root.find_children("*", "Label3D", true, false):
			if String((l as Label3D).text) == "Heart-Knot":
				(l as Label3D).visible = true
	if b:
		if id == "thorn_move":
			(b as Thornwarden)._leap_cd = 99.0          # the lanes are the move: no pounce through the lens
		elif id.begins_with("warden"):
			(b as AscendedWarden)._blink_t = maxf((b as AscendedWarden)._blink_t, 3.0) if id == "warden_phase" else 99.0
	_events(id, tt, b)


## What each shot makes the boss do, and when (shot clock).
func _events(id: String, tt: float, b: Enemy) -> void:
	match id:
		"thorn_reveal", "boss_reveal", "warden", "anchoress":
			if tt > 0.1:
				kit.pull()
		"thorn_move":
			if b and tt > 0.25 and d.once("a4_" + id):
				(b as Thornwarden)._thorn_lanes()
		"thorn_knots":
			if b and tt > 0.1 and d.once("a4_" + id):
				b.hp = float(b.max_hp) * 0.69
			if b and tt > 1.2 and d.once("a4_knot_hit") and not kit.ar.room.knots.is_empty():
				(kit.ar.room.knots[0] as Node3D).take_hit(6.0, d.p)
		"boss_wide":
			if b and tt > 0.15 and d.once("a4_" + id):
				(b as BoneAbbot)._requiem()
		"abbot_phase":
			if b and tt > 0.15 and d.once("a4_" + id):
				b.hp = float(b.max_hp) * 0.65
		"warden_move":
			if b and tt > 0.15 and d.once("a4_" + id):
				(b as AscendedWarden)._aim_fan(false)
		"warden_phase":
			if b and tt > 0.2 and d.once("a4_" + id):
				b.hp = float(b.max_hp) * 0.64
		"anchoress_move":
			if b and tt > 0.2 and d.once("a4_" + id):
				b.call("_swing", 0.0)
		"anchoress_phase":
			if b and tt > 0.2 and d.once("a4_" + id):
				b.hp = float(b.max_hp) * 0.69
		"hierarch_voice", "hierarch_edict":
			if b and tt > 0.2 and d.once("a4_" + id):
				(b as HierarchVoice)._edict(1)
		"hierarch_phase":
			if b and tt > 0.2 and d.once("a4_" + id):
				b.hp = float(b.max_hp) * 0.64
		"final_blow":
			if b and tt > 0.5 and d.once("a4_" + id):
				d.boss = null
				b.set_meta(&"test_no_floor", true)
				b.hp = 1.0
				b.take_hit(50.0, d.p)


func _e_any(_id: String) -> void:
	kit.finish()
	d.key.light_energy = _lit_was.x
	d.key.omni_range = _lit_was.y
	d.key.light_color = Color(0.62, 0.72, 1.0)

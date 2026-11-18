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
	"thorn_reveal": {"boss": "thornwarden", "W": 11.0, "pre": false, "cam": [24.0, 0, 9.0, 0, 5.0, 0, 6.0], "push": 3.0, "fov": 55.0, "lit": [5.0, 40.0]},
	"thorn_move": {"boss": "thornwarden", "W": 12.0, "pre": true, "cam": [26.0, 0, 16.0, 0, 9.0, 0, 4.0], "push": 1.5, "fov": 60.0, "lit": [5.0, 40.0]},
	"thorn_knots": {"boss": "thornwarden", "W": 8.0, "pre": true, "knot": 60.0, "cam": [9.0, 0, -4.5, 0, 4.2, 0, 3.4], "push": 2.0, "fov": 55.0, "lit": [7.0, 40.0]},
	"boss_reveal": {"boss": "bone_abbot", "W": 9.0, "pre": false, "cam": [11.0, 0, 3.0, 0, 2.4, 0, 3.0], "ring": [70.0, 13.0], "fov": 46.0, "lit": [1.6, 24.0, 1]},
	"boss_wide": {"boss": "bone_abbot", "W": 8.0, "pre": true, "cam": [17.0, 0, 7.0, 0, 6.0, 0, 1.5], "ring": [70.0, 12.0], "push": 1.0, "fov": 60.0, "lit": [1.6, 30.0, 1]},
	"abbot_phase": {"boss": "bone_abbot", "W": 8.0, "pre": true, "cam": [15.0, 0, -5.0, 0, 3.8, 0, 3.0], "ring": [-70.0, 12.0], "push": 1.5, "fov": 58.0, "lit": [1.6, 30.0, 1]},
	"abbot_fall": {"boss": "bone_abbot", "W": 8.0, "pre": true, "cam": [16.0, 0, 6.0, 0, 5.0, 0, 1.5], "ring": [70.0, 12.0], "push": 1.2, "fov": 60.0, "lit": [1.6, 30.0, 1]},
	"abbot_burn": {"boss": "bone_abbot", "W": 8.0, "pre": true, "cam": [13.0, 0, -4.0, 0, 3.2, 0, 3.0], "ring": [-70.0, 12.0], "push": 1.5, "fov": 56.0, "lit": [1.6, 30.0, 1]},
	"warden": {"boss": "ascended_warden", "W": 13.0, "pre": false, "cam": [19.0, 0, 4.0, 0, 1.0, 0, 6.0], "push": 3.0, "fov": 62.0, "lit": [6.0, 50.0]},
	"warden_move": {"boss": "ascended_warden", "W": 13.0, "pre": true, "cam": [21.0, 0, -8.0, 0, 9.0, 0, 5.0], "push": 2.0, "fov": 62.0, "lit": [6.0, 50.0]},
	"warden_phase": {"boss": "ascended_warden", "W": 12.0, "pre": true, "cam": [20.0, 0, 5.0, 0, 1.2, 0, 8.0], "push": 2.0, "fov": 64.0, "lit": [6.0, 50.0]},
	"anchoress": {"boss": "r37_anchoress", "W": 9.0, "pre": false, "cam": [16.0, 0, 4.0, 0, 2.5, 0, 6.0], "push": 2.5, "fov": 55.0, "lit": [8.0, 32.0]},
	"anchoress_move": {"boss": "r37_anchoress", "W": 10.0, "pre": true, "cam": [22.0, 0, 12.0, 0, 8.0, 0, 5.0], "push": 1.5, "fov": 58.0, "lit": [8.0, 32.0]},
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


# --- the Bone Abbot's last phase in one shot (Luke, 8 Nov) --------------------------------------------
## Phase IV played out on one slow orbit of the hall: the count is finished (the burn: no ward, the Requiems and the
## falling floor come fast), the wanderer fights him for real (bolts, then the charged lance, round and round), and
## the killing blow.
const WHOLE_BEATS := [[0.2, "burn"], [1.1, "sweep"], [2.2, "rain"], [3.7, "requiem"], [5.4, "song_breaks"], [6.2, "cage"],
	[7.4, "toll"], [8.8, "spikes"], [10.4, "kill"]]
## [shot time, what the wanderer does]: every spell he has, on the move, each answering one of the Abbot's rites
const IV_CASTS := [[0.35, "familiar"], [0.6, "bolts"], [1.3, "bolts_up"], [1.4, "step"], [2.3, "ward"], [2.9, "lance"],
	[3.5, "lance_go"], [3.9, "reliq"], [5.2, "bolts_up"], [5.6, "well"], [6.6, "nova"], [7.0, "tether"], [7.8, "step"],
	[8.6, "peal"], [9.0, "bolts"], [9.8, "bolts_up"], [9.85, "lance"], [10.35, "lance_go"]]
const SK := {"bolt": "res://core/skills/skill_bolt.gd", "lance": "res://core/skills/skill_lance.gd", "nova": "res://core/skills/skill_nova.gd",
	"ward": "res://core/skills/skill_ward.gd", "step": "res://core/skills/skill_step.gd", "well": "res://core/skills/skill_well.gd",
	"familiar": "res://core/skills/skill_familiar.gd", "tether": "res://core/skills/skill_tether.gd", "peal": "res://core/skills/skill_peal.gd"}


var _reliq_aim := false


## Put a skill in a slot (cooldowns reset, as the act II shots do) and cast it there.
func _iv_slot(slot: int, sk: String) -> void:
	if d.book == null:
		return
	d.book.set_slot(slot, (load(String(SK[sk])) as GDScript).new())
	d.book.reset_cooldowns()


func _iv_cast(what: String) -> void:
	match what:
		"bolts":
			_iv_slot(0, "bolt")
			d.press(d.slot_action(0))
		"bolts_up":
			d.release(d.slot_action(0))
			_reliq_aim = false
		"reliq":                                       # the Requiem: bolts into the reliquary at his breast
			_reliq_aim = true
			_iv_slot(0, "bolt")
			d.press(d.slot_action(0))
		"lance":
			_iv_slot(1, "lance")
			d.press(d.slot_action(1))                  # drawn back while he runs...
		"lance_go":
			d.release(d.slot_action(1))                # ...and thrown
		"step":
			_iv_slot(4, "step")
			d.cast(4)
		"nova":
			_iv_slot(2, "nova")
			d.cast(2)
		"ward", "familiar", "peal":
			_iv_slot(3, what)
			d.cast(3)
		"well", "tether":
			_iv_slot(1, what)
			d.cast(1)

var _orbit0 := 0.0


func _s_abbot_iv() -> void:
	var ar: BossArena = kit.begin("bone_abbot")
	if ar == null:
		return
	var cen := ar.global_position
	_home = cen + Cam.flat(ar.boss_at - cen).rotated(Vector3.UP, deg_to_rad(70.0)) * 12.0
	kit.stand(_home, Cam.yaw_dir(Cam.flat(ar.boss_at - _home)))
	d.use_free_cam()
	d.cam.fov = 68.0
	_lit_was = Vector2(d.key.light_energy, d.key.omni_range)
	d.key.light_energy = 1.6
	d.key.omni_range = 30.0
	d.key.light_color = Color(1.0, 0.78, 0.5)
	var v := Cam.flat(_home - cen)
	_orbit0 = atan2(v.x, v.z) + deg_to_rad(35.0)
	_iv_dir = Vector3.ZERO
	_iv_cam = Vector3.ZERO
	_iv_solve_t = 0.0
	_iv_last = 0.0
	if kit.pre_pull() == null:
		print("TRAILER no boss for abbot_iv")
	for bt: Array in WHOLE_BEATS:
		d.flags.erase("aw_" + String(bt[1]))


var _iv_dir := Vector3.ZERO
var _iv_cam := Vector3.ZERO
var _iv_goal := Vector3.ZERO
var _iv_solve_t := 0.0
var _iv_dt := 1.0 / 60.0
var _iv_last := 0.0


func _u_abbot_iv(tt: float) -> void:
	_iv_dt = clampf(tt - _iv_last, 0.0, 0.1)
	_iv_last = tt
	var ar: BossArena = kit.ar
	if ar == null:
		return
	var cen := ar.global_position
	var b: Enemy = kit.boss()
	var bp := b.global_position if b else ar.boss_at
	# the lens: outside the fight, looking in toward the mound, so the mound is always behind the pair and never between
	# them and us; it follows them round slowly (its way turned ~1.5 rad/s at most) and drifts 30 degrees across the shot
	var span := float(d.SHOTS[d.si][1])
	var k := float(d.sm(clampf(tt / span, 0.0, 1.0)))
	var mid := bp.lerp(d.pp(), 0.45)
	var out := Cam.flat(mid - cen)
	if out.length() < 1.0:
		out = Cam.flat(_home - cen)
	var want := out.normalized().rotated(Vector3.UP, deg_to_rad(lerpf(-15.0, 15.0, k)))
	if _iv_dir == Vector3.ZERO:
		_iv_dir = want
	else:
		var ang := _iv_dir.signed_angle_to(want, Vector3.UP)
		_iv_dir = _iv_dir.rotated(Vector3.UP, clampf(ang, -1.5 * _iv_dt, 1.5 * _iv_dt))
	# a spot clear of the hall's columns, bells and the cage, seeing both of them: solved every 0.4 s near the wished-for
	# one (FLOOR_R 18.5, columns and bells beyond it: kept within 16 m of the middle), eased between
	var spot := mid + _iv_dir * 12.0                 # (the Abbot stands 4-5 times a man now: a lens back and up to hold all of him)
	var wr := Cam.flat(spot - cen)
	if wr.length() > 16.0:
		spot = cen + wr.normalized() * 16.0
	if tt >= _iv_solve_t:
		_iv_solve_t = tt + 0.4
		var look: Array = [bp + Vector3.UP * 5.0, d.pp() + Vector3.UP * 1.2]
		var v := Cam.flat(spot - mid)
		var at: Vector3 = d.solve_cam(look, mid, atan2(v.x, v.z), maxf(v.length(), 6.0), 10.0)
		_iv_goal = at if at != Vector3.ZERO else spot + Vector3.UP * 10.0
		if _iv_cam == Vector3.ZERO:
			_iv_cam = _iv_goal
	_iv_cam = _iv_cam.lerp(_iv_goal, 1.0 - exp(-_iv_dt * 2.5))
	# set straight, not frame_cam: its ray pulls the lens in front of whatever crosses it (the shades, the bone rain)
	d._cam_pos = _iv_cam
	d._cam_at = mid + Vector3.UP * 3.5
	d.light_at(mid, 6.0)
	# the wanderer: on the move round him the whole fight (the way changes, a Rift Step out of his reach) and every
	# spell he has, one after another (IV_CASTS)
	if b:
		var wk: Variant = b.get("_weak")
		d.aim_at((wk as Node3D).global_position if _reliq_aim and wk is Node3D and is_instance_valid(wk) else bp)
		var away: Vector3 = d.p.global_position - bp
		away.y = 0.0
		var dist := away.length()
		away = away.normalized()
		var turn := 1.0 if fposmod(tt, 5.0) < 2.6 else -1.0
		var wish := away.cross(Vector3.UP) * turn
		if dist < 8.0:
			wish += away * 0.6
		elif dist > 12.0:
			wish -= away * 0.5
		var home: Vector3 = cen - d.p.global_position
		home.y = 0.0
		if home.length() > 14.0:
			wish += home.normalized() * 0.6
		d.drive(wish.limit_length(1.0))
		for c: Array in IV_CASTS:
			if tt > float(c[0]) and d.once("iv_%s_%.2f" % [c[1], c[0]]):
				_iv_cast(String(c[1]))
	for bt: Array in WHOLE_BEATS:
		if tt > float(bt[0]) and d.once("aw_" + String(bt[1])):
			_whole_beat(String(bt[1]), b)


func _whole_beat(beat: String, b: Enemy) -> void:
	if b == null:
		print("TRAILER no boss for abbot_iv ", beat)
		return
	match beat:
		"burn":
			b.set("_inter", 2)
			b.set("phase", 3)
			b.hp = float(b.max_hp) * 0.11          # phase IV: the Last Count
		"sweep":
			_hold_rites(b)                           # from here every rite is the shot's, in order
			b.call("_sweep")
		"rain":
			b.call("_bone_rain")
		"requiem":
			b.call("_requiem")
		"song_breaks":                               # the bolts found the reliquary: two bursts break the song
			if float(b.get("_reliq_t")) > 0.0:
				b.call("_on_weak_hit", 1.0)
				b.call("_on_weak_hit", 1.0)
		"cage":
			b.call("_cage")
		"toll":
			b.call("_tolling")
		"spikes":
			b.call("_grave_spikes")
		"kill":
			d.boss = null
			b.set_meta(&"test_no_floor", true)
			b.hp = 1.0
			b.take_hit(50.0, d.p)


## Every rite's own clock pushed out, so the shot calls them one by one.
func _hold_rites(b: Enemy) -> void:
	for f in ["_requiem_t", "_rain_t", "_toll_t", "_cage_t", "_spike_t", "_grave_t", "_tithe_t", "_reckon_t", "_raise_t", "_choir_t"]:
		if f in b:
			b.set(f, 99.0)


func _e_abbot_iv() -> void:
	kit.finish()
	_iv_slot(0, "bolt")
	_iv_slot(1, "lance")
	_iv_slot(2, "nova")
	_iv_slot(3, "ward")
	_iv_slot(4, "step")
	for n in d.get_tree().get_nodes_in_group(&"bound_shade"):
		(n as Node).queue_free()
	d.key.light_energy = _lit_was.x
	d.key.omni_range = _lit_was.y
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
		"abbot_fall":                       # phase III: the floor remembers its dead
			if b and tt > 0.15 and d.once("a4_" + id):
				b.set("_inter", 2)
				b.set("phase", 2)
				b.hp = float(b.max_hp) * 0.32
		"abbot_burn":                       # phase IV: the burn, no ward
			if b and tt > 0.15 and d.once("a4_" + id):
				b.set("_inter", 2)
				b.set("phase", 3)
				b.hp = float(b.max_hp) * 0.11
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

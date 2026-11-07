extends "res://zz/trailer_shots_act3b.gd"
## Act III story shots (extends the Act III kit): the eighth bell and its keeper, a secret opening, the real escort and
## defend steps with foes that attack the ward, world events, the map. Everything is the live system fed its own data
## (the quest chains' own step dictionaries); the director only places the wanderer and the lens.

const Escort := preload("res://core/story/escort.gd")
const Defend := preload("res://core/story/defend.gd")
const Sig := preload("res://core/story/quest_chains_signature.gd")
const QProps := preload("res://core/story/quest_props.gd")
const Book := preload("res://core/story/quest_book.gd")
const SecKit := preload("res://core/life/secrets/kit.gd")
const R37E := preload("res://core/world/realm/realm_pois_r37_east.gd")

const BELL := Vector2(242.0, 13.5)               ## the Shut-Out Bell at the Spire's foot (quest_chains_bells.gd)

var _bell: Node3D
var _shut: Enemy
var _esc: Escort
var _def: Defend
var _walk_to := Vector3.ZERO
var _shrunk := {}


# --- the bell and its keeper ----------------------------------------------------------------------------

func bell_at() -> Vector3:
	return d.on_ground(Vector3(BELL.x, 0.0, BELL.y))


func put_bell() -> void:
	if _bell != null and is_instance_valid(_bell):
		return
	var at := bell_at()
	_bell = QProps.make(d.main, "TrailerBell", "bell", Transform3D(Basis(Vector3.UP, 0.4), at))


func call_shutter() -> void:
	_shut = null
	for r in d._by_script("rares.gd"):
		var e := r.call("spawn_rare", "lamp_shutter") as Enemy
		if e != null:
			_shut = e
			break
	if _shut == null:
		print("TRAILER no Shutter")
		return
	print("TRAILER Shutter at %s visible=%s" % [_shut.global_position, _shut.visible])
	_shut.global_position = bell_at() + Vector3(-2.6, 0.1, 1.0)
	_shut.home = _shut.global_position
	d.spawned.append(_shut)


var _bell_cam := Vector3.ZERO
var _bell_aim := Vector3.ZERO
var _keeper_at := Vector3.ZERO


## Locks a lens spot round the bell that sees the bell, the keeper and the wanderer with nothing in the way.
func lock_bell_cam(pts: Array, yaw0: float, dist: float, h: float) -> void:
	var b := bell_at()
	_bell_aim = Vector3.ZERO
	for v: Vector3 in pts:
		_bell_aim += v
	_bell_aim /= float(pts.size())
	# south of the bell is the open side (the tower and the bluff close the rest): the lens straight out from it
	var from: Vector3 = d.on_ground(b + Vector3(sin(yaw0), 0.0, cos(yaw0)) * dist, h)
	_bell_cam = from if _lens_clear(b + Vector3.UP * 1.3, from, _bell_aim) else d.solve_cam(pts, b, yaw0, dist, h)
	print("TRAILER bell lens %s aim %s dist %.1f" % [_bell_cam, _bell_aim, _bell_cam.distance_to(_bell_aim)])


func _s_bells() -> void:
	d.clear_spawned()
	put_bell()
	call_shutter()
	var b := bell_at()
	var keeper := b + Vector3(-1.9, 0.1, 1.3)
	var me := b + Vector3(2.3, 0.0, 1.4)
	d.put_player(me, Cam.yaw_dir(b - me), -0.05)
	d.drive(Vector3.ZERO)
	_keeper_at = keeper
	if is_instance_valid(_shut):
		_shut.global_position = keeper
		_shut.home = keeper
	d.use_free_cam()
	d.cam.fov = 62.0
	fill(b + Vector3(0.0, 2.6, 4.0), 4.0, 14.0)
	lock_bell_cam([b + Vector3.UP * 1.3, keeper + Vector3.UP * 1.2, me + Vector3.UP * 1.3], 0.0, 5.6, 2.0)


func _u_bells(tt: float) -> void:
	var b := bell_at()
	if is_instance_valid(_shut):
		_shut.global_position = _keeper_at                  # the keeper stands its post by the bell
	var k: float = d.sm(clampf(tt / 2.0, 0.0, 1.0))
	var from := _bell_cam.lerp(_bell_aim + (_bell_cam - _bell_aim) * 0.82, k)
	d.hold_cam(from, _bell_aim + Vector3.UP * 0.15)
	d.light_at(b, 4.0)
	d.aim_at(b)


func _e_bells() -> void:
	d.drive(Vector3.ZERO)
	clear_fills()
	d.cam.fov = 62.0


func _s_shutter_fight() -> void:
	d.clear_spawned()
	if d.main.get_node_or_null("RungBell_bell_spire") == null:
		put_bell()
	call_shutter()
	var b := bell_at()
	d.put_player(b + Vector3(0.5, 0.0, 7.0), 0.0, -0.15)
	d.use_free_cam()
	d.cam.fov = 55.0
	fill(b + Vector3(0.0, 2.5, 3.0), 3.0, 14.0)
	if _shut:
		_shut.wake()
		_shut.global_position = b + Vector3(-1.0, 0.1, 1.5)


func _u_shutter_fight(tt: float) -> void:
	var sp: Vector3 = _shut.global_position if is_instance_valid(_shut) else bell_at()
	two_shot(d.pp(), sp, d.sm(clampf(tt / 2.6, 0.0, 1.0)), 7.0, 3.5, -1.0, 0.3, 1.2)
	d.light_at(d.pp().lerp(bell_at(), 0.5), 5.0)
	var foe: Node3D = d.target()
	if foe:
		d.aim_at(foe.global_position)
	if tt > 0.1 and d.once("sf_bolts"):
		d.press(d.slot_action(0))
	if tt > 1.6:
		d.drive(Cam.flat(d.pp() - bell_at()) * 0.35)         # giving ground from the swing
	if _shut and is_instance_valid(_shut) and _shut.hp < 12.0:
		_shut.hp = 12.0


func _e_shutter_fight() -> void:
	d.release(d.slot_action(0))
	d.drive(Vector3.ZERO)
	clear_fills()
	d.cam.fov = 62.0


func _s_bell_ring() -> void:
	d.clear_spawned()
	var rung: Node = d.main.get_node_or_null("RungBell_bell_spire")
	if rung:
		rung.queue_free()
	put_bell()
	var b := bell_at()
	var me := b + Vector3(2.3, 0.0, 1.2)
	d.put_player(me, Cam.yaw_dir(b - me), -0.05)
	d.drive(Vector3.ZERO)
	d.aim_at(b)
	d.use_free_cam()
	d.cam.fov = 56.0
	fill(b + Vector3(0.5, 2.0, 2.4), 6.0, 10.0)
	lock_bell_cam([b + Vector3.UP * 1.4, b + Vector3.UP * 2.4, me + Vector3.UP * 1.3], 0.0, 5.2, 1.6)


func _u_bell_ring(tt: float) -> void:
	var b := bell_at()
	var k: float = d.sm(clampf(tt / 2.4, 0.0, 1.0))
	var from := _bell_cam.lerp(_bell_aim + (_bell_cam - _bell_aim) * 0.85, k)
	d.hold_cam(from, _bell_aim + Vector3.UP * 0.4)
	d.light_at(b, 3.5)
	d.aim_at(b)
	if tt > 0.7 and d.once("br_reach"):
		d.p._visual.cast_pose(&"reach")
	if tt > 0.9 and d.once("br_ring"):
		# the answer the bell asks: rung where it hangs; the keeper of the night's own state does the rest
		if _bell and is_instance_valid(_bell):
			_bell.queue_free()
		Book.start("bell_spire")
		Book.q("bell_spire")["p"] = "rung"
		Events.quest_changed.emit("bell_spire", 1, false)
		SecKit.play("bell_great", b, 0.0, 1.0)


func _e_bell_ring() -> void:
	d.drive(Vector3.ZERO)
	clear_fills()
	d.cam.fov = 62.0


# --- a secret opens ---------------------------------------------------------------------------------------

func _valve(i: int) -> Interactable:
	var site: Node = d.main.find_child("SaltVault", true, false)
	return site.get_node_or_null("Valve_%d" % i) as Interactable if site else null


func hatch_at() -> Vector3:
	var s: Dictionary = R37E.spots
	var cc: Vector3 = (s.crust as Dictionary).at
	return d.on_ground(Vector3(cc.x + 3.4, 0.0, cc.z - 3.8))


func _s_secret() -> void:
	d.clear_spawned()
	var h := hatch_at()
	d.put_player(h + Vector3(3.2, 0.0, 3.0), Cam.yaw_dir(Vector3(-1.0, 0.0, -0.6)), -0.05)
	d.drive(Cam.flat(h - d.pp()) * 0.3)
	d.use_free_cam()
	d.cam.fov = 54.0
	fill(h + Vector3(0.0, 3.0, 2.0), 3.5, 14.0, Color(0.7, 0.8, 1.0))
	# the brine-clerk's order, east, west, middle: the last turn lands as the shot opens
	for i in [2, 0, 1]:
		var v := _valve(i)
		if v:
			v.interact(d.p)
		else:
			print("TRAILER no valve %d" % i)


func _u_secret(tt: float) -> void:
	var h := hatch_at()
	var k: float = d.sm(clampf(tt / 2.4, 0.0, 1.0))
	cam.orbit(h + Vector3(1.5, 0.0, 1.0), k, 9.0, 7.5, 0.4, 1.0, 3.2, 3.0, 0.4)
	d.light_at(h, 4.0)
	if tt > 1.4:
		d.drive(Vector3.ZERO)


func _e_secret() -> void:
	d.drive(Vector3.ZERO)
	clear_fills()
	d.cam.fov = 62.0


# --- escort -----------------------------------------------------------------------------------------------

## The real ferry passenger (the Last Crossing's escort step), standing at waypoint `from`; `near_next` puts them a
## step short of the next waypoint so its ambush springs as the shot opens.
func start_escort(from: int, near_next: bool) -> void:
	var stp: Dictionary = ((Sig.MERE_FERRY.steps as Array)[2] as Dictionary).duplicate(true)
	# the real ferry path hugs the chapel wall (the passenger came out half inside it): the same step walks the open
	# road west of the green instead, a few paces from the first brazier-free stretch
	var road: Array[Vector2] = []
	for i in 4:
		road.append(Vector2(d.ARENA.x - 14.0 - 12.0 * float(i), d.ARENA.z))
	stp["path"] = road
	stp["at"] = road[3]
	_shrunk.clear()
	_esc = Escort.new() as Escort
	_esc.setup("mere_ferry", stp, from)
	d.main.add_child(_esc)
	_esc.set_process(false)                              # ticked by the shoot, so its foes are adopted before the director's sweep
	var path: Array = stp.path
	var a: Vector2 = path[from]
	var bb: Vector2 = path[from + 1]
	var dir := (bb - a).normalized()
	var at := a + (bb - a) - dir * 1.4 if near_next else a
	_esc.global_position = d.on_ground(Vector3(at.x, 0.0, at.y))
	_walk_to = Vector3(bb.x, 0.0, bb.y)
	var fr: Dictionary = _esc._frame
	d.keep_layers.append(fr.layer as CanvasLayer)
	var side := Vector3(dir.y, 0.0, -dir.x)
	_side_sign = _open_side(_esc.global_position, side)
	side *= _side_sign
	d.put_player(_esc.global_position - Vector3(dir.x, 0.0, dir.y) * 1.2 + side * 1.6, Cam.yaw_dir(Vector3(dir.x, 0.0, dir.y)), -0.08)


var _side_sign := 1.0


## +1 or -1: the side of the walking line with more room (a lens hugging a wall fills the frame with it).
func _open_side(at: Vector3, side: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = d.main.get_world_3d().direct_space_state
	var room := [0.0, 0.0]
	for i in 2:
		var sg := 1.0 if i == 0 else -1.0
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.UP * 1.2 + side * sg * 7.0, Layers.WORLD | Layers.PROPS)
		var hit: Dictionary = space.intersect_ray(q)
		room[i] = 7.0 if hit.is_empty() else (hit.position as Vector3).distance_to(at + Vector3.UP * 1.2)
	return 1.0 if float(room[0]) >= float(room[1]) else -1.0


func esc_tick() -> void:
	_esc.tick(d.get_process_delta_time())
	adopt(_esc.foes)
	for f: Enemy in _esc.foes:
		if is_instance_valid(f) and not _shrunk.has(f.get_instance_id()):
			# the ambush rises at the ring's 8 m; the shoot draws it in to 5 m so the foes read beside the pair
			_shrunk[f.get_instance_id()] = true
			var off: Vector3 = f.global_position - _esc.global_position
			off.y = 0.0
			var np: Vector3 = _esc.global_position + off.normalized() * 5.0
			f.global_position = Vector3(np.x, d.gy(np.x, np.z) + 0.1, np.z)


func esc_drive(tt: float) -> void:
	# keeps pace beside the passenger, a step to the side and a little behind, like a player would
	var f := -_esc.global_basis.z
	var side := f.cross(Vector3.UP)
	var want: Vector3 = _esc.global_position - f * 0.6 + side * 1.7 * _side_sign
	var to: Vector3 = want - d.pp()
	to.y = 0.0
	d.drive(to.normalized() * clampf(to.length() * 0.7, 0.0, 0.7))


func finish_escort() -> void:
	d.drive(Vector3.ZERO)
	d.release(d.slot_action(0))
	if _esc and is_instance_valid(_esc):
		_esc.queue_free()
	d.clear_spawned()
	clear_fills()
	d.cam.fov = 62.0


func _s_escort() -> void:
	d.clear_spawned()
	start_escort(0, false)
	d.use_player_cam()
	fill(_esc.global_position + Vector3(0.0, 3.0, 0.0), 2.0, 12.0)


func _u_escort(tt: float) -> void:
	esc_tick()
	esc_drive(tt)
	d.aim_at(_walk_to)
	d.p.set_view(Cam.yaw_dir(Cam.flat(_walk_to - d.pp())), -0.3)
	d.light_at(_esc.global_position, 4.0)


func _e_escort() -> void:
	finish_escort()


func _s_escort_attack() -> void:
	d.clear_spawned()
	start_escort(0, true)
	d.use_player_cam()
	fill(_esc.global_position + Vector3(0.0, 3.0, 0.0), 2.0, 12.0)


func _u_escort_attack(tt: float) -> void:
	esc_tick()
	var foe: Node3D = d.target()
	d.light_at(_esc.global_position.lerp(d.pp(), 0.5), 5.0)
	if foe:
		d.aim_at(foe.global_position)
		d.drive(Cam.flat(foe.global_position - d.pp()) * 0.3)
		if tt > 0.2 and d.once("ea_bolts"):
			d.press(d.slot_action(0))
	else:
		esc_drive(tt)


func _e_escort_attack() -> void:
	finish_escort()


func _s_escort_top() -> void:
	d.clear_spawned()
	start_escort(1, true)
	d.use_free_cam()
	d.cam.fov = 55.0
	d.key.light_energy = 11.0
	d.key.omni_range = 36.0


func _u_escort_top(tt: float) -> void:
	esc_tick()
	var mid: Vector3 = _esc.global_position.lerp(d.pp(), 0.5)
	d.top_down(mid, 11.0, 58.0)
	d.light_at(mid, 6.0)
	var foe: Node3D = d.target()
	if foe:
		d.aim_at(foe.global_position)
		d.drive(Cam.flat(foe.global_position - d.pp()) * 0.25)
		if tt > 0.3 and d.once("et_bolts"):
			d.press(d.slot_action(0))
	else:
		esc_drive(tt)


func _e_escort_top() -> void:
	d.key.light_energy = 3.0
	d.key.omni_range = 24.0
	finish_escort()


# --- defend -----------------------------------------------------------------------------------------------

## The real hold-the-ward step: `quest` is "ORCHARD_STAND" or "MOOR_FIRES". Waves come at once (the data's own kinds).
func start_defend(quest: String, wave_from: int) -> void:
	var qd: Dictionary = Sig.ORCHARD_STAND if quest == "ORCHARD_STAND" else Sig.MOOR_FIRES
	var stp: Dictionary = ((qd.steps as Array)[2] as Dictionary).duplicate(true)
	var waves: Array = (stp.waves as Array).slice(wave_from)
	var t := 0.4
	for w: Dictionary in waves:
		w["at"] = t
		t += 1.4
	stp["waves"] = waves
	stp["time"] = 120.0
	_def = Defend.new() as Defend
	_def.setup("trailer_" + quest, stp)
	d.main.add_child(_def)
	_def.set_process(false)
	_shrunk.clear()
	var at: Vector2 = stp.at
	d.keep_layers.append((_def._frame.layer as CanvasLayer))
	var c := Vector3(at.x, 0.0, at.y)
	d.put_player(c + Vector3(-2.2, 0.0, 3.2), Cam.yaw_dir(Vector3(0.3, 0.0, -1.0)), -0.08)


func def_fight(tt: float, key: String) -> void:
	_def.tick(d.get_process_delta_time())
	adopt(_def.foes)
	for f: Enemy in _def.foes:
		if is_instance_valid(f) and not _shrunk.has(f.get_instance_id()):
			# the waves rise at the ward's own ring (12 m); the shoot draws them in to 6 m so they arrive within the shot
			_shrunk[f.get_instance_id()] = true
			var off: Vector3 = f.global_position - _def.global_position
			off.y = 0.0
			var np: Vector3 = _def.global_position + off.normalized() * 6.5
			f.global_position = Vector3(np.x, d.gy(np.x, np.z) + 0.1, np.z)
	var foe: Node3D = d.target()
	if foe:
		d.aim_at(foe.global_position)
		if tt > 0.3 and d.once(key):
			d.press(d.slot_action(0))
		if d.pp().distance_to(_def.global_position) > 4.0:
			d.drive(Cam.flat(_def.global_position - d.pp()) * 0.4)
		else:
			d.drive(Vector3.ZERO)


func finish_defend() -> void:
	d.drive(Vector3.ZERO)
	d.release(d.slot_action(0))
	if _def and is_instance_valid(_def):
		_def.queue_free()
	d.clear_spawned()
	clear_fills()
	d.key.light_energy = 3.0
	d.key.omni_range = 24.0
	d.cam.fov = 62.0


func _s_defend() -> void:
	d.clear_spawned()
	start_defend("MOOR_FIRES", 0)
	d.use_free_cam()
	d.cam.fov = 55.0
	d.key.light_energy = 11.0
	d.key.omni_range = 36.0


func _u_defend(tt: float) -> void:
	def_fight(tt, "df_bolts")
	var mid: Vector3 = _def.global_position.lerp(d.pp(), 0.3)
	d.top_down(mid, 8.0, 42.0)
	d.light_at(mid, 6.0)


func _e_defend() -> void:
	finish_defend()


func _s_defend_game() -> void:
	d.clear_spawned()
	start_defend("MOOR_FIRES", 0)
	d.use_player_cam()
	fill(_def.global_position + Vector3(0.0, 2.5, 0.0), 2.0, 12.0)


func _u_defend_game(tt: float) -> void:
	def_fight(tt, "dg_bolts")
	d.p.set_view(float(d.p.get("_yaw")), -0.32)
	d.light_at(_def.global_position.lerp(d.pp(), 0.5), 5.0)


func _e_defend_game() -> void:
	finish_defend()


func _s_defend_top() -> void:
	d.clear_spawned()
	start_defend("MOOR_FIRES", 1)
	d.use_free_cam()
	d.cam.fov = 55.0
	d.key.light_energy = 11.0
	d.key.omni_range = 36.0


func _u_defend_top(tt: float) -> void:
	def_fight(tt, "dt_bolts")
	var mid: Vector3 = _def.global_position.lerp(d.pp(), 0.3)
	d.top_down(mid, 8.5 - tt * 0.4, 48.0)
	d.light_at(mid, 6.0)


func _e_defend_top() -> void:
	finish_defend()


# --- world events and the map -------------------------------------------------------------------------------

func roam_events() -> Node:
	return d.get_tree().get_first_node_in_group(&"roam_events")


## Foes the event spawned belong to the shoot now (the director culls any it did not cast).
func adopt_roam() -> void:
	for n in d.get_tree().get_nodes_in_group(Groups.ENEMY):
		if n.has_meta(&"roam") and String(n.get_meta(&"roam")) != "":
			adopt([n])


func end_roam() -> void:
	var re := roam_events()
	if re:
		re.set("kind", "")
		var pin: Node = d.main.find_child("RoamPin", true, false)
		if pin:
			pin.queue_free()


var _roam_cam := Vector3.ZERO


func _s_roam() -> void:
	d.clear_spawned()
	d.put_player(d.ARENA + Vector3(-30.0, 0.0, 0.0), d.WEST, -0.05)
	var re := roam_events()
	var ok := false
	if re:
		ok = bool(re.call("start", "procession"))
	print("TRAILER roam procession started: %s" % ok)
	adopt_roam()
	var fl: Array[Node3D] = d.foes()
	var m: Vector3 = d.ARENA
	if not fl.is_empty():
		m = Vector3.ZERO
		for f in fl:
			m += f.global_position
		m /= float(fl.size())
		# the file walks toward the summit: the wanderer stands ahead of it on the way, watching it come
		var ahead := Cam.flat(Vector3(0.0, 0.0, -104.0) - m)
		d.put_player(m + ahead * 12.0, Cam.yaw_dir(-ahead), -0.05)
	d.use_free_cam()
	d.cam.fov = 56.0
	d.key.light_energy = 6.0
	d.key.omni_range = 30.0
	# a lens spot off to the side of the line from the wanderer to the file, that sees both ends and every foe
	var pts: Array = [d.pp() + Vector3.UP * 1.4, m + Vector3.UP * 1.2]
	for f in fl:
		pts.append(f.global_position + Vector3.UP * 1.0)
	var mid: Vector3 = d.pp().lerp(m, 0.5)
	var across := Cam.flat(m - d.pp()).cross(Vector3.UP)
	_roam_cam = d.solve_cam(pts, mid, d.yaw_to(across), 11.0, 4.0)
	gather_props()
	var lens_xz := clear_stand(Vector2(_roam_cam.x, _roam_cam.z))              # not hard against a lamp post or a sign
	_roam_cam = Vector3(lens_xz.x, _roam_cam.y, lens_xz.y)


func _u_roam(tt: float) -> void:
	adopt_roam()
	var foes: Array[Node3D] = d.foes()
	var mid: Vector3 = d.pp()
	if not foes.is_empty():
		mid = Vector3.ZERO
		for f in foes:
			mid += f.global_position
		mid /= float(foes.size())
	var k: float = d.sm(clampf(tt / 1.6, 0.0, 1.0))
	var between: Vector3 = d.pp().lerp(mid, 0.5)
	d.hold_cam(_roam_cam.lerp(between + Vector3.UP * 3.0, k * 0.15), between + Vector3.UP * 1.2)
	d.aim_at(mid)
	d.light_at(mid.lerp(d.pp(), 0.4), 5.0)


func _e_roam() -> void:
	end_roam()
	d.clear_spawned()
	d.key.light_energy = 3.0
	d.key.omni_range = 24.0
	d.cam.fov = 62.0


var _fire: Node3D


func _s_roam_incursion() -> void:
	d.clear_spawned()
	# the nearest lit fire 35 m or more off the open road: the wanderer is walked 45 m from it, the event starts, then
	# she stands at its edge (the dark leans on it; hollowed gather where its light ends)
	_fire = null
	var best := INF
	for b in d.get_tree().get_nodes_in_group(Groups.BRAZIER):
		var bn := b as Node3D
		if bn == null:
			continue
		var dd := bn.global_position.distance_to(d.ARENA)
		if dd > 40.0 and dd < best:
			best = dd
			_fire = bn
	if _fire == null:
		print("TRAILER no lit brazier")
		return
	if not bool(_fire.get("lit")):
		_fire.call("kindle_quiet")                         # a fire the wanderer kept lit
	var f := _fire.global_position
	var away := Cam.flat(d.ARENA - f)
	d.put_player(f + away * 45.0, Cam.yaw_dir(-away), -0.05)
	var re := roam_events()
	var ok := false
	if re:
		ok = bool(re.call("start", "incursion"))
	print("TRAILER roam incursion started: %s at %s" % [ok, f])
	adopt_roam()
	d.put_player(f + away * 2.4, Cam.yaw_dir(-away), -0.05)
	d.use_free_cam()
	d.cam.fov = 55.0
	d.key.light_energy = 11.0
	d.key.omni_range = 36.0


func _u_roam_incursion(tt: float) -> void:
	if _fire == null:
		return
	adopt_roam()
	var f := _fire.global_position
	d.top_down(f, 20.0 - tt * 0.6, 62.0)
	d.light_at(f, 6.0)
	var foe: Node3D = d.target()
	if foe:
		d.aim_at(foe.global_position)
		if tt > 0.3 and d.once("ri_bolts"):
			d.press(d.slot_action(0))


func _e_roam_incursion() -> void:
	d.release(d.slot_action(0))
	end_roam()
	d.clear_spawned()
	d.key.light_energy = 3.0
	d.key.omni_range = 24.0
	d.cam.fov = 62.0


const WorldMapS := preload("res://ui/world_map.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
var _wm: WorldMapS


func _s_map() -> void:
	d.clear_spawned()
	for r: Dictionary in RealmLayout.REGIONS:
		CodexStore.discover(String(r.id))                  # the journal has walked the whole Realm: the ink shows everywhere
	_wm = d.get_tree().get_first_node_in_group(&"world_map") as WorldMapS
	if _wm == null:
		print("TRAILER no world map")
		return
	d.put_player(d.GREEN, d.WEST)
	d.keep_layers.append(_wm)
	_wm.open()


func _u_map(_tt: float) -> void:
	if _wm == null:
		return
	_wm.visible = true
	_wm._zoom_by(1.004, _wm._area.get_center())         # a slow push in


func _e_map() -> void:
	if _wm:
		_wm.close()

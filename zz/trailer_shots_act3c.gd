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
	_shut.global_position = bell_at() + Vector3(-2.6, 0.1, 1.0)
	_shut.home = _shut.global_position
	d.spawned.append(_shut)


func _s_bells() -> void:
	d.clear_spawned()
	put_bell()
	call_shutter()
	var b := bell_at()
	d.put_player(b + Vector3(3.5, 0.0, 6.0), Cam.yaw_dir(Vector3(-0.4, 0.0, -1.0)), -0.05)
	d.drive(Cam.flat(b - d.pp()) * 0.35)
	d.use_free_cam()
	d.cam.fov = 52.0
	fill(b + Vector3(0.0, 2.2, 2.0), 3.0, 14.0)


func _u_bells(tt: float) -> void:
	var b := bell_at()
	var k: float = d.sm(clampf(tt / 2.0, 0.0, 1.0))
	# low on the bell, the keeper at its side, the Spire standing behind them; a slow orbit
	cam.orbit(b, k, 6.5, 5.6, 0.55, 0.15, 1.0, 1.5, 1.6)
	d.light_at(b, 4.0)
	if is_instance_valid(_shut):
		d.aim_at(_shut.global_position)


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
	d.put_player(b + Vector3(0.5, 0.0, 10.5), 0.0, -0.1)
	d.use_player_cam()
	fill(b + Vector3(0.0, 2.5, 3.0), 3.0, 14.0)
	if _shut:
		_shut.wake()
		_shut.global_position = b + Vector3(-1.0, 0.1, 2.0)


func _u_shutter_fight(tt: float) -> void:
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


func _s_bell_ring() -> void:
	d.clear_spawned()
	var rung: Node = d.main.get_node_or_null("RungBell_bell_spire")
	if rung:
		rung.queue_free()
	put_bell()
	var b := bell_at()
	d.put_player(b + Vector3(1.0, 0.0, 4.2), Cam.yaw_dir(Vector3(-0.2, 0.0, -1.0)), -0.05)
	d.drive(Cam.flat(b - d.pp()) * 0.4)
	d.aim_at(b)
	d.use_free_cam()
	d.cam.fov = 46.0
	fill(b + Vector3(0.0, 2.0, 1.5), 3.0, 12.0)


func _u_bell_ring(tt: float) -> void:
	var b := bell_at()
	var k: float = d.sm(clampf(tt / 2.4, 0.0, 1.0))
	cam.orbit(b, k, 5.4, 4.2, -0.5, -0.1, 1.2, 1.5, 1.45)
	d.light_at(b, 3.5)
	if tt > 0.9:
		d.drive(Vector3.ZERO)
	if tt > 0.95 and d.once("br_reach"):
		d.p._visual.cast_pose(&"reach")
	if tt > 1.1 and d.once("br_ring"):
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
	d.put_player(h + Vector3(-1.5, 0.0, 5.5), Cam.yaw_dir(Vector3(0.1, 0.0, -1.0)), -0.05)
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
	cam.orbit(h, k, 8.0, 6.0, 0.2, 0.7, 2.6, 2.2, 0.2)
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
	var stp: Dictionary = (Sig.MERE_FERRY.steps as Array)[2]
	_esc = Escort.new() as Escort
	_esc.setup("mere_ferry", stp.duplicate(true), from)
	d.main.add_child(_esc)
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
	d.put_player(_esc.global_position - Vector3(dir.x, 0.0, dir.y) * 1.2 + side * 1.6, Cam.yaw_dir(Vector3(dir.x, 0.0, dir.y)), -0.08)


func esc_drive(tt: float) -> void:
	# keeps pace beside the passenger, a step to the side and a little behind, like a player would
	var f := -_esc.global_basis.z
	var side := f.cross(Vector3.UP)
	var want: Vector3 = _esc.global_position - f * 0.6 + side * 1.7
	var to: Vector3 = want - d.pp()
	to.y = 0.0
	d.drive(to.normalized() * clampf(to.length() * 0.7, 0.0, 0.7))
	adopt(_esc.foes)


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
	esc_drive(tt)
	d.aim_at(_walk_to)
	d.p.set_view(Cam.yaw_dir(Cam.flat(_walk_to - d.pp())), -0.12)
	d.light_at(_esc.global_position, 4.0)


func _e_escort() -> void:
	finish_escort()


func _s_escort_attack() -> void:
	d.clear_spawned()
	start_escort(0, true)
	d.use_player_cam()
	fill(_esc.global_position + Vector3(0.0, 3.0, 0.0), 2.0, 12.0)


func _u_escort_attack(tt: float) -> void:
	adopt(_esc.foes)
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
	d.key.light_energy = 7.0
	d.key.omni_range = 30.0


func _u_escort_top(tt: float) -> void:
	adopt(_esc.foes)
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
	var at: Vector2 = stp.at
	d.keep_layers.append((_def._frame.layer as CanvasLayer))
	var c := Vector3(at.x, 0.0, at.y)
	d.put_player(c + Vector3(-2.2, 0.0, 3.2), Cam.yaw_dir(Vector3(0.3, 0.0, -1.0)), -0.08)


func def_fight(tt: float, key: String) -> void:
	adopt(_def.foes)
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
	start_defend("ORCHARD_STAND", 0)
	d.use_free_cam()
	d.cam.fov = 55.0
	d.key.light_energy = 7.0
	d.key.omni_range = 30.0


func _u_defend(tt: float) -> void:
	def_fight(tt, "df_bolts")
	var mid: Vector3 = _def.global_position.lerp(d.pp(), 0.3)
	d.top_down(mid, 12.0, 60.0)
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
	d.light_at(_def.global_position.lerp(d.pp(), 0.5), 5.0)


func _e_defend_game() -> void:
	finish_defend()


func _s_defend_top() -> void:
	d.clear_spawned()
	start_defend("ORCHARD_STAND", 1)
	d.use_free_cam()
	d.cam.fov = 55.0
	d.key.light_energy = 7.0
	d.key.omni_range = 30.0


func _u_defend_top(tt: float) -> void:
	def_fight(tt, "dt_bolts")
	var mid: Vector3 = _def.global_position.lerp(d.pp(), 0.3)
	d.top_down(mid, 15.0 - tt * 0.8, 62.0)
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


func _s_roam() -> void:
	d.clear_spawned()
	d.put_player(d.ARENA + Vector3(-30.0, 0.0, 0.0), d.WEST, -0.05)
	var re := roam_events()
	var ok := false
	if re:
		ok = bool(re.call("start", "procession"))
	print("TRAILER roam procession started: %s" % ok)
	adopt_roam()
	d.use_free_cam()
	d.cam.fov = 50.0
	d.key.light_energy = 6.0
	d.key.omni_range = 30.0


func _u_roam(tt: float) -> void:
	adopt_roam()
	var foes: Array[Node3D] = d.foes()
	var mid: Vector3 = d.pp()
	if not foes.is_empty():
		mid = Vector3.ZERO
		for f in foes:
			mid += f.global_position
		mid /= float(foes.size())
		d.aim_at(mid)
	var back := Cam.flat(d.pp() - mid)
	# behind the wanderer, low, the file coming along the road toward them
	d.frame_cam(d.pp() + back * 3.0 + Vector3.UP * 1.9 + back.cross(Vector3.UP) * (1.0 - tt * 0.6), mid + Vector3.UP * 1.4)
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
		if bn == null or not bool(bn.get("lit")):
			continue
		var dd := bn.global_position.distance_to(d.ARENA)
		if dd > 40.0 and dd < best:
			best = dd
			_fire = bn
	if _fire == null:
		print("TRAILER no lit brazier")
		return
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
	d.key.light_energy = 7.0
	d.key.omni_range = 30.0


func _u_roam_incursion(tt: float) -> void:
	if _fire == null:
		return
	adopt_roam()
	var f := _fire.global_position
	d.top_down(f, 17.0 - tt * 0.8, 62.0)
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

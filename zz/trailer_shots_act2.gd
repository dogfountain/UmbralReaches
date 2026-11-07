extends RefCounted
## Act II shots (what climbs comes down hollow): the learned spells, Gloom and the Shade, loot, the slide, weather.
## Existing in the director: card_dark, fight_otc, fp_lance, fight_top, fight_side, vault, grab, kick, fp_run, storm, wildlife.

const Cam := preload("res://zz/trailer_cam.gd")
const SKILL_WELL := "res://core/skills/skill_well.gd"
const SKILL_FAMILIAR := "res://core/skills/skill_familiar.gd"
const SKILL_LANCE := "res://core/skills/skill_lance.gd"
const SKILL_WARD := "res://core/skills/skill_ward.gd"
const GearDB := preload("res://core/items/gear_db.gd")

var d
var cam
var _husk: Node3D
var _herd: Node3D
var _herd_cam := Vector3.ZERO


func _init(director: Object) -> void:
	d = director
	cam = Cam.new(director)


func _swap(slot: int, path: String) -> void:
	if d.book == null:
		return
	d.book.set_slot(slot, (load(path) as GDScript).new())
	d.book.reset_cooldowns()


func _restore_slots() -> void:
	_swap(1, SKILL_LANCE)
	_swap(3, SKILL_WARD)


func _fight_pack(near: float) -> void:
	d.put_player(d.ARENA, d.WEST)
	d.spawn_pack(d.ARENA, d.WEST, near)


func _face_foe() -> void:
	var foe: Node3D = d.target()
	if foe:
		d.aim_at(foe.global_position)


# --- the Lantern Ward: the flame stands, the pack is thrown back off its edge --------------------------

func _s_spell_ward() -> void:
	_fight_pack(6.5)
	d.use_free_cam()
	d.cam.fov = 52.0


func _u_spell_ward(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 2.2, 0.0, 1.0))
	cam.orbit(d.pp(), k, 4.6, 3.8, 2.4, 3.5, 1.2, 2.0, 1.1)
	d.light_at(d.pp(), 4.0)
	_face_foe()
	if tt > 0.35 and d.once("ward_cast"):
		d.cast(3)
	if tt > 0.9 and d.once("ward_bolt"):
		d.press(d.slot_action(0))
	if tt > 1.8 and d.once("ward_bolt_up"):
		d.release(d.slot_action(0))


func _e_spell_ward() -> void:
	d._release_inputs()
	d.clear_spawned()
	d.cam.fov = 62.0


# --- the Umbral Well, from above: the pack dragged to its heart ------------------------------------------

func _s_spell_arcana() -> void:
	_swap(1, SKILL_WELL)
	_swap(3, SKILL_FAMILIAR)
	d.key.light_energy = 7.0
	d.key.omni_range = 30.0
	d.put_player(d.ARENA + Vector3(-6.0, 0.0, 2.0), d.WEST)
	d.spawn_pack(d.ARENA + Vector3(-6.0, 0.0, 2.0), d.WEST, 8.0)
	d.use_free_cam()
	d.cam.fov = 55.0


func _u_spell_arcana(tt: float) -> void:
	var mid: Vector3 = d.pp().lerp(d.pack_mid(), 0.5)
	d.top_down(mid, clampf(d.pp().distance_to(d.pack_mid()) * 0.8 + 4.0, 8.0, 11.0), 55.0)
	d.light_at(mid, 6.0)
	_face_foe()
	if tt > 0.1 and d.once("arc_fam"):
		d.cast(3)                                       # the familiar steps out of the dark
	if tt > 0.7 and d.once("arc_well"):
		d.cast(1)                                       # the Umbral Well opens under the pack
	if tt > 1.4 and d.once("arc_bolt"):
		d.press(d.slot_action(0))


func _e_spell_arcana() -> void:
	d._release_inputs()
	d.clear_spawned()
	_restore_slots()
	for n in d.get_tree().get_nodes_in_group(&"bound_shade"):
		(n as Node).queue_free()
	d.key.light_energy = 3.0
	d.key.omni_range = 24.0
	d.cam.fov = 62.0


# --- the Familiar fights beside the wanderer -----------------------------------------------------------------

func _s_familiar() -> void:
	_swap(3, SKILL_FAMILIAR)
	_fight_pack(7.5)
	d.use_free_cam()
	d.cam.fov = 50.0


func _u_familiar(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 2.2, 0.0, 1.0))
	var mid: Vector3 = d.pp().lerp(d.pack_mid(), 0.3)
	cam.orbit(mid, k, 5.5, 4.6, 1.2, 2.2, 1.6, 2.2, 1.0)
	d.light_at(mid, 5.0)
	_face_foe()
	if tt > 0.15 and d.once("fam_cast"):
		d.cast(3)
	if tt > 0.6 and d.once("fam_bolt"):
		d.press(d.slot_action(0))


func _e_familiar() -> void:
	d._release_inputs()
	d.clear_spawned()
	_restore_slots()
	for n in d.get_tree().get_nodes_in_group(&"bound_shade"):
		(n as Node).queue_free()
	d.cam.fov = 62.0


# --- Gloom and the Shade: out of the light, the dark takes shape behind --------------------------------------

func _s_gloom_shade() -> void:
	d.hollow_ok = true
	d.clear_spawned()
	d.put_player(d.ARENA + Vector3(-30.0, 0.0, 0.0), -d.WEST)
	d.p.gloom = d.p.gloom_max
	d.drive(d.fwd_of(-d.WEST), true)
	d._drive = d._drive_to
	d.use_free_cam()
	d.cam.fov = 58.0


func _u_gloom_shade(tt: float) -> void:
	d.p.gloom = maxf(d.p.gloom, d.p.gloom_max * 0.96)
	var f: Vector3 = d.fwd_of(-d.WEST)
	if tt > 0.3 and is_instance_valid(d.p._shade) and d.once("shade_close"):
		d.p._shade.global_position = d.p.global_position - f * 8.0 + Vector3.UP * 3.4     # it has been gaining on the runner
	# the lens runs ahead of the wanderer, low, looking back down the road at the Shade
	var k: float = d.sm(clampf(tt / 2.4, 0.0, 1.0))
	d.frame_cam(d.pp() + f * lerpf(3.6, 2.8, k) + Vector3.UP * 0.9 + f.cross(Vector3.UP) * 0.7, d.pp() - f * 5.0 + Vector3.UP * 2.4)
	d.light_at(d.pp(), 3.0)


func _e_gloom_shade() -> void:
	d.hollow_ok = false
	d.drive(Vector3.ZERO)
	if is_instance_valid(d.p._shade):
		(d.p._shade as Node).queue_free()
	d.p.gloom = 0.0
	d.cam.fov = 62.0


# --- loot: a foe falls, the bag stands in its beam, the wanderer takes it -------------------------------------

func _s_loot() -> void:
	d.clear_spawned()
	d.put_player(d.ARENA, d.WEST)
	_husk = d.spawn(d.HUSK_P, d.ARENA + d.fwd_of(d.WEST) * 5.0)
	d.use_free_cam()
	d.cam.fov = 50.0


func _u_loot(tt: float) -> void:
	var f: Vector3 = d.fwd_of(d.WEST)
	var side := f.cross(Vector3.UP)
	var bag := d.get_tree().get_first_node_in_group("loot_bag") as Node3D
	var spot: Vector3 = bag.global_position if bag else d.ARENA + f * 4.0
	var focus: Vector3 = d.pp().lerp(spot, 0.6) if bag else spot
	d.frame_cam(d.on_ground(focus + side * 3.8 - f * 1.0, 1.1), focus + Vector3.UP * 0.8)
	d.light_at(spot, 3.0)
	if is_instance_valid(_husk) and tt < 0.9:
		d.aim_at(_husk.global_position)
		if tt > 0.15 and d.once("loot_bolt"):
			d.press(d.slot_action(0))
	if tt > 0.7 and d.once("loot_fall"):
		d.release(d.slot_action(0))
		var at: Vector3 = d.on_ground(spot, 0.0)
		if is_instance_valid(_husk):
			at = _husk.global_position
			_husk.call("take_hit", 9999.0, d.p)
		var gear: Node = d.get_tree().get_first_node_in_group("gear")
		if gear:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 41
			var piece: Dictionary = GearDB.make(rng, {"rarity": 3, "uid": 99001})
			gear.call("drop_bag", [{"kind": "gear", "piece": piece}, {"kind": "item", "id": "grave_ash", "n": 7}], at, "the remains")
		d.drive(Vector3.ZERO)
	if tt > 1.0 and bag:
		d.aim_at(bag.global_position)
		if bag.global_position.distance_to(d.p.global_position) > 1.6:
			d.drive((bag.global_position - d.p.global_position).normalized() * 0.55)
		else:
			d.drive(Vector3.ZERO)


func _e_loot() -> void:
	d._release_inputs()
	d.drive(Vector3.ZERO)
	for b in d.get_tree().get_nodes_in_group("loot_bag"):
		(b as Node).queue_free()
	d.cam.fov = 62.0


# --- the slide, on the game's camera -------------------------------------------------------------------------

func _s_slide() -> void:
	d.put_player(d.ARENA + Vector3(24.0, 0.0, 0.0), d.WEST, -0.16)   # clear for 16 m west: from +14 the road met a cottage wall
	d.drive(d.fwd_of(d.WEST), true)
	d._drive = d._drive_to
	d.use_player_cam()


func _u_slide(tt: float) -> void:
	d.light_at(d.pp(), 4.0)
	if tt > 0.5 and d.once("sl_in"):
		d.press("slide")
	if tt > 1.3 and d.once("sl_out"):
		d.release("slide")


func _e_slide() -> void:
	d.release("slide")
	d.drive(Vector3.ZERO)


# --- weather: the drizzle comes in, then the mist ----------------------------------------------------------------

func _s_rain_mist() -> void:
	var wx: Node = d.life.get("weather") if d.life else null
	if wx:
		wx.call("force", "drizzle", true)
	d.put_player(d.ARENA + Vector3(-8.0, 0.0, 0.0), d.WEST, -0.02)
	d.drive(d.fwd_of(d.WEST) * 0.5)
	d.use_free_cam()
	d.cam.fov = 55.0


func _u_rain_mist(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 1.6, 0.0, 1.0))
	var f: Vector3 = d.fwd_of(d.WEST)
	d.frame_cam(d.pp() - f * lerpf(4.5, 3.6, k) + Vector3.UP * 1.5 + f.cross(Vector3.UP) * -1.0, d.pp() + f * 8.0 + Vector3.UP * 1.8)
	d.light_at(d.pp(), 4.0)
	if tt > 0.7 and d.once("mist_in"):
		var wx: Node = d.life.get("weather") if d.life else null
		if wx:
			wx.call("force", "mist", true)


func _e_rain_mist() -> void:
	var wx: Node = d.life.get("weather") if d.life else null
	if wx:
		wx.call("force", "clear", true)
	d.drive(Vector3.ZERO)
	d.cam.fov = 62.0


# --- the herd on the flats ----------------------------------------------------------------------------------------

func _herd_mid() -> Vector3:
	var ps: Array = _herd.call("positions")
	if ps.is_empty():
		return _herd.get("center")
	var c := Vector3.ZERO
	for v: Vector3 in ps:
		c += v
	return c / float(ps.size())


func _s_wildlife_herd() -> void:
	_herd = null
	var best := 0
	for g in (d.life.get("groups") as Array if d.life else []):
		if is_instance_valid(g) and String(g.get("kind")) in ["deer", "elk", "stag"]:
			var n := (g.call("positions") as Array).size()
			if OS.get_environment("HERD_AT") != "":
				var pr := OS.get_environment("HERD_AT").split(",")
				n = 100 - int((g as Node3D).global_position.distance_to(Vector3(float(pr[0]), (g as Node3D).global_position.y, float(pr[1]))))
			if n > best:
				best = n
				_herd = g
	d.use_free_cam()
	d.cam.fov = 40.0
	if _herd == null:
		print("TRAILER no herd")
		return
	var at := _herd_mid()
	d.put_player(at + Vector3(35.0, 0.0, 0.0), -d.WEST)
	_herd_cam = d.solve_cam([at + Vector3.UP * 1.2], at, d.yaw_to(Vector3(-0.6, 0, -0.8)), 9.0, 3.0)   # from the west: the herd against the gate's ember post, the lamp posts of the gate behind the lens
	d.hold_cam(_herd_cam, at + Vector3.UP * 1.0)


func _u_wildlife_herd(_tt: float) -> void:
	if _herd == null or not is_instance_valid(_herd):
		return
	d.hold_cam(_herd_cam, _herd_mid() + Vector3.UP * 1.0)
	d.light_at(_herd_mid(), 6.0)


func _e_wildlife_herd() -> void:
	d.cam.fov = 62.0

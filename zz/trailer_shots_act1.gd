extends RefCounted
## Act I shots (the last fire): the village, the Keg, the HUD and the menus.
## `d` is the director (zz/trailer.gd). The existing cold / tavern / run_game shots live there.

const Cam := preload("res://zz/trailer_cam.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const GREEN := Vector3(2.0, 0.0, 34.0)

var d
var cam
var _patrons: Array[Node] = []
var _husk: Node3D
var _sh_cam := Vector3.ZERO


func _init(director: Object) -> void:
	d = director
	cam = Cam.new(director)


func _wake_villagers(at: Vector3, radius: float) -> void:
	for v in d._by_script("villager.gd"):
		var n3 := v as Node3D
		if n3 != null and n3.global_position.distance_to(at) < radius:
			n3.visible = true
			n3.process_mode = Node.PROCESS_MODE_INHERIT


func _stand_down_villagers() -> void:
	for v in d._by_script("villager.gd"):
		var n3 := v as Node3D
		if n3 != null:
			n3.visible = false
			n3.process_mode = Node.PROCESS_MODE_DISABLED


func _screen() -> CanvasLayer:
	return d.get_tree().get_first_node_in_group(&"character_screen") as CanvasLayer


# --- the village: the green at night, people about, a slow dolly -----------------------------------

func _s_village() -> void:
	_wake_villagers(GREEN, 40.0)
	d.put_player(GREEN + Vector3(-3.0, 0.0, 10.0), 0.0, -0.05)
	d.use_free_cam()
	d.cam.fov = 55.0
	d.drive(Vector3.ZERO)


func _u_village(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 2.4, 0.0, 1.0))
	var a: Vector3 = d.on_ground(GREEN + Vector3(-13.0, 0.0, 20.0), 1.9)
	var b: Vector3 = d.on_ground(GREEN + Vector3(-5.0, 0.0, 17.0), 2.2)
	cam.dolly(a, b, d.on_ground(GREEN + Vector3(2.0, 0.0, 0.0), 1.5), k)
	d.light_at(GREEN, 6.0)


func _e_village() -> void:
	_stand_down_villagers()
	d.cam.fov = 62.0


# --- the Keg's song from a second angle -------------------------------------------------------------

func _s_keg_song() -> void:
	_patrons = d._by_script("dwarf_npc.gd")
	d.p.teleport(Vector3(11.4, -0.5, 27.0))
	for kk in d._by_script("keg_scenes.gd"):
		kk.call("play", "song")
	d.use_free_cam()
	d.cam.fov = 46.0


func _u_keg_song(tt: float) -> void:
	var c := Vector3(11.4, -0.5, 27.0)
	if not _patrons.is_empty():
		c = Vector3.ZERO
		var n := 0
		for pt in _patrons:
			if is_instance_valid(pt):
				c += (pt as Node3D).global_position
				n += 1
		c = c / float(maxi(n, 1))
	var a := lerpf(2.4, 1.9, d.sm(clampf(tt / 2.0, 0.0, 1.0)))
	d.frame_cam(c + Vector3(sin(a) * 2.4, 1.05, cos(a) * 2.4), c + Vector3.UP * 0.9)
	d.light_at(c, 2.0)


func _e_keg_song() -> void:
	d.cam.fov = 62.0


# --- the HUD: spell bar, minimap, compass, on the game's camera --------------------------------------

func _s_spellbar() -> void:
	d._s_fight_otc()
	d.keep_hud = true


func _u_spellbar(tt: float) -> void:
	d._u_fight_otc(tt)


func _e_spellbar() -> void:
	d._release_inputs()
	d.drive(Vector3.ZERO)
	d.clear_spawned()


# --- the menus, over the paused world ----------------------------------------------------------------

func _home_fire() -> void:
	var Hearth := load("res://core/life/progression/hearth.gd")
	for n in d.get_tree().get_nodes_in_group(Groups.BRAZIER):
		if Hearth.is_home_fire(n):
			d.p.teleport((n as Node).call("spawn_point"))
			return
	d.put_player(GREEN, 0.0)


## The world is paused behind a menu, so the lens is the free one, on the wanderer at the fire.
func _ui_cam() -> void:
	var me: Vector3 = d.p.global_position
	d.frame_cam(me + Vector3(1.6, 1.7, 3.4), me + Vector3.UP * 1.2)
	d.light_at(me, 4.0)


func _open_screen(top: String, page: String, from_fire: bool) -> void:
	var cs := _screen()
	if cs == null:
		return
	d.keep_menus = true
	d.keep_layers.append(cs)
	cs.call("open_at", top, page, from_fire)


func _close_screen() -> void:
	var cs := _screen()
	if cs != null and cs.call("is_open"):
		cs.call("close")
	d.get_tree().paused = false


func _s_hearth_tithe() -> void:
	_home_fire()
	d.use_free_cam()
	_open_screen("kindling", "hearth", true)


func _u_hearth_tithe(tt: float) -> void:
	_ui_cam()
	if tt > 0.7 and d.once("tithe_buy"):
		var hr: Node = d.get_tree().get_first_node_in_group(&"hearth")
		if hr:
			hr.call("tithe", "ward", true)              # the ash goes into the fire: the night-ward
			_close_screen()
			_open_screen("kindling", "hearth", true)


func _e_hearth_tithe() -> void:
	_close_screen()


func _s_kindling() -> void:
	_home_fire()
	d.use_free_cam()
	_open_screen("kindling", "spells", true)


func _u_kindling(tt: float) -> void:
	_ui_cam()
	if tt > 1.0 and d.once("kin_oaths"):
		var cs := _screen()
		if cs:
			cs.call("open_at", "kindling", "oaths", true)


func _e_kindling() -> void:
	_close_screen()


func _s_gear() -> void:
	var GearRuntime := load("res://core/items/gear_runtime.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for r in [1, 2, 3, 2, 3, 4, 1, 2]:
		GearRuntime.store(GearDB.make(rng, {"rarity": r, "uid": 98000 + int(rng.randi() % 900)}))
	_home_fire()
	d.use_free_cam()
	_open_screen("wanderer", "gear", false)


func _u_gear(_tt: float) -> void:
	_ui_cam()


func _e_gear() -> void:
	_close_screen()


# --- the staff: a heavy blow, and the parry ------------------------------------------------------------

func _s_staff_heavy() -> void:
	d.clear_spawned()
	d.put_player(d.ARENA, d.WEST)
	_husk = d.spawn(d.WRETCH_P, d.ARENA + d.fwd_of(d.WEST) * 2.4)
	if _husk:
		_husk.set("max_hp", 9999)
		_husk.set("hp", 9999.0)
	# side-on, a little in front of the pair, so the wretch and the swing both read (the game's lens sat behind the wanderer)
	d.use_free_cam()
	d.cam.fov = 48.0
	var mid: Vector3 = d.ARENA + d.fwd_of(d.WEST) * 1.2
	_sh_cam = d.solve_cam([mid + Vector3.UP * 1.0, mid + Vector3.UP * 1.9, d.ARENA + d.fwd_of(d.WEST) * 2.8 + Vector3.UP * 1.0], mid, Cam.yaw_dir(Vector3(0.0, 0.0, 1.0)) + PI + 0.0, 5.0, 1.6)
	d.hold_cam(_sh_cam, mid + Vector3.UP * 1.1)


func _u_staff_heavy(tt: float) -> void:
	d.light_at(d.pp() + d.fwd_of(d.WEST) * 1.2, 3.0)
	d.hold_cam(_sh_cam, d.pp() + d.fwd_of(d.WEST) * 1.2 + Vector3.UP * 1.1)
	if is_instance_valid(_husk):
		d.aim_at(_husk.global_position)
	if tt > 0.1 and d.once("sh_hold"):
		Input.action_press("staff_strike")
	if tt > 1.2 and d.once("sh_go"):
		Input.action_release("staff_strike")


func _e_staff_heavy() -> void:
	d.cam.fov = 62.0
	Input.action_release("staff_strike")
	d.clear_spawned()


func _s_staff_parry() -> void:
	d.clear_spawned()
	d.put_player(d.ARENA, d.WEST)
	_husk = d.spawn(d.WRETCH_P, d.ARENA + d.fwd_of(d.WEST) * 2.3)
	if _husk:
		_husk.set("max_hp", 9999)
		_husk.set("hp", 9999.0)
		if _husk.has_method("on_engaged"):
			_husk.call("on_engaged", d.p)
	d.use_free_cam()
	d.cam.fov = 50.0


func _u_staff_parry(tt: float) -> void:
	var f: Vector3 = d.fwd_of(d.WEST)
	var mid: Vector3 = d.pp().lerp(_husk.global_position if is_instance_valid(_husk) else d.pp() + f * 2.0, 0.5)
	d.frame_cam(mid + f.cross(Vector3.UP) * 4.2 + Vector3.UP * 1.5, mid + Vector3.UP * 1.1)
	d.light_at(mid, 4.0)
	if is_instance_valid(_husk):
		d.aim_at(_husk.global_position)
		if int(_husk.get("_state")) == Enemy.WINDUP and d.once("sp_guard"):
			Input.action_press("guard")
	if tt > 1.5 and d.once("sp_up"):
		Input.action_release("guard")


func _e_staff_parry() -> void:
	Input.action_release("guard")
	d.clear_spawned()
	d.cam.fov = 62.0

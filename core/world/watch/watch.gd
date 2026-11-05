extends Node3D
## r36 the Kindled Watch (docs/critique/r36_plan.md, step 4): small posts on the roads between the far
## countries, each held by three watchmen with swords (villager rigs; the village's chop and kneel
## poses). While the wanderer is near, the dark comes at a post every so often: a handful of hollowed
## walk in from the dark and go for the watchmen (Enemy.focus). The watchmen meet them blade to
## blade; the wanderer can help. A post that holds pays grave ash and its favour (every third hold, a
## piece of gear from its quartermaster); a post whose watchmen are all down falls for a while.
## One node per post, built by WatchPosts (watch_posts.gd). Asleep (no per-frame work) while the
## wanderer is further than WAKE.
##   state: Travel.system_state("watch") = {held: {id: n}, fallen: {id: unix time}}

const VillagerScript := preload("res://core/life/village/villager.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
const ReachState := preload("res://core/world/night/reach_state.gd")

const WAKE := 70.0               ## the post wakes (watchmen, assaults) within this of the wanderer
const ASSAULT_R := 55.0          ## assaults only come while she is this close
const EVERY := Vector2(80.0, 140.0)   ## seconds between assaults
const COME_FROM := 15.0          ## metres out the dark comes from
const HP := 10.0                 ## a watchman's life
const BLOW := 1.0                ## what a hollowed's blow does to a watchman
const BLOW_EVERY := 1.6
const CUT := 1.1                 ## what a watchman's cut does
const REACH := 1.8
const GUARD_R := 14.0            ## watchmen leave the post for foes this close to it
const FALLEN_FOR := 150.0
const SWING := 1.7               ## the village's chop cycle; the cut lands at 0.62 of it

var id := ""
var title := ""
var face := Vector3.FORWARD
var men: Array[Node3D] = []
var hp: Array[float] = []
var _posts: Array[Vector3] = []
var _village: Node = null
var _awake := false
var _scan := 0.0
var _next := 30.0
var _wave: Array[Node3D] = []
var _blow_t := {}                ## enemy id -> seconds to its next blow
var _swing_t: Array[float] = []
var _fallen_t := 0.0
var _in_assault := false
var _light: OmniLight3D


func setup(wid: String, d: Dictionary, village: Node) -> void:
	id = wid
	title = String(d.name)
	_village = village
	var f: Vector2 = d.get("face", Vector2(0, -1))
	face = Vector3(f.x, 0.0, f.y).normalized()


func _ready() -> void:
	add_to_group(&"watch_post")
	set_meta(&"map_kind", "watch")
	set_meta(&"map_label", title)
	add_to_group("map_marker")
	_build_post()
	_next = randf_range(20.0, 40.0)


## Stakes in a broken ring, a banner pole, a lantern on a hook (a plain light: the dark is not kept
## off by it, as a fire would; the watch has to do that).
func _build_post() -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	var right := face.cross(Vector3.UP).normalized()
	for i in 11:
		var a := -2.1 + 4.2 * float(i) / 10.0
		var dir := face.rotated(Vector3.UP, a)
		var at := dir * 4.2
		var lean := Basis(dir.cross(Vector3.UP).normalized(), -0.35)
		k.box("wood", at + Vector3.UP * 0.55, Vector3(0.14, 1.2, 0.14), lean, false, 0.7)
	k.box("wood", -face * 1.5 + Vector3.UP * 1.6, Vector3(0.1, 3.2, 0.1), Basis.IDENTITY, false, 0.7)
	k.commit(self, "Post")
	# r36: the watch's banner is cloth, and the wind works along it from the pole
	Sway.flag(self, global_position - face * 1.5 + Vector3.UP * 2.75, atan2(-right.z, right.x), "plaster", Vector2(0.7, 0.85))
	for c in get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = 110.0
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.66, 0.34)
	_light.light_energy = 1.1
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 50.0
	_light.distance_fade_length = 12.0
	_light.position = -face * 1.5 + Vector3.UP * 2.2
	add_child(_light)


func _wake() -> void:
	_awake = true
	if _village == null:
		# the village is built after the posts: find its director when the post first wakes
		for vn in get_tree().get_nodes_in_group("villager"):
			_village = vn.get("village")
			if _village != null:
				break
	if not men.is_empty() or _village == null:
		return
	var right := face.cross(Vector3.UP).normalized()
	_posts = [face * 2.4 + right * -1.6, face * 2.8, face * 2.4 + right * 1.6]
	for i in 3:
		var v: Node3D = VillagerScript.new()
		var vid := "watch_%s_%d" % [id, i]
		v.call("setup", vid, _man(i), _village)
		add_child(v)
		v.remove_from_group(Groups.INTERACTABLE)
		v.remove_from_group("villager")          # not Hearthward's: they walk off its floor map
		v.global_position = _ground(global_position + _posts[i])
		v.call("hold", "idle", v.global_position + face * 5.0)
		men.append(v)
		hp.append(HP * ReachState.watch_hp_mult(global_position))
		_swing_t.append(0.0)


func _sleep() -> void:
	_awake = false
	for v in men:
		if is_instance_valid(v):
			v.queue_free()
	men.clear()
	hp.clear()
	_swing_t.clear()


## The Watch's two uniforms (a hooded coat and a capped one, the same grey-brown, a sword in the right
## hand). Two looks, not one each, so only two meshes are ever built: WatchPosts prewarms both while
## the Realm loads, and a post that wakes in play builds nothing (each was a 250 ms stall).
const LOOKS := [
	{"seed": 7711, "sex": "m", "age": "adult", "garment": "coat", "hood": true, "hat": "", "beard": "short", "r": "sword", "girth": 1.04,
		"cloth": Color(0.25, 0.21, 0.2), "cloth2": Color(0.2, 0.17, 0.16), "leather": Color(0.3, 0.2, 0.12), "skin": Color(0.7, 0.52, 0.4)},
	{"seed": 7723, "sex": "m", "age": "adult", "garment": "coat", "hood": false, "hat": "cap", "beard": "", "r": "sword", "girth": 1.0,
		"cloth": Color(0.25, 0.21, 0.2), "cloth2": Color(0.2, 0.17, 0.16), "leather": Color(0.3, 0.2, 0.12), "skin": Color(0.62, 0.46, 0.36)},
]


func _man(i: int) -> Dictionary:
	return {"name": "Watchman", "camp": "watch", "fearless": true, "speed": 1.6, "routines": {}, "rig": (LOOKS[i % 2] as Dictionary).duplicate()}


func _physics_process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 1.0
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		var d := p.global_position.distance_to(global_position) if p else INF
		if d < WAKE and not _awake:
			_wake()
		elif d > WAKE + 10.0 and _awake and _wave.is_empty():
			_sleep()
		if _awake and _wave.is_empty() and _fallen_t <= 0.0 and d < ASSAULT_R:
			_next -= 1.0
			if _next <= 0.0:
				_assault()
	if not _awake:
		return
	if _fallen_t > 0.0:
		_fallen_t -= delta
		if _fallen_t <= 0.0:
			_rise()
		return
	_fight(delta)


## The dark comes: 3 hollowed (more as the post has held), walking in from where its light ends.
func _assault() -> void:
	_next = randf_range(EVERY.x, EVERY.y)
	_in_assault = true
	var held := int((_state().held as Dictionary).get(id, 0))
	var n := clampi(int(round(float(3 + held / 2) * ReachState.pressure())), 3, 7)
	var host := get_parent()
	for i in n:
		var a := randf_range(-1.2, 1.2)
		var at := _ground(global_position + face.rotated(Vector3.UP, a) * COME_FROM)
		var e: Enemy = ((Husk as GDScript) if i % 3 == 2 else (Wretch as GDScript)).new() as Enemy
		e.set_meta(&"watch", id)
		host.add_child(e)
		e.global_position = at + Vector3.UP * 0.05
		e.focus = men[i % men.size()] if not men.is_empty() else null
		_wave.append(e)
	Events.toast.emit("%s: the dark comes at the watch." % title)


func _fight(delta: float) -> void:
	# who is still coming
	for i in range(_wave.size() - 1, -1, -1):
		if not is_instance_valid(_wave[i]) or not (_wave[i] as Enemy).is_alive():
			_wave.remove_at(i)
	if _wave.is_empty() and _in_assault:
		_in_assault = false
		_blow_t.clear()
		_held()
	var standing := 0
	for m in men.size():
		var v := men[m]
		if not is_instance_valid(v):
			continue
		if hp[m] <= 0.0:
			continue
		standing += 1
		var foe := _nearest_foe(v)
		if foe == null:
			_go_post(m)
			continue
		var d := foe.global_position.distance_to(v.global_position)
		if d > REACH:
			if v.get("pinned"):
				v.call("release")
			var to := foe.global_position - v.global_position
			to.y = 0.0
			v.set("follow", foe.global_position - to.normalized() * (REACH - 0.4))
			_swing_t[m] = 0.0
		else:
			if String(v.get("act")) != "chop" or not bool(v.get("pinned")):
				v.call("hold", "chop", foe.global_position)
				_swing_t[m] = 0.0
			(_village.get("anchors") as Dictionary)["@block_" + String(v.get("id"))] = foe.global_position + Vector3.UP * 0.6
			var was := fposmod(_swing_t[m], SWING) / SWING
			_swing_t[m] += delta
			var now := fposmod(_swing_t[m], SWING) / SWING
			if was < 0.62 and now >= 0.62:
				foe.take_hit(CUT, null)
				Vfx.burst(foe.global_position + Vector3.UP, Color(0.9, 0.85, 0.8), {"count": 6, "life": 0.3, "speed": Vector2(1.0, 3.0), "size": 0.03, "gravity": -6.0})
		# blows on him from foes at his side
		for e2 in _wave:
			if not is_instance_valid(e2):
				continue
			var en := e2 as Enemy
			if en == null or en.global_position.distance_to(v.global_position) > en.strike_range + 0.5:
				continue
			var key := en.get_instance_id()
			var t := float(_blow_t.get(key, BLOW_EVERY * 0.6)) - delta
			if t <= 0.0:
				t = BLOW_EVERY
				hp[m] -= BLOW
				if hp[m] <= 0.0:
					_down(m)
			_blow_t[key] = t
	if standing == 0 and not men.is_empty():
		_fall()


func _nearest_foe(v: Node3D) -> Enemy:
	var best: Enemy = null
	var bd := INF
	for e in _wave:
		if not is_instance_valid(e):
			continue
		var en := e as Enemy
		if en == null or not en.is_alive():
			continue
		if en.global_position.distance_to(global_position) > GUARD_R + 4.0:
			continue
		var d := en.global_position.distance_to(v.global_position)
		if d < bd:
			bd = d
			best = en
	return best


func _go_post(m: int) -> void:
	var v := men[m]
	var post := _ground(global_position + _posts[m])
	if v.global_position.distance_to(post) > 0.6:
		if v.get("pinned"):
			v.call("release")
		v.set("follow", post)
	elif v.get("follow") != null or String(v.get("act")) != "idle":
		v.call("hold", "idle", v.global_position + face * 5.0)


func _down(m: int) -> void:
	var v := men[m]
	v.set_meta(&"down", true)
	v.call("hold", "kneel", v.global_position + face)
	for e in _wave:
		if is_instance_valid(e) and (e as Enemy).focus == v:
			(e as Enemy).focus = _standing_man()


func _standing_man() -> Node3D:
	for m in men.size():
		if hp[m] > 0.0 and is_instance_valid(men[m]):
			return men[m]
	return null


## The wave is broken with a watchman standing: the post holds.
func _held() -> void:
	var st := _state()
	var held: Dictionary = st.held
	held[id] = int(held.get(id, 0)) + 1
	var n := int(held[id])
	Travel.give("grave_ash", 6, false)
	var line := "%s holds. (+6 grave ash)" % title
	if n % 3 == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var piece := GearDB.make(rng, {"rarity": 2 if n >= 6 else 1})
		var got := GearRuntime.store(piece)
		line += "  The quartermaster gives you %s." % String(piece.get("name", "gear"))
		if got != "":
			Events.toast.emit(got)
	Events.toast.emit(line)
	Travel.save_soon()
	for m in men.size():
		hp[m] = minf(HP, hp[m] + HP * 0.5)
		if hp[m] > 0.0 and is_instance_valid(men[m]):
			men[m].set_meta(&"down", false)


func _fall() -> void:
	_fallen_t = FALLEN_FOR
	Events.toast.emit("%s has fallen. Its watchmen will get up again, if the dark lets them." % title)
	for e in _wave:
		if is_instance_valid(e):
			(e as Enemy).focus = null
	_wave.clear()
	_blow_t.clear()
	_in_assault = false


func _rise() -> void:
	for m in men.size():
		hp[m] = HP
		if is_instance_valid(men[m]):
			men[m].set_meta(&"down", false)
			men[m].call("hold", "idle", men[m].global_position + face * 5.0)


func _state() -> Dictionary:
	var st := Travel.system_state("watch")
	if not (st.get("held") is Dictionary):
		st["held"] = {}
	return st


func _ground(at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 30.0, Layers.WORLD))
	return (hit.position as Vector3) if not hit.is_empty() else at


## Tests and the map.
func info() -> Dictionary:
	return {"id": id, "awake": _awake, "men": men.size(), "standing": hp.filter(func(h: float) -> bool: return h > 0.0).size(),
		"wave": _wave.size(), "fallen": _fallen_t > 0.0}

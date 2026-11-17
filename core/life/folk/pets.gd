extends Node3D
## THE VILLAGE'S ANIMALS (folk stage): three dogs and two cats, a MultiMesh each (the wildlife's own creature shader and
## the same gait rig, so a gait, a head and a tail are drawn by the GPU: nothing here but five formulas). Hearthward's dogs
## belong to someone: each follows its person at a trot (a run when far behind), sits when they stop, sniffs about, and
## comes to the wanderer when he is near, circles him and sits at his feet. They bark at any foe within 28 m (the
## head up and thrown with the bark, the body turned to it) and, when the moon goes out, run for the Keg's door and
## are gone until it returns. The cats sit on cottage roofs: watching the wanderer with the head turning to follow
## him, grooming, stretching, and leaping to another roof when he runs close. All rates are formulas of dt, the body
## turns and speeds ease with `1 - exp(-k dt)`; nothing runs beyond SLEEP_R metres from the camera. The dogs and the cats
## have bodies of their own (wildlife/life_pet_mesh.gd, in the fox's frame so the creature shader's gait is shared): two MultiMeshes.

const Kit := preload("res://core/life/wildlife/life_kit.gd")
const Group := preload("res://core/life/wildlife/life_group.gd")
const Reg := preload("res://core/world/night_life/night_registry.gd")
const Windows := preload("res://core/world/night_life/living_windows.gd")
const Roles := preload("res://core/life/folk/folk_roles.gd")

enum { FOLLOW, SIT, SNIFF, BARK, GREET, HIDE, ROOF, GROOM, STRETCH, LEAP, STARE }

const SLEEP_R := 130.0
const GAIT_K := 2.6                        ## gait radians per metre (the fox's)
const BARK_R := 28.0
const DOGS := ["watchman", "porter", "talk_b", "shepherd"]       ## whose dogs they are (folk ids)

var ctx: Dictionary = {}
var _mm: MultiMeshInstance3D          ## the dogs
var _mmc: MultiMeshInstance3D         ## the cats (their own mesh: life_pet_mesh.gd)
var _buf := PackedFloat32Array()
var _bufc := PackedFloat32Array()
var _nd := 0                          ## dogs come first in the arrays: index < _nd is a dog
var _n := 0
var _built := false
var _wait := 0.0
var _scan := 0.0
var _foe := Vector3.INF
var _foe_t := 0.0
var _gy_t := 0.0
var _hidden_all := false

# per pet (parallel arrays)
var _kind := PackedInt32Array()            ## 0 dog, 1 cat
var _pos := PackedVector3Array()
var _yaw := PackedFloat32Array()
var _spd := PackedFloat32Array()
var _gait := PackedFloat32Array()
var _head := PackedFloat32Array()          ## head yaw, body-relative
var _pitch := PackedFloat32Array()
var _tilt := PackedFloat32Array()
var _scale := PackedFloat32Array()
var _state := PackedInt32Array()
var _t := PackedFloat32Array()             ## time in the state
var _next := PackedFloat32Array()          ## state clock to the next idle thing
var _owner: Array = []                     ## folk id (dogs) or ""
var _ground := PackedFloat32Array()
var _spots: Array = []                     ## cats: [Vector3 roof, Vector3 roof]
var _at := PackedInt32Array()              ## cats: which roof


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	visible = Reg.enabled
	if not Reg.enabled:
		return
	if not _built:
		_build_step(delta)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dt := minf(delta, 0.1)
	var near := cam.global_position.distance_to(_pos[0]) < SLEEP_R or cam.global_position.distance_to(_pos[_n - 1]) < SLEEP_R
	_mm.visible = near
	_mmc.visible = near
	if not near:
		return
	_scan -= dt
	if _scan <= 0.0:
		_scan = 0.5
		_watch(cam.global_position)
	_gy_t -= dt
	var ray := _gy_t <= 0.0
	if ray:
		_gy_t = 0.3
	for i in _n:
		_step(i, dt, ray)
		_draw(i)
	_mm.multimesh.buffer = _buf
	_mmc.multimesh.buffer = _bufc


## Once the folk are standing and the houses are known: the pets are made in one go (the fox body is a cache hit).
func _build_step(delta: float) -> void:
	_wait += delta
	if _wait < 2.5 or not bool(ctx.get("ready", false)):
		return
	var folk: Array = ctx.folk
	for who: String in DOGS:
		for f: Variant in folk:
			if String(f.id) == who:
				var p: Vector3 = (f as Node3D).global_position + Vector3(1.5, 0.0, 1.0)
				_add(0, p, who)
	# two cats on the roofs nearest the green
	var roofs := _roofs()
	if roofs.size() >= 2:
		_spots = roofs
		for c in 2:
			var i := _add(1, roofs[c] as Vector3, "")
			_at[i] = c
			_state[i] = ROOF
	_n = _kind.size()
	if _n == 0:
		_built = true
		return
	_nd = _kind.count(0)
	_mm = Kit.group("dog", maxi(_nd, 1))
	_mm.name = "Dogs"
	_mmc = Kit.group("cat", maxi(_n - _nd, 1))
	_mmc.name = "Cats"
	_buf.resize(maxi(_nd, 1) * 16)
	_bufc.resize(maxi(_n - _nd, 1) * 16)
	for mm: MultiMeshInstance3D in [_mm, _mmc]:
		mm.visibility_range_end = SLEEP_R + 20.0
		add_child(mm)
		mm.multimesh.custom_aabb = AABB(Vector3(-1000, -200, -1000), Vector3(2000, 600, 2000))
	_built = true


func _add(kind: int, p: Vector3, owner_id: String) -> int:
	_kind.append(kind)
	_pos.append(p)
	_yaw.append(randf() * TAU)
	_spd.append(0.0)
	_gait.append(0.0)
	_head.append(0.0)
	_pitch.append(0.0)
	_tilt.append(0.0)
	_scale.append(0.85 if kind == 0 else 0.78)
	_state.append(FOLLOW if kind == 0 else ROOF)
	_t.append(0.0)
	_next.append(4.0 + randf() * 6.0)
	_owner.append(owner_id)
	_ground.append(p.y)
	_at.append(0)
	return _kind.size() - 1


## Roof tops of the cottages nearest the green: a ray from above onto whatever solid is highest at the cottage's centre.
func _roofs() -> Array:
	var out: Array = []
	var world := get_world_3d()
	if world == null:
		return out
	var cs := Windows.centres()
	var by: Array = []
	for c: Vector3 in cs:
		by.append([Vector2(c.x, c.z).distance_to(Roles.GREEN), c])
	by.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for e: Array in by:
		var c: Vector3 = e[1]
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0.0, 14.0, 0.0), c + Vector3(0.0, -2.0, 0.0), 0xFFFF)
		var hit := world.direct_space_state.intersect_ray(q)
		if hit.is_empty():
			continue
		var top: Vector3 = hit.position
		if top.y > c.y + 2.2 and top.y < c.y + 9.0:
			out.append(top + Vector3(0.0, 0.02, 0.0))
		if out.size() >= 2:
			break
	return out


## The nearest foe within bark range, twice a second.
func _watch(cp: Vector3) -> void:
	_foe = Vector3.INF
	var best := BARK_R * BARK_R
	for n: Node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := n as Node3D
		if e == null or not e.is_inside_tree():
			continue
		for i in _n:
			if _kind[i] != 0:
				continue
			var d2 := e.global_position.distance_squared_to(_pos[i])
			if d2 < best:
				best = d2
				_foe = e.global_position
	_hidden_all = float(ctx.get("eclipse", 0.0)) > 0.5


func _folk_pos(id: String) -> Vector3:
	for f: Variant in ctx.get("folk", []):
		if String(f.id) == id and not bool(f.held):
			return (f as Node3D).global_position
	return Vector3.INF


func _step(i: int, dt: float, ray: bool) -> void:
	_t[i] += dt
	var p := _pos[i]
	var want_yaw := _yaw[i]
	var want_spd := 0.0
	var head_to := 0.0
	var pitch_to := 0.0
	var tilt_to := 0.0
	var player: Vector3 = ctx.get("player", Vector3.INF)
	var st := _state[i]
	if _kind[i] == 0:
		_dog(i, dt, st, player)
		st = _state[i]
		want_spd = _dog_speed(i)
		match st:
			SIT:
				tilt_to = 0.5
				pitch_to = 0.15
				head_to = _look_at(i, player, 4.0)
			SNIFF:
				pitch_to = -0.8
				head_to = 0.35 * sin(_t[i] * 1.7)
			BARK:
				want_yaw = atan2(-(_foe.x - p.x), -(_foe.z - p.z)) if _foe != Vector3.INF else _yaw[i]
				var pulse := pow(maxf(0.0, sin(_t[i] * 7.0)), 3.0)
				pitch_to = 0.15 + 0.3 * pulse
				tilt_to = 0.12 * pulse
			GREET:
				head_to = _look_at(i, player, 8.0)
				pitch_to = 0.1
			_:
				pass
		if st == FOLLOW or st == GREET:
			var tgt := _dog_target(i, player)
			var to := Vector2(tgt.x - p.x, tgt.z - p.z)
			if to.length() > 0.2 and _spd[i] > 0.1:
				want_yaw = atan2(-to.x, -to.y)
	else:
		_cat(i, dt, st, player)
		st = _state[i]
		match st:
			ROOF, STARE:
				tilt_to = 0.5
				pitch_to = 0.2
				head_to = _look_at(i, player, 16.0)
				if float(ctx.get("eclipse", 0.0)) > 0.5:
					pitch_to = 0.5
			GROOM:
				tilt_to = 0.55
				pitch_to = -0.9
				head_to = 0.5 * sin(_t[i] * 2.3)
			STRETCH:
				var s := sin(PI * clampf(_t[i] / 2.6, 0.0, 1.0))
				tilt_to = -0.35 * s
				pitch_to = -0.5 * s
			LEAP:
				pass
			_:
				pass
		if st == LEAP:
			want_spd = 0.0
	# ease everything with dt
	_yaw[i] = lerp_angle(_yaw[i], want_yaw, 1.0 - exp(-8.0 * dt))
	_spd[i] = lerpf(_spd[i], want_spd, 1.0 - exp(-5.0 * dt))
	_head[i] = lerpf(_head[i], head_to, 1.0 - exp(-6.0 * dt))
	_pitch[i] = lerpf(_pitch[i], pitch_to, 1.0 - exp(-7.0 * dt))
	_tilt[i] = lerpf(_tilt[i], tilt_to, 1.0 - exp(-6.0 * dt))
	_gait[i] += _spd[i] * GAIT_K * dt
	if _spd[i] > 0.02 and st != LEAP and st != HIDE:
		var fwd := Vector3(-sin(_yaw[i]), 0.0, -cos(_yaw[i]))
		_pos[i] += fwd * _spd[i] * dt
	if st == HIDE:
		_scale[i] = lerpf(_scale[i], 0.001, 1.0 - exp(-6.0 * dt))
	else:
		_scale[i] = lerpf(_scale[i], 0.85 if _kind[i] == 0 else 0.78, 1.0 - exp(-4.0 * dt))
	if _kind[i] == 0:
		if ray:
			var w := get_world_3d()
			if w != null:
				var q := PhysicsRayQueryParameters3D.create(_pos[i] + Vector3(0, 3, 0), _pos[i] + Vector3(0, -6, 0), Layers.WORLD)
				var hit := w.direct_space_state.intersect_ray(q)
				if not hit.is_empty():
					_ground[i] = (hit.position as Vector3).y
		var gp := _pos[i]
		gp.y = lerpf(gp.y, _ground[i], 1.0 - exp(-10.0 * dt))
		_pos[i] = gp


# --- dogs ------------------------------------------------------------------------------------------

func _dog_target(i: int, player: Vector3) -> Vector3:
	if _state[i] == GREET and player != Vector3.INF:
		return player + Vector3(0.9, 0.0, 0.6)
	var o: Vector3 = _folk_pos(String(_owner[i]))
	if o == Vector3.INF:
		return _pos[i]
	# a little behind and to one side of the person it follows
	return o + Vector3(1.4 + 0.3 * float(i), 0.0, 1.2)


func _dog_speed(i: int) -> float:
	var st := _state[i]
	if st == HIDE:
		return 5.0 if _pos[i].distance_to(_keg()) > 1.0 else 0.0
	if st != FOLLOW and st != GREET:
		return 0.0
	var tg := _dog_target(i, ctx.get("player", Vector3.INF))
	var d := Vector2(tg.x - _pos[i].x, tg.z - _pos[i].z).length()
	if d > 9.0:
		return 6.0
	if d > 3.0:
		return 3.2
	if d > 1.0:
		return 1.3
	return 0.0


func _keg() -> Vector3:
	var k := Roles.node_pos("keg_in", Vector2(17.6, 23.6))
	return Vector3(k.x, _pos[0].y, k.y)


func _dog(i: int, dt: float, st: int, player: Vector3) -> void:
	var p := _pos[i]
	# the eclipse: run for the door and be gone
	if _hidden_all:
		if st != HIDE:
			_state[i] = HIDE
			_t[i] = 0.0
		var door := _keg()
		var to := Vector2(door.x - p.x, door.z - p.z)
		if to.length() > 0.5:
			_yaw[i] = lerp_angle(_yaw[i], atan2(-to.x, -to.y), 1.0 - exp(-8.0 * dt))
		return
	if st == HIDE:
		_state[i] = FOLLOW
		_t[i] = 0.0
		return
	# a foe near: bark at it until it has gone
	if _foe != Vector3.INF and p.distance_to(_foe) < BARK_R:
		if st != BARK:
			_state[i] = BARK
			_t[i] = 0.0
		return
	if st == BARK:
		_state[i] = FOLLOW
		_t[i] = 0.0
		return
	var near_pl := player != Vector3.INF and p.distance_to(player) < 12.0 and (i == 1)
	if near_pl and st != GREET:
		_state[i] = GREET
		_t[i] = 0.0
		return
	if st == GREET and not near_pl:
		_state[i] = FOLLOW
		_t[i] = 0.0
		return
	var d := _dog_speed(i)
	if (st == FOLLOW or st == GREET) and d <= 0.01 and _spd[i] < 0.3 and _t[i] > 3.0:
		_state[i] = SIT if randf() < 0.6 else SNIFF
		_t[i] = 0.0
		_next[i] = 5.0 + randf() * 6.0
	elif (st == SIT or st == SNIFF) and (_t[i] > _next[i] or _dog_speed_far(i)):
		_state[i] = FOLLOW
		_t[i] = 0.0


func _dog_speed_far(i: int) -> bool:
	var o := _folk_pos(String(_owner[i]))
	return o != Vector3.INF and Vector2(o.x - _pos[i].x, o.z - _pos[i].z).length() > 5.0


# --- cats ------------------------------------------------------------------------------------------

func _cat(i: int, _dt: float, st: int, player: Vector3) -> void:
	match st:
		ROOF, STARE:
			if player != Vector3.INF and _pos[i].distance_to(player) < 5.5 and (ctx.get("player_speed", 0.0) as float) > 5.0 and _t[i] > 4.0:
				_leap(i)
				return
			if _t[i] > _next[i]:
				_state[i] = GROOM if randf() < 0.55 else STRETCH
				_t[i] = 0.0
				_next[i] = 7.0 + randf() * 12.0
		GROOM:
			if _t[i] > 4.5:
				_state[i] = ROOF
				_t[i] = 0.0
		STRETCH:
			if _t[i] > 2.6:
				_state[i] = ROOF
				_t[i] = 0.0
		LEAP:
			# a parabola between two roofs
			var from: Vector3 = _spots[1 - _at[i]]
			var to: Vector3 = _spots[_at[i]]
			var u := clampf(_t[i] / 1.1, 0.0, 1.0)
			_pos[i] = from.lerp(to, u) + Vector3(0.0, 1.6 * sin(PI * u), 0.0)
			_yaw[i] = lerp_angle(_yaw[i], atan2(-(to.x - from.x), -(to.z - from.z)), 0.3)
			_tilt[i] = lerpf(_tilt[i], lerpf(0.6, -0.5, u), 0.4)
			if u >= 1.0:
				_state[i] = ROOF
				_t[i] = 0.0


func _leap(i: int) -> void:
	_at[i] = 1 - _at[i]
	_state[i] = LEAP
	_t[i] = 0.0


func _look_at(i: int, target: Vector3, within: float) -> float:
	if target == Vector3.INF or _pos[i].distance_to(target) > within:
		return 0.0
	var d := target - _pos[i]
	var rel := wrapf(atan2(-d.x, -d.z) - _yaw[i], -PI, PI)
	return clampf(rel, -1.0, 1.0)


func _draw(i: int) -> void:
	var cd := Color(clampf(_spd[i] / 3.0, 0.0, 1.0), _head[i], _gait[i], _pitch[i])
	var p := _pos[i]
	if absf(_tilt[i]) > 0.001:
		Group.put(_buf if i < _nd else _bufc, i if i < _nd else i - _nd, Basis(Vector3.UP, _yaw[i]) * Basis(Vector3.RIGHT, _tilt[i]) * Basis.from_scale(Vector3.ONE * _scale[i]), p, cd)
	else:
		Group.put_yaw(_buf if i < _nd else _bufc, i if i < _nd else i - _nd, _yaw[i], _scale[i], p, cd)

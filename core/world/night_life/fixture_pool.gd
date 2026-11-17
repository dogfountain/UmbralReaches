extends Node3D
## FIXTURE POOL: real light for every source without one. A forge mouth, a chapel window, a graveyard lantern,
## a mystery in a ruin: each is a row in the night registry, but only a handful stand near the wanderer at once, so
## ten unshadowed omnis are lent to the nearest rows (within RANGE m) and follow the player round the Realm. A light
## eases its energy up on a new row and down when it is let go (never a pop). Class "player_orb": outside the
## LightDirector's budget, so the budget of lamps stays as tuned. One node, ten lights, no shadows.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const POOL_N := 10
const RANGE := 42.0
const TICK := 0.35

var _lights: Array[OmniLight3D] = []
var _row: PackedInt32Array = PackedInt32Array()       ## the registry row each light serves (-1 free)
var _goal: PackedFloat32Array = PackedFloat32Array()
var _t := 0.0
var _tick := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for i in POOL_N:
		var l := OmniLight3D.new()
		l.name = "Fixture%d" % i
		l.shadow_enabled = false
		l.light_energy = 0.0
		l.omni_range = 8.0
		l.omni_attenuation = 1.3
		l.light_specular = 0.2
		l.light_volumetric_fog_energy = 0.7
		l.set_meta("light_class", "player_orb")
		l.visible = false
		add_child(l)
		_lights.append(l)
		_row.append(-1)
		_goal.append(0.0)


func _process(delta: float) -> void:
	_t += delta
	var on := Reg.enabled
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		if on:
			_assign()
		else:
			for i in POOL_N:
				_row[i] = -1
	var boost := 1.0 + 0.35 * clampf(Reg.gain_mul - 1.0, 0.0, 1.0) / 0.6
	for i in POOL_N:
		var l := _lights[i]
		var r := _row[i]
		var goal := 0.0
		if r >= 0 and on:
			var k := int(Reg.kind[r])
			goal = _energy(k) * Reg.gain[r] * Reg.shimmer(r, _t) * boost
		l.light_energy = move_toward(l.light_energy, goal, delta * 5.0)
		l.visible = l.light_energy > 0.02
		if r >= 0 and l.visible:
			var p: Vector3 = Reg.pos[r]
			l.global_position = p


## The nearest rows without a light of their own take the lights; a light keeps its row while that row stays in range.
func _assign() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var best: Array = []                                # [dist2, row]
	for i in Reg.size():
		if Reg.on[i] == 0 or Reg.real[i] == 1 or int(Reg.kind[i]) == Reg.Kind.COLD:
			continue
		var d2 := cp.distance_squared_to(Reg.pos[i])
		if d2 < RANGE * RANGE:
			best.append([d2, i])
	best.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var want := {}
	for j in mini(best.size(), POOL_N):
		want[int((best[j] as Array)[1])] = true
	# release lights whose row left the wanted set (they fade down, then are reused)
	for i in POOL_N:
		var r := _row[i]
		if r >= 0 and not want.has(r):
			if _lights[i].light_energy <= 0.03:
				_row[i] = -1
			else:
				_goal[i] = 0.0
				_row[i] = -2 - r                        # fading: owns its light until dark
		elif r >= 0:
			want.erase(r)
	for i in POOL_N:
		var r := _row[i]
		if r <= -2:                                     # fading out
			if _lights[i].light_energy <= 0.03:
				_row[i] = -1
	for r: int in want.keys():
		for i in POOL_N:
			if _row[i] == -1:
				_row[i] = r
				_lights[i].light_color = Reg.colour(int(Reg.kind[r]))
				_lights[i].omni_range = _range(int(Reg.kind[r]))
				_lights[i].global_position = Reg.pos[r]
				break


static func _energy(k: int) -> float:
	match k:
		Reg.Kind.FIRE:
			return 2.6
		Reg.Kind.WINDOW:
			return 1.6
		Reg.Kind.MYSTERY:
			return 2.2
		Reg.Kind.TOWER:
			return 1.8
	return 1.0


static func _range(k: int) -> float:
	match k:
		Reg.Kind.FIRE:
			return 10.0
		Reg.Kind.WINDOW:
			return 6.5
		Reg.Kind.MYSTERY:
			return 9.0
	return 8.0

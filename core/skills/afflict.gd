extends Node
## Afflictions on enemies (skills, r28):
##   burn   ember damage every TICK for a while (Cinder Core bolts, Kindled Rift, a Maelstrom)
##   chill  rime: slows by CHILL_SLOW for CHILL_TIME; the third chill inside that freezes the foe in
##          place for FREEZE_TIME (Rime Core). A frozen foe takes double from the Lance and the
##          Nova (shatter(), the SHATTER combo) and thaws.
## Enemies carry no extra script: one manager node per scene ("Afflictions", made on first use)
## keeps a record per afflicted enemy and ticks them at 10 Hz. Speed changes share the Briar
## metas (`briar_base`, `briar_until`) so the Thorn Heart's roots and the rime never fight.
## Load by path (no class_name): const Afflict := preload("res://core/skills/afflict.gd")

const DB := preload("res://core/life/progression/upgrade_db.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Combo := preload("res://core/skills/combo.gd")

const TICK := 0.5
const BURN_DMG := 0.3
const CHILL_SLOW := 0.7
const CHILL_TIME := 2.0
const FREEZE_TIME := 1.2
const FREEZE_AT := 3
const EMBER := Color(2.8, 1.0, 0.3)
const RIME := Color(1.4, 2.4, 3.4)

static var _inst: Node
static var _ice_mesh: ArrayMesh
static var _ice_mat: StandardMaterial3D

var _rec := {}            ## enemy instance id -> record
var _step := 0.0


static func _mgr() -> Node:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	var host := Vfx.host()
	if host == null:
		return null
	var m: Node = new()
	m.name = "Afflictions"
	host.add_child(m)
	_inst = m
	return m


static func _rec_of(e: Node) -> Dictionary:
	var m := _mgr()
	if m == null or e == null or not is_instance_valid(e):
		return {}
	var recs: Dictionary = m.get("_rec")
	var id := e.get_instance_id()
	if not recs.has(id):
		var base := float(e.get_meta(&"briar_base", e.get("walk_speed")))
		if not e.has_meta(&"briar_base"):
			e.set_meta(&"briar_base", base)
		recs[id] = {"e": e, "base": base, "burn": 0.0, "burn_dmg": BURN_DMG, "burn_tick": TICK, "burn_n": 0,
			"chill": 0.0, "stacks": 0, "frozen": 0.0, "fx_burn": null, "fx_chill": null, "ice": null,
			"slow": 0.0, "slow_f": 1.0}
	return recs[id]


## Set `e` burning for `secs` (refreshes; the stronger tick wins).
static func burn(e: Node, secs := 2.0, dmg := BURN_DMG) -> void:
	if not _alive(e):
		return
	var r := _rec_of(e)
	if r.is_empty():
		return
	var fresh := float(r.burn) <= 0.0
	r.burn = maxf(float(r.burn), secs)
	r.burn_dmg = maxf(float(r.burn_dmg) if not fresh else 0.0, dmg)
	if fresh:
		r.burn_tick = TICK * 0.5
		var en := e as Node3D
		var fx := Vfx.emitter(EMBER, {"count": 22, "life": 0.6, "speed": Vector2(0.6, 1.8), "size": 0.05, "gravity": 1.6, "radius": 0.35, "turbulence": true, "trail": 0.05})
		fx.position = Vector3.UP * (float(e.get("hp_bar_y")) * 0.45 if e.get("hp_bar_y") != null else 0.9)
		en.add_child(fx)
		fx.emitting = true
		r.fx_burn = fx
		Vfx.burst(en.global_position + fx.position, EMBER, {"count": 14, "life": 0.35, "speed": Vector2(1.5, 3.5), "size": 0.045, "gravity": -3.0, "trail": 0.05})


## A plain slow (an Umbral Well's drag): speed x `factor` for `secs` (the stronger one wins).
static func slow(e: Node, factor: float, secs: float) -> void:
	if not _alive(e):
		return
	var r := _rec_of(e)
	if r.is_empty():
		return
	r.slow_f = minf(float(r.slow_f), factor) if float(r.slow) > 0.0 else factor
	r.slow = maxf(float(r.slow), secs)
	(_mgr() as Node).call("_apply_speed", r)


## One chill: slows; the FREEZE_AT-th inside the window freezes in place.
static func chill(e: Node, secs := CHILL_TIME) -> void:
	if not _alive(e):
		return
	var r := _rec_of(e)
	if r.is_empty():
		return
	var en := e as Node3D
	if float(r.frozen) > 0.0:
		return
	r.stacks = int(r.stacks) + 1 if float(r.chill) > 0.0 else 1
	r.chill = secs
	if r.fx_chill == null or not is_instance_valid(r.fx_chill):
		var fx := Vfx.emitter(RIME, {"count": 16, "life": 0.9, "speed": Vector2(0.1, 0.5), "size": 0.04, "gravity": -0.6, "radius": 0.45, "turbulence": true})
		fx.position = Vector3.UP * 1.0
		en.add_child(fx)
		fx.emitting = true
		r.fx_chill = fx
	Vfx.ring(en.global_position + Vector3.UP * 0.08, 0.5 + 0.2 * float(r.stacks), RIME, 0.3, 0.06, Vector3.UP, 1.0)
	if int(r.stacks) >= FREEZE_AT:
		_freeze(r)
	(_mgr() as Node).call("_apply_speed", r)


static func _freeze(r: Dictionary) -> void:
	var en := r.get("e") as Node3D
	r.frozen = FREEZE_TIME
	r.stacks = 0
	_ensure_ice()
	var ice := MeshInstance3D.new()
	ice.name = "Rime"
	ice.mesh = _ice_mesh
	ice.material_override = _ice_mat
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var h := float(en.get("hp_bar_y")) if en.get("hp_bar_y") != null else 2.0
	ice.scale = Vector3(1.0, h / 2.0, 1.0)
	en.add_child(ice)
	r.ice = ice
	Vfx.burst(en.global_position + Vector3.UP, RIME, {"count": 30, "life": 0.5, "speed": Vector2(1.5, 4.0), "size": 0.05, "gravity": -5.0, "trail": 0.05})
	StaffSfx.play("chill_hit", en.global_position, 0.0, 0.7)
	HitText.pop(en.global_position + Vector3.UP * (h + 0.5), "frozen", Color(0.7, 0.9, 1.0))
	Hints.once(&"frozen_shatter", "Frozen: the Lance, the Nova and a well's Event Horizon shatter the ice for double. The staff does not.")


static func is_frozen(e: Node) -> bool:
	if _inst == null or not is_instance_valid(_inst) or e == null:
		return false
	var r: Dictionary = (_inst.get("_rec") as Dictionary).get(e.get_instance_id(), {})
	return float(r.get("frozen", 0.0)) > 0.0


static func is_burning(e: Node) -> bool:
	if _inst == null or not is_instance_valid(_inst) or e == null:
		return false
	var r: Dictionary = (_inst.get("_rec") as Dictionary).get(e.get_instance_id(), {})
	return float(r.get("burn", 0.0)) > 0.0


## Damage multiplier for a heavy blow on `e`: 2 on a frozen foe (it shatters free), else 1.
static func shatter(e: Node) -> float:
	if not is_frozen(e):
		return 1.0
	var r: Dictionary = (_inst.get("_rec") as Dictionary)[e.get_instance_id()]
	r.frozen = 0.0
	r.chill = 0.0
	r.stacks = 0
	_inst.call("_thaw", r)
	var at := (e as Node3D).global_position + Vector3.UP
	Vfx.burst(at, Color(2.2, 3.0, 3.8), {"count": 46, "life": 0.6, "speed": Vector2(3.0, 8.0), "size": 0.06, "gravity": -9.0, "trail": 0.05})
	Vfx.burst(at, Color(0.7, 0.85, 1.0, 0.9), {"count": 18, "life": 0.9, "speed": Vector2(2.0, 5.0), "size": 0.12, "gravity": -12.0, "additive": false})
	SpellFx.shell(at, 0.2, 1.8, Color(1.2, 2.0, 3.0), 0.25)
	StaffSfx.play("shatter", at, 0.0)
	Combo.note("SHATTER", at + Vector3.UP * 0.6, Color(0.75, 0.92, 1.0), "x2 damage")
	return 2.0


static func _alive(e: Node) -> bool:
	return e != null and is_instance_valid(e) and e.is_inside_tree() and (not e.has_method("is_alive") or e.call("is_alive"))


static func _ensure_ice() -> void:
	if _ice_mesh != null:
		return
	# a crust of leaning shards round a 0.5 m column (scaled to the body's height)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for k in 11:
		var a := TAU * float(k) / 11.0 + rng.randf_range(-0.2, 0.2)
		var base := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.28, 0.45) + Vector3.UP * rng.randf_range(0.0, 0.9)
		var tip := base + Vector3(cos(a) * 0.25, rng.randf_range(0.6, 1.2), sin(a) * 0.25)
		var w := rng.randf_range(0.08, 0.14)
		var side := Vector3(-sin(a), 0.0, cos(a)) * w
		var out := Vector3(cos(a), 0.0, sin(a)) * w
		var ring: Array[Vector3] = [base + side, base + out, base - side, base - out]
		for i in 4:
			var p0 := ring[i]
			var p1 := ring[(i + 1) % 4]
			var n := (p1 - p0).cross(tip - p0).normalized()
			for v: Vector3 in [p0, tip, p1]:
				st.set_normal(-n)
				st.add_vertex(v)
	_ice_mesh = st.commit()
	_ice_mat = StandardMaterial3D.new()
	_ice_mat.albedo_color = Color(0.62, 0.82, 1.0, 0.55)
	_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ice_mat.roughness = 0.08
	_ice_mat.metallic_specular = 0.9
	_ice_mat.emission_enabled = true
	_ice_mat.emission = Color(0.35, 0.6, 1.0)
	_ice_mat.emission_energy_multiplier = 0.9
	_ice_mat.rim_enabled = true
	_ice_mat.rim = 0.8
	_ice_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _ready() -> void:
	process_physics_priority = 10


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _physics_process(delta: float) -> void:
	if _rec.is_empty():
		return
	_step += delta
	if _step < 0.1:
		return
	var dt := _step
	_step = 0.0
	var rosary := bool(DB.get_mod("rosary", false))
	var power := float(DB.get_mod("power", 1.0))
	for id: int in _rec.keys():
		var r: Dictionary = _rec[id]
		var ev: Variant = r.get("e")
		if not is_instance_valid(ev) or not _alive(ev as Node):
			_drop(id, r, false)
			continue
		var e := ev as Node
		if float(r.burn) > 0.0:
			r.burn = float(r.burn) - dt
			r.burn_tick = float(r.burn_tick) - dt
			if float(r.burn_tick) <= 0.0:
				r.burn_tick = TICK
				r.burn_n = int(r.burn_n) + 1
				if int(r.burn_n) == 1:
					HitText.pop((e as Node3D).global_position + Vector3.UP * (float(e.get("hp_bar_y")) + 0.35), "burning", Color(2.4, 1.0, 0.4))
				HitText.hush = true
				e.call("take_hit", float(r.burn_dmg) * power, null)
				HitText.hush = false
				if rosary and int(r.burn_n) % 2 == 0 and _alive(e):
					e.call("add_mark", 1)
			if float(r.burn) <= 0.0:
				_stop_fx(r, "fx_burn")
		var was_frozen := float(r.frozen) > 0.0
		if was_frozen:
			r.frozen = float(r.frozen) - dt
			if float(r.frozen) <= 0.0:
				_thaw(r)
		elif float(r.chill) > 0.0:
			r.chill = float(r.chill) - dt
			if float(r.chill) <= 0.0:
				r.stacks = 0
				_stop_fx(r, "fx_chill")
		if float(r.slow) > 0.0:
			r.slow = float(r.slow) - dt
			if float(r.slow) <= 0.0:
				r.slow_f = 1.0
		_apply_speed(r)
		if float(r.burn) <= 0.0 and float(r.chill) <= 0.0 and float(r.frozen) <= 0.0 and float(r.slow) <= 0.0:
			_drop(id, r, true)


func _apply_speed(r: Dictionary) -> void:
	var ev: Variant = r.get("e")
	if not is_instance_valid(ev):
		return
	var e := ev as Node
	var f := 1.0
	if float(r.frozen) > 0.0:
		f = 0.02
	elif float(r.chill) > 0.0:
		f = CHILL_SLOW
	if float(r.slow) > 0.0:
		f = minf(f, float(r.slow_f))
	if int(e.get_meta(&"briar_until", 0)) > Time.get_ticks_msec():
		f = minf(f, 0.45)
	e.set("walk_speed", float(r.base) * f)


func _thaw(r: Dictionary) -> void:
	r.frozen = 0.0
	if r.ice != null and is_instance_valid(r.ice):
		var ice := r.ice as MeshInstance3D
		var at := ice.global_position + Vector3.UP
		ice.queue_free()
		Vfx.burst(at, Color(0.8, 0.95, 1.0, 0.8), {"count": 10, "life": 0.6, "speed": Vector2(1.0, 2.5), "size": 0.08, "gravity": -9.0, "additive": false})
	r.ice = null
	_apply_speed(r)


func _stop_fx(r: Dictionary, key: String) -> void:
	var fx: Variant = r.get(key)
	if fx != null and is_instance_valid(fx):
		(fx as GPUParticles3D).emitting = false
		get_tree().create_timer(1.0, false).timeout.connect((fx as Node).queue_free)
	r[key] = null


func _drop(id: int, r: Dictionary, restore: bool) -> void:
	_stop_fx(r, "fx_burn")
	_stop_fx(r, "fx_chill")
	if r.ice != null and is_instance_valid(r.ice):
		(r.ice as Node).queue_free()
	if restore and is_instance_valid(r.get("e")):
		var e := r.get("e") as Node
		var briar := int(e.get_meta(&"briar_until", 0)) > Time.get_ticks_msec()
		e.set("walk_speed", float(r.base) * (0.45 if briar else 1.0))
	_rec.erase(id)

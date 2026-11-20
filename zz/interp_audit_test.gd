extends Node3D
## Physics interpolation audit. With the display at 120 Hz and physics at 60, every moving thing must be
## drawn at a new place on EVERY rendered frame and move without 60 Hz steps. A real Player walks a flat
## floor while a bolt flies, a Shade drifts in, a Familiar rides, a cage lift rises and the charge glow
## rides the staff; then the Tether line hauls. Each rendered frame logs where each is DRAWN (a node on
## physics interpolation: its interpolated transform; a node off it: its own transform on the drawn
## parent) and asserts, per subject:
##   (a) no duplicated frames (a tick-stepped node repeats its place every other frame at 120/60)
##   (b) for steady subjects, the frame-to-frame speed stays near its median (no 0 / 2x alternation)
##   godot --headless --path . res://zz/interp_audit_test.tscn

const BOLT := preload("res://core/player/magic_bolt.tscn")
const FamiliarScript := preload("res://core/skills/bound_shade.gd")
const HZ := 120
const TICKS := 60
const SETTLE := 1.6
const SPAN := 1.4
const DUP_FRAC := 0.12          ## a frame that moved less than this fraction of the median speed is a duplicate
const MAX_LAG := 0.06           ## m: how far a node riding the staff head may be from where the head is drawn
const MAX_BAD := 0.04           ## fraction of frames allowed to be a duplicate or an outlier (a hitch)

var bad := 0
var p: Player
var _subjects: Array = []      ## {name, get: Callable -> Vector3, steady: float (tolerance, 0 = skip)}
var _logs: Dictionary = {}     ## name -> Array of [Vector3, dt]
var _recording := false
var _frames := 0
var _ticks_at_start := 0
var _phase := ""
var _charge := 0.0


func _ready() -> void:
	Travel._busy = true
	process_priority = 100
	process_physics_priority = 1000
	Engine.max_fps = HZ
	Engine.physics_ticks_per_second = TICKS
	_floor()
	_run.call_deferred()


func _floor() -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(400, 1.0, 1200)
	cs.shape = sh
	b.add_child(cs)
	add_child(b)
	b.position = Vector3(0, -0.5, -500)


func _spawn_player() -> void:
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.set_script(load("res://core/player/player.gd"))
	pl.floor_max_angle = 0.80285144
	pl.floor_snap_length = 0.5
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	pl.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.set_script(load("res://core/player/character_rig.gd"))
	pl.add_child(vis)
	var r := Node3D.new()
	r.name = "CameraRig"
	r.position.y = 1.55
	pl.add_child(r)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	r.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	pitch.add_child(arm)
	var pcam := Camera3D.new()
	pcam.name = "Camera"
	arm.add_child(pcam)
	pl.position = Vector3(0, 0.05, 2)
	add_child(pl)
	p = pl as Player


## Where `n` is drawn this frame: a node on physics interpolation uses its interpolated transform; a node
## off it sits (locally) on whatever its parent is drawn as, unless it is top level.
func _drawn(n: Node3D) -> Transform3D:
	if n.is_physics_interpolated_and_enabled():
		return n.get_global_transform_interpolated()
	var par := n.get_parent() as Node3D
	if n.top_level or par == null:
		return n.global_transform
	return _drawn(par) * n.transform


func _origin(n: Node3D) -> Vector3:
	return _drawn(n).origin if is_instance_valid(n) and n.visible else Vector3.INF


func _body_origin(n: Node3D) -> Vector3:
	return n.get_global_transform_interpolated().origin


func _add(nm: String, node: Node3D, getter: Callable, steady: float, truth := Callable()) -> void:
	_subjects.append({"name": nm, "node": node, "get": getter, "steady": steady, "truth": truth})
	_logs[nm] = []


func _run() -> void:
	_spawn_player()
	await get_tree().create_timer(0.5).timeout
	# a Shade closing from the side
	var shade := Shade.new()
	shade.target = p
	add_child(shade)
	shade.global_position = Vector3(40, 3, 2)
	# the Familiar
	var fam := FamiliarScript.new() as Node3D
	fam.owner_p = p
	fam.life = 60.0
	add_child(fam)
	# a cage lift, slow enough to be near constant speed mid-travel
	var lift := ChainLift.new()
	lift.bottom = Vector3(20, 0, 20)
	lift.top_y = 400.0
	lift.travel_time = 80.0
	lift.dwell = 0.05
	add_child(lift)
	# the Tether anchor, far down the floor
	var anchor := Node3D.new()
	add_child(anchor)
	anchor.global_position = Vector3(0, 30, -400)
	p.debug_drive(Vector3(0, 0, -1))
	await get_tree().create_timer(1.0).timeout
	var cam := p.get_node("CameraRig/Pitch/SpringArm/Camera") as Node3D
	_add("camera", cam, _origin, 0.35)
	_add("player body", p, _body_origin, 0.35)
	_add("shade body", shade._body, _origin, 0.4)
	_add("shade pool", shade._pool, _origin, 0.4)
	_add("familiar", fam, _origin, 0.0)
	_add("chain lift deck", lift._deck, _origin, 0.3)
	# the charge glow rides the drawn staff head
	_charge = 0.5
	p.casting.set_charge_glow(_charge)
	_add("charge orb", p._charge_orb, _origin, 0.0, p._visual.muzzle_drawn)
	_add("charge light", p._charge_light, _origin, 0.0, p._visual.muzzle_drawn)
	await get_tree().create_timer(SETTLE).timeout
	# a bolt flying level over the floor, off to the side
	var bolt := BOLT.instantiate() as MagicBolt
	add_child(bolt)
	bolt.direction = Vector3(0, 0, -1)
	bolt.transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1)), Vector3(-30, 3, 0))
	_add("bolt", bolt, _origin, 0.3)
	_record_phase("walk")
	await get_tree().create_timer(SPAN).timeout
	_check_phase()
	# the haul: the line is drawn from the staff head to the anchor
	_charge = 0.0
	p.casting.set_charge_glow(0.0)
	_subjects.clear()
	_logs.clear()
	var g = p._grapple
	p.debug_drive(Vector3.ZERO)
	await get_tree().create_timer(0.3).timeout
	if not g.start(anchor):
		_fail("grapple start refused")
	await get_tree().process_frame
	await get_tree().process_frame
	_add("grapple line", g._line, _origin, 0.0, func() -> Vector3: return (p._visual.muzzle_drawn() + anchor.global_position) * 0.5)
	_add("player on the haul", p, _body_origin, 0.0)
	await get_tree().create_timer(0.5).timeout
	_record_phase("haul")
	await get_tree().create_timer(0.9).timeout
	_check_phase()
	_static_multimeshes()
	print("interp_audit_test: ", "FAIL %d" % bad if bad > 0 else "PASS")
	get_tree().quit(1 if bad > 0 else 0)


## The skill book sets the glow on its own tick (to 0 when nothing charges): hold it on after that.
func _physics_process(_dt: float) -> void:
	if _charge > 0.0 and is_instance_valid(p):
		p.casting.set_charge_glow(_charge)


func _record_phase(nm: String) -> void:
	_phase = nm
	for s: Dictionary in _subjects:
		_logs[s.name] = []
	_frames = 0
	_ticks_at_start = Engine.get_physics_frames()
	_recording = true


func _process(dt: float) -> void:
	if not _recording:
		return
	_frames += 1
	for s: Dictionary in _subjects:
		var at: Vector3 = (s.get as Callable).call(s.node)
		var err := 0.0
		if (s.truth as Callable).is_valid() and at.x != INF:
			err = at.distance_to((s.truth as Callable).call())
		(_logs[s.name] as Array).append([at, dt, err])


func _fail(msg: String) -> void:
	bad += 1
	print("FAIL ", msg)


func _check_phase() -> void:
	_recording = false
	var ticks := Engine.get_physics_frames() - _ticks_at_start
	var ratio := float(_frames) / maxf(float(ticks), 1.0)
	print("%s: %d frames over %d ticks (%.2f per tick)" % [_phase, _frames, ticks, ratio])
	if ratio < 1.5 or ratio > 2.6:
		_fail("%s: the run is not at 2 frames per tick (%.2f); the audit would say nothing" % [_phase, ratio])
		return
	for s: Dictionary in _subjects:
		var log: Array = _logs[s.name]
		var speeds: Array[float] = []
		for i in range(1, log.size()):
			var a: Vector3 = log[i - 1][0]
			var b: Vector3 = log[i][0]
			if a.x == INF or b.x == INF:
				continue
			speeds.append(a.distance_to(b) / maxf(float(log[i][1]), 0.0001))
		if speeds.size() < log.size() / 2:
			_fail("%s: %s was gone for most of the run" % [_phase, s.name])
			continue
		var sorted := speeds.duplicate()
		sorted.sort()
		var med: float = sorted[sorted.size() / 2]
		var dups := 0
		var outliers := 0
		for v: float in speeds:
			if v < med * DUP_FRAC:
				dups += 1
			elif float(s.steady) > 0.0 and absf(v - med) > med * float(s.steady):
				outliers += 1
		var worst := float(dups + outliers) / float(speeds.size())
		var lag := 0.0
		for e: Array in log:
			lag = maxf(lag, float(e[2]))
		var ok := worst <= MAX_BAD and med > 0.01 and lag < MAX_LAG
		print("  %-20s median %.2f m/s, %d dup, %d outlier of %d, worst miss %.3f m  %s" % [s.name, med, dups, outliers, speeds.size(), lag, "ok" if ok else "FAIL"])
		if not ok:
			bad += 1


## The static MultiMesh builders (flora, props, dressing) put their node off physics interpolation before it enters the tree:
## an interpolated MultiMesh makes its add wait on the GPU (12-20 ms for the first add of a frame; umbral-donts, Static MultiMeshes).
const STATIC_MMI := ["core/world/realm/flora_emit.gd", "core/world/mesh_chunks.gd", "core/world/realm/east_works_kit.gd",
	"core/world/realm/reach_towns.gd", "core/world/realm/realm_pois.gd", "core/world/realm/realm_pois_east_reach.gd",
	"core/world/realm/rift/crossing.gd", "core/world/realm/rift/features.gd", "core/world/realm/rift_rim.gd",
	"core/world/realm/site_dress.gd", "core/world/realm/wonders/r39/shorelines.gd", "core/world/realm/wonders/r39/wonder_kit.gd",
	"core/world/realm/wonders/sky_chain.gd", "core/life/secrets/site_glade.gd", "core/life/wildlife/life_kit.gd",
	"world/areas/ossuary/oss_deep.gd", "world/areas/ossuary/oss_kit.gd"]


func _static_multimeshes() -> void:
	var n := 0
	for path: String in STATIC_MMI:
		var lines := FileAccess.get_file_as_string("res://" + path).split("\n")
		for i in lines.size():
			if "MultiMeshInstance3D.new()" in lines[i]:
				n += 1
				var near := "\n".join(lines.slice(i, mini(i + 4, lines.size())))
				if not "PHYSICS_INTERPOLATION_MODE_OFF" in near:
					_fail("%s:%d: a static MultiMeshInstance3D is added with physics interpolation on" % [path, i + 1])
	print("static MultiMeshInstance3D builders checked: %d" % n)
	if n < 20:
		_fail("only %d static MultiMesh builders found (the list is stale)" % n)

class_name WardSeal
extends Node3D
## A sealed gateway: a solid barrier across an opening that dissolves when its guard camps are
## cleared (EnemySpawner camps tagged with this seal's id) and any required bosses are slain.
## The broken state persists (Travel.seals_broken), so a cleared gate stays open.
##
## Looks: "bone" = a portcullis of femur bars; "thorn" = a woven bramble; "light" = a runed veil.

@export var seal_id := ""
@export var size := Vector2(2.4, 3.0)          ## opening width, height (metres)
@export var look := "light"
@export var requires_bosses: Array[String] = []
## r36 Act II: the Founder's bells answered for (QuestBook.bells()) before it opens (the summit ward).
@export var requires_bells := 0
@export var title := "The way is sealed"

var _body: StaticBody3D
var _vis: Node3D
var _open := false
var _cleared := false
var _light: OmniLight3D
## An arena-only gate (r30): no camps, no persistence, open until a fight shuts it. Progression seals
## (the bone portcullis, the summit ward) stay what they are; the arena shuts its own gate at its mouth.
var arena_only := false


static func make(host: Node3D, id: String, at: Vector3, facing: Vector3, w: float, h: float, look_kind: String, label: String, bosses: Array[String] = []) -> WardSeal:
	var s := WardSeal.new()
	s.seal_id = id
	s.size = Vector2(w, h)
	s.look = look_kind
	s.title = label
	s.requires_bosses = bosses
	s.name = "Seal_" + id
	host.add_child(s)
	s.global_position = at
	var f := Vector3(facing.x, 0, facing.z).normalized()
	s.global_basis = Basis(f.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, f).orthonormalized()
	return s


## A barrier at an arena's mouth that only a fight closes (BossArena.gate / gates). Open at rest.
static func make_arena_gate(host: Node3D, id: String, at: Vector3, facing: Vector3, w: float, h: float, look_kind: String) -> WardSeal:
	var s := WardSeal.new()
	s.arena_only = true
	s.seal_id = id
	s.size = Vector2(w, h)
	s.look = look_kind
	s.title = "The way"
	s.name = "ArenaGate_" + id
	host.add_child(s)
	s.global_position = at
	var f := Vector3(facing.x, 0, facing.z).normalized()
	s.global_basis = Basis(f.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, f).orthonormalized()
	return s


func _ready() -> void:
	if not arena_only:
		add_to_group(&"ward_seal")
	_body = StaticBody3D.new()
	_body.collision_layer = Layers.WORLD | Layers.PROPS
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, size.y + 1.2, 0.5)          # taller than the opening: no hopping over
	cs.shape = bs
	cs.position = Vector3(0, (size.y + 1.2) * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)
	_vis = Node3D.new()
	add_child(_vis)
	_build_look()
	if arena_only:
		_open = true
		_body.collision_layer = 0
		_body.process_mode = Node.PROCESS_MODE_DISABLED
		_vis.visible = false
		if _light:
			_light.visible = false
		return
	_cleared = Travel.seals_broken.has(seal_id)
	Events.seal_broken.connect(_on_broken)
	Events.boss_slain.connect(func(_id: String) -> void: _refresh(true))
	if requires_bells > 0:
		Events.quest_changed.connect(func(_id: String, _s: int, _d: bool) -> void: _refresh(true))
	Events.seal_progress.connect(_on_progress)
	_refresh(false)


func _on_progress(id: String, cleared: int, total: int) -> void:
	if id != seal_id or _open:
		return
	Events.toast.emit("%s weakens — %d of %d guardians fallen." % [title, cleared, total])
	var tw := create_tween()
	_vis.scale = Vector3.ONE * 1.04
	tw.tween_property(_vis, "scale", Vector3.ONE, 0.4)


func _on_broken(id: String) -> void:
	if id != seal_id:
		return
	_cleared = true
	_refresh(true)


func bosses_ok() -> bool:
	for b in requires_bosses:
		if not Travel.bosses_slain.has(b):
			return false
	return requires_bells <= 0 or QuestBookScript.bells() >= requires_bells


const QuestBookScript := preload("res://core/story/quest_book.gd")


func is_open() -> bool:
	return _open


func _refresh(animate: bool) -> void:
	if _open:
		return
	var camps := EnemySpawner.seal_total(seal_id)
	if (_cleared or camps == 0) and bosses_ok():
		_open = true
		_body.collision_layer = 0
		_body.process_mode = Node.PROCESS_MODE_DISABLED
		if animate:
			Sfx.play("res://art/audio/ward_chime.wav", global_position + Vector3.UP, 2.0)
			SpellFx.rift_in(global_position)
			Events.toast.emit("%s is broken." % title)
			var tw := create_tween()
			tw.tween_property(_vis, "position:y", -size.y - 0.4 if look == "bone" else 0.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_vis, "scale", Vector3(1.0, 0.02, 1.0) if look != "bone" else Vector3.ONE, 1.6)
			tw.tween_callback(func() -> void: _vis.visible = false)
			if _light:
				tw.parallel().tween_property(_light, "light_energy", 0.0, 1.2)
		else:
			_vis.visible = false
			if _light:
				_light.visible = false


func _build_look() -> void:
	var w := size.x
	var h := size.y
	match look:
		"bone":
			var bone := OssKit.mat("bone")
			var iron := OssKit.mat("iron")
			var n := maxi(3, int(w / 0.32))
			for i in n:
				var x := lerpf(-w * 0.5 + 0.14, w * 0.5 - 0.14, float(i) / float(n - 1))
				_bar(Vector3(x, h * 0.5, 0), Vector3(0.09, h, 0.09), bone)
				_bar(Vector3(x, 0.08, 0), Vector3(0.14, 0.2, 0.14), bone)           # spiked foot
			for y: float in [0.5, h * 0.55, h - 0.2]:
				_bar(Vector3(0, y, 0.0), Vector3(w, 0.08, 0.06), iron)
		"thorn":
			var cm := CreatureMesh.new(int(absf(global_position.x) * 31.0) + 5)
			var rng := RandomNumberGenerator.new()
			rng.seed = 911
			for i in 26:
				var x0 := rng.randf_range(-w * 0.55, w * 0.55)
				var pts := PackedVector3Array()
				var rad := PackedFloat32Array()
				for k in 5:
					var t := float(k) / 4.0
					pts.append(Vector3(x0 + sin(t * 5.0 + float(i)) * 0.5, t * (h + 0.4), rng.randf_range(-0.18, 0.18)))
					rad.append(lerpf(0.06, 0.02, t))
				cm.tube(pts, rad, 5, Color(0.18, 0.1, 0.08), 0.0, 0.25, 0.0, Vector2.ONE, 0.4)
			var mi := MeshInstance3D.new()
			mi.mesh = cm.commit()
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.9
			m.emission_enabled = true
			m.emission = Color(0.45, 0.05, 0.08)
			m.emission_energy_multiplier = 0.25
			mi.material_override = m
			_vis.add_child(mi)
		_:
			var veil := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(w, h)
			veil.mesh = q
			veil.position = Vector3(0, h * 0.5, 0)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_color = Color(0.5, 0.3, 1.0, 0.35)
			veil.material_override = m
			_vis.add_child(veil)
			for k in 3:
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.42 + 0.3 * float(k)
				tm.outer_radius = tm.inner_radius + 0.03
				ring.mesh = tm
				ring.rotation.x = PI * 0.5
				ring.position = Vector3(0, h * 0.5, 0)
				ring.material_override = m
				_vis.add_child(ring)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.9, 0.3, 0.35) if look == "thorn" else Color(0.7, 0.45, 1.0)
	_light.light_energy = 0.6
	_light.omni_range = 4.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, h * 0.6, 0.6)
	add_child(_light)


func _bar(at: Vector3, s: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = s
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	_vis.add_child(mi)


## Arena gates: drop the barrier again behind a challenger, lift it when the fight ends.
func close() -> void:
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	_body.collision_layer = Layers.WORLD | Layers.PROPS
	_vis.visible = true
	var tw := create_tween()
	if look == "bone":
		_vis.scale = Vector3.ONE
		_vis.position.y = -size.y - 0.4
		tw.tween_property(_vis, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		# thorns grow up out of the ground, a veil draws itself upward: not a pop (r30)
		_vis.position.y = 0.0
		_vis.scale = Vector3(1.0, 0.02, 1.0)
		tw.tween_property(_vis, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		SpellFx.rift_in(global_position)
	Sfx.play("res://art/audio/ward_chime.wav", global_position + Vector3.UP, 0.0)
	if _light:
		_light.visible = true
		_light.light_energy = 0.6


## After a fight (won or reset): an arena-only gate, or a seal already broken, opens; a progression
## seal still guarded goes back to its own closed state instead of being forced open (r30: a death on
## the dais used to leave the summit ward open for the session with its camp alive).
func reopen() -> void:
	if arena_only or _open:
		release()
		return
	_refresh(true)                  # opens it only if its camps and bosses now allow it
	if _open:
		return
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	_body.collision_layer = Layers.WORLD | Layers.PROPS
	_vis.visible = true
	_vis.position.y = 0.0
	_vis.scale = Vector3.ONE


## Force the barrier open (tests and arena gates). Does not mark a seal broken.
func release() -> void:
	_body.collision_layer = 0
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	var tw := create_tween()
	tw.tween_property(_vis, "position:y", -size.y - 0.4 if look == "bone" else 0.0, 1.2)
	tw.tween_callback(func() -> void: _vis.visible = false)
	if _light:
		tw.parallel().tween_property(_light, "light_energy", 0.0, 1.0)


## Audit hook: a seal must have guards to clear or a boss requirement, or it can never open.
func audit() -> Array[String]:
	var out: Array[String] = []
	if EnemySpawner.seal_total(seal_id) == 0 and requires_bosses.is_empty() and not Travel.seals_broken.has(seal_id):
		out.append("%s has no guard camps and no boss requirement" % seal_id)
	return out

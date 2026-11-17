extends Node3D
## THE NIGHT'S VFX LIBRARY (events in, pooled effects out). Every one reads in the dark by shape and colour, and every one is
## a Vfx burst, ring or flash: pooled (Vfx keeps its emitters), capped, and made nothing until the event happens. Together with
## hit_reads.gd (blows and kills), telegraph_glow.gd (enemy casts and breaks) and arena_light.gd (boss phases):
##   CASTS           when the wanderer begins a staged cast (Events.cast_started) a rune ring closes on the ground at his feet over the
##                   cast's time, in the skill's colour (ember orange, umbral violet, light blue-white); finishing it throws a burst
##                   and, for the ground spells (nova, ward, peal), a wide shock ring the size of the spell; breaking it is a red
##                   fizzle at his hand;
##   STATUSES        every buff and debuff (Events.status_changed) is a small continuous effect on whoever carries it, in the
##                   status's own colour (core/skills/combat_state.gd DEFS): embers rising off a foe with an Ember Scar (more
##                   of them per stack), violet shards falling from a Sundered one, a Shaken one's red sparks, the Umbral Mark's
##                   motes circling up, the wanderer's Resonance violet drifting up round him and a Rift Surge's gold flicker;
##                   at most ten carriers at a time, four bursts a second between them;
##   PICKUPS         an item gained (Events.item_gained) lifts a few gold motes and a small ring at the wanderer's feet;
##   LEVEL-UP        the Hearth's leveled_up: a tall column of light (one card, one tween) over the wanderer, a wide gold ring, sixty
##                   motes rising, a flash, and the landmark cards flare a moment (the registry pulse).
## No work between events beyond the status carriers. Skipped with the Living Night off.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const MAX_CARRIERS := 10

var _carriers := {}                       ## instance id -> {"n": Node3D, "st": {status id -> stacks}}
var _tick := 0.0
var _slot := 0
var _column: MeshInstance3D
var _col_t := -1.0
var _hearth: Node
var _hearth_t := 1.0
var _hearth_tries := 0
static var _col_tex: ImageTexture


func _ready() -> void:
	Events.cast_started.connect(_on_cast_started)
	Events.cast_stopped.connect(_on_cast_stopped)
	Events.skill_cast.connect(_on_skill_cast)
	Events.status_changed.connect(_on_status)
	Events.item_gained.connect(_on_item)
	_build_column()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


## The colour a skill's effects take, from what its name says of it.
static func skill_colour(id: StringName) -> Color:
	var s := String(id)
	if s.contains("lance") or s.contains("ember") or s.contains("fire"):
		return Color(2.4, 0.9, 0.25)
	if s.contains("ward") or s.contains("peal") or s.contains("light") or s.contains("kindle"):
		return Color(1.3, 1.7, 2.4)
	return Color(1.4, 0.6, 2.6)


# --- casts -----------------------------------------------------------------------------------------

func _on_cast_started(id: StringName, total: float) -> void:
	if not Reg.enabled or total < 0.2:
		return
	var p := _player()
	if p == null:
		return
	Vfx.ring(p.global_position, 1.7, skill_colour(id), total, 0.07)


func _on_cast_stopped(id: StringName, reason: StringName) -> void:
	if not Reg.enabled:
		return
	var p := _player()
	if p == null:
		return
	var at := p.global_position + Vector3(0.0, 1.1, 0.0)
	if reason == &"done":
		Vfx.burst(at, skill_colour(id), {"count": 14, "life": 0.4, "speed": Vector2(2.0, 5.0), "size": 0.05, "gravity": -3.0, "spread": 180.0, "damping": 2.0})
	elif reason == &"interrupted" or reason == &"moved":
		Vfx.burst(at, Color(2.0, 0.4, 0.3), {"count": 10, "life": 0.3, "speed": Vector2(1.0, 3.0), "size": 0.04, "gravity": 4.0, "spread": 180.0, "damping": 2.5})


func _on_skill_cast(id: StringName) -> void:
	if not Reg.enabled:
		return
	var p := _player()
	if p == null:
		return
	var s := String(id)
	var r := 0.0
	if s.contains("nova"):
		r = 6.0
	elif s.contains("peal"):
		r = 9.0
	elif s.contains("ward"):
		r = 3.2
	if r > 0.0:
		var c := skill_colour(id)
		Vfx.ring(p.global_position, r, c, 0.55, 0.12)
		Vfx.light(p.global_position + Vector3(0.0, 0.8, 0.0), c, 2.8, r + 3.0, 0.3, 2)


# --- statuses --------------------------------------------------------------------------------------

func _on_status(target: Node, id: StringName, stacks: int, _left: float) -> void:
	if not (target is Node3D):
		return
	var key := target.get_instance_id()
	if stacks <= 0:
		if _carriers.has(key):
			(_carriers[key].st as Dictionary).erase(id)
			if (_carriers[key].st as Dictionary).is_empty():
				_carriers.erase(key)
		return
	if not _carriers.has(key):
		if _carriers.size() >= MAX_CARRIERS:
			return
		_carriers[key] = {"n": target, "st": {}}
	_carriers[key].st[id] = stacks


func _process(delta: float) -> void:
	if _hearth == null:
		_hearth_t -= delta
		if _hearth_t <= 0.0:
			_hearth_tries += 1
			_hearth_t = 2.0 if _hearth_tries < 8 else 40.0     # a search of the whole tree is not for every two seconds for ever
			_look_for_hearth()
	if _col_t >= 0.0:
		_col_t += delta
		var u := _col_t / 2.2
		if u >= 1.0:
			_col_t = -1.0
			_column.visible = false
		else:
			var a := (1.0 - u) * smoothstep(0.0, 0.08, u)
			(_column.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.5, a)
			_column.scale = Vector3(1.6 + 2.0 * u, 26.0, 1.0)
	if not Reg.enabled or _carriers.is_empty():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	# one carrier a quarter second (four bursts a second between however many there are)
	var keys := _carriers.keys()
	_slot = (_slot + 1) % keys.size()
	var key: int = keys[_slot]
	var rec: Dictionary = _carriers[key]
	var n := rec.n as Node3D
	if not is_instance_valid(n) or not n.is_inside_tree():
		_carriers.erase(key)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(n.global_position) > 38.0:
		return
	for sid: StringName in rec.st:
		_status_burst(n, sid, int(rec.st[sid]))


func _status_burst(n: Node3D, id: StringName, stacks: int) -> void:
	var at := n.global_position + Vector3(0.0, 1.0, 0.0)
	match id:
		&"ember_scar":
			Vfx.burst(at, Color(2.6, 0.9, 0.3), {"count": 2 + stacks * 2, "life": 1.0, "speed": Vector2(0.3, 1.0), "size": 0.05, "gravity": -1.2, "spread": 35.0, "dir": Vector3.UP})
		&"sundered":
			Vfx.burst(at + Vector3(0.0, 0.5, 0.0), Color(1.1, 0.7, 1.6), {"count": 4, "life": 0.7, "speed": Vector2(0.2, 0.8), "size": 0.045, "gravity": 3.0, "spread": 180.0})
		&"shaken":
			Vfx.burst(at, Color(1.6, 0.4, 0.35), {"count": 3, "life": 0.4, "speed": Vector2(1.0, 2.5), "size": 0.04, "gravity": 0.0, "spread": 180.0, "damping": 2.0})
		&"resonance":
			Vfx.burst(at, Color(1.2, 0.6, 2.6), {"count": 1 + stacks, "life": 1.2, "speed": Vector2(0.2, 0.6), "size": 0.045, "gravity": -0.5, "spread": 60.0, "dir": Vector3.UP})
		&"surge":
			Vfx.burst(at, Color(2.4, 1.6, 0.8), {"count": 5, "life": 0.5, "speed": Vector2(1.0, 3.0), "size": 0.04, "gravity": -2.0, "spread": 120.0, "dir": Vector3.UP})
		_:
			Vfx.burst(at, Color(1.4, 0.6, 3.0), {"count": 2, "life": 1.0, "speed": Vector2(0.3, 0.8), "size": 0.045, "gravity": -0.4, "spread": 180.0})


# --- pickups and the level -------------------------------------------------------------------------

func _on_item(_id: String, amount: int, _total: int) -> void:
	if not Reg.enabled or amount <= 0:
		return
	var p := _player()
	if p == null:
		return
	Vfx.burst(p.global_position + Vector3(0.0, 0.5, 0.0), Color(2.2, 1.7, 0.7), {"count": 8, "life": 0.9, "speed": Vector2(0.4, 1.4), "size": 0.045, "gravity": -1.0, "spread": 50.0, "dir": Vector3.UP})
	Vfx.ring(p.global_position, 0.9, Color(2.2, 1.7, 0.7), 0.4, 0.05)


func _on_level(_level: int, _points: int) -> void:
	if not Reg.enabled:
		return
	var p := _player()
	if p == null:
		return
	var c := Color(2.4, 1.8, 0.7)
	Vfx.ring(p.global_position, 8.0, c, 1.0, 0.14)
	Vfx.ring(p.global_position, 4.0, c, 0.7, 0.1)
	Vfx.burst(p.global_position + Vector3(0.0, 0.3, 0.0), c, {"count": 60, "life": 1.8, "speed": Vector2(1.0, 4.5), "size": 0.06, "gravity": -1.5, "spread": 25.0, "dir": Vector3.UP})
	Vfx.light(p.global_position + Vector3(0.0, 1.2, 0.0), c, 4.0, 14.0, 1.2, 3)
	Reg.pulse = 1.0
	_column.global_position = p.global_position + Vector3(0.0, 13.0, 0.0)
	_column.visible = true
	_col_t = 0.0


## The column of light over a level: one tall billboard card, stretched and faded by a clock (no tween object, no light).
func _build_column() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _beam_tex()
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.0)
	mat.disable_fog = true
	_column = MeshInstance3D.new()
	_column.mesh = quad
	_column.material_override = mat
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.top_level = true
	_column.visible = false
	_column.extra_cull_margin = 40.0
	add_child(_column)


## The Hearth (progression) is built after this node: looked for by name every two seconds until it exists (then its
## level-up is listened to, and the looking stops).
func _look_for_hearth() -> void:
	var h := get_tree().current_scene.find_child("Hearth", true, false)
	if h != null and h.has_signal("leveled_up"):
		_hearth = h
		h.connect("leveled_up", _on_level)


static func _beam_tex() -> ImageTexture:
	if _col_tex:
		return _col_tex
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := absf(float(x) + 0.5 - w * 0.5) / (w * 0.5)
			var v := float(y) / float(h)
			var a := pow(clampf(1.0 - u, 0.0, 1.0), 2.5) * (0.25 + 0.75 * sin(v * PI))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_col_tex = ImageTexture.create_from_image(img)
	return _col_tex

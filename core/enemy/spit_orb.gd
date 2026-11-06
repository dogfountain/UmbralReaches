class_name SpitOrb
extends Area3D
## Spitter projectile. Slow on purpose (read it, sidestep it, shadowstep through it, or shoot it
## down). Teal so it survives the grade: grade.gdshader protects the 155-200 deg band, and violet
## is the player's colour, warm is safe light.

const SPEED := 9.0
const LIFE := 3.4
const SAG := 1.2              ## m/s² of droop so long shots arc a little
const TEAL := Color(0.25, 1.7, 1.15)

static var _core_mesh: SphereMesh
static var _shell_mesh: SphereMesh
static var _flare_mesh: QuadMesh
static var _shape: SphereShape3D

var velocity := Vector3.ZERO
var gloom := 10.0
var _age := 0.0
var _dead := false
var _skipped := false         ## it entered you while you were evading: it wounds when the roll ends, once
var _light: OmniLight3D
var _body: Node3D


static func launch(host: Node, from: Vector3, dir: Vector3, gloom_amount: float) -> SpitOrb:
	if host == null:
		return null
	var orb := SpitOrb.new()
	orb.gloom = gloom_amount
	orb.velocity = dir.normalized() * SPEED
	host.add_child(orb)
	orb.global_position = from
	return orb


func _ready() -> void:
	add_to_group(Groups.ENEMY_SHOT)
	collision_layer = Layers.HURTBOX            # player bolts and Nova can find and pop it
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.PROPS
	monitoring = true
	monitorable = true
	_ensure_shared()
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	add_child(cs)
	_body = Node3D.new()
	add_child(_body)
	for m in [_core_mesh, _shell_mesh]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(mi)
	var flare := MeshInstance3D.new()
	flare.mesh = _flare_mesh
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(flare)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.3, 1.0, 0.8)
	_light.light_energy = 1.3
	_light.omni_range = 3.2
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 0.4
	_light.set_meta("light_class", "glimmer")
	add_child(_light)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	if _age >= LIFE:
		pop()
		return
	velocity.y -= SAG * delta
	if _skipped:
		for b in get_overlapping_bodies():
			if b is Player and not (b as Player).is_evading():
				_on_body(b)
				return
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.PLAYER | Layers.PROPS)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)    # a hitch cannot carry it through a body
	if not hit.is_empty():
		global_position = hit.position
		_on_body(hit.collider as Node)
		if _dead:
			return
		to = global_position + velocity * delta * 0.02
	global_position = to
	var w := 1.0 + sin(_age * 22.0) * 0.12
	_body.scale = Vector3(w, 2.0 - w, w)


func _on_body(b: Node) -> void:
	if _dead or b is Enemy:
		return
	if b is Player:
		var p := b as Player
		if p.is_evading():
			_skipped = true
			return                   # stepped through it
		p.take_wound(gloom, global_position - velocity.normalized() * 3.0)
	pop()


## Anything with take_hit can be shot down: a bolt's proximity fuse finds it on the HURTBOX layer.
func take_hit(_dmg: float, _from: Node = null) -> void:
	pop()


func pop() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	Vfx.burst(global_position, TEAL, {"count": 22, "life": 0.45, "speed": Vector2(1.5, 4.0), "size": 0.045, "gravity": -7.0, "trail": 0.06})
	Vfx.burst(global_position, Color(0.05, 0.25, 0.18, 0.7), {"count": 8, "life": 0.6, "speed": Vector2(0.3, 1.0), "size": 0.25, "gravity": -1.0, "additive": false})
	remove_from_group(Groups.ENEMY_SHOT)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_body, "scale", Vector3.ONE * 2.4, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(_light, "light_energy", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


static func _ensure_shared() -> void:
	if _core_mesh != null:
		return
	_core_mesh = SphereMesh.new()
	_core_mesh.radius = 0.12
	_core_mesh.height = 0.24
	_core_mesh.radial_segments = 10
	_core_mesh.rings = 6
	_core_mesh.material = ProcMesh.glow_mat(TEAL)
	_shell_mesh = SphereMesh.new()
	_shell_mesh.radius = 0.22
	_shell_mesh.height = 0.44
	_shell_mesh.radial_segments = 10
	_shell_mesh.rings = 6
	var shell := ProcMesh.glow_mat(Color(0.12, 0.6, 0.45, 0.4))
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_mesh.material = shell
	_flare_mesh = QuadMesh.new()
	_flare_mesh.size = Vector2(0.7, 0.7)
	var fmat := ShaderMaterial.new()
	fmat.shader = preload("res://world/flare.gdshader")
	fmat.set_shader_parameter("color", Color(0.3, 1.9, 1.3))
	_flare_mesh.material = fmat
	_shape = SphereShape3D.new()
	_shape.radius = 0.24

class_name BoltPool
extends Node
## Zone-owned bolt / burst / shock pool. Not static — scene change drops the nodes.

const BOLT := preload("res://core/player/magic_bolt.tscn")
const CAP := 12
const BURST_CAP := 6
const SHOCK_CAP := 6

var _free: Array[MagicBolt] = []
var _bursts: Array[GPUParticles3D] = []
var _shocks: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("bolt_pool")
	for i in CAP:
		var bolt := BOLT.instantiate() as MagicBolt
		bolt.process_mode = Node.PROCESS_MODE_DISABLED
		bolt.visible = false
		add_child(bolt)
		_free.append(bolt)
	for i in BURST_CAP:
		var bang := MagicBolt.make_particles(true)
		bang.emitting = false
		add_child(bang)
		_bursts.append(bang)
	for i in SHOCK_CAP:
		var shock := MagicBolt.make_shock()
		shock.visible = false
		add_child(shock)
		_shocks.append(shock)
	call_deferred("_prewarm")


## The night is torn down (quit, or the Deeper Night rebuilding in-process): the combat VFX
## caches in statics go with it (statics outlive the renderer at quit; a rebuilt night starts clean).
## r36: this does NOT cure the exit "1 shaders of type ParticlesShaderRD were never freed": that
## one reproduces with every bolt node and material already freed and released before quit (a
## lone MagicBolt.make_particles in an empty scene), so it is not a reference we keep.
func _exit_tree() -> void:
	MagicBolt.release_shared()
	Vfx.release()
	SpellFx.release()


func take() -> MagicBolt:
	var bolt: MagicBolt
	if _free.is_empty():
		bolt = BOLT.instantiate() as MagicBolt
		add_child(bolt)
	else:
		bolt = _free.pop_back()
	bolt.process_mode = Node.PROCESS_MODE_INHERIT
	bolt.visible = true
	return bolt


func release(bolt: MagicBolt) -> void:
	if bolt == null or not is_instance_valid(bolt):
		return
	bolt.reset_idle()
	if bolt.get_parent() != self:
		bolt.reparent(self)
	if not _free.has(bolt):
		_free.append(bolt)


func take_burst() -> GPUParticles3D:
	for p in _bursts:
		if is_instance_valid(p) and not p.emitting:
			return p
	var bang := MagicBolt.make_particles(true)
	add_child(bang)
	_bursts.append(bang)
	return bang


func take_shock() -> MeshInstance3D:
	for s in _shocks:
		if is_instance_valid(s) and not s.visible:
			return s
	var shock := MagicBolt.make_shock()
	add_child(shock)
	_shocks.append(shock)
	return shock


func _prewarm() -> void:
	var bolt := take()
	bolt.global_position = Vector3(0.0, -100.0, 0.0)
	bolt.arm(false)
	bolt.explode(bolt.global_position)

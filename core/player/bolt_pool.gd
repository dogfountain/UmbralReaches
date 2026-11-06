class_name BoltPool
extends Node
## Zone-owned bolt / burst / shock pool. Not static — scene change drops the nodes.

const BOLT := preload("res://core/player/magic_bolt.tscn")
const CAP := 12
const BURST_CAP := 6
const SHOCK_CAP := 6
const LIVE_CAP := 24            ## no more bolts than this are ever made; past it take() answers null
const FX_CAP := 12              ## bursts and shocks grow to this, then the oldest is reused

var _free: Array[MagicBolt] = []
var _bursts: Array[GPUParticles3D] = []
var _shocks: Array[MeshInstance3D] = []
var _made := 0                  ## bolts instantiated so far


func _ready() -> void:
	add_to_group("bolt_pool")
	for i in CAP:
		var bolt := BOLT.instantiate() as MagicBolt
		bolt.process_mode = Node.PROCESS_MODE_DISABLED
		bolt.visible = false
		add_child(bolt)
		_free.append(bolt)
		_made += 1
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
	# drop the particle process materials before their nodes go (a lone one is what the exit
	# log's ParticlesShaderRD line counts)
	for p in _bursts:
		if is_instance_valid(p):
			p.process_material = null
			p.draw_pass_1 = null
	for b in get_children():
		if b is MagicBolt:
			(b as MagicBolt).drop_materials()
	MagicBolt.release_shared()
	Vfx.release()
	SpellFx.release()


func take() -> MagicBolt:
	var bolt: MagicBolt
	if _free.is_empty():
		if _made >= LIVE_CAP:
			return null
		bolt = BOLT.instantiate() as MagicBolt
		add_child(bolt)
		_made += 1
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
	if _bursts.size() >= FX_CAP:
		var oldest: GPUParticles3D = _bursts.pop_front()
		_bursts.append(oldest)
		return oldest
	var bang := MagicBolt.make_particles(true)
	add_child(bang)
	_bursts.append(bang)
	return bang


func take_shock() -> MeshInstance3D:
	for s in _shocks:
		if is_instance_valid(s) and not s.visible:
			return s
	if _shocks.size() >= FX_CAP:
		var oldest: MeshInstance3D = _shocks.pop_front()
		_shocks.append(oldest)
		return oldest
	var shock := MagicBolt.make_shock()
	add_child(shock)
	_shocks.append(shock)
	return shock


func _prewarm() -> void:
	var bolt := take()
	bolt.global_position = Vector3(0.0, -100.0, 0.0)
	bolt.arm(false)
	bolt.explode(bolt.global_position)

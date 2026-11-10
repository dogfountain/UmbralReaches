extends Node3D
## The Sexton's counterweight cage (no class_name): a called lift between two stops. Unlike the
## summit ChainLift it does not cycle: haul the chain on the deck and it goes to the other stop;
## pull a landing's bell-rope and it comes to you. Until `unlocked` says so the cage stays pinned
## at the bottom, and the top landing's rope does nothing ("barred from below"): the shortcut is
## opened from the depths, once. Rails stand on the west and south sides; it is left open east
## (the gallery door at the top) and north (the Weighing Floor at the bottom).
##   var lift := OssLift.new(); lift.bottom = ...; lift.top_y = ...; lift.unlocked = func() -> bool
## Built in world space (top_level).

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const DECK := Vector3(2.4, 0.3, 2.4)
const SPEED := 2.2                      ## m/s at full travel

var bottom := Vector3.ZERO              ## deck top at the low stop (world)
var top_y := 8.4
var unlocked: Callable                  ## () -> bool
var on_unlock: Callable                 ## the bottom rope's first pull (when allowed): () -> void
var unlock_ready: Callable              ## () -> bool : may the bottom rope release it now?
var deck: AnimatableBody3D
var at_top := false
var _u := 0.0                           ## 0 bottom .. 1 top
var _target := 0.0
var _weight: Node3D
var _chains: Array[MeshInstance3D] = []
var _creak_t := 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector3.ZERO
	_build()
	_place()


func moving() -> bool:
	return not is_equal_approx(_u, _target)


func send(to_top: bool) -> void:
	_target = 1.0 if to_top else 0.0
	at_top = to_top
	Kit.play("grind", deck.global_position, -4.0, 0.8)
	Kit.play("clank", deck.global_position, -6.0, 0.9)


func _physics_process(delta: float) -> void:
	if moving():
		var span := maxf(top_y - bottom.y, 0.1)
		_u = move_toward(_u, _target, delta * SPEED / span * (0.35 + 0.65 * sin(PI * clampf(_u, 0.04, 0.96))))
		_place()
		_creak_t -= delta
		if _creak_t <= 0.0:
			_creak_t = 1.6
			Kit.play("creak", deck.global_position, -12.0, randf_range(0.8, 1.1))
		if not moving():
			Kit.play("clank", deck.global_position, -3.0, 0.7)


func _place() -> void:
	var y := lerpf(bottom.y, top_y, smoothstep(0.0, 1.0, _u))
	deck.global_position = Vector3(bottom.x, y, bottom.z)
	if _weight:
		_weight.global_position = Vector3(bottom.x - 1.75, lerpf(top_y + 1.0, bottom.y + 1.2, smoothstep(0.0, 1.0, _u)), bottom.z - 0.7)
	var top := top_y + 3.4
	for i in _chains.size():
		var ch := _chains[i]
		var a: Vector3
		var b: Vector3
		if i < 2:
			var s := -0.85 if i == 0 else 0.85
			a = Vector3(bottom.x + s, top, bottom.z)
			b = Vector3(bottom.x + s, y + 1.9, bottom.z)
		else:
			a = Vector3(bottom.x - 1.75, top, bottom.z - 0.7)
			b = _weight.global_position + Vector3.UP * 0.6
		ch.global_position = (a + b) * 0.5
		ch.global_basis = Basis.IDENTITY.scaled(Vector3(1.0, maxf(a.distance_to(b), 0.05), 1.0))


func _build() -> void:
	var iron := OssKit.mat("iron")
	deck = AnimatableBody3D.new()
	deck.name = "Cage"
	deck.sync_to_physics = true
	deck.collision_layer = Layers.WORLD
	deck.collision_mask = 0
	deck.position = bottom                  # before it enters the tree (sync_to_physics keeps the first state)
	add_child(deck)
	# everything that rides is one OssKit in deck space (a handful of draws, not fifty)
	var dk := OssKit.new()
	dk.keep_lanes = false
	dk.box("wood", Vector3(0, -DECK.y * 0.5, 0), DECK, Basis.IDENTITY, false, 0.8)
	for x: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:             # plank seams
		dk.box("iron", Vector3(x, 0.005, 0), Vector3(0.03, 0.01, DECK.z - 0.1), Basis.IDENTITY, false, 0.7)
	# cage: four corner posts, a hoop frame overhead (the chains hang from it), rails W and S
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		dk.box("iron", Vector3(c.x * 1.12, 1.0, c.y * 1.12), Vector3(0.08, 2.0, 0.08), Basis.IDENTITY, false)
	for s: float in [-1.0, 1.0]:
		dk.box("iron", Vector3(0, 2.0, s * 1.12), Vector3(2.32, 0.08, 0.08), Basis.IDENTITY, false)
		dk.box("iron", Vector3(s * 1.12, 2.0, 0), Vector3(0.08, 0.08, 2.32), Basis.IDENTITY, false)
	dk.box("iron", Vector3(0, 2.0, 0), Vector3(1.8, 0.1, 0.1), Basis.IDENTITY, false)
	for h: float in [0.5, 1.0]:
		dk.box("iron", Vector3(-1.12, h, 0), Vector3(0.06, 0.06, 2.3), Basis.IDENTITY, false)
		dk.box("iron", Vector3(0, h, 1.12), Vector3(2.3, 0.06, 0.06), Basis.IDENTITY, false)
	for z: float in [-0.6, 0.0, 0.6]:
		dk.box("iron", Vector3(-1.12, 0.5, z), Vector3(0.04, 1.0, 0.04), Basis.IDENTITY, false)
	for x: float in [-0.6, 0.0, 0.6]:
		dk.box("iron", Vector3(x, 0.5, 1.12), Vector3(0.04, 1.0, 0.04), Basis.IDENTITY, false)
	# skulls wired to the hoop: the sexton's tally rides with the cage; a lamp so it reads from afar
	for k in 5:
		dk.skull(Vector3(-0.8 + 0.4 * float(k), 1.82, 1.12), 0.0, 1.0, k % 2, 0.2)
	dk.box("glow", Vector3(-0.9, 1.75, 0.9), Vector3(0.16, 0.24, 0.16), Basis.IDENTITY, false, 0.6)
	dk.commit(deck, "CageSkinUnused")
	_col(deck, Vector3(0, -DECK.y * 0.5, 0), DECK)
	_col(deck, Vector3(-1.12, 0.55, 0), Vector3(0.12, 1.1, DECK.z))
	_col(deck, Vector3(0, 0.55, 1.12), Vector3(DECK.x, 1.1, 0.12))
	# guides: two iron rails on the west from the depths to the pulley, a beam and wheels on top
	var top := top_y + 3.4
	var gk := OssKit.new()
	gk.keep_lanes = false
	var guides := StaticBody3D.new()
	guides.collision_layer = Layers.WORLD
	add_child(guides)
	for s: float in [-1.0, 1.0]:
		var gx := bottom.x - 1.45
		var gz := bottom.z + s * 0.95
		gk.box("iron", Vector3(gx, (bottom.y - 1.2 + top) * 0.5, gz), Vector3(0.14, top - bottom.y + 1.2, 0.14), Basis.IDENTITY, false)
		_col(guides, Vector3(gx, (bottom.y - 1.2 + top) * 0.5, gz), Vector3(0.14, top - bottom.y + 1.2, 0.14), true)
	gk.box("iron", Vector3(bottom.x - 0.4, top, bottom.z), Vector3(3.2, 0.3, 0.4), Basis.IDENTITY, false)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = 0.12
	var cyl_am := ArrayMesh.new()
	cyl_am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cyl.get_mesh_arrays())
	for s: float in [-1.0, 1.0]:
		gk.append_mesh("iron", cyl_am, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(bottom.x + s * 0.85, top - 0.3, bottom.z)))
	gk.commit(self, "GuidesSkinUnused")
	# the counterweight: a cage of bones bound round a stone, on its own chain west of the deck
	_weight = Node3D.new()
	_weight.name = "Counterweight"
	add_child(_weight)
	var wk := OssKit.new()
	wk.keep_lanes = false
	wk.box("stone", Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.7), Basis.IDENTITY, false, 0.8)
	for k in 6:
		var a := TAU * float(k) / 6.0
		wk.bone(Vector3(cos(a) * 0.4, 0.55, sin(a) * 0.4), Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3.ONE * 2.6), 0, false)
	wk.commit(_weight, "WeightSkinUnused")
	for i in 3:
		var ch := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.045, 1.0, 0.045)
		ch.mesh = bx
		ch.material_override = iron
		ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ch.visibility_range_end = 60.0
		add_child(ch)
		_chains.append(ch)
	var l := Kit.omni(deck, deck.global_position + Vector3(-0.9, 1.6, 0.9), Color(1.0, 0.6, 0.3), 0.9, 6.0)
	l.name = "CageLamp"
	# the haul chain on the deck
	var t := Kit.touch(deck, deck.global_position + Vector3(-0.8, 1.1, 0.8), "", func(_by: Node) -> void:
		if moving():
			return
		if not _is_unlocked():
			Kit.play("clank", deck.global_position, -6.0)
			State.toast("The cage will not rise. The counterweight is pinned below.")
			return
		send(not at_top), 1.8)
	t.name = "HaulChain"
	t.set("prompt_fn", func() -> String:
		if moving():
			return ""
		if not _is_unlocked():
			return "Haul the chain"
		return "Haul the chain (down)" if at_top else "Haul the chain (up)")


## A landing's bell-rope: brings the cage to that stop. The bottom one also releases the
## counterweight the first time (when `unlock_ready` allows).
func rope(parent: Node, at: Vector3, is_top: bool) -> Node3D:
	var t := Kit.touch(parent, at, "", func(_by: Node) -> void:
		if moving():
			return
		if not _is_unlocked():
			if is_top:
				Kit.play("clank", at, -8.0)
				State.toast("The rope is cut through below. Something has to be loosed from the bottom.")
				return
			if unlock_ready.is_valid() and not bool(unlock_ready.call()):
				State.toast("The counterweight's pin is chained fast. The Sexton keeps the key.")
				return
			if on_unlock.is_valid():
				on_unlock.call()
			return
		if at_top != is_top:
			send(is_top), 1.8)
	t.name = "RopeTop" if is_top else "RopeBottom"
	t.set("prompt_fn", func() -> String:
		if moving():
			return ""
		if not _is_unlocked():
			return "Pull the bell-rope" if is_top else "Knock out the counterweight pin"
		return "" if at_top == is_top else "Call the cage")
	# the rope itself: a frayed line from a bracket, a bronze handbell at its foot
	var rope_mi := _mi(parent as Node3D, at + Vector3(0, 0.9, 0), Vector3(0.04, 1.8, 0.04), Kit.mat("rope"), true)
	rope_mi.name = "RopeLine"
	_mi(parent as Node3D, at + Vector3(0, 1.85, 0.15), Vector3(0.06, 0.06, 0.4), OssKit.mat("iron"), true)
	return t


func _is_unlocked() -> bool:
	return unlocked.is_valid() and bool(unlocked.call())


func _mi(parent: Node3D, at: Vector3, size: Vector3, m: Material, world := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	parent.add_child(mi)
	if world:
		mi.global_position = at
	else:
		mi.position = at
	return mi


func _col(body: CollisionObject3D, at: Vector3, size: Vector3, world := false) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	if world:
		cs.global_position = at
	else:
		cs.position = at

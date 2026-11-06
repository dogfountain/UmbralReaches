extends Interactable
## A chest left in one of the valley's places (r31 world pass, core/world/realm/realm_pois.gd).
## Open it with E: the lid swings up, a warm breath of motes, and what it holds goes in the satchel.
## Each chest opens once per save (Travel.system_state("world_pois").chests[chest_id]); an opened
## chest stays open, empty, on the next night. No class_name: preload by path.
##
## Loot (coordinated with the equipment pass, core/items):
##   - `loot`: ItemDB ids -> amount. Ids ItemDB does not know are skipped (so a table can name items
##     another system adds later without breaking).
##   - gear: the Gear runtime (group "gear", core/items/gear_runtime.gd). If it has
##     `roll_chest(tier, chest_id) -> Dictionary` that decides the piece; otherwise
##     `roll_drop(GEAR_SRC[tier])` (iron and reliquary chests always hold a piece, a wooden one
##     sometimes). The piece is laid as a shaft of light in front of the chest.
## Tiers: "wood" (a burner's box), "iron" (iron-banded), "reliquary" (a stone ossuary chest).

const SID := "world_pois"
const GROUP := "loot_chest"
const GEAR_SRC := {"wood": "tough", "iron": "elite", "reliquary": "elite"}
const TIER_NAME := {"wood": "the box", "iron": "the chest", "reliquary": "the reliquary chest"}

var chest_id := ""
var tier := "wood"
var loot := {}                          ## ItemDB id -> amount

var _lid: Node3D
var _motes: GPUParticles3D
var _opened := false
var _t := 0.0


static func state() -> Dictionary:
	var st := Travel.system_state(SID)
	if not (st.get("chests") is Dictionary):
		st["chests"] = {}
	return st


static func is_opened(id: String) -> bool:
	return (state().chests as Dictionary).has(id)


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	add_to_group(GROUP)
	set_meta("chest_id", chest_id)
	set_meta("tier", tier)
	_build()
	_opened = is_opened(chest_id)
	if _opened:
		_lid.rotation.x = -1.95
		_motes.emitting = false


func _build() -> void:
	var body_key := "wood"
	var band_key := "iron"
	var size := Vector3(0.95, 0.5, 0.6)
	match tier:
		"iron":
			size = Vector3(1.05, 0.56, 0.64)
		"reliquary":
			body_key = "stone"
			band_key = "bone"
			size = Vector3(1.2, 0.6, 0.7)
	var vis := Node3D.new()
	vis.name = "Vis"
	add_child(vis)
	_box(vis, Vector3(0, size.y * 0.5, 0), size, body_key)
	_box(vis, Vector3(0, 0.03, 0), Vector3(size.x + 0.06, 0.06, size.z + 0.06), band_key if tier != "wood" else "wood")
	# bands round the body (iron) or rope (wood)
	for x: float in [-size.x * 0.32, size.x * 0.32]:
		_box(vis, Vector3(x, size.y * 0.5, 0), Vector3(0.07, size.y + 0.02, size.z + 0.03), band_key)
	# lid: hinged at the back edge (local -z), so it swings up and back
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0, size.y, -size.z * 0.5)
	vis.add_child(_lid)
	var lh := 0.16 if tier != "reliquary" else 0.24
	_box(_lid, Vector3(0, lh * 0.5, size.z * 0.5), Vector3(size.x + 0.04, lh, size.z + 0.04), body_key)
	for x: float in [-size.x * 0.32, size.x * 0.32]:
		_box(_lid, Vector3(x, lh * 0.5, size.z * 0.5), Vector3(0.08, lh + 0.02, size.z + 0.07), band_key)
	if tier == "reliquary":
		# a skull on the lid, as the Ossuary's own chests have
		var sk := MeshInstance3D.new()
		sk.mesh = OssKit.skull_mesh()
		sk.material_override = OssKit.mat("bone")
		sk.position = Vector3(0, lh + 0.08, size.z * 0.5)
		sk.scale = Vector3.ONE * 0.9
		_lid.add_child(sk)
	# the lock: a small warm glint on the front, the eye's first read of "something to open"
	_box(_lid, Vector3(0, -0.02, size.z + 0.03), Vector3(0.12, 0.14, 0.04), "glow")
	_motes = Vfx.emitter(Color(1.5, 0.95, 0.45), {"count": 8, "life": 1.8, "speed": Vector2(0.05, 0.2), "size": 0.025, "gravity": -0.25, "radius": 0.4, "swirl": 0.8})
	_motes.position = Vector3(0, size.y + 0.1, 0)
	add_child(_motes)
	_motes.emitting = true
	# collision: a box you can stand on (it is furniture, not a ghost)
	var sb := StaticBody3D.new()
	sb.name = "ChestBody"
	sb.collision_layer = Layers.PROPS
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(size.x, size.y + lh, size.z)
	cs.shape = bx
	cs.position = Vector3(0, (size.y + lh) * 0.5, 0)
	sb.add_child(cs)
	add_child(sb)


func _box(parent: Node3D, at: Vector3, size: Vector3, key: String) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = OssKit.mat(key)
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if size.length() < 0.3 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


func can_interact() -> bool:
	return not _opened


func interact_text() -> String:
	return "[%s]  Open %s" % [Interactable.prompt_key(), TIER_NAME.get(tier, "the chest")]


func interact_feel() -> StringName:
	return &"use"


func interact(_by: Node) -> void:
	open()


## Open it (also called by tests): give the loot once, save soon, swing the lid.
func open() -> Array[String]:
	var got: Array[String] = []
	if _opened:
		return got
	_opened = true
	(state().chests as Dictionary)[chest_id] = true
	for id: String in loot:
		if not ItemDB.DEFS.has(id):
			continue
		var n := int(loot[id])
		Travel.give(id, n, false, false)
		got.append("%s%s" % [String(ItemDB.def(id).name), (" x%d" % n) if n > 1 else ""])
	var piece := _gear_piece()
	Travel.save_soon()
	# the toast names what entered the bag; the piece is the bag on the ground, which carries its own name
	var told := ", ".join(got) if not got.is_empty() else ("what it held is in the bag" if not piece.is_empty() else "empty, long since")
	Events.toast.emit("Opened %s: %s." % [TIER_NAME.get(tier, "the chest"), told])
	if is_inside_tree():
		Sfx.play("res://art/audio/ward_chime.wav", global_position, -8.0)
		var tw := create_tween()
		tw.tween_property(_lid, "rotation:x", -1.95, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_motes.amount_ratio = 1.0
		Vfx.burst(global_position + _motes.position, Color(1.8, 1.1, 0.5), {"count": 28, "life": 1.2, "speed": Vector2(0.4, 1.4), "size": 0.03, "gravity": -0.6, "radius": 0.3})
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if is_instance_valid(_motes):
				_motes.emitting = false)
	return got


func _gear_piece() -> Dictionary:
	if not is_inside_tree():
		return {}
	var gear := get_tree().get_first_node_in_group("gear")
	if gear == null:
		return {}
	var piece: Dictionary = {}
	if gear.has_method("roll_chest"):
		piece = gear.call("roll_chest", tier, chest_id)
	elif gear.has_method("roll_drop"):
		piece = gear.call("roll_drop", String(GEAR_SRC.get(tier, "tough")))
	if piece.is_empty():
		return {}
	var at := global_position + global_basis.z * 1.3
	if gear.has_method("drop_at"):
		gear.call("drop_at", piece, at)
	return piece

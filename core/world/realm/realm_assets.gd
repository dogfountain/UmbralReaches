extends RefCounted
## Realm module "assets" (docs/REALM_PLAN.md): the model-quality pass. Runs near the end of
## Realm.build, after land/rift/bosses/lore/flora placed their props, and:
##   1 material_pass(): OssKit masonry, lanterns, roots/branches, rune glow, glass/ember (glow budget)
##   2 upgrade_tree(root): every instance of the shared prop GLBs (found by scene_file_path) gets
##     a better mesh and/or material in place. Transforms, node names and collision are kept, so
##     code that looks them up ("Stone", "Post", "Iron*", "Ember", ...) still works.
##   3 watches node_added, so props spawned later (streamed Ossuary, lazy dressing) are upgraded too.
## upgrade(model) is public: zz/asset_shot.tscn renders before | after with it.
## RockKit (core/world/realm/rock_kit.gd) is the procedural rock library this builds on.

const RockKit := preload("res://core/world/realm/rock_kit.gd")
const T := "res://art/textures/"
const M := "res://art/models/"

## scene_file_path -> upgrade kind
const KINDS := {
	"res://art/models/menhir.glb": "menhir",
	"res://art/models/cairn.glb": "cairn",
	"res://art/models/rune_slab.glb": "rune_slab",
	"res://art/models/twisted_root.glb": "root",
	"res://art/models/fallen_branch.glb": "branch",
	"res://art/models/lantern.glb": "lantern",
	"res://art/models/stone_frame.glb": "stone_frame",
	"res://art/models/mirror_frame.glb": "mirror_frame",
	"res://art/models/rock_a.glb": "rock",
	"res://art/models/rock_b.glb": "rock",
}

static var _mats := {}
static var _meshes := {}
static var _counts := {}
static var _watching := false


static func build(root: Node) -> void:
	var t0 := Time.get_ticks_msec()
	material_pass()
	var n := upgrade_tree(root)
	if not _watching and root.is_inside_tree():
		_watching = true
		root.get_tree().node_added.connect(_on_node_added)
	print("REALM assets: upgraded %d props %s in %d ms" % [n, str(_counts), Time.get_ticks_msec() - t0])
	# r30 world pass: lanterns on the spokes, cold glints over unlit fires, rock at the world's edges
	var wf := load("res://core/world/realm/realm_wayfinding.gd") as GDScript
	if wf and wf.can_instantiate():
		wf.call("build", root)


static func upgrade_tree(root: Node) -> int:
	var n := 0
	for node in root.find_children("*", "Node3D", true, false):
		if KINDS.has(node.scene_file_path) and upgrade(node):
			n += 1
	return n


static func _on_node_added(node: Node) -> void:
	if node is Node3D and KINDS.has(node.scene_file_path):
		# deferred: the placer paints material_override right after add_child
		_upgrade_later.call_deferred(weakref(node))


static func _upgrade_later(ref: WeakRef) -> void:
	var node := ref.get_ref() as Node
	if node != null and node.is_inside_tree():
		upgrade(node)


## Upgrade one instanced prop GLB in place. Returns false if it is not a known prop or was done.
static func upgrade(model: Node) -> bool:
	if model == null or model.has_meta("realm_asset"):
		return false
	var kind: String = KINDS.get(model.scene_file_path, "")
	if kind == "":
		return false
	model.set_meta("realm_asset", true)
	var at := (model as Node3D).global_position if model.is_inside_tree() else Vector3.ZERO
	var seed_v := int(absf(at.x * 7.13 + at.z * 3.71 + at.y)) + model.name.hash()
	match kind:
		"menhir": _menhir(model, seed_v, at)
		"cairn": _cairn(model, seed_v, at)
		"rune_slab": _rune_slab(model, seed_v, at)
		"root", "branch": _wood(model)
		"lantern": _lantern(model)
		"stone_frame": _stone_frame(model)
		"mirror_frame": pass                 # the flame shader frame (mirror.gd) already reads well
		"rock": _rock(model, seed_v, at)
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	return true


# --- per-prop upgrades -------------------------------------------------------------------------

static func _mi(model: Node, n: String) -> MeshInstance3D:
	return model.find_child(n, true, false) as MeshInstance3D


static func _hide(model: Node, names: Array) -> void:
	for n: String in names:
		var mi := model.find_child(n, true, false) as GeometryInstance3D
		if mi != null:
			mi.visible = false


static func _style_at(at: Vector3, wet: String, dry: String) -> String:
	var biome := RealmLayout.biome_at(at.x, at.z)
	match biome:
		"oldforest", "fen", "glade": return wet
		"ash": return "ash" if dry == "ash" else "basalt"
		"crag": return "granite"
	return dry


## Standing stone: the four boolean "bites" become one chipped, weathered slab with a broken crown.
static func _menhir(model: Node, seed_v: int, at: Vector3) -> void:
	var stone := _mi(model, "Stone")
	if stone == null:
		return
	var style := _style_at(at, "mossy", "granite")
	stone.mesh = RockKit.slab(seed_v, Vector3(0.9, 3.2, 0.5), style, 0.3)
	stone.material_override = null
	_hide(model, ["StoneBite", "StoneCarve", "StoneFootChip", "StoneShoulder", "MossSkirt", "Lichen"])


## Cairn: the stacked boxes become a pile of rounded, chipped field stones.
static func _cairn(model: Node, seed_v: int, at: Vector3) -> void:
	var mi := _mi(model, "Stone_001")
	if mi == null:
		return
	var style := _style_at(at, "mossy", "granite")
	mi.mesh = cairn_mesh(seed_v, style)
	mi.material_override = null


static func cairn_mesh(seed_v: int, style: String) -> ArrayMesh:
	var key := "cairn|%d|%s" % [posmod(seed_v, 6), style]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	RockKit._seed_noise(rng.randi())
	var g := RockKit.Geo.new()
	var y := 0.0
	var n := rng.randi_range(5, 7)
	var w := 0.4
	for i in n:
		var f := float(i) / float(n - 1)
		var sw := lerpf(w, w * 0.38, f) * rng.randf_range(0.88, 1.08)
		var sh := sw * rng.randf_range(0.3, 0.42)
		var sz := Vector3(sw, sh, sw * rng.randf_range(0.7, 0.9))
		var sg: RockKit.Geo = RockKit._boulder_geo(rng, sz, "mossy" if style == "mossy" and i < n - 1 else "granite", 260)
		var off := Vector3(rng.randf_range(-0.03, 0.03), y, rng.randf_range(-0.025, 0.025))
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)), off)
		var tone := rng.randf_range(0.75, 1.0)
		for k in sg.col.size():
			sg.col[k].r *= tone
		g.add(sg, xf)
		y += sh * 0.92
		if i == 0:
			# a few loose stones round the foot
			for k in 3:
				var a := rng.randf() * TAU
				var ls := Vector3(0.12, 0.07, 0.1) * rng.randf_range(0.7, 1.2)
				var lg: RockKit.Geo = RockKit._boulder_geo(rng, ls, "granite", 90)
				g.add(lg, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a), 0.0, sin(a)) * w * 0.62))
	var mesh: ArrayMesh = RockKit._finish(g, style, key)
	_meshes[key] = mesh
	return mesh


## Rune slab: a dressed slab with a clean face for the glowing mark (kept; its glow tamed).
static func _rune_slab(model: Node, seed_v: int, at: Vector3) -> void:
	var stone := _mi(model, "Stone")
	if stone == null:
		return
	var style := _style_at(at, "mossy", "granite")
	# the mark sits on the -Z face: build with the flat face at +Z and turn the stone round
	stone.mesh = RockKit.slab(seed_v, Vector3(0.47, 0.74, 0.13), style, 0.18, true)
	stone.rotation.y = PI
	stone.material_override = null
	var mark := _mi(model, "Mark")
	if mark != null:
		mark.material_override = _mat("rune")
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Roots and fallen branches: same meshes, now textured bark with LODs.
static func _wood(model: Node) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.mesh = _lod(m.mesh)
		m.material_override = _mat("bark")


static func _lantern(model: Node) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var n := String(m.name)
		if n.begins_with("Post"):
			m.material_override = _mat("wood")
		elif n.begins_with("Iron"):
			m.mesh = _lod(m.mesh)
			m.material_override = _mat("iron")
		elif n.begins_with("Glass"):
			m.material_override = _mat("glass")
		elif n.begins_with("Ember"):
			m.material_override = _mat("ember")


static func _stone_frame(model: Node) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.mesh = _lod(m.mesh)
		m.material_override = _mat("frame")


static func _rock(model: Node, seed_v: int, at: Vector3) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var size := m.mesh.get_aabb().size
		m.mesh = RockKit.boulder(seed_v, size, _style_at(at, "mossy", "granite"))
		m.material_override = null


static func _lod(mesh: Mesh) -> Mesh:
	if mesh == null:
		return null
	var out := MeshChunks.with_lods(mesh)
	return out if out != null else mesh


# --- materials ---------------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"bark":
			_tri(m, "bark", 0.9, Color(0.86, 0.86, 0.96))
			m.normal_scale = 1.6
			m.roughness = 0.9
			m.rim_enabled = true
			m.rim = 0.3
			m.rim_tint = 0.4
		"wood":
			# weathered post: the bark maps, warm-tinted and finer (tavern textures are Luke's)
			_tri(m, "bark", 1.6, Color(0.78, 0.6, 0.48))
			m.normal_scale = 0.9
			m.roughness = 0.85
		"iron":
			# blackened wrought iron: micro-pitted, dull sheen
			m.albedo_color = Color(0.13, 0.13, 0.15)
			m.metallic = 0.7
			m.roughness = 0.5
			m.roughness_texture = load(T + "micro_rough.png")
			m.normal_enabled = true
			m.normal_texture = load(T + "micro_normal.png")
			m.normal_scale = 0.6
			m.uv1_triplanar = true
			m.uv1_triplanar_sharpness = 4.0
			m.uv1_scale = Vector3.ONE * 3.0
			m.rim_enabled = true
			m.rim = 0.2
			m.rim_tint = 0.5
		"frame":
			# same dressed ashlar as the Ossuary / Crossing masonry
			_tri(m, "oss_ashlar", 0.32, Color(0.74, 0.76, 0.84))
			m.normal_scale = 1.3
			m.roughness = 0.9
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.35
		"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.93, 0.68, 0.41, 0.42)
			m.roughness = 0.15
			m.emission_enabled = true
			m.emission = Color(1.0, 0.62, 0.32)
			m.emission_energy_multiplier = 0.32
		"ember":
			# the flame core of a lantern: over the glow threshold, but not a blowout (was x6)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.66, 0.36)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.6, 0.28)
			m.emission_energy_multiplier = 0.55
		"rune":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.5, 0.68, 1.0) * 0.9
			m.emission_enabled = true
			m.emission = Color(0.45, 0.66, 1.0)
			m.emission_energy_multiplier = 1.15
	_mats[key] = m
	return m


static func _tri(m: StandardMaterial3D, tex: String, scale: float, tint: Color) -> void:
	m.albedo_texture = load(T + tex + "_albedo.png")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(T + tex + "_normal.png")
	if ResourceLoader.exists(T + tex + "_rough.png"):
		m.roughness_texture = load(T + tex + "_rough.png")
	if tex != "bark" and ResourceLoader.exists(T + tex + "_ao.png"):   # the trunks dropped their occlusion; roots match
		m.ao_enabled = true
		m.ao_texture = load(T + tex + "_ao.png")
		m.ao_light_affect = 0.3
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


## Shared masonry that stays visible in the Realm (Ossuary, summit, the Crossing): OssKit's
## cached materials get a little more relief and a faint cold moonlight rim, never a restyle.
static func material_pass() -> void:
	if _mats.has("_pass"):
		return
	_mats["_pass"] = true
	for key: String in ["stone", "plaster", "floor", "slate", "dark", "iron", "wood"]:
		var m := OssKit.mat(key) as StandardMaterial3D
		if m == null:
			continue
		m.normal_scale = 1.35 if key in ["stone", "floor", "slate", "dark"] else 1.15
		if key != "iron":
			m.rim_enabled = true
			m.rim = 0.18
			m.rim_tint = 0.45
		if key == "iron":
			m.metallic = 0.65
			m.roughness = 0.6
		if m.ao_enabled:
			m.ao_light_affect = 0.3
	var bone := OssKit.mat("bone") as StandardMaterial3D
	if bone != null:
		bone.normal_scale = 1.2

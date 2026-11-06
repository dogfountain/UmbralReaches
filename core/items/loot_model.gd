extends RefCounted
## What a loot drop looks like lying on the ground: the real thing, not a bundle. Gear is its own
## slot's piece (an orb in a cradle, a folded vestment, a lantern, a coiled belt); a trophy or charm
## takes the shape its ItemDB entry names (a fist of rings, a crown, a mask); materials are a pouch,
## relics a reliquary box, staff cores a crystal. The meshes are art/models/loot_props.glb, made by
## tools/blender/loot_props.py. Rarity shows in the surfaces named LP_Trim (the metal rim, the hem,
## the buckle, the studs: the quality colour) and LP_Gem (the glass or jewel: the quality colour, with
## a faint glow from Hallowed up); LP_Tint* surfaces take the item's own tint. Load by path:
##   const LootModel := preload("res://core/items/loot_model.gd")

const GearDB := preload("res://core/items/gear_db.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const PROPS := preload("res://art/models/loot_props.glb")

## Drawn larger than life so a drop reads from ten metres.
const GROUND_SCALE := 1.5

const SLOT_MODEL := {"focus": "OrbFocus", "vestment": "Vestment", "lantern": "Lantern", "girdle": "Girdle"}
## ItemDB shape -> mesh, for trophies and charms. Anything not here is a Ring (charm) or a Stone (trophy).
const SHAPE_MODEL := {
	"fist": "Fist", "tablet": "Tablet", "branch": "Branch", "stone": "Stone", "mask": "Mask",
	"crown": "Crown", "sigil": "Sigil", "lantern": "Lantern", "bell": "Lantern",
}
## Per-shape size on top of GROUND_SCALE, for the things that are small in the hand.
const SHAPE_SCALE := {"Fist": 1.9, "Mask": 1.5, "Ring": 1.3, "Crystal": 1.4, "Crown": 1.25, "Sigil": 1.15}
## Glow a jewel carries at each quality (Worn and Kindled are plain glass).
const GEM_GLOW := [0.0, 0.0, 0.3, 0.55, 0.9]

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


## The mesh name for a loot entry ({kind: "gear", piece} | {kind: "item", id}).
static func model_name(e: Dictionary) -> String:
	if String(e.get("kind", "")) == "gear":
		return String(SLOT_MODEL.get(String((e.get("piece", {}) as Dictionary).get("slot", "")), "Vestment"))
	var d: Dictionary = ItemDB.def(String(e.get("id", "")))
	match String(d.get("kind", "material")):
		"relic":
			return "Reliquary"
		"core":
			return "Crystal"
		"material":
			return "Pouch"
		"charm":
			return String(SHAPE_MODEL.get(String(d.get("shape", "")), "Ring"))
	return String(SHAPE_MODEL.get(String(d.get("shape", "")), "Stone"))


## The item lying down for `e` at quality `q`, as a Node3D whose base rests on y = 0. Null when the
## art is missing.
static func build(e: Dictionary, q: int) -> Node3D:
	var nm := model_name(e)
	var mesh := _mesh(nm)
	if mesh == null:
		return null
	var tint_col := Color(0.7, 0.7, 0.7)
	var gem_col := LootDB.quality_color(q)
	if String(e.get("kind", "")) != "gear":
		var d: Dictionary = ItemDB.def(String(e.get("id", "")))
		tint_col = d.get("tint", tint_col)
		if nm == "Crystal":
			gem_col = tint_col
	var root := Node3D.new()
	root.name = "Item"
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.scale = Vector3.ONE * GROUND_SCALE * float(SHAPE_SCALE.get(nm, 1.0))
	mi.rotation.y = float(absi(hash(nm + str(e.get("id", (e.get("piece", {}) as Dictionary).get("uid", 0))))) % 628) * 0.01
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)
	for i in mesh.get_surface_count():
		var base := mesh.surface_get_material(i) as BaseMaterial3D
		if base == null:
			continue
		var dressed := _dress(base, q, gem_col, tint_col)
		if dressed != base:
			mi.set_surface_override_material(i, dressed)
	return root


## Height of the item (metres, scaled) for placing a glint above it.
static func height_of(item: Node3D) -> float:
	if item == null or item.get_child_count() == 0:
		return 0.2
	var mi := item.get_child(0) as MeshInstance3D
	return mi.get_aabb().size.y * mi.scale.y if mi else 0.2


static func _mesh(nm: String) -> Mesh:
	if _meshes.is_empty():
		var scene := PROPS.instantiate()
		for c in scene.get_children():
			var m := c as MeshInstance3D
			if m and m.mesh:
				_meshes[String(m.name)] = m.mesh
		scene.free()
	return _meshes.get(nm) as Mesh


static func _dress(base: BaseMaterial3D, q: int, gem_col: Color, tint_col: Color) -> Material:
	var key := ""
	var kind := base.resource_name
	if kind == "LP_Trim" or kind == "LP_Thread":
		key = "%s%d" % [kind, q]
	elif kind == "LP_Gem":
		key = "gem%s%d" % [gem_col.to_html(false), q]
	elif kind.begins_with("LP_Tint"):
		key = "%s%s" % [kind, tint_col.to_html(false)]
	else:
		return base
	if _mats.has(key):
		return _mats[key]
	var m := base.duplicate() as BaseMaterial3D
	if kind == "LP_Thread":
		var tc := LootDB.quality_color(q)
		m.albedo_color = Color(tc.r * 0.9, tc.g * 0.9, tc.b * 0.9)
		m.metallic = 0.0
		m.roughness = 0.85
	elif kind == "LP_Trim":
		var c := LootDB.quality_color(q)
		m.albedo_color = Color(c.r * 0.95, c.g * 0.95, c.b * 0.95)
		m.metallic = 0.75
		m.roughness = 0.42
		if q >= 3:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 0.12 * float(q - 2)
	elif kind == "LP_Gem":
		m = StandardMaterial3D.new()
		m.albedo_color = Color(gem_col.r * 0.55, gem_col.g * 0.55, gem_col.b * 0.55)
		m.metallic = 0.1
		m.roughness = 0.06
		m.rim_enabled = true
		m.rim = 0.6
		m.rim_tint = 0.5
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.04
		var glow: float = GEM_GLOW[clampi(q, 0, 4)]
		m.emission_enabled = true
		m.emission = gem_col
		m.emission_energy_multiplier = 0.05 + glow
	else:
		m.albedo_color = Color(minf(tint_col.r * 1.1, 1.0), minf(tint_col.g * 1.1, 1.0), minf(tint_col.b * 1.1, 1.0))
	_mats[key] = m
	return m

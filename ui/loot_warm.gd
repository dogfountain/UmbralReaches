extends RefCounted
## Loot and kill first-use costs, paid under the loading screen: a ground bag for each kind of model
## and quality (the beam shader, the glowing and plain gem materials, the name label's glyphs), a gear
## drop, and the floating combat text with the letters and digits a fight prints. The loading screen
## shows them with the combat set and frees them with it through `clear`. No class_name: loaded by path.

const GearDB := preload("res://core/items/gear_db.gd")
const LootBagScript := preload("res://core/items/loot_bag.gd")
const GearDropScript := preload("res://core/items/gear_drop.gd")

const SLOTS := ["focus", "vestment", "lantern", "girdle"]
## One item id per ground model (pouch, reliquary, crystal, ring, fist, tablet, branch, stone, mask,
## crown, sigil, lantern), at a mid quality.
const ITEMS := ["grave_ash", "thorn_heart", "charm_ring", "hobbs_knuckles", "lisles_tally", "briar_antler", "heart_stone",
	"scraped_face", "abbot_crown", "ascension_seal", "cinder_censer", "ember_shard"]
const ALPHABET := "The quick brown fox jumps over the lazy dog. THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG 0123456789 +-'x%,:()"


## Lay everything out in a row in front of the camera; returns the nodes to hand back to `clear`.
static func show(zone: Node3D, c: Vector3, right: Vector3, fwd: Vector3) -> Array[Node]:
	var out: Array[Node] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var k := 0
	var base := c + fwd * 3.0
	for slot: String in SLOTS:
		for q: int in [0, 2, 4]:
			var piece := GearDB.make(rng, {"rarity": q, "slot": slot})
			out.append(_bag(zone, [{"kind": "gear", "piece": piece}, {"kind": "item", "id": "ember_shard", "n": 2}], base + right * (float(k) - 10.0) * 0.55))
			k += 1
	for id: String in ITEMS:
		out.append(_bag(zone, [{"kind": "item", "id": id, "n": 1}], base + right * (float(k) - 10.0) * 0.55 + fwd * 1.2))
		k += 1
	for r in 5:
		var d := GearDropScript.new()
		d.piece = GearDB.make(rng, {"rarity": r, "slot": SLOTS[r % SLOTS.size()]})
		zone.add_child(d)
		d.global_position = base + right * (float(r) - 2.0) * 0.8 - fwd * 1.0
		d.remove_from_group(&"gear_drop")
		out.append(d)
	out.append(_label(zone, 40, 10, base + Vector3.UP * 3.2))
	out.append(_label(zone, 36, 9, base + Vector3.UP * 3.6))
	HitText.pop(base + Vector3.UP * 2.6, ALPHABET, Color(1.0, 0.8, 0.5), false)
	HitText.pop(base + Vector3.UP * 2.9, ALPHABET, Color(1.1, 0.7, 2.2), true)
	return out


static func _label(zone: Node3D, size: int, outline: int, at: Vector3) -> Label3D:
	var lab := Label3D.new()
	lab.text = ALPHABET
	lab.font_size = size
	lab.outline_size = outline
	lab.pixel_size = 0.004
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.add_child(lab)
	lab.global_position = at
	return lab


static func _bag(zone: Node3D, entries: Array, at: Vector3) -> Node3D:
	var b := LootBagScript.new()
	b.entries = entries
	zone.add_child(b)
	b.global_position = at
	b.remove_from_group(&"loot_bag")                 # nothing targets or names these
	b.remove_from_group(Groups.INTERACTABLE)
	return b


## Free what `show` made. Bags and drops pour what they hold into the satchel when they leave the tree,
## so they are emptied first.
static func clear(nodes: Array[Node]) -> void:
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if n is GearDropScript:
			(n as GearDropScript).piece = {}
		elif n is LootBagScript:
			(n as LootBagScript).entries = []
		n.queue_free()

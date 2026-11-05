extends RefCounted
## THE NINTH COMPANY'S OFFERING (r28, agent D): the ritual ring the lore builds in the Thornwood
## (core/world/realm/lore/scenes.gd) keeps an offering in its ninth stone. It only shows itself to
## someone who has read the company's three letters (the camp, Aldo's grave, the ring): a
## collectible story that unlocks something. Until then the stone is only a stone.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const LETTERS := ["nc_company_1", "nc_company_2", "nc_company_3"]


static func told() -> bool:
	for id: String in LETTERS:
		if not CodexStore.has_read(id):
			return false
	return true


static func build(_root: Node, host: Node3D) -> void:
	var Scenes: GDScript = load("res://core/world/realm/lore/scenes.gd")
	var ring: Dictionary = Scenes.get("ring")
	var placed: Dictionary = Scenes.get("placed")
	if ring.is_empty() or not placed.has("ring"):
		print("SECRETS ninth company: no ring placed")
		return
	var node := Node3D.new()
	node.name = "NinthOffering"
	host.add_child(node)
	var stone: Vector3 = ring.at
	var inner: Vector3 = ring.inner
	var size: Vector3 = ring.size
	var c: Vector3 = placed.ring
	var at := stone + inner * (size.z * 0.5 + 0.08) + Vector3.UP * 0.55
	# the niche at the stone's foot: a dark hollow and the offering in it, hidden by a stone plug
	var k := OssKit.new()
	k.keep_lanes = false
	var b := Basis(Vector3.UP, atan2(inner.x, inner.z))
	k.box("dark", at + Vector3.DOWN * 0.1, Vector3(0.42, 0.36, 0.06), b, false, 0.3)
	k.commit(node, "OfferingBody")
	var plug := Kit.mi(node, _box(Vector3(0.5, 0.42, 0.14)), OssKit.mat("lore_moss") if OssKit._mats.has("lore_moss") else OssKit.mat("stone"), Transform3D(b, at + Vector3.DOWN * 0.08 + inner * 0.04), 60.0)
	var gift := Kit.mi(node, _box(Vector3(0.16, 0.14, 0.12)), Kit.mat("bronze"), Transform3D(b, at + Vector3.DOWN * 0.18 + inner * -0.02), 40.0, false)
	var glint := Kit.glint(node, at + Vector3.UP * 0.25 + inner * 0.2, Color(1.0, 0.75, 0.45), 0.3)
	State.cache(node, "company", at, "the Ninth Company's offering", func(_a: bool) -> void: gift.visible = false, func() -> bool: return told())
	var watch := Timer.new()
	watch.wait_time = 1.0
	watch.autostart = true
	node.add_child(watch)
	var shown := [false]
	var sync := func(animate: bool) -> void:
		var open := told()
		var taken := State.has("looted", "company")
		glint.visible = open and not taken
		gift.visible = open and not taken
		if open and not shown[0]:
			shown[0] = true
			var to := Transform3D(b * Basis(Vector3.RIGHT, 1.2), at + Vector3.DOWN * 0.42 + inner * 0.45)
			if animate:
				Kit.play("grind", at, -8.0, 1.6)
				plug.create_tween().tween_property(plug, "global_transform", to, 0.9)
			else:
				plug.global_transform = to
	watch.timeout.connect(func() -> void: sync.call(true))
	State.register({"id": "company", "name": "The Ninth Company's Ring", "at": c, "r": 5.5, "node": node, "sync": sync,
		"route": {"from": Vector3(c.x + 9.0, 0.0, c.z + 2.0), "pts": [Vector3(c.x + 5.5, 0, c.z + 1.0), Vector3(c.x + 1.5, 0, c.z - 1.6)] as Array[Vector3]},
		"goal": Vector3(c.x + 1.5, 0, c.z - 1.6)})
	sync.call(false)


static func _box(size: Vector3) -> BoxMesh:
	var bx := BoxMesh.new()
	bx.size = size
	return bx

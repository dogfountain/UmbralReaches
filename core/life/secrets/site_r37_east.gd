extends RefCounted
## East Marches (docs/r37_expansion.md): two hidden things, each beside a place the wanderer has a
## reason to visit (realm_pois_r37_east.gd), in the earlier-round manner:
##   boathouse    THE SUNKEN BOAT-HOUSE (Stillwater): a timber boat-house the lake took to its roof, on the
##                lake's west shore (the sunken boat-house slot of RealmLayout.SLOTS). Wade in under the
##                roof: the lamplighters' oil-chest and the boat-keeper's tin. (Reading the log, the
##                Spire's lamp wants oil: the quest asks only for a coal, but the chest hands out ember.)
##   salt_vault   THE BRINE-CLERK'S VAULT (White Pans): a strongroom under the crust by the crystals, shut
##                by a hatch. Three brine valves stand beside the pans; the clerk's slate gives their
##                order (east, west, middle). Turned right, the hatch slides off. A wrong valve floods the
##                sluice: they all shut again (as the Ninth Rank's lamps go out).
## State: secrets' own (State: open.boathouse? no: found.*, looted.*, solved.salt_vault). Texts: pages.gd.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const WATER := -0.9

## Valve order, left to right as they stand (west, middle, east): the slate's words (east, west, middle).
const VALVE_ORDER := [2, 0, 1]
static var _turned: Array[int] = []


static func release() -> void:
	_turned.clear()


static func build(root: Node, host: Node3D) -> void:
	_turned.clear()
	var pois := root.get_node_or_null("RealmPois")
	if pois == null:
		print("SECRETS r37e: no places built")
		return
	_boathouse(root, host)
	_vault(root, host, pois.get_node_or_null("Poi_saltworks") as Node3D, pois.get_node_or_null("Poi_crust") as Node3D)


static func _bx(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _camp_near(q: Vector2, r: float) -> bool:
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var a: Vector3 = c.at
		if Vector2(a.x, a.z).distance_to(q) < r:
			return true
	return false


# --- the Sunken Boat-House -----------------------------------------------------------------------------

static func _boathouse(root: Node, host: Node3D) -> void:
	var sp := Kit.space(root)
	# the slot's spot, else the best ring of low ground round it: under the water line, off the camps
	var want := Vector2(196, -14)
	var best := Vector2.INF
	var best_d := INF
	for r: float in [0.0, 3.0, 6.0, 9.0, 12.0]:
		for i in (1 if r == 0.0 else 8):
			var a := TAU * float(i) / 8.0
			var q := want + Vector2(cos(a), sin(a)) * r
			var g := Kit.low(sp, q, 2.4)
			if g < WATER - 0.2 and g > WATER - 3.2 and WorldLanes.site_at(q, 4.0).is_empty() and not _camp_near(q, 9.0) and r < best_d:
				best_d = r
				best = q
	if best == Vector2.INF:
		print("SECRETS boat-house: no shallow water near %s" % want)
		return
	var bottom := Kit.low(sp, best, 2.4)
	var out := (best - RealmLayout.LAKE_C)
	out = out.normalized() if out.length() > 0.5 else Vector2(1, 0)
	var yaw := atan2(out.x, out.y)                      # local +z: toward the shore (the open end)
	var b := Basis(Vector3.UP, yaw)
	var top := WATER + 1.3
	var c := Vector3(best.x, bottom, best.y)
	var node := Node3D.new()
	node.name = "SunkBoathouse"
	node.set_meta("site", "secrets_boathouse")
	host.add_child(node)
	LK.ensure_mats()
	var k := OssKit.new()
	k.keep_lanes = false
	var h := top - bottom
	var W := 4.6
	var D := 6.2
	# floor on the lake bed, three walls to the roof, a pitched roof of old shingles, the posts of a slip
	k.box("wood", c + b * Vector3(0, 0.1, 0), Vector3(W, 0.2, D), b, true, 0.7)
	k.box("wood", c + b * Vector3(-W * 0.5, h * 0.5, 0), Vector3(0.22, h, D), b, true, 0.7)
	k.box("wood", c + b * Vector3(W * 0.5, h * 0.5, 0), Vector3(0.22, h, D), b, true, 0.7)
	k.box("wood", c + b * Vector3(0, h * 0.5, -D * 0.5), Vector3(W, h, 0.22), b, true, 0.7)
	k.box("slate", c + b * Vector3(-W * 0.25, h + 0.15, 0), Vector3(W * 0.6, 0.16, D + 0.6), b * Basis(Vector3.FORWARD, 0.28), true, 0.8)
	k.box("slate", c + b * Vector3(W * 0.25, h + 0.15, 0), Vector3(W * 0.6, 0.16, D + 0.6), b * Basis(Vector3.FORWARD, -0.28), true, 0.8)
	for sz: float in [-1.0, 1.0]:
		k.box("wood", c + b * Vector3(sz * 1.2, h * 0.5, D * 0.5 + 1.0), Vector3(0.18, h, 0.18), b, false, 0.65)
	# a boat on its slip inside: a long dark hull, overturned
	k.box("dark", c + b * Vector3(0.9, 0.6, 0.4), Vector3(1.3, 0.8, 3.6), b, true, 0.6)
	k.box("iron", c + b * Vector3(-1.4, 1.1, -2.4), Vector3(0.1, 0.9, 0.1), b, false, 0.8)
	k.commit(node, "BoathouseBody")
	var chest_at := c + b * Vector3(-1.2, 0.2, -1.6)
	State.cache(node, "boathouse", chest_at + Vector3.UP * 0.5, "the lamplighters' oil-chest", Callable())
	State.reading(node, "sc_boat_lamp", c + b * Vector3(-W * 0.5 + 0.3, minf(h - 0.4, 2.2), 1.0))
	State.reading(node, "sc_boat_log", c + b * Vector3(1.0, 1.4, -2.6))
	var oil := Kit.mi(node, _bx(Vector3(0.7, 0.45, 0.5)), OssKit.mat("wood"), Transform3D(b, chest_at + Vector3.UP * 0.22), 60.0)
	Kit.site(root, "secrets_boathouse", Rect2(best.x - W, best.y - D, W * 2.0, D * 2.0), bottom)
	var shore := best + out * 16.0
	State.register({"id": "boathouse", "name": "The Sunken Boat-House", "at": c + Vector3.UP * 1.0, "r": 6.0, "node": node,
		"route": {"from": Vector3(shore.x, 0, shore.y), "pts": [c + b * Vector3(0, 0, D * 0.5 + 1.0)] as Array[Vector3]},
		"goal": c + b * Vector3(0, 0, 0.5),
		"sync": func(_animate: bool) -> void:
			oil.scale = Vector3(1, 0.4, 1) if State.has("looted", "boathouse") else Vector3.ONE})
	print("SECRETS boat-house at %s (bed %.1f, %.1f m off the slot)" % [c.snapped(Vector3.ONE * 0.1), bottom, best_d])


# --- the Brine-Clerk's Vault ---------------------------------------------------------------------------

static func _vault(root: Node, host: Node3D, works: Node3D, crust: Node3D) -> void:
	if works == null or crust == null:
		print("SECRETS salt vault: no pans")
		return
	var R37E := load("res://core/world/realm/realm_pois_r37_east.gd") as GDScript
	var spots: Dictionary = R37E.get("spots")
	if not spots.has("saltworks") or not spots.has("crust"):
		print("SECRETS salt vault: no spots")
		return
	var sp := Kit.space(root)
	var wc: Vector3 = (spots.saltworks as Dictionary).at
	var cc: Vector3 = (spots.crust as Dictionary).at
	var node := Node3D.new()
	node.name = "SaltVault"
	node.set_meta("site", "secrets_vault")
	host.add_child(node)
	LK.ensure_mats()
	var k := OssKit.new()
	k.keep_lanes = false
	# the three valves, left to right (west, middle, east), each an iron wheel on a post beside the pans
	var vp: Array[Vector3] = []
	for off: Vector2 in [Vector2(-14.8, 6.0), Vector2(-1.0, 14.5), Vector2(13.2, 6.0)]:
		var p := Vector3(wc.x + off.x, 0, wc.z + off.y)
		p.y = Kit.gy(sp, p.x, p.z)
		vp.append(p)
	var wheels: Array[MeshInstance3D] = []
	var flames: Array[MeshInstance3D] = []
	for i in 3:
		var p := vp[i]
		k.box("wood", p + Vector3.UP * 0.55, Vector3(0.2, 1.1, 0.2), Basis.IDENTITY, true, 0.7)
		k.box("iron", p + Vector3.UP * 1.1, Vector3(0.3, 0.1, 0.3), Basis.IDENTITY, false, 0.75)
		var wheel := Kit.mi(node, _bx(Vector3(0.6, 0.06, 0.06)), OssKit.mat("iron"), Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.18), 60.0)
		wheels.append(wheel)
		var fl := Kit.mi(node, QuadMesh.new(), Kit.shader_mat("glint"), Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.7), 50.0, false)
		(fl.mesh as QuadMesh).size = Vector2(0.4, 0.4)
		fl.set_instance_shader_parameter(&"tint", Color(0.7, 0.85, 1.0))
		fl.visible = false
		flames.append(fl)
		var idx := i
		var t := Kit.touch(node, p + Vector3(0, 1.1, 0.6), "", func(_by: Node) -> void: turn(idx, flames, vp[idx]), 2.2)
		t.name = "Valve_%d" % i
		var label: String = ["Turn the west valve", "Turn the middle valve", "Turn the east valve"][i]
		t.set("prompt_fn", func() -> String: return "" if State.has("solved", "salt_vault") else label)
	# the strongroom hatch on the crust, by the great crystal: a stone-framed lid that slides off
	var hp := Vector3(cc.x + 3.4, 0, cc.z - 3.8)
	hp.y = Kit.gy(sp, hp.x, hp.z)
	k.box("stone", hp + Vector3(0, 0.05, 0), Vector3(2.8, 0.2, 2.8), Basis.IDENTITY, true, 0.8)
	k.commit(node, "VaultBody")
	var lid := Kit.mi(node, _bx(Vector3(2.2, 0.16, 2.2)), OssKit.mat("stone"), Transform3D(Basis.IDENTITY, hp + Vector3.UP * 0.22), 80.0)
	var lid_body := Kit.box_body(node, hp + Vector3.UP * 0.22, Vector3(2.2, 0.16, 2.2), Basis.IDENTITY)
	State.cache(node, "salt_vault", hp + Vector3(0, 0.5, 0), "the brine-clerk's strongroom", Callable(), func() -> bool: return State.has("solved", "salt_vault"))
	State.reading(node, "sc_vault_slate", Vector3(wc.x - 12.0, Kit.gy(sp, wc.x - 12.0, wc.z + 12.5) + 0.9, wc.z + 12.5))
	State.reading(node, "sc_vault_plate", hp + Vector3(1.9, 0.9, 0.0))
	Kit.site(root, "secrets_vault", Rect2(hp.x - 2.2, hp.z - 2.2, 4.4, 4.4), hp.y)
	var sync := func(animate: bool) -> void:
		var done := State.has("solved", "salt_vault")
		for m in flames:
			if is_instance_valid(m):
				m.visible = done or (flames.find(m) in _turned)
		Kit.set_body(lid_body, not done)
		var to := Transform3D(Basis(Vector3.UP, 0.2), hp + Vector3(2.0, 0.0, 0.2))
		if done and animate:
			Kit.play("grind", hp, -4.0, 1.2)
			lid.create_tween().tween_property(lid, "global_transform", to, 1.4).set_trans(Tween.TRANS_SINE)
		elif done:
			lid.global_transform = to
	State.register({"id": "salt_vault", "name": "The Brine-Clerk's Vault", "at": hp, "r": 5.0, "node": node, "sync": sync,
		"lamps": flames, "order": VALVE_ORDER, "tomb": hp, "lid": lid_body,
		"route": {"from": Vector3(hp.x, 0, hp.z) + Vector3(0, 0, 10.0), "pts": [hp + Vector3(0, 0, 2.2)] as Array[Vector3]},
		"goal": hp + Vector3(0, 0, 2.2)})
	sync.call(false)
	print("SECRETS salt vault: hatch at %s, valves %s" % [hp.snapped(Vector3.ONE * 0.1), vp.size()])


## Turn valve `idx`: in the slate's order the hatch opens; out of it the sluice floods and all shut.
static func turn(idx: int, flames: Array[MeshInstance3D], at: Vector3) -> void:
	if State.has("solved", "salt_vault") or idx in _turned:
		return
	var want: int = VALVE_ORDER[_turned.size()]
	if idx != want:
		_turned.clear()
		for m in flames:
			if is_instance_valid(m):
				m.visible = false
		Kit.play("thud", at, -4.0)
		State.toast("Brine rushes through the sluice and the valves spring shut together. The pans go very quiet.")
		return
	_turned.append(idx)
	if idx < flames.size() and is_instance_valid(flames[idx]):
		flames[idx].visible = true
	Kit.play("chime", at, -8.0, 0.8 + 0.15 * float(_turned.size()))
	if _turned.size() < VALVE_ORDER.size():
		return
	_turned.clear()
	State.mark("solved", "salt_vault")
	State.toast("Three valves open. Out on the crust, stone grinds on stone.")
	State.banner("the brine-clerk's vault is open", "The Brine-Clerk's Vault")
	State.refresh(true)

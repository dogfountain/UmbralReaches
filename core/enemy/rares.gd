extends Node3D
## r33 RARES (WoW's named rare spawns, adapted): a few named hollowed walk a slow beat round a fixed
## haunt in the Realm. Each is a camp kind grown large and strange -- more health, a silver shimmer, a
## name over it (Enemy.rank() == "rare", Enemy.display_name()) -- and pays better than a camp: grave ash,
## relic fragments, and the loot system's rare bag (core/items/gear_runtime.gd reads metas "rare_id" and
## "rare_name": ember shards and a gear piece, a named one on its first fall).
## Their haunts are map markers (group "map_marker", meta map_kind "rare"); the marker leaves the map
## while its rare is dead and comes back when it does (RESPAWN seconds later, not while you watch).
## Built by EnemySpawner once the Realm's camps are planted (realm only). Load by path (no class_name).
##   rares.spawn_rare(id) -> Enemy     tests call it directly
##   rares.marker(id) -> Node3D        its map marker

const EliteKit := preload("res://core/life/encounters/elite_kit.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const TICK := 0.5
const NEAR := 95.0              ## the rare walks its beat while you are within this (and it is not dead)
const FAR := 130.0              ## further than this it goes back into the dark, healed
const RESPAWN := 480.0
const SILVER := Color(0.78, 0.86, 1.0)
const BEAT_R := 6.0

## id -> {title, kind (EnemySpawner key), spots (candidate haunts, first clear one wins), hp, scale,
## ash, loot [[item id, count], ...], line (the toast when it falls)}
const RARES := {
	"gutterwick": {"title": "Gutterwick the Lamp-Eater", "kind": "wretch", "hp": 22, "scale": 1.3,
		"spots": [Vector2(-66, 34), Vector2(-62, 28), Vector2(-74, 32), Vector2(-96, 6), Vector2(-70, -40), Vector2(-100, -10)], "ash": 30, "loot": [["relic_fragment", 1]],
		"line": "Gutterwick falls. The lamp-oil in its belly burns blue, then out."},
	"mother_sallow": {"title": "Mother Sallow", "kind": "spitter", "hp": 18, "scale": 1.3,
		"spots": [Vector2(84, -22), Vector2(90, 6), Vector2(100, 12)], "ash": 32, "loot": [["relic_fragment", 2]],
		"line": "Mother Sallow sinks into the fen she nursed."},
	"wicker_jack": {"title": "Wicker Jack, the Grinning", "kind": "gaunt", "hp": 20, "scale": 1.25,
		"spots": [Vector2(12, 72), Vector2(-12, 74), Vector2(24, 74)], "ash": 30, "loot": [["relic_fragment", 1]],
		"line": "Wicker Jack comes apart in straw and teeth."},
	"cairnback": {"title": "Cairnback", "kind": "husk", "hp": 34, "scale": 1.35,
		"spots": [Vector2(84, -50), Vector2(70, -30), Vector2(90, -44)], "ash": 40, "loot": [["relic_fragment", 3]],
		"line": "Cairnback settles, a barrow at last."},
}

var haunts: Dictionary = {}      ## id -> Vector3 on the ground
var nodes: Dictionary = {}       ## id -> Enemy
var _markers: Dictionary = {}    ## id -> Node3D
var _dead_until: Dictionary = {} ## id -> msec when it may walk again
var _acc := 0.0
var _scripts: Dictionary = {}


func _ready() -> void:
	name = "Rares"
	Events.enemy_killed.connect(_on_killed)


## `scripts`: EnemySpawner's kind -> GDScript map.
func setup(scripts: Dictionary) -> void:
	_scripts = scripts
	var space := get_world_3d().direct_space_state
	for id: String in RARES:
		for c: Vector2 in RARES[id].spots:
			var g := _ground(space, Vector3(c.x, 90.0, c.y))
			if g == Vector3.INF or LightGrid.is_lit(g):
				continue
			if not WorldLanes.site_at(c, 1.0).is_empty():
				continue
			haunts[id] = g
			break
		if not haunts.has(id):
			push_warning("Rares: no clear haunt for %s" % id)
			continue
		_markers[id] = _make_marker(id, haunts[id])


## Twice a second: walk the beat near you, rest in the dark far off, come back after RESPAWN.
func _process(delta: float) -> void:
	_acc += delta
	if _acc < TICK:
		return
	_acc = 0.0
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	var now := Time.get_ticks_msec()
	for id: String in haunts:
		var at: Vector3 = haunts[id]
		var e := nodes.get(id) as Enemy if is_instance_valid(nodes.get(id)) else null
		var d := p.global_position.distance_to(at)
		if e == null:
			nodes.erase(id)
			if now >= int(_dead_until.get(id, 0)) and d < NEAR and d > 30.0 and not LightGrid.is_lit(at):
				spawn_rare(id)
			continue
		var de := p.global_position.distance_to(e.global_position)
		if d > FAR and de > FAR:
			e.queue_free()                         # back into the dark, whole
			nodes.erase(id)
		elif de > e.sleep_range:
			e.sleep()
		else:
			e.wake()


func spawn_rare(id: String) -> Enemy:
	if not RARES.has(id) or not haunts.has(id):
		return null
	if is_instance_valid(nodes.get(id)):
		return nodes[id] as Enemy
	var d: Dictionary = RARES[id]
	var script: GDScript = _scripts.get(String(d.kind))
	if script == null:
		script = load("res://core/enemy/%s.gd" % String(d.kind)) as GDScript
	if script == null:
		return null
	var at: Vector3 = haunts[id]
	var e := script.new() as Enemy
	e.max_hp = int(d.hp)
	e.hp = float(e.max_hp)
	e.chase_range = maxf(e.chase_range, 14.0)
	e.hunt_leash = maxf(e.hunt_leash, 22.0)
	e.sleep_range = 70.0
	e.poise += 1.5
	e.strike_gloom *= 1.2
	e.can_flee = false
	e.hp_bar_y *= float(d.scale) * 0.95
	e.set_meta(&"rare_id", id)
	e.set_meta(&"display_name", String(d.title))
	e.set_meta(&"rare_name", String(d.title))      # the loot bag's title (gear_runtime.drop_rare)
	EliteKit.scale(e, Tiers.tier_at(at), false)
	get_parent().add_child(e)
	e.global_position = at + Vector3.UP * 0.05
	e.home = at
	e.patrol = _beat(at)
	if e._rig:
		e._rig.scale *= float(d.scale)
	_shimmer(e)
	nodes[id] = e
	_show_marker(id, true)
	return e


func marker(id: String) -> Node3D:
	return _markers.get(id) as Node3D


func _on_killed(e: Node) -> void:
	if e == null or not e.has_meta(&"rare_id"):
		return
	var id := String(e.get_meta(&"rare_id"))
	if not RARES.has(id):
		return
	var d: Dictionary = RARES[id]
	_dead_until[id] = Time.get_ticks_msec() + int(RESPAWN * 1000.0)
	nodes.erase(id)
	_show_marker(id, false)
	var got: Array[String] = []
	var ash := int(d.ash) * (1 + int(int(e.get_meta(&"enc_tier", 0)) >= 3))
	Travel.give("grave_ash", ash, false)
	got.append("%d grave ash" % ash)
	for pair: Array in d.loot:
		Travel.give(String(pair[0]), int(pair[1]), false)
		got.append("%d %s" % [int(pair[1]), String(ItemDB.def(String(pair[0])).get("name", pair[0]))])
	Events.toast.emit("%s  (%s)" % [String(d.line), ", ".join(got)])
	if e is Node3D:
		var at := (e as Node3D).global_position + Vector3.UP
		Vfx.burst(at, SILVER, {"count": 40, "life": 1.0, "speed": Vector2(1.0, 4.0), "size": 0.06, "gravity": -1.5, "trail": 0.06})
	Travel.save_soon()


## Three points round the haunt on the ground (the beat it walks).
func _beat(at: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [at]
	var space := get_world_3d().direct_space_state
	var a0 := float(hash(at.snapped(Vector3.ONE)) % 628) * 0.01
	for k in 3:
		var a := a0 + TAU * float(k) / 3.0
		var g := _ground(space, at + Vector3(cos(a) * BEAT_R, 6.0, sin(a) * BEAT_R))
		if g != Vector3.INF and absf(g.y - at.y) < 2.5 and not LightGrid.is_lit(g):
			out.append(g)
	return out


## Silver about it: a faint light and a few rising motes (it reads as "not a camp pawn" at range).
func _shimmer(e: Enemy) -> void:
	var l := OmniLight3D.new()
	l.name = "RareShimmer"
	l.light_color = SILVER
	l.light_energy = 0.7
	l.omni_range = 3.2
	l.shadow_enabled = false
	l.position = Vector3.UP * e.hp_bar_y * 0.6
	e.add_child(l)
	var fx := Vfx.emitter(Color(SILVER.r * 1.6, SILVER.g * 1.6, SILVER.b * 1.8), {"count": 14, "life": 1.4, "speed": Vector2(0.1, 0.5), "size": 0.035, "gravity": -0.5, "radius": 0.5, "turbulence": true})
	fx.position = Vector3.UP * e.hp_bar_y * 0.5
	e.add_child(fx)
	fx.emitting = true


func _make_marker(id: String, at: Vector3) -> Node3D:
	var m := Node3D.new()
	m.name = "RareMarker_" + id
	m.set_meta("map_kind", "rare")
	m.set_meta("map_label", String(RARES[id].title))
	m.set_meta("map_color", SILVER)
	add_child(m)
	m.global_position = at
	m.add_to_group(&"map_marker")
	return m


func _show_marker(id: String, on: bool) -> void:
	var m := _markers.get(id) as Node3D
	if m == null:
		return
	if on and not m.is_in_group(&"map_marker"):
		m.add_to_group(&"map_marker")
	elif not on and m.is_in_group(&"map_marker"):
		m.remove_from_group(&"map_marker")


func _ground(space: PhysicsDirectSpaceState3D, from: Vector3) -> Vector3:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 140.0, Layers.WORLD))
	if hit.is_empty() or (hit.normal as Vector3).y < 0.6:
		return Vector3.INF
	return hit.position

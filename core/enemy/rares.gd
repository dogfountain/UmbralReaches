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

const TickPhase := preload("res://core/util/tick_phase.gd")
const EliteKit := preload("res://core/life/encounters/elite_kit.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const Variants := preload("res://core/life/encounters/variants.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
const Staging := preload("res://core/life/encounters/staging.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
## A rare's ground: the camps' rules (no pool, lip, slope or rock), but it may walk a way, and the Holds' edge
## is Old Rook's by design.
const GROUND := {"ways": false, "safe": false}
const TICK := 0.5
const NEAR := 95.0              ## the rare walks its beat while you are within this (and it is not dead)
const FAR := 130.0              ## further than this it goes back into the dark, healed
const RESPAWN := 480.0
const SILVER := Color(0.78, 0.86, 1.0)
const BEAT_R := 6.0
const ROUTE_PACE := 1.35        ## m/s along a long route (WoW's patrolling rares: you meet it on its round)

## id -> {title, kind (EnemySpawner key), spots (candidate haunts, first clear one wins), hp, scale,
## ash, loot [[item id, count], ...], line (the toast when it falls)}
## r34: optional "variant" (a Variants look: stonebound, drowned) and "route" (xz points it walks in a
## loop from its haunt, its home walking with it, instead of the short beat round the haunt).
const RARES := {
	"gutterwick": {"title": "Gutterwick the Lamp-Eater", "kind": "wretch", "hp": 22, "scale": 1.3,
		"spots": [Vector2(-66, 34), Vector2(-62, 28), Vector2(-74, 32), Vector2(-96, 6), Vector2(-70, -40), Vector2(-100, -10),
			Vector2(-67, 30), Vector2(-92, 13), Vector2(-109, 5)],    # r34: the old six are on the chapel yard and the henge's raid floor
		"ash": 30, "loot": [["relic_fragment", 1]],
		"line": "Gutterwick falls. The lamp-oil in its belly burns blue, then out."},
	"mother_sallow": {"title": "Mother Sallow", "kind": "spitter", "hp": 18, "scale": 1.3,
		"spots": [Vector2(84, -22), Vector2(90, 6), Vector2(100, 12), Vector2(80, -12), Vector2(104, 2), Vector2(92, -24)], "ash": 32, "loot": [["relic_fragment", 2]],
		"line": "Mother Sallow sinks into the fen she nursed."},
	"wicker_jack": {"title": "Wicker Jack, the Grinning", "kind": "gaunt", "hp": 20, "scale": 1.25,
		"spots": [Vector2(12, 72), Vector2(-12, 74), Vector2(24, 74)], "ash": 30, "loot": [["relic_fragment", 1]],
		"line": "Wicker Jack comes apart in straw and teeth."},
	"cairnback": {"title": "Cairnback", "kind": "husk", "hp": 34, "scale": 1.35,
		"spots": [Vector2(84, -50), Vector2(70, -30), Vector2(90, -44)], "ash": 40, "loot": [["relic_fragment", 3]],
		"line": "Cairnback settles, a barrow at last."},
	# r34: one (at least) for each new region
	"brother_chisel": {"title": "Brother Chisel, the Four-Thousandth", "kind": "husk", "variant": "stonebound", "hp": 40, "scale": 1.4,
		"spots": [Vector2(-136, -112), Vector2(-130, -120), Vector2(-124, -110)], "ash": 42, "loot": [["relic_fragment", 2]],
		"line": "Brother Chisel sets down his last stone. The step is finished."},
	"clapper": {"title": "Clapper, the Bell-Tongue", "kind": "cinder", "hp": 22, "scale": 1.35,
		"spots": [Vector2(124, -96), Vector2(148, -96), Vector2(118, -90)], "ash": 40, "loot": [["relic_fragment", 2]],
		"line": "Clapper cracks like a bell poured too cold."},
	"hennet": {"title": "Gorse-Wife Hennet", "kind": "gaunt", "hp": 24, "scale": 1.3,
		"spots": [Vector2(140, -4), Vector2(144, 2)], "ash": 36, "loot": [["relic_fragment", 1]],
		"route": [Vector2(144, 2), Vector2(142, 19), Vector2(139, 26), Vector2(142, 12), Vector2(140, -4), Vector2(136, -40), Vector2(144, -38), Vector2(141, -51), Vector2(136, -40)],
		"line": "Hennet falls in the heather. The wind does not stop for her."},
	"old_pippin": {"title": "Old Pippin, the Ash-Grub", "kind": "burrower", "hp": 32, "scale": 1.4,
		"spots": [Vector2(-96, 140), Vector2(-86, 98), Vector2(-120, 124)], "ash": 36, "loot": [["relic_fragment", 1]],
		"line": "Old Pippin curls up in the ash, and is still."},
	"last_pilgrim": {"title": "The Last Pilgrim", "kind": "pilgrim", "hp": 28, "scale": 1.3,
		"spots": [Vector2(-12, 140), Vector2(-36, 124), Vector2(19, 125)], "ash": 38, "loot": [["relic_fragment", 2]],
		"route": [Vector2(-12, 140), Vector2(-36, 124), Vector2(-20, 108), Vector2(19, 125), Vector2(14, 140)],
		"line": "The Last Pilgrim kneels, facing the mountain, and does not get up."},
	"ferryman": {"title": "The Ferryman Without a Boat", "kind": "husk", "variant": "drowned", "hp": 36, "scale": 1.35,
		"spots": [Vector2(140, 128), Vector2(137, 102)], "ash": 40, "loot": [["relic_fragment", 2]],
		"route": [Vector2(140, 128), Vector2(130, 140), Vector2(118, 132), Vector2(137, 116), Vector2(137, 102)],
		"line": "The Ferryman goes under. Nobody pays the fare tonight."},
	"old_rook": {"title": "Old Rook, the Kin-Taker", "kind": "gaunt", "hp": 20, "scale": 1.3,
		# (18 Nov: in the Holds, moved 31 m west off the henge's 1.6x skirt)
		"spots": [Vector2(-171, 11), Vector2(-162, -1)], "ash": 32, "loot": [["relic_fragment", 1]],
		"route": [Vector2(-171, 11), Vector2(-173, 24), Vector2(-162, 30), Vector2(-152, 26), Vector2(-162, -1)],
		"line": "Old Rook will not come to the Holds' door again. The Rooted can sleep."},
	# r36 Act II: the keepers of the Founder's bells (each bell quest's slay step wants its own; they
	# haunt the bell, so the bell is guarded whenever you come to it)
	"kin_caller": {"title": "The Kin-Caller", "kind": "gaunt", "hp": 30, "scale": 1.4,
		"spots": [Vector2(-166, 23), Vector2(-172, 17), Vector2(-167, 28)], "ash": 40, "loot": [["relic_fragment", 2], ["kin_lamp", 1]],
		"line": "The Kin-Caller lets go of the rope."},
	"bell_hewer": {"title": "The Bell-Hewer", "kind": "husk", "variant": "stonebound", "hp": 44, "scale": 1.45,
		"spots": [Vector2(-117, -115), Vector2(-123, -121)], "ash": 44, "loot": [["relic_fragment", 2], ["mason_mark", 1]],
		"line": "The Bell-Hewer stops, mid-stroke, for the first time."},
	"fog_shepherd": {"title": "The Fog-Shepherd", "kind": "gaunt", "hp": 32, "scale": 1.4,
		"spots": [Vector2(143, -25), Vector2(149, -31)], "ash": 40, "loot": [["relic_fragment", 2], ["fog_crook", 1]],
		"line": "The Fog-Shepherd lies down in the heather. Nobody follows it now."},
	"slag_born": {"title": "The Slag-Born", "kind": "cinder", "hp": 30, "scale": 1.5,
		"spots": [Vector2(137, -87), Vector2(143, -93)], "ash": 44, "loot": [["relic_fragment", 2], ["slag_heart", 1]],
		"line": "The Slag-Born cools, and cracks, and is only slag."},
	"ash_sower": {"title": "The Ash-Sower", "kind": "burrower", "hp": 38, "scale": 1.5,
		"spots": [Vector2(-95, 125), Vector2(-101, 131)], "ash": 40, "loot": [["relic_fragment", 2], ["ash_seed", 1]],
		"line": "The Ash-Sower goes back into the ash it came out of."},
	"passing_ringer": {"title": "The Passing-Ringer", "kind": "pilgrim", "hp": 34, "scale": 1.4,
		"spots": [Vector2(-1, 125), Vector2(-7, 131)], "ash": 42, "loot": [["relic_fragment", 2], ["hair_rope", 1]],
		"line": "The Passing-Ringer kneels. One stroke, for itself."},
	"fare_caller": {"title": "The Fare-Caller", "kind": "husk", "variant": "drowned", "hp": 40, "scale": 1.4,
		"spots": [Vector2(135, 111), Vector2(129, 105)], "ash": 42, "loot": [["relic_fragment", 2], ["ferry_coin", 1]],
		"line": "The Fare-Caller goes under without its fare."},
	# the eighth keeper: the Order left him at the Spire's foot to see the shut-out bell stayed quiet (at the stair's foot since the
	# stair down the south spur took his old ground, 21 Nov)
	"lamp_shutter": {"title": "The Shutter", "kind": "bulwark", "hp": 50, "scale": 1.5,
		"spots": [Vector2(237.0, 28.0), Vector2(248.5, 28.0), Vector2(242.5, 31.0)], "ash": 48, "loot": [["relic_fragment", 3]],
		"line": "The Shutter lowers his shutter for the last time. Behind it the lamp is lit."},
	# --- south marches ---
	"bell_wether": {"title": "The Bell-Wether", "kind": "gaunt", "hp": 28, "scale": 1.4,
		"spots": [Vector2(-30, 222), Vector2(-60, 226), Vector2(20, 224)], "ash": 38, "loot": [["relic_fragment", 2]],
		"route": [Vector2(-30, 222), Vector2(-62, 226), Vector2(-98, 226), Vector2(-62, 232), Vector2(-26, 228), Vector2(10, 224)],
		"line": "The Bell-Wether stops. The bell on its neck rings once more, alone, and is quiet."},
	"flint_hound": {"title": "The Flint-Hound", "kind": "crawler", "hp": 24, "scale": 1.6,
		"spots": [Vector2(96, 224), Vector2(110, 222), Vector2(140, 226)], "ash": 34, "loot": [["relic_fragment", 1]],
		"route": [Vector2(96, 224), Vector2(122, 228), Vector2(146, 222), Vector2(130, 214), Vector2(104, 218)],
		"line": "The Flint-Hound lies down on the chalk it was bred to guard. It does not get up."},
	# --- west marches ---
	"drowned_reeve": {"title": "The Drowned Reeve", "kind": "husk", "variant": "drowned", "hp": 38, "scale": 1.4,
		"spots": [Vector2(-224, -28), Vector2(-226, -36), Vector2(-220, -18)], "ash": 40, "loot": [["relic_fragment", 2]],
		"route": [Vector2(-224, -28), Vector2(-228, -14), Vector2(-226, 6), Vector2(-222, -10), Vector2(-224, -28)],
		"line": "The Drowned Reeve sinks to his knees in the shallows. The tolls are paid."},
	"moss_mason": {"title": "The Moss-Mason", "kind": "husk", "variant": "stonebound", "hp": 44, "scale": 1.45,
		"spots": [Vector2(-232, -96), Vector2(-240, -100), Vector2(-226, -90)], "ash": 44, "loot": [["relic_fragment", 2]],
		"line": "The Moss-Mason sets down his chisel. The Hierarch's thumb will stay unfinished."},
	"gate_breaker": {"title": "The Gate-Breaker", "kind": "bulwark", "hp": 36, "scale": 1.4,
		"spots": [Vector2(-241, 142), Vector2(-241, 157), Vector2(-238, 128)], "ash": 42, "loot": [["relic_fragment", 2]],
		"line": "The Gate-Breaker drops its ram. The gate it wanted is a long way east."},
	# --- the east marches ---
	"salt_widow": {"title": "The Salt-Widow", "kind": "gaunt", "hp": 30, "scale": 1.4,
		"spots": [Vector2(238, 132), Vector2(248, 138), Vector2(224, 134), Vector2(216, 142), Vector2(218, 136)], "ash": 40, "loot": [["relic_fragment", 2]],
		"route": [Vector2(238, 132), Vector2(250, 142), Vector2(236, 138), Vector2(222, 134), Vector2(212, 130)],
		"line": "The Salt-Widow sits down on the white, and the white takes her."},
	"drowned_lamplighter": {"title": "The Drowned Lamplighter", "kind": "husk", "variant": "drowned", "hp": 36, "scale": 1.35,
		"spots": [Vector2(180, 18), Vector2(178, -2), Vector2(184, 30)], "ash": 38, "loot": [["relic_fragment", 2]],
		"route": [Vector2(180, 18), Vector2(176, -2), Vector2(178, -24), Vector2(184, 6), Vector2(186, 28)],
		"line": "The Drowned Lamplighter lets the lamp go. It does not float."},
	# --- the Far Reaches (enemies pass): one for each wild region, on its landmark; most walk a round (you meet
	# them on it), a step tougher than the Marches' as the outer ring is
	"keep_sentry": {"title": "The Sentry Who Was Never Relieved", "kind": "bulwark", "variant": "stonebound", "hp": 56, "scale": 1.5,
		"spots": [Vector2(-284, -116), Vector2(-278, -112), Vector2(-290, -118), Vector2(-286, -110)], "ash": 50, "loot": [["relic_fragment", 3]],
		"line": "The Sentry sets down his pike at the fell shrine. Nobody came to relieve him, so he relieves himself."},
	"lamp_wick": {"title": "Wick, the Lamp-Grown", "kind": "spitter", "hp": 30, "scale": 1.4,
		"spots": [Vector2(-288, -16), Vector2(-316, -28), Vector2(-290, -34)], "ash": 44, "loot": [["relic_fragment", 2]],
		"route": [Vector2(-288, -16), Vector2(-294, -38), Vector2(-314, -36), Vector2(-320, -12), Vector2(-304, -2)],
		"line": "Wick goes out. The caps round it glow a little brighter, for a while."},
	"crownless": {"title": "The Crownless King", "kind": "ossuant", "hp": 44, "scale": 1.5,
		"spots": [Vector2(-312, 84), Vector2(-316, 92), Vector2(-308, 78)], "ash": 46, "loot": [["relic_fragment", 3]],
		"route": [Vector2(-312, 84), Vector2(-324, 118), Vector2(-310, 156), Vector2(-322, 182), Vector2(-308, 126)],
		"line": "The Crownless King lies down at last. His barrow is still open, and still empty."},
	"heron_wife": {"title": "The Heron-Wife", "kind": "spitter", "hp": 32, "scale": 1.45,
		"spots": [Vector2(-326, 372), Vector2(-318, 360), Vector2(-336, 380)], "ash": 44, "loot": [["relic_fragment", 2]],
		"route": [Vector2(-326, 372), Vector2(-344, 384), Vector2(-344, 380), Vector2(-356, 344), Vector2(-312, 352)],
		"line": "The Heron-Wife folds down into the reeds. The meres go quiet."},
	"tithe_taker": {"title": "The Tithe-Taker", "kind": "husk", "hp": 38, "scale": 1.4,
		"spots": [Vector2(-176, 380), Vector2(-150, 376), Vector2(-196, 350)], "ash": 40, "loot": [["relic_fragment", 2]],
		"route": [Vector2(-176, 380), Vector2(-150, 376), Vector2(-132, 386), Vector2(-160, 362), Vector2(-196, 350)],
		"line": "The Tithe-Taker drops his sack. There is nothing in it but soil."},
	"aqueduct_hound": {"title": "Spill, the Aqueduct's Hound", "kind": "crawler", "hp": 30, "scale": 1.6,
		"spots": [Vector2(-12, 360), Vector2(8, 362), Vector2(-24, 366)], "ash": 44, "loot": [["relic_fragment", 2]],
		"route": [Vector2(-12, 360), Vector2(12, 362), Vector2(44, 356), Vector2(64, 346), Vector2(24, 350)],
		"line": "Spill lies down in the dry channel it guarded. Nothing runs in it now."},
	"charcoal_burner": {"title": "The Last Charcoal-Burner", "kind": "cinder", "hp": 36, "scale": 1.5,
		"spots": [Vector2(246, 384), Vector2(238, 384), Vector2(254, 378), Vector2(232, 372), Vector2(226, 388), Vector2(258, 366)], "ash": 46, "loot": [["relic_fragment", 3]],
		"line": "The Last Charcoal-Burner banks his fire for good. The stack smokes on without him."},
	"cracked_tollman": {"title": "The Cracked Tollman", "kind": "tollman", "hp": 40, "scale": 1.5,
		"spots": [Vector2(362, 118), Vector2(338, 119), Vector2(344, 116)], "ash": 50,      # round the crater's south rim (its bowl is the bell's) "loot": [["relic_fragment", 3]],
		"route": [Vector2(362, 118), Vector2(352, 120), Vector2(344, 116), Vector2(338, 119), Vector2(344, 116), Vector2(352, 120)],
		"line": "The Cracked Tollman rings once more, flat. The eighth bell does not answer."},
	"rope_nun": {"title": "The Bell-Rope Nun", "kind": "chanter", "hp": 34, "scale": 1.45,
		"spots": [Vector2(350, 146), Vector2(354, 160), Vector2(346, 136)], "ash": 44, "loot": [["relic_fragment", 2]],
		"route": [Vector2(350, 146), Vector2(354, 176), Vector2(342, 204), Vector2(354, 160), Vector2(344, 128)],
		"line": "The Bell-Rope Nun lets go of the rope. Under the water, something in the nave rings."},
	"cairn_counter": {"title": "The One Who Counted", "kind": "pilgrim", "hp": 38, "scale": 1.45,
		"spots": [Vector2(318, 252), Vector2(310, 258), Vector2(324, 248)], "ash": 50, "loot": [["relic_fragment", 3]],
		"route": [Vector2(318, 252), Vector2(330, 290), Vector2(358, 306), Vector2(334, 362), Vector2(296, 346), Vector2(300, 306)],
		"line": "The One Who Counted adds a stone, and stops. The count is a thousand."},
	# --- the ossuary --- the last of the bearers, still walking the Lych Way's head with its burden
	"last_bearer": {"title": "The Last Bearer", "kind": "ossuant", "hp": 36, "scale": 1.5,
		"spots": [Vector2(-61.0, 77.0), Vector2(-65.5, 76.5), Vector2(-66.5, 70.5)], "ash": 40, "loot": [["relic_fragment", 2]],
		"route": [Vector2(-61.0, 77.0), Vector2(-63.0, 83.5), Vector2(-65.8, 76.0), Vector2(-66.2, 70.5)],      # north of the orchard watch (14 m+)
		"line": "The Last Bearer sets its burden down at last. Nobody counts it."},
}

var haunts: Dictionary = {}      ## id -> Vector3 on the ground
var nodes: Dictionary = {}       ## id -> Enemy
var _markers: Dictionary = {}    ## id -> Node3D
var _dead_until: Dictionary = {} ## id -> msec when it may walk again
var _acc := 0.0
var _scripts: Dictionary = {}


func _ready() -> void:
	_acc = TickPhase.first(self, TICK)
	name = "Rares"
	Events.enemy_killed.connect(_on_killed)


## `scripts`: EnemySpawner's kind -> GDScript map.
func setup(scripts: Dictionary) -> void:
	_scripts = scripts
	var space := get_world_3d().direct_space_state
	for id: String in RARES:
		var fallback := Vector3.INF
		for c: Vector2 in RARES[id].spots:
			var g := _ground(space, _over(c))
			if g == Vector3.INF or LightGrid.is_lit(g):
				continue
			if not WorldLanes.site_at(c, 1.0).is_empty() or not SpawnRules.ok(space, g, GROUND):
				continue
			# r34: a haunt it can walk a beat round (open, level enough); else the first clear one
			if not RARES[id].has("route") and _beat(g).size() < 3:
				if fallback == Vector3.INF:
					fallback = g
				continue
			haunts[id] = g
			break
		if not haunts.has(id) and fallback != Vector3.INF:
			haunts[id] = fallback
		if not haunts.has(id):
			push_warning("Rares: no clear haunt for %s" % id)
			PlacementLog.skip("rares", id, Vector3.ZERO, "no clear haunt")
			continue
		_markers[id] = _make_marker(id, haunts[id])


## Twice a second: walk the beat near you, rest in the dark far off, come back after RESPAWN.
func _process(delta: float) -> void:
	_acc += delta
	if _acc < TICK:
		return
	_acc = TickPhase.carry(_acc, TICK)
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	var now := Time.get_ticks_msec()
	var built := false
	for id: String in haunts:
		var at: Vector3 = haunts[id]
		var e := nodes.get(id) as Enemy if is_instance_valid(nodes.get(id)) else null
		var d := p.global_position.distance_to(at)
		if e == null:
			nodes.erase(id)
			var due := now >= int(_dead_until.get(id, 0))
			var lit := LightGrid.is_lit(at)
			_show_marker(id, due and not lit)      # a lit haunt has no body, so no pin either
			# one a tick (a teleport built every rare in reach in one frame); the builder builds them ahead, unseen (staging.gd)
			if due and not lit and not built and d < NEAR:
				spawn_rare(id)
				built = true
			continue
		if Staging.waits(e, d < NEAR):
			continue
		var de := p.global_position.distance_to(e.global_position)
		if d > FAR and de > FAR:
			if not Staging.stand_down([e]):       # untouched: waiting again where it stands
				e.queue_free()                     # back into the dark, whole
				nodes.erase(id)
		elif de > e.sleep_range:
			e.sleep()
		else:
			e.wake()


## Its respawn time has come (it is not lying dead).
func due(id: String) -> bool:
	return Time.get_ticks_msec() >= int(_dead_until.get(id, 0))


func spawn_rare(id: String) -> Enemy:
	if not RARES.has(id) or not haunts.has(id):
		return null
	if is_instance_valid(nodes.get(id)):
		Staging.rise(nodes[id] as Enemy)          # (a direct call wants it up: the builder's waits unseen)
		return nodes[id] as Enemy
	var d: Dictionary = RARES[id]
	var script: GDScript = _scripts.get(String(d.kind))
	if script == null:
		script = load("res://core/enemy/%s.gd" % String(d.kind)) as GDScript
	if script == null:
		return null
	var at: Vector3 = haunts[id]
	var e := script.new() as Enemy
	if "dormant" in e:
		e.set("dormant", false)                   # r34: a named Pilgrim walks its round awake
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
	var look := String(d.get("variant", ""))
	if look != "":
		Variants.pre(e, look)
	get_parent().add_child(e)
	if look != "":
		Variants.dress(e, look)
	e.global_position = at + Vector3.UP * 0.05
	e.home = at
	if d.has("route"):
		e.patrol = route(id)
		e.roam = true
		e.patrol_speed = ROUTE_PACE
	else:
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


## r34: a long route's points on the ground, from the haunt (points with no ground, or lit, are skipped).
var _routes: Dictionary = {}


func route(id: String) -> Array[Vector3]:
	if _routes.has(id):
		return (_routes[id] as Array[Vector3]).duplicate()
	var out: Array[Vector3] = [haunts[id]]
	var space := get_world_3d().direct_space_state
	for c: Vector2 in RARES[id].get("route", []):
		var g := _ground(space, _over(c))
		if g != Vector3.INF and not SpawnRules.ok(space, g, GROUND):
			g = SpawnRules.find(space, c, 5.0, g.y + 8.0, GROUND, g.y, 3.0)    # a stop in a pool or on a lip: beside it
		if g == Vector3.INF or LightGrid.is_lit(g) or g.distance_to(out[out.size() - 1]) < 1.0:
			continue
		out.append(g)
	_routes[id] = out
	return out.duplicate()


## Three points round the haunt on the ground (the beat it walks).
func _beat(at: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = [at]
	var space := get_world_3d().direct_space_state
	var a0 := float(hash(at.snapped(Vector3.ONE)) % 628) * 0.01
	for k in 3:
		var a := a0 + TAU * float(k) / 3.0
		var g := _ground(space, at + Vector3(cos(a) * BEAT_R, 6.0, sin(a) * BEAT_R))
		if g != Vector3.INF and absf(g.y - at.y) < 2.5 and not LightGrid.is_lit(g) and SpawnRules.ok(space, g, GROUND):
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
	l.set_meta(Staging.HIDDEN, true)               # (a rare built ahead, asleep, shows neither until it rises)
	e.add_child(l)
	var fx := Vfx.emitter(Color(SILVER.r * 1.6, SILVER.g * 1.6, SILVER.b * 1.8), {"count": 14, "life": 1.4, "speed": Vector2(0.1, 0.5), "size": 0.035, "gravity": -0.5, "radius": 0.5, "turbulence": true})
	fx.position = Vector3.UP * e.hp_bar_y * 0.5
	fx.set_meta(Staging.HIDDEN, true)
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


## Just over the ground at xz (a roof, a deck or a tree's crown above the haunt is not where a rare walks).
func _over(c: Vector2) -> Vector3:
	return Vector3(c.x, RealmLand.height_at(c.x, c.y) + 3.0, c.y)


func _ground(space: PhysicsDirectSpaceState3D, from: Vector3) -> Vector3:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 140.0, Layers.WORLD))
	if hit.is_empty() or (hit.normal as Vector3).y < 0.6:
		return Vector3.INF
	return hit.position

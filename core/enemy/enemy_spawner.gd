class_name EnemySpawner
extends Node3D
## Plants enemies on a zone. Packs are several pawns around one camp.

const RESPAWN := 10.0            ## a seal camp's refill (the seal's progress is its kills)
const RESPAWN_ROAM := 90.0       ## a cleared road camp stays down long enough to leave and come back on foot
const RETRY := 1.5
const KEEP_CLEAR := 7.0
const HAVEN := Vector3(-3.4, 0.0, -8.5)
const HAVEN_R := 12.0

const ReachCamps := preload("res://core/enemy/realm_camps_reaches.gd")

## Camps of the redesigned zone (docs/REALM_PLAN.md, RealmLayout). r28: five camps that the sites
## had swallowed (skipped at plant: "inside site barrow_92_-65", "fen_graves_55_22", "barrow_89_-50",
## "rd_wall_-62_70", "rd_wall_54_74") moved 5-11 m onto clear ground off the paths.
## Ground camps are given at y 60 with "probe" 0: the ground under them is found once the Realm is built (see `_plant`). Every one stands
## off the paths (RealmLayout.path_dist > 4), outside the sites, and 13 m+ from every checkpoint
## brazier (RealmBosses.BRAZIERS). The crypt's own seal camps ("oss_gallery") stay in the Ossuary.
const REALM_CAMPS: Array[Dictionary] = [
	# guardians of the thorn seal: the Thornwood edge along west_way, below the henge hill
	{"at": Vector3(-50.0, 60.0, 8.0), "kinds": ["wretch", "crawler"], "probe": 0.0, "seal": "henge"},        # past the glade
	{"at": Vector3(-41.0, 60.0, -18.0), "kinds": ["spitter", "wretch"], "probe": 0.0, "seal": "henge"},      # the stair's foot, east of the flight (moved 4 m off west_way: it stood 3.7 m from the walk)
	{"at": Vector3(-54.0, 60.0, -18.8), "kinds": ["leaper", "crawler"], "probe": 0.0, "seal": "henge"},      # the stair's head on the raid floor's rim (r32: was at -74,12, 22 m off any path, behind the hill; r34 enemies: -18 -> -18.8, 13 m+ from HengeFire on its landing)
	# guardians of the summit ward (it also needs the Thornwarden and the Bone Abbot): they hold the
	# Crossing itself, its west tower (Crossing.T2, parapeted) and its head in front of the ward
	# (r32: the first pack stood 12-16 m east of the Crossing's foot, off the way, beside a roaming pack)
	{"at": Vector3(-13.0, 12.0, -30.0), "kinds": ["husk", "wretch"], "probe": 18.0, "r": 1.4, "strict": true, "seal": "summit"},
	{"at": Vector3(0.0, 28.0, -68.0), "kinds": ["spitter", "wretch"], "probe": 18.0, "r": 1.4, "strict": true, "seal": "summit"},
	# roaming packs (they come back)
	# r28 war bands: a guard (Bulwark) before a caster (Chanter), flankers on the sides
	# r31: a Tollman rides with it (kill it before it rings, or the Thornwood comes) and a Gaunt darts
	{"at": Vector3(-126.0, 60.0, -32.0), "kinds": ["bulwark", "chanter", "gaunt", "wretch", "tollman"], "probe": 0.0, "r": 3.0},   # Thornwood deep (r34 layout: was -92,-30, inside the henge's raid floor; now off west_track, west of the hill)
	{"at": Vector3(-84.0, 60.0, 22.0), "kinds": ["leaper", "husk"], "probe": 0.0},                 # Thornwood west (r30: was 18 m from Wyck the hermit)
	{"at": Vector3(-82.0, 60.0, -56.0), "kinds": ["mite", "mite", "mite", "mite", "mite"], "probe": 0.0, "r": 1.6},   # Thornwood under the Crowns: a swarm nest
	{"at": Vector3(-66.0, 60.0, 24.0), "kinds": ["wretch", "spitter"], "probe": 0.0},              # Thornwood's village edge, back in the trees (47 m from the green and 5 m off west_way, it held the walk out of the village)
	{"at": Vector3(94.0, 60.0, -10.0), "kinds": ["ossuant", "wretch"], "probe": 0.0},              # Hollow Fen east
	{"at": Vector3(86.0, 60.0, -75.0), "kinds": ["burrower", "spitter", "burrower"], "probe": 0.0},    # Hollow Fen north: the soft ground (r30: 10 m+ inside the bounds, off the barrows)
	{"at": Vector3(63.0, 60.0, 18.0), "kinds": ["wretch", "leaper"], "probe": 0.0},                # Hollow Fen south
	{"at": Vector3(70.0, 60.0, 2.0), "kinds": ["husk"], "probe": 0.0},                             # a drowned husk off east_way
	# r29: east_way had no camp within 18 m of it in 83 m (zz critA density: 3.6 foes / 100 m against
	# 19 on west_way); a small pack on its first stretch, 9 m off the path
	{"at": Vector3(43.0, 60.0, -6.0), "kinds": ["wretch", "crawler", "spitter", "tollman"], "probe": 0.0},     # east_way, past the rift's shoulder
	{"at": Vector3(99.0, 60.0, -34.0), "kinds": ["ossuant", "ossuant", "quiller"], "probe": 0.0},              # Barrow Field (r29: was at -50, inside secrets_barrow: skipped; r30: 10 m+ inside the bounds)
	{"at": Vector3(60.0, 60.0, -68.0), "kinds": ["bulwark", "quiller", "wretch"], "probe": 0.0},   # above fen_descent
	{"at": Vector3(-60.0, 60.0, 78.0), "kinds": ["husk", "gaunt"], "probe": 0.0},                 # Pilgrims' Road west, 10 m+ off the road
	{"at": Vector3(-84.0, 60.0, 88.0), "kinds": ["burrower", "wretch"], "probe": 0.0},             # south of the road beyond the chapel, at the orchard's edge (it lay 47 m from the green, on the road out of the village)
	{"at": Vector3(80.0, 60.0, 49.0), "kinds": ["chanter", "husk", "crawler"], "probe": 0.0},      # Pilgrims' Road east, back from the road (it stood 4.7 m off it)
	{"at": Vector3(-35.0, 60.0, -10.0), "kinds": ["quiller", "leaper"], "probe": 0.0},             # rift rim west (r31 merge: off the secret bridge's landing at -23.5,-5.3, where a pounce threw you into the rift; r34 enemies: was -38,6, 7 m from the Shrine fire: in its light)
	{"at": Vector3(22.0, 60.0, -6.0), "kinds": ["wretch", "crawler"], "probe": 0.0},               # rift rim east
	# --- r34 enemies: the new ground at the old density (docs/r34/layout.md: ~4 camps per 10,000 m²,
	# ~1 foe per 1,000 m²), each region its own roster and a reason. Every camp: 10 m+ inside BOUNDS,
	# 13 m+ from every fire (the braziers and the new regions' fire slots), 4 m+ off the ways, off the
	# sites and the raid floors (checked by zz/enemies_r34_test on the built Realm). Husks, Bulwarks and
	# Leapers in the quarry and Husks, Wretches and Ossuants in the mere wear the region's own look
	# (Tiers.REGION_VARIANT: stone-bound, drowned); "kind@variant" names one outright.
	# The Saints' Quarry (tier 2): the Order's cutters, still at it. Leapers on the benches, stone-bound
	# husks hauling, a chanter keeping their pace.
	{"at": Vector3(-111.0, 60.0, -99.0), "kinds": ["husk", "leaper", "leaper"], "probe": 0.0},     # the east benches
	{"at": Vector3(-139.0, 60.0, -89.0), "kinds": ["leaper", "husk", "wretch"], "probe": 0.0},     # the west benches
	{"at": Vector3(-119.0, 60.0, -116.0), "kinds": ["husk", "husk", "chanter"], "probe": 0.0},     # the south benches, by the unfinished steps
	# The Founder's Pits (tier 2): the bell-founders' hollowed. Bulwarks hold the furnace mouth with
	# Cinder Casters behind them (go round the shields or kill the caster first).
	{"at": Vector3(137.0, 60.0, -98.0), "kinds": ["bulwark", "cinder", "bulwark", "cinder"], "probe": 0.0, "r": 2.8},   # before the bell furnace
	{"at": Vector3(115.0, 60.0, -102.0), "kinds": ["cinder", "wretch", "gaunt"], "probe": 0.0},    # the west bench
	# The Lanternless Moor (tier 1): no camps to sit in -- packs that walk the heather (long sight
	# lines: you see them coming, they see you). Gaunts, who hunt in the open.
	{"at": Vector3(141.0, 60.0, -51.0), "kinds": ["gaunt", "gaunt", "wretch"], "probe": 0.0,
		"patrol": [Vector2(141, -51), Vector2(144, -38), Vector2(136, -40)]},                       # the north moor
	{"at": Vector3(142.0, 60.0, 32.0), "kinds": ["gaunt", "crawler", "crawler"], "probe": 0.0,
		"patrol": [Vector2(142, 32), Vector2(142, 19), Vector2(139, 26)]},                         # the south moor
	{"at": Vector3(144.0, 60.0, 2.0), "kinds": ["husk", "wretch"], "probe": 0.0,
		"patrol": [Vector2(144, 2), Vector2(140, -4)]},                                            # under the tor
	# The Cinder Orchard (tier 1): what roots in the ash -- burrowers under the burned rows, mite nests.
	{"at": Vector3(-136.0, 60.0, 104.0), "kinds": ["burrower", "burrower", "crawler"], "probe": 0.0},   # the west rows
	{"at": Vector3(-80.0, 60.0, 142.0), "kinds": ["mite", "mite", "mite", "mite", "mite"], "probe": 0.0, "r": 1.6},   # the south rows: a nest in the ash
	{"at": Vector3(-120.0, 60.0, 112.0), "kinds": ["burrower", "mite", "mite", "mite"], "probe": 0.0, "r": 1.8},     # the press-house rows
	# The Waiting Field (tier 1): the pilgrims, buried facing the mountain, waiting. Risen Pilgrims lie
	# under their graves until you walk among them; ossuants and chanters keep the vigil.
	{"at": Vector3(-30.0, 60.0, 146.0), "kinds": ["pilgrim", "pilgrim", "chanter"], "probe": 0.0},  # the west tombs
	{"at": Vector3(28.0, 60.0, 114.0), "kinds": ["ossuant", "pilgrim", "ossuant"], "probe": 0.0},   # the east tombs
	{"at": Vector3(-12.0, 60.0, 140.0), "kinds": ["pilgrim", "pilgrim", "pilgrim", "pilgrim"], "probe": 0.0, "r": 3.0},   # a row of graves below the mausoleum
	{"at": Vector3(-40.0, 60.0, 110.0), "kinds": ["chanter", "ossuant", "quiller"], "probe": 0.0},  # the field's west edge (was -36,124: 12 m from Sister Agathe's fire)
	# Corvin's Mere (tier 1): the drowned and what nests over the water. Spitters on the banks, drowned
	# husks out of the meres; the causeway itself is an ambush (director.FIXED_AMBUSHES).
	{"at": Vector3(137.0, 60.0, 102.0), "kinds": ["spitter", "husk", "wretch"], "probe": 0.0},     # the east bank
	{"at": Vector3(118.0, 60.0, 144.0), "kinds": ["husk", "spitter", "husk"], "probe": 0.0},       # the south bank
	{"at": Vector3(118.0, 60.0, 108.0), "kinds": ["spitter", "spitter", "ossuant"], "probe": 0.0}, # the hummocks east of the causeway
	# The Rooted Holds: no camp. The clearing is safe-ish (the director spawns nothing in it); only Old
	# Rook (rares.gd) walks round its edge at night.
	# The road's new ends and the west wood along west_track
	{"at": Vector3(-128.0, 60.0, 74.0), "kinds": ["husk", "gaunt", "wretch"], "probe": 0.0},       # the West Gate's approach
	{"at": Vector3(132.0, 60.0, 58.0), "kinds": ["chanter", "husk", "crawler"], "probe": 0.0},     # the East Gate's approach
	{"at": Vector3(-144.0, 60.0, -50.0), "kinds": ["leaper", "wretch", "crawler"], "probe": 0.0},  # west_track under the quarry
	{"at": Vector3(-135.0, 60.0, 40.0), "kinds": ["wretch", "crawler"], "probe": 0.0},             # west_track north of the Holds
	# --- south marches ---
	# The Southern Downs (tier 1): open chalk, long sight lines; gaunts who hunt the flock's old ground and a
	# leaper in the heather. 13 m+ from every fire, off the tracks (the layout's two "downs" camp slots).
	{"at": Vector3(-120.0, 60.0, 214.0), "kinds": ["gaunt", "gaunt", "wretch"], "probe": 0.0,
		"patrol": [Vector2(-120, 214), Vector2(-112, 204), Vector2(-126, 205)]},                  # the west downs
	{"at": Vector3(126.0, 60.0, 214.0), "kinds": ["gaunt", "leaper", "crawler"], "probe": 0.0,
		"patrol": [Vector2(126, 214), Vector2(134, 206), Vector2(118, 207)]},                     # the east downs
	{"at": Vector3(18.0, 60.0, 226.0), "kinds": ["gaunt", "wretch", "crawler"], "probe": 0.0,
		"patrol": [Vector2(18, 226), Vector2(28, 220), Vector2(8, 222)]},                          # the middle downs, south of downs_track
	{"at": Vector3(-92.0, 60.0, 222.0), "kinds": ["burrower", "mite", "crawler"], "probe": 0.0, "r": 1.8},  # west of the Grandmother Oak, clear of downs_track
	{"at": Vector3(96.0, 60.0, 222.0), "kinds": ["spitter", "husk", "ossuant"], "probe": 0.0},   # the Well's south-east rim, clear of the fire
	# --- west marches (docs/r37_expansion.md): the Sorrow's Banks (tier 2: the drowned and what hunts the fords),
	# the empty plinth's valley (tier 2: the stone-bound), the Siege Lines round the fallen Hierarch (tier 3: the Marches'
	# war-bands that never went home, stone-bound round the skull). Weirford itself has no camp: its watch holds it.
	{"at": Vector3(-240.0, 60.0, -10.0), "kinds": ["husk@drowned", "spitter", "wretch@drowned"], "probe": 0.0},          # the Sorrow's west bank
	{"at": Vector3(-178.0, 60.0, -50.0), "kinds": ["crawler", "gaunt", "crawler"], "probe": 0.0},                      # the east bank, off weir_track
	{"at": Vector3(-187.0, 60.0, -102.0), "kinds": ["husk@stonebound", "bulwark@stonebound", "chanter"], "probe": 0.0, "r": 2.6},   # the valley floor, east of the plinth
	{"at": Vector3(-240.0, 60.0, 168.0), "kinds": ["husk@stonebound", "bulwark@stonebound", "chanter"], "probe": 0.0},   # the west strip between the river and the skull
	{"at": Vector3(-240.0, 60.0, 218.0), "kinds": ["leaper", "husk", "wretch"], "probe": 0.0},                         # the south rings
	{"at": Vector3(-216.0, 60.0, 226.0), "kinds": ["gaunt", "gaunt", "wretch"], "probe": 0.0},                         # south of the giant's hand
	{"at": Vector3(-196.0, 60.0, 228.0), "kinds": ["cinder", "bulwark", "cinder"], "probe": 0.0, "r": 2.8},            # beyond the broken waist
	# --- the east marches: Stillwater (tier 2: the lake's drowned and what nests on its shore), the Anchorholds
	# (tier 3: the hermits' own, walled in and let out), Saltmarket's approach (tier 1), the White Pans (tier 2)
	{"at": Vector3(172.0, 60.0, -36.0), "kinds": ["husk", "spitter", "husk"], "probe": 0.0},      # the north shore
	{"at": Vector3(246.0, 60.0, -28.0), "kinds": ["gaunt", "wretch", "gaunt"], "probe": 0.0},     # the lake's east bank, under the bluff
	{"at": Vector3(188.0, 60.0, 44.0), "kinds": ["spitter", "husk"], "probe": 0.0},               # the south shore, off the fire
	{"at": Vector3(228.0, 60.0, -18.0), "kinds": ["gaunt", "spitter", "wretch"], "probe": 0.0},   # Stillwater's east bank under the Spire, clear of spire_track
	{"at": Vector3(180.0, 60.0, -82.0), "kinds": ["bulwark", "chanter", "leaper"], "probe": 0.0},  # the scree
	{"at": Vector3(232.0, 60.0, -94.0), "kinds": ["bulwark", "quiller", "wretch"], "probe": 0.0},  # the east cells
	{"at": Vector3(184.0, 60.0, -60.0), "kinds": ["leaper", "gaunt", "gaunt"], "probe": 0.0},      # anchor_track's lower bend
	{"at": Vector3(170.0, 60.0, 122.0), "kinds": ["wretch", "crawler"], "probe": 0.0},            # Saltmarket's west approach (the salt shed stands at (195, 119.5); was 182,110: 10 m past the hamlet's edge)
	{"at": Vector3(178.0, 60.0, 196.0), "kinds": ["burrower", "burrower", "crawler", "mite"], "probe": 0.0, "r": 1.8},   # the west pans
	{"at": Vector3(240.0, 60.0, 140.0), "kinds": ["cinder", "wretch", "gaunt"], "probe": 0.0},    # the east pans
	{"at": Vector3(210.0, 60.0, 214.0), "kinds": ["husk", "husk", "chanter"], "probe": 0.0},      # the south pans
	# --- the ossuary --- its own ground (ossuary_ground.gd; tier 2): the Abbot's servants above the pit. The bearers
	# walk the Lych Way's hollow with their bell-ringer (kill the Tollman before he tolls the choir down on you); the
	# choir keeps the lantern; the sorters work the west rim over the gate hall. 13 m+ from the gate hall's fire, 14 m+ from
	# the Kindled Watch's post at the hollow way's north mouth (its watchmen leave the post for foes that close).
	{"at": Vector3(-56.5, 60.0, 120.0), "kinds": ["ossuant", "ossuant", "tollman"], "probe": 0.0,
		"patrol": [Vector2(-56.5, 120.0), Vector2(-55.0, 128.0), Vector2(-49.0, 126.0), Vector2(-50.6, 117.0), Vector2(-51.4, 110.5), Vector2(-50.6, 117.0), Vector2(-49.0, 126.0), Vector2(-55.0, 128.0)]},   # the bearers (they keep 14 m+ off the orchard watch's post)
	{"at": Vector3(-60.0, 60.0, 139.0), "kinds": ["chanter", "ossuant", "chanter", "pilgrim"], "probe": 0.0, "r": 2.6},   # the choir under the lantern
	{"at": Vector3(-71.0, 60.0, 171.0), "kinds": ["husk", "bulwark", "quiller"], "probe": 0.0},                         # the sorters on the west rim
] + ReachCamps.CAMPS          # the Far Reaches (core/enemy/realm_camps_reaches.gd)


## Realm entry (world/main.gd calls this when --realm is on). The camps are counted for their seals
## now (a WardSeal built in the same frame already knows its guards); they are planted once the
## Realm has finished building its ground (`_plant` waits for it).
static func seed_realm(root: Node) -> void:
	_seed(root, REALM_CAMPS.duplicate(true))
	var n := root.get_node_or_null("EnemySpawner")
	if n:
		n.set("_realm", true)


## Seal bookkeeping (static, filled synchronously when camps are seeded so a WardSeal built in the
## same frame already knows its guard count): seal id -> {camp key -> pawn count}.
static var _seal_camps: Dictionary = {}
static var _seal_kills: Dictionary = {}     # seal id -> {slot key -> true}

## Encounters hooks (core/life/encounters, docs/LIFE_PLAN.md). Unset = the old behaviour exactly.
## `kind_hook(slot) -> GDScript|null` may swap the kind a slot spawns (tiers, mixed packs);
## `dress_hook(pawn, slot)` runs on the new pawn before it enters the tree (stats, variant looks).
static var kind_hook: Callable
static var dress_hook: Callable
## Rest rhythm: when on, roaming (non-seal) camps stay dead until `refill()` (a rest at a fire),
## with REST_HOLD as a long fallback. Seal guards never come back either way.
static var hold_for_rest := false
const REST_HOLD := 420.0
signal planted                            ## the camps are in the world (encounters waits on it)
var planted_done := false


static func seal_total(id: String) -> int:
	if id == "" or not _seal_camps.has(id):
		return 0
	var n := 0
	for k in _seal_camps[id]:
		n += int(_seal_camps[id][k])
	return n


static func _seed(root: Node, camps: Array) -> void:
	if root == null or root.get_node_or_null("EnemySpawner") != null:
		return
	for c: Dictionary in camps:
		var sid := String(c.get("seal", ""))
		if sid == "":
			continue
		if not _seal_camps.has(sid):
			_seal_camps[sid] = {}
		_seal_camps[sid][str(c.at)] = (c.kinds as Array).size()
	var n := new()
	n.name = "EnemySpawner"
	n._camps = camps
	root.add_child(n)


## r28 kin (no class_name: loaded by path).
const KIN := {
	"bulwark": "res://core/enemy/bulwark.gd", "chanter": "res://core/enemy/chanter.gd",
	"burrower": "res://core/enemy/burrower.gd", "mite": "res://core/enemy/mite.gd",
	"gaunt": "res://core/enemy/gaunt.gd", "quiller": "res://core/enemy/quiller.gd", "tollman": "res://core/enemy/tollman.gd",
	# r34
	"pilgrim": "res://core/enemy/pilgrim.gd", "cinder": "res://core/enemy/cinder_caster.gd",
}
const Tiers := preload("res://core/life/encounters/tiers.gd")
const Variants := preload("res://core/life/encounters/variants.gd")
const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
const PATROL_PACE := 1.5           ## m/s a roaming camp walks its round at (every member alike: in step)
const HIDE_R := 170.0              ## a sleeping pawn further than this is hidden (the bodies' draw range ends ~130 m)
var _camps: Array = []
var _realm := false
var _slots: Array[Dictionary] = []
var _tick := 0.0
var _scripts: Dictionary = {}
static var _cap: CapsuleShape3D


func _ready() -> void:
	add_to_group(&"enemy_spawner")             # the minimap (ui/minimap.gd) lists seal guards from here
	_scripts["wretch"] = Wretch
	_scripts["husk"] = Husk
	_scripts["crawler"] = Crawler
	_scripts["leaper"] = Leaper
	_scripts["spitter"] = Spitter
	_scripts["ossuant"] = Ossuant
	for k: String in KIN:
		_scripts[k] = load(KIN[k])
	if Events.enemy_killed.is_connected(_on_killed) == false:
		Events.enemy_killed.connect(_on_killed)
	_plant()


func _plant() -> void:
	await get_tree().physics_frame
	if _realm:
		# the Realm builds its ground over many frames after this node exists: wait until its last
		# pass that shapes the ground (SummitDress runs after land, sites, the stamp and flora)
		var t0 := Time.get_ticks_msec()
		var host := get_parent()
		while is_inside_tree() and not host.has_meta("summit_dressed") and Time.get_ticks_msec() - t0 < 120000:
			await get_tree().process_frame
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for camp in _camps:
		var center := _ground(space, camp.at, float(camp.get("probe", 24.0)), bool(camp.get("strict", false)))
		var why := ""
		if Vector2(center.x - HAVEN.x, center.z - HAVEN.z).length() < HAVEN_R or Vector2(center.x, center.z + 10.0).length() < 12.0:
			why = "haven"
		elif _realm and is_nan(_last_hit_y):
			why = "no ground"                       # e.g. the Crossing's head is not built
		elif _realm and not camp.get("strict", false) and not _camp_ground_ok(space, center, String(camp.get("seal", ""))):
			# a place built over it since it was set down (a site), or ground the spawn rules refuse (water, a lip, a
			# rock): the nearest fair ground within CAMP_MOVE keeps the camp where it was meant to be
			var moved := _camp_move(space, center, String(camp.get("seal", "")))
			if moved == Vector3.INF:
				var st := WorldLanes.site_at(Vector2(center.x, center.z), 1.0)
				why = ("inside site " + String(st.name)) if not st.is_empty() else "no fair ground: " + String(SpawnRules.assess(space, center).why)
			else:
				center = moved
		if why != "":
			var skip := String(camp.get("seal", ""))
			if skip != "" and _seal_camps.has(skip):
				(_seal_camps[skip] as Dictionary).erase(str(camp.at))   # a camp that never spawns guards nothing
			push_warning("EnemySpawner: camp at %s skipped (%s)" % [camp.at, why])
			PlacementLog.skip("camps", "camp_%d_%d" % [int((camp.at as Vector3).x), int((camp.at as Vector3).z)], camp.at, why)
			continue
		var kinds: Array = camp.kinds
		var n := kinds.size()
		var sid := String(camp.get("seal", ""))
		if sid != "" and Travel.seals_broken.has(sid):
			continue                                  # a broken seal's guardians stay dead
		var route: Array[Vector3] = []
		for c2: Vector2 in camp.get("patrol", []):
			var g2 := _ground(space, Vector3(c2.x, float(camp.at.y), c2.y), float(camp.get("probe", 24.0)))
			if is_nan(_last_hit_y):
				continue
			if _realm and not SpawnRules.ok(space, g2):
				g2 = SpawnRules.find(space, Vector2(c2.x, c2.y), 6.0, g2.y + 8.0)   # a stop on a way, in a pool, on a lip: beside it
			if g2 != Vector3.INF:
				route.append(g2)
		var opts := {"ways": sid == ""}
		for i in n:
			var a := TAU * float(i) / float(maxi(n, 1)) + 0.15
			var ring: float = float(camp.get("r", 2.5)) if n > 1 else float(camp.get("r", 0.0))
			var off := Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			var probe := center + off
			if _realm and not camp.get("strict", false):
				probe.y = float(camp.at.y)               # realm ground camps probe from high above
			var at := _ground(space, probe, float(camp.get("probe", 24.0)), bool(camp.get("strict", false)))
			if _realm and is_nan(_last_hit_y):
				at = center                               # no floor there (a cliff edge): stand at the camp
			elif _realm and not camp.get("strict", false) and not SpawnRules.ok(space, at, opts):
				# its place in the ring is water, a lip, a rock or the way: the nearest fair floor beside it, else the camp's
				var near := SpawnRules.find(space, Vector2(at.x, at.z), 3.0, center.y + 8.0, opts, center.y, 2.5)
				if near == Vector3.INF:
					near = SpawnRules.find(space, Vector2(center.x, center.z), ring + 2.5, center.y + 8.0, opts, center.y, 2.5)
				at = near if near != Vector3.INF else center
			var key := String(kinds[i])
			var look := ""
			if key.contains("@"):
				look = key.get_slice("@", 1)
				key = key.get_slice("@", 0)
			elif _realm:
				look = Tiers.region_variant(at, key)      # r34: the quarry's stone-bound, the mere's drowned
			var kind: GDScript = _scripts.get(key, _scripts.get("wretch"))
			if kind == null:
				continue
			var slot := {"at": at, "pawn": null, "pending": false, "kind": kind, "seal": sid, "key": "%s#%d" % [str(camp.at), i], "variant": look,
				"strict": bool(camp.get("strict", false)), "center": center}
			if route.size() > 1:
				var pts: Array[Vector3] = []
				for g3 in route:
					pts.append(g3 + off)
				slot["patrol"] = pts
			_slots.append(slot)
	for slot in _slots:
		_spawn(slot)
	if _realm:
		_settle.call_deferred()            # the rares and a second look at every slot once the Realm's ground is final
		if Slice.full():                    # the Kindled Watch is outside the 30-minute slice (docs/DECISIONS.md)
			(load("res://core/world/watch/watch_posts.gd") as GDScript).call("build", get_parent() as Node3D)
		(load("res://core/world/mount/stables.gd") as GDScript).call("build", get_parent() as Node3D)   # r36 horses
		if get_parent().get_node_or_null("ReachState") == null:            # r36 the night progresses
			var rs: Node = ReachState.new()
			rs.name = "ReachState"
			get_parent().add_child(rs)
		if get_parent().get_node_or_null("RoamEvents") == null:            # r36 roaming events
			var roam: Node = (load("res://core/world/roam/roam_events.gd") as GDScript).new()
			roam.name = "RoamEvents"
			get_parent().add_child(roam)
	planted_done = true
	planted.emit()


## The camps are planted before the Realm's last passes: the places built after them register their own ground,
## and TerrainStamp.settle moves the ground under the floors (up to a metre). Once the Realm is done every slot
## and patrol stop is set on the ground as it is and checked against the spawn rules again (a pawn standing far
## off is moved with its slot), then the rares find their haunts on it. `settled` is set when that is done.
var settled := false
signal settled_done


func _settle() -> void:
	var host := get_parent()
	var t0 := Time.get_ticks_msec()
	while is_inside_tree() and not host.has_meta("realm_done") and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var player := _player()
	var moved := 0
	for slot in _slots:
		if bool(slot.get("strict", false)):
			continue
		var at: Vector3 = slot.at
		var opts := {"ways": String(slot.get("seal", "")) == ""}
		var g := SpawnRules.floor_at(space, Vector2(at.x, at.z), at.y + 3.0, 7.0)
		if g == Vector3.INF or not SpawnRules.ok(space, g, opts) or not WorldLanes.site_at(Vector2(g.x, g.z), 0.4).is_empty():
			var near := SpawnRules.find(space, Vector2(at.x, at.z), 4.0, at.y + 4.0, opts, at.y, 3.0)
			g = near if near != Vector3.INF else g
		var pawn: Variant = slot.pawn
		if slot.has("patrol"):
			# each pawn walks its own line of the round (the camp's stops plus its place in the ring): every stop
			# on the ground as settled and on fair floor, else beside it
			var pts: Array[Vector3] = []
			for q: Vector3 in slot.patrol:
				var h := SpawnRules.floor_at(space, Vector2(q.x, q.z), q.y + 3.0, 7.0)
				if h == Vector3.INF or not SpawnRules.ok(space, h, opts):
					var near := SpawnRules.find(space, Vector2(q.x, q.z), 3.5, q.y + 4.0, opts, q.y, 3.0)
					h = near if near != Vector3.INF else h
				pts.append(h if h != Vector3.INF else q)
			slot.patrol = pts
			if is_instance_valid(pawn) and pawn is Enemy:
				(pawn as Enemy).patrol.assign(pts)
		if g == Vector3.INF or g.distance_to(at) < 0.03:
			continue
		slot.at = g
		moved += 1
		if is_instance_valid(pawn) and pawn is Enemy and (pawn as Enemy).is_alive() and (player == null or player.global_position.distance_to(g) > 40.0):
			(pawn as Enemy).station(g)
	print("ENEMYSPAWNER settled: %d of %d slots set on the final ground" % [moved, _slots.size()])
	_make_rares()
	settled = true
	settled_done.emit()


## A camp's centre: off sites, off the ways (CAMP_BERTH; a seal guard's way is its post) and on ground the spawn
## rules take (core/life/encounters/spawn_rules.gd).
const CAMP_BERTH := 4.0
const CAMP_MOVE := 12.0


func _camp_ground_ok(space: PhysicsDirectSpaceState3D, at: Vector3, sid: String) -> bool:
	var q := Vector2(at.x, at.z)
	if not WorldLanes.site_at(q, 1.0).is_empty():
		return false
	if sid == "" and RealmLayout.path_dist(q) < CAMP_BERTH:
		return false
	var gap: Array = SpawnRules.safe_gap(q)
	if sid == "" and float(gap[0]) < float(gap[2]):
		return false                                    # never nearer a town (or the hub) than its camp margin
	return SpawnRules.ok(space, at, {"ways": sid == ""})


func _camp_move(space: PhysicsDirectSpaceState3D, at: Vector3, sid: String) -> Vector3:
	var r := 1.5
	while r <= CAMP_MOVE:
		var n := int(r * 1.6) + 6
		for k in n:
			var a := TAU * float(k) / float(n) + r * 0.37
			var g := SpawnRules.floor_at(space, Vector2(at.x + cos(a) * r, at.z + sin(a) * r), at.y + 10.0)
			if g != Vector3.INF and absf(g.y - at.y) < 4.0 and _camp_ground_ok(space, g, sid):
				return g
		r += 1.5
	return Vector3.INF


## r33: the named rares walk their haunts (core/enemy/rares.gd); their haunts are map markers.
const RARES := "res://core/enemy/rares.gd"
var rares: Node3D


func _make_rares() -> void:
	var host := get_parent() as Node3D
	if host == null or host.get_node_or_null("Rares") != null:
		return
	rares = (load(RARES) as GDScript).new() as Node3D
	host.add_child(rares)
	rares.call("setup", _scripts)


## The living guards of unbroken seals: [{pos: Vector3, seal: String}] (the minimap's red rings).
func seal_guards() -> Array:
	var out: Array = []
	for slot in _slots:
		var sid := String(slot.get("seal", ""))
		if sid == "" or Travel.seals_broken.has(sid):
			continue
		var pawn: Variant = slot.pawn
		if is_instance_valid(pawn) and pawn is Node3D and (pawn as Node).is_inside_tree():
			out.append({"pos": (pawn as Node3D).global_position, "seal": sid})
	return out


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0.0
	var player := _player()
	for slot in _slots:
		var pawn: Variant = slot.pawn
		if not is_instance_valid(pawn):
			# freed (killed and dissolved): `pawn is Enemy` on a freed object is a script error
			if slot.get("sealed_dead", false):
				continue
			if not slot.pending:
				_schedule(slot, _respawn_delay(slot))
			continue
		if player == null or not (pawn is Enemy):
			continue
		var enemy := pawn as Enemy
		var d2 := player.global_position.distance_squared_to(enemy.global_position)
		var reach := enemy.sleep_range
		if d2 > reach * reach:
			# far past its body's draw range it is not shown at all, so its skin stops at its first check each frame
			# (the doubled Realm keeps a few hundred camp pawns asleep at any spot). Visibility flips only when it
			# changes (sleep() shows it): asleep, hidden and far, it is left alone.
			var far := d2 > HIDE_R * HIDE_R
			if enemy.process_mode != Node.PROCESS_MODE_DISABLED or (not far and not enemy.visible):
				enemy.sleep()
			if far and enemy.visible:
				enemy.visible = false
		else:
			enemy.wake()


func _on_killed(enemy: Node) -> void:
	for slot in _slots:
		if slot.pawn == enemy:
			var sid: String = slot.get("seal", "")
			if sid != "":
				_count_seal_kill(sid, String(slot.key))
				slot["sealed_dead"] = true              # guardians of a seal do not come back
				return
			_schedule(slot, _respawn_delay(slot))
			return


func _count_seal_kill(sid: String, key: String) -> void:
	if Travel.seals_broken.has(sid):
		return
	if not _seal_kills.has(sid):
		_seal_kills[sid] = {}
	_seal_kills[sid][key] = true
	var done := (_seal_kills[sid] as Dictionary).size()
	var total := seal_total(sid)
	if done >= total:
		Events.seal_broken.emit(sid)
	else:
		Events.seal_progress.emit(sid, done, total)


func _schedule(slot: Dictionary, delay: float) -> void:
	if slot.pending:
		return
	slot.pending = true
	get_tree().create_timer(delay, false).timeout.connect(_respawn.bind(slot))


func _respawn(slot: Dictionary) -> void:
	slot.pending = false
	if is_instance_valid(slot.pawn) and slot.pawn is Enemy and (slot.pawn as Enemy).is_alive():
		return                                    # refilled meanwhile (a rest): no second pawn
	var player := _player()
	var near_player := player != null and player.global_position.distance_to(slot.at) < KEEP_CLEAR
	if near_player or LightGrid.is_lit(slot.at) or _in_sight(slot.at):
		_schedule(slot, RETRY)
		return
	_spawn(slot)


## A refill never appears in plain view (Luke, 9 Nov: things pop in): within UNSEEN_R of the camera and inside its
## view, the slot waits and tries again (RETRY) until you have turned away or walked off.
const UNSEEN_R := 55.0
func _in_sight(at: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	return cam.global_position.distance_to(at) < UNSEEN_R and cam.is_position_in_frustum(at + Vector3.UP)


func _spawn(slot: Dictionary) -> void:
	var kind: GDScript = slot.kind
	if kind_hook.is_valid():
		var swap: Variant = kind_hook.call(slot)
		if swap is GDScript:
			kind = swap
	if kind == null:
		kind = _scripts.get("wretch")
	if kind == null:
		return
	var host := get_parent()
	if host == null:
		return
	var pawn: Node = kind.new()
	var look := String(slot.get("variant", ""))
	if dress_hook.is_valid():
		dress_hook.call(pawn, slot)                    # the director applies the slot's look itself
	elif look != "":
		Variants.pre(pawn, look)
		pawn.ready.connect(Variants.dress.bind(pawn, look), CONNECT_ONE_SHOT)
	host.add_child(pawn)
	if pawn.has_method("station"):
		pawn.station(slot.at)
	else:
		pawn.global_position = slot.at + Vector3(0.0, 0.05, 0.0)
	if slot.has("patrol") and pawn is Enemy:
		var en := pawn as Enemy
		en.patrol.assign(slot.patrol)
		en.roam = true
		en.patrol_speed = PATROL_PACE
	slot.pawn = pawn


## --- encounters additions -----------------------------------------------------------------------

func _respawn_delay(slot: Dictionary) -> float:
	if hold_for_rest and String(slot.get("seal", "")) == "":
		return REST_HOLD
	# r36 the night progresses: a quiet country (its bell rung) and a kin faction's country wait longer
	var base := RESPAWN if String(slot.get("seal", "")) != "" else RESPAWN_ROAM
	return base * ReachState.respawn_mult(slot.at) if _realm else base


const ReachState := preload("res://core/world/night/reach_state.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")


## A rest at a fire: every dead roaming camp pawn comes back now (not seal guards, not within
## `min_dist` of the player, not in light: those keep their normal retry). Returns how many rose.
func refill(min_dist := 22.0) -> int:
	var player := _player()
	var n := 0
	for slot in _slots:
		if slot.get("sealed_dead", false) or String(slot.get("seal", "")) != "":
			continue
		if is_instance_valid(slot.pawn) and slot.pawn is Enemy and (slot.pawn as Enemy).is_alive():
			continue
		if player != null and player.global_position.distance_to(slot.at) < min_dist:
			continue
		if LightGrid.is_lit(slot.at):
			continue
		_spawn(slot)
		n += 1
	return n


## Encounters' mixed packs: one more roaming pawn at `at` (already on the ground), of `kind`.
## It respawns like any roaming slot. Returns the slot.
func add_slot(at: Vector3, kind: GDScript, key: String) -> Dictionary:
	var slot := {"at": at, "pawn": null, "pending": false, "kind": kind, "seal": "", "key": key}
	_slots.append(slot)
	if planted_done:
		_spawn(slot)
	return slot


## Live pawns of the camps (encounters retrofits tier looks onto ones planted before it loaded).
func slots() -> Array[Dictionary]:
	return _slots


## The Realm's tree colliders (RealmFlora's chunks).
static func _is_flora_body(n: Node) -> bool:
	if n == null:
		return false
	var nm := String(n.name)
	if nm == "FloraBody":
		return true
	var par := n.get_parent()
	return par != null and String(par.name).begins_with("Trees_")


var _last_hit_y := NAN     ## y of the last `_ground` hit (NAN when the probe found no floor)


## `up`: how far above `from` the probe starts (indoor camps pass ~1.5 so roofs aren't floors).
## `strict`: only probe straight down (no sideways search) and only accept ground within 4 m of
## `from` -- on the 5 m-wide stair the search used to drift off the edge into the chasm.
func _ground(space: PhysicsDirectSpaceState3D, from: Vector3, up := 24.0, strict := false) -> Vector3:
	if space == null:
		return Vector3(from.x, 0.6, from.z)
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(2.2, 0.0, 0.0), Vector3(-2.2, 0.0, 0.0),
		Vector3(0.0, 0.0, 2.2), Vector3(0.0, 0.0, -2.2),
		Vector3(3.4, 0.0, 2.0), Vector3(-3.4, 0.0, 2.0),
		Vector3(2.0, 0.0, -3.0), Vector3(-2.0, 0.0, -3.0),
	]
	var fallback := Vector3(from.x, 0.6, from.z)
	_last_hit_y = NAN
	if _cap == null:
		_cap = CapsuleShape3D.new()
		_cap.radius = 0.35
		_cap.height = 1.7
	if strict:
		offsets = [Vector3.ZERO]
	for off in offsets:
		var probe := from + off
		var q := PhysicsRayQueryParameters3D.create(
			probe + Vector3(0.0, up, 0.0),
			probe + Vector3(0.0, -80.0, 0.0)
		)
		q.collision_mask = Layers.WORLD
		var hit := space.intersect_ray(q)
		# a tree's trunk or the top of a rock face is no floor: a pawn set on one stood metres up in the wood
		var skipped: Array[RID] = []
		while not hit.is_empty() and skipped.size() < 6 and _is_flora_body(hit.collider as Node):
			skipped.append(hit.rid)
			q.exclude = skipped
			hit = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit.get("normal", Vector3.UP)
		if n.y < 0.55:
			continue
		var at: Vector3 = hit.position
		if strict and absf(at.y - from.y) > 14.0:
			continue                                          # was 4: summit camps sat just off the band and never spawned
		fallback = at
		_last_hit_y = at.y
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = _cap
		sq.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.86, 0.0))
		sq.collision_mask = Layers.WORLD
		if space.intersect_shape(sq, 1).is_empty():
			return at
	return fallback


func _player() -> Player:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Player

extends RefCounted
## THE FOUR DEEP HALLS (the world pass: the doors the story keeps opening are now real places under the ground). Each is a
## complex of rooms under a hillside, entered by a stair cut down from the surface (dungeon_kit.gd), a gate on the surface,
## and a reward room with a hook:
##   kings_undercroft   the King's Barrow's other door: antechamber, a pillared hall of sarcophagi, an ossuary chapel,
##                      an armoury, the king's crypt (a reliquary chest on the dais), a hidden grave-room
##   castellum_cisterns under the castellum: a flooded cistern hall crossed by a plank walk, the pump room (wheels), the
##                      keeper's quarters (bed, desk, the log), the sluice vault (reliquary chest), a hidden dry store
##   witchs_cellar      the Hollow-Witch's root cellar in the Southwood: root-walled rooms hung with herbs and jars, a herb
##                      store, a bedroom, the sanctum (a cauldron fire, an altar, a reliquary chest), a hidden nook
##   nave_crypt         the Drowned Nave's crypt: knee-deep water through a pillared hall, a sunken altar, half-sunk tombs,
##                      a pale light well, the crypt of the unfinished (a reliquary chest), a dry reliquary
## Each room is lit by a few unshadowed lamps and fires (the kit's light cap applies), has collision floors, walls and
## ceilings (a ceiling slab under the hill, so the ground above is never seen through), and its doorways are 2.6 x 3.4 m.
## Every complex sets group `deep_hall` and metadata the story seat can hang a payoff on: `reward_at` (the reward chest's
## world position), `threshold_at` (the stair's head on the surface) and `hall_id`. Placed by WK.find_any near the door it
## belongs to (never on it); the stair is registered as a WorldLanes flight (the ground over it is cut away).
## Build-time only; each complex fades out beyond 120 m and its big meshes carry LODs. No class_name.

const SELF := "res://core/world/realm/wonders/r39/deep_halls.gd"
const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const DK := preload("res://core/world/realm/wonders/r39/dungeon_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")
const Plan := preload("res://core/world/realm/wonders/r39/wonder_plan.gd")

const SPECS := [
	{"id": "kings_undercroft", "title": "The King's Undercroft", "line": "the barrow has a second stair", "region": "kingsbarrows", "theme": "crypt",
		"cand": [Vector2(-334.0, 118.0), Vector2(-330.0, 190.0), Vector2(-352.0, 100.0)]},
	{"id": "castellum_cisterns", "title": "The Castellum Cisterns", "line": "the water-keeper's cellars, still wet", "region": "arches", "theme": "cistern",
		"cand": [Vector2(-60.0, 365.0), Vector2(-30.0, 372.0), Vector2(-90.0, 372.0)]},
	{"id": "witchs_cellar", "title": "The Witch's Cellar", "line": "the root-cellar under the hollow", "region": "southwood", "theme": "cellar",
		"cand": [Vector2(226.0, 340.0), Vector2(250.0, 350.0), Vector2(205.0, 345.0)]},
	{"id": "nave_crypt", "title": "The Nave's Crypt", "line": "what the flood did not reach", "region": "nave", "theme": "flooded",
		"cand": [Vector2(300.0, 190.0), Vector2(340.0, 200.0), Vector2(300.0, 120.0)]},
]

var _ids: Array = []


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	for reg: Dictionary in RealmLayout.REGIONS:
		_ids.append(String(reg.id))
	# the four spots are searched once and stored (wonder_plan.gd): a warm boot builds the halls on the last picks
	var pk := Plan.key("deep_halls", SELF, ["res://core/world/realm/wonders/r39/dungeon_kit.gd"])
	var stored: Variant = Plan.load_plan(pk, SELF)
	var spots: Array = []
	if stored is Dictionary and ((stored as Dictionary).spots as Array).size() == SPECS.size():
		spots = (stored as Dictionary).spots
	var warm := not spots.is_empty()
	var n := 0
	for si in SPECS.size():
		var spec: Dictionary = SPECS[si]
		var c: Vector2
		var yaw: float
		if warm:
			var sp: Array = spots[si]
			c = sp[0]
			yaw = float(sp[1])
		else:
			var f := WK.place_first(spec.cand as Array, Vector2(16.0, 34.0), [0.0, PI * 0.5, PI, PI * 1.5], 12.0)
			c = f.pos
			yaw = float(f.yaw)
			spots.append([c, yaw])
		if _hall(root, spec, c, yaw):
			n += 1
	if not warm:
		Plan.save_plan(pk, SELF, {"spots": spots})
	print("WONDER deep_halls: %d of %d complexes" % [n, SPECS.size()])


func _hall(root: Node, spec: Dictionary, c: Vector2, yaw: float) -> bool:
	var ez := Vector2(-sin(yaw), cos(yaw))
	# the entry is the end of the footprint with the lower ground; the way in runs up the hill
	var ea := c - ez * 33.0
	var eb := c + ez * 33.0
	var fwd2 := ez if WK.h(ea.x, ea.y) <= WK.h(eb.x, eb.y) else -ez
	var d := DK.new()
	d.k = WK.new()
	d.k.setup(root, "Hall_" + String(spec.id), 7700 + (hash(String(spec.id)) % 100))
	d.fwd = Vector3(fwd2.x, 0.0, fwd2.y)
	d.side = d.fwd.cross(Vector3.UP)
	var start := c - fwd2 * 33.0
	d.run = 30.0
	d.o = Vector3(start.x, WK.h(start.x, start.y), start.y)
	var gmin := INF
	for ui in range(-16, 17, 8):
		for vi in range(0, 39, 6):
			var q := d.o + d.fwd * (d.run + float(vi)) + d.side * float(ui)
			gmin = minf(gmin, WK.h(q.x, q.z))
	gmin = minf(gmin, d.o.y)
	d.yf = gmin - 8.6
	_theme(d, String(spec.theme))
	d.k.poi(String(spec.id), String(spec.title), String(spec.line), String(spec.region))
	d.k.host.add_to_group("deep_hall")
	d.k.host.set_meta("hall_id", String(spec.id))
	d.k.host.set_meta("threshold_at", d.o)
	WorldLanes.register_flight("hall_" + String(spec.id), d.o, Vector3(d.o.x + d.fwd.x * d.run, d.yf, d.o.z + d.fwd.z * d.run), 3.6)
	WK.reserve("hall_gate_" + String(spec.id), Vector2(d.o.x, d.o.z), Vector2(9.0, 7.0), yaw, d.o.y - 2.0, d.o.y + 8.0)
	if not d.k.cached(WK.fp(SELF, [String(spec.id), d.o, d.yf, d.fwd, WK.tsig(Vector2(d.o.x, d.o.z) + Vector2(d.fwd.x, d.fwd.z) * 32.0, 40.0)])):
		d.stair()
		d.gate()
		match String(spec.theme):
			"crypt": _crypt(d, spec)
			"cistern": _cistern(d, spec)
			"cellar": _cellar(d, spec)
			_: _flooded(d, spec)
	var n: int = d.k.commit(120.0)
	var bed := {"crypt": ["crypt", "crypt"], "cistern": ["hall", "hall"], "cellar": ["cave", "hollow"], "flooded": ["hall", "nave"]}[String(spec.theme)] as Array
	d.zone(-15.0, 15.0, 0.0, 44.0, 6.8, String(bed[0]), String(bed[1]))
	d.k.host.set_meta("reward_at", d.p(0.0, 0.3, 39.0))
	print("WONDER deep_hall %s: gate %s floor %.1f, %d rooms, %d meshes, %d fires, %d lights, %d chests" % [String(spec.id), Vector2(d.o.x, d.o.z), d.yf, d.count.rooms, n, d.k.fires, d.k.lights, d.k.chests])
	return true


func _theme(d, theme: String) -> void:
	match theme:
		"cistern":
			d.wall = "brick_big"
			d.trim = "stone_big"
			d.light = Color(1.0, 0.72, 0.4)
		"cellar":
			d.wall = "bark"
			d.trim = "wood_big"
			d.ceil_key = "bark"
			d.floor_key = "wood_big"
			d.light = Color(0.95, 0.8, 0.4)
		"flooded":
			d.wall = "chalk"
			d.trim = "ruin_big"
			d.light = Color(0.55, 0.75, 1.0)
		_:
			d.wall = "stone_big"
			d.trim = "ruin_big"


## The skeleton shared by all four: antechamber, hall, two side rooms off it, the end room, a hidden room off the end room.
func _rooms(d, hall_h: float, hidden := true) -> void:
	d.room(-4.0, 4.0, 0.0, 8.0, 4.4, {"front": true, "gaps_front": [0.0], "gaps_back": [0.0]})
	d.room(-6.0, 6.0, 8.8, 30.0, hall_h, {"gaps_back": [0.0], "gaps_left": [16.0], "gaps_right": [16.0]})
	d.room(-15.0, -6.8, 12.0, 21.0, 4.6, {"no_right": true})
	d.room(6.8, 15.0, 12.0, 21.0, 4.6, {"no_left": true})
	d.room(-7.0, 7.0, 30.8, 44.0, 6.4, {"gaps_right": [38.0] if hidden else []})
	if hidden:
		d.room(7.8, 14.0, 34.0, 42.0, 3.8, {"no_left": true})


func _end_chest(d, tier: String, id: String, loot: Dictionary) -> void:
	d.blk(d.trim, -3.0, 3.0, 38.0, 42.0, 0.0, 0.6, 0.9)
	d.blk(d.wall, -2.3, 2.3, 38.6, 41.4, 0.6, 1.0, 0.95)
	d.k.chest(id, tier, d.p(0.0, 1.0, 40.2), atan2(-d.fwd.x, -d.fwd.z), loot)


## The hidden room: reached through a doorway half-hidden behind a leaning slab and rubble in the end room's east wall.
func _hidden(d, id: String, loot: Dictionary) -> void:
	var slab: Vector3 = d.p(6.2, 1.2, 36.6)
	d.k.kit.box(d.trim, slab, Vector3(0.5, 2.4, 1.5), Basis(d.side, Vector3.UP, d.fwd) * Basis(Vector3.FORWARD, 0.4), true, 0.84)
	Dress.rubble(d.k, d.p(5.8, 0.0, 36.0), 1.5, 8, d.wall)
	d.lamp(10.5, 2.0, 38.0, 0.8, 6.0)
	d.k.chest(id, "iron", d.p(12.6, 0.3, 38.0), atan2(d.side.x, d.side.z) + PI, loot)
	d.k.kit.box("glow", d.p(8.0, 2.6, 38.0), Vector3(0.2, 0.3, 0.2), d.basis(), false, 1.0)


func _crypt(d, spec: Dictionary) -> void:
	_rooms(d, 6.0)
	var rng: RandomNumberGenerator = d.k.rng
	# antechamber: braziers, a bench, a notice
	d.k.fire(d.p(-3.2, 0.9, 1.5), 0.7, 1.4)
	d.k.fire(d.p(3.2, 0.9, 1.5), 0.7, 1.4)
	for s: float in [-1.0, 1.0]:
		d.k.kit.box("iron", d.p(s * 3.2, 0.4, 1.5), Vector3(0.7, 0.8, 0.7), d.basis(), true, 0.7)
		d.k.kit.box("wood_big", d.p(s * 3.1, 0.4, 5.5), Vector3(0.6, 0.8, 2.4), d.basis(), true, 0.8)
	d.k.chest("uc_ante", "wood", d.p(-3.0, 0.1, 7.0), 0.0, {"grave_ash": 8, "grave_iron": 1})
	d.lamp(0.0, 3.4, 4.0, 1.0, 9.0)
	# the hall: two rows of columns, sarcophagi in the bays, sconces
	for i in 4:
		for s: float in [-1.0, 1.0]:
			d.column(s * 3.2, 12.0 + 5.0 * float(i), 6.0)
	for i in 4:
		d.sarcophagus(-5.0, 12.0 + 5.0 * float(i), 0.0, 0.0 if i != 2 else 0.5)
		d.sarcophagus(5.0, 12.0 + 5.0 * float(i), 0.0, 0.0 if i != 1 else -0.4)
		d.sconce(-5.6, 3.0, 13.0 + 5.0 * float(i), 1.0, 0.8)
		if i % 2 == 0:
			d.sconce(5.6, 3.0, 13.0 + 5.0 * float(i), -1.0, 0.8)
	Dress.carved_band(d.k, d.p(-5.9, 3.6, 9.0), d.p(-5.9, 3.6, 29.0), 20, Vector3(0.3, 0.45, 0.8), d.trim)
	Dress.carved_band(d.k, d.p(5.9, 3.6, 9.0), d.p(5.9, 3.6, 29.0), 20, Vector3(0.3, 0.45, 0.8), d.trim)
	Dress.strands(d.k, d.p(-5.0, 5.9, 9.0), d.p(5.0, 5.9, 9.0), 7, 1.6)
	Dress.rubble(d.k, d.p(1.0, 0.0, 22.0), 3.0, 14, d.wall)
	# the ossuary chapel: heaps of skulls and bones
	for i in 40:
		var q: Vector3 = d.p(rng.randf_range(-14.4, -7.4), 0.2 + 0.5 * rng.randf(), rng.randf_range(12.4, 20.6))
		d.k.kit.skull(q, rng.randf() * TAU, rng.randf_range(0.8, 1.1), rng.randi() % 2, rng.randf_range(-0.4, 0.4))
		if i % 3 == 0:
			d.k.kit.bone(q + Vector3(0.1, -0.05, 0.1), Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, 1.4), rng.randi() % 3, false)
	d.k.kit.candle_cluster(d.p(-11.0, 1.0, 16.5), 6, 0.3, rng)
	d.k.kit.box(d.trim, d.p(-11.0, 0.5, 16.5), Vector3(2.2, 1.0, 1.2), d.basis(), true, 0.9)
	d.lamp(-11.0, 2.6, 16.5, 1.0, 8.0)
	# the armoury: racks of spears and rusted shields, a weapon table
	for i in 5:
		var rx := 8.0 + 1.5 * float(i)
		d.k.tube("iron", d.p(rx, 0.0, 12.8), d.p(rx + 0.3, 3.0, 12.7), 0.05, 0.03, 4, false, 0.55)
		d.k.tube("wood_big", d.p(rx + 0.2, 0.0, 12.8), d.p(rx + 0.3, 2.5, 12.8), 0.04, 0.04, 4, false, 0.6)
		d.k.kit.box("iron", d.p(rx, 1.2, 20.3), Vector3(0.8, 0.8, 0.12), Basis(d.side, Vector3.UP, d.fwd) * Basis(Vector3.RIGHT, 0.2), false, 0.5)
	d.k.kit.box("wood_big", d.p(11.0, 0.5, 16.5), Vector3(3.0, 0.9, 1.2), d.basis(), true, 0.8)
	d.lamp(11.0, 2.8, 16.5, 0.9, 8.0)
	# the crypt: a dais with the king's tomb, braziers, the reliquary chest, the hidden room's door
	d.blk(d.trim, -4.0, 4.0, 33.0, 37.5, 0.0, 0.5, 0.9)
	d.blk(d.trim, -1.6, 1.6, 33.8, 36.7, 0.5, 1.4, 0.92)
	d.k.kit.box(d.wall, d.p(0.0, 1.7, 35.2), Vector3(1.2, 0.6, 2.4), d.basis(), true, 0.98)
	for s: float in [-1.0, 1.0]:
		d.column(s * 5.6, 33.0, 6.4, 0.5)
		d.column(s * 5.6, 41.0, 6.4, 0.5)
		d.k.fire(d.p(s * 3.2, 1.2, 33.4), 0.9, 1.8)
		d.k.kit.box("iron", d.p(s * 3.2, 0.7, 33.4), Vector3(0.7, 0.4, 0.7), d.basis(), true, 0.7)
	_end_chest(d, "reliquary", "uc_main", {"grave_ash": 30, "grave_iron": 4, "relic_fragment": 3})
	d.lamp(0.0, 4.6, 36.0, 1.4, 12.0)
	_hidden(d, "uc_secret", {"grave_ash": 14, "grave_iron": 2, "relic_fragment": 1})
	Dress.camp(d.k, d.p(-2.0, 0.0, 3.0), 0.0, false)


func _cistern(d, spec: Dictionary) -> void:
	_rooms(d, 6.4)
	var rng: RandomNumberGenerator = d.k.rng
	d.k.fire(d.p(-3.2, 0.9, 1.5), 0.7, 1.4)
	d.k.kit.box("iron", d.p(-3.2, 0.4, 1.5), Vector3(0.7, 0.8, 0.7), d.basis(), true, 0.7)
	d.lamp(0.0, 3.4, 4.0, 1.0, 9.0)
	d.k.chest("cc_ante", "wood", d.p(3.0, 0.1, 6.8), 0.0, {"grave_ash": 8, "grave_iron": 1})
	d.water(-6.0, 6.0, 8.8, 30.0, 0.7)
	for i in 4:
		for s: float in [-1.0, 1.0]:
			d.column(s * 4.0, 12.0 + 5.0 * float(i), 6.4, 0.55)
	# the plank walk down the middle: boards on piles above the water
	for i in 11:
		var v := 9.2 + 2.0 * float(i)
		d.blk("wood_big", -1.1, 1.1, v, v + 1.9, 0.78, 0.95, 0.8)
		if i % 3 == 0:
			for s: float in [-1.0, 1.0]:
				d.k.tube("wood_big", d.p(s * 1.0, -0.5, v + 0.5), d.p(s * 1.0, 0.9, v + 0.5), 0.12, 0.12, 5, true, 0.7)
	for i in 4:
		d.sconce(-5.6, 3.2, 13.0 + 5.0 * float(i), 1.0, 0.9)
		d.sconce(5.6, 3.2, 13.0 + 5.0 * float(i), -1.0, 0.9)
	Dress.chain(d.k, d.p(-5.0, 5.8, 10.0), d.p(5.0, 5.8, 10.0), 1.2)
	Dress.strands(d.k, d.p(-5.0, 6.3, 9.0), d.p(5.0, 6.3, 29.0), 10, 1.6)
	# the pump room (west): wheels, a boiler, pipes down into the water
	for i in 2:
		var wc: Vector3 = d.p(-10.5 + 3.0 * float(i), 1.9, 16.5)
		d.k.tube("iron", wc - d.fwd * 0.2, wc + d.fwd * 0.2, 1.7, 1.7, 12, false, 0.6, Vector2(1.0, -1.0), true)
		d.k.tube("iron", wc - d.fwd * 0.3, wc + d.fwd * 0.3, 0.3, 0.3, 6, false, 0.5, Vector2(1.0, -1.0), true)
	d.k.tube("iron", d.p(-13.0, 0.0, 12.8), d.p(-13.0, 4.4, 12.8), 0.35, 0.35, 8, true, 0.6)
	d.k.tube("iron", d.p(-13.0, 4.0, 12.8), d.p(-7.0, 4.0, 12.8), 0.22, 0.22, 6, false, 0.6)
	d.k.kit.box("iron", d.p(-12.0, 0.9, 19.5), Vector3(2.4, 1.8, 1.4), d.basis(), true, 0.6)
	d.k.fire(d.p(-12.0, 1.9, 19.5), 0.5, 1.2)
	d.lamp(-11.0, 3.0, 16.5, 1.0, 8.0)
	# the keeper's quarters (east): a bed, a desk with the log, a shelf, a stove
	d.k.kit.box("wood_big", d.p(14.0, 0.4, 14.0), Vector3(1.0, 0.8, 2.2), d.basis(), true, 0.8)
	d.k.kit.box("wax", d.p(14.0, 0.85, 14.0), Vector3(0.9, 0.12, 2.0), d.basis(), false, 0.9)
	d.k.kit.box("wood_big", d.p(10.0, 0.5, 20.0), Vector3(2.4, 1.0, 1.0), d.basis(), true, 0.8)
	d.k.kit.box("wax", d.p(10.0, 1.05, 20.0), Vector3(0.7, 0.05, 0.5), d.basis(), false, 0.95)
	d.k.kit.box("wood_big", d.p(14.5, 1.5, 18.0), Vector3(0.5, 3.0, 3.0), d.basis(), true, 0.8)
	d.k.kit.candle_cluster(d.p(10.6, 1.1, 20.0), 3, 0.15, rng)
	d.lamp(10.5, 2.6, 17.0, 1.0, 8.0)
	d.k.chest("cc_keeper", "wood", d.p(13.0, 0.1, 19.6), PI, {"grave_ash": 9, "grave_iron": 1})
	# the sluice vault: a great wheel on the end wall, a dais and the reliquary chest
	var wc2: Vector3 = d.p(0.0, 3.4, 43.0)
	d.k.tube("iron", wc2 - d.fwd * 0.2, wc2 + d.fwd * 0.2, 2.2, 2.2, 16, false, 0.6, Vector2(1.0, -1.0), true)
	for i in 4:
		var a := PI * float(i) / 4.0
		d.k.beam("iron", wc2 + (d.side * cos(a) + Vector3.UP * sin(a)) * 2.2, wc2 - (d.side * cos(a) + Vector3.UP * sin(a)) * 2.2, 0.18, 0.18, false, 0.55)
	d.blk(d.trim, -4.0, 4.0, 33.0, 38.0, 0.0, 0.5, 0.9)
	d.k.fire(d.p(-3.0, 1.1, 33.6), 0.8, 1.6)
	d.k.fire(d.p(3.0, 1.1, 33.6), 0.8, 1.6)
	_end_chest(d, "reliquary", "cc_main", {"grave_ash": 28, "grave_iron": 4, "relic_fragment": 3})
	d.lamp(0.0, 4.6, 36.0, 1.3, 12.0)
	_hidden(d, "cc_secret", {"grave_ash": 14, "grave_iron": 2, "relic_fragment": 1})


func _cellar(d, spec: Dictionary) -> void:
	_rooms(d, 5.6)
	var rng: RandomNumberGenerator = d.k.rng
	d.k.fire(d.p(0.0, 0.5, 2.0), 0.6, 1.4)
	d.lamp(0.0, 3.4, 4.0, 1.0, 9.0)
	d.k.chest("wc_ante", "wood", d.p(3.0, 0.1, 6.8), 0.0, {"grave_ash": 8, "grave_iron": 1})
	# roots through every room: strands from the ceilings, buttress roots in the corners
	for v: float in [3.0, 13.0, 22.0, 28.0, 36.0, 42.0]:
		Dress.strands(d.k, d.p(-5.5, 5.4, v), d.p(5.5, 5.4, v), 9, 2.4, "bark")
	for i in 14:
		var u := rng.randf_range(-5.5, 5.5)
		var v := rng.randf_range(10.0, 29.0)
		d.k.tube("bark", d.p(u, 5.6, v), d.p(u + rng.randf_range(-0.5, 0.5), 2.6, v + rng.randf_range(-0.5, 0.5)), 0.22, 0.05, 5, false, 0.7)
	for s: float in [-1.0, 1.0]:
		for v: float in [9.5, 29.5]:
			d.k.tube("bark", d.p(s * 5.6, 0.0, v), d.p(s * 4.2, 5.5, v + 0.5), 0.6, 0.25, 6, false, 0.75)
	# the hall: long tables, benches, hanging herbs on lines, jars on shelves, lamps
	d.k.kit.box("wood_big", d.p(0.0, 0.5, 16.0), Vector3(1.6, 0.9, 8.0), d.basis(), true, 0.8)
	for s: float in [-1.0, 1.0]:
		d.k.kit.box("wood_big", d.p(s * 1.6, 0.25, 16.0), Vector3(0.5, 0.5, 8.0), d.basis(), true, 0.75)
	for i in 3:
		Dress.rope(d.k, d.p(-5.5, 3.9, 12.0 + 5.0 * float(i)), d.p(5.5, 3.9, 12.0 + 5.0 * float(i)), 0.4, 0.03)
		Dress.strands(d.k, d.p(-4.5, 3.9, 12.0 + 5.0 * float(i)), d.p(4.5, 3.9, 12.0 + 5.0 * float(i)), 8, 1.1, "bark")
	for i in 9:
		d.k.tube("wood_big", d.p(-5.2, 1.0 + 0.9 * float(i % 3), 10.5 + 2.1 * float(i / 3)), d.p(-5.2, 1.5 + 0.9 * float(i % 3), 10.5 + 2.1 * float(i / 3)), 0.22, 0.22, 7, false, 0.7, Vector2(1.0, -1.0), true)
	for i in 3:
		d.lamp(0.0, 3.2, 11.0 + 8.0 * float(i), 0.9, 8.0)
		d.k.kit.box("glow", d.p(0.0, 3.2, 11.0 + 8.0 * float(i)), Vector3(0.22, 0.3, 0.22), d.basis(), false, 1.0)
	# the herb store (west): drying racks, sacks, a mortar bench; the bedroom (east): a nest of furs, a chest, a mirror
	for i in 4:
		d.k.kit.box("wood_big", d.p(-14.0, 0.8, 13.0 + 2.2 * float(i)), Vector3(0.6, 1.6, 1.6), d.basis(), true, 0.75)
		Dress.strands(d.k, d.p(-14.4, 3.3, 12.5 + 2.2 * float(i)), d.p(-13.6, 3.3, 12.5 + 2.2 * float(i)), 4, 1.0, "bark")
	Dress.barrel(d.k, d.p(-8.0, 0.0, 19.5), 0.0, 1.1)
	Dress.crate(d.k, d.p(-8.2, 0.0, 13.0), 0.3, 0.9)
	d.lamp(-11.0, 2.8, 16.5, 0.9, 7.0)
	d.k.kit.box("wax", d.p(11.0, 0.3, 17.0), Vector3(3.0, 0.5, 2.0), d.basis(), false, 0.75)
	d.k.kit.box("wood_big", d.p(14.2, 1.3, 15.5), Vector3(0.1, 2.0, 1.2), d.basis(), false, 0.5)
	d.k.chest("wc_bed", "wood", d.p(8.8, 0.1, 13.2), 0.0, {"grave_ash": 9, "grave_iron": 1})
	d.lamp(11.0, 2.6, 16.5, 0.9, 7.0)
	# the sanctum: a great cauldron on a fire, an altar of roots, the reliquary chest
	d.k.tube("iron", d.p(0.0, 0.9, 34.5), d.p(0.0, 2.1, 34.5), 1.2, 1.0, 12, false, 0.55, Vector2(1.0, -1.0), true)
	d.k.fire(d.p(0.0, 0.2, 34.5), 1.5, 3.0)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		d.k.beam("iron", d.p(cos(a) * 1.0, 0.0, 34.5 + sin(a) * 1.0), d.p(0.0, 2.8, 34.5), 0.08, 0.08, false, 0.5)
	d.k.kit.box("bark", d.p(-5.5, 0.7, 39.0), Vector3(1.4, 1.4, 3.0), d.basis(), true, 0.8)
	d.k.kit.candle_cluster(d.p(-5.5, 1.4, 39.0), 6, 0.3, rng)
	_end_chest(d, "reliquary", "wc_main", {"grave_ash": 30, "grave_iron": 4, "relic_fragment": 3})
	d.lamp(0.0, 4.2, 38.0, 1.3, 11.0)
	_hidden(d, "wc_secret", {"grave_ash": 14, "grave_iron": 2, "relic_fragment": 1})


func _flooded(d, spec: Dictionary) -> void:
	_rooms(d, 6.4)
	var rng: RandomNumberGenerator = d.k.rng
	d.k.fire(d.p(3.2, 0.9, 1.5), 0.7, 1.4)
	d.k.kit.box("iron", d.p(3.2, 0.4, 1.5), Vector3(0.7, 0.8, 0.7), d.basis(), true, 0.7)
	d.lamp(0.0, 3.4, 4.0, 1.0, 9.0)
	d.k.chest("nc_ante", "wood", d.p(-3.0, 0.1, 7.0), 0.0, {"grave_ash": 8, "grave_iron": 1})
	d.water(-15.0, 15.0, 8.8, 30.0, 0.55)
	d.water(-7.0, 7.0, 30.8, 44.0, 0.45)
	for i in 4:
		for s: float in [-1.0, 1.0]:
			d.column(s * 3.4, 12.0 + 5.0 * float(i), 6.4, 0.6)
	# the sunken altar mid-hall, half-sunk tombs in the bays, drowned banners, a pale light well of glass
	d.blk(d.trim, -2.5, 2.5, 19.0, 23.0, 0.0, 0.9, 0.9)
	d.blk(d.wall, -1.2, 1.2, 20.0, 22.0, 0.9, 1.6, 0.95)
	d.k.kit.candle_cluster(d.p(0.0, 1.6, 21.0), 5, 0.25, rng)
	for i in 4:
		d.sarcophagus(-4.9, 12.0 + 5.0 * float(i), 0.0, 0.0 if i != 3 else 0.6, d.wall)
		d.sarcophagus(4.9, 12.0 + 5.0 * float(i), 0.0, 0.0, d.wall)
	for i in 4:
		d.sconce(-5.6, 3.2, 13.0 + 5.0 * float(i), 1.0, 0.9)
	var wq: Vector3 = d.p(0.0, 0.0, 25.5)
	for i in 6:
		var g0: Vector3 = d.p(-0.9, 6.3, 24.6 + 0.4 * float(i))
		var g1: Vector3 = d.p(0.9, 6.3, 24.6 + 0.4 * float(i))
		var g2: Vector3 = d.p(0.9, 1.2, 25.0 + 0.2 * float(i))
		var g3: Vector3 = d.p(-0.9, 1.2, 25.0 + 0.2 * float(i))
		d.k.kit.quad("glow", g0, g1, g2, g3, -d.fwd, false, 0.4)      # the falling light, a sheet
	d.k.lamp(wq + Vector3.UP * 3.0, Color(0.6, 0.78, 1.0), 1.8, 11.0)
	Dress.banner(d.k, d.p(-5.7, 5.5, 12.0), d.fwd, 2.0, 3.6, d.side)
	Dress.banner(d.k, d.p(5.7, 5.5, 22.0), -d.fwd, 2.0, 3.0, -d.side)
	Dress.strands(d.k, d.p(-5.0, 6.3, 9.0), d.p(5.0, 6.3, 29.0), 9, 1.3, "chalk")
	Dress.rubble(d.k, d.p(0.0, 0.0, 27.0), 3.0, 12, d.wall)
	# the side rooms: west a drowned chapel (an altar, kneelers), east the vestry (chests, vestments on rails)
	d.k.kit.box(d.trim, d.p(-11.0, 0.5, 16.5), Vector3(2.4, 1.0, 1.2), d.basis(), true, 0.9)
	for i in 4:
		d.k.kit.box("wood_big", d.p(-11.0, 0.25, 13.5 + 0.0), Vector3(0.4, 0.5, 0.5), d.basis(), false, 0.7)
	d.lamp(-11.0, 2.8, 16.5, 0.9, 7.0)
	d.k.kit.box("wood_big", d.p(11.0, 0.6, 20.0), Vector3(3.0, 1.2, 0.8), d.basis(), true, 0.8)
	d.k.beam("wood_big", d.p(8.0, 3.2, 13.0), d.p(14.0, 3.2, 13.0), 0.1, 0.1, false, 0.7)
	Dress.banner(d.k, d.p(8.5, 3.2, 13.0), d.side, 2.0, 2.4, d.fwd, "chalk")
	d.lamp(11.0, 2.8, 16.5, 0.9, 7.0)
	d.k.chest("nc_vestry", "wood", d.p(13.8, 0.1, 19.0), PI, {"grave_ash": 9, "grave_iron": 1})
	# the crypt of the unfinished: a dais, the reliquary chest, braziers, columns
	d.blk(d.trim, -4.0, 4.0, 33.0, 38.0, 0.0, 0.5, 0.9)
	for s: float in [-1.0, 1.0]:
		d.k.fire(d.p(s * 3.0, 1.1, 33.6), 0.8, 1.6)
		d.column(s * 5.6, 33.0, 6.4, 0.5)
		d.column(s * 5.6, 41.0, 6.4, 0.5)
	_end_chest(d, "reliquary", "nc_main", {"grave_ash": 28, "grave_iron": 4, "relic_fragment": 3})
	d.lamp(0.0, 4.6, 36.0, 1.3, 12.0)
	_hidden(d, "nc_secret", {"grave_ash": 14, "grave_iron": 2, "relic_fragment": 1})

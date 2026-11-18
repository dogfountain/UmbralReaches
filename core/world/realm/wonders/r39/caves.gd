extends RefCounted
## CAVES AND GROTTOS (the world pass): seven caves off the roads, each its own kind, each with an interior to walk, water
## or crystal or root or ember, and something found at the back. Built with the same generator as the deep halls
## (dungeon_kit.gd): a stair cut down into the hill (WorldLanes flight), then three chambers (mouth, middle, deep) under the
## natural ground, rock walls (the "cave" materials: dark stone, mossy stone, pale crystal), stalactites and stalagmites,
## a pool in the middle chamber, a few unshadowed lamps (the kit's light cap applies), and a find.
##   0 crystal grotto   pale crystals in clusters that glow cold, a still pool, an iron chest on a crystal bed
##   1 root cave        roots through the ceiling, a seeping pool, a lost pilgrim's pack (camp) and a chest
##   2 bat cave         hanging bundles, guano heaps, a drip pool, a chest wedged behind fallen rock
##   3 flooded cave     knee-deep water through all three chambers, stepping stones, a chest on a dry island
##   4 ember cave       glowing seams in the walls, fire pits, basalt columns, a chest on a ledge
##   5 bone den         skulls and bones in heaps, a burrow of furs, a chest with a relic
##   6 fungus grotto    shelves of pale fungus, glowing caps, damp moss, a chest in the cap ring
## Each has a mouth marked by two flanking boulders (RockKit) and rubble, is a discovery (world_poi) and sets group `cave`
## with `find_at`. Positions: found by sampling the Far Reaches and the old valley's wild ground 60+ m off every way and
## 90 m apart (WK.find_any); each cave fades at 110 m, its meshes carry LODs when large. Build-time only.
## No class_name.

const SELF := "res://core/world/realm/wonders/r39/caves.gd"
const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const DK := preload("res://core/world/realm/wonders/r39/dungeon_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const Plan := preload("res://core/world/realm/wonders/r39/wonder_plan.gd")

const NAMES := ["The Crystal Grotto", "The Root Cave", "The Bat Cave", "The Drowned Cave", "The Ember Cave", "The Bone Den", "The Fungus Grotto"]
const LINES := ["a cold light under the heather", "the roots go all the way down", "something lives in the dark and leaves it", "the water came in and stayed",
	"a seam of the rift reached here", "the bears were not the first to dig it", "the cap-ring of a thousand nights"]

var _placed: Array[Vector2] = []
var _picks: Array = []                 ## [centre, yaw] of every cave built, in order: the stored search (wonder_plan.gd)


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _run(root: Node) -> void:
	# a warm boot builds the caves the last search picked (wonder_plan.gd), in the same order
	var pk := Plan.key("caves", SELF, ["res://core/world/realm/wonders/r39/dungeon_kit.gd"])
	var stored: Variant = Plan.load_plan(pk, SELF)
	# (map audit, 18 Nov: a stored pick is used only while it is still clear of every site the landmarks built before it
	# reserved -- cave 4's stored spot lay inside the Sleeper, built after the plan was made; a stale plan is searched again)
	if stored is Dictionary and _plan_clear((stored as Dictionary).spots):
		var sd: Dictionary = stored
		var spots: Array = sd.spots
		for si in spots.size():
			var sp: Array = spots[si]
			_make(root, si, sp[0] as Vector2, float(sp[1]))
		print(String(sd.log))
		return
	# the whole Realm is the candidate set (a jittered 26 m grid, shuffled): the first seven that pass; every refusal is counted
	var cands := WK.grid(7710, 26.0, 30.0)
	var t := {}
	var n := 0
	var tried := 0
	for fc: Vector2 in [Vector2(-302.8, 365.0), Vector2(-27.0, 278.4)]:       # the Crystal Grotto and the Root Cave keep the spots they had
		if _cave(root, n, fc):
			n += 1
	for c: Vector2 in cands:
		if n >= 7:
			break
		tried += 1
		if _ok(c, t) and _cave(root, n, c):
			n += 1
	var line := "WONDER caves: %d of 7 (%d of %d candidates tried); rejected: %s" % [n, tried, cands.size(), WK.rejected(t)]
	print(line)
	Plan.save_plan(pk, SELF, {"spots": _picks, "log": line})


## Every stored cave still clear of the sites reserved before the caves are built (the Sleeper, the Salt Ship, the halls).
static func _plan_clear(spots: Array) -> bool:
	for sp: Array in spots.slice(2):              # (the first two keep their fixed spots, sites or no)
		var c: Vector2 = sp[0]
		if WK.site_hit(Rect2(c - Vector2(10.0, 20.0), Vector2(20.0, 40.0)), 1.0):
			return false
	return true


func _ok(c: Vector2, t: Dictionary) -> bool:
	if RealmLayout.path_dist(c) < 12.0:
		return WK.rej(t, "way")
	if WK.wet(c.x, c.y):
		return WK.rej(t, "water")
	for q: Vector2 in _placed:
		if q.distance_to(c) < 55.0:
			return WK.rej(t, "spacing")
	if WK.region_at(c) in ["hearth", "summit", "rift", "ossuary", "henge"] or WK.in_town(c, 20.0):
		return WK.rej(t, "region")
	if WK.site_hit(Rect2(c - Vector2(10.0, 20.0), Vector2(20.0, 40.0)), 1.0):
		return WK.rej(t, "site")
	return true


func _cave(root: Node, i: int, c0: Vector2) -> bool:
	var f := WK.place_first([c0], Vector2(12.0, 26.0), [0.0, PI * 0.5, PI, PI * 1.5], 14.0, c0 in [Vector2(-302.8, 365.0), Vector2(-27.0, 278.4)])
	if bool(f.get("site", true)):
		return false
	var c: Vector2 = f.pos
	_placed.append(c)
	_picks.append([c, float(f.yaw)])
	return _make(root, i, c, float(f.yaw))


## The cave `i` at centre `c`, its stair running along `yaw`: the build from a pick.
func _make(root: Node, i: int, c: Vector2, yaw: float) -> bool:
	var ez := Vector2(-sin(yaw), cos(yaw))
	var fwd2 := ez if WK.h(c.x - ez.x * 24.0, c.y - ez.y * 24.0) <= WK.h(c.x + ez.x * 24.0, c.y + ez.y * 24.0) else -ez
	var d := DK.new()
	d.k = WK.new()
	d.k.setup(root, "Cave%d" % i, 8300 + i)
	d.fwd = Vector3(fwd2.x, 0.0, fwd2.y)
	d.side = d.fwd.cross(Vector3.UP)
	var start := c - fwd2 * 24.0
	d.run = 20.0
	d.o = Vector3(start.x, WK.h(start.x, start.y), start.y)
	# (map audit: every 3 m over the whole footprint and 1.6 m more cover: caves 1, 2 and 4 showed their roof slabs and
	# black walls through the turf of their hillsides)
	var gmin := d.o.y
	for ui in range(-12, 13, 3):
		for vi in range(-2, 40, 3):
			var q := d.o + d.fwd * (d.run + float(vi)) + d.side * float(ui)
			gmin = minf(gmin, WK.h(q.x, q.z))
	d.yf = gmin - 9.0
	d.wall = "cave"
	d.trim = "cave"
	d.ceil_key = "cave"
	d.floor_key = "cave"
	d.light = Color(0.6, 0.78, 1.0) if i in [0, 3, 6] else Color(1.0, 0.7, 0.4)
	d.k.poi("cave_%d" % i, String(NAMES[i]), String(LINES[i]), WK.region_at(c) if WK.region_at(c) != "" else "road")
	d.k.host.add_to_group("cave")
	d.k.host.set_meta("threshold_at", d.o)
	WorldLanes.register_flight("cave_%d" % i, d.o, Vector3(d.o.x + d.fwd.x * d.run, d.yf, d.o.z + d.fwd.z * d.run), 3.2)
	WK.reserve("cave_mouth_%d" % i, Vector2(d.o.x, d.o.z), Vector2(8.0, 6.0), yaw, d.o.y - 2.0, d.o.y + 6.0)
	_boulders(d, i)
	if not d.k.cached(WK.fp(SELF, [i, d.o, d.yf, d.fwd, WK.tsig(c, 30.0)])):
		_mouth(d, i)
		d.stair(3.0)
		d.room(-4.5, 4.5, 0.0, 9.0, 4.4, {"front": true, "gaps_front": [0.0], "gaps_back": [0.0]})
		d.room(-8.0, 8.0, 9.8, 25.0, 5.6, {"gaps_back": [0.0]})
		d.room(-5.5, 5.5, 25.8, 36.0, 5.2, {})
		_dress(d, i)
	d.k.host.set_meta("find_at", d.p(0.0, 0.3, 33.0))
	var n: int = d.k.commit(110.0)
	d.zone(-8.0, 8.0, 0.0, 36.0, 5.8, "cave", "hollow" if i == 1 else "cave")
	print("WONDER cave %d %s at %s floor %.1f: %d meshes, %d fires, %d lights, %d chests" % [i, String(NAMES[i]), Vector2(d.o.x, d.o.z), d.yf, n, d.k.fires, d.k.lights, d.k.chests])
	return true


## The mouth's two flanking boulders (real rocks, with collision: never cached, built each time).
func _boulders(d, i: int) -> void:
	for s: float in [-1.0, 1.0]:
		var p: Vector3 = d.o + d.side * (s * 4.2) + d.fwd * 1.5
		var mesh := RockKit.boulder(i * 2 + int(s > 0.0), Vector3(4.6, 3.4, 3.8), "mossy")
		RockKit.spawn(d.k.host, mesh, Transform3D(Basis(Vector3.UP, float(i) + s), Vector3(p.x, WK.h(p.x, p.z) - 0.3, p.z)))


## The mouth's rubble and hanging moss (kit geometry: cached with the rest).
func _mouth(d, _i: int) -> void:
	Dress.rubble(d.k, d.o + d.fwd * -2.0, 3.0, 10, "cave")
	Dress.strands(d.k, d.o + d.side * -3.0 + Vector3.UP * 0.2, d.o + d.side * 3.0 + Vector3.UP * 0.2, 8, 0.8, "cave_moss")


func _stalks(d, rooms: Array, n: int) -> void:
	var rng: RandomNumberGenerator = d.k.rng
	for r: Array in rooms:
		var u0: float = r[0]
		var u1: float = r[1]
		var v0: float = r[2]
		var v1: float = r[3]
		var h: float = r[4]
		for j in n:
			var u := rng.randf_range(u0 + 0.8, u1 - 0.8)
			var v := rng.randf_range(v0 + 0.8, v1 - 0.8)
			var l := rng.randf_range(0.8, 2.4)
			d.k.tube("cave", d.p(u, h, v), d.p(u + rng.randf_range(-0.1, 0.1), h - l, v), 0.28 * l * 0.5 + 0.08, 0.02, 5, false, rng.randf_range(0.7, 1.0))
			if rng.randf() < 0.6:
				var l2 := rng.randf_range(0.4, 1.4)
				d.k.tube("cave", d.p(u + 0.8, 0.0, v + 0.5), d.p(u + 0.8, l2, v + 0.5), 0.3, 0.03, 5, false, rng.randf_range(0.7, 1.0))


func _crystals(d, cols: Array, n: int, lamps: int) -> void:
	var rng: RandomNumberGenerator = d.k.rng
	for j in n:
		var c: Vector3 = d.p(rng.randf_range(-4.5, 4.5), 0.0, rng.randf_range(26.5, 35.0))
		var l := rng.randf_range(0.8, 2.4)
		var tilt := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		d.k.tube("crystal", c, c + Vector3.UP * l + tilt, 0.22 + 0.06 * l, 0.02, 6, false, 0.95)
		if j % 3 == 0:
			d.k.kit.box("glow", c + Vector3.UP * (l * 0.5) + tilt * 0.5, Vector3(0.1, l * 0.6, 0.1), d.basis(), false, 0.9)
	for j in lamps:
		d.k.lamp(d.p(-3.0 + 3.0 * float(j), 1.6, 30.5 + float(j % 2) * 2.0), Color(0.6, 0.8, 1.0), 1.2, 8.0)


func _dress(d, i: int) -> void:
	var rng: RandomNumberGenerator = d.k.rng
	_stalks(d, [[-8.0, 8.0, 9.8, 25.0, 5.6], [-4.5, 4.5, 0.0, 9.0, 4.4], [-5.5, 5.5, 25.8, 36.0, 5.2]], 7)
	d.lamp(0.0, 3.0, 4.0, 0.9, 8.0)
	d.lamp(0.0, 3.4, 17.0, 1.0, 10.0)
	# a pool in the middle chamber (shallow, still), with stepping stones across it
	if i != 3:
		d.water(-5.0, 5.0, 12.0, 22.0, 0.35)
		for j in 5:
			d.k.kit.box("cave", d.p(rng.randf_range(-1.2, 1.2), 0.2, 11.0 + 2.3 * float(j)), Vector3(1.2, 0.5, 1.0), Basis(Vector3.UP, rng.randf() * TAU), true, 0.85)
	var find_pos: Vector3 = d.p(0.0, 0.0, 33.0)
	var loot := {"grave_ash": 12 + i, "grave_iron": 1 + i % 2}
	if i in [0, 5]:
		loot["relic_fragment"] = 1
	match i:
		0:
			_crystals(d, [], 22, 3)
			d.k.kit.box("crystal", find_pos + Vector3.UP * 0.2, Vector3(2.4, 0.4, 2.0), d.basis(), true, 0.95)
		1:
			for j in 12:
				d.k.tube("bark", d.p(rng.randf_range(-7.0, 7.0), 5.6, rng.randf_range(10.0, 25.0)), d.p(rng.randf_range(-7.5, 7.5), 2.0, rng.randf_range(10.0, 25.0)), 0.3, 0.05, 5, false, 0.7)
			Dress.strands(d.k, d.p(-7.0, 5.5, 12.0), d.p(7.0, 5.5, 24.0), 14, 3.0, "bark")
			Dress.camp(d.k, d.p(4.5, 0.0, 15.0), 0.6)
			d.k.chest("cave_1_pack", "wood", d.p(5.5, 0.1, 13.6), 0.0, {"grave_ash": 8, "grave_iron": 1})
		2:
			for j in 20:
				var q: Vector3 = d.p(rng.randf_range(-7.0, 7.0), 5.5, rng.randf_range(10.5, 24.5))
				d.k.tube("cave", q, q + Vector3.DOWN * rng.randf_range(0.6, 1.2), 0.18, 0.1, 5, false, 0.55)
			Dress.rubble(d.k, d.p(-6.0, 0.0, 23.0), 2.5, 14, "cave")
			Dress.rubble(d.k, d.p(3.0, 0.0, 28.0), 2.0, 10, "cave")
		3:
			d.water(-4.5, 4.5, 0.0, 9.0, 0.5)
			d.water(-8.0, 8.0, 9.8, 25.0, 0.5)
			d.water(-5.5, 5.5, 25.8, 36.0, 0.5)
			for j in 14:
				d.k.kit.box("cave", d.p(0.5 * sin(float(j)), 0.3, 2.0 + 2.4 * float(j)), Vector3(1.3, 0.8, 1.2), Basis(Vector3.UP, float(j)), true, 0.85)
			d.k.kit.box("cave", find_pos + Vector3.UP * 0.4, Vector3(3.0, 0.9, 2.6), d.basis(), true, 0.9)
		4:
			for j in 16:
				var q: Vector3 = d.p(-7.8 if j % 2 == 0 else 7.8, 0.6 + 3.5 * rng.randf(), 10.5 + 14.0 * rng.randf())
				d.k.kit.box("glow", q, Vector3(0.1, 0.9 + rng.randf(), 1.4), d.basis(), false, 0.9)
			d.k.fire(d.p(-4.0, 0.4, 15.0), 0.9, 1.8)
			d.k.fire(d.p(4.0, 0.4, 20.0), 0.9, 1.8)
			for j in 5:
				var cp: Vector3 = d.p(-3.0 + 1.5 * float(j), 0.0, 27.0 + rng.randf() * 7.0)
				d.k.tube("dark", cp, cp + Vector3.UP * rng.randf_range(2.0, 4.5), 0.5, 0.45, 6, true, 0.6)
			d.k.kit.box("cave", find_pos + Vector3.UP * 0.5, Vector3(2.6, 1.0, 2.2), d.basis(), true, 0.9)
		5:
			for j in 60:
				var q: Vector3 = d.p(rng.randf_range(-7.0, 7.0), 0.15 + 0.4 * rng.randf(), rng.randf_range(10.5, 24.5))
				d.k.kit.skull(q, rng.randf() * TAU, rng.randf_range(0.8, 1.1), rng.randi() % 2, rng.randf_range(-0.4, 0.4))
				if j % 3 == 0:
					d.k.kit.bone(q, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, 1.4), rng.randi() % 3, false)
			d.k.kit.box("wax", d.p(0.0, 0.3, 30.0), Vector3(3.6, 0.5, 2.6), d.basis(), false, 0.7)
			d.k.fire(d.p(-3.0, 0.2, 14.0), 0.7, 1.4)
		_:
			for j in 18:
				var u := rng.randf_range(-7.4, 7.4)
				var v := rng.randf_range(10.5, 24.5)
				d.k.kit.box("chalk", d.p(u, 0.2 + 0.2 * rng.randf(), v), Vector3(0.9, 0.12, 0.7), Basis(Vector3.UP, rng.randf() * TAU), false, 0.9)
				d.k.tube("chalk", d.p(u, 0.0, v), d.p(u, 0.5, v), 0.06, 0.05, 5, false, 0.9)
				d.k.kit.box("glow", d.p(u, 0.55, v), Vector3(0.22, 0.12, 0.22), d.basis(), false, 0.8)
			d.k.lamp(d.p(0.0, 1.4, 17.0), Color(0.5, 0.95, 0.8), 1.2, 10.0)
			for j in 8:
				var a := TAU * float(j) / 8.0
				d.k.kit.box("chalk", find_pos + Vector3(cos(a) * 2.4, 0.3, sin(a) * 2.4), Vector3(0.8, 0.14, 0.6), Basis(Vector3.UP, a), false, 0.9)
	d.k.chest("cave_%d_find" % i, "iron", find_pos + Vector3(0.0, 1.0 if i in [0, 3, 4] else 0.1, 0.0), atan2(-d.fwd.x, -d.fwd.z), loot)
	d.lamp(0.0, 3.8, 32.0, 1.0, 9.0)

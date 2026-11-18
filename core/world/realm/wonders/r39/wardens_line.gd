extends RefCounted
## THE WARDENS' LINE (the world pass): six beacon towers a hundred metres apart along the Pilgrims' Road, west to east. Lore:
## the Order's wardens kept the road lit tower to tower, so no pilgrim walked a night in the dark; when the wardens
## were gone the fires went out one by one and the line went dark from the west. The wanderer can light it again.
## Each tower is a stout 10 m keep, 12 m to the roof, built of the Order's big masonry:
##   - a plinth and a door in the west wall (turned to face the road) with a small fire by it, lit slit windows
##   - inside: a hall with a chest, a lamp, and a square stair of four flights wound round the walls
##   - on the roof (a crenellated deck): a cresset that is COLD until the wanderer lights it (E; wardens_cresset.gd):
##     the flame, the warm lights and the far beacon come on, for good (saved); a cold pilot glow shows until then
##   - lighting all six pays out once (ash, iron, relic fragments) and is told in a toast
## Placed by WK.find on the flattest open ground 30-45 m north or south of the road at each station; every tower
## reserves its ground. Built once; the unlit tower costs a few meshes and one pilot light that fades with distance.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Cresset := preload("res://core/world/realm/wonders/r39/wardens_cresset.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

const STATIONS := [-338.0, -232.0, -128.0, 124.0, 226.0, 330.0]
const ALLOW := ["lanternwood", "kingsbarrows", "greyfell", "lastlight", "nave", "bellfall", "weirford", "sorrow", "downs"]
const SELF := "res://core/world/realm/wonders/r39/wardens_line.gd"
const HI := 4.3                      ## the hall's half width
const WALL := 0.9

var k: WK
var mid := Vector3.ZERO
var rot := Basis.IDENTITY
var y0 := 0.0
var _gmin := 0.0


static func build(root: Node) -> void:
	var w := new()
	w._run(root)


func _w(x: float, y: float, z: float) -> Vector3:
	return mid + rot * Vector3(x, y, z) + Vector3(0.0, y0, 0.0)


func _blk(key: String, x0: float, x1: float, z0: float, z1: float, y_lo: float, y_hi: float, shade := 1.0, solid := true) -> void:
	k.kit.box(key, _w((x0 + x1) * 0.5, (y_lo + y_hi) * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, y_hi - y_lo, z1 - z0), rot, solid, shade)


func _run(root: Node) -> void:
	var placed := 0
	var meshes := 0
	var fires := 0
	var lights := 0
	for i in STATIONS.size():
		var x: float = STATIONS[i]
		var f := WK.place([Vector2(x, 26.0), Vector2(x, 104.0), Vector2(x, 14.0), Vector2(x, 116.0)], Vector2(8.0, 8.0), [0.0], 2.5, 16.0)
		if bool(f.get("site", true)):
			print("WONDER wardens_line: tower %d has no clean ground: not placed" % (i + 1))
			continue
		var c: Vector2 = f.pos
		WorldLanes.register_terrace("wonder_wardens_%d" % (i + 1), c, 9.0, (float(f.lo) + float(f.hi)) * 0.5)
		k = WK.new()                                   # one kit (one set of meshes) per tower: each culls on its own
		k.setup(root, "WardensTower%d" % (i + 1), 6101 + i)
		k.poi("wardens_tower_%d" % (i + 1), "The Wardens' Line", "tower %d of six, dark since the west went out" % (i + 1), WK.region_at(c) if WK.region_at(c) != "" else "road")
		var lv := (float(f.lo) + float(f.hi)) * 0.5
		_tower(i + 1, c, lv, lv)
		var tp: Array[Vector3] = [_w(-4.0, 0.2, -4.0), _w(4.0, 11.0, -4.0), _w(-4.0, 11.0, 4.0), _w(4.0, 0.2, 4.0)]
		WK.acoustic(tp, "hall", "tower")
		meshes += k.commit(0.0)
		k.far(150.0, 0.08)
		fires += k.fires
		lights += k.lights
		placed += 1
	print("WONDER wardens_line: %d of %d towers, %d meshes, %d fires, %d lights" % [placed, STATIONS.size(), meshes, fires, lights])


func _tower(no: int, c: Vector2, glo: float, ghi: float) -> void:
	var to_road := Vector2(0.0, signf(62.0 - c.y))
	var a := atan2(to_road.y, -to_road.x)                     # local -x faces the road
	rot = Basis(Vector3.UP, a)
	mid = Vector3(c.x, 0.0, c.y)
	y0 = ghi + 0.25
	_gmin = glo
	var fl := 0.3
	var low := glo - 0.9
	var rise := 2.75
	var dk := fl + 4.0 * rise
	if not k.cached(WK.fp(SELF, [mid, a, y0, no, WK.tsig(c, 14.0)])):
		# the plinth (its top is the hall's floor), a thin floor slab, the four walls (the west one with the door z 0..1.6, 2.9 m high)
		k.kit.box("stone_big", Vector3(mid.x, (low + y0 + fl - 0.04) * 0.5, mid.z), Vector3(11.8, y0 + fl - 0.04 - low, 11.8), rot, true, 0.86)
		_blk("floor", -HI, HI, -HI, HI, fl - 0.04, fl, 0.9)
		var top := 12.5
		_blk("stone_big", -HI - WALL, -HI, -HI - WALL, 0.0, fl, top, 1.0)
		_blk("stone_big", -HI - WALL, -HI, 1.6, HI + WALL, fl, top, 1.0)
		_blk("stone_big", -HI - WALL, -HI, 0.0, 1.6, 2.9, top, 0.96)
		_blk("stone_big", HI, HI + WALL, -HI - WALL, HI + WALL, fl, top, 1.0)
		_blk("stone_big", -HI, HI, -HI - WALL, -HI, fl, top, 1.0)
		_blk("stone_big", -HI, HI, HI, HI + WALL, fl, top, 1.0)
		_blk("ruin_big", -HI - WALL - 0.25, HI + WALL + 0.25, -HI - WALL - 0.25, HI + WALL + 0.25, 11.0, 11.5, 0.84)     # a string course
		# the stair: four flights round the walls, corner landings, the roof deck with the well open over the climb
		_flight(Vector3(-2.5, fl, -3.4), Vector3(2.5, fl + rise, -3.4), 1.8)
		_blk("stone_big", 2.5, HI, -HI, -2.5, fl, fl + rise, 0.95)
		_flight(Vector3(3.4, fl + rise, -2.5), Vector3(3.4, fl + 2.0 * rise, 2.5), 1.8)
		_blk("stone_big", 2.5, HI, 2.5, HI, fl, fl + 2.0 * rise, 0.95)
		_flight(Vector3(2.5, fl + 2.0 * rise, 3.4), Vector3(-2.5, fl + 3.0 * rise, 3.4), 1.8, fl + 2.0 * rise - 0.6)
		_blk("stone_big", -HI, -2.5, 2.5, HI, fl, fl + 3.0 * rise, 0.95)
		_flight(Vector3(-3.4, fl + 3.0 * rise, 2.5), Vector3(-3.4, fl + 4.0 * rise, -2.5), 1.8, fl + 3.0 * rise - 0.6)     # (open beneath: the door is under it)
		_blk("stone_big", -2.5, HI, -HI, HI, dk - 0.7, dk, 0.94)
		_blk("stone_big", -HI, -2.5, -HI, -2.5, dk - 0.7, dk, 0.94)
		# the parapet merlons on the wall tops, corner posts
		for s: float in [-1.0, 1.0]:
			for q in 5:
				var t := -3.9 + 1.95 * float(q)
				_blk("stone_big", t - 0.7, t + 0.7, s * (HI + WALL * 0.5) - 0.45, s * (HI + WALL * 0.5) + 0.45, top, top + 1.1, 0.98)
				_blk("stone_big", s * (HI + WALL * 0.5) - 0.45, s * (HI + WALL * 0.5) + 0.45, t - 0.7, t + 0.7, top, top + 1.1, 0.98)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				_blk("stone_big", sx * (HI + WALL * 0.5) - 0.7, sx * (HI + WALL * 0.5) + 0.7, sz * (HI + WALL * 0.5) - 0.7, sz * (HI + WALL * 0.5) + 0.7, top, top + 1.8, 0.9)
		# windows: lit slits on all four faces at two heights, a lamp in the hall, a fire by the door
		var ex := rot * Vector3(1.0, 0.0, 0.0)
		var ez := rot * Vector3(0.0, 0.0, 1.0)
		var e := HI + WALL + 0.01
		for y: float in [4.3, 7.9]:
			var o := 1.9 if y < 6.0 else -1.9
			k.window(_w(o, y, -e), ex, -ez, 0.8, 1.7)
			k.window(_w(-o, y, e), ex, ez, 0.8, 1.7)
			k.window(_w(e, y, o), ez, ex, 0.8, 1.7)
			k.window(_w(-e, y, -2.6 if y < 6.0 else 3.0), ez, -ex, 0.8, 1.7)
		k.lamp(_w(0.0, 3.0, 0.0), Color(1.0, 0.66, 0.36), 1.1, 9.0)
		k.lamp(_w(-HI - WALL - 1.6, 2.4, 0.8), Color(1.0, 0.66, 0.36), 1.2, 8.0)
		k.fire(_w(-HI - WALL - 1.3, 0.7, 2.6), 0.55, 1.5, false)
		k.kit.box("iron", _w(-HI - WALL - 1.3, 0.3, 2.6), Vector3(0.7, 0.6, 0.7), rot, true, 0.7)
		k.kit.box("iron", _w(-HI - WALL - 1.3, 0.3, -1.0), Vector3(0.7, 0.6, 0.7), rot, true, 0.7)
		k.fire(_w(-HI - WALL - 1.3, 0.7, -1.0), 0.55, 1.5, false)
		# the stair outside the door, from the ground up to the sill
		var door_out := rot * Vector3(-1.0, 0.0, 0.0)
		var g0 := WK.h(mid.x + door_out.x * 8.0, mid.z + door_out.z * 8.0)
		var steps := maxi(2, int(ceilf((y0 + fl - g0 + 0.2) / 0.34)))
		var run := maxf(2.4, float(steps) * 0.9)
		var sill := _w(-HI - WALL, fl, 0.8)
		var far := Vector3(sill.x + door_out.x * run, 0.0, sill.z + door_out.z * run)
		var gf := WK.h(far.x, far.z)
		k.kit.stairs("stone_big", Vector3(far.x, gf - 0.15, far.z), sill, 2.4, maxi(2, int(ceilf((y0 + fl - gf + 0.15) / 0.34))), gf - 1.6)
		# a chest in the hall (the sixth tower's is the reliquary)
		var tier := "reliquary" if no == 6 else "wood"
		var loot := {"grave_ash": 22, "grave_iron": 3, "relic_fragment": 2} if no == 6 else {"grave_ash": 7 + no, "grave_iron": 1}
		k.chest("wardens_tower_%d" % no, tier, _w(-1.5, fl, -1.4), a, loot)
		# the cresset on the roof: an iron tripod and basin (its flame is hidden until lit, a cold pilot glow shows until then)
		var cc0 := _w(0.0, dk, 0.0)
		k.kit.box("iron", cc0 + Vector3.UP * 0.5, Vector3(1.6, 1.0, 1.6), rot, true, 0.7)
		k.kit.box("dark", cc0 + Vector3.UP * 1.02, Vector3(1.9, 0.14, 1.9), rot, false, 0.5)
		for i in 3:
			var ang := float(i) * TAU / 3.0
			k.tube("iron", cc0 + Vector3(cos(ang) * 1.0, 0.0, sin(ang) * 1.0), cc0 + Vector3(cos(ang) * 0.5, 1.05, sin(ang) * 0.5), 0.1, 0.1, 4, false, 0.6)
		_dress(no)
	# the cresset's own nodes (never cached: they are toggled and saved by the player's lighting)
	var cc := _w(0.0, dk, 0.0)
	var flames: Array[Node3D] = k.fire(cc + Vector3.UP * 1.1, 2.8, 4.6, true, true)
	var pilot: OmniLight3D = k.lamp(cc + Vector3.UP * 1.6, Color(0.55, 0.75, 1.0), 0.8, 8.0, true)
	var pg := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.radial_segments = 8
	sm.rings = 4
	pg.mesh = sm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.55, 0.78, 1.0)
	gm.emission_enabled = true
	gm.emission = Color(0.5, 0.75, 1.0)
	gm.emission_energy_multiplier = 0.9
	pg.material_override = gm
	pg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.host.add_child(pg)
	pg.position = cc + Vector3.UP * 1.4
	var cr: Node3D = Cresset.new()
	cr.name = "Cresset_%d" % no
	cr.set("tower_id", "tower_%d" % no)
	cr.set("tower_no", no)
	cr.set("total", STATIONS.size())
	cr.set("flames", flames)
	var cold: Array[Node3D] = [pilot, pg]
	cr.set("cold", cold)
	cr.set("beacon_at", cc + Vector3.UP * 2.0)
	cr.set("beacon_parent", k.host)
	k.host.add_child(cr)
	cr.position = cc + Vector3.UP * 1.0


func _flight(lo: Vector3, hi: Vector3, width: float, base_rel := 0.3) -> void:
	var a := _w(lo.x, lo.y, lo.z)
	var b := _w(hi.x, hi.y, hi.z)
	var steps := maxi(3, int(ceilf(absf(hi.y - lo.y) / 0.36)))
	k.kit.stairs("stone_big", a, b, width, steps, y0 + base_rel)


# --- secondary forms -----------------------------------------------------------------------------------

func _dress(no: int) -> void:
	var ex := rot * Vector3(1.0, 0.0, 0.0)
	var ez := rot * Vector3(0.0, 0.0, 1.0)
	var e := HI + WALL + 0.15
	Dress.banner(k, _w(2.0, 10.5, -e), ex, 2.0, 5.0, -ez)
	Dress.banner(k, _w(-3.5, 10.0, e), ex, 2.0, 4.5, ez)
	Dress.banner(k, _w(e, 10.2, -1.0), ez, 2.0, 4.8, ex)
	Dress.chain(k, _w(-HI - WALL - 0.2, 4.5, -1.2), _w(-HI - WALL - 0.2, 4.5, 2.4), 0.5)
	Dress.rubble(k, _w(-8.0, 0.4, -6.0), 3.4, 12, "ruin_big")
	Dress.rubble(k, _w(7.5, 0.4, 7.0), 3.0, 10, "ruin_big")
	Dress.barrel(k, _w(-HI - WALL - 2.4, 0.3, -3.0), 0.0, 1.0)
	Dress.crate(k, _w(-HI - WALL - 2.6, 0.3, 4.6), 0.3, 0.9)
	Dress.strands(k, _w(-5.0, 12.4, e), _w(5.0, 12.4, e), 6, 4.0)
	Dress.strands(k, _w(e, 12.4, -5.0), _w(e, 12.4, 5.0), 6, 3.5)
	Dress.crack(k, _w(-5.2, 3.0, -4.0), _w(-5.2, 9.0, -1.0), 0.14)
	Dress.carved_band(k, _w(-5.0, 11.2, -e - 0.1), _w(5.0, 11.2, -e - 0.1), 8, Vector3(1.0, 0.45, 0.3))
	if no == 6:
		Dress.camp(k, _w(-HI - WALL - 4.5, 0.3, 0.4), 0.0)

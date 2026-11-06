extends RefCounted
## The rift's west rim (secrets): three linked places of the Order's bell-founders.
##   bells   THE FALLEN BELLS: a collapsed bell tower on the rim's berm, its three bells (Hope,
##           Patience, Homecoming) thrown down round it. Strike them from the bottom up (great,
##           middle, treble) and they answer; the Founder's coffer opens and, far off, the sealed
##           barrow in the Barrow Field grinds open (site_barrow).
##   spill   THE FOUNDER'S SPILL: a hidden stair from the berm top down the rift wall to a ledge
##           walk, behind a curtain of molten rock poured from the cracked furnace's spout, to a niche.
##   bridge  THE RIM BRIDGE: a rope bridge from the ledge's south end over the rim slope to a
##           landing near the Last Bell. It hangs cut loose until wound out from the ledge side;
##           then it stays: a shortcut from the rift rim to the ledge and the berm.
## Stays off the Crossing (>= 9 m west of its nearest site) and off RealmLayout.PATHS.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")

const TOWER := Vector2(-34.6, -27.0)
const BELLS := [
	# id, name, position xz, size, tilt basis euler (deg), tone
	["great", "Homecoming", Vector2(-38.9, -23.0), 1.45, Vector3(78, 20, 0), "bell_great"],
	["middle", "Patience", Vector2(-40.3, -29.4), 1.05, Vector3(-70, 130, 8), "bell_middle"],
	["treble", "Hope", Vector2(-37.4, -32.4), 0.72, Vector3(172, 40, 0), "bell_treble"],
]
const ORDER := ["great", "middle", "treble"]
const WALK_X := -26.3            ## the ledge walk's centre line
const WALK_W := 2.2
const WALK_Z0 := -21.2           ## south end (bridge anchor), clear of the rift fall at z -19
const WALK_Z1 := -31.0           ## north end, past the stair foot (the z -38 fall stays clear)
const SPOUT_Z := -23.6
const STAIR_TOP := Vector2(-34.6, -35.8)
const LANDING := Vector2(-23.6, -4.6)

static var _seq: Array[String] = []
static var _seq_t := 0.0
static var walk_y := 4.5


static func build(root: Node, host: Node3D) -> void:
	# a fresh build is a cold one: puzzle progress that is not the save does not outlive its night
	_seq.clear()
	_seq_t = 0.0
	var sp := Kit.space(root)
	Kit.clear_flora(root, [Vector3(TOWER.x - 2.0, TOWER.y, 9.5), Vector3(-30.5, -31.0, 7.5), Vector3(-27.0, -22.0, 7.0),
		Vector3(LANDING.x, LANDING.y, 3.5), Vector3(-25.0, -11.0, 5.0)])
	var node := Node3D.new()
	node.name = "Rim"
	node.set_meta("site", "secrets_rim")
	host.add_child(node)
	_bells(node, sp)
	_ledge(node, sp)
	_bridge(node, sp)
	Kit.site(root, "secrets_bells", Rect2(TOWER.x - 2.6, TOWER.y - 2.6, 5.2, 5.2), Kit.low(sp, TOWER, 2.4))
	Kit.site(root, "secrets_ledge", Rect2(WALK_X - 1.4, WALK_Z1, 2.8, WALK_Z0 - WALK_Z1), walk_y)
	Kit.site(root, "secrets_rim_landing", Rect2(LANDING.x - 1.5, LANDING.y - 1.6, 3.0, 3.0), Kit.low(sp, LANDING, 1.6) + 0.1)


# --- the fallen bells -------------------------------------------------------------------------------

static func _bells(node: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	var fy := Kit.low(sp, TOWER, 2.4) + 0.05
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var h := 2.3
	k.block("stone", Vector3(TOWER.x - h, fy - 1.0, TOWER.y - h), Vector3(TOWER.x + h, fy + 0.12, TOWER.y + h), true, 0.8)
	# walls as piers of broken height: west (door), north, south tall; east thrown down
	var walls := [[Vector3(-1, 0, 0), 5.6, true], [Vector3(0, 0, -1), 6.4, false], [Vector3(0, 0, 1), 4.6, false], [Vector3(1, 0, 0), 1.3, false]]
	for wd: Array in walls:
		var n: Vector3 = wd[0]
		var tall: float = wd[1]
		var door: bool = wd[2]
		var along := n.cross(Vector3.UP)
		var c := Vector3(TOWER.x, fy, TOWER.y) + n * (h - 0.35)
		var pieces := 6
		for i in pieces:
			var t := (float(i) + 0.5) / float(pieces) - 0.5
			if door and absf(t) < 0.2:
				continue
			var hh := tall * rng.randf_range(0.55, 1.0) * (1.0 - absf(t) * 0.35 if not door else 1.0)
			if n.x > 0.5:
				hh = rng.randf_range(0.5, tall)
			var pc := c + along * (t * h * 2.0) + Vector3.UP * (hh * 0.5)
			k.box("stone", pc, Vector3(h * 2.0 / float(pieces) + 0.02, hh, 0.7), Basis(along, Vector3.UP, n), true, rng.randf_range(0.82, 1.0))
		if door:
			# lintel over the doorway, cracked
			k.box("stone", c + Vector3.UP * 2.55, Vector3(1.9, 0.4, 0.8), Basis(along, Vector3.UP, n).rotated(n, 0.06), true, 0.9)
	# string course and corner quoins on the standing corners
	for s: Vector2 in [Vector2(-1, -1), Vector2(-1, 1)]:
		var q := Vector3(TOWER.x + s.x * (h - 0.1), fy, TOWER.y + s.y * (h - 0.1))
		for j in 6:
			k.box("stone", q + Vector3.UP * (0.45 + j * 0.8), Vector3(0.62 if j % 2 == 0 else 0.48, 0.38, 0.62 if j % 2 == 1 else 0.48), Basis.IDENTITY, true, 0.92)
	# rubble thrown east toward the rift and round the base
	for i in 26:
		var a := rng.randf_range(-1.2, 1.2) if i < 18 else rng.randf() * TAU
		var d := rng.randf_range(2.6, 5.5)
		var p2 := TOWER + Vector2(cos(a), sin(a)) * d
		var g := Kit.gy(sp, p2.x, p2.y)
		var sz := Vector3(rng.randf_range(0.4, 0.9), rng.randf_range(0.25, 0.5), rng.randf_range(0.3, 0.6))
		k.box("stone", Vector3(p2.x, g + sz.y * 0.3, p2.y), sz, Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))), i % 3 == 0, rng.randf_range(0.7, 0.95))
	# the broken bell-frame: a fallen headstock beam and two snapped uprights
	var fb := Vector2(-36.9, -26.2)
	var gb := Kit.gy(sp, fb.x, fb.y)
	k.box("wood", Vector3(fb.x, gb + 0.22, fb.y), Vector3(3.4, 0.36, 0.38), Basis(Vector3.UP, 0.5).rotated(Vector3.FORWARD, 0.05), true, 0.85)
	k.box("wood", Vector3(fb.x - 1.2, gb + 0.7, fb.y + 1.1), Vector3(0.3, 1.4, 0.3), Basis(Vector3.UP, 0.2).rotated(Vector3.RIGHT, 0.35), true, 0.8)
	k.box("wood", Vector3(fb.x + 1.0, gb + 0.4, fb.y - 1.3), Vector3(0.3, 0.8, 0.3), Basis(Vector3.UP, 0.9).rotated(Vector3.FORWARD, 0.6), true, 0.8)
	k.box("iron", Vector3(fb.x + 0.1, gb + 0.42, fb.y - 0.05), Vector3(0.6, 0.08, 0.42), Basis(Vector3.UP, 0.5), false, 0.7)
	# the Founder's coffer, inside against the north wall
	var cof := Vector3(TOWER.x - 0.5, fy + 0.12, TOWER.y - 1.2)
	k.box("wood", cof + Vector3.UP * 0.28, Vector3(1.0, 0.56, 0.62), Basis.IDENTITY, true, 0.75)
	k.box("iron", cof + Vector3.UP * 0.3, Vector3(1.04, 0.07, 0.66), Basis.IDENTITY, false, 0.8)
	k.commit(node, "BellsBody")
	_fade(node, 110.0)
	var lid := Kit.mi(node, _box_mesh(Vector3(1.04, 0.12, 0.66)), OssKit.mat("wood"), Transform3D(Basis.IDENTITY, cof + Vector3.UP * 0.62), 70.0)
	var sync_lid := func(animate: bool) -> void:
		if State.has("looted", "bells"):
			var to := Transform3D(Basis(Vector3.RIGHT, -1.9), cof + Vector3(0, 0.62, -0.36))
			if animate:
				lid.create_tween().tween_property(lid, "global_transform", to, 0.8)
			else:
				lid.global_transform = to
	State.cache(node, "bells", cof + Vector3.UP * 0.6, "the Founder's coffer", sync_lid, func() -> bool: return State.has("solved", "bells"))
	State.reading(node, "sc_bells", Vector3(fb.x, gb + 0.5, fb.y))
	State.reading(node, "sc_founder", cof + Vector3(0.6, 0.7, 0.0), "Read")
	# the bells
	for b: Array in BELLS:
		var p: Vector2 = b[2]
		var size: float = b[3]
		var g := Kit.gy(sp, p.x, p.y)
		var e: Vector3 = b[4]
		var bas := Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
		var centre := Vector3(p.x, g + size * 0.36, p.y)
		var xf := Transform3D(bas, centre - bas * Vector3(0, -size * 0.5, 0))
		var bell := Kit.mi(node, Kit.bell_mesh(size, hash(b[0]) % 97), Kit.mat("bronze"), xf, 80.0)
		bell.name = "Bell_" + String(b[0])
		Kit.box_body(node, centre, Vector3(size * 1.1, size * 0.7, size * 1.1), Basis(Vector3.UP, deg_to_rad(e.y)))
		var bid: String = b[0]
		var tone: String = b[5]
		var t := Kit.touch(node, centre + Vector3.UP * 0.3, "Strike %s, the %s bell" % [b[1], bid], func(_by: Node) -> void: strike(bid, tone, bell), 2.6)
		t.name = "Strike_" + bid
	var heart := Vector3(TOWER.x - 2.5, fy, TOWER.y)
	State.register({"id": "bells", "name": "The Fallen Bells", "at": heart, "r": 9.0, "node": node,
		"route": {"from": Vector3(-8.0, 1.0, 2.0), "pts": _v3([Vector2(-20, 1), Vector2(-30, -2), Vector2(-35, -9), Vector2(-37.5, -17), Vector2(-37.6, -25.6)])},
		"goal": Vector3(-37.6, 0, -25.6)})


static func strike(id: String, tone: String, bell: Node3D) -> void:
	var at := bell.global_position
	Kit.play(tone, at, 2.0)
	if bell.is_inside_tree():
		var tw := bell.create_tween()
		var b0 := bell.global_transform
		tw.tween_property(bell, "global_transform", b0.rotated_local(Vector3.FORWARD, 0.04), 0.06)
		tw.tween_property(bell, "global_transform", b0, 0.3).set_trans(Tween.TRANS_ELASTIC)
		Kit.fx_dust(at, Color(0.5, 0.5, 0.45, 0.5), 10)
	if State.has("solved", "bells"):
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _seq_t > 30.0:
		_seq.clear()
	_seq_t = now
	_seq.append(id)
	var want: String = ORDER[_seq.size() - 1]
	if id != want:
		_seq.clear()
		if id == ORDER[0]:
			_seq.append(id)          # a wrong run, but the great bell starts a new one
			return
		Kit.play("clank", at, -2.0)
		State.toast("The note dies flat against the others.")
		return
	if _seq.size() < ORDER.size():
		return
	_seq.clear()
	State.mark("solved", "bells")
	Kit.play("bell_chord", at, 4.0)
	State.toast("From the bottom up. Far off, in the Barrow Field, stone grinds on stone.")
	State.banner("the bells ring up", "The Fallen Bells")
	State.refresh(true)


# --- the ledge walk, the spout, the stair, the niche -----------------------------------------------

static func _ledge(node: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	var xin := WALK_X - WALK_W * 0.5
	var xout := WALK_X + WALK_W * 0.5
	# the walk is level, just above the highest ground under its inner edge
	var wy := -INF
	var z := WALK_Z0
	while z >= WALK_Z1:
		wy = maxf(wy, Kit.gy(sp, xin - 0.2, z))
		z -= 0.5
	wy += 0.15
	walk_y = wy
	var len := WALK_Z0 - WALK_Z1
	var zc := (WALK_Z0 + WALK_Z1) * 0.5
	# deck of big flags on a retaining wall, corbels under the outer edge
	var nflags := int(len / 1.1)
	for i in nflags:
		var zz := WALK_Z0 - (float(i) + 0.5) * len / float(nflags)
		k.box("stone", Vector3(WALK_X, wy - 0.12, zz), Vector3(WALK_W, 0.24, len / float(nflags) - 0.03), Basis.IDENTITY, true, 0.86 + 0.1 * float(i % 3) / 2.0)
	var zstep := 1.6
	z = WALK_Z0 - 0.3
	while z > WALK_Z1:
		var gout := Kit.gy(sp, xout, z)
		var bot := minf(gout, Kit.gy(sp, xout - 0.6, z)) - 0.6
		k.box("stone", Vector3(xout - 0.35, (wy - 0.24 + bot) * 0.5, z - zstep * 0.5), Vector3(0.75, wy - 0.24 - bot, zstep - 0.04), Basis.IDENTITY, true, 0.8)
		k.box("dark", Vector3(xout + 0.05, wy - 0.42, z - zstep * 0.5), Vector3(0.36, 0.3, 0.5), Basis.IDENTITY, false, 0.8)
		z -= zstep
	# outer kerb (low parapet) with an invisible rail above it, open at the bridge's south end
	k.box("stone", Vector3(xout - 0.12, wy + 0.25, zc - 0.9), Vector3(0.28, 0.5, len - 1.8), Basis.IDENTITY, true, 0.9)
	Kit.box_body(node, Vector3(xout - 0.12, wy + 1.0, zc - 0.9), Vector3(0.3, 1.6, len - 1.8))
	# end wall at the north, past the stair foot
	k.box("stone", Vector3(WALK_X, wy + 0.8, WALK_Z1 - 0.3), Vector3(WALK_W + 0.4, 1.6, 0.6), Basis.IDENTITY, true, 0.85)
	# inner face: a revetment hiding the cut, and the niche under the spout
	z = WALK_Z0
	while z > WALK_Z1:
		if absf(z - 0.8 - SPOUT_Z) > 1.6:
			var gin := Kit.gy(sp, xin - 0.5, z - 0.8)
			var top := maxf(gin + 0.3, wy + 0.6)
			k.box("stone", Vector3(xin - 0.15, (wy - 0.2 + top) * 0.5, z - 0.8), Vector3(0.4, top - wy + 0.2, 1.6), Basis.IDENTITY, true, 0.78)
		z -= 1.6
	var nb := Vector3(xin - 0.55, wy, SPOUT_Z)
	k.arch_panel("stone", Vector3(xin - 0.15, wy, SPOUT_Z), Vector3(0, 0, 1), 1.6, 1.4, 2.8, 0.45, 0.7)
	k.box("stone", nb + Vector3(-0.35, 1.3, 0), Vector3(0.3, 2.6, 1.8), Basis.IDENTITY, true, 0.7)
	k.box("stone", nb + Vector3(0.0, 2.75, 0), Vector3(1.0, 0.3, 1.9), Basis.IDENTITY, true, 0.75)
	k.box("stone", nb + Vector3(0.0, 0.25, 0), Vector3(0.9, 0.5, 1.4), Basis.IDENTITY, true, 0.7)   # the ledge in the niche
	# the spout: a stone gutter beam out from the berm over the walk, on two raking struts
	var berm_x := -31.0
	var by := Kit.gy(sp, berm_x, SPOUT_Z) + 0.3
	var tip := Vector3(-24.6, maxf(by - 0.4, wy + 3.9), SPOUT_Z)
	var root3 := Vector3(berm_x, by, SPOUT_Z)
	var mid := (root3 + tip) * 0.5
	var along := (tip - root3).normalized()
	var bas := Basis(Vector3.BACK, atan2(tip.y - root3.y, tip.x - root3.x))
	k.box("stone", mid, Vector3((tip - root3).length(), 0.7, 1.3), bas, true, 0.85)
	for s: float in [-0.5, 0.5]:
		k.box("stone", mid + Vector3(0, 0.45, s), Vector3((tip - root3).length(), 0.3, 0.2), bas, true, 0.9)
	for sx: float in [0.35, 0.7]:
		var a := root3.lerp(tip, sx) + Vector3.DOWN * 0.35
		var foot := Vector3(xin - 0.3, wy + 0.4, SPOUT_Z)
		var sm := (a + foot) * 0.5
		var dd := a - foot
		k.box("dark", sm, Vector3(0.36, dd.length(), 0.36), Basis(Vector3.BACK, atan2(-dd.x, dd.y)), false, 0.75)
	# the furnace mouth on the berm top: a squat cracked kiln, glow in its throat
	var kc := Vector3(berm_x - 1.2, Kit.gy(sp, berm_x - 1.2, SPOUT_Z + 1.3), SPOUT_Z + 1.3)
	k.box("stone", kc + Vector3.UP * 0.8, Vector3(2.0, 1.6, 2.2), Basis.IDENTITY, true, 0.7)
	k.box("stone", kc + Vector3.UP * 1.75, Vector3(1.6, 0.4, 1.8), Basis(Vector3.UP, 0.2), true, 0.65)
	k.box("dark", kc + Vector3(0.9, 0.8, 0), Vector3(0.3, 0.9, 0.9), Basis.IDENTITY, false, 0.5)
	Kit.box_body(node, (root3 + tip) * 0.5 + Vector3.UP * 1.2, Vector3((tip - root3).length(), 2.4, 1.6), bas)  # keep off the gutter
	# the hidden stair: steps seated above the face, from the berm top down to the walk's north end
	var a2 := Vector3(STAIR_TOP.x, Kit.gy(sp, STAIR_TOP.x, STAIR_TOP.y) + 0.1, STAIR_TOP.y)
	var b2 := Vector3(WALK_X - 0.3, wy, WALK_Z1 + 1.2)
	var dir := Vector3(b2.x - a2.x, 0, b2.z - a2.z).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var tread := 0.5
	var y := a2.y
	var p := Vector2(a2.x, a2.z)
	var steps: Array = []
	var guard := 0
	while guard < 80:
		guard += 1
		var c2 := p + Vector2(dir.x, dir.z) * tread
		var hi := -INF
		for o: float in [-0.8, 0.0, 0.8]:
			for q: float in [0.0, tread]:
				var s2 := p + Vector2(side.x, side.z) * o + Vector2(dir.x, dir.z) * q
				hi = maxf(hi, Kit.gy(sp, s2.x, s2.y))
		var ny := maxf(y - 0.36, hi + 0.08)
		if Vector2(c2.x - b2.x, c2.y - b2.z).length() < 0.6 or ny <= wy + 0.05:
			ny = maxf(ny, wy)
		ny = maxf(ny, wy)
		steps.append([p + Vector2(dir.x, dir.z) * (tread * 0.5), ny])
		y = ny
		p = c2
		if absf(y - wy) < 0.02 and Vector2(p.x - b2.x, p.y - b2.z).length() < 1.0:
			break
		if Vector2(p.x - a2.x, p.y - a2.z).length() > Vector2(b2.x - a2.x, b2.z - a2.z).length() + 0.5:
			break
	var sb := Basis(side, Vector3.UP, dir)
	for st: Array in steps:
		var c3: Vector2 = st[0]
		var sy: float = st[1]
		var gl := minf(Kit.gy(sp, c3.x + side.x * 0.8, c3.y + side.z * 0.8), Kit.gy(sp, c3.x - side.x * 0.8, c3.y - side.z * 0.8))
		var bot := gl - 0.5
		k.box("stone", Vector3(c3.x, (sy + bot) * 0.5, c3.y), Vector3(1.5, sy - bot, tread + 0.03), sb, true, 0.84 if steps.find(st) % 2 == 0 else 0.94)
	k.commit(node, "LedgeBody")
	_fade(node, 120.0)
	# the curtain of molten rock from the spout tip down the rift wall
	_curtain(node, sp, tip + Vector3(0.12, -0.3, 0), 1.5)
	Kit.omni(node, Vector3(-25.2, wy + 2.4, SPOUT_Z), Color(1.0, 0.42, 0.14), 1.6, 9.0)
	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(0.9, 0.7)
	glow.mesh = gq
	glow.material_override = Kit.mat("ember")
	node.add_child(glow)
	glow.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), kc + Vector3(1.06, 0.8, 0))
	var nc := nb + Vector3(0.0, 0.55, 0)
	State.cache(node, "spill", nc + Vector3.UP * 0.1, "the Founder's strongbox", func(_a: bool) -> void: pass)
	var box_mi := Kit.mi(node, _box_mesh(Vector3(0.6, 0.4, 0.8)), OssKit.mat("iron"), Transform3D(Basis.IDENTITY, nc + Vector3.UP * 0.2), 50.0)
	box_mi.name = "Strongbox"
	State.reading(node, "sc_spill", nb + Vector3(0.1, 1.6, 0.75))
	# a faint glint at the stair head: the only cue from above
	Kit.glint(node, a2 + Vector3.UP * 0.9, Color(1.0, 0.6, 0.3), 0.26, 30.0)
	State.register({"id": "spill", "name": "The Founder's Spill", "at": Vector3(WALK_X, wy, SPOUT_Z), "r": 5.0, "node": node,
		"route": {"from": Vector3(-39.0, 10.0, -31.0), "pts": _v3([Vector2(-37.0, -36.8), Vector2(STAIR_TOP.x, STAIR_TOP.y)] + _stair_pts(steps) + [Vector2(WALK_X, WALK_Z1 + 2.0), Vector2(WALK_X, SPOUT_Z - 2.2), Vector2(WALK_X - 0.4, SPOUT_Z)])},
		"goal": Vector3(WALK_X - 0.4, wy, SPOUT_Z)})


static func _stair_pts(steps: Array) -> Array:
	var out := []
	for i in range(0, steps.size(), 4):
		out.append(steps[i][0])
	if not steps.is_empty():
		out.append(steps[steps.size() - 1][0])
	return out


## The poured sheet: down from the lip, then along the real rock to below the lava line.
static func _curtain(node: Node3D, sp: PhysicsDirectSpaceState3D, lip: Vector3, w: float) -> void:
	var pts: Array[Vector3] = [lip]
	var x := lip.x
	var hit_y := Kit.gy(sp, x + 0.25, lip.z)
	pts.append(Vector3(x + 0.25, hit_y + 0.1, lip.z))
	while x < -16.0:
		x += 0.5
		var gy := Kit.gy(sp, x, lip.z)
		pts.append(Vector3(x, gy + 0.08, lip.z))
		if gy < RealmLayout.LAVA_Y + 0.2:
			break
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vlen := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var wa := w * (1.0 if i > 0 else 0.85)
		var wb := w * (1.0 + 0.05 * float(i))
		var v0 := vlen / 8.0
		var v1 := (vlen + seg) / 8.0
		vlen += seg
		var n := (b - a).cross(Vector3.FORWARD).normalized()
		var quad := [[a + Vector3(0, 0, -wa * 0.5), Vector2(0, v0)], [a + Vector3(0, 0, wa * 0.5), Vector2(1, v0)], [b + Vector3(0, 0, wb * 0.5), Vector2(1, v1)], [b + Vector3(0, 0, -wb * 0.5), Vector2(0, v1)]]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	var m := st.commit()
	var c := MeshInstance3D.new()
	c.name = "Curtain"
	c.mesh = m
	c.material_override = Kit.shader_mat("curtain")
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.visibility_range_end = 140.0
	node.add_child(c)
	var e := Vfx.emitter(Color(1.7, 0.6, 0.15), {"count": 40, "life": 2.2, "speed": Vector2(0.3, 1.4), "size": 0.04, "gravity": -0.5, "radius": 0.6, "turbulence": true, "explosive": 0.0})
	if e:
		e.name = "SpillEmbers"
		node.add_child(e)
		e.global_position = lip + Vector3(0.6, -2.5, 0)


# --- the rim bridge ----------------------------------------------------------------------------------

static func _bridge(node: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	var wy := walk_y
	var north := Vector3(WALK_X + 0.2, wy, WALK_Z0 + 0.2)
	var ly := Kit.low(sp, LANDING, 1.6) + 0.12
	var south := Vector3(LANDING.x, maxf(ly, Kit.gy(sp, LANDING.x, LANDING.y) + 0.1), LANDING.y - 1.4)
	# fixed parts: the landing (south) and the windlass posts (north)
	var k := OssKit.new()
	k.keep_lanes = false
	var lgy := Kit.low(sp, LANDING, 2.0)
	k.block("stone", Vector3(LANDING.x - 1.5, lgy - 0.6, LANDING.y - 1.6), Vector3(LANDING.x + 1.5, south.y, LANDING.y + 1.4), true, 0.85)
	for s: float in [-1.0, 1.0]:
		k.box("wood", Vector3(LANDING.x + s * 0.95, south.y + 0.75, south.z + 0.1), Vector3(0.26, 1.5, 0.26), Basis.IDENTITY, true, 0.8)
		k.box("wood", Vector3(north.x + s * 0.95, wy + 0.85, north.z - 0.3), Vector3(0.28, 1.7, 0.28), Basis.IDENTITY, true, 0.8)
	k.box("wood", Vector3(north.x, wy + 0.75, north.z - 0.9), Vector3(1.6, 0.22, 0.22), Basis.IDENTITY, false, 0.7)   # windlass drum
	k.box("iron", Vector3(north.x + 0.95, wy + 0.75, north.z - 0.9), Vector3(0.1, 0.6, 0.08), Basis.IDENTITY, false, 0.8)  # crank
	k.commit(node, "BridgeFixed")
	# the bridge itself: planks on a sag, two hand ropes; one rigid node hinged at the north posts
	var span := south - north
	var lenh := span.length()
	var hinge := Node3D.new()
	hinge.name = "RimBridge"
	node.add_child(hinge)
	hinge.global_position = north
	var dir := span.normalized()
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	var side := flat.cross(Vector3.UP).normalized()
	var deck := OssKit.new()
	deck.keep_lanes = false
	var n := int(lenh / 0.42)
	var cm := CreatureMesh.new(9)
	var rope_l := PackedVector3Array()
	var rope_r := PackedVector3Array()
	var rad := PackedFloat32Array()
	var bodies: Array[StaticBody3D] = []
	var sag := 0.55
	for i in n + 1:
		var t := float(i) / float(n)
		var p := span * t + Vector3.DOWN * (sag * 4.0 * t * (1.0 - t))       # local to the hinge
		var t2 := minf(t + 1.0 / float(n), 1.0)
		var p2 := span * t2 + Vector3.DOWN * (sag * 4.0 * t2 * (1.0 - t2))
		var fwd := (p2 - p).normalized() if i < n else dir
		var up := side.cross(fwd).normalized() * -1.0
		if up.y < 0.0:
			up = -up
		var bas := Basis(side, up, fwd).orthonormalized()
		if i < n:
			deck.box("wood", p + fwd * 0.21 + up * -0.04, Vector3(1.4, 0.07, 0.36), bas.rotated(fwd, sin(float(i) * 2.7) * 0.03), false, 0.75 + 0.2 * float(i % 3) / 2.0)
		rope_l.append(p + side * 0.78 + Vector3.UP * (0.95 - sag * 0.3 * sin(t * PI)))
		rope_r.append(p - side * 0.78 + Vector3.UP * (0.95 - sag * 0.3 * sin(t * PI)))
		rad.append(0.035)
		if i % 4 == 0 and i < n:
			cm.tube(PackedVector3Array([p + side * 0.74, p + side * 0.78 + Vector3.UP * 0.95]), PackedFloat32Array([0.02, 0.02]), 4, Color.WHITE, 0.0, 0.0)
			cm.tube(PackedVector3Array([p - side * 0.74, p - side * 0.78 + Vector3.UP * 0.95]), PackedFloat32Array([0.02, 0.02]), 4, Color.WHITE, 0.0, 0.0)
	for i in range(0, n, 3):
		var t := float(i) / float(n)
		var t3 := minf(float(i + 3) / float(n), 1.0)
		var a := span * t + Vector3.DOWN * (sag * 4.0 * t * (1.0 - t))
		var b := span * t3 + Vector3.DOWN * (sag * 4.0 * t3 * (1.0 - t3))
		var f := (b - a)
		var bas2 := Basis(side, side.cross(f.normalized()) * -1.0, f.normalized()).orthonormalized()
		if bas2.y.y < 0.0:
			bas2 = Basis(side, -bas2.y, f.normalized()).orthonormalized()
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.4, 0.2, f.length() + 0.1)
		cs.shape = bs
		body.add_child(cs)
		hinge.add_child(body)
		body.transform = Transform3D(bas2, (a + b) * 0.5 - bas2.y * 0.14)
		bodies.append(body)
		for s: float in [-1.0, 1.0]:      # rails: keep the walk on the deck
			var rb := StaticBody3D.new()
			rb.collision_layer = Layers.WORLD
			var rcs := CollisionShape3D.new()
			var rbs := BoxShape3D.new()
			rbs.size = Vector3(0.12, 1.3, f.length() + 0.1)
			rcs.shape = rbs
			rb.add_child(rcs)
			hinge.add_child(rb)
			rb.transform = Transform3D(bas2, (a + b) * 0.5 + side * (s * 0.8) + Vector3.UP * 0.5)
			bodies.append(rb)
	cm.tube(rope_l, rad, 5, Color.WHITE, 0.0, 0.0)
	cm.tube(rope_r, rad, 5, Color.WHITE, 0.0, 0.0)
	var rope_mi := MeshInstance3D.new()
	rope_mi.mesh = cm.commit()
	rope_mi.material_override = Kit.mat("rope")
	rope_mi.name = "Ropes"
	hinge.add_child(rope_mi)
	var tmp := Node3D.new()
	hinge.add_child(tmp)
	deck.commit(tmp, "unused")
	for c in tmp.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = 120.0
	# hanging: swung down from the hinge, deck against the rift wall below the north posts
	var hang := Basis(side, -1.25)
	var sync := func(animate: bool) -> void:
		var open := State.has("open", "bridge")
		for b in bodies:
			Kit.set_body(b, open)
		var to := Basis.IDENTITY if open else hang
		if animate and open:
			Kit.play("creak", north, 0.0)
			var tw := hinge.create_tween()
			tw.tween_property(hinge, "basis", to, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			hinge.basis = to
	sync.call(false)
	var wind := Kit.touch(node, Vector3(north.x + 0.9, wy + 0.8, north.z - 0.9), "", func(_by: Node) -> void:
		if State.mark("open", "bridge"):
			State.toast("The bridge swings out across the rim and holds.")
			State.banner("a way opens", "The Rim Bridge")
			sync.call(true), 2.2)
	wind.name = "Windlass"
	wind.set("prompt_fn", func() -> String: return "" if State.has("open", "bridge") else "Wind out the rope bridge")
	var far := Kit.touch(node, south + Vector3(0, 0.8, 0.6), "", func(_by: Node) -> void:
		State.toast("The bridge hangs from the far posts. Its windlass is on the other side."), 2.0)
	far.name = "HangingRopes"
	far.set("prompt_fn", func() -> String: return "" if State.has("open", "bridge") else "Pull at the hanging ropes")
	State.reading(node, "sc_bridge", Vector3(north.x - 0.95, wy + 1.3, north.z - 0.3))
	State.register({"id": "bridge", "name": "The Rim Bridge", "at": south, "r": 4.0, "node": node, "sync": sync,
		"route": {"from": Vector3(-8.0, 1.0, 2.0), "pts": _v3([Vector2(-16, 0), Vector2(LANDING.x, LANDING.y + 1.2), Vector2(LANDING.x, LANDING.y - 1.2)])},
		"cross": [Vector3(south.x, 0, south.z), Vector3(north.x, 0, north.z - 1.0), Vector3(WALK_X, 0, -22.0)],
		"goal": Vector3(LANDING.x, 0, LANDING.y - 1.2)})


# --- helpers ------------------------------------------------------------------------------------------

static func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _fade(node: Node3D, end: float) -> void:
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visibility_range_end == 0.0:
			(c as MeshInstance3D).visibility_range_end = end
			(c as MeshInstance3D).visibility_range_end_margin = end * 0.1
			(c as MeshInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func _v3(a: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: Vector2 in a:
		out.append(Vector3(v.x, 0, v.y))
	return out

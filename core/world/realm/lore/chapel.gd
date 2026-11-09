extends RefCounted
## The Chapel of the First Kindling (RealmLayout.CHAPEL_C): once the Chapel of the Open Sky, a
## pilgrims' washing-house. Roofless: an aisleless nave with lancet windows and broken buttresses,
## a chancel arch, a polygonal apse with the altar and the First Hearth (still warm), defaced saints
## in the nave, pews thrown down, roof timbers fallen in, a broken bellcote over the east door
## (chapel_lane arrives at it). North of it, the Kindlers' Yard: a walled graveyard with Edda's
## plain stone, Brother Ansel, the pilgrims' row.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const X0 := -87.0          ## nave west (chancel arch) outer line
const X1 := -70.2          ## nave east wall outer face (door)
const Z0 := 47.2           ## north wall outer face
const Z1 := 55.6           ## south wall outer face
const T := 0.8
const H := 6.4
const KEY := "lore_ashlar"


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "ChapelOfTheFirstKindling", 5120)
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var zc := (Z0 + Z1) * 0.5
	var R := (Z1 - Z0) * 0.5
	var foot := Rect2(X0 - R - 0.6, Z0 - 0.9, (X1 + 0.3) - (X0 - R - 0.6), (Z1 + 0.9) - (Z0 - 0.9))
	var gr: Vector2 = L.g_range(foot)
	var fy := gr.y + 0.15
	L.site("chapel", foot, fy, fy - 0.3)
	# foundation + floor (nave and apse)
	k.foundation(KEY, Vector2(X0 - R - 0.2, Z0), Vector2(X1, Z1), fy, gr.x)
	k.block("floor", Vector3(X0 - R + 0.4, fy - 0.15, Z0 + T), Vector3(X1 - T, fy + 0.002, Z1 - T), true, 0.8)
	# --- long walls: three lancet bays each, jagged ruined tops --------------------------------
	var bays := [X0 + 3.4, X0 + 8.4, X0 + 13.4]
	for side: int in [0, 1]:
		var zm := Z0 + T * 0.5 if side == 0 else Z1 - T * 0.5
		var x := X0
		for bi in bays.size():
			var bx: float = bays[bi]
			_solid(L, x, bx - 1.25, zm, fy, side)
			var top := _prof(bx, side) * H
			if side == 1 and bi == 1:
				# a broken window: the head fell in, jambs stand to different heights
				k.box(KEY, Vector3(bx - 1.0, fy + 1.6, zm), Vector3(0.5, 3.2, T), Basis.IDENTITY, true)
				k.box(KEY, Vector3(bx + 1.0, fy + 2.2, zm), Vector3(0.5, 4.4, T), Basis.IDENTITY, true)
				k.box(KEY, Vector3(bx, fy + 0.8, zm), Vector3(1.5, 1.6, T), Basis.IDENTITY, true)
				L.rubble(k, Vector3(bx, 0, zm + (1.6 if side == 1 else -1.6)), 1.4, 12, KEY, false)
			else:
				k.arch_panel(KEY, Vector3(bx, fy, zm), Vector3.RIGHT, 1.5, 3.6, maxf(top, 5.6), T, 0.5, 0.85, 1.6, "lore_ashlar")
			x = bx + 1.25
		_solid(L, x, X1, zm, fy, side)
		# buttresses between bays and at the corners, some broken
		for i in 4:
			var bxx: float = [X0 + 0.6, X0 + 5.9, X0 + 10.9, X1 - 0.6][i]
			var out := -1.0 if side == 0 else 1.0
			var zf := (Z0 if side == 0 else Z1) + out * 0.65
			var broken := (i + side) % 3 == 1
			var h1 := 3.6 if not broken else rng.randf_range(1.4, 2.4)
			k.box(KEY, Vector3(bxx, fy + h1 * 0.5 - 0.3, zf), Vector3(0.9, h1 + 0.6, 1.3), Basis.IDENTITY, true, 0.9)
			if not broken:
				k.box(KEY, Vector3(bxx, fy + h1 + 0.9, zf - out * 0.2), Vector3(0.75, 1.8, 0.9), Basis.IDENTITY, true, 0.95)
				k.box(KEY, Vector3(bxx, fy + h1 + 1.9, zf - out * 0.32), Vector3(0.8, 0.3, 0.85), Basis(Vector3.RIGHT, out * 0.6), false, 0.82)
			else:
				L.rubble(k, Vector3(bxx, 0, zf + out * 1.0), 1.2, 9, KEY, false)
	# --- chancel arch, apse ---------------------------------------------------------------------
	k.arch_panel(KEY, Vector3(X0 + T * 0.5, fy, zc), Vector3.BACK, 5.6, 3.4, 7.2, T, (Z1 - Z0 - 5.6) * 0.5, 0.75, 0.0, "lore_ashlar")
	var n := 7
	for i in n:
		var a0 := PI * 0.5 + PI * float(i) / float(n)
		var a1 := PI * 0.5 + PI * float(i + 1) / float(n)
		var p0 := Vector3(X0 + cos(a0) * R, 0, zc - sin(a0) * R)
		var p1 := Vector3(X0 + cos(a1) * R, 0, zc - sin(a1) * R)
		var mid := (p0 + p1) * 0.5
		var along := (p1 - p0).normalized()
		var inward := (Vector3(X0, 0, zc) - mid).normalized()
		var ln := p0.distance_to(p1) + 0.35
		var hh := H * (0.85 - 0.35 * absf(sin(float(i) * 1.7)))
		var c := mid + inward * (T * 0.5) + Vector3.UP * fy
		if i == 3:
			k.arch_panel(KEY, c, along, 0.9, 3.4, maxf(hh, 5.0), T, (ln - 0.9) * 0.5, 0.9, 1.8, "lore_ashlar")
			# the east-facing lancet still has glass: the only lit window (the hearth behind it)
		else:
			k.box(KEY, c + Vector3.UP * (hh * 0.5), Vector3(ln, hh, T), Basis(along, Vector3.UP, inward), true, rng.randf_range(0.9, 1.0))
	k.block("floor", Vector3(X0 - R + 0.6, fy, zc - 2.6), Vector3(X0 + 0.4, fy + 0.3, zc + 2.6), true, 0.86)   # chancel step
	# --- the altar and the First Hearth -------------------------------------------------------
	var alt := Vector3(X0 - 1.6, fy + 0.3, zc)
	k.box(KEY, alt + Vector3.UP * 0.5, Vector3(1.0, 1.0, 2.2), Basis.IDENTITY, true, 0.9)
	k.box(KEY, alt + Vector3.UP * 1.04, Vector3(1.2, 0.1, 2.4), Basis.IDENTITY, true, 0.8)
	var basin := CreatureMesh.new(77)
	basin.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.16, 0), Vector3(0, 0.26, 0)]), PackedFloat32Array([0.28, 0.42, 0.48]), 14, Color(0.8, 0.78, 0.76), 0.0, 0.05)
	LK.organic(k, "lore_tstone", basin.commit(), Transform3D(Basis.IDENTITY, alt + Vector3.UP * 1.09))
	k.box("lore_char", alt + Vector3.UP * 1.33, Vector3(0.62, 0.05, 0.62), Basis(Vector3.UP, 0.4), false, 0.4)
	k.box("lore_ember", alt + Vector3.UP * 1.36, Vector3(0.36, 0.04, 0.3), Basis(Vector3.UP, 1.1), false, 0.8)
	k.box("lore_ember", alt + Vector3(0.08, 1.37, 0.1), Vector3(0.18, 0.04, 0.2), Basis(Vector3.UP, 0.2), false, 1.0)
	for o: Vector3 in [Vector3(0, 1.09, -0.95), Vector3(0, 1.09, 0.95)]:
		k.candle_cluster(alt + o, 4, 0.16, rng)
	L.letters(alt + Vector3(0.505, 0.65, 0), Vector3.RIGHT, 0.9, 3)
	L.scrap("ch_hearth", alt + Vector3(1.1, 0.0, 0.0))
	var fh: OmniLight3D = L.light("FirstHearth", alt + Vector3(0.6, 1.9, 0), Color(1.0, 0.5, 0.2), 1.6, 9.0)
	if fh:
		fh.set_meta(&"fire", true)
	var fire := Vfx.emitter(Color(1.0, 0.45, 0.12), {"count": 14, "life": 0.9, "speed": Vector2(0.2, 0.6), "size": 0.12, "gravity": -1.0, "radius": 0.18, "additive": true, "spread": 20.0})
	if fire:
		fire.name = "HearthEmbers"
		L.holder.add_child(fire)
		fire.global_position = alt + Vector3.UP * 1.38
		fire.emitting = true
	# --- the defaced saints along the nave -----------------------------------------------------
	var n_in := Z0 + T + 0.55
	var s_in := Z1 - T - 0.55
	var e1: Vector3 = L.saint(Vector3(X0 + 5.9, fy, n_in), PI, 1, 0.75)
	L.letters(e1 + Vector3(0, 0, 0.02), Vector3.BACK, 0.5, 2)
	L.scrap("ch_edda_saint", e1 + Vector3(0, 0, 0.8), e1)
	# where Brother Ansel stopped: his chisel and mallet on the floor by her plinth, a page
	var ch := Vector3(X0 + 7.0, fy + 0.03, n_in + 0.7)
	k.box("iron", ch + Vector3(0, 0.02, 0), Vector3(0.24, 0.025, 0.03), Basis(Vector3.UP, 0.7), false, 0.7)
	k.box("lore_beam", ch + Vector3(0.18, 0.04, 0.12), Vector3(0.12, 0.08, 0.08), Basis(Vector3.UP, -0.3), false, 0.7)
	k.box("lore_beam", ch + Vector3(0.1, 0.03, 0.26), Vector3(0.03, 0.03, 0.3), Basis(Vector3.UP, -0.3), false, 0.7)
	L.page(ch + Vector3(-0.3, 0.0, 0.2), Vector3.UP, 0.5)
	L.scrap("ch_ansel_1", ch + Vector3(0.1, 0.27, 0.6), ch + Vector3(-0.2, 0.05, 0.2))
	var c1: Vector3 = L.saint(Vector3(X0 + 5.9, fy, s_in), 0.0, 2, 0.75)
	L.letters(c1 + Vector3(0, 0, -0.02), Vector3.FORWARD, 0.5, 2)
	L.scrap("ch_corvin", c1 + Vector3(0, 0, -0.8), c1)
	L.saint(Vector3(X0 + 10.9, fy, n_in), PI, 3, 0.75)
	# the fourth fell off its plinth into the nave
	k.box("lore_tstone", Vector3(X0 + 10.9, fy + 0.35, s_in), Vector3(0.95, 0.75, 0.85), Basis.IDENTITY, true, 0.85)
	L.fallen_saint(Vector3(X0 + 10.4, fy, zc + 1.2), -2.4, 1, true)
	# --- pews, thrown about ---------------------------------------------------------------------
	for row in 4:
		for col: float in [-1.0, 1.0]:
			var px := X0 + 4.2 + float(row) * 2.2
			var pz := zc + col * 2.1
			var r := rng.randf()
			if r < 0.2:
				continue
			var yaw := rng.randf_range(-0.08, 0.08)
			var tip := 0.0
			if r > 0.7:
				tip = PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
				yaw += rng.randf_range(-0.5, 0.5)
			_pew(L, Vector3(px, fy, pz), yaw, tip)
	L.page(Vector3(X0 + 8.6, fy + 0.5, zc - 2.1), Vector3(0.1, 1, 0).normalized())
	L.scrap("jn_3", Vector3(X0 + 8.6, fy + 0.3, zc - 2.9))
	# lecterns with the Litany: by the chancel step, mid-nave (thrown down), by the door
	L.scrap("ch_litany_1", L.lectern(Vector3(X0 + 1.4, fy, zc - 2.3), -PI * 0.5) + Vector3(0.6, -0.6, 0))
	var lz := Vector3(X0 + 12.8, fy, zc - 0.2)
	k.box("lore_tstone", lz + Vector3(0, 0.15, 0), Vector3(1.0, 0.3, 0.3), Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, PI * 0.5), true, 0.85)
	L.page(lz + Vector3(0.6, 0.02, 0.4), Vector3.UP)
	L.scrap("ch_litany_2", lz + Vector3(0.6, 0.3, 0.4))
	L.scrap("ch_litany_3", L.lectern(Vector3(X1 - T - 1.6, fy, zc + 2.6), PI * 0.5) + Vector3(-1.0, -0.6, 0))
	# fallen roof timbers and rubble
	for i in 4:
		var c0 := Vector3(X0 + 2.5 + float(i) * 3.0 + rng.randf_range(-0.5, 0.5), fy, zc + rng.randf_range(-1.0, 1.0))
		var dirv := Vector3(rng.randf_range(-0.5, 0.5), 0.0, 1.0).normalized()
		var lift := rng.randf_range(0.1, 0.45)
		k.box("lore_beam", c0 + Vector3.UP * (0.25 + lift * 1.5), Vector3(0.28, 0.3, 6.5), Basis.looking_at(Vector3(dirv.x, lift, dirv.z).normalized(), Vector3.UP), true, 0.7)
	for q: Vector3 in [Vector3(X0 + 2.0, 0, Z0 + 1.6), Vector3(X1 - 2.5, 0, Z0 + 1.5), Vector3(X0 + 12.0, 0, Z1 - 1.6)]:
		L.rubble(k, Vector3(q.x, fy, q.z), 1.3, 12, KEY, true)
	# --- east front: door, broken gable, bellcote ------------------------------------------------
	var door_w := 2.2
	k.arch_panel(KEY, Vector3(X1 - T * 0.5, fy, zc), Vector3.BACK, door_w, 2.5, H + 0.2, T, (Z1 - Z0 - door_w) * 0.5, 0.8, 0.0, "lore_ashlar")
	# the gable: the north half stands to the bellcote, the south half has fallen
	var gy := fy + maxf(H + 0.2, 2.5 + 2.0)
	var gx := X1 - T * 0.5
	k.quad(KEY, Vector3(X1, gy, Z0), Vector3(X1, gy, zc + 0.3), Vector3(X1, gy + 2.8, zc + 0.3), Vector3(X1, gy + 2.8, zc + 0.3), Vector3.RIGHT)
	k.quad(KEY, Vector3(X1 - T, gy, Z0), Vector3(X1 - T, gy, zc + 0.3), Vector3(X1 - T, gy + 2.8, zc + 0.3), Vector3(X1 - T, gy + 2.8, zc + 0.3), Vector3.LEFT)
	k.quad(KEY, Vector3(X1 - T, gy, zc + 0.3), Vector3(X1, gy, zc + 0.3), Vector3(X1, gy + 2.8, zc + 0.3), Vector3(X1 - T, gy + 2.8, zc + 0.3), Vector3.BACK)
	k.box(KEY, Vector3(gx, gy + 1.3, zc + 0.75), Vector3(T, 2.6, 0.9), Basis.IDENTITY, true, 0.92)
	k.arch_panel(KEY, Vector3(gx, gy + 2.6, zc), Vector3.BACK, 0.8, 0.5, 1.6, T * 0.8, 0.28, 0.8, 0.0, "")
	k.pinnacle(KEY, Vector3(gx, gy + 4.25, zc), 0.3, 0.3, 0.6)
	for j in 3:
		L.rubble(k, Vector3(X1 + 1.6 + float(j) * 0.4, fy, Z1 - 1.2 - float(j) * 0.9), 1.0, 8, KEY, false)
	# porch threshold and steps down to the lane, the dedication stone
	var gd: float = L.g(X1 + 1.5, zc)
	var rise := fy - gd
	if rise > 0.15:
		var ns := Metrics.steps_for(rise)
		k.stairs(KEY, Vector3(X1 + 0.2 + Metrics.TREAD * float(ns), gd, zc), Vector3(X1 + 0.2, fy, zc), door_w + 0.4, ns, gd - 0.6)
	var ded := Vector3(X1 + 0.05, fy + 1.4, zc + 2.2)
	k.box("lore_tstone", ded, Vector3(0.12, 0.6, 0.9), Basis.IDENTITY, false, 1.05)
	L.letters(ded + Vector3(0.065, 0, 0), Vector3.RIGHT, 0.7, 4)
	L.scrap("ch_door", Vector3(X1 + 1.3, fy, zc + 2.2))
	L.finish()
	L.note("Chapel of the First Kindling", Vector3(-78, fy, zc))
	_yard(parent)


## Wall run from xa to xb along a long side, column by column to a ragged top.
static func _solid(L: RefCounted, xa: float, xb: float, zm: float, fy: float, side: int) -> void:
	var k: OssKit = L.k
	if xb - xa < 0.05:
		return
	var n := maxi(1, ceili((xb - xa) / 0.7))
	for i in n:
		var x0 := lerpf(xa, xb, float(i) / float(n))
		var x1 := lerpf(xa, xb, float(i + 1) / float(n))
		var h: float = _prof((x0 + x1) * 0.5, side) * H + L.rng.randf_range(-0.25, 0.15)
		k.box(KEY, Vector3((x0 + x1) * 0.5, fy + h * 0.5, zm), Vector3(x1 - x0 + 0.004, h, T), Basis.IDENTITY, true, L.rng.randf_range(0.9, 1.0))
		k.broken_crown(KEY, Vector3((x0 + x1) * 0.5, fy + h, zm), Basis.IDENTITY, x1 - x0, T, L.rng, 0.92)
		# string course at sill height
		k.box(KEY, Vector3((x0 + x1) * 0.5, fy + 1.55, zm), Vector3(x1 - x0 + 0.004, 0.16, T + 0.14), Basis.IDENTITY, false, 0.8)
		if h > 2.2:
			k.box(KEY, Vector3((x0 + x1) * 0.5, fy + 0.2, zm), Vector3(x1 - x0 + 0.004, 0.4, T + 0.18), Basis.IDENTITY, false, 0.82)


## Ruin profile along the nave: high at the ends, slumped in the middle of each side.
static func _prof(x: float, side: int) -> float:
	var u := (x - X0) / (X1 - X0)
	var slump := 0.45 * exp(-pow((u - (0.55 if side == 0 else 0.4)) * 3.2, 2.0)) + 0.12 * sin(u * 17.0 + float(side) * 2.0)
	return clampf(1.0 - slump, 0.45, 1.0)


static func _pew(L: RefCounted, at: Vector3, yaw: float, tip: float) -> void:
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw)
	if tip != 0.0:
		b = b * Basis(Vector3.RIGHT, tip)
	var o := at + (Vector3.UP * 0.25 if tip != 0.0 else Vector3.ZERO)
	k.box("lore_beam", o + b * Vector3(0, 0.45, 0), Vector3(0.42, 0.07, 3.0), b, true, 0.78)
	k.box("lore_beam", o + b * Vector3(-0.2, 0.8, 0), Vector3(0.06, 0.6, 3.0), b, false, 0.72)
	for z: float in [-1.3, 0.0, 1.3]:
		k.box("lore_beam", o + b * Vector3(0, 0.22, z), Vector3(0.38, 0.45, 0.08), b, false, 0.68)


static func _yard(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "KindlersYard", 5121)
	var rng: RandomNumberGenerator = L.rng
	var yard := Rect2(-88.0, 33.0, 24.5, 12.6)
	var gr: Vector2 = L.g_range(yard)
	L.site("chapel_yard", yard, gr.x)
	# boundary wall, a gap toward the chapel door and one to the east
	var c := [Vector3(yard.position.x, 0, yard.position.y), Vector3(yard.end.x, 0, yard.position.y), Vector3(yard.end.x, 0, yard.end.y), Vector3(yard.position.x, 0, yard.end.y)]
	L.drystone(c[0], c[1], 1.0, 0.35, "lore_moss")
	L.drystone(c[1], Vector3(yard.end.x, 0, yard.end.y - 4.0), 1.0, 0.3, "lore_moss")
	L.drystone(c[2] + Vector3(-4.5, 0, 0), c[3], 0.9, 0.5, "lore_moss")
	L.drystone(c[3], c[0], 1.0, 0.35, "lore_moss")
	# rows of the dead
	var named := {Vector2i(1, 2): "ch_ansel"}
	for row in 3:
		var z := yard.position.y + 4.2 + float(row) * 2.8
		for i in 8:
			if rng.randf() < 0.18 and not named.has(Vector2i(row, i)):
				continue
			var x := yard.position.x + 2.2 + float(i) * 2.7 + rng.randf_range(-0.3, 0.3)
			var at: Vector3 = L.gv(x, z)
			var tilt := Vector2(rng.randf_range(-0.12, 0.18), rng.randf_range(-0.12, 0.12))
			var style := rng.randi_range(0, 3)
			var fp: Vector3 = L.headstone(at, PI + rng.randf_range(-0.1, 0.1), style, rng.randf_range(0.75, 1.15), tilt, "lore_tstone", true)
			if named.has(Vector2i(row, i)):
				L.letters(fp + Vector3(0, 0, 0.04), Vector3.BACK, 0.3, 3)
				L.scrap(named[Vector2i(row, i)], fp + Vector3(0, -0.3, 0.6), fp)
	# the pilgrims' row: nine small markers along the north wall, facing the chapel
	for i in 9:
		var at2: Vector3 = L.gv(yard.position.x + 3.0 + float(i) * 2.2, yard.position.y + 1.5)
		var fp2: Vector3 = L.headstone(at2, PI, 1, 0.6, Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1)), "lore_tstone", false)
		if i == 4:
			L.scrap("ch_yard", fp2 + Vector3(0, -0.2, 0.7))
	# Edda: a plain rough stone by the apse end, candles, a worn path of offerings
	var ed: Vector3 = L.gv(-85.2, 44.0)
	var efp: Vector3 = L.headstone(ed, PI, 4, 0.9, Vector2.ZERO, "lore_moss", true)
	L.p.candle_cluster(ed + Vector3(0.5, 0.0, 0.5), 5, 0.22, rng)
	L.p.candle_cluster(ed + Vector3(-0.5, 0.0, 0.4), 3, 0.15, rng)
	L.cairn(L.p, ed + Vector3(0.0, 0.0, 0.7), 0.35)
	L.letters(efp + Vector3(0, 0.05, 0.06), Vector3.BACK, 0.2, 2)
	L.scrap("ch_edda_grave", efp + Vector3(0, -0.3, 0.9), efp)
	L.light("EddasStone", ed + Vector3(0.3, 0.9, 0.9), Color(1.0, 0.55, 0.25), 0.45, 4.0)
	# the keeper's bench by the gate, a pot of banked coals, Ansel's second leaf under it
	var kb: Vector3 = L.gv(-64.7, 44.7)
	L.bench(kb, PI * 0.5)
	var potm: ArrayMesh = LK.pooled("coal_pot", func() -> ArrayMesh:
		var cm := CreatureMesh.new(14)
		cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.12, 0), Vector3(0, 0.22, 0)]), PackedFloat32Array([0.11, 0.16, 0.14]), 10, Color(0.45, 0.32, 0.26), 0.0, 0.06)
		return cm.commit())
	LK.organic(L.p, "lore_rock", potm, Transform3D(Basis.IDENTITY, kb + Vector3(0.0, 0.48, 0.45)))
	L.p.box("lore_ember", kb + Vector3(0.0, 0.7, 0.45), Vector3(0.16, 0.03, 0.16), Basis(Vector3.UP, 0.5), false, 0.6)
	L.page(kb + Vector3(-0.1, 0.49, -0.35), Vector3.UP, 0.4)
	L.scrap("ch_ansel_2", kb + Vector3(-0.9, 0.25, 0.0), kb + Vector3(-0.1, 0.5, -0.35))
	L.finish()
	L.note("The Kindlers' Yard", Vector3(yard.get_center().x, gr.x, yard.get_center().y))

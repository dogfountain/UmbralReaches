extends RefCounted
## Hearthward's cottages (no class_name). One stone cottage per call, in its own frame: centre `c`
## (xz), `w` x `d` footprint (local x along the front, local -z = front with the door), `yaw`.
## state: "dark" (whole, door barred, shutters closed), "lit" (whole, one window still lit),
##        "ruin" (roofless, jagged walls, rubble inside), "burned" (ruin, blackened, charred beams).
## Returns {floor, door (world, outside the threshold), xf, site}.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const LA := preload("res://core/world/realm/lore/lore_assets.gd")
const T := 0.5          ## wall thickness
const H := 2.6          ## eaves height above the floor


static func build(L: RefCounted, site_name: String, c: Vector2, w: float, d: float, yaw: float, state: String, roof := "slate", walls := "lore_rubble") -> Dictionary:
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var bas := Basis(Vector3.UP, yaw)
	# footprint corners in world xz -> site rect, ground range
	var corners: Array[Vector2] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var q: Vector3 = bas * Vector3(sx * (w * 0.5 + 0.3), 0, sz * (d * 0.5 + 0.3))
			corners.append(Vector2(c.x + q.x, c.y + q.z))
	var lo := corners[0]
	var hi := corners[0]
	for q in corners:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var rect := Rect2(lo, hi - lo)
	var gr: Vector2 = L.g_range(rect)
	var fy := gr.y + 0.15
	L.site(site_name, rect, fy, fy - 0.3)
	var xf := Transform3D(bas, Vector3(c.x, fy, c.y))
	var ruined := state == "ruin" or state == "burned"
	var stone := "lore_rubble" if walls == "lore_rubble" else "lore_tstone"
	var face_key := walls
	var shade := 0.55 if state == "burned" else 1.0
	# foundation (local footprint, world rotated): one block per footprint, below grade
	k.box(stone, xf * Vector3(0, -(fy - gr.x + 0.5) * 0.5, 0), Vector3(w + 0.24, fy - gr.x + 0.5, d + 0.24), bas, true, 0.82 * shade)
	k.box("floor", xf * Vector3(0, -0.06, 0), Vector3(w - T * 2.0, 0.12, d - T * 2.0), bas, true, 0.75 * shade)
	# walls: front (with door + window), back (windows), two gable ends
	var hw := w * 0.5
	var hd := d * 0.5
	var door := {"at": w * 0.36, "w": 1.1, "sill": 0.0, "top": 2.05, "door": true}
	var win := {"w": 0.8, "sill": 0.95, "top": 1.85}
	var ruin := 0.0
	if ruined:
		ruin = 0.55 if state == "ruin" else 0.4
	_wall(L, xf, face_key, Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3.BACK, H, [door, _o(win, w * 0.72)], ruin, shade, state)
	_wall(L, xf, face_key, Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3.FORWARD, H, [_o(win, w * 0.3), _o(win, w * 0.7)], ruin, shade, state)
	var gable_h := H + (d * 0.5) * 0.95
	_wall(L, xf, face_key, Vector3(-hw, 0, hd), Vector3(-hw, 0, -hd), Vector3.RIGHT, H, [_o(win, d * 0.5)], ruin, shade, state)
	_wall(L, xf, face_key, Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3.LEFT, H, [], ruin, shade, state)
	# timber framing over the plaster: posts by every opening, rails, braces, a gable king post
	if face_key == "lore_plaster":
		var beam := "lore_char" if state == "burned" else "lore_beam"
		var tops: float = H if not ruined else H * 0.55
		_framing(L, xf, Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3.FORWARD, [door, _o(win, w * 0.72)], tops, beam)
		_framing(L, xf, Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3.BACK, [_o(win, w * 0.3), _o(win, w * 0.7)], tops, beam)
		_framing(L, xf, Vector3(-hw, 0, hd), Vector3(-hw, 0, -hd), Vector3.LEFT, [_o(win, d * 0.5)], tops, beam)
		_framing(L, xf, Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3.RIGHT, [], tops, beam)
		if not ruined:
			for sx3: float in [-1.0, 1.0]:
				var gx3 := sx3 * (hw + 0.035)
				var gb := xf.basis * Basis(Vector3.UP, PI * 0.5)
				k.box(beam, xf * Vector3(gx3, (H + gable_h) * 0.5 - 0.15, 0), Vector3(0.16, gable_h - H - 0.3, 0.07), gb, false, 0.6)
				k.box(beam, xf * Vector3(gx3, H + 0.05, 0), Vector3(d + 0.1, 0.16, 0.07), gb, false, 0.6)
				for sz3: float in [-1.0, 1.0]:
					var a3 := Vector3(gx3, H + 0.1, sz3 * hd * 0.8)
					var b3 := Vector3(gx3, H + (gable_h - H) * 0.55, 0)
					var dd3 := b3 - a3
					var bb := xf.basis * Basis(dd3.normalized(), Vector3.RIGHT.cross(dd3.normalized()).normalized() * sx3, Vector3.RIGHT * sx3).orthonormalized()
					k.box(beam, xf * ((a3 + b3) * 0.5), Vector3(dd3.length(), 0.13, 0.06), bb, false, 0.58)
	# a stone plinth course round the foot (whitewashed cottages stand on it), timber corner posts
	if face_key != stone:
		for sz2: float in [-1.0, 1.0]:
			k.box(stone, xf * Vector3(0, 0.25, sz2 * (hd - T * 0.5)), Vector3(w + 0.1, 0.5, T + 0.1), bas, false, 0.8 * shade)
		for sx2: float in [-1.0, 1.0]:
			k.box(stone, xf * Vector3(sx2 * (hw - T * 0.5), 0.25, 0), Vector3(T + 0.1, 0.5, d + 0.1), bas, false, 0.8 * shade)
	# quoins (stone) or corner posts (whitewash)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var y := 0.15
			var i := 0
			var top := H - 0.2 if not ruined else H * rng.randf_range(0.35, 0.8)
			if face_key != stone:
				k.box("lore_beam", xf * Vector3(sx * (hw - T * 0.5 + 0.03), H * 0.5 + 0.2, sz * (hd - T * 0.5 + 0.03)), Vector3(T + 0.08, H - 0.4, T + 0.08), bas, false, 0.7)
				continue
			while y < top:
				var lx := 0.42 if i % 2 == 0 else 0.26
				var lz := 0.26 if i % 2 == 0 else 0.42
				k.box(stone, xf * Vector3(sx * (hw - T * 0.5), y + 0.15, sz * (hd - T * 0.5)), Vector3(T + lx, 0.3, T + lz), bas, false, 0.84 * shade)
				y += 0.34
				i += 1
	# gable triangles and roof
	if not ruined:
		for sx: float in [-1.0, 1.0]:
			var gx := sx * hw
			var a := xf * Vector3(gx, H, -hd)
			var b := xf * Vector3(gx, H, hd)
			var apex := xf * Vector3(gx, gable_h, 0)
			var o := bas * Vector3(sx, 0, 0)
			k.quad(face_key, a, b, apex, apex, o, true, shade)
			k.quad(face_key, a - o * T, b - o * T, apex - o * T, apex - o * T, -o, false, shade)
		_roof(L, xf, w, d, H, gable_h, roof, state)
		# chimney on the east gable, standing clear of the thatch; a cap stone and a pot
		var ch := Vector3(hw - 0.35, 0, hd * 0.25)
		var cht := gable_h + (1.5 if roof != "slate" else 1.0)
		k.box(stone, xf * Vector3(ch.x, cht * 0.5, ch.z), Vector3(0.7, cht, 0.8), bas, true, 0.9)
		k.box(stone, xf * Vector3(ch.x, cht + 0.05, ch.z), Vector3(0.84, 0.14, 0.94), bas, false, 0.78)
		k.box(stone, xf * Vector3(ch.x, cht - 0.55, ch.z), Vector3(0.78, 0.1, 0.88), bas, false, 0.8)
		var pot: ArrayMesh = LK.pooled("chimney_pot", func() -> ArrayMesh:
			var cm := CreatureMesh.new(31)
			cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.22, 0), Vector3(0, 0.36, 0)]), PackedFloat32Array([0.15, 0.12, 0.13]), 10, Color(0.62, 0.42, 0.34), 0.0, 0.05)
			return cm.commit())
		LK.organic(k, "lore_rock", pot, Transform3D(bas, xf * Vector3(ch.x, cht + 0.11, ch.z)))
		if state == "lit":
			var smoke := Vfx.emitter(Color(0.32, 0.32, 0.36, 0.35), {"count": 10, "life": 4.5, "speed": Vector2(0.25, 0.5), "size": 0.55, "gravity": -0.12, "radius": 0.1, "additive": false, "spread": 12.0})
			if smoke:
				smoke.name = "ChimneySmoke"
				L.holder.add_child(smoke)
				smoke.global_position = xf * Vector3(ch.x, cht + 0.5, ch.z)
				smoke.emitting = true
	else:
		# rafters fallen in, rubble
		var beam := "lore_char" if state == "burned" else "lore_beam"
		for i in 3:
			var x := lerpf(-hw + 0.8, hw - 0.8, float(i) / 2.0) + rng.randf_range(-0.3, 0.3)
			var lean := rng.randf_range(0.35, 0.75)
			var p0 := xf * Vector3(x, 0.15, rng.randf_range(-hd * 0.4, hd * 0.2))
			var dir := bas * Vector3(rng.randf_range(-0.3, 0.3), sin(lean), cos(lean)).normalized()
			var ln := rng.randf_range(2.2, 3.4)
			k.box(beam, p0 + dir * (ln * 0.5), Vector3(0.16, 0.18, ln), Basis.looking_at(dir, Vector3.UP), true, 0.8)
		L.rubble(k, xf * Vector3(hw * 0.3, 0, -hd * 0.1), 1.6, 14, stone, true)
		L.rubble(L.p, xf * Vector3(-hw * 0.4, 0, hd * 0.3), 1.0, 8, stone)
		if state == "burned":
			for i in 5:
				var q := xf * Vector3(rng.randf_range(-hw + 0.7, hw - 0.7), 0.06, rng.randf_range(-hd + 0.7, hd - 0.7))
				L.p.box("lore_char", q, Vector3(rng.randf_range(0.6, 1.6), 0.1, 0.12), Basis(Vector3.UP, rng.randf() * TAU), false, 0.6)
	# hearth on the east gable inside (seen through ruined walls or the door)
	k.box(stone, xf * Vector3(hw - T - 0.3, 0.5, hd * 0.25), Vector3(0.6, 1.0, 1.3), bas, true, 0.8 * shade)
	k.box("dark", xf * Vector3(hw - T - 0.58, 0.35, hd * 0.25), Vector3(0.04, 0.55, 0.8), bas, false, 0.2)
	# lived-in traces: a doorstep, a water butt at the corner, logs along the gable
	var ds := xf * Vector3(-hw + w * 0.36, -0.08, -hd - 0.35)
	k.box(stone, ds, Vector3(1.4, 0.3, 0.6), bas, true, 0.78 * shade)
	if not ruined:
		var wb := xf * Vector3(hw - 0.45, 0, -hd - 0.5)
		wb.y = L.g(wb.x, wb.z)
		L.barrel(L.p, wb, 1.0, false, rng.randf() * TAU)
		for row in 2:
			for i in 5 - row:
				var lq := xf * Vector3(-hw - 0.35, 0.12 + 0.2 * float(row), -hd + 0.9 + 0.22 * float(i) + 0.11 * float(row))
				var cm := CreatureMesh.new(rng.randi())
				cm.tube(PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0)]), PackedFloat32Array([0.1, 0.1]), 7, Color(0.75, 0.65, 0.55), 0.0, 0.12)
				LK.organic(L.p, "lore_beam", cm.commit(), Transform3D(bas * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, rng.randf() * TAU), lq))
		LK.col_box(L.p, xf * Vector3(-hw - 0.35, 0.25, -hd + 1.4), Vector3(0.5, 0.5, 1.2), bas)
	var door_out := xf * Vector3(-hw + w * 0.36, 0.0, -hd - 0.9)
	return {"floor": fy, "door": door_out, "xf": xf, "site": site_name, "rect": rect, "ground": gr}


static func _o(base: Dictionary, at: float) -> Dictionary:
	var dd := base.duplicate()
	dd["at"] = at
	return dd


## Straight wall from local a to local b (outer face line, y = floor), thickness toward `inward`
## (local), `h` tall, openings {at, w, sill, top, door?}. `ruin` > 0 breaks the top into a jagged
## line (0.55 = down to about half height in places).
static func _wall(L: RefCounted, xf: Transform3D, key: String, a: Vector3, b: Vector3, inward: Vector3, h: float, openings: Array, ruin: float, shade: float, state: String) -> void:
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var t := T
	var lb := Basis(along, Vector3.UP, inward)
	var wb := xf.basis * lb
	var col_w := 0.55
	# column heights (jagged top for ruins)
	var heights: Array[float] = []
	var n := maxi(1, ceili(length / col_w))
	var phase := rng.randf() * 10.0
	for i in n:
		if ruin <= 0.0:
			heights.append(h)
		else:
			var u := float(i) / float(n)
			var dip := clampf(0.5 + 0.5 * sin(u * 5.0 + phase) + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
			var edge := 1.0 - 0.6 * minf(u, 1.0 - u) * 2.0          # corners stand taller
			heights.append(h * (1.0 - ruin * dip * (1.0 - edge * 0.45)) + rng.randf_range(-0.1, 0.1))
	for i in n:
		var x0 := length * float(i) / float(n)
		var x1 := length * float(i + 1) / float(n)
		var top: float = heights[i]
		var spans: Array = [[x0, x1, 0.0, top]]
		for o: Dictionary in openings:
			var ox0: float = float(o.at) - float(o.w) * 0.5
			var ox1: float = float(o.at) + float(o.w) * 0.5
			var out: Array = []
			for sp: Array in spans:
				var s0: float = sp[0]
				var s1: float = sp[1]
				if s1 <= ox0 or s0 >= ox1:
					out.append(sp)
					continue
				if s0 < ox0:
					out.append([s0, ox0, sp[2], sp[3]])
				if s1 > ox1:
					out.append([ox1, s1, sp[2], sp[3]])
				var m0 := maxf(s0, ox0)
				var m1 := minf(s1, ox1)
				out.append([m0, m1, 0.0, minf(float(o.sill), top)])
				if top > float(o.top) + 0.05:
					out.append([m0, m1, float(o.top), top])
			spans = out
		for sp: Array in spans:
			var s0: float = sp[0]
			var s1: float = sp[1]
			var y0: float = sp[2]
			var y1: float = sp[3]
			if s1 - s0 < 0.02 or y1 - y0 < 0.02:
				continue
			var cl := a + along * ((s0 + s1) * 0.5) + Vector3.UP * ((y0 + y1) * 0.5) + inward * (t * 0.5)
			k.box(key, xf * cl, Vector3(s1 - s0 + 0.004, y1 - y0, t), wb, true, shade * rng.randf_range(0.92, 1.0))
			if ruin > 0.0 and absf(y1 - top) < 0.001 and s1 - s0 > 0.3:
				k.broken_crown(key, xf * (cl + Vector3.UP * ((y1 - y0) * 0.5)), wb, s1 - s0, t, rng, shade)
	for o: Dictionary in openings:
		var mid := a + along * float(o.at)
		var top_ok := true
		for i in n:
			var cx := length * (float(i) + 0.5) / float(n)
			if absf(cx - float(o.at)) < float(o.w) * 0.5 + 0.3 and heights[i] < float(o.top) + 0.25:
				top_ok = false
		var beam := "lore_char" if state == "burned" else "lore_beam"
		if top_ok:
			k.box(beam, xf * (mid + Vector3.UP * (float(o.top) + 0.1) + inward * (t * 0.5)), Vector3(float(o.w) + 0.5, 0.2, t + 0.04), wb, false, 0.75)
		if float(o.sill) > 0.0:
			k.box(key, xf * (mid + Vector3.UP * (float(o.sill) - 0.03) + inward * (t * 0.5 - 0.06)), Vector3(float(o.w) + 0.2, 0.08, t + 0.14), wb, false, 0.8 * shade)
		var pc := mid + inward * (t * 0.5) + Vector3.UP * ((float(o.sill) + float(o.top)) * 0.5)
		var oh := float(o.top) - float(o.sill)
		if top_ok and not o.get("door", false):
			# a timber window frame set in the reveal
			var fbeam := "lore_char" if state == "burned" else "lore_beam"
			for sg: float in [-1.0, 1.0]:
				k.box(fbeam, xf * (pc + along * (sg * (float(o.w) * 0.5 - 0.04)) - inward * 0.12), Vector3(0.08, oh, 0.1), wb, false, 0.66)
			k.box(fbeam, xf * (pc + Vector3.UP * (oh * 0.5 - 0.04) - inward * 0.12), Vector3(float(o.w), 0.08, 0.1), wb, false, 0.66)
		elif top_ok:
			for sg2: float in [-1.0, 1.0]:
				k.box("lore_beam", xf * (pc + along * (sg2 * (float(o.w) * 0.5 + 0.02)) - inward * (t * 0.5 - 0.04)), Vector3(0.12, oh + 0.04, 0.14), wb, false, 0.6)
		if o.get("door", false):
			k.box(key, xf * (mid + Vector3.UP * 0.03 + inward * (t * 0.5)), Vector3(float(o.w), 0.06, t + 0.2), wb, false, 0.72 * shade)   # threshold
			if state == "dark" or state == "lit":
				# plank door, shut, barred across with a timber
				k.box("lore_beam", xf * pc, Vector3(float(o.w) - 0.04, oh - 0.02, 0.1), wb, true, 0.62)
				for q in 4:
					k.box("lore_beam", xf * (pc - inward * 0.055 + along * ((float(q) - 1.5) * 0.25)), Vector3(0.02, oh - 0.06, 0.012), wb, false, 0.45)
				for yy: float in [0.4, 1.6]:
					k.box("iron", xf * (pc - inward * 0.06 + Vector3.UP * (yy - oh * 0.5)), Vector3(float(o.w) * 0.8, 0.05, 0.02), wb, false, 0.7)
				if state == "dark":
					k.box("lore_beam", xf * (pc - inward * 0.12 + Vector3.UP * 0.05), Vector3(float(o.w) + 0.5, 0.14, 0.1), wb * Basis(Vector3.BACK, 0.12), false, 0.7)
			elif state == "ruin":
				# the door hangs from one hinge
				var hinge := a + along * (float(o.at) - float(o.w) * 0.5) + inward * (t + 0.05)
				var leaf := xf.basis * Basis(Vector3.UP, -1.9) * Basis(Vector3.BACK, 0.12) * lb
				k.box("lore_beam", xf * hinge + leaf.x * (float(o.w) * 0.5) + Vector3.UP * (oh * 0.45), Vector3(float(o.w) - 0.06, oh - 0.3, 0.08), leaf, false, 0.6)
		else:
			if state == "dark":
				# shutters closed
				for sgn: float in [-1.0, 1.0]:
					k.box("lore_beam", xf * (pc - inward * 0.02 + along * (sgn * float(o.w) * 0.25)), Vector3(float(o.w) * 0.5 - 0.02, oh, 0.06), wb, false, 0.6)
				k.box("iron", xf * (pc - inward * 0.06), Vector3(float(o.w) * 0.8, 0.05, 0.03), wb, false, 0.6)
			elif state == "lit":
				var hwv := along * (float(o.w) * 0.5)
				var hh := Vector3.UP * (oh * 0.5)
				var pg := pc + inward * 0.08
				# four mullioned panes (was one flat glow card)
				for sx: float in [-0.5, 0.5]:
					for sy: float in [-0.5, 0.5]:
						var c2 := pg + along * (float(o.w) * 0.25 * sx) + Vector3.UP * (oh * 0.25 * sy)
						var pw := hwv * 0.46
						var ph := hh * 0.46
						k.quad("glow", xf * (c2 - pw - ph), xf * (c2 + pw - ph), xf * (c2 + pw + ph), xf * (c2 - pw + ph), xf.basis * -inward, false, 0.22)
				var mouth: Vector3 = xf * (pc - inward * 0.2)
				Interiors.shaft(L.holder, "CotTrail_%d_%d" % [int(mouth.x * 4.0), int(mouth.z * 4.0)], mouth, xf.basis * (-inward) + Vector3(0.0, -0.55, 0.0), Color(1.0, 0.58, 0.24), 0.85, 9.5, 20.0)
				# the window's own warmth on the wall round it: the shaft only lights the ground, and the gable and
				# back walls (off the moon and the lamps) stood as flat black silhouettes round a lit pane
				L.light("CotGlow_%d_%d" % [int(mouth.x * 4.0), int(mouth.z * 4.0)], xf * (pc - inward * 0.6), Color(1.0, 0.58, 0.26), 0.42, 3.6)
				k.box("iron", xf * (pc + inward * 0.04), Vector3(0.04, oh, 0.04), wb, false, 0.5)
				k.box("iron", xf * (pc + inward * 0.04), Vector3(float(o.w), 0.04, 0.04), wb, false, 0.45)
				k.box("iron", xf * (pc + inward * 0.04 + Vector3.UP * (oh * 0.1)), Vector3(float(o.w), 0.04, 0.04), wb, false, 0.5)
				# one shutter open, one hanging
				k.box("lore_beam", xf * (pc - inward * 0.05 + along * (-float(o.w) * 0.5 - 0.22)), Vector3(0.42, oh, 0.05), wb * Basis(Vector3.UP, 0.5), false, 0.6)


## Gable roof, ridge along local x: individual slates (a few slipped or gone when the house
## has gone dark) or a layered thatch with a scalloped ridge (lore_assets builders, cached),
## and a collision slab under each slope.
static func _roof(L: RefCounted, xf: Transform3D, w: float, d: float, eave: float, ridge: float, roof: String, state: String) -> void:
	var k: OssKit = L.k
	var seed_n := int(absf(xf.origin.x) * 7.0 + absf(xf.origin.z) * 13.0) % 97
	if roof == "slate":
		L.uv_add("lore_slates", LA.slate_roof(w, d, eave, ridge, seed_n, 0.07 if state == "dark" else 0.0), xf)
	else:
		var t: Dictionary = LA.thatch_roof(w, d, eave, ridge, seed_n)
		L.uv_add("lore_thatch_uv", t.thatch, xf)
		L.uv_add("lore_thatch_uv", t.under, xf)
	# the gable verge boards and the collision under each slope
	var hd := d * 0.5
	var ov := 0.45
	for s: float in [-1.0, 1.0]:
		var top := Vector3(0, ridge, 0)
		var bot := Vector3(0, eave - ov * (ridge - eave) / hd, s * (hd + ov))
		var mid := (top + bot) * 0.5
		var dv := (bot - top).normalized()
		var out := Vector3(0, absf(dv.z), -dv.y * s).normalized()
		var bb := xf.basis * Basis(Vector3.RIGHT, out, Vector3.RIGHT.cross(out)).orthonormalized()
		LK.col_box(k, xf * (mid + out * 0.2), Vector3(w + 0.7, 0.3, top.distance_to(bot)), bb)
		if roof == "slate":
			for gx: float in [-w * 0.5 - 0.36, w * 0.5 + 0.36]:
				k.box("lore_beam", xf * (Vector3(gx, 0, 0) + mid + out * 0.02), Vector3(0.05, 0.2, top.distance_to(bot) + 0.05), bb, false, 0.6)


## Exposed timber frame on a plastered wall from local a to b (outer face), standing out along
## `out`: posts at the ends and beside every opening, a sole rail, a rail over the openings, and
## braces in the blind panels.
static func _framing(L: RefCounted, xf: Transform3D, a: Vector3, b: Vector3, out: Vector3, openings: Array, h: float, beam: String) -> void:
	var k: OssKit = L.k
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var wb := xf.basis * Basis(along, Vector3.UP, out)
	var off := out * 0.035
	var posts: Array[float] = [0.2, length - 0.2]
	for o: Dictionary in openings:
		posts.append(float(o.at) - float(o.w) * 0.5 - 0.1)
		posts.append(float(o.at) + float(o.w) * 0.5 + 0.1)
	posts.sort()
	var top := minf(h, H) - 0.12
	for x in posts:
		if x < 0.1 or x > length - 0.1:
			continue
		k.box(beam, xf * (a + along * x + Vector3.UP * (top * 0.5 + 0.25) + off), Vector3(0.16, top - 0.5, 0.07), wb, false, 0.6)
	k.box(beam, xf * (a + along * (length * 0.5) + Vector3.UP * 0.55 + off), Vector3(length - 0.1, 0.14, 0.07), wb, false, 0.58)
	if h >= H - 0.1:
		k.box(beam, xf * (a + along * (length * 0.5) + Vector3.UP * 2.22 + off), Vector3(length - 0.1, 0.14, 0.07), wb, false, 0.58)
		k.box(beam, xf * (a + along * (length * 0.5) + Vector3.UP * (H - 0.08) + off), Vector3(length + 0.1, 0.18, 0.09), wb, false, 0.56)
	# braces in panels with no opening
	for i in posts.size() - 1:
		var x0: float = posts[i]
		var x1: float = posts[i + 1]
		if x1 - x0 < 0.7 or x1 - x0 > 2.6:
			continue
		var blocked := false
		for o: Dictionary in openings:
			if float(o.at) > x0 and float(o.at) < x1:
				blocked = true
		if blocked:
			continue
		var y0 := 0.62
		var y1 := minf(2.15, top - 0.1)
		var flip := i % 2 == 0
		var p0 := a + along * (x0 + 0.08) + Vector3.UP * (y0 if flip else y1)
		var p1 := a + along * (x1 - 0.08) + Vector3.UP * (y1 if flip else y0)
		var dd := p1 - p0
		var bb := xf.basis * Basis(dd.normalized(), out.cross(dd.normalized()).normalized(), out).orthonormalized()
		k.box(beam, xf * ((p0 + p1) * 0.5 + off * 0.9), Vector3(dd.length(), 0.13, 0.06), bb, false, 0.56)

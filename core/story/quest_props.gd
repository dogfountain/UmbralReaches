extends RefCounted
## Small things the tasks put in the world (story; no class_name): Edda's tongs, name-slates, the
## Keg's mugs and chalk circles, Father Harrow's lantern, Oswin's staff. Built from OssKit boxes in
## the kit's existing materials (iron, wood, slate, stone, plaster, glow, dark), so they add no
## shader; no collision, faded out past `FAR`. Everything is built around the holder's origin.
## Load by path: const QuestProps := preload("res://core/story/quest_props.gd")

const FAR := 45.0


## A holder named `n` under `parent` at `xf`, with the mesh for `kind` ("tongs", "slate", "mug",
## "mug_full", "lantern", "lantern_lit", "slabs", "staff", "place"; r33: "coal", "loaf", "clapper").
static func make(parent: Node3D, n: String, kind: String, xf: Transform3D) -> Node3D:
	var h := Node3D.new()
	h.name = n
	parent.add_child(h)
	h.global_transform = xf
	var k := OssKit.new()
	k.keep_lanes = false
	match kind:
		"tongs":
			_tongs(k, Vector3.ZERO, 0.0)
		"slate":
			_slate(k, Vector3.ZERO)
		"mug":
			_chalk(k, Vector3.ZERO, 0.38)
			# on its side, mouth toward the green
			var b := Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, 0.4)
			_mug(k, Vector3(0.0, 0.055, 0.0), b, false)
		"mug_full":
			_chalk(k, Vector3.ZERO, 0.32)
			_mug(k, Vector3(0.0, 0.07, 0.0), Basis.IDENTITY, true)
		"lantern":
			_lantern(k, Vector3(0, 0.1, 0), Basis(Vector3.FORWARD, 1.35), false)
		"lantern_lit":
			_lantern(k, Vector3(0, 0.13, 0), Basis.IDENTITY, true)
		"slabs":
			for i in 3:
				var o := Vector3(float(i - 1) * 0.62, 0.0, 0.08 * float(i % 2))
				var bs := Basis(Vector3.UP, 0.08 * float(i - 1)) * Basis(Vector3.RIGHT, -0.06 + 0.04 * float(i))
				# new-cut stone, pale against the old ones; the name cut in two dark lines, a third short
				k.box("stone", o + bs * Vector3(0, 0.3, 0), Vector3(0.42, 0.6, 0.12), bs, false, 1.0)
				k.box("stone", o + bs * Vector3(0, 0.63, 0), Vector3(0.3, 0.06, 0.1), bs, false, 0.9)
				k.box("dark", o + bs * Vector3(0, 0.44, -0.061), Vector3(0.24, 0.022, 0.006), bs, false, 1.0)
				k.box("dark", o + bs * Vector3(0, 0.38, -0.061), Vector3(0.2, 0.018, 0.006), bs, false, 1.0)
				k.box("dark", o + bs * Vector3(-0.04, 0.32, -0.061), Vector3(0.11, 0.018, 0.006), bs, false, 1.0)
		"staff":
			var sb := Basis(Vector3.RIGHT, -0.22) * Basis(Vector3.FORWARD, 0.06)
			k.box("wood", sb * Vector3(0, 0.85, 0), Vector3(0.045, 1.7, 0.045), sb, false, 0.85)
			k.box("plaster", sb * Vector3(0, 1.45, 0), Vector3(0.06, 0.12, 0.06), sb, false, 0.6)
			k.box("wood", Vector3(0.25, 0.06, 0.35), Vector3(0.28, 0.12, 0.2), Basis(Vector3.UP, 0.5), false, 0.6)   # his satchel, left behind
		"waystone":
			# a pilgrims' waystone: weathered pillar, a worn cap, XLI cut on the face toward the road,
			# a little cairn of offering pebbles at its foot
			var lean := Basis(Vector3.FORWARD, 0.05) * Basis(Vector3.RIGHT, -0.04)
			k.box("stone", lean * Vector3(0, 0.5, 0), Vector3(0.36, 1.0, 0.26), lean, false, 0.82)
			k.box("stone", lean * Vector3(0, 1.04, 0), Vector3(0.42, 0.1, 0.32), lean, false, 0.7)
			k.box("stone", Vector3(0, 0.06, 0), Vector3(0.56, 0.12, 0.44), Basis(Vector3.UP, 0.1), false, 0.6)
			var face := lean * Vector3(0, 0.0, -0.132)
			var cut := func(c: Vector3, sz: Vector3, rot: float) -> void:
				k.box("dark", lean * c + face, sz, lean * Basis(Vector3.FORWARD, rot), false, 1.0)
			# X
			cut.call(Vector3(-0.1, 0.78, 0), Vector3(0.016, 0.16, 0.008), 0.5)
			cut.call(Vector3(-0.1, 0.78, 0), Vector3(0.016, 0.16, 0.008), -0.5)
			# L
			cut.call(Vector3(0.0, 0.78, 0), Vector3(0.016, 0.15, 0.008), 0.0)
			cut.call(Vector3(0.035, 0.71, 0), Vector3(0.07, 0.016, 0.008), 0.0)
			# I
			cut.call(Vector3(0.11, 0.78, 0), Vector3(0.016, 0.15, 0.008), 0.0)
			for i in 6:
				var a := float(i) * 1.05
				k.box("stone", Vector3(cos(a) * 0.12 + 0.05, 0.14 + 0.03 * float(i % 2), -0.3 + sin(a) * 0.08), Vector3(0.07, 0.05, 0.06), Basis(Vector3.UP, a), false, 0.75)
		"coal":
			# r33: a live coal in a shallow iron dish with a ring handle
			k.box("iron", Vector3(0, 0.03, 0), Vector3(0.26, 0.04, 0.26), Basis(Vector3.UP, 0.4), false, 0.55)
			k.box("iron", Vector3(0.17, 0.04, 0), Vector3(0.12, 0.02, 0.03), Basis(Vector3.UP, 0.4), false, 0.5)
			for i in 4:
				var a := float(i) * 1.6
				k.box("glow", Vector3(cos(a) * 0.05, 0.07, sin(a) * 0.05), Vector3(0.07, 0.05, 0.06), Basis(Vector3.UP, a), false, 0.9)
		"loaf":
			# r33: the Almonry's last loaf on a board, a cross cut in the crust
			k.box("wood", Vector3(0, 0.02, 0), Vector3(0.42, 0.04, 0.3), Basis(Vector3.UP, 0.2), false, 0.7)
			k.box("plaster", Vector3(0, 0.09, 0), Vector3(0.24, 0.1, 0.16), Basis(Vector3.UP, 0.2), false, 0.62)
			k.box("dark", Vector3(0, 0.142, 0), Vector3(0.16, 0.006, 0.014), Basis(Vector3.UP, 0.2), false, 1.0)
			k.box("dark", Vector3(0, 0.142, 0), Vector3(0.014, 0.006, 0.11), Basis(Vector3.UP, 0.2), false, 1.0)
		"clapper":
			# r33: a drowned bell's iron tongue lying in the reeds: a long shank, a heavy bulb
			var cb := Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, PI * 0.5)
			k.box("iron", cb * Vector3(0, 0.0, -0.06) + Vector3(0, 0.05, 0), Vector3(0.05, 0.62, 0.05), cb, false, 0.45)
			k.box("iron", cb * Vector3(0, -0.36, -0.06) + Vector3(0, 0.08, 0), Vector3(0.15, 0.17, 0.15), cb, false, 0.4)
			k.box("iron", cb * Vector3(0, 0.33, -0.06) + Vector3(0, 0.05, 0), Vector3(0.1, 0.05, 0.03), cb, false, 0.5)
		# r36 Act II: one of the Founder's bells, hung low on a timber frame (the pickup opens its
		# conversation: ring it, or carry the tongue)
		"bell":
			for sx: float in [-0.62, 0.62]:
				k.box("wood", Vector3(sx, 0.75, 0), Vector3(0.12, 1.5, 0.12), Basis.IDENTITY, false, 0.7)
			k.box("wood", Vector3(0, 1.52, 0), Vector3(1.5, 0.12, 0.14), Basis.IDENTITY, false, 0.7)
			# the bell, stepped from crown to lip; r36: it hangs from the beam (a headstock pin at
			# 1.46) and swings, barely in the wind, hard when it is rung (`ring_bell`)
			var hs := 1.46
			var sw := Sway.bell(h, h.global_transform * Vector3(0, hs, 0), h.global_basis.get_euler().y, 2.2)
			var kb := OssKit.new()
			kb.keep_lanes = false
			kb.box("iron", Vector3(0, 1.43 - hs, 0), Vector3(0.1, 0.06, 0.1), Basis.IDENTITY, false, 0.45)
			var rows := [[1.36, 0.16, 0.09], [1.24, 0.3, 0.12], [1.08, 0.42, 0.16], [0.92, 0.5, 0.16], [0.79, 0.62, 0.08]]
			for i in rows.size():
				var row: Array = rows[i]
				for j in 2:
					kb.box("iron", Vector3(0, float(row[0]) - hs, 0), Vector3(float(row[1]), float(row[2]), float(row[1])), Basis(Vector3.UP, 0.785 * float(j)), false, 0.42 + 0.03 * float(i))
			kb.box("iron", Vector3(0, 0.66 - hs, 0), Vector3(0.06, 0.2, 0.06), Basis.IDENTITY, false, 0.4)
			sw.take(kb, FAR)
			for c in sw.get_children():
				if c is GeometryInstance3D:
					(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# r34: the new regions' finds
		"ward":
			# a Rooted ward-stone: a rounded grey stone, a spiral pecked in its face (pale cuts)
			var wb := Basis(Vector3.RIGHT, -0.2)
			k.box("stone", wb * Vector3(0, 0.11, 0), Vector3(0.36, 0.22, 0.28), wb, false, 0.72)
			k.box("stone", wb * Vector3(0, 0.2, 0), Vector3(0.28, 0.06, 0.22), wb, false, 0.66)
			for i in 6:
				var a := float(i) * 1.15
				var rr := 0.03 + 0.016 * float(i)
				k.box("plaster", wb * Vector3(cos(a) * rr, 0.13 + sin(a) * rr, -0.142), Vector3(0.04, 0.014, 0.004), wb * Basis(Vector3.BACK, a), false, 0.9)
		"mark":
			# a squared block left on the bench, a cutter's mark on its end
			k.box("stone", Vector3(0, 0.22, 0), Vector3(0.9, 0.44, 0.52), Basis(Vector3.UP, 0.1), false, 0.9)
			k.box("stone", Vector3(0.06, 0.45, 0.02), Vector3(0.7, 0.02, 0.4), Basis(Vector3.UP, 0.1), false, 0.8)
			var mb := Basis(Vector3.UP, 0.1)
			k.box("dark", mb * Vector3(-0.451, 0.26, 0.0), Vector3(0.006, 0.16, 0.02), mb, false, 1.0)
			k.box("dark", mb * Vector3(-0.451, 0.32, 0.05), Vector3(0.006, 0.02, 0.1), mb, false, 1.0)
			k.box("dark", mb * Vector3(-0.451, 0.22, -0.06), Vector3(0.006, 0.02, 0.08), mb, false, 1.0)
		"cairn":
			# a cairn knocked down: a spread of flat moor stones, one still standing on another
			for i in 7:
				var a := float(i) * 0.9
				var rr := 0.15 + 0.12 * float(i % 3)
				k.box("stone", Vector3(cos(a) * rr, 0.05, sin(a) * rr), Vector3(0.22, 0.1, 0.16), Basis(Vector3.UP, a * 1.7) * Basis(Vector3.RIGHT, 0.15 * float(i % 2)), false, 0.65 + 0.05 * float(i % 3))
			k.box("stone", Vector3(0.02, 0.15, 0.0), Vector3(0.2, 0.1, 0.15), Basis(Vector3.UP, 0.4), false, 0.75)
		"mould":
			# a cheek of a bell mould: a curved shell of fired loam in an iron cage
			for i in 5:
				var a := -0.6 + 0.3 * float(i)
				var cb2 := Basis(Vector3.UP, a)
				k.box("plaster", cb2 * Vector3(0, 0.18, -0.32), Vector3(0.16, 0.36, 0.06), cb2 * Basis(Vector3.RIGHT, 0.12), false, 0.55)
			k.box("iron", Vector3(0, 0.37, -0.28), Vector3(0.62, 0.025, 0.08), Basis.IDENTITY, false, 0.5)
			k.box("iron", Vector3(0, 0.03, -0.3), Vector3(0.66, 0.025, 0.08), Basis.IDENTITY, false, 0.5)
		"bud":
			# a burned limb on the ash, one green eye at the cut
			k.box("dark", Vector3(0, 0.04, 0), Vector3(0.07, 0.07, 0.62), Basis(Vector3.UP, 0.5), false, 0.8)
			k.box("wood", Vector3(-0.14, 0.05, -0.23), Vector3(0.05, 0.05, 0.18), Basis(Vector3.UP, 1.2), false, 0.6)
			(load("res://core/world/realm/lore/lore_kit.gd") as GDScript).call("ensure_mats")
			k.box("lore_moss", Vector3(0.12, 0.1, 0.22), Vector3(0.05, 0.06, 0.05), Basis(Vector3.UP, 0.5), false, 1.0)
		"page":
			# a page of the roll under a stone, its corner lifting
			k.box("plaster", Vector3(0, 0.01, 0), Vector3(0.24, 0.006, 0.32), Basis(Vector3.UP, 0.3), false, 0.9)
			k.box("plaster", Vector3(0.09, 0.02, -0.13), Vector3(0.08, 0.004, 0.07), Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, 0.4), false, 0.95)
			for i in 4:
				k.box("dark", Vector3(-0.01, 0.0145, 0.08 - 0.05 * float(i)), Vector3(0.16, 0.002, 0.01), Basis(Vector3.UP, 0.3), false, 1.0)
			k.box("stone", Vector3(-0.06, 0.05, 0.1), Vector3(0.12, 0.08, 0.1), Basis(Vector3.UP, 0.9), false, 0.7)
		"place":
			pass
	if kind != "place":
		k.commit(h, "Body")
	for c in h.get_children():
		if c is GeometryInstance3D:
			var gi := c as GeometryInstance3D
			gi.visibility_range_end = FAR
			gi.visibility_range_end_margin = 6.0
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return h


## r36: swing a bell prop (kind "bell") as if it had just been rung.
static func ring_bell(holder: Node, k := 1.0) -> void:
	if holder == null:
		return
	for c in holder.get_children():
		if c is Sway:
			(c as Sway).ring(k)


## A faint drift of motes over something a task wants found (one small emitter, warm).
static func glint(parent: Node3D, warm := true) -> GPUParticles3D:
	var col := Color(1.0, 0.78, 0.42, 0.7) if warm else Color(0.75, 0.82, 1.0, 0.6)
	var p := Vfx.emitter(col, {"count": 6, "life": 1.8, "speed": Vector2(0.04, 0.18), "size": 0.032, "gravity": -0.22, "radius": 0.22, "additive": true, "spread": 35.0, "dir": Vector3.UP})
	if p == null:
		return null
	p.name = "Glint"
	parent.add_child(p)
	p.position = Vector3(0, 0.15, 0)
	p.visibility_range_end = 30.0
	p.emitting = true
	return p


static func _tongs(k: OssKit, at: Vector3, yaw: float) -> void:
	# two long iron arms crossed at the rivet, jaws burned dark, handles wrapped in cloth
	for s: float in [-1.0, 1.0]:
		var b := Basis(Vector3.UP, yaw + s * 0.17)
		k.box("iron", at + b * Vector3(0, 0.018, 0.0), Vector3(0.028, 0.016, 0.5), b, false, 0.55)
		k.box("dark", at + b * Vector3(s * 0.01, 0.02, -0.27), Vector3(0.04, 0.03, 0.07), b, false, 0.7)
		k.box("plaster", at + b * Vector3(0, 0.022, 0.17), Vector3(0.038, 0.03, 0.14), b, false, 0.55)
	k.box("iron", at + Vector3(0, 0.03, -0.12), Vector3(0.035, 0.035, 0.035), Basis(Vector3.UP, yaw), false, 0.6)


static func _slate(k: OssKit, at: Vector3) -> void:
	var b := Basis(Vector3.RIGHT, -0.32) * Basis(Vector3.FORWARD, 0.05)
	k.box("slate", at + b * Vector3(0, 0.2, 0), Vector3(0.34, 0.42, 0.035), b, false, 0.85)
	k.box("plaster", at + b * Vector3(0, 0.27, -0.019), Vector3(0.22, 0.018, 0.004), b, false, 1.0)
	k.box("plaster", at + b * Vector3(-0.02, 0.21, -0.019), Vector3(0.17, 0.016, 0.004), b, false, 1.0)
	k.box("plaster", at + b * Vector3(0.03, 0.15, -0.019), Vector3(0.12, 0.016, 0.004), b, false, 1.0)
	k.box("stone", at + Vector3(0.0, 0.04, 0.09), Vector3(0.3, 0.08, 0.16), Basis(Vector3.UP, 0.2), false, 0.7)


static func _mug(k: OssKit, at: Vector3, b: Basis, full: bool) -> void:
	# a stave mug: eight staves round a base, two iron hoops, a handle
	for i in 8:
		var a := TAU * float(i) / 8.0
		var sb := b * Basis(Vector3.UP, a)
		k.box("wood", at + sb * Vector3(0, 0.0, -0.045), Vector3(0.036, 0.13, 0.012), sb, false, 0.8 + 0.06 * float(i % 2))
	for y: float in [-0.04, 0.045]:
		k.box("iron", at + b * Vector3(0, y, 0), Vector3(0.1, 0.012, 0.1), b, false, 0.6)
	k.box("wood", at + b * Vector3(0.065, 0.0, 0), Vector3(0.016, 0.09, 0.03), b, false, 0.75)
	if full:
		k.box("dark", at + b * Vector3(0, 0.055, 0), Vector3(0.082, 0.004, 0.082), b, false, 1.0)


static func _chalk(k: OssKit, at: Vector3, r: float) -> void:
	# a child's chalk circle: short thick strokes, not quite closed
	for i in 15:
		var a := TAU * float(i) / 16.0 + 0.2
		var b := Basis(Vector3.UP, -a)
		var p := at + Vector3(cos(a), 0.0, sin(a)) * (r + 0.015 * sin(float(i) * 2.3))
		k.box("plaster", p + Vector3.UP * 0.004, Vector3(0.03, 0.006, r * 0.42), b, false, 1.1)


static func _lantern(k: OssKit, at: Vector3, b: Basis, lit: bool) -> void:
	k.box("iron", at + b * Vector3(0, -0.11, 0), Vector3(0.16, 0.02, 0.16), b, false, 0.55)
	k.box("iron", at + b * Vector3(0, 0.11, 0), Vector3(0.17, 0.025, 0.17), b, false, 0.55)
	k.box("iron", at + b * Vector3(0, 0.15, 0), Vector3(0.08, 0.05, 0.08), b, false, 0.55)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box("iron", at + b * Vector3(sx * 0.072, 0, sz * 0.072), Vector3(0.016, 0.22, 0.016), b, false, 0.5)
	k.box("glow" if lit else "slate", at + b * Vector3(0, 0, 0), Vector3(0.12, 0.19, 0.12), b, false, 0.95 if lit else 0.35)
	k.box("iron", at + b * Vector3(0, 0.21, 0), Vector3(0.11, 0.012, 0.012), b, false, 0.5)

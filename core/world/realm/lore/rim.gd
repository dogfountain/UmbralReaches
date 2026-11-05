extends RefCounted
## The rim of the Ashen Rift, where the rift_rim path leaves Hearthward for the Crossing: the
## Last Bell (a great bronze bell off the Stair, cracked, lying on its lip in the ash, its yoke
## broken and its tongue torn out) and the Hierarch's third edict on a stele, cut the morning of
## the Night. Kept off the rift itself (z > -11), the path and every site.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "RiftRim", 2020)
	var k: OssKit = L.k
	var ba: Vector3 = L.spot_any("rim_bell", [Vector2(-7.0, -3.0), Vector2(7.5, -3.5), Vector2(-7.5, 3.0), Vector2(8.0, 2.0), Vector2(-9.0, -7.0)], 2.0, 0.4)
	if ba != Vector3.INF:
		var yaw := atan2(-ba.x, 0.0) + 0.6
		var b := Basis(Vector3.UP, yaw)
		# the bell, tipped on its side: a flared bronze profile, mouth toward the path
		var bell: ArrayMesh = LK.pooled("great_bell", func() -> ArrayMesh:
			var cm := CreatureMesh.new(88)
			cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.12, 0), Vector3(0, 0.5, 0), Vector3(0, 0.95, 0), Vector3(0, 1.2, 0), Vector3(0, 1.3, 0)]),
				PackedFloat32Array([0.78, 0.72, 0.6, 0.52, 0.42, 0.18]), 20, Color(1, 1, 1), 0.0, 0.02)
			cm.tube(PackedVector3Array([Vector3(0, 0.02, 0), Vector3(0, 0.1, 0)]), PackedFloat32Array([0.8, 0.79]), 20, Color(0.8, 0.8, 0.8), 0.0, 0.0)   # sound bow
			cm.tube(PackedVector3Array([Vector3(0, 0.62, 0), Vector3(0, 0.68, 0)]), PackedFloat32Array([0.58, 0.575]), 20, Color(0.85, 0.85, 0.85), 0.0, 0.0)   # band
			cm.tube(PackedVector3Array([Vector3(-0.16, 1.28, 0), Vector3(0, 1.5, 0), Vector3(0.16, 1.28, 0)]), PackedFloat32Array([0.06, 0.06, 0.06]), 6, Color(0.8, 0.8, 0.8), 0.0, 0.0)   # crown loop
			return cm.commit())
		var lie := b * Basis(Vector3.BACK, PI * 0.5 - 0.12)
		var bxf := Transform3D(lie, ba + Vector3.UP * 0.58 + b * Vector3(0.0, 0, 0))
		LK.organic(k, "lore_bronze", bell, bxf, false)
		LK.col_box(k, ba + Vector3.UP * 0.55, Vector3(1.4, 1.1, 1.4), b)
		# the crack, a dark seam down the waist; ash drifted against it
		k.box("dark", bxf * Vector3(0.0, 0.55, -0.56), Vector3(0.05, 0.75, 0.04), lie * Basis(Vector3.BACK, 0.25), false, 0.1)
		L.rubble(L.p, ba + b * Vector3(-0.8, 0, 0.9), 1.0, 7, "lore_rock")
		# the broken yoke (headstock) beside it
		k.box("lore_char", ba + b * Vector3(1.6, 0.18, -0.6), Vector3(1.9, 0.3, 0.32), b * Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.1), true, 0.6)
		k.box("iron", ba + b * Vector3(1.3, 0.36, -0.4), Vector3(0.5, 0.06, 0.08), b * Basis(Vector3.UP, 0.5), false, 0.6)
		k.candle_cluster(ba + b * Vector3(-0.2, 0.0, -1.1), 3, 0.15, L.rng)
		L.scrap("rim_bell", ba + b * Vector3(-0.4, 0.3, -1.8), ba + Vector3.UP * 1.1)
	var ea: Vector3 = L.spot_any("rim_edict", [Vector2(-6.0, 9.0), Vector2(6.5, -1.0), Vector2(-6.5, 13.0), Vector2(6.5, 12.0)], 0.9, 0.4)
	if ea != Vector3.INF:
		var d := Vector2(0.0, ea.z) - Vector2(ea.x, ea.z)
		var fp: Vector3 = L.stele(ea, atan2(-d.x, -d.y), 2.3)
		L.scrap("rim_edict_3", ea + Vector3(signf(-ea.x) * 1.3, 0.3, 0.0), fp + Vector3.UP * 0.5)
	L.finish()
	L.note("The Rift's Rim", Vector3(0, 0, 0))

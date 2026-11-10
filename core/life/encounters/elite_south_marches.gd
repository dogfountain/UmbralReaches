extends RefCounted
## The South pass's two named elites: their pieces on the rig (Elites._build asks for them).
##   root_wife    bark antlers and hanging moss on the head, a shawl of root and a heartwood knot on the
##                chest, a gnarled root-staff in the hand
##   well_answer  a veil and three struck-bronze halos on the head, a hanging bell on the chest, a
##                tuning-fork in the hand
## Built from CreatureMesh as the other elites are (Variants.cm); the parts are cached by Elites.

const Variants := preload("res://core/life/encounters/variants.gd")
const BARK := Color(0.3, 0.22, 0.16)
const BARK_LIT := Color(0.42, 0.32, 0.22)
const MOSS := Color(0.16, 0.26, 0.12)
const HEART := Color(0.55, 0.36, 0.2)
const BRONZE := Color(0.5, 0.36, 0.18)
const VEIL := Color(0.62, 0.66, 0.7)


static func build(id: String, _rig: CharacterRig, sd: int) -> Dictionary:
	var parts := {}
	match id:
		"root_wife":
			var h: CreatureMesh = Variants.cm(sd)
			# a crown of bark antlers, branching, one snapped
			for side: float in [-1.0, 1.0]:
				var base := Vector3(side * 0.07, 0.1, 0.0)
				var tip := base + Vector3(side * 0.22, 0.5, 0.1)
				h.tube(PackedVector3Array([base, base.lerp(tip, 0.45) + Vector3(side * 0.06, 0.0, 0.0), tip]), PackedFloat32Array([0.034, 0.024, 0.0]), 6, BARK, 1.0, 0.1)
				for k in 4:
					var t := 0.3 + 0.17 * float(k)
					var p := base.lerp(tip, t)
					h.claw(p, Vector3(side * (0.5 + 0.2 * float(k % 2)), 0.7, -0.3 + 0.25 * float(k)).normalized(), 0.15 - 0.02 * float(k), 0.013, Vector3(0, 0.05, 0), BARK_LIT)
			# hair of moss
			for k in 9:
				var ang := TAU * float(k) / 9.0
				h.strand(Vector3(cos(ang) * 0.1, 0.1, sin(ang) * 0.09), Vector3(cos(ang) * 0.4, -1.0, sin(ang) * 0.3).normalized(), 0.3 + 0.08 * float(k % 3), 0.035, 0.03, MOSS, 1.0, 0.3, 5)
			parts["head"] = h.commit()
			var c: CreatureMesh = Variants.cm(sd + 1)
			var f := Variants.chest_front("husk")
			# the heartwood knot, a slow glow, and root cords wound round the ribs
			c.blob(Vector3(0.0, -0.02, -f - 0.04), Vector3(0.11, 0.1, 0.06), Basis.IDENTITY, HEART, 1.0, 0.14, 0.0, 6, 10)
			c.blob(Vector3(0.0, -0.02, -f - 0.1), Vector3(0.03, 0.03, 0.02), Basis.IDENTITY, Color(0.3, 0.55, 0.2), 0.0, 0.0, 0.6, 4, 6)
			c.wrap(Vector3(-0.26, 0.14, -0.02), Vector3(0.26, -0.2, -0.02), 0.24, 0.55, 0.02, BARK)
			c.wrap(Vector3(0.26, 0.14, -0.02), Vector3(-0.26, -0.2, -0.02), 0.24, 0.55, 0.02, BARK_LIT)
			for k in 14:
				var ang := TAU * float(k) / 14.0
				var o := Vector3(cos(ang) * 0.26, 0.12 - 0.1 * float(k % 3), sin(ang) * 0.22)
				c.strand(o, Vector3(cos(ang) * 0.2, -1.0, sin(ang) * 0.2).normalized(), 0.32 + 0.1 * float(k % 3), 0.035, 0.02, MOSS, 1.0, 0.3, 5)
			parts["chest"] = c.commit()
			var s: CreatureMesh = Variants.cm(sd + 2)
			s.tube(PackedVector3Array([Vector3(0, 0.1, 0), Vector3(0.012, -0.3, 0.01), Vector3(0, -0.7, 0.0)]), PackedFloat32Array([0.03, 0.026, 0.02]), 6, BARK, 1.0, 0.12)
			for k in 3:
				s.claw(Vector3(0, 0.08 - 0.05 * float(k), 0.0), Vector3(0.7 * (float(k) - 1.0), 0.6, 0.3).normalized(), 0.14, 0.012, Vector3(0, 0.04, 0), BARK_LIT)
			parts["hand_r"] = s.commit()
		"well_answer":
			var h: CreatureMesh = Variants.cm(sd)
			# a veil over the face, and three halos of struck bronze, one inside the next
			h.blob(Vector3(0, 0.05, 0.03), Vector3(0.15, 0.16, 0.16), Basis.IDENTITY, VEIL, 0.0, 0.2, 0.0, 7, 12, 1.0)
			for k in 3:
				Variants._ring(h, Vector3(0, 0.12 + 0.02 * float(k), 0.0), 0.2 + 0.07 * float(k), 0.007, BRONZE, 0.7 - 0.2 * float(k), 1.0)
			parts["head"] = h.commit()
			var c: CreatureMesh = Variants.cm(sd + 1)
			var f := Variants.chest_front("spitter")
			# a bell hung from a cord at the breast, the clapper a pale drop
			c.tube(PackedVector3Array([Vector3(-0.1, 0.18, -0.02), Vector3(0.0, 0.1, -f - 0.02), Vector3(0.1, 0.18, -0.02)]), PackedFloat32Array([0.008, 0.008, 0.008]), 4, Color(0.3, 0.22, 0.14), 1.0, 0.0)
			c.blob(Vector3(0, -0.04, -f - 0.04), Vector3(0.07, 0.085, 0.07), Basis.IDENTITY, BRONZE, 1.0, 0.05, 0.0, 6, 10)
			c.blob(Vector3(0, -0.12, -f - 0.04), Vector3(0.012, 0.016, 0.012), Basis.IDENTITY, Color(0.7, 0.8, 0.9), 0.0, 0.0, 0.7, 4, 6)
			for k in 8:
				var ang := TAU * float(k) / 8.0
				c.strand(Vector3(cos(ang) * 0.12, 0.1, sin(ang) * 0.1), Vector3(cos(ang) * 0.25, -1.0, sin(ang) * 0.2).normalized(), 0.36, 0.04, 0.03, VEIL, 1.0, 0.3, 5)
			parts["chest"] = c.commit()
			var r: CreatureMesh = Variants.cm(sd + 2)
			for sx: float in [-0.018, 0.018]:
				r.tube(PackedVector3Array([Vector3(sx, -0.02, 0), Vector3(sx, -0.2, 0.0), Vector3(sx, -0.34, 0.0)]), PackedFloat32Array([0.008, 0.008, 0.008]), 4, BRONZE, 1.0, 0.0)
			r.blob(Vector3(0, -0.02, 0), Vector3(0.03, 0.014, 0.014), Basis.IDENTITY, BRONZE, 1.0, 0.0, 0.0, 4, 6)
			parts["hand_r"] = r.commit()
	return parts

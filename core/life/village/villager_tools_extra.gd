extends RefCounted
## More things for a villager's hands (the ambient folk, core/life/folk): a broom, a water bucket, a sack, a fiddle, a
## bow and a torch. Built into the villager's one skinned surface exactly as VillagerRig._tool builds the others (tube and
## blob primitives in the fist's own frame: `ax` the tool's axis through the palm, `fd` the fingers' direction, which
## is down when the hand hangs), called from its `_tool` for any kind it does not know. Static; load by path.
const DwarfMesh := preload("res://core/npc/dwarf_mesh.gd")
const WOOD := Color(0.36, 0.26, 0.17)
const IRON := Color(0.3, 0.3, 0.32)
const STRAW := Color(0.62, 0.5, 0.26)
const LINEN := Color(0.62, 0.56, 0.44)
const RESIN := Color(0.12, 0.08, 0.06)


static func pf(a: Array, m: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v: float in a:
		out.append(v * m)
	return out


## Build `kind` in the fist of `side` (0 right, 1 left). `mb` is the mesh builder; sets rig.tips[side] to the working end.
static func build(rig: Variant, mb: Variant, side: int, kind: String) -> void:
	var g: Vector3 = rig.grip[side]
	var ax: Vector3 = rig.grip_ax[side]
	var fd: Vector3 = (rig.grip_up[side] as Vector3).slide(ax).normalized()
	var cx: Vector3 = ax.cross(fd).normalized()
	var K: float = rig.k
	match kind:
		"broom":
			# a long ash handle and a head of straw bound at the neck: held with the bristles to the ground
			mb.tube(PackedVector3Array([g - ax * 0.12 * K, g + ax * 0.6 * K, g + ax * 1.18 * K]), pf([0.013, 0.014, 0.015], K), 8, WOOD, DwarfMesh.MAT_WOOD, {"lumps": 0.02})
			var nk := g + ax * 1.2 * K
			mb.tube(PackedVector3Array([nk, nk + ax * 0.05 * K]), pf([0.03, 0.03], K), 8, Color(0.3, 0.22, 0.14), DwarfMesh.MAT_LEATHER, {"lumps": 0.0})
			mb.tube(PackedVector3Array([nk + ax * 0.04 * K, nk + ax * 0.2 * K, nk + ax * 0.34 * K]), pf([0.035, 0.07, 0.085], K), 8, STRAW, DwarfMesh.MAT_LINEN, {"lumps": 0.12})
			rig.tips[side] = g + ax * 1.5 * K
		"bucket":
			# an iron bail from the fist, a staved bucket with two hoops and a dark surface of water
			var lc := g + fd * 0.24 * K
			mb.tube(PackedVector3Array([g - ax * 0.02 * K, g + fd * 0.07 * K, lc - fd * 0.02 * K]), pf([0.004, 0.004, 0.004], K), 4, IRON, DwarfMesh.MAT_METAL, {"lumps": 0.0})
			mb.tube(PackedVector3Array([lc, lc + fd * 0.2 * K]), pf([0.09, 0.066], K), 10, WOOD.lightened(0.05), DwarfMesh.MAT_WOOD, {"lumps": 0.02})
			mb.tube(PackedVector3Array([lc + fd * 0.04 * K, lc + fd * 0.05 * K]), pf([0.093, 0.093], K), 10, IRON, DwarfMesh.MAT_METAL, {"lumps": 0.0})
			mb.tube(PackedVector3Array([lc + fd * 0.15 * K, lc + fd * 0.16 * K]), pf([0.072, 0.072], K), 10, IRON, DwarfMesh.MAT_METAL, {"lumps": 0.0})
			mb.blob(lc + fd * 0.012 * K, Vector3(0.082, 0.01, 0.082) * K, Basis(cx, fd, ax).orthonormalized(), Color(0.16, 0.26, 0.4), DwarfMesh.MAT_LINEN, {"lumps": 0.0})
			rig.tips[side] = lc + fd * 0.1 * K
		"sack":
			# a grain sack hung by its tied neck from the fist: heavy, slumped at the bottom
			var nk2 := g + fd * 0.1 * K
			mb.tube(PackedVector3Array([g, nk2]), pf([0.016, 0.02], K), 6, Color(0.42, 0.33, 0.22), DwarfMesh.MAT_LEATHER, {"lumps": 0.0})
			mb.blob(nk2 + fd * 0.22 * K, Vector3(0.15, 0.22, 0.12) * K, Basis(cx, fd, ax).orthonormalized(), LINEN.darkened(0.1), DwarfMesh.MAT_LINEN, {"lumps": 0.16})
			mb.blob(nk2 + fd * 0.06 * K, Vector3(0.055, 0.045, 0.055) * K, Basis(cx, fd, ax).orthonormalized(), LINEN.darkened(0.25), DwarfMesh.MAT_LINEN, {"lumps": 0.1})
			rig.tips[side] = nk2 + fd * 0.3 * K
		"fiddle":
			# the neck in the fist, a waisted body and a scroll: held up under the chin
			mb.tube(PackedVector3Array([g - ax * 0.02 * K, g + ax * 0.16 * K, g + ax * 0.24 * K]), pf([0.011, 0.012, 0.014], K), 6, Color(0.14, 0.1, 0.08), DwarfMesh.MAT_WOOD, {"lumps": 0.0})
			mb.blob(g - ax * 0.14 * K, Vector3(0.03, 0.085, 0.1) * K, Basis(cx, fd, ax).orthonormalized(), Color(0.5, 0.28, 0.12), DwarfMesh.MAT_WOOD, {"lumps": 0.01})
			mb.blob(g - ax * 0.21 * K, Vector3(0.03, 0.065, 0.06) * K, Basis(cx, fd, ax).orthonormalized(), Color(0.5, 0.28, 0.12), DwarfMesh.MAT_WOOD, {"lumps": 0.01})
			mb.blob(g + ax * 0.26 * K, Vector3(0.014, 0.014, 0.022) * K, Basis.IDENTITY, Color(0.14, 0.1, 0.08), DwarfMesh.MAT_WOOD, {"lumps": 0.0})
			rig.tips[side] = g + ax * 0.26 * K
		"bow":
			# a fiddler's bow: a thin stick and a ribbon of horsehair
			mb.tube(PackedVector3Array([g - ax * 0.12 * K, g + ax * 0.3 * K, g + ax * 0.62 * K]), pf([0.006, 0.0055, 0.005], K), 5, Color(0.3, 0.2, 0.12), DwarfMesh.MAT_WOOD, {"lumps": 0.0})
			mb.tube(PackedVector3Array([g - ax * 0.1 * K + fd * 0.025 * K, g + ax * 0.6 * K + fd * 0.01 * K]), pf([0.0025, 0.0025], K), 4, Color(0.88, 0.85, 0.78), DwarfMesh.MAT_LINEN, {"lumps": 0.0})
			rig.tips[side] = g + ax * 0.62 * K
		"torch":
			# a wooden shaft, a wrapped head dark with pitch (the flame is the rig's glow part)
			mb.tube(PackedVector3Array([g - ax * 0.08 * K, g + ax * 0.3 * K, g + ax * 0.5 * K]), pf([0.017, 0.016, 0.02], K), 8, WOOD.darkened(0.1), DwarfMesh.MAT_WOOD, {"lumps": 0.04})
			mb.tube(PackedVector3Array([g + ax * 0.46 * K, g + ax * 0.54 * K, g + ax * 0.6 * K]), pf([0.026, 0.034, 0.024], K), 8, RESIN, DwarfMesh.MAT_LINEN, {"lumps": 0.18})
			rig.tips[side] = g + ax * 0.6 * K

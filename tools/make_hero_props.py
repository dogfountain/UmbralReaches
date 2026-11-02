"""Dedicated hero props. Bevelled primary/secondary forms, sized to live sockets.

Run: blender --background --python tools/make_hero_props.py
Writes art/blender/hero_props.blend and art/models/*.glb

Does not rewrite robe pieces, Shade, gothic_bay, toad, or the portal frames.
"""

from __future__ import annotations

import math
import os

import bpy
import bmesh
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLEND = os.path.join(ROOT, "art", "blender", "hero_props.blend")
MODELS = os.path.join(ROOT, "art", "models")


def clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete()
	for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
		for data in list(block):
			if data.users == 0:
				block.remove(data)


def mat(name: str, color, rough: float, metal: float = 0.0, emit=None, alpha: float = 1.0) -> bpy.types.Material:
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = metal
	if emit is not None:
		bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
		if "Emission Strength" in bsdf.inputs:
			bsdf.inputs["Emission Strength"].default_value = emit[3] if len(emit) > 3 else 2.0
	if alpha < 1.0:
		bsdf.inputs["Alpha"].default_value = alpha
		if hasattr(m, "surface_render_method"):
			m.surface_render_method = "BLENDED"
		m.use_backface_culling = False
	tex = m.node_tree.nodes.new("ShaderNodeTexNoise")
	tex.inputs["Scale"].default_value = 6.0 if metal < 0.5 else 18.0
	tex.inputs["Detail"].default_value = 4.0
	bump = m.node_tree.nodes.new("ShaderNodeBump")
	bump.inputs["Strength"].default_value = 0.16 if metal < 0.5 else 0.05
	m.node_tree.links.new(tex.outputs["Fac"], bump.inputs["Height"])
	m.node_tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	return m


def empty(name: str, loc=(0.0, 0.0, 0.0)) -> bpy.types.Object:
	o = bpy.data.objects.new(name, None)
	o.empty_display_size = 0.08
	o.location = loc
	bpy.context.scene.collection.objects.link(o)
	return o


def finish(obj: bpy.types.Object, bevel_w: float) -> None:
	for poly in obj.data.polygons:
		poly.use_smooth = True
	if bevel_w <= 0.0:
		return
	mod = obj.modifiers.new("Bevel", "BEVEL")
	mod.width = bevel_w
	mod.segments = 2
	mod.limit_method = "ANGLE"
	mod.angle_limit = math.radians(40)
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.modifier_apply(modifier=mod.name)
	obj.select_set(False)


def mesh_object(name: str, bm: bmesh.types.BMesh, parent: bpy.types.Object, material, bevel_w: float = 0.0) -> bpy.types.Object:
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	me.validate()
	obj = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = parent
	obj.data.materials.append(material)
	finish(obj, bevel_w)
	return obj


def lathe(bm, profile, segments, close_loop=False, cap=True):
	rings = []
	for radius, z in profile:
		ring = []
		for i in range(segments):
			angle = math.tau * i / segments
			ring.append(bm.verts.new((radius * math.cos(angle), radius * math.sin(angle), z)))
		rings.append(ring)

	def bridge(r0, r1):
		for s in range(segments):
			a = r0[s]
			b = r0[(s + 1) % segments]
			c = r1[(s + 1) % segments]
			d = r1[s]
			bm.faces.new((a, b, c, d))

	for i in range(len(rings) - 1):
		bridge(rings[i], rings[i + 1])
	if close_loop and len(rings) > 2:
		bridge(rings[-1], rings[0])
	elif cap:
		for ring, flip in ((rings[0], True), (rings[-1], False)):
			if ring[0].co.xy.length < 1e-5:
				continue
			acc = Vector((0, 0, 0))
			for v in ring:
				acc += v.co
			center = bm.verts.new(acc / len(ring))
			for s in range(segments):
				a = ring[s]
				b = ring[(s + 1) % segments]
				bm.faces.new((center, b, a) if flip else (center, a, b))
	return rings


def bar(bm, a, b, radius, sides=6):
	a = Vector(a)
	b = Vector(b)
	axis = b - a
	length = axis.length
	if length < 1e-6:
		return
	axis.normalize()
	up = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
	side = axis.cross(up).normalized()
	lift = side.cross(axis).normalized()
	rings = []
	for p in (a, b):
		ring = []
		for i in range(sides):
			ang = math.tau * i / sides
			ring.append(bm.verts.new(p + side * math.cos(ang) * radius + lift * math.sin(ang) * radius))
		rings.append(ring)
	for s in range(sides):
		bm.faces.new((rings[0][s], rings[0][(s + 1) % sides], rings[1][(s + 1) % sides], rings[1][s]))
	bm.faces.new(rings[0])
	bm.faces.new(list(reversed(rings[1])))


def sphere(bm, radius, loc, u=12, v=8, sx=1.0, sy=1.0, sz=1.0):
	bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius)
	for vert in bm.verts:
		vert.co.x *= sx
		vert.co.y *= sy
		vert.co.z *= sz
		vert.co += Vector(loc)


def box(bm, loc, size):
	bmesh.ops.create_cube(bm, size=1.0)
	for v in bm.verts:
		v.co.x *= size[0]
		v.co.y *= size[1]
		v.co.z *= size[2]
		v.co += Vector(loc)


def export_glb(root: bpy.types.Object, filename: str) -> None:
	bpy.ops.object.select_all(action="DESELECT")
	root.select_set(True)
	for child in root.children_recursive:
		child.select_set(True)
	bpy.context.view_layer.objects.active = root
	path = os.path.join(MODELS, filename)
	os.makedirs(MODELS, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=path,
		use_selection=True,
		export_format="GLB",
		export_apply=True,
		export_lights=False,
		export_cameras=False,
		export_yup=True,
	)
	print("EXPORTED", path, "bytes", os.path.getsize(path))


# --- world props -------------------------------------------------------------

def build_brazier(stone, iron, coals_mat) -> bpy.types.Object:
	root = empty("SM_Brazier")
	plinth = bmesh.new()
	lathe(plinth, [
		(0.52, 0.00), (0.52, 0.08), (0.46, 0.10),
		(0.38, 0.12), (0.36, 0.22),
		(0.22, 0.24), (0.16, 0.78),
		(0.18, 0.86), (0.28, 0.92), (0.34, 0.96),
	], 16)
	mesh_object("Plinth", plinth, root, stone, 0.008)
	bowl = bmesh.new()
	lathe(bowl, [
		(0.18, 0.96), (0.26, 1.02), (0.36, 1.14), (0.48, 1.26),
		(0.58, 1.34), (0.60, 1.38), (0.52, 1.38), (0.42, 1.26),
		(0.30, 1.14), (0.22, 1.04),
	], 20, close_loop=True, cap=False)
	for side in (-1, 1):
		bar(bowl, (0.0, side * 0.54, 1.34), (0.0, side * 0.72, 1.30), 0.016, 8)
		bar(bowl, (side * 0.54, 0.0, 1.34), (side * 0.70, 0.0, 1.31), 0.012, 6)
	mesh_object("Bowl", bowl, root, iron, 0.004)
	rim = bmesh.new()
	lathe(rim, [(0.61, 1.36), (0.63, 1.38), (0.61, 1.40), (0.58, 1.38)], 20)
	mesh_object("IronRim", rim, root, iron, 0.002)
	for i in range(4):
		a = i * math.pi * 0.5 + 0.4
		leg = bmesh.new()
		bar(leg, (math.cos(a) * 0.44, math.sin(a) * 0.44, 0.06), (math.cos(a) * 0.50, math.sin(a) * 0.50, 1.18), 0.018, 6)
		mesh_object("IronLeg%d" % i, leg, root, iron, 0.003)
	bed = bmesh.new()
	sphere(bed, 1.0, (0.0, 0.0, 1.18), 16, 10, 0.32, 0.32, 0.13)
	for v in bed.verts:
		if v.co.z < 1.18:
			v.co.z = 1.18 - (1.18 - v.co.z) * 0.25
	mesh_object("EmberCoals", bed, root, coals_mat, 0.0)
	return root


def build_lantern(wood, iron, glass, ember) -> bpy.types.Object:
	root = empty("SM_Lantern")
	root.rotation_euler[2] = math.pi
	post = bmesh.new()
	lathe(post, [
		(0.14, 0.00), (0.14, 0.05), (0.10, 0.07),
		(0.068, 0.55), (0.050, 2.02), (0.060, 2.26), (0.062, 2.38),
	], 12)
	mesh_object("Post", post, root, wood, 0.005)
	bands = bmesh.new()
	for z, radius in ((0.72, 0.074), (1.72, 0.058)):
		lathe(bands, [(radius, z), (radius + 0.01, z + 0.01), (radius + 0.01, z + 0.04), (radius, z + 0.05)], 12)
	mesh_object("IronBand", bands, root, iron, 0.002)
	metal = bmesh.new()
	bar(metal, (0, 0.04, 2.34), (0, 0.40, 2.30), 0.016, 8)
	bar(metal, (0, 0.05, 2.16), (0, 0.34, 2.28), 0.010, 6)
	bar(metal, (0, 0.40, 2.30), (0, 0.40, 2.16), 0.010, 6)
	half = 0.108
	z0, z1 = 1.78, 2.14
	corners = [(sx * half, 0.40 + sy * half) for sx in (-1, 1) for sy in (-1, 1)]
	for x, y in corners:
		bar(metal, (x, y, z0), (x, y, z1), 0.012, 6)
	def frame(z):
		pts = [(-half, 0.40 - half, z), (half, 0.40 - half, z), (half, 0.40 + half, z), (-half, 0.40 + half, z)]
		for i in range(4):
			bar(metal, pts[i], pts[(i + 1) % 4], 0.010, 6)
	frame(z0)
	frame(z1)
	frame((z0 + z1) * 0.5)
	apex = (0.0, 0.40, 2.32)
	top = [(-half, 0.40 - half, z1), (half, 0.40 - half, z1), (half, 0.40 + half, z1), (-half, 0.40 + half, z1)]
	for i in range(4):
		metal.faces.new((metal.verts.new(top[i]), metal.verts.new(top[(i + 1) % 4]), metal.verts.new(apex)))
	bar(metal, apex, (0.0, 0.40, 2.42), 0.010, 6)
	floor = [(-half, 0.40 - half, z0), (half, 0.40 - half, z0), (half, 0.40 + half, z0), (-half, 0.40 + half, z0)]
	below = [(p[0] * 0.55, 0.40 + (p[1] - 0.40) * 0.55, z0 - 0.045) for p in floor]
	for i in range(4):
		metal.faces.new((
			metal.verts.new(floor[i]), metal.verts.new(floor[(i + 1) % 4]),
			metal.verts.new(below[(i + 1) % 4]), metal.verts.new(below[i]),
		))
	mesh_object("Ironwork", metal, root, iron, 0.0018)
	panes = bmesh.new()
	inset = half - 0.012
	for sx in (-1, 1):
		x = sx * inset
		panes.faces.new((
			panes.verts.new((x, 0.40 - inset, z0 + 0.02)),
			panes.verts.new((x, 0.40 + inset, z0 + 0.02)),
			panes.verts.new((x, 0.40 + inset, z1 - 0.02)),
			panes.verts.new((x, 0.40 - inset, z1 - 0.02)),
		))
	for sy in (-1, 1):
		y = 0.40 + sy * inset
		panes.faces.new((
			panes.verts.new((-inset, y, z0 + 0.02)),
			panes.verts.new((inset, y, z0 + 0.02)),
			panes.verts.new((inset, y, z1 - 0.02)),
			panes.verts.new((-inset, y, z1 - 0.02)),
		))
	mesh_object("Glass", panes, root, glass, 0.0)
	glow = bmesh.new()
	sphere(glow, 0.048, (0.0, 0.40, 1.96), 14, 10)
	mesh_object("Ember", glow, root, ember, 0.0)
	return root


def build_menhir(stone) -> bpy.types.Object:
	root = empty("SM_Menhir")
	sections = [
		(0.00, 0.42, 0.20, 0.00, 0.00),
		(0.22, 0.44, 0.22, 0.00, 0.00),
		(0.90, 0.34, 0.17, 0.05, 0.02),
		(1.55, 0.30, 0.15, 0.09, 0.04),
		(2.15, 0.27, 0.14, 0.04, 0.06),
		(2.75, 0.20, 0.11, 0.00, 0.10),
		(3.20, 0.07, 0.045, 0.00, 0.16),
	]
	bm = bmesh.new()
	rings = []
	sides = 10
	for z, rx, ry, notch, shift in sections:
		ring = []
		for i in range(sides):
			angle = -math.pi / 2 + math.tau * i / sides
			wobble = 1.0 + 0.035 * math.sin(angle * 3.0 + z * 2.1)
			x = math.cos(angle) * rx * wobble + shift + z * 0.035
			y = math.sin(angle) * ry * wobble
			if i == 0:
				y += notch
			ring.append(bm.verts.new((x, y, z)))
		rings.append(ring)
	for i in range(len(rings) - 1):
		for s in range(sides):
			bm.faces.new((rings[i][s], rings[i][(s + 1) % sides], rings[i + 1][(s + 1) % sides], rings[i + 1][s]))
	for ring, flip in ((rings[0], True), (rings[-1], False)):
		acc = Vector((0, 0, 0))
		for v in ring:
			acc += v.co
		center = bm.verts.new(acc / len(ring))
		for s in range(sides):
			bm.faces.new((center, ring[(s + 1) % sides], ring[s]) if flip else (center, ring[s], ring[(s + 1) % sides]))
	chip = bmesh.new()
	box(chip, (0.18, 0.02, 2.55), (0.22, 0.16, 0.55))
	# Extra weathered bites so the silhouette reads dark-fantasy, not a smooth pillar.
	chip2 = bmesh.new()
	box(chip2, (-0.12, -0.08, 1.35), (0.18, 0.14, 0.42))
	chip3 = bmesh.new()
	box(chip3, (0.08, 0.10, 0.55), (0.20, 0.12, 0.28))
	# Shallow carved face recess on the front.
	carve = bmesh.new()
	box(carve, (0.02, 0.20, 1.85), (0.16, 0.04, 0.55))
	mesh_object("Stone", bm, root, stone, 0.010)
	mesh_object("StoneShoulder", chip, root, stone, 0.018)
	mesh_object("StoneBite", chip2, root, stone, 0.014)
	mesh_object("StoneFootChip", chip3, root, stone, 0.012)
	mesh_object("StoneCarve", carve, root, stone, 0.006)
	return root


def build_staff(wood, iron, grip_m) -> bpy.types.Object:
	root = empty("SM_Staff")
	shaft = bmesh.new()
	lathe(shaft, [
		(0.042, -0.66), (0.036, -0.15), (0.032, 0.25),
		(0.028, 0.75), (0.024, 1.12),
	], 12)
	mesh_object("Shaft", shaft, root, wood, 0.003)
	grip = bmesh.new()
	lathe(grip, [(0.040, -0.12), (0.042, 0.00), (0.040, 0.18)], 12)
	mesh_object("ShaftGrip", grip, root, grip_m, 0.003)
	for z, r, h, name in ((-0.62, 0.055, 0.08, "IronFerrule"), (0.48, 0.040, 0.045, "IronBand"), (1.08, 0.058, 0.10, "IronCollar")):
		part = bmesh.new()
		lathe(part, [(r, z - h * 0.5), (r, z + h * 0.5)], 12)
		mesh_object(name, part, root, iron, 0.002)
	butt = bmesh.new()
	lathe(butt, [(0.062, -0.72), (0.034, -0.64)], 12)
	mesh_object("IronButt", butt, root, iron, 0.002)
	setting = bmesh.new()
	pts = []
	for i in range(18):
		u = i / 17.0
		pts.append(Vector((-math.sin(u * math.pi) * 0.13, 0.0, 1.22 + u * 0.48)))
	for i in range(1, 18):
		u = i / 17.0
		pts.append(Vector((math.sin(u * math.pi) * 0.13, 0.0, 1.70 - u * 0.48)))
	for i in range(len(pts) - 1):
		bar(setting, pts[i], pts[i + 1], 0.012, 6)
	bar(setting, (0.0, 0.0, 1.08), (0.0, 0.0, 1.24), 0.016, 8)
	bar(setting, (-0.16, 0.0, 1.36), (0.16, 0.0, 1.36), 0.014, 6)
	mesh_object("IronCradle", setting, root, iron, 0.002)
	return root


def build_hand_lantern(iron, glass, ember) -> bpy.types.Object:
	root = empty("SM_HandLantern")
	chain = bmesh.new()
	for i, z in enumerate((-0.018, -0.048, -0.078)):
		cx, cz = (0.0, z)
		for k in range(10):
			a0 = math.tau * k / 10.0
			a1 = math.tau * (k + 1) / 10.0
			major, minor = 0.016, 0.004
			# torus in XY or XZ alternating
			if i % 2 == 0:
				def pt(a):
					return Vector((math.cos(a) * major, math.sin(a) * major, cz))
			else:
				def pt(a):
					return Vector((math.cos(a) * major, 0.0, cz + math.sin(a) * major))
			bar(chain, pt(a0) + Vector((0, 0, 0)), pt(a1), minor, 5)
	mesh_object("IronChain", chain, root, iron, 0.0)
	cap = bmesh.new()
	lathe(cap, [(0.016, -0.10), (0.075, -0.125), (0.018, -0.155)], 8)
	mesh_object("IronCap", cap, root, iron, 0.002)
	cage = bmesh.new()
	for z, r in ((-0.155, 0.062), (-0.335, 0.058)):
		lathe(cage, [(r - 0.006, z), (r + 0.006, z)], 10, cap=False)
	for k in range(6):
		a = math.tau * k / 6.0
		bar(cage, (math.cos(a) * 0.06, math.sin(a) * 0.06, -0.155), (math.cos(a) * 0.058, math.sin(a) * 0.058, -0.335), 0.005, 6)
	lathe(cage, [(0.07, -0.34), (0.07, -0.36)], 10)
	mesh_object("IronCage", cage, root, iron, 0.0015)
	panes = bmesh.new()
	r = 0.048
	for k in range(6):
		a0 = math.tau * k / 6.0
		a1 = math.tau * (k + 1) / 6.0
		panes.faces.new((
			panes.verts.new((math.cos(a0) * r, math.sin(a0) * r, -0.32)),
			panes.verts.new((math.cos(a1) * r, math.sin(a1) * r, -0.32)),
			panes.verts.new((math.cos(a1) * r, math.sin(a1) * r, -0.17)),
			panes.verts.new((math.cos(a0) * r, math.sin(a0) * r, -0.17)),
		))
	mesh_object("GlassPane", panes, root, glass, 0.0)
	glow = bmesh.new()
	sphere(glow, 0.026, (0.0, 0.0, -0.245), 12, 8)
	mesh_object("Ember", glow, root, ember, 0.0)
	return root


def build_boot(leather, sole, metal) -> bpy.types.Object:
	# Socket: +Z Blender = +Y Godot (up shin). +Y Blender = -Z Godot (toe forward).
	root = empty("SM_Boot")
	shaft = bmesh.new()
	lathe(shaft, [(0.058, 0.03), (0.062, 0.08), (0.068, 0.155)], 12)
	mesh_object("LeatherShaft", shaft, root, leather, 0.004)
	cuff = bmesh.new()
	lathe(cuff, [(0.070, 0.14), (0.072, 0.16), (0.068, 0.17)], 12)
	mesh_object("LeatherCuff", cuff, root, leather, 0.003)
	last = bmesh.new()
	box(last, (0.0, 0.03, 0.035), (0.09, 0.13, 0.055))
	mesh_object("LeatherLast", last, root, leather, 0.005)
	toe = bmesh.new()
	sphere(toe, 0.042, (0.0, 0.08, 0.032), 10, 6, 1.05, 1.25, 0.7)
	mesh_object("LeatherToe", toe, root, leather, 0.004)
	sol = bmesh.new()
	box(sol, (0.0, 0.025, 0.008), (0.095, 0.15, 0.018))
	mesh_object("Sole", sol, root, sole, 0.003)
	heel = bmesh.new()
	box(heel, (0.0, -0.03, 0.004), (0.08, 0.05, 0.028))
	mesh_object("SoleHeel", heel, root, sole, 0.003)
	strap = bmesh.new()
	box(strap, (0.0, 0.04, 0.11), (0.08, 0.016, 0.012))
	mesh_object("LeatherStrap", strap, root, leather, 0.002)
	buckle = bmesh.new()
	box(buckle, (0.0, 0.055, 0.11), (0.022, 0.018, 0.008))
	mesh_object("MetalBuckle", buckle, root, metal, 0.002)
	return root


def build_gauntlet(leather, metal) -> bpy.types.Object:
	# Fingers toward +Y Blender = Godot -Z.
	root = empty("SM_Gauntlet")
	palm = bmesh.new()
	sphere(palm, 0.042, (0, 0, 0), 12, 8, 0.95, 1.15, 0.75)
	mesh_object("LeatherPalm", palm, root, leather, 0.004)
	cuff = bmesh.new()
	lathe(cuff, [(0.048, 0.02), (0.050, 0.058)], 12)
	mesh_object("MetalCuff", cuff, root, metal, 0.003)
	plate = bmesh.new()
	box(plate, (0.0, 0.02, 0.012), (0.05, 0.036, 0.016))
	mesh_object("MetalPlate", plate, root, metal, 0.003)
	knuckle = bmesh.new()
	box(knuckle, (0.0, 0.028, -0.004), (0.052, 0.018, 0.014))
	mesh_object("MetalKnuckle", knuckle, root, metal, 0.002)
	for i in range(3):
		x = (i - 1) * 0.016
		finger = bmesh.new()
		bar(finger, (x, 0.02, -0.01), (x, 0.062, -0.028), 0.009, 8)
		mesh_object("LeatherFinger%d" % i, finger, root, leather, 0.002)
		nail = bmesh.new()
		box(nail, (x, 0.068, -0.032), (0.009, 0.012, 0.006))
		mesh_object("MetalNail%d" % i, nail, root, metal, 0.001)
	return root


def build_rock(name: str, seed: float, squash: float, stone) -> bpy.types.Object:
	root = empty("SM_" + name)
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.72)
	for v in bm.verts:
		n = math.sin(v.co.x * 3.1 + seed) * math.cos(v.co.y * 2.4 + seed * 1.7) * math.sin(v.co.z * 2.8)
		n2 = math.sin(v.co.x * 7.4 + seed * 2.2) * math.cos(v.co.z * 6.1)
		v.co *= 1.0 + 0.22 * n + 0.08 * n2
		v.co.z *= squash
	bottom = min(v.co.z for v in bm.verts)
	for v in bm.verts:
		v.co.z -= bottom
		if v.co.z < 0.08:
			v.co.z *= 0.35
	mesh_object("Stone", bm, root, stone, 0.012)
	return root


def build_step(stone) -> bpy.types.Object:
	root = empty("SM_Step")
	bm = bmesh.new()
	bmesh.ops.create_grid(bm, x_segments=10, y_segments=4, size=1.0)
	for v in bm.verts:
		v.co.x *= 5.0
		v.co.y *= 1.1
		edge = max(0.0, abs(v.co.x) - 1.8)
		v.co.z += math.sin(v.co.x * 1.6) * math.cos(v.co.y * 3.5) * 0.03
		v.co.z -= edge * 0.035
		if v.co.y < -0.35:
			v.co.y -= 0.05
			v.co.z += 0.035
	top = list(bm.faces)
	ret = bmesh.ops.extrude_face_region(bm, geom=top)
	pushed = [v for v in ret["geom"] if isinstance(v, bmesh.types.BMVert)]
	bmesh.ops.translate(bm, verts=pushed, vec=(0.0, 0.0, -0.9))
	mesh_object("Stone", bm, root, stone, 0.014)
	nosing = bmesh.new()
	box(nosing, (0.0, -0.58, -0.04), (4.6, 0.08, 0.10))
	mesh_object("StoneNosing", nosing, root, stone, 0.008)
	return root


def build_column(stone) -> bpy.types.Object:
	root = empty("SM_Column")
	bm = bmesh.new()
	profile = [
		(0.56, -1.0), (0.52, -0.88), (0.40, -0.72),
		(0.36, -0.50), (0.34, 0.10), (0.36, 0.55),
		(0.42, 0.78), (0.54, 0.92), (0.50, 1.0),
	]
	lathe(bm, profile, 14)
	mesh_object("Stone", bm, root, stone, 0.010)
	return root


def build_platform(stone) -> bpy.types.Object:
	root = empty("SM_Platform")
	bm = bmesh.new()
	lathe(bm, [(5.2, -0.7), (5.4, -0.55), (5.6, 0.55), (5.3, 0.70)], 20)
	mesh_object("Stone", bm, root, stone, 0.022)
	return root


def build_wretch_torso(flesh, rag, bone) -> bpy.types.Object:
	root = empty("SM_WretchTorso")
	rib = bmesh.new()
	lathe(rib, [(0.14, -0.22), (0.16, -0.04), (0.15, 0.18), (0.10, 0.26)], 12)
	mesh_object("FleshRib", rib, root, flesh, 0.006)
	belly = bmesh.new()
	sphere(belly, 0.13, (0.0, 0.04, -0.14), 10, 6, 1.0, 0.9, 0.85)
	mesh_object("FleshBelly", belly, root, flesh, 0.005)
	wrap = bmesh.new()
	lathe(wrap, [(0.175, -0.12), (0.18, 0.02), (0.16, 0.12)], 12)
	mesh_object("RagWrap", wrap, root, rag, 0.004)
	sash = bmesh.new()
	lathe(sash, [(0.185, -0.18), (0.17, -0.10)], 10)
	mesh_object("RagSash", sash, root, rag, 0.003)
	neck = bmesh.new()
	lathe(neck, [(0.05, 0.22), (0.058, 0.34)], 10)
	mesh_object("FleshNeck", neck, root, flesh, 0.003)
	spine = bmesh.new()
	bar(spine, (0.0, 0.09, -0.12), (0.0, 0.09, 0.22), 0.032, 8)
	mesh_object("BoneSpine", spine, root, bone, 0.002)
	return root


def build_wretch_head(flesh, rag, bone, void_m) -> bpy.types.Object:
	# Face +Y Blender = Godot -Z.
	root = empty("SM_WretchHead")
	skull = bmesh.new()
	sphere(skull, 0.11, (0.0, 0.01, 0.04), 14, 8, 1.0, 0.95, 1.15)
	mesh_object("FleshSkull", skull, root, flesh, 0.005)
	jaw = bmesh.new()
	sphere(jaw, 0.07, (0.0, 0.04, -0.05), 10, 6)
	mesh_object("FleshJaw", jaw, root, flesh, 0.004)
	brow = bmesh.new()
	box(brow, (0.0, 0.07, 0.07), (0.16, 0.04, 0.03))
	mesh_object("FleshBrow", brow, root, flesh, 0.002)
	cowl = bmesh.new()
	lathe(cowl, [(0.08, 0.00), (0.14, 0.18)], 12)
	# tilt cowl toward +Y (face)
	for v in cowl.verts:
		v.co.y += 0.02
	mesh_object("RagCowl", cowl, root, rag, 0.005)
	drape = bmesh.new()
	lathe(drape, [(0.13, -0.08), (0.08, 0.06)], 10)
	mesh_object("RagDrape", drape, root, rag, 0.004)
	for name, loc in (("VoidEyeL", (-0.035, 0.085, 0.04)), ("VoidEyeR", (0.035, 0.085, 0.04))):
		eye = bmesh.new()
		sphere(eye, 0.022, loc, 8, 6)
		mesh_object(name, eye, root, void_m, 0.0)
	for name, loc in (("BoneFangL", (-0.02, 0.07, -0.07)), ("BoneFangR", (0.02, 0.07, -0.07))):
		fang = bmesh.new()
		bar(fang, loc, (loc[0], loc[1] + 0.01, loc[2] - 0.04), 0.006, 6)
		mesh_object(name, fang, root, bone, 0.001)
	return root


def build_husk_torso(flesh, rag, bone, void_m) -> bpy.types.Object:
	root = empty("SM_HuskTorso")
	rib = bmesh.new()
	lathe(rib, [(0.13, -0.20), (0.17, 0.00), (0.13, 0.22)], 12)
	mesh_object("FleshRib", rib, root, flesh, 0.006)
	wrap = bmesh.new()
	lathe(wrap, [(0.18, -0.12), (0.16, 0.08)], 12)
	mesh_object("RagWrap", wrap, root, rag, 0.004)
	skirt = bmesh.new()
	lathe(skirt, [(0.16, -0.28), (0.22, -0.08)], 12)
	mesh_object("RagSkirt", skirt, root, rag, 0.005)
	show = bmesh.new()
	lathe(show, [(0.14, 0.04), (0.13, 0.12)], 12)
	mesh_object("BoneRibShow", show, root, bone, 0.003)
	hollow = bmesh.new()
	sphere(hollow, 0.055, (0.0, 0.12, 0.06), 8, 6)
	mesh_object("VoidHollow", hollow, root, void_m, 0.0)
	return root


def build_husk_head(flesh, bone, void_m) -> bpy.types.Object:
	root = empty("SM_HuskHead")
	skull = bmesh.new()
	sphere(skull, 0.10, (0.0, 0.0, 0.04), 14, 8, 1.05, 0.92, 1.05)
	mesh_object("FleshSkull", skull, root, flesh, 0.005)
	jaw = bmesh.new()
	sphere(jaw, 0.065, (0.0, 0.03, -0.05), 10, 6)
	mesh_object("FleshJaw", jaw, root, flesh, 0.004)
	for name, loc in (("VoidEyeL", (-0.032, 0.08, 0.035)), ("VoidEyeR", (0.032, 0.08, 0.035))):
		eye = bmesh.new()
		sphere(eye, 0.02, loc, 8, 6)
		mesh_object(name, eye, root, void_m, 0.0)
	teeth = bmesh.new()
	bar(teeth, (-0.03, 0.06, -0.04), (0.03, 0.06, -0.04), 0.01, 8)
	mesh_object("BoneTeeth", teeth, root, bone, 0.001)
	return root


def main() -> None:
	clear_scene()
	stone = mat("HeroStone", (0.52, 0.44, 0.46), 0.78)
	iron = mat("HeroIron", (0.14, 0.12, 0.13), 0.38, 0.9)
	wood = mat("HeroWood", (0.24, 0.13, 0.08), 0.78)
	glass = mat("HeroGlass", (0.85, 0.42, 0.14), 0.18, 0.1, emit=(1.0, 0.42, 0.12, 1.4), alpha=0.38)
	ember = mat("HeroEmber", (1.0, 0.42, 0.12), 0.35, 0.0, emit=(1.0, 0.38, 0.08, 6.0))
	coals = mat("HeroCoals", (0.08, 0.03, 0.015), 0.8, 0.0, emit=(1.0, 0.32, 0.06, 3.5))
	leather = mat("HeroLeather", (0.07, 0.06, 0.07), 0.9)
	sole = mat("HeroSole", (0.04, 0.035, 0.04), 0.95)
	metal = mat("HeroMetal", (0.36, 0.34, 0.32), 0.34, 1.0)
	staff_wood = mat("StaffWood", (0.32, 0.22, 0.16), 0.72)
	grip = mat("StaffGrip", (0.16, 0.10, 0.08), 0.82)
	w_flesh = mat("WretchFlesh", (0.82, 0.64, 0.50), 0.72)
	w_rag = mat("WretchRag", (0.36, 0.22, 0.14), 0.9)
	w_bone = mat("WretchBone", (0.84, 0.72, 0.56), 0.42)
	h_flesh = mat("HuskFlesh", (0.42, 0.34, 0.30), 0.78)
	h_rag = mat("HuskRag", (0.16, 0.12, 0.10), 0.92)
	h_bone = mat("HuskBone", (0.58, 0.50, 0.40), 0.5)
	void_m = mat("VoidBlack", (0.02, 0.015, 0.02), 1.0)

	jobs = [
		(build_brazier(stone, iron, coals), "brazier.glb"),
		(build_lantern(wood, iron, glass, ember), "lantern.glb"),
		(build_menhir(stone), "menhir.glb"),
		(build_staff(staff_wood, iron, grip), "staff.glb"),
		(build_hand_lantern(iron, glass, ember), "hand_lantern.glb"),
		(build_boot(leather, sole, metal), "boot.glb"),
		(build_gauntlet(leather, metal), "gauntlet.glb"),
		(build_rock("RockA", 0.4, 0.72, stone), "rock_a.glb"),
		(build_rock("RockB", 2.1, 0.95, stone), "rock_b.glb"),
		(build_step(stone), "stair_step.glb"),
		(build_column(stone), "stair_column.glb"),
		(build_platform(stone), "stair_platform.glb"),
		(build_wretch_torso(w_flesh, w_rag, w_bone), "wretch_torso.glb"),
		(build_wretch_head(w_flesh, w_rag, w_bone, void_m), "wretch_head.glb"),
		(build_husk_torso(h_flesh, h_rag, h_bone, void_m), "husk_torso.glb"),
		(build_husk_head(h_flesh, h_bone, void_m), "husk_head.glb"),
	]
	# Spread in the .blend so a later inspect isn't a pile at the origin.
	for i, (root, _name) in enumerate(jobs):
		root.location.x = (i % 6) * 3.4
		root.location.y = (i // 6) * 4.2

	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	print("SAVED", BLEND)
	for root, name in jobs:
		kept = root.location.copy()
		root.location = (0.0, 0.0, 0.0)
		export_glb(root, name)
		root.location = kept


if __name__ == "__main__":
	main()

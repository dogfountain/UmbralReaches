"""Wanderer robe pieces. Same sockets; the coat now follows a body.

Coat hangs from chest, hood from head, sleeves from shoulders, bracers from elbows.
Blender Z → Godot Y. Blender +Y is the face (Godot -Z).

Shoulders, chest, waist, hips, and a dark body under the opening so it reads as a person.
No cape, no hem slit, no asymmetric sleeves, no silver cloth.
"""

from __future__ import annotations

import math
import os

import bpy
import bmesh
from mathutils import Vector


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(ROOT, "art", "models")
BLEND = os.path.join(ROOT, "art", "blender", "robe.blend")

FRONT = math.pi / 2.0


def reset() -> None:
	bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough, metal=0.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = metal
	tex = m.node_tree.nodes.new("ShaderNodeTexNoise")
	tex.inputs["Scale"].default_value = 14.0 if metal < 0.4 else 28.0
	tex.inputs["Detail"].default_value = 5.0
	bump = m.node_tree.nodes.new("ShaderNodeBump")
	bump.inputs["Strength"].default_value = 0.12 if metal < 0.4 else 0.04
	m.node_tree.links.new(tex.outputs["Fac"], bump.inputs["Height"])
	m.node_tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	return m


def q(bm, a, b, c, d, slot):
	face = bm.faces.new((a, b, c, d))
	face.material_index = slot
	face.smooth = True
	return face


def q_uv(bm, a, b, c, d, slot, uv_lay, ua, ub, uc, ud):
	face = q(bm, a, b, c, d, slot)
	wanted = {a: ua, b: ub, c: uc, d: ud}
	for loop in face.loops:
		uv = wanted.get(loop.vert)
		if uv is not None:
			loop[uv_lay].uv = uv
	return face


def ensure_uv(ob):
	if ob.data.uv_layers:
		return ob
	bpy.context.view_layer.objects.active = ob
	ob.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.03)
	bpy.ops.object.mode_set(mode="OBJECT")
	ob.select_set(False)
	return ob


def finish(name, bm, materials):
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	me.validate()
	for material in materials:
		me.materials.append(material)
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	bpy.context.view_layer.objects.active = ob
	centre = Vector((0.0, 0.0, 0.0))
	for v in me.vertices:
		centre += v.co
	centre /= max(1, len(me.vertices))
	outward = 0.0
	for poly in me.polygons:
		sample = me.vertices[poly.vertices[0]].co - centre
		outward += poly.normal.dot(sample)
		poly.use_smooth = True
	if outward < 0.0:
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.mesh.flip_normals()
		bpy.ops.object.mode_set(mode="OBJECT")
	print("ROBE", name, "verts", len(me.vertices), "faces", len(me.polygons))
	if len(me.vertices) < 8:
		raise RuntimeError("robe mesh %s is empty" % name)
	return ob


def bevel(ob, width=0.002, segs=2):
	mod = ob.modifiers.new("Bevel", "BEVEL")
	mod.width = width
	mod.segments = segs
	mod.limit_method = "ANGLE"
	mod.angle_limit = math.radians(35)
	bpy.context.view_layer.objects.active = ob
	ob.select_set(True)
	bpy.ops.object.modifier_apply(modifier=mod.name)
	ob.select_set(False)
	return ob


def join(name, objects):
	bpy.ops.object.select_all(action="DESELECT")
	for ob in objects:
		ensure_uv(ob)
		ob.select_set(True)
	bpy.context.view_layer.objects.active = objects[0]
	bpy.ops.object.join()
	objects[0].name = name
	print("ROBE joined", name, "verts", len(objects[0].data.vertices))
	return objects[0]


def _solid(name, material, bevel_w=0.0):
	ob = bpy.context.active_object
	ob.name = name
	bpy.ops.object.transform_apply(scale=True, rotation=True)
	if not ob.data.materials:
		ob.data.materials.append(material)
	for poly in ob.data.polygons:
		poly.use_smooth = True
	if bevel_w > 0.0:
		bevel(ob, bevel_w)
	return ob


def _lerp_keys(z, keys):
	if z >= keys[0][0]:
		return keys[0][1]
	for i in range(len(keys) - 1):
		z0, r0 = keys[i]
		z1, r1 = keys[i + 1]
		if z >= z1:
			return r0 + (r1 - r0) * ((z0 - z) / (z0 - z1))
	return keys[-1][1]


def shell(name, cloth, lining, z_top, z_hem, steps, segs, radius_fn, gap_fn, fold_fn, thickness, y_bias=0.0, sx=1.0, sy=1.0):
	"""An open coat. gap_fn is the half-angle cut out of the front (+Y). sx/sy squash the ring into a torso."""
	bm = bmesh.new()
	uv_lay = bm.loops.layers.uv.new("UVMap")
	outer = []
	inner = []
	edges = []
	for i in range(steps):
		t = i / (steps - 1)
		z = z_top + (z_hem - z_top) * t
		gap = gap_fn(z)
		sweep = math.tau - 2.0 * gap
		row_o = []
		row_i = []
		for k in range(segs):
			a = FRONT + gap + sweep * (k / (segs - 1))
			r = radius_fn(z) + fold_fn(z, a)
			end = min(k, segs - 1 - k)
			if end == 0:
				r += 0.01
			x = math.cos(a) * r * sx
			y = y_bias + math.sin(a) * r * sy
			if end == 0:
				y += 0.012
			point = Vector((x, y, z))
			flat = Vector((x, y - y_bias, 0.0))
			normal = flat.normalized() if flat.length > 1e-5 else Vector((0.0, 1.0, 0.0))
			row_o.append(bm.verts.new(point))
			row_i.append(bm.verts.new(point - normal * thickness))
		outer.append(row_o)
		inner.append(row_i)
		edges.append((row_o[0].co.copy(), row_o[-1].co.copy()))
	du = 1.0 / (segs - 1)
	dv = 1.0 / (steps - 1)
	for i in range(steps - 1):
		v0 = 1.0 - i * dv
		v1 = 1.0 - (i + 1) * dv
		for k in range(segs - 1):
			u0 = k * du
			u1 = (k + 1) * du
			q_uv(bm, outer[i][k], outer[i][k + 1], outer[i + 1][k + 1], outer[i + 1][k], 0, uv_lay,
				Vector((u0, v0)), Vector((u1, v0)), Vector((u1, v1)), Vector((u0, v1)))
			q_uv(bm, inner[i][k], inner[i + 1][k], inner[i + 1][k + 1], inner[i][k + 1], 1, uv_lay,
				Vector((u0, v0)), Vector((u0, v1)), Vector((u1, v1)), Vector((u1, v0)))
		for k in (0, segs - 1):
			u = 0.0 if k == 0 else 1.0
			q_uv(bm, outer[i][k], inner[i][k], inner[i + 1][k], outer[i + 1][k], 1, uv_lay,
				Vector((u, v0)), Vector((u + 0.02, v0)), Vector((u + 0.02, v1)), Vector((u, v1)))
	last = steps - 1
	for k in range(segs - 1):
		u0 = k * du
		u1 = (k + 1) * du
		q_uv(bm, outer[last][k], inner[last][k], inner[last][k + 1], outer[last][k + 1], 0, uv_lay,
			Vector((u0, 0.0)), Vector((u0, 0.02)), Vector((u1, 0.02)), Vector((u1, 0.0)))
		q_uv(bm, outer[0][k], outer[0][k + 1], inner[0][k + 1], inner[0][k], 0, uv_lay,
			Vector((u0, 1.0)), Vector((u1, 1.0)), Vector((u1, 0.98)), Vector((u0, 0.98)))
	return finish(name, bm, [cloth, lining]), edges


# Neck → deltoid → chest → waist → hip → modest A-line. Not a hanging cone.
_COAT = (
	(0.24, 0.090),
	(0.16, 0.210),
	(0.07, 0.248),
	(0.00, 0.192),
	(-0.16, 0.138),
	(-0.34, 0.116),
	(-0.50, 0.172),
	(-0.82, 0.190),
	(-1.16, 0.212),
)


def coat_radius(z):
	return _lerp_keys(z, _COAT)


def coat_gap(z):
	if z > 0.04:
		return 0.20
	if z > -0.28:
		return 0.12
	return 0.04


def coat_fold(z, ang):
	# Folds live on the skirt. Shoulders and waist stay readable.
	skirt = min(1.0, max(0.0, (-0.36 - z) / 0.80))
	amp = 0.004 + 0.028 * skirt
	wave = math.sin(ang * 6.0 + 0.6) * 0.72 + math.sin(ang * 11.0 + z * 4.0) * 0.28
	return math.copysign(abs(wave) ** 0.55, wave) * amp


def mantle_radius(z):
	return 0.195 + (0.215 - 0.195) * (0.16 - z) / 0.22


def mantle_gap(_z):
	return math.pi / 2.0


def mantle_fold(z, ang):
	wave = math.sin(ang * 5.0 + 0.4) + 0.35 * math.sin(ang * 9.0 + z * 3.0)
	return math.copysign(abs(wave) ** 0.5, wave) * 0.012


def bar(bm, a, b, radius, sides=6):
	a = Vector(a)
	b = Vector(b)
	axis = b - a
	if axis.length < 1e-5:
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


def piping(edges, cloth):
	bm = bmesh.new()
	for side in (0, 1):
		pts = [e[side] for e in edges]
		for i in range(len(pts) - 1):
			bar(bm, pts[i], pts[i + 1], 0.0045, 6)
	return finish("Piping", bm, [cloth])


def collar(cloth, lining):
	def radius(z):
		return 0.095 + (0.018 if z > 0.26 else 0.0)
	def gap(_z):
		return 0.28
	def fold(_z, ang):
		return math.sin(ang * 4.0) * 0.003
	ob, _edges = shell("Collar", cloth, lining, 0.30, 0.18, 8, 20, radius, gap, fold, 0.007, sx=1.12, sy=0.88)
	return ob


def stud(loc, metal):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=0.006, location=loc)
	return _solid("Stud", metal, 0.001)


def emblem(metal):
	parts = []
	bpy.ops.mesh.primitive_torus_add(major_radius=0.028, minor_radius=0.0036, location=(-0.045, 0.128, 0.05))
	ring = bpy.context.active_object
	ring.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
	parts.append(_solid("Halo", metal, 0.001))
	bpy.ops.mesh.primitive_torus_add(major_radius=0.016, minor_radius=0.0020, location=(-0.045, 0.131, 0.05))
	inner = bpy.context.active_object
	inner.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
	parts.append(_solid("HaloInner", metal, 0.0008))
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.045, 0.134, 0.045))
	bar_ob = bpy.context.active_object
	bar_ob.scale = (0.011, 0.007, 0.084)
	parts.append(_solid("Bar", metal, 0.0015))
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.045, 0.136, 0.066))
	cross = bpy.context.active_object
	cross.scale = (0.052, 0.007, 0.011)
	parts.append(_solid("Crossbar", metal, 0.0015))
	bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=5, radius=0.008, location=(-0.045, 0.140, 0.066))
	parts.append(_solid("Boss", metal, 0.001))
	return parts


def belt(metal, leather):
	parts = []
	bpy.ops.mesh.primitive_torus_add(major_radius=0.148, minor_radius=0.016, location=(0.0, 0.0, -0.32))
	band = bpy.context.active_object
	band.scale = (1.18, 0.82, 1.45)
	parts.append(_solid("Belt", leather, 0.002))
	bpy.ops.mesh.primitive_torus_add(major_radius=0.150, minor_radius=0.005, location=(0.0, 0.0, -0.29))
	edge = bpy.context.active_object
	edge.scale = (1.18, 0.82, 1.0)
	parts.append(_solid("BeltEdge", metal, 0.001))
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.13, -0.32))
	buckle = bpy.context.active_object
	buckle.scale = (0.048, 0.012, 0.036)
	parts.append(_solid("Buckle", metal, 0.002))
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.138, -0.32))
	tongue = bpy.context.active_object
	tongue.scale = (0.010, 0.007, 0.024)
	parts.append(_solid("Tongue", metal, 0.001))
	for side in (-0.016, 0.016):
		bpy.ops.mesh.primitive_cube_add(size=1.0, location=(side, 0.125, -0.42))
		strap = bpy.context.active_object
		strap.scale = (0.007, 0.005, 0.08)
		parts.append(_solid("Strap", leather, 0.001))
	bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=5, radius=0.014, location=(0.0, 0.13, -0.50))
	drop = bpy.context.active_object
	drop.scale = (0.7, 0.55, 1.15)
	parts.append(_solid("Drop", metal, 0.002))
	return parts


def roundels(metal):
	parts = []
	for sign in (-1.0, 1.0):
		bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.026, depth=0.008, location=(sign * 0.09, 0.125, 0.05))
		disc = bpy.context.active_object
		disc.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
		parts.append(_solid("Roundel", metal, 0.0015))
		bpy.ops.mesh.primitive_torus_add(major_radius=0.016, minor_radius=0.0028, location=(sign * 0.09, 0.130, 0.05))
		ring = bpy.context.active_object
		ring.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
		parts.append(_solid("RoundelRing", metal, 0.0008))
		bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=0.006, location=(sign * 0.09, 0.134, 0.05))
		parts.append(_solid("RoundelBoss", metal, 0.001))
	return parts


def body(material):
	"""Dark figure under the coat so the opening is a person, not a hollow tube."""
	parts = []
	bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.042, depth=0.16, location=(0.0, 0.012, 0.22))
	parts.append(_solid("BodyNeck", material, 0.002))
	bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0, location=(0.0, 0.035, 0.04))
	chest = bpy.context.active_object
	chest.scale = (0.155, 0.095, 0.135)
	parts.append(_solid("BodyChest", material, 0.003))
	bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0, location=(0.0, 0.018, -0.16))
	belly = bpy.context.active_object
	belly.scale = (0.125, 0.082, 0.155)
	parts.append(_solid("BodyBelly", material, 0.003))
	bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, radius=1.0, location=(0.0, 0.0, -0.46))
	hips = bpy.context.active_object
	hips.scale = (0.145, 0.090, 0.095)
	parts.append(_solid("BodyHips", material, 0.003))
	for sign in (-1.0, 1.0):
		bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.072, location=(sign * 0.17, -0.01, 0.11))
		pad = bpy.context.active_object
		pad.scale = (1.15, 0.85, 0.90)
		parts.append(_solid("BodyShoulder", material, 0.002))
	return parts


def torso(cloth, lining, metal, leather, flesh):
	coat, edges = shell(
		"Coat", cloth, lining, 0.22, -1.16, 36, 40,
		coat_radius, coat_gap, coat_fold, 0.012, sx=1.34, sy=0.70,
	)
	mantle, _edges = shell(
		"Mantle", cloth, lining, 0.16, -0.06, 10, 24,
		mantle_radius, mantle_gap, mantle_fold, 0.008, y_bias=-0.03, sx=1.22, sy=0.78,
	)
	parts = [coat, mantle, piping(edges, cloth), collar(cloth, lining)]
	parts += body(flesh)
	parts += emblem(metal)
	parts += belt(metal, leather)
	parts += roundels(metal)
	for left, right in edges[1:-8:3]:
		parts.append(stud(left, metal))
		parts.append(stud(right, metal))
	return join("Torso", parts)


def hood(cloth, lining):
	def radius(z):
		if z > 0.18:
			return max(0.02, 0.13 * (0.28 - z) / 0.10)
		if z > 0.02:
			return 0.128
		return 0.128 + 0.035 * (-z) / 0.14

	def gap(z):
		if z > 0.16:
			return 0.18
		if z > 0.0:
			return 0.92
		return 0.38

	def fold(_z, ang):
		return math.sin(ang * 4.0) * 0.004 + math.sin(ang * 9.0) * 0.0015

	def centre(z):
		if z > 0.16:
			return -0.03
		if z > 0.0:
			return -0.02
		return 0.01

	ob, edges = shell("Hood", cloth, lining, 0.28, -0.12, 20, 28, radius, gap, fold, 0.009, sx=1.08, sy=0.92)
	for vert in ob.data.vertices:
		vert.co.y += centre(vert.co.z)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.normals_make_consistent(inside=False)
	bpy.ops.object.mode_set(mode="OBJECT")
	lip, _e = shell(
		"HoodLip", cloth, lining, 0.10, -0.02, 8, 18,
		lambda _z: 0.125, lambda _z: 0.78, lambda _z, a: math.sin(a * 3.0) * 0.003, 0.010, y_bias=0.02, sx=1.06, sy=0.94,
	)
	return join("Hood", [ob, lip, piping(edges, cloth)])


def peak(cloth):
	bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.048, radius2=0.0, depth=0.13, location=(0.0, 0.0, 0.06))
	cone = _solid("HoodPeak", cloth, 0.003)
	bpy.ops.mesh.primitive_torus_add(major_radius=0.036, minor_radius=0.005, location=(0.0, 0.0, 0.01))
	band = _solid("PeakBand", cloth, 0.0015)
	return join("HoodPeak", [cone, band])


def sleeve(cloth, _lining):
	bm = bmesh.new()
	uv_lay = bm.loops.layers.uv.new("UVMap")
	steps = 16
	segs = 18
	rings = []
	for i in range(steps):
		t = i / (steps - 1)
		z = -0.32 * t
		# Deltoid → bicep → elbow. Oval like an arm, not a pipe.
		if t < 0.18:
			rad = 0.082 - 0.014 * (t / 0.18)
		elif t < 0.55:
			rad = 0.068 + 0.010 * math.sin((t - 0.18) / 0.37 * math.pi)
		else:
			rad = 0.068 - 0.020 * ((t - 0.55) / 0.45)
		row = []
		for k in range(segs):
			a = math.tau * k / segs
			fold = 0.003 * math.sin(a * 5.0 + t * 2.0)
			rx = rad * 1.14 + fold
			ry = rad * 0.84 + fold
			row.append(bm.verts.new((math.cos(a) * rx, math.sin(a) * ry + 0.012, z)))
		rings.append(row)
	for i in range(steps - 1):
		v0 = 1.0 - i / (steps - 1)
		v1 = 1.0 - (i + 1) / (steps - 1)
		for k in range(segs):
			k2 = (k + 1) % segs
			u0 = k / segs
			u1 = (k + 1) / segs
			q_uv(bm, rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k], 0, uv_lay,
				Vector((u0, v0)), Vector((u1, v0)), Vector((u1, v1)), Vector((u0, v1)))
	cloth_ob = finish("Sleeve", bm, [cloth])
	bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.082, location=(0.0, 0.01, 0.01))
	cap = bpy.context.active_object
	cap.scale = (1.18, 0.88, 0.70)
	cap = _solid("SleeveCap", cloth, 0.002)
	bpy.ops.mesh.primitive_torus_add(major_radius=0.072, minor_radius=0.005, location=(0.0, 0.012, -0.02))
	top = _solid("SleeveGather", cloth, 0.001)
	bpy.ops.mesh.primitive_torus_add(major_radius=0.050, minor_radius=0.004, location=(0.0, 0.012, -0.30))
	cuff = _solid("SleeveCuff", cloth, 0.001)
	return join("Sleeve", [cloth_ob, cap, top, cuff])


def bracer(cloth, lining, metal):
	def radius(_z):
		return 0.048

	def gap(_z):
		return 0.05

	def fold(_z, a):
		return math.sin(a * 8.0) * 0.002

	cloth_ob, edges = shell("Forearm", cloth, lining, 0.0, -0.20, 8, 14, radius, gap, fold, 0.006)
	parts = [cloth_ob, piping(edges, cloth)]
	bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.056, depth=0.12, location=(0.0, 0.0, -0.22))
	parts.append(_solid("Cuff", metal, 0.002))
	for z in (-0.16, -0.22, -0.28):
		bpy.ops.mesh.primitive_torus_add(major_radius=0.059, minor_radius=0.005, location=(0.0, 0.0, z))
		parts.append(_solid("Band", metal, 0.001))
	for k in range(6):
		a = k * math.tau / 6.0 + 0.35
		loc = (math.cos(a) * 0.056, math.sin(a) * 0.056, -0.22)
		parts.append(stud(loc, metal))
	return join("Bracer", parts)


def export(ob, filename):
	if ob is None or ob.data is None or len(ob.data.vertices) < 8:
		raise RuntimeError("export refused empty %s" % filename)
	loc = ob.location.copy()
	rot = ob.rotation_euler.copy()
	ob.location = (0.0, 0.0, 0.0)
	ob.rotation_euler = (0.0, 0.0, 0.0)
	bpy.ops.object.select_all(action="DESELECT")
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	os.makedirs(MODEL_DIR, exist_ok=True)
	path = os.path.join(MODEL_DIR, filename)
	bpy.ops.export_scene.gltf(
		filepath=path,
		use_selection=True,
		export_format="GLB",
		export_apply=True,
		export_lights=False,
		export_cameras=False,
		export_yup=True,
	)
	ob.location = loc
	ob.rotation_euler = rot
	print("EXPORTED", path, "bytes", os.path.getsize(path))
	if os.path.getsize(path) < 2000:
		raise RuntimeError("exported %s is tiny" % path)


def main():
	reset()
	cloth = mat("Cloth", (0.07, 0.064, 0.072), 0.88)
	lining = mat("Lining", (0.12, 0.09, 0.095), 0.82)
	leather = mat("Leather", (0.08, 0.06, 0.05), 0.70)
	metal = mat("Iron", (0.22, 0.20, 0.19), 0.38, 0.82)
	flesh = mat("Body", (0.045, 0.038, 0.040), 0.96)
	torso_ob = torso(cloth, lining, metal, leather, flesh)
	hood_ob = hood(cloth, lining)
	peak_ob = peak(cloth)
	sleeve_ob = sleeve(cloth, lining)
	bracer_ob = bracer(cloth, lining, metal)
	torso_ob.location = (0.0, 0.0, 1.28)
	hood_ob.location = (0.0, 0.0, 1.64)
	peak_ob.location = (0.0, -0.02, 1.96)
	peak_ob.rotation_euler = (0.4, 0.0, 0.0)
	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	print("SAVED", BLEND)
	export(torso_ob, "robe_torso.glb")
	export(hood_ob, "robe_hood.glb")
	export(peak_ob, "robe_peak.glb")
	export(sleeve_ob, "robe_sleeve.glb")
	export(bracer_ob, "robe_bracer.glb")


if __name__ == "__main__":
	main()

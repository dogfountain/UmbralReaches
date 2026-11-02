"""Cathedral-scale mossy summit monument + orb mage.

Imports Poly Haven rock_moss_set_02 (CC0) for real moss geometry.
Platform is a multi-tier plaza ~24 m across — not a 6 m disc.

Run: blender --background --python tools/make_summit_mage.py
"""

from __future__ import annotations

import math
import os
import random

import bpy
import bmesh
from mathutils import Matrix, Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLEND = os.path.join(ROOT, "art", "blender", "summit_mage.blend")
MODELS = os.path.join(ROOT, "art", "models")
TEX = os.path.join(ROOT, "art", "textures", "import")
PH_BLEND = "/tmp/umbral_moss_dl/rock_moss_1k.blend"
PH_GLTF = "/tmp/umbral_moss_dl/gltf/rock_moss_set_02_2k.gltf"
STEP_GLB = os.path.join(MODELS, "import", "stone_step_platform.glb")
RNG = random.Random(77)

# Cathedral footprint
BASE_R = 12.0
MID_R = 9.2
TOP_R = 6.4
BASE_H = 1.15
MID_H = 2.05
TOP_H = 2.85


def clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete()
	for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
		for data in list(block):
			if data.users == 0:
				block.remove(data)


def empty(name: str) -> bpy.types.Object:
	o = bpy.data.objects.new(name, None)
	o.empty_display_size = 0.25
	bpy.context.scene.collection.objects.link(o)
	return o


def mat_tex(name, albedo_path, normal_path=None, rough=0.82, tint=(1, 1, 1), emit=None):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bsdf = nt.nodes["Principled BSDF"]
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Base Color"].default_value = (*tint, 1.0)
	if emit is not None:
		bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
		if "Emission Strength" in bsdf.inputs:
			bsdf.inputs["Emission Strength"].default_value = emit[3]
	if albedo_path and os.path.isfile(albedo_path):
		img = bpy.data.images.load(albedo_path)
		tex = nt.nodes.new("ShaderNodeTexImage")
		tex.image = img
		tex.location = (-400, 200)
		# Dark fantasy cool grade on albedo
		mix = nt.nodes.new("ShaderNodeMix")
		mix.data_type = "RGBA"
		mix.inputs["Factor"].default_value = 0.35
		mix.inputs[7].default_value = (0.18, 0.28, 0.42, 1.0)  # B
		nt.links.new(tex.outputs["Color"], mix.inputs[6])
		nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
		if normal_path and os.path.isfile(normal_path):
			nimg = bpy.data.images.load(normal_path)
			ntex = nt.nodes.new("ShaderNodeTexImage")
			ntex.image = nimg
			ntex.image.colorspace_settings.name = "Non-Color"
			nmap = nt.nodes.new("ShaderNodeNormalMap")
			nmap.inputs["Strength"].default_value = 1.35
			nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
			nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
	else:
		tex = nt.nodes.new("ShaderNodeTexNoise")
		tex.inputs["Scale"].default_value = 18.0
		bump = nt.nodes.new("ShaderNodeBump")
		bump.inputs["Strength"].default_value = 0.4
		nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
		nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	return m


def mat_simple(name, color, rough, emit=None):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = rough
	if emit is not None:
		bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
		if "Emission Strength" in bsdf.inputs:
			bsdf.inputs["Emission Strength"].default_value = emit[3]
	return m


def mesh_object(name, bm, parent, material, bevel_w=0.0, smooth=False):
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	me.validate()
	# World-scale UVs so moss/stone textures tile across cathedral decks.
	me.uv_layers.new(name="UVMap")
	obj = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = parent
	if material:
		obj.data.materials.append(material)
	for poly in obj.data.polygons:
		poly.use_smooth = smooth
	# Triplanar-ish UV project from top
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.cube_project(cube_size=4.0)
	bpy.ops.object.mode_set(mode="OBJECT")
	if bevel_w > 0.0:
		mod = obj.modifiers.new("Bevel", "BEVEL")
		mod.width = bevel_w
		mod.segments = 2
		mod.limit_method = "ANGLE"
		mod.angle_limit = math.radians(30)
		bpy.ops.object.modifier_apply(modifier=mod.name)
	obj.select_set(False)
	return obj


def bar(bm, a, b, r0, r1=None, segments=8):
	a, b = Vector(a), Vector(b)
	span = b - a
	length = span.length
	if length < 1e-6:
		return
	r1 = r0 if r1 is None else r1
	geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r0, radius2=r1, depth=length)
	quat = Vector((0, 0, 1)).rotation_difference(span.normalized())
	m = quat.to_matrix().to_4x4()
	m.translation = (a + b) / 2
	bmesh.ops.transform(bm, verts=geom["verts"], matrix=m)


def ring_deck(bm, r_in, r_out, z0, z1, segs=64, brick=True):
	"""Solid annular deck with optional brick seam notches."""
	for i in range(segs):
		a0 = math.tau * i / segs
		a1 = math.tau * (i + 1) / segs
		notch = 0.04 if brick and (i % 4) == 0 else 0.0
		ri0, ri1 = r_in + notch * 0.5, r_out - notch
		def V(r, a, z):
			return bm.verts.new((math.cos(a) * r, math.sin(a) * r, z))
		b00, b01 = V(ri0, a0, z0), V(ri0, a1, z0)
		b10, b11 = V(ri1, a0, z0), V(ri1, a1, z0)
		t00, t01 = V(ri0, a0, z1), V(ri0, a1, z1)
		t10, t11 = V(ri1, a0, z1), V(ri1, a1, z1)
		bm.faces.new((t00, t01, t11, t10))
		bm.faces.new((b00, b10, b11, b01))
		bm.faces.new((b10, t10, t11, b11))
		if r_in > 0.05:
			bm.faces.new((b00, b01, t01, t00))


def load_moss_rocks():
	"""Bring Poly Haven moss rocks into the scene; return mesh objects."""
	before = set(bpy.data.objects)
	if os.path.isfile(PH_BLEND):
		with bpy.data.libraries.load(PH_BLEND, link=False) as (data_from, data_to):
			data_to.objects = [n for n in data_from.objects if data_from.objects]
		for obj in data_to.objects:
			if obj is not None:
				bpy.context.scene.collection.objects.link(obj)
	elif os.path.isfile(PH_GLTF):
		bpy.ops.import_scene.gltf(filepath=PH_GLTF)
	rocks = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
	# Hide originals; we instance copies onto the monument.
	for o in rocks:
		o.hide_set(True)
		o.hide_render = True
	print("MOSS_ROCKS", len(rocks), [o.name for o in rocks[:12]])
	return rocks


def instance_rock(template: bpy.types.Object, parent, loc, scale, yaw, material=None):
	obj = template.copy()
	obj.data = template.data.copy()
	obj.hide_set(False)
	obj.hide_render = False
	obj.parent = parent
	obj.location = loc
	obj.rotation_euler = (RNG.uniform(-0.15, 0.15), RNG.uniform(-0.15, 0.15), yaw)
	obj.scale = (scale, scale * RNG.uniform(0.85, 1.15), scale * RNG.uniform(0.55, 0.95))
	bpy.context.scene.collection.objects.link(obj)
	if material and obj.data.materials:
		obj.data.materials[0] = material
	elif material:
		obj.data.materials.append(material)
	# Rename so dress paints Moss*
	obj.name = "MossRock_%s" % obj.name[:24]
	return obj


def build_cathedral_platform(stone_mat, moss_mat, moss_rocks):
	root = empty("SM_MossyPlatform")

	# --- Tier slabs (cathedral scale) ---
	bm = bmesh.new()
	# Base drum
	ring_deck(bm, 0.0, BASE_R, 0.0, BASE_H, segs=72)
	# Mid terrace
	ring_deck(bm, 0.0, MID_R, BASE_H, MID_H, segs=64)
	# Top dais body
	ring_deck(bm, 0.0, TOP_R, MID_H, TOP_H, segs=56)
	mesh_object("StoneMonument", bm, root, stone_mat, 0.012, smooth=False)

	# Hero cobble disc — concentric rings matching the ozavry_ ref (clear masonry, not moss pile).
	dais = bmesh.new()
	ring_deck(dais, 0.0, TOP_R - 0.05, TOP_H, TOP_H + 0.12, segs=72, brick=True)
	for r0, r1 in ((0.0, 1.15), (1.25, 2.35), (2.45, 3.55), (3.65, 4.75), (4.85, 6.15)):
		ring_deck(dais, r0, r1, TOP_H + 0.12, TOP_H + 0.16, segs=56, brick=True)
	cobble_path = os.path.join(ROOT, "art", "textures", "cobble_ring.png")
	cobble_n = os.path.join(ROOT, "art", "textures", "cobble_ring_n.png")
	cobble_mat = mat_tex("CobbleDais", cobble_path, cobble_n, rough=0.55, tint=(0.85, 0.95, 1.1))
	mesh_object("CobbleDais", dais, root, cobble_mat, 0.006, smooth=False)

	# --- Approach stair (faces +Y → player climb after glTF) ---
	stair = bmesh.new()
	steps = 10
	stair_w = 5.5
	for s in range(steps):
		t = s / steps
		z0 = t * TOP_H
		z1 = z0 + TOP_H / steps + 0.02
		y0 = BASE_R - 0.2 - s * 0.55
		y1 = y0 - 0.55
		# Box step
		verts = []
		for x in (-stair_w * 0.5, stair_w * 0.5):
			for y in (y1, y0):
				for z in (z0, z1):
					verts.append(stair.verts.new((x, y, z)))
		# Build faces from 8 corners — use cube then transform is cleaner
	stair.free()
	stair = bmesh.new()
	for s in range(steps):
		z0 = (s / steps) * TOP_H
		h = TOP_H / steps + 0.03
		depth = 0.58
		y_front = BASE_R + 0.15 - s * depth
		geom = bmesh.ops.create_cube(stair, size=1.0)
		for v in geom["verts"]:
			v.co.x *= stair_w
			v.co.y *= depth
			v.co.z *= h
			v.co.y += y_front - depth * 0.5
			v.co.z += z0 + h * 0.5
	mesh_object("StoneApproach", stair, root, stone_mat, 0.008, smooth=False)

	# --- Monumental balustrade on mid terrace rear arc ---
	rail = bmesh.new()
	for i in range(22):
		t = i / 21.0
		a = math.pi * 0.08 + t * math.pi * 0.84
		x, y = math.cos(a) * (MID_R - 0.35), math.sin(a) * (MID_R - 0.35)
		bar(rail, (x, y, MID_H), (x, y, MID_H + 1.35), 0.09, 0.07, 8)
		# Cap
		geom = bmesh.ops.create_cone(rail, cap_ends=True, segments=8, radius1=0.14, radius2=0.02, depth=0.28)
		bmesh.ops.translate(rail, verts=geom["verts"], vec=(x, y, MID_H + 1.52))
	for i in range(21):
		t0, t1 = i / 21.0, (i + 1) / 21.0
		a0 = math.pi * 0.08 + t0 * math.pi * 0.84
		a1 = math.pi * 0.08 + t1 * math.pi * 0.84
		p0 = Vector((math.cos(a0) * (MID_R - 0.35), math.sin(a0) * (MID_R - 0.35), MID_H + 1.15))
		p1 = Vector((math.cos(a1) * (MID_R - 0.35), math.sin(a1) * (MID_R - 0.35), MID_H + 1.15))
		bar(rail, p0, p1, 0.05, 0.05, 6)
	mesh_object("StoneRail", rail, root, stone_mat, 0.005, smooth=False)

	# Moss only on lower tiers + rim — top cobble dais stays readable like the ref.
	carpet = bmesh.new()
	for r_max, z, dens in ((BASE_R - 0.3, BASE_H + 0.03, 0.62), (MID_R - 0.25, MID_H + 0.03, 0.72)):
		for i in range(48):
			a0 = math.tau * i / 48
			a1 = math.tau * (i + 1) / 48
			r0 = r_max * dens
			v0 = carpet.verts.new((math.cos(a0) * r0, math.sin(a0) * r0, z))
			v1 = carpet.verts.new((math.cos(a1) * r0, math.sin(a1) * r0, z))
			v2 = carpet.verts.new((math.cos(a1) * r_max, math.sin(a1) * r_max, z))
			v3 = carpet.verts.new((math.cos(a0) * r_max, math.sin(a0) * r_max, z))
			carpet.faces.new((v0, v1, v2, v3))
	mesh_object("MossCarpet", carpet, root, moss_mat, 0.0, smooth=True)

	# Ref-style short rear pillars + rail ON the top dais (close framing behind the mage).
	frame = bmesh.new()
	for side in (-1.0, 1.0):
		px, py = side * 2.35, -3.45
		bar(frame, (px, py, TOP_H + 0.16), (px, py, TOP_H + 1.35), 0.16, 0.13, 8)
		bar(frame, (px, py, TOP_H + 1.35), (px, py, TOP_H + 1.55), 0.22, 0.18, 8)
		geom = bmesh.ops.create_cone(frame, cap_ends=True, segments=10, radius1=0.28, radius2=0.02, depth=0.55)
		bmesh.ops.translate(frame, verts=geom["verts"], vec=(px, py, TOP_H + 1.85))
	# Connecting low rail
	bar(frame, (-2.2, -3.45, TOP_H + 0.95), (2.2, -3.45, TOP_H + 0.95), 0.05, 0.05, 6)
	for t in range(5):
		x = -1.8 + t * 0.9
		bar(frame, (x, -3.45, TOP_H + 0.16), (x, -3.45, TOP_H + 0.95), 0.05, 0.045, 6)
	mesh_object("StoneDaisRail", frame, root, stone_mat, 0.004, smooth=False)

	if moss_rocks:
		# Lower tiers only — keep the hero cobble circle clear.
		tiers = [
			(BASE_H, BASE_R * 0.92, 48, (0.55, 1.35)),
			(MID_H, MID_R * 0.9, 36, (0.45, 1.1)),
		]
		for z, rmax, count, sc_range in tiers:
			for _ in range(count):
				tmpl = moss_rocks[RNG.randrange(len(moss_rocks))]
				ang = RNG.random() * math.tau
				rad = rmax * (0.6 + 0.4 * (RNG.random() ** 0.55))
				loc = Vector((math.cos(ang) * rad, math.sin(ang) * rad, z))
				sc = RNG.uniform(*sc_range)
				instance_rock(tmpl, root, loc, sc, RNG.random() * math.tau, moss_mat)
		for s in range(steps):
			z = (s / steps) * TOP_H + 0.1
			y = BASE_R + 0.15 - s * 0.58
			for side in (-1.0, 1.0):
				tmpl = moss_rocks[RNG.randrange(len(moss_rocks))]
				instance_rock(
					tmpl, root,
					Vector((side * stair_w * 0.48, y - 0.2, z)),
					RNG.uniform(0.4, 0.85), RNG.random() * math.tau, moss_mat,
				)

	# --- Import and scale stone step modules as ruin plinth accents ---
	if os.path.isfile(STEP_GLB):
		before = set(bpy.data.objects)
		bpy.ops.import_scene.gltf(filepath=STEP_GLB)
		imported = [o for o in bpy.data.objects if o not in before]
		for i, ang in enumerate((0.9, 2.2, 4.0, 5.3)):
			for src in imported:
				if src.type != "MESH":
					continue
				dup = src.copy()
				dup.data = src.data
				dup.parent = root
				dup.name = "StoneStepAccent%d" % i
				dup.location = (math.cos(ang) * (BASE_R - 1.2), math.sin(ang) * (BASE_R - 1.2), BASE_H)
				dup.rotation_euler = (0, 0, ang + math.pi * 0.5)
				dup.scale = (1.8, 1.8, 1.6)
				bpy.context.scene.collection.objects.link(dup)
				if stone_mat:
					if dup.data.materials:
						dup.data.materials[0] = stone_mat
					else:
						dup.data.materials.append(stone_mat)
		for src in imported:
			src.hide_set(True)
			src.hide_render = True

	return root


def build_summit_pillar(stone_mat, moss_mat, moss_rocks):
	root = empty("SM_SummitPillar")
	bm = bmesh.new()
	bar(bm, (0, 0, 0.0), (0, 0, 0.45), 0.85, 0.78, 10)
	bar(bm, (0, 0, 0.45), (0, 0, 4.2), 0.42, 0.36, 10)
	bar(bm, (0, 0, 4.2), (0, 0, 4.7), 0.62, 0.55, 10)
	geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.72, radius2=0.02, depth=1.4)
	bmesh.ops.translate(bm, verts=geom["verts"], vec=(0, 0, 5.35))
	mesh_object("Stone", bm, root, stone_mat, 0.01, smooth=False)
	if moss_rocks:
		for k in range(8):
			a = math.tau * k / 8
			tmpl = moss_rocks[RNG.randrange(len(moss_rocks))]
			instance_rock(
				tmpl, root,
				Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, RNG.uniform(0.3, 3.2))),
				RNG.uniform(0.35, 0.75), a, moss_mat,
			)
	return root


def build_summit_mage(robe, void, orb_mat):
	root = empty("SM_SummitMage")
	body = bmesh.new()
	profile = [
		(0.22, 0.02), (0.28, 0.15), (0.32, 0.55), (0.30, 1.05),
		(0.26, 1.45), (0.22, 1.75), (0.20, 1.95),
	]
	rings = []
	sides = 12
	for r, z in profile:
		ring = []
		for i in range(sides):
			a = math.tau * i / sides
			rr = r * (1.0 + 0.08 * math.sin(a + 0.4))
			if z < 0.2:
				rr *= 1.0 + 0.12 * abs(math.sin(a * 3.0))
			ring.append(body.verts.new((math.cos(a) * rr, math.sin(a) * rr * 0.85, z)))
		rings.append(ring)
	for i in range(len(rings) - 1):
		for s in range(sides):
			body.faces.new((rings[i][s], rings[i][(s + 1) % sides], rings[i + 1][(s + 1) % sides], rings[i + 1][s]))
	acc = Vector((0, 0, 0))
	for v in rings[-1]:
		acc += v.co
	top = body.verts.new(acc / len(rings[-1]))
	for s in range(sides):
		body.faces.new((top, rings[-1][s], rings[-1][(s + 1) % sides]))
	mesh_object("RobeBody", body, root, robe, 0.008, True)

	hat = bmesh.new()
	bar(hat, (0, 0.02, 1.92), (0, 0.02, 2.12), 0.24, 0.20, 12)
	peak = [
		Vector((0.0, 0.02, 2.12)), Vector((0.05, -0.05, 2.45)), Vector((0.18, -0.18, 2.75)),
		Vector((0.42, -0.35, 2.95)), Vector((0.72, -0.55, 2.85)), Vector((0.95, -0.72, 2.55)),
	]
	for i in range(len(peak) - 1):
		t = i / (len(peak) - 1)
		r = 0.16 * (1.0 - t) + 0.02
		bar(hat, peak[i], peak[i + 1], r, r * 0.7, 8)
	mesh_object("RobeHat", hat, root, robe, 0.006, True)

	face = bmesh.new()
	geom = bmesh.ops.create_uvsphere(face, u_segments=10, v_segments=6, radius=0.11)
	bmesh.ops.translate(face, verts=geom["verts"], vec=(0.0, 0.12, 2.00))
	mesh_object("VoidFace", face, root, void, 0.0, True)

	arm_l = bmesh.new()
	bar(arm_l, (-0.18, 0.05, 1.70), (-0.28, 0.10, 1.15), 0.07, 0.055, 8)
	bar(arm_l, (-0.28, 0.10, 1.15), (-0.22, 0.12, 0.85), 0.055, 0.045, 7)
	mesh_object("RobeSleeveL", arm_l, root, robe, 0.005, True)

	arm_r = bmesh.new()
	bar(arm_r, (0.18, 0.05, 1.70), (0.38, 0.12, 1.95), 0.07, 0.055, 8)
	bar(arm_r, (0.38, 0.12, 1.95), (0.52, 0.22, 2.22), 0.055, 0.045, 7)
	geom = bmesh.ops.create_icosphere(arm_r, subdivisions=1, radius=0.055)
	bmesh.ops.translate(arm_r, verts=geom["verts"], vec=(0.55, 0.26, 2.28))
	mesh_object("RobeSleeveR", arm_r, root, robe, 0.005, True)

	orb = bmesh.new()
	geom = bmesh.ops.create_uvsphere(orb, u_segments=14, v_segments=10, radius=0.07)
	bmesh.ops.translate(orb, verts=geom["verts"], vec=(0.58, 0.30, 2.48))
	for ax in ((0.18, 0, 0), (-0.18, 0, 0), (0, 0, 0.18), (0, 0, -0.18)):
		p0 = Vector((0.58, 0.30, 2.48))
		bar(orb, p0, p0 + Vector(ax), 0.018, 0.002, 5)
	for ax in ((0.12, 0, 0.12), (-0.12, 0, 0.12), (0.12, 0, -0.12), (-0.12, 0, -0.12)):
		p0 = Vector((0.58, 0.30, 2.48))
		bar(orb, p0, p0 + Vector(ax) * 0.7, 0.012, 0.002, 4)
	mesh_object("OrbCore", orb, root, orb_mat, 0.0, True)
	return root


def export_glb(root, filename):
	bpy.ops.object.select_all(action="DESELECT")
	root.select_set(True)
	for child in root.children_recursive:
		child.select_set(True)
		child.hide_set(False)
	bpy.context.view_layer.objects.active = root
	path = os.path.join(MODELS, filename)
	os.makedirs(MODELS, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=path, use_selection=True, export_format="GLB",
		export_apply=True, export_lights=False, export_cameras=False, export_yup=True,
	)
	print("EXPORTED", path, os.path.getsize(path))


def main():
	clear_scene()
	diff = os.path.join(TEX, "rock_moss_diff.jpg")
	nor = os.path.join(TEX, "rock_moss_nor.jpg")
	stone = mat_tex("CathedralStone", diff, nor, rough=0.78, tint=(0.75, 0.82, 0.95))
	moss = mat_tex("CathedralMoss", diff, nor, rough=0.9, tint=(0.35, 0.95, 0.45))
	robe = mat_simple("SummitRobe", (0.06, 0.08, 0.16), 0.9)
	void = mat_simple("SummitVoid", (0.01, 0.01, 0.02), 1.0)
	orb = mat_simple("SummitOrb", (0.75, 0.85, 1.0), 0.2, emit=(0.55, 0.65, 1.0, 4.5))

	rocks = load_moss_rocks()
	platform = build_cathedral_platform(stone, moss, rocks)
	mage = build_summit_mage(robe, void, orb)
	# Mage stands on top dais centre
	mage.location = (0.0, 0.0, TOP_H)
	pillar_a = build_summit_pillar(stone, moss, rocks)
	pillar_a.location = (-7.2, -6.5, MID_H)
	pillar_b = build_summit_pillar(stone, moss, rocks)
	pillar_b.location = (7.2, -6.5, MID_H)
	pillar_c = build_summit_pillar(stone, moss, rocks)
	pillar_c.location = (-5.5, -9.2, BASE_H)
	pillar_d = build_summit_pillar(stone, moss, rocks)
	pillar_d.location = (5.5, -9.2, BASE_H)

	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)

	# Detach for clean per-asset export
	for o in (mage, pillar_a, pillar_b, pillar_c, pillar_d):
		o.location = (0, 0, 0)
	export_glb(platform, "mossy_platform.glb")
	export_glb(mage, "summit_mage.glb")
	export_glb(pillar_a, "summit_pillar.glb")
	print("SAVED", BLEND, "BASE_R", BASE_R, "TOP_H", TOP_H)


if __name__ == "__main__":
	main()

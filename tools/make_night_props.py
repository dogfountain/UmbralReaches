"""Dark-fantasy night props for Stair runtime dress.

Run: blender --background --python tools/make_night_props.py
Writes art/blender/night_props.blend and art/models/{twisted_root,fallen_branch,rune_slab,cairn}.glb

Does not touch wanderer, shade, gothic_bay, toad, or lantern/brazier sockets.
"""

from __future__ import annotations

import math
import os

import bpy
import bmesh
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLEND = os.path.join(ROOT, "art", "blender", "night_props.blend")
MODELS = os.path.join(ROOT, "art", "models")


def clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete()
	for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
		for data in list(block):
			if data.users == 0:
				block.remove(data)


def mat(name: str, color, rough: float, metal: float = 0.0, emit=None) -> bpy.types.Material:
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = metal
	if emit is not None:
		bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
		if "Emission Strength" in bsdf.inputs:
			bsdf.inputs["Emission Strength"].default_value = emit[3] if len(emit) > 3 else 1.5
	tex = m.node_tree.nodes.new("ShaderNodeTexNoise")
	tex.inputs["Scale"].default_value = 9.0
	tex.inputs["Detail"].default_value = 6.0
	bump = m.node_tree.nodes.new("ShaderNodeBump")
	bump.inputs["Strength"].default_value = 0.28
	m.node_tree.links.new(tex.outputs["Fac"], bump.inputs["Height"])
	m.node_tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	return m


def empty(name: str) -> bpy.types.Object:
	o = bpy.data.objects.new(name, None)
	o.empty_display_size = 0.08
	bpy.context.scene.collection.objects.link(o)
	return o


def mesh_object(name: str, bm: bmesh.types.BMesh, parent: bpy.types.Object, material, bevel_w: float = 0.0) -> bpy.types.Object:
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	me.validate()
	obj = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = parent
	if material:
		obj.data.materials.append(material)
	for poly in obj.data.polygons:
		poly.use_smooth = True
	if bevel_w > 0.0:
		mod = obj.modifiers.new("Bevel", "BEVEL")
		mod.width = bevel_w
		mod.segments = 2
		mod.limit_method = "ANGLE"
		mod.angle_limit = math.radians(40)
		bpy.context.view_layer.objects.active = obj
		obj.select_set(True)
		bpy.ops.object.modifier_apply(modifier=mod.name)
		obj.select_set(False)
	return obj


def bar(bm, a, b, radius, segments=6):
	a = Vector(a)
	b = Vector(b)
	span = b - a
	length = span.length
	if length < 1e-6:
		return
	geom = bmesh.ops.create_cone(
		bm, cap_ends=True, segments=segments,
		radius1=radius, radius2=radius * 0.72, depth=length,
	)
	quat = Vector((0, 0, 1)).rotation_difference(span.normalized())
	mat4 = quat.to_matrix().to_4x4()
	mat4.translation = (a + b) / 2
	bmesh.ops.transform(bm, verts=geom["verts"], matrix=mat4)


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


def build_twisted_root(bark) -> bpy.types.Object:
	root = empty("SM_TwistedRoot")
	bm = bmesh.new()
	# Several gnarled limbs rising from a shared foot.
	rng = 0.37
	for i in range(5):
		a0 = math.tau * i / 5.0 + 0.2
		x0, y0 = math.cos(a0) * 0.12, math.sin(a0) * 0.12
		pts = [Vector((x0, y0, 0.02))]
		ang = a0
		pitch = 0.55
		for s in range(7):
			ang += math.sin(s * 1.3 + i) * 0.35
			pitch += 0.08
			last = pts[-1]
			step = 0.14 + 0.02 * s
			pts.append(last + Vector((
				math.cos(ang) * step * 0.7,
				math.sin(ang) * step * 0.7,
				step * pitch * 0.55,
			)))
		for j in range(len(pts) - 1):
			r = 0.055 * (1.0 - j / 8.0)
			bar(bm, pts[j], pts[j + 1], r, 7)
		# Side claw.
		mid = pts[3]
		claw = mid + Vector((math.cos(ang + 1.2) * 0.22, math.sin(ang + 1.2) * 0.22, 0.05))
		bar(bm, mid, claw, 0.028, 6)
	# Foot plate mass.
	geom = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.22)
	bmesh.ops.translate(bm, verts=geom["verts"], vec=(0.0, 0.0, 0.04))
	for v in geom["verts"]:
		v.co.z *= 0.45
		v.co.x *= 1.35
		v.co.y *= 1.35
	mesh_object("Bark", bm, root, bark, 0.006)
	return root


def build_fallen_branch(bark) -> bpy.types.Object:
	root = empty("SM_FallenBranch")
	bm = bmesh.new()
	pts = [Vector((-0.55, 0.0, 0.06))]
	yaw = 0.15
	for s in range(8):
		yaw += math.sin(s * 0.9) * 0.22
		last = pts[-1]
		pts.append(last + Vector((0.16, math.sin(yaw) * 0.08, math.cos(s * 0.7) * 0.025)))
	for j in range(len(pts) - 1):
		r = 0.045 * (1.0 - j * 0.06)
		bar(bm, pts[j], pts[j + 1], r, 7)
	# Forks.
	for idx, side in ((3, 1.0), (5, -1.0)):
		p = pts[idx]
		q = p + Vector((0.12, side * 0.22, 0.08))
		bar(bm, p, q, 0.022, 6)
		bar(bm, q, q + Vector((0.08, side * 0.1, 0.04)), 0.014, 5)
	mesh_object("Bark", bm, root, bark, 0.004)
	return root


def build_rune_slab(stone, glow) -> bpy.types.Object:
	root = empty("SM_RuneSlab")
	body = bmesh.new()
	bmesh.ops.create_cube(body, size=1.0)
	for v in body.verts:
		v.co.x *= 0.42
		v.co.y *= 0.12
		v.co.z *= 0.72
		v.co.z += 0.36
		# Lean and chip.
		v.co.x += v.co.z * 0.04
		n = math.sin(v.co.x * 8.0) * math.cos(v.co.z * 6.0) * 0.012
		v.co += Vector((n, n * 0.4, 0.0))
	mesh_object("Stone", body, root, stone, 0.01)
	# Carved glow channels on the face.
	mark = bmesh.new()
	for i, (x0, z0, x1, z1) in enumerate((
		(-0.08, 0.25, 0.08, 0.25),
		(0.0, 0.22, 0.0, 0.55),
		(-0.12, 0.40, 0.12, 0.48),
		(-0.06, 0.58, 0.06, 0.62),
	)):
		bar(mark, (x0, 0.065, z0), (x1, 0.065, z1), 0.012, 5)
	mesh_object("Mark", mark, root, glow, 0.0)
	return root


def build_cairn(stone) -> bpy.types.Object:
	root = empty("SM_Cairn")
	bm = bmesh.new()
	# Stack of worn slabs.
	heights = [0.0, 0.14, 0.28, 0.40, 0.50]
	sizes = [0.38, 0.32, 0.26, 0.20, 0.14]
	for h, s, i in zip(heights, sizes, range(5)):
		geom = bmesh.ops.create_cube(bm, size=1.0)
		for v in geom["verts"]:
			v.co.x *= s * (1.0 + 0.08 * math.sin(i * 2.1))
			v.co.y *= s * 0.72 * (1.0 + 0.06 * math.cos(i * 1.7))
			v.co.z *= 0.11
			v.co.z += h + 0.06
			v.co.x += math.sin(i * 1.3) * 0.03
			v.co.y += math.cos(i * 0.9) * 0.02
	mesh_object("Stone", bm, root, stone, 0.008)
	return root


def main() -> None:
	clear_scene()
	bark = mat("NightBark", (0.12, 0.10, 0.14), 0.88)
	stone = mat("NightStone", (0.28, 0.32, 0.42), 0.82)
	glow = mat("NightRune", (0.35, 0.55, 1.0), 0.35, emit=(0.25, 0.45, 1.0, 2.2))

	props = [
		(build_twisted_root(bark), "twisted_root.glb"),
		(build_fallen_branch(bark), "fallen_branch.glb"),
		(build_rune_slab(stone, glow), "rune_slab.glb"),
		(build_cairn(stone), "cairn.glb"),
	]
	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	for root, name in props:
		export_glb(root, name)
	print("SAVED", BLEND)


if __name__ == "__main__":
	main()

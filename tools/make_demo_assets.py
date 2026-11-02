"""Demo-zone meshes: a warping flame mirror frame, a stair tread, a pier, and two rocks.

The mirror arch matches MirrorGate (width 1.16, sill 0.46, springing 3.38) so the
existing glass pane still sits in the opening. Blender is Z-up; glTF export
turns that into Godot Y-up.
"""

import math
import os

import bpy
import bmesh
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "art", "models")
BLEND = os.path.join(ROOT, "art", "blender", "demo_assets.blend")

ARCH_W = 1.16
ARCH_Y0 = 0.46
ARCH_Y1 = 3.38


def reset() -> None:
	bpy.ops.wm.read_factory_settings(use_empty=True)


def new_mesh(name: str, bm: bmesh.types.BMesh):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	obj = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def arch_point(t: float) -> Vector:
	if t <= 1.0:
		return Vector((-ARCH_W, 0.0, ARCH_Y0 + (ARCH_Y1 - ARCH_Y0) * t))
	if t <= 2.0:
		a = math.pi * (t - 1.0)
		return Vector((-math.cos(a) * ARCH_W, 0.0, ARCH_Y1 + math.sin(a) * ARCH_W))
	u = t - 2.0
	return Vector((ARCH_W, 0.0, ARCH_Y1 + (ARCH_Y0 - ARCH_Y1) * u))


def arch_axes(t: float):
	"""Outward (away from the opening), forward (toward the viewer), tangent."""
	ahead = arch_point(min(t + 0.02, 2.999))
	behind = arch_point(max(t - 0.02, 0.0))
	tangent = (ahead - behind).normalized()
	if t <= 1.0:
		inward = Vector((1.0, 0.0, 0.0))
	elif t <= 2.0:
		a = math.pi * (t - 1.0)
		inward = Vector((math.cos(a), 0.0, -math.sin(a)))
	else:
		inward = Vector((-1.0, 0.0, 0.0))
	outward = -inward
	forward = Vector((0.0, -1.0, 0.0))
	return outward, forward, tangent


def heat(u: float):
	"""Yellow at the root, deep red at the tip. The game shader grades this."""
	u = max(0.0, min(1.0, u))
	if u < 0.35:
		k = u / 0.35
		return (1.0, 0.72 - 0.30 * k, 0.16 - 0.08 * k, 1.0)
	k = (u - 0.35) / 0.65
	return (1.0 - 0.48 * k, 0.42 - 0.36 * k, 0.08 - 0.06 * k, 1.0)


def paint(face, uv_layer, color_layer, along, heats) -> None:
	for loop, h in zip(face.loops, heats):
		loop[uv_layer].uv = (along, h)
		loop[color_layer] = heat(h)


def add_tube(bm, uv_layer, color_layer) -> None:
	"""A warped arch the glass sits inside. The inner lip stays hot and solid."""
	segs = 72
	sides = 8
	radius = 0.055
	rings = []
	for i in range(segs):
		t = 3.0 * i / (segs - 1)
		outward, forward, _tangent = arch_axes(t)
		center = arch_point(t)
		center += forward * math.sin(t * 4.0) * 0.04
		center += outward * math.sin(t * 2.2 + 0.6) * 0.025
		ring = []
		for j in range(sides):
			a = math.tau * j / sides
			off = outward * math.cos(a) * radius + forward * math.sin(a) * (radius * 0.8)
			ring.append((bm.verts.new(center + off), a))
		rings.append((ring, t / 3.0))
	for i in range(len(rings) - 1):
		ring, u0 = rings[i]
		nxt, u1 = rings[i + 1]
		for j in range(sides):
			a0 = ring[j][1]
			a1 = ring[(j + 1) % sides][1]
			face = bm.faces.new((
				ring[j][0], ring[(j + 1) % sides][0],
				nxt[(j + 1) % sides][0], nxt[j][0],
			))
			# cos = 1 faces out of the opening. The lip toward the glass stays at a low UV.
			heats = []
			for ang in (a0, a1, a1, a0):
				outwardness = (math.cos(ang) + 1.0) * 0.5
				heats.append(0.04 + outwardness * 0.28)
			paint(face, uv_layer, color_layer, (u0 + u1) * 0.5, heats)


def add_flame(bm, uv_layer, color_layer, t: float, length: float, radius: float, twist: float) -> None:
	"""A closed teardrop. Wide face toward the viewer so the outline reads as fire."""
	outward, forward, tangent = arch_axes(t)
	rise = tangent if tangent.z >= 0.0 else -tangent
	# Belly in the middle, point at the tip. Fractions of `radius`.
	profile = (
		(0.0, 0.55, 0.4), (0.14, 1.0, 0.62), (0.32, 0.92, 0.58),
		(0.52, 0.62, 0.4), (0.72, 0.34, 0.24), (0.88, 0.16, 0.12), (1.0, 0.07, 0.06),
	)
	origin = arch_point(t) + outward * 0.04 + forward * 0.015
	path = origin.copy()
	rings = []
	for u, w_scale, d_scale in profile:
		direc = (rise * (1.0 - 0.65 * u) + outward * (0.2 + 1.05 * u) + Vector((0.0, 0.0, 0.4 * u * u))).normalized()
		if u > 0.0:
			prev = rings[-1][1]
			path = path + direc * (length * (u - prev))
		side = direc.cross(forward)
		if side.length < 0.2:
			side = direc.cross(outward)
		side = side.normalized()
		up = direc.cross(side).normalized()
		center = path + side * math.sin(u * math.pi + twist) * 0.025 + forward * math.sin(u * math.pi + twist * 0.5) * 0.03
		w = radius * w_scale
		d = radius * d_scale
		ring = []
		for j in range(8):
			a = math.tau * j / 8.0
			off = side * math.cos(a) * w + up * math.sin(a) * d
			ring.append(bm.verts.new(center + off))
		rings.append((ring, u, center, direc))
	along = t / 3.0
	sides = 8
	for i in range(len(rings) - 1):
		ring, u0, _c0, _d0 = rings[i]
		nxt, u1, _c1, _d1 = rings[i + 1]
		for j in range(sides):
			face = bm.faces.new((ring[j], ring[(j + 1) % sides], nxt[(j + 1) % sides], nxt[j]))
			paint(face, uv_layer, color_layer, along, (u0, u0, u1, u1))
	root, _u, center, direc = rings[0]
	cap = bm.verts.new(center - direc * 0.02)
	for j in range(sides):
		face = bm.faces.new((cap, root[(j + 1) % sides], root[j]))
		paint(face, uv_layer, color_layer, along, (0.0, 0.0, 0.0))
	tip_ring, _u, center, direc = rings[-1]
	tip = bm.verts.new(center + direc * (length * 0.08))
	for j in range(sides):
		face = bm.faces.new((tip_ring[j], tip_ring[(j + 1) % sides], tip))
		paint(face, uv_layer, color_layer, along, (0.92, 0.92, 1.0))


def _reach(t: float) -> float:
	"""A thin lip, with a handful of narrow licks. Not a repeating wave."""
	spots = (0.32, 0.78, 1.18, 1.50, 1.86, 2.28, 2.68)
	heights = (0.42, 0.50, 0.36, 0.48, 0.40, 0.52, 0.34)
	widths = (0.18, 0.20, 0.16, 0.28, 0.17, 0.20, 0.16)
	lick = 0.0
	for spot, height, width in zip(spots, heights, widths):
		d = (t - spot) / width
		lick = max(lick, height * max(0.0, 1.0 - d * d) ** 1.35)
	return 0.055 + lick


def build_mirror():
	"""One swept frame. The inner lip is the mirror edge; the outer edge is the fire."""
	bm = bmesh.new()
	uv = bm.loops.layers.uv.new("UVMap")
	color = bm.loops.layers.color.new("Color")
	# Section in (outward amount, forward amount, heat). Outward is scaled by the lick.
	section = (
		(-0.045, 0.00, 0.02),
		(-0.01, 0.05, 0.08),
		(0.22, 0.07, 0.22),
		(0.62, 0.04, 0.48),
		(1.00, 0.00, 0.92),
		(0.58, -0.05, 0.5),
		(0.12, -0.035, 0.16),
	)
	segs = 110
	rings = []
	for i in range(segs):
		t = 3.0 * i / (segs - 1)
		outward, forward, tangent = arch_axes(t)
		rise = tangent if tangent.z >= 0.0 else -tangent
		# On the crown the arch runs sideways, so the lick points up instead of across itself.
		point = (rise * (0.25 + 0.75 * abs(rise.z)) + Vector((0.0, 0.0, 1.0)) * (1.0 - abs(rise.z))).normalized()
		reach = _reach(t)
		roll = math.sin(t * 2.4 + 0.5) * 0.6
		center = arch_point(t) + forward * math.sin(t * 3.1) * 0.025
		ring = []
		for ox, fy, h in section:
			dist = ox * reach if ox > 0.0 else ox
			# The outer edge climbs along the arch, so a lick has a tip instead of a lump.
			climb = max(ox, 0.0) ** 1.6 * max(reach - 0.055, 0.0) * 0.85
			pos = center + outward * dist + point * climb + forward * (fy + roll * max(ox, 0.0) * 0.04)
			ring.append((bm.verts.new(pos), h))
		rings.append(ring)
	for i in range(segs - 1):
		along = (i + 0.5) / segs
		for j in range(len(section)):
			j2 = (j + 1) % len(section)
			face = bm.faces.new((
				rings[i][j][0], rings[i][j2][0],
				rings[i + 1][j2][0], rings[i + 1][j][0],
			))
			paint(face, uv, color, along, (
				rings[i][j][1], rings[i][j2][1],
				rings[i + 1][j2][1], rings[i + 1][j][1],
			))
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	obj = new_mesh("FlameFrame", bm)
	for poly in obj.data.polygons:
		poly.use_smooth = True
	return obj


def build_preview_glass():
	"""Not exported. Shows the opening the portal glass fills."""
	bm = bmesh.new()
	n = 28
	verts = []
	for i in range(n):
		t = 3.0 * i / (n - 1)
		p = arch_point(t)
		outward, _forward, _tangent = arch_axes(t)
		verts.append(bm.verts.new(p + outward * -0.06 + Vector((0.0, -0.02, 0.0))))
	peak = arch_point(1.5)
	sill = Vector((0.0, -0.02, ARCH_Y0 + 0.15))
	centre = bm.verts.new((peak + sill) * 0.5)
	for i in range(n - 1):
		bm.faces.new((centre, verts[i], verts[i + 1]))
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	obj = new_mesh("PreviewGlass", bm)
	return obj


def build_step():
	bm = bmesh.new()
	# Worn slab: 5 wide, 1.1 deep, 0.9 thick. Nosing on -Y so it faces +Z in Godot.
	bmesh.ops.create_grid(bm, x_segments=8, y_segments=3, size=1.0)
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
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	return new_mesh("Step", bm)


def build_column():
	bm = bmesh.new()
	profile = [
		(0.52, -1.0), (0.48, -0.82), (0.40, -0.55),
		(0.36, 0.15), (0.40, 0.72), (0.50, 1.0),
	]
	rings = []
	sides = 8
	for radius, z in profile:
		ring = []
		for i in range(sides):
			a = math.tau * i / sides
			wobble = 1.0 + 0.04 * math.sin(a * 2.0 + z * 3.0)
			ring.append(bm.verts.new((math.cos(a) * radius * wobble, math.sin(a) * radius * wobble, z)))
		rings.append(ring)
	for i in range(len(rings) - 1):
		for s in range(sides):
			bm.faces.new((
				rings[i][s], rings[i][(s + 1) % sides],
				rings[i + 1][(s + 1) % sides], rings[i + 1][s],
			))
	for ring, flip in ((rings[0], True), (rings[-1], False)):
		acc = Vector((0, 0, 0))
		for v in ring:
			acc += v.co
		center = bm.verts.new(acc / len(ring))
		for s in range(sides):
			a = ring[s]
			b = ring[(s + 1) % sides]
			bm.faces.new((center, b, a) if flip else (center, a, b))
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	return new_mesh("Column", bm)


def build_platform():
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=5.2, radius2=5.6, depth=1.4)
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	return new_mesh("Platform", bm)


def build_rock(name: str, seed: float, squash: float):
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.72)
	for v in bm.verts:
		n = math.sin(v.co.x * 3.1 + seed) * math.cos(v.co.y * 2.4 + seed * 1.7) * math.sin(v.co.z * 2.8)
		# Higher-frequency crunch for wet-stone catch lights under blue moon.
		n2 = math.sin(v.co.x * 9.4 + seed * 2.1) * math.cos(v.co.y * 8.2) * 0.08
		v.co *= 1.0 + 0.28 * n + n2
		v.co.z *= squash
		# Facet push — sharper ridges.
		if abs(v.co.x) > 0.35:
			v.co.x *= 1.08
	bottom = min(v.co.z for v in bm.verts)
	for v in bm.verts:
		v.co.z -= bottom
		if v.co.z < 0.08:
			v.co.z *= 0.35
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	return new_mesh(name, bm)


def export(obj, filename: str) -> None:
	kept = obj.location.copy()
	obj.location = (0.0, 0.0, 0.0)
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	path = os.path.join(OUT, filename)
	bpy.ops.export_scene.gltf(
		filepath=path,
		use_selection=True,
		export_format="GLB",
		export_apply=True,
		export_lights=False,
		export_cameras=False,
		export_yup=True,
	)
	obj.location = kept
	print("EXPORTED", path)


def shade() -> None:
	mat = bpy.data.materials.new("Preview")
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (0.45, 0.38, 0.40, 1)
	bsdf.inputs["Roughness"].default_value = 0.85
	fire = bpy.data.materials.new("Fire")
	fire.use_nodes = True
	fb = fire.node_tree.nodes["Principled BSDF"]
	attr = fire.node_tree.nodes.new("ShaderNodeAttribute")
	attr.attribute_name = "Color"
	fire.node_tree.links.new(attr.outputs["Color"], fb.inputs["Base Color"])
	fire.node_tree.links.new(attr.outputs["Color"], fb.inputs["Emission Color"])
	fb.inputs["Emission Strength"].default_value = 1.6
	fb.inputs["Roughness"].default_value = 0.55
	glass = bpy.data.materials.new("Glass")
	glass.use_nodes = True
	gb = glass.node_tree.nodes["Principled BSDF"]
	gb.inputs["Base Color"].default_value = (0.05, 0.06, 0.09, 1)
	gb.inputs["Roughness"].default_value = 0.04
	gb.inputs["Metallic"].default_value = 1.0
	for obj in bpy.data.objects:
		if obj.type != "MESH":
			continue
		if obj.name == "FlameFrame":
			slot = fire
		elif obj.name == "PreviewGlass":
			slot = glass
		else:
			slot = mat
		obj.data.materials.append(slot)


def preview() -> None:
	scene = bpy.context.scene
	world = bpy.data.worlds.new("Night")
	scene.world = world
	world.use_nodes = True
	bg = world.node_tree.nodes["Background"]
	bg.inputs["Color"].default_value = (0.02, 0.015, 0.04, 1)
	bg.inputs["Strength"].default_value = 0.3
	cam_data = bpy.data.cameras.new("Cam")
	cam_data.lens = 40
	cam = bpy.data.objects.new("Cam", cam_data)
	cam.location = (0.35, -7.2, 2.15)
	bpy.context.scene.collection.objects.link(cam)
	direction = Vector((0.0, 0.0, 2.1)) - cam.location
	cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
	scene.camera = cam
	for obj in bpy.data.objects:
		if obj.type == "MESH" and obj.name != "FlameFrame":
			obj.hide_render = True
	key = bpy.data.lights.new("Key", "AREA")
	key.energy = 80
	key_obj = bpy.data.objects.new("Key", key)
	key_obj.location = (-2.0, -3.0, 4.0)
	bpy.context.scene.collection.objects.link(key_obj)
	scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 900
	scene.render.resolution_y = 1200
	scene.render.filepath = "/tmp/mirror_frame.png"
	scene.eevee.taa_render_samples = 16
	bpy.ops.render.render(write_still=True)


def main() -> None:
	reset()
	frame = build_mirror()
	build_preview_glass()
	step = build_step()
	step.location.x = 6.5
	column = build_column()
	column.location.x = 10.5
	platform = build_platform()
	platform.location = (0.0, 8.0, 0.0)
	rock_a = build_rock("RockA", 0.4, 0.72)
	rock_a.location = (4.2, -2.2, 0.0)
	rock_b = build_rock("RockB", 2.1, 0.95)
	rock_b.location = (6.4, -2.4, 0.0)
	shade()
	preview()
	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	export(frame, "mirror_frame.glb")
	export(step, "stair_step.glb")
	export(column, "stair_column.glb")
	export(platform, "stair_platform.glb")
	export(rock_a, "rock_a.glb")
	export(rock_b, "rock_b.glb")


if __name__ == "__main__":
	main()

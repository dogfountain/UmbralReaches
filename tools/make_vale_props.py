"""Three Vale props, sized to the meshes they would replace.

Lantern: path post is ~2.45 m, cage ~0.22 x 0.32 m.
Brazier: pedestal ~1.0 m, bowl rim ~1.4 m.
Menhir: one stone ~3.2 m, footprint ~0.76 x 0.36 m.

Run: blender --background --python tools/make_vale_props.py
"""

import math
import os

import bpy
import bmesh
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLEND = os.path.join(ROOT, "art", "blender", "vale_props.blend")
PREVIEW = "/tmp/vale_props.png"


def clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete()
	for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
		for data in list(block):
			if data.users == 0:
				block.remove(data)


def empty(name: str, location) -> bpy.types.Object:
	obj = bpy.data.objects.new(name, None)
	obj.empty_display_type = "PLAIN_AXES"
	obj.empty_display_size = 0.25
	obj.location = location
	bpy.context.scene.collection.objects.link(obj)
	return obj


def mesh_object(name: str, bm: bmesh.types.BMesh, parent: bpy.types.Object) -> bpy.types.Object:
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	me.validate()
	obj = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = parent
	return obj


def finish(obj: bpy.types.Object, smooth: bool, bevel_width: float = 0.0) -> None:
	for poly in obj.data.polygons:
		poly.use_smooth = smooth
	if bevel_width <= 0.0:
		return
	mod = obj.modifiers.new("Bevel", "BEVEL")
	mod.width = bevel_width
	mod.segments = 2
	mod.limit_method = "ANGLE"
	mod.angle_limit = math.radians(45)
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.modifier_apply(modifier=mod.name)
	obj.select_set(False)


def material(name, color, rough, metal=0.0, emit=0.0, emit_color=None, transmission=0.0, grain=False):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	nt = mat.node_tree
	bsdf = nt.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = metal
	if emit > 0.0:
		bsdf.inputs["Emission Color"].default_value = (*(emit_color or color), 1)
		bsdf.inputs["Emission Strength"].default_value = emit
	if transmission > 0.0:
		# Alpha, not refraction: EEVEE and the Godot lamp both need the ember readable through the cage.
		bsdf.inputs["Alpha"].default_value = 0.35
		bsdf.inputs["Roughness"].default_value = 0.2
		mat.surface_render_method = "BLENDED"
		mat.use_backface_culling = False
		return mat
	tex = nt.nodes.new("ShaderNodeTexNoise")
	tex.inputs["Scale"].default_value = 3.2 if grain else (4.5 if metal < 0.5 else 22.0)
	tex.inputs["Detail"].default_value = 3.0
	bump = nt.nodes.new("ShaderNodeBump")
	bump.inputs["Strength"].default_value = 0.18 if grain else (0.28 if metal < 0.5 else 0.06)
	if grain:
		mapping = nt.nodes.new("ShaderNodeMapping")
		coord = nt.nodes.new("ShaderNodeTexCoord")
		mapping.inputs["Scale"].default_value = (0.6, 0.6, 4.5)
		nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
		nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
	nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
	nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	return mat


def assign(obj: bpy.types.Object, mat) -> None:
	obj.data.materials.append(mat)


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
	if close_loop:
		bridge(rings[-1], rings[0])
	elif cap:
		for ring, flip in ((rings[0], True), (rings[-1], False)):
			acc = Vector((0, 0, 0))
			for v in ring:
				acc += v.co
			center = bm.verts.new(acc / len(ring))
			for s in range(segments):
				a = ring[s]
				b = ring[(s + 1) % segments]
				bm.faces.new((center, b, a) if flip else (center, a, b))


def bar(bm, a, b, radius, segments=6):
	a = Vector(a)
	b = Vector(b)
	span = b - a
	length = span.length
	if length < 1e-6:
		return
	geom = bmesh.ops.create_cone(
		bm,
		cap_ends=True,
		segments=segments,
		radius1=radius,
		radius2=radius,
		depth=length,
	)
	quat = Vector((0, 0, 1)).rotation_difference(span.normalized())
	mat = quat.to_matrix().to_4x4()
	mat.translation = (a + b) / 2
	bmesh.ops.transform(bm, verts=geom["verts"], matrix=mat)


def build_lantern(wood, iron, glass, ember) -> None:
	root = empty("Lantern", (0.0, 0.0, 0.0))
	root.rotation_euler[2] = math.pi
	post = bmesh.new()
	lathe(post, [
		(0.13, 0.00), (0.13, 0.045), (0.078, 0.07),
		(0.062, 0.55), (0.048, 2.05), (0.058, 2.28), (0.058, 2.36),
	], 8)
	obj = mesh_object("Post", post, root)
	finish(obj, True, 0.004)
	assign(obj, wood)

	metal = bmesh.new()
	for z, radius in ((0.72, 0.070), (1.72, 0.056)):
		lathe(metal, [(radius, z), (radius + 0.008, z + 0.012), (radius + 0.008, z + 0.038), (radius, z + 0.050)], 8, cap=True)
	# Bracket out to where the cage hangs, plus a diagonal brace.
	bar(metal, (0, 0.04, 2.34), (0, 0.40, 2.30), 0.016, 6)
	bar(metal, (0, 0.05, 2.16), (0, 0.34, 2.28), 0.010, 5)
	bar(metal, (0, 0.40, 2.30), (0, 0.40, 2.16), 0.010, 5)
	half = 0.105
	z0, z1 = 1.78, 2.12
	corners = [(sx * half, 0.40 + sy * half) for sx in (-1, 1) for sy in (-1, 1)]
	for x, y in corners:
		bar(metal, (x, y, z0), (x, y, z1), 0.012, 5)
	def frame(z):
		pts = [(-half, 0.40 - half, z), (half, 0.40 - half, z), (half, 0.40 + half, z), (-half, 0.40 + half, z)]
		for i in range(4):
			bar(metal, pts[i], pts[(i + 1) % 4], 0.010, 5)
	frame(z0)
	frame(z1)
	frame((z0 + z1) * 0.5)
	apex = (0.0, 0.40, 2.30)
	top = [(-half, 0.40 - half, z1), (half, 0.40 - half, z1), (half, 0.40 + half, z1), (-half, 0.40 + half, z1)]
	for i in range(4):
		a = top[i]
		b = top[(i + 1) % 4]
		metal.faces.new((
			metal.verts.new(a),
			metal.verts.new(b),
			metal.verts.new(apex),
		))
	bar(metal, apex, (0.0, 0.40, 2.40), 0.010, 6)
	# Floor plate.
	floor = [(-half, 0.40 - half, z0), (half, 0.40 - half, z0), (half, 0.40 + half, z0), (-half, 0.40 + half, z0)]
	below = [(p[0] * 0.55, 0.40 + (p[1] - 0.40) * 0.55, z0 - 0.045) for p in floor]
	for i in range(4):
		metal.faces.new((
			metal.verts.new(floor[i]),
			metal.verts.new(floor[(i + 1) % 4]),
			metal.verts.new(below[(i + 1) % 4]),
			metal.verts.new(below[i]),
		))
	obj = mesh_object("Ironwork", metal, root)
	finish(obj, True, 0.0015)
	assign(obj, iron)

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
	obj = mesh_object("Glass", panes, root)
	finish(obj, False)
	assign(obj, glass)

	glow = bmesh.new()
	bmesh.ops.create_uvsphere(glow, u_segments=12, v_segments=8, radius=0.045)
	bmesh.ops.translate(glow, verts=glow.verts, vec=(0.0, 0.40, 1.96))
	obj = mesh_object("Ember", glow, root)
	finish(obj, True)
	assign(obj, ember)

	lamp = bpy.data.lights.new("LanternFlame", "POINT")
	lamp.color = (1.0, 0.62, 0.28)
	lamp.energy = 6.0
	lamp.shadow_soft_size = 0.05
	light = bpy.data.objects.new("LanternFlame", lamp)
	light.location = (0.0, 0.40, 1.96)
	light.parent = root
	bpy.context.scene.collection.objects.link(light)


def build_brazier(stone, iron, coals) -> None:
	root = empty("Brazier", (2.35, 0.0, 0.0))
	plinth = bmesh.new()
	lathe(plinth, [
		(0.50, 0.00), (0.50, 0.11),
		(0.36, 0.11), (0.36, 0.20),
		(0.24, 0.22), (0.17, 0.78),
		(0.26, 0.86), (0.32, 0.94),
	], 8)
	obj = mesh_object("Plinth", plinth, root)
	finish(obj, True, 0.006)
	assign(obj, stone)

	bowl = bmesh.new()
	lathe(bowl, [
		(0.18, 0.96), (0.26, 1.02), (0.34, 1.12), (0.46, 1.24), (0.56, 1.32),
		(0.58, 1.36), (0.50, 1.36), (0.42, 1.26), (0.30, 1.14), (0.22, 1.04),
	], 16, close_loop=True, cap=False)
	# Two lugs so the rim has a silhouette.
	for side in (-1, 1):
		bar(bowl, (0.0, side * 0.52, 1.32), (0.0, side * 0.68, 1.30), 0.018, 6)
	obj = mesh_object("Bowl", bowl, root)
	finish(obj, True, 0.003)
	assign(obj, iron)

	bed = bmesh.new()
	bmesh.ops.create_uvsphere(bed, u_segments=16, v_segments=8, radius=1.0)
	for v in bed.verts:
		v.co.x *= 0.30
		v.co.y *= 0.30
		v.co.z *= 0.12
		if v.co.z < 0:
			v.co.z *= 0.25
	bmesh.ops.translate(bed, verts=bed.verts, vec=(0.0, 0.0, 1.18))
	obj = mesh_object("Coals", bed, root)
	finish(obj, True)
	assign(obj, coals)

	fire = bpy.data.lights.new("BrazierFire", "POINT")
	fire.color = (1.0, 0.45, 0.16)
	fire.energy = 10.0
	fire.shadow_soft_size = 0.15
	light = bpy.data.objects.new("BrazierFire", fire)
	light.location = (2.35, 0.0, 1.25)
	light.parent = root
	bpy.context.scene.collection.objects.link(light)


def build_menhir(stone) -> None:
	root = empty("Menhir", (-2.15, 0.15, 0.0))
	# (z, half-width, half-depth, front notch, tip shift)
	sections = [
		(0.00, 0.40, 0.19, 0.00, 0.00),
		(0.18, 0.42, 0.21, 0.00, 0.00),
		(0.90, 0.33, 0.17, 0.04, 0.02),
		(1.55, 0.29, 0.15, 0.08, 0.04),
		(2.15, 0.27, 0.14, 0.03, 0.06),
		(2.75, 0.20, 0.11, 0.00, 0.10),
		(3.20, 0.07, 0.045, 0.00, 0.16),
	]
	bm = bmesh.new()
	rings = []
	sides = 6
	for z, rx, ry, notch, shift in sections:
		ring = []
		for i in range(sides):
			angle = -math.pi / 2 + math.tau * i / sides
			x = math.cos(angle) * rx + shift + z * 0.035
			y = math.sin(angle) * ry
			if i == 0:
				y += notch
			ring.append(bm.verts.new((x, y, z)))
		rings.append(ring)
	for i in range(len(rings) - 1):
		for s in range(sides):
			a = rings[i][s]
			b = rings[i][(s + 1) % sides]
			c = rings[i + 1][(s + 1) % sides]
			d = rings[i + 1][s]
			bm.faces.new((a, b, c, d))
	for ring, flip in ((rings[0], True), (rings[-1], False)):
		acc = Vector((0, 0, 0))
		for v in ring:
			acc += v.co
		center = bm.verts.new(acc / len(ring))
		for s in range(sides):
			a = ring[s]
			b = ring[(s + 1) % sides]
			bm.faces.new((center, b, a) if flip else (center, a, b))
	obj = mesh_object("Stone", bm, root)
	finish(obj, False, 0.008)
	assign(obj, stone)


def build_stage(stone) -> None:
	bm = bmesh.new()
	bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=8.0)
	obj = mesh_object("Ground", bm, empty("Stage", (0, 0, 0)))
	# Grid is built in XY at z=0, which is correct for Blender Z-up.
	finish(obj, False)
	assign(obj, stone)


def add_light(name, kind, location, color, energy, size) -> None:
	data = bpy.data.lights.new(name, kind)
	data.color = color
	data.energy = energy
	if kind == "AREA":
		data.size = size
	else:
		data.shadow_soft_size = size
	obj = bpy.data.objects.new(name, data)
	obj.location = location
	bpy.context.scene.collection.objects.link(obj)
	return obj


def look_at(obj, target) -> None:
	direction = Vector(target) - obj.location
	obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def main() -> None:
	clear_scene()
	wood = material("ValeWood", (0.24, 0.13, 0.08), 0.78, grain=True)
	iron = material("ValeIron", (0.11, 0.08, 0.09), 0.38, metal=1.0)
	stone = material("ValeStone", (0.58, 0.48, 0.52), 0.9)
	glass = material("ValeGlass", (0.85, 0.42, 0.14), 0.2, transmission=1.0)
	ember = material("ValeEmber", (1.0, 0.42, 0.12), 0.4, emit=8.0, emit_color=(1.0, 0.38, 0.08))
	coals = material("ValeCoals", (0.08, 0.03, 0.015), 0.8, emit=3.5, emit_color=(1.0, 0.32, 0.06))
	ground = material("ValeGround", (0.07, 0.055, 0.07), 0.95)

	build_menhir(stone)
	build_lantern(wood, iron, glass, ember)
	build_brazier(stone, iron, coals)
	build_stage(ground)

	world = bpy.data.worlds.new("ValeNight")
	bpy.context.scene.world = world
	world.use_nodes = True
	bg = world.node_tree.nodes["Background"]
	bg.inputs["Color"].default_value = (0.02, 0.016, 0.04, 1)
	bg.inputs["Strength"].default_value = 0.35

	key = add_light("Key", "AREA", (-6.0, -4.0, 5.5), (1.0, 0.86, 0.72), 220, 2.4)
	look_at(key, (0.2, 0.2, 1.2))
	rim = add_light("Rim", "AREA", (5.5, 4.5, 3.4), (0.45, 0.32, 0.95), 90, 2.0)
	look_at(rim, (0.2, 0.0, 1.4))
	fill = add_light("Fill", "AREA", (0.4, -6.0, 1.0), (0.55, 0.6, 0.8), 30, 3.0)
	look_at(fill, (0.2, 0.0, 1.2))

	cam_data = bpy.data.cameras.new("Review")
	cam_data.lens = 36
	cam = bpy.data.objects.new("Review", cam_data)
	cam.location = (0.2, -8.0, 2.7)
	bpy.context.scene.collection.objects.link(cam)
	look_at(cam, (0.1, 0.0, 1.15))
	bpy.context.scene.camera = cam

	scene = bpy.context.scene
	scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 1600
	scene.render.resolution_y = 900
	scene.render.filepath = PREVIEW
	scene.eevee.taa_render_samples = 32
	scene.view_settings.view_transform = "AgX"
	scene.view_settings.look = "AgX - Medium High Contrast"

	for area in bpy.context.screen.areas:
		if area.type == "VIEW_3D":
			for space in area.spaces:
				if space.type == "VIEW_3D":
					space.region_3d.view_perspective = "CAMERA"
					space.shading.type = "MATERIAL"
					space.shading.use_scene_lights = True
					space.shading.use_scene_world = True

	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	bpy.ops.render.render(write_still=True)
	print("SAVED", BLEND)
	print("PREVIEW", PREVIEW)


if __name__ == "__main__":
	main()

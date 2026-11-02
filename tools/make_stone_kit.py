"""Stone mirror frame, the held staff, and the belt lantern.

Blender Z is up and becomes Godot Y. The frame shares the mirror's arch
(opening 2.32 wide, sill at 0.46, crown at 4.54) and stands on the ground.
"""

import math
import os

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(ROOT, "art", "models")
BLEND = os.path.join(ROOT, "art", "blender", "stone_kit.blend")

ARCH_W = 1.16
SILL = 0.46
SPRING = 3.38


def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 960
	scene.render.resolution_y = 1280
	scene.render.film_transparent = False
	world = bpy.data.worlds.new("Kit")
	scene.world = world
	world.use_nodes = True
	bg = world.node_tree.nodes["Background"]
	bg.inputs[0].default_value = (0.045, 0.04, 0.055, 1.0)
	bg.inputs[1].default_value = 0.8


def mat(name, color, rough, metal=0.0, emit=0.0, alpha=1.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = metal
	if emit > 0.0:
		bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
		bsdf.inputs["Emission Strength"].default_value = emit
	if alpha < 1.0:
		m.blend_method = "BLEND" if hasattr(m, "blend_method") else "HASHED"
		bsdf.inputs["Alpha"].default_value = alpha
		bsdf.inputs["Transmission Weight"].default_value = 0.6
	return m


def new_object(name, bm, material):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	me.materials.append(material)
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def _box(name, loc, size, rot, material):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
	ob = bpy.context.active_object
	ob.name = name
	ob.scale = size
	bpy.ops.object.transform_apply(scale=True, rotation=True)
	ob.data.materials.append(material)
	for poly in ob.data.polygons:
		poly.use_smooth = False
	return ob


def _wedge(bm, a0, a1, r0, r1, y0, y1):
	"""A true voussoir: radial sides, curved only by the angle, so neighbours share a joint."""
	verts = []
	for a in (a0, a1):
		for r in (r0, r1):
			for y in (y0, y1):
				verts.append(bm.verts.new((-math.cos(a) * r, y, SPRING + math.sin(a) * r)))
	# 0 a0 r0 y0, 1 a0 r0 y1, 2 a0 r1 y0, 3 a0 r1 y1, 4..7 the a1 end
	bm.faces.new((verts[0], verts[2], verts[3], verts[1]))
	bm.faces.new((verts[4], verts[5], verts[7], verts[6]))
	bm.faces.new((verts[0], verts[1], verts[5], verts[4]))
	bm.faces.new((verts[2], verts[6], verts[7], verts[3]))
	bm.faces.new((verts[0], verts[4], verts[6], verts[2]))
	bm.faces.new((verts[1], verts[3], verts[7], verts[5]))


def stone_frame():
	"""Fitted ashlar. Jambs are large courses; the arch is real wedges with a seated keystone."""
	from mathutils import Matrix
	stone = mat("Stone", (0.42, 0.40, 0.44), 0.86, 0.04)
	bm = bmesh.new()
	thick = 0.36
	inner = ARCH_W
	outer = ARCH_W + thick
	gap = 0.007

	def add_box(center, size):
		bmesh.ops.create_cube(
			bm,
			size=1.0,
			matrix=Matrix.Translation(center) @ Matrix.Diagonal((size.x, size.y, size.z, 1.0)),
		)

	for side in (-1.0, 1.0):
		cx = side * (inner + thick * 0.55)
		add_box(Vector((cx, 0.0, 0.16)), Vector((thick + 0.22, 0.46, 0.32)))
		courses = 4
		z0 = 0.34
		z1 = SPRING - 0.10
		h = (z1 - z0 - gap * (courses - 1)) / courses
		for i in range(courses):
			z = z0 + i * (h + gap) + h * 0.5
			add_box(Vector((side * (inner + thick * 0.5), 0.0, z)), Vector((thick, 0.38, h)))
		add_box(Vector((side * (inner + thick * 0.62), -0.02, SPRING - 0.045)), Vector((thick + 0.18, 0.46, 0.09)))

	count = 11
	weights = [1.0] * count
	weights[count // 2] = 1.45
	total = sum(weights)
	cursor = 0.0
	joint = 0.012 / inner
	for i, w in enumerate(weights):
		a0 = math.pi * cursor / total
		cursor += w
		a1 = math.pi * cursor / total
		key = i == count // 2
		r1 = outer + (0.07 if key else 0.0)
		y0 = -0.15 - (0.035 if key else 0.0)
		y1 = 0.13
		_wedge(bm, a0 + joint, a1 - joint, inner, r1, y0, y1)
		# A second, narrower order on the face, in the same joints.
		_wedge(bm, a0 + joint, a1 - joint, inner - 0.01, inner + 0.05, -0.24, -0.15)
	add_box(Vector((0.0, 0.0, 0.02)), Vector((inner * 1.7, 0.36, 0.04)))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	frame = new_object("StoneFrame", bm, stone)
	bpy.context.view_layer.objects.active = frame
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.bevel(offset=0.01, segments=1, affect="EDGES")
	bpy.ops.object.mode_set(mode="OBJECT")
	for poly in frame.data.polygons:
		poly.use_smooth = False
	return frame


def _square_sweep(name, points, width, depth, material):
	bm = bmesh.new()
	rings = []
	hw = width * 0.5
	hd = depth * 0.5
	for i, p in enumerate(points):
		if i == 0:
			tangent = points[1] - p
		elif i == len(points) - 1:
			tangent = p - points[i - 1]
		else:
			tangent = points[i + 1] - points[i - 1]
		tangent.normalize()
		up = Vector((0.0, 1.0, 0.0))
		if abs(tangent.dot(up)) > 0.92:
			up = Vector((1.0, 0.0, 0.0))
		side = tangent.cross(up).normalized()
		lift = side.cross(tangent).normalized()
		rings.append((
			bm.verts.new(p + side * hw + lift * hd),
			bm.verts.new(p - side * hw + lift * hd),
			bm.verts.new(p - side * hw - lift * hd),
			bm.verts.new(p + side * hw - lift * hd),
		))
	for i in range(len(rings) - 1):
		a = rings[i]
		b = rings[i + 1]
		for k in range(4):
			k2 = (k + 1) % 4
			bm.faces.new((a[k], a[k2], b[k2], b[k]))
	bm.faces.new(rings[0])
	bm.faces.new(tuple(reversed(rings[-1])))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return new_object(name, bm, material)


def _sweep(name, points, radius, sides, material):
	bm = bmesh.new()
	rings = []
	for i, p in enumerate(points):
		if i == 0:
			tangent = points[1] - p
		elif i == len(points) - 1:
			tangent = p - points[i - 1]
		else:
			tangent = points[i + 1] - points[i - 1]
		tangent.normalize()
		up = Vector((0.0, 1.0, 0.0))
		if abs(tangent.dot(up)) > 0.9:
			up = Vector((1.0, 0.0, 0.0))
		side = tangent.cross(up).normalized()
		lift = side.cross(tangent).normalized()
		row = []
		for k in range(sides):
			a = math.tau * k / sides
			row.append(bm.verts.new(p + side * math.cos(a) * radius + lift * math.sin(a) * radius))
		rings.append(row)
	for i in range(len(rings) - 1):
		for k in range(sides):
			k2 = (k + 1) % sides
			bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
	bm.faces.new(rings[0])
	bm.faces.new(list(reversed(rings[-1])))
	return new_object(name, bm, material)


def staff():
	"""Shaft in the hand, iron cradle around the orb the rig already hangs at z 1.44."""
	wood = mat("Wood", (0.32, 0.22, 0.16), 0.58, 0.0)
	iron = mat("Iron", (0.34, 0.35, 0.38), 0.38, 0.85)
	grip = mat("Grip", (0.16, 0.10, 0.08), 0.72, 0.0)
	bm = bmesh.new()
	sides = 8
	zs = (-0.66, -0.15, 0.25, 0.75, 1.12)
	rs = (0.042, 0.034, 0.032, 0.028, 0.024)
	rings = []
	for z, r in zip(zs, rs):
		row = []
		for k in range(sides):
			a = math.tau * k / sides
			row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
		rings.append(row)
	for i in range(len(rings) - 1):
		for k in range(sides):
			k2 = (k + 1) % sides
			bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
	bm.faces.new(rings[0])
	shaft = new_object("Staff", bm, wood)
	hold = _sweep(
		"Grip",
		[Vector((0.0, 0.0, -0.12)), Vector((0.0, 0.0, 0.18))],
		0.040,
		8,
		grip,
	)
	names = [shaft.name, hold.name]
	for z, r, h, label in ((-0.62, 0.055, 0.08, "Ferrule"), (0.48, 0.040, 0.045, "Band"), (1.08, 0.058, 0.10, "Collar")):
		bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=h, location=(0.0, 0.0, z))
		part = bpy.context.active_object
		part.name = label
		part.data.materials.append(iron)
		names.append(part.name)
	bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.062, radius2=0.034, depth=0.07, location=(0.0, 0.0, -0.68))
	butt = bpy.context.active_object
	butt.name = "Butt"
	butt.data.materials.append(iron)
	names.append(butt.name)
	setting = []
	for i in range(18):
		u = i / 17.0
		setting.append(Vector((-math.sin(u * math.pi) * 0.13, 0.0, 1.22 + u * 0.48)))
	for i in range(1, 18):
		u = i / 17.0
		setting.append(Vector((math.sin(u * math.pi) * 0.13, 0.0, 1.70 - u * 0.48)))
	head = _square_sweep("Setting", setting, 0.036, 0.028, iron)
	names.append(head.name)
	neck = _square_sweep("Neck", [Vector((0.0, 0.0, 1.08)), Vector((0.0, 0.0, 1.24))], 0.04, 0.032, iron)
	names.append(neck.name)
	bar = _square_sweep(
		"Crossbar",
		[Vector((-0.16, 0.0, 1.36)), Vector((0.16, 0.0, 1.36))],
		0.032,
		0.026,
		iron,
	)
	names.append(bar.name)
	bpy.ops.object.select_all(action="DESELECT")
	for name in names:
		bpy.data.objects[name].select_set(True)
	bpy.context.view_layer.objects.active = shaft
	bpy.ops.object.join()
	shaft.name = "Staff"
	return shaft


def hand_lantern():
	"""A palm lantern: chain, cap, barred cage, warm glass. Pivot is the top link."""
	iron = mat("LanternIron", (0.13, 0.12, 0.14), 0.36, 0.82)
	glass = mat("LanternGlass", (1.0, 0.62, 0.22), 0.12, 0.0, emit=1.1, alpha=0.72)
	names = []
	for i, z in enumerate((-0.018, -0.048, -0.078)):
		bpy.ops.mesh.primitive_torus_add(
			major_radius=0.016,
			minor_radius=0.004,
			location=(0.0, 0.0, z),
			rotation=(math.pi / 2.0, 0.0, (i % 2) * math.pi / 2.0),
		)
		link = bpy.context.active_object
		link.name = "Link%d" % i
		link.data.materials.append(iron)
		names.append(link.name)
	bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.075, radius2=0.016, depth=0.055, location=(0.0, 0.0, -0.125))
	cap = bpy.context.active_object
	cap.name = "Cap"
	cap.data.materials.append(iron)
	names.append(cap.name)
	for z, r in ((-0.155, 0.062), (-0.335, 0.058)):
		bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.006, location=(0.0, 0.0, z), rotation=(0.0, 0.0, 0.0))
		ring = bpy.context.active_object
		ring.name = "Ring"
		ring.data.materials.append(iron)
		names.append(ring.name)
	for k in range(6):
		a = math.tau * k / 6.0
		bpy.ops.mesh.primitive_cylinder_add(
			vertices=6,
			radius=0.005,
			depth=0.18,
			location=(math.cos(a) * 0.06, math.sin(a) * 0.06, -0.245),
		)
		bar = bpy.context.active_object
		bar.name = "Bar%d" % k
		bar.data.materials.append(iron)
		names.append(bar.name)
	bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.07, depth=0.02, location=(0.0, 0.0, -0.35))
	base = bpy.context.active_object
	base.name = "Base"
	base.data.materials.append(iron)
	names.append(base.name)
	gbm = bmesh.new()
	for k in range(6):
		a0 = math.tau * k / 6.0
		a1 = math.tau * (k + 1) / 6.0
		r = 0.048
		gbm.faces.new((
			gbm.verts.new((math.cos(a0) * r, math.sin(a0) * r, -0.32)),
			gbm.verts.new((math.cos(a1) * r, math.sin(a1) * r, -0.32)),
			gbm.verts.new((math.cos(a1) * r, math.sin(a1) * r, -0.17)),
			gbm.verts.new((math.cos(a0) * r, math.sin(a0) * r, -0.17)),
		))
	pane = new_object("Panes", gbm, glass)
	names.append(pane.name)
	bpy.ops.mesh.primitive_uv_sphere_add(radius=0.026, location=(0.0, 0.0, -0.245))
	ember = bpy.context.active_object
	ember.name = "Ember"
	ember.data.materials.append(glass)
	names.append(ember.name)
	bpy.ops.object.select_all(action="DESELECT")
	for name in names:
		bpy.data.objects[name].select_set(True)
	bpy.context.view_layer.objects.active = bpy.data.objects[names[0]]
	bpy.ops.object.join()
	lantern = bpy.data.objects[names[0]]
	lantern.name = "HandLantern"
	return lantern


def look(camera, target):
	direction = (target - camera.location).normalized()
	camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render(path, objects, location, target, lens=50):
	for ob in bpy.context.scene.objects:
		ob.hide_render = ob not in objects
	cam_data = bpy.data.cameras.new("Cam")
	cam_data.lens = lens
	cam = bpy.data.objects.new("Cam", cam_data)
	bpy.context.scene.collection.objects.link(cam)
	cam.location = location
	look(cam, target)
	bpy.context.scene.camera = cam
	key_data = bpy.data.lights.new("Key", "AREA")
	key_data.energy = 420
	key_data.size = 2.2
	key = bpy.data.objects.new("Key", key_data)
	bpy.context.scene.collection.objects.link(key)
	key.location = target + Vector((2.2, -3.2, 2.4))
	look(key, target)
	fill_data = bpy.data.lights.new("Fill", "AREA")
	fill_data.energy = 220
	fill_data.size = 4.0
	fill = bpy.data.objects.new("Fill", fill_data)
	bpy.context.scene.collection.objects.link(fill)
	fill.location = target + Vector((-2.4, -2.0, 0.6))
	look(fill, target)
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	bpy.data.objects.remove(cam, do_unlink=True)
	bpy.data.objects.remove(key, do_unlink=True)
	bpy.data.objects.remove(fill, do_unlink=True)


def export(ob, filename):
	loc = ob.location.copy()
	ob.location = (0.0, 0.0, 0.0)
	bpy.ops.object.select_all(action="DESELECT")
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
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
	print("exported", path)


def main():
	reset()
	frame = stone_frame()
	staff_ob = staff()
	staff_ob.location = (3.4, 0.0, 0.0)
	bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(3.4, 0.0, 1.44))
	stand_in = bpy.context.active_object
	stand_in.name = "StandInOrb"
	stand_in.data.materials.append(mat("Orb", (0.62, 0.35, 1.0), 0.15, 0.0, emit=2.0))
	lantern = hand_lantern()
	lantern.location = (-2.6, 0.0, 1.6)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	render(
		"/tmp/stone_frame.png",
		{frame},
		Vector((3.1, -7.2, 2.15)),
		Vector((0.0, 0.0, 2.15)),
		36,
	)
	render(
		"/tmp/held_staff.png",
		{staff_ob, stand_in},
		Vector((3.4, -3.6, 0.7)),
		Vector((3.4, 0.0, 0.7)),
		50,
	)
	render(
		"/tmp/staff_head.png",
		{staff_ob, stand_in},
		Vector((3.85, -1.15, 1.55)),
		Vector((3.4, 0.0, 1.46)),
		60,
	)
	render(
		"/tmp/hand_lantern.png",
		{lantern},
		Vector((-2.15, -0.85, 1.42)),
		Vector((-2.6, 0.0, 1.38)),
		65,
	)
	export(frame, "stone_frame.glb")
	export(staff_ob, "staff.glb")
	export(lantern, "hand_lantern.glb")


if __name__ == "__main__":
	main()

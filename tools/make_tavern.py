"""The Kindled Keg — pitched timber hall and stout dwarves.

Run: blender --background --python tools/make_tavern.py
Does not rewrite the wanderer, Shade, gothic_bay, or toad.
"""

from __future__ import annotations

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_hero_props import (  # noqa: E402
	bar,
	clear_scene,
	empty,
	export_glb,
	finish,
	lathe,
	mesh_object,
)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLEND = os.path.join(ROOT, "art", "blender", "tavern.blend")
TEX = os.path.join(ROOT, "art", "textures")

HX = 4.55
HY = 3.65
WALL = 0.22
DOOR_W = 1.22
DOOR_H = 2.22
EAVE_Z = 3.12
RIDGE_Z = 4.72


def box(bm, loc, size):
	geo = bmesh.ops.create_cube(bm, size=1.0)
	ox, oy, oz = loc
	sx, sy, sz = size
	for v in geo["verts"]:
		v.co.x = v.co.x * sx + ox
		v.co.y = v.co.y * sy + oy
		v.co.z = v.co.z * sz + oz


def sphere(bm, radius, loc, u=12, v=8, sx=1.0, sy=1.0, sz=1.0):
	geo = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius)
	ox, oy, oz = loc
	for v in geo["verts"]:
		v.co.x = v.co.x * sx + ox
		v.co.y = v.co.y * sy + oy
		v.co.z = v.co.z * sz + oz


def lathe_at(bm, profile, segments, loc, cap=True):
	n0 = len(bm.verts)
	lathe(bm, profile, segments, cap=cap)
	ox, oy = loc[0], loc[1]
	oz = loc[2] if len(loc) > 2 else 0.0
	for v in list(bm.verts)[n0:]:
		v.co.x += ox
		v.co.y += oy
		v.co.z += oz


def panel(bm, corners, inward, thick):
	n = Vector(inward).normalized()
	outer = [bm.verts.new(Vector(p)) for p in corners]
	inner = [bm.verts.new(Vector(p) + n * thick) for p in corners]
	bm.faces.new(outer)
	bm.faces.new(list(reversed(inner)))
	for i in range(len(corners)):
		j = (i + 1) % len(corners)
		bm.faces.new((outer[i], outer[j], inner[j], inner[i]))


def unwrap(obj, smart=False):
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	if smart:
		bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.018)
	else:
		bpy.ops.uv.cube_project(cube_size=1.8, correct_aspect=True)
	bpy.ops.object.mode_set(mode="OBJECT")
	obj.select_set(False)


def part(name, parent, material, bevel=0.01, smart=False):
	bm = bmesh.new()

	def done():
		obj = mesh_object(name, bm, parent, material, bevel)
		unwrap(obj, smart=smart)
		return obj

	return bm, done


def _load_img(path, non_color=False):
	img = bpy.data.images.load(path, check_existing=True)
	if non_color:
		img.colorspace_settings.name = "Non-Color"
	return img


def mat(name, prefix=None, tint=(1.0, 1.0, 1.0), rough=0.8, metal=0.0, emit=None, alpha=1.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bsdf = nt.nodes["Principled BSDF"]
	bsdf.inputs["Metallic"].default_value = metal
	bsdf.inputs["Roughness"].default_value = rough
	if emit is not None:
		bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
		if "Emission Strength" in bsdf.inputs:
			bsdf.inputs["Emission Strength"].default_value = emit[3] if len(emit) > 3 else 2.0
	if alpha < 1.0:
		bsdf.inputs["Alpha"].default_value = alpha
		if hasattr(m, "surface_render_method"):
			m.surface_render_method = "BLENDED"
		m.use_backface_culling = False
	if prefix:
		alb_path = os.path.join(TEX, prefix + "_albedo.png")
		nrm_path = os.path.join(TEX, prefix + "_normal.png")
		rgh_path = os.path.join(TEX, prefix + "_rough.png")
		if os.path.isfile(alb_path):
			alb = nt.nodes.new("ShaderNodeTexImage")
			alb.image = _load_img(alb_path)
			mix = nt.nodes.new("ShaderNodeMixRGB")
			mix.blend_type = "MULTIPLY"
			mix.inputs["Fac"].default_value = 1.0
			mix.inputs["Color2"].default_value = (tint[0], tint[1], tint[2], 1.0)
			nt.links.new(alb.outputs["Color"], mix.inputs["Color1"])
			nt.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
		if os.path.isfile(nrm_path):
			tex_n = nt.nodes.new("ShaderNodeTexImage")
			tex_n.image = _load_img(nrm_path, True)
			nmap = nt.nodes.new("ShaderNodeNormalMap")
			nmap.inputs["Strength"].default_value = 1.1
			nt.links.new(tex_n.outputs["Color"], nmap.inputs["Color"])
			nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
		if os.path.isfile(rgh_path):
			tex_r = nt.nodes.new("ShaderNodeTexImage")
			tex_r.image = _load_img(rgh_path, True)
			nt.links.new(tex_r.outputs["Color"], bsdf.inputs["Roughness"])
	else:
		bsdf.inputs["Base Color"].default_value = (tint[0], tint[1], tint[2], 1.0)
	return m


def foundation(root, stone):
	bm, done = part("Foundation", root, stone, 0.012)
	box(bm, (0.0, 0.0, -0.28), (HX * 2.0 + 0.7, HY * 2.0 + 0.7, 0.7))
	for i, x in enumerate((-HX - 0.12, -HX / 3, HX / 3, HX + 0.12)):
		for j, y in enumerate((-HY - 0.12, 0.0, HY + 0.12)):
			h = 0.55 + ((i + j) % 3) * 0.12
			box(bm, (x, y, h * 0.35), (0.42, 0.42, h))
	# stoop
	box(bm, (HX + 0.55, 0.0, 0.08), (1.15, 2.15, 0.18))
	box(bm, (HX + 0.95, 0.0, -0.02), (0.7, 1.7, 0.14))
	done()


def walls(root, plaster, wood, beam):
	h = EAVE_Z - 0.08
	bm, done = part("Plaster", root, plaster, 0.006)
	# back −X
	panel(bm, [(-HX, -HY, 0.18), (-HX, HY, 0.18), (-HX, HY, h), (-HX, -HY, h)], (1, 0, 0), WALL)
	# ±Y long walls
	panel(bm, [(-HX, -HY, 0.18), (HX, -HY, 0.18), (HX, -HY, h), (-HX, -HY, h)], (0, 1, 0), WALL)
	panel(bm, [(-HX, HY, 0.18), (-HX, HY, h), (HX, HY, h), (HX, HY, 0.18)], (0, -1, 0), WALL)
	# +X split around the door
	gap = DOOR_W * 0.5
	panel(bm, [(HX, -HY, 0.18), (HX, -gap - 0.06, 0.18), (HX, -gap - 0.06, h), (HX, -HY, h)], (-1, 0, 0), WALL)
	panel(bm, [(HX, gap + 0.06, 0.18), (HX, HY, 0.18), (HX, HY, h), (HX, gap + 0.06, h)], (-1, 0, 0), WALL)
	panel(bm, [(HX, -gap - 0.06, DOOR_H), (HX, gap + 0.06, DOOR_H), (HX, gap + 0.06, h), (HX, -gap - 0.06, h)], (-1, 0, 0), WALL)
	# close the attic — gable triangles
	panel(bm, [(HX, -HY, h), (HX, HY, h), (HX, 0.0, RIDGE_Z)], (-1, 0, 0), WALL)
	panel(bm, [(-HX, HY, h), (-HX, -HY, h), (-HX, 0.0, RIDGE_Z)], (1, 0, 0), WALL)
	done()
	bm, done = part("Wainscot", root, wood, 0.005)
	box(bm, (-HX + 0.08, 0.0, 0.52), (0.1, HY * 2.0 - 0.5, 0.72))
	box(bm, (0.0, -HY + 0.08, 0.52), (HX * 2.0 - 0.5, 0.1, 0.72))
	box(bm, (0.0, HY - 0.08, 0.52), (HX * 2.0 - 0.5, 0.1, 0.72))
	done()
	bm, done = part("Timbers", root, beam, 0.01)
	posts_x = [-HX + 0.08, -HX / 3.0, HX / 3.0, HX - 0.08]
	posts_y = [-HY + 0.08, 0.0, HY - 0.08]
	for x in posts_x:
		for y in posts_y:
			if abs(x - (HX - 0.08)) < 0.05 and abs(y) < gap + 0.1:
				continue
			box(bm, (x, y, h * 0.5), (0.16, 0.16, h))
	for y in (-HY + 0.08, HY - 0.08):
		box(bm, (0.0, y, h - 0.07), (HX * 2.0 - 0.12, 0.14, 0.16))
		box(bm, (0.0, y, 0.86), (HX * 2.0 - 0.2, 0.12, 0.1))
	for x in (-HX + 0.08, HX - 0.08):
		box(bm, (x, 0.0, h - 0.07), (0.14, HY * 2.0 - 0.12, 0.16))
	# braces
	for y in (-HY + 0.08, HY - 0.08):
		bar(bm, (-HX + 0.2, y, 0.9), (-HX / 3.0, y, h - 0.2), 0.05, 6)
		bar(bm, (HX - 0.2, y, 0.9), (HX / 3.0, y, h - 0.2), 0.05, 6)
	done()


def door_and_windows(root, wood, iron, glass):
	bm, done = part("Door", root, wood, 0.007)
	box(bm, (HX - 0.04, -0.32, DOOR_H * 0.5 - 0.02), (0.08, 1.08, DOOR_H - 0.1))
	box(bm, (HX - 0.01, -0.32, 0.16), (0.1, 1.12, 0.12))
	box(bm, (HX - 0.01, -0.32, DOOR_H - 0.18), (0.1, 1.12, 0.1))
	box(bm, (HX - 0.01, -0.32, DOOR_H * 0.52), (0.1, 1.12, 0.08))
	box(bm, (HX - 0.01, -0.32, DOOR_H * 0.5), (0.1, 0.08, DOOR_H - 0.2))
	# frame
	box(bm, (HX + 0.02, 0.0, DOOR_H * 0.5), (0.1, 1.42, DOOR_H + 0.12))
	done()
	bm, done = part("DoorIron", root, iron, 0.003)
	box(bm, (HX + 0.06, 0.18, 1.08), (0.04, 0.08, 0.16))
	bar(bm, (HX + 0.08, 0.22, 1.08), (HX + 0.18, 0.32, 1.08), 0.016, 6)
	for z in (0.45, 1.05, 1.7):
		box(bm, (HX + 0.04, -0.32, z), (0.03, 1.0, 0.03))
	done()
	spots = [(-2.35, HY), (1.85, HY), (-2.35, -HY), (1.85, -HY)]
	bm, done = part("WindowFrames", root, wood, 0.005)
	for x, y in spots:
		box(bm, (x, y, 1.78), (1.05, 0.14, 1.22))
		box(bm, (x, y, 1.78), (0.07, 0.16, 1.22))
		box(bm, (x, y, 1.78), (1.05, 0.16, 0.07))
		box(bm, (x - 0.26, y, 1.78), (0.05, 0.16, 1.1))
		box(bm, (x + 0.26, y, 1.78), (0.05, 0.16, 1.1))
		box(bm, (x, y, 1.48), (0.95, 0.16, 0.05))
		box(bm, (x, y, 2.08), (0.95, 0.16, 0.05))
		# sill
		box(bm, (x, y * 1.02, 1.14), (1.12, 0.18, 0.08))
		box(bm, (x, y * 1.02, 2.42), (1.12, 0.16, 0.07))
	done()
	bm, done = part("Shutters", root, wood, 0.005)
	for x, y in spots:
		side = 1.0 if y > 0 else -1.0
		box(bm, (x - 0.62, y + side * 0.08, 1.78), (0.28, 0.05, 1.05))
		box(bm, (x + 0.62, y + side * 0.08, 1.78), (0.28, 0.05, 1.05))
		for sx in (-0.62, 0.62):
			box(bm, (x + sx, y + side * 0.08, 1.78), (0.04, 0.06, 1.0))
			box(bm, (x + sx, y + side * 0.08, 1.78), (0.26, 0.06, 0.04))
	done()
	bm, done = part("WindowGlass", root, glass, 0.0)
	for x, y in spots:
		box(bm, (x, y * 0.985, 1.78), (0.88, 0.025, 1.02))
	done()


def roof(root, slate, beam, stone):
	over = 0.55
	x0, x1 = -HX - over, HX + over
	ye = HY + over
	bm, done = part("Roof", root, slate, 0.004)
	# two pitches, 8 cm thick
	panel(bm, [(x0, ye, EAVE_Z), (x1, ye, EAVE_Z), (x1, 0.0, RIDGE_Z), (x0, 0.0, RIDGE_Z)], (0, -0.55, -1), 0.09)
	panel(bm, [(x0, -ye, EAVE_Z), (x0, 0.0, RIDGE_Z), (x1, 0.0, RIDGE_Z), (x1, -ye, EAVE_Z)], (0, 0.55, -1), 0.09)
	# ridge cap
	box(bm, (0.0, 0.0, RIDGE_Z + 0.06), (HX * 2.0 + 0.9, 0.28, 0.1))
	done()
	bm, done = part("RoofTiles", root, slate, 0.0)
	nx, ny = 9, 4
	for i in range(nx):
		for j in range(ny):
			t0 = i / float(nx) - 0.008
			t1 = (i + 1) / float(nx) + 0.008
			u0 = j / float(ny)
			u1 = (j + 1) / float(ny) + 0.05
			x_a, x_b = x0 + t0 * (x1 - x0), x0 + t1 * (x1 - x0)
			y_a = ye + u0 * (0.0 - ye)
			y_b = ye + u1 * (0.0 - ye)
			z_a = EAVE_Z + u0 * (RIDGE_Z - EAVE_Z) + 0.05
			z_b = EAVE_Z + u1 * (RIDGE_Z - EAVE_Z) + 0.05
			panel(bm, [(x_a, y_a, z_a), (x_b, y_a, z_a), (x_b, y_b, z_b), (x_a, y_b, z_b)], (0, -0.55, -1), 0.03)
			panel(bm, [(x_a, -y_a, z_a), (x_a, -y_b, z_b), (x_b, -y_b, z_b), (x_b, -y_a, z_a)], (0, 0.55, -1), 0.03)
	done()
	bm, done = part("Bargeboard", root, beam, 0.006)
	for sx in (-1.0, 1.0):
		bar(bm, (sx * (HX + 0.08), ye - 0.05, EAVE_Z + 0.02), (sx * (HX + 0.08), 0.0, RIDGE_Z + 0.04), 0.05, 6)
		bar(bm, (sx * (HX + 0.08), -ye + 0.05, EAVE_Z + 0.02), (sx * (HX + 0.08), 0.0, RIDGE_Z + 0.04), 0.05, 6)
	done()
	bm, done = part("Rafters", root, beam, 0.008)
	for i in range(8):
		x = -HX + 0.35 + i * ((HX * 2.0 - 0.7) / 7.0)
		bar(bm, (x, ye - 0.1, EAVE_Z - 0.05), (x, 0.0, RIDGE_Z - 0.12), 0.055, 6)
		bar(bm, (x, -ye + 0.1, EAVE_Z - 0.05), (x, 0.0, RIDGE_Z - 0.12), 0.055, 6)
	box(bm, (0.0, ye, EAVE_Z - 0.08), (HX * 2.0 + 1.0, 0.16, 0.12))
	box(bm, (0.0, -ye, EAVE_Z - 0.08), (HX * 2.0 + 1.0, 0.16, 0.12))
	done()
	bm, done = part("Chimney", root, stone, 0.012)
	box(bm, (-2.55, -HY + 0.35, 4.15), (0.72, 0.62, 1.85))
	box(bm, (-2.55, -HY + 0.35, 5.12), (0.92, 0.82, 0.16))
	box(bm, (-2.55, -HY + 0.35, 5.28), (0.55, 0.45, 0.22))
	box(bm, (-2.72, -HY + 0.35, 5.42), (0.16, 0.16, 0.28))
	box(bm, (-2.38, -HY + 0.35, 5.42), (0.16, 0.16, 0.28))
	done()


def sign_and_porch(root, wood, beam, iron, slate):
	bm, done = part("PorchPosts", root, beam, 0.01)
	for y in (-0.95, 0.95):
		box(bm, (HX + 1.15, y, 1.45), (0.16, 0.16, 2.7))
	box(bm, (HX + 1.15, 0.0, 2.78), (0.16, 2.15, 0.14))
	bar(bm, (HX + 0.15, -0.95, 2.7), (HX + 1.15, -0.95, 2.78), 0.045, 6)
	bar(bm, (HX + 0.15, 0.95, 2.7), (HX + 1.15, 0.95, 2.78), 0.045, 6)
	done()
	bm, done = part("PorchRoof", root, slate, 0.004)
	panel(
		bm,
		[(HX + 0.08, 1.4, 2.98), (HX + 1.85, 1.4, 2.62), (HX + 1.85, -1.4, 2.62), (HX + 0.08, -1.4, 2.98)],
		(0.35, 0.0, -1),
		0.08,
	)
	done()
	bm, done = part("PorchLantern", root, iron, 0.003)
	box(bm, (HX + 0.28, 0.62, 2.18), (0.12, 0.12, 0.22))
	box(bm, (HX + 0.28, 0.62, 2.32), (0.16, 0.16, 0.04))
	box(bm, (HX + 0.28, 0.62, 2.06), (0.16, 0.16, 0.04))
	bar(bm, (HX + 0.28, 0.62, 2.32), (HX + 0.28, 0.62, 2.72), 0.012, 6)
	done()
	bm, done = part("Sign", root, wood, 0.008)
	box(bm, (HX + 0.72, 1.35, 2.62), (0.08, 1.05, 0.62))
	# tankard relief
	lathe_at(bm, [(0.07, 2.42), (0.11, 2.46), (0.1, 2.68), (0.12, 2.74)], 8, (HX + 0.78, 1.35))
	done()
	bm, done = part("SignIron", root, iron, 0.003)
	bar(bm, (HX + 0.12, 1.35, 3.02), (HX + 0.72, 1.35, 2.95), 0.016, 6)
	bar(bm, (HX + 0.08, 1.35, 3.08), (HX - 0.05, 1.35, 3.08), 0.016, 6)
	done()
	bm, done = part("Yard", root, wood, 0.008)
	# rain barrel
	lathe_at(bm, [(0.18, 0.02), (0.28, 0.08), (0.3, 0.42), (0.26, 0.7), (0.2, 0.78)], 10, (HX + 1.55, -1.55))
	# crates
	box(bm, (HX + 1.35, 1.55, 0.28), (0.55, 0.42, 0.42))
	box(bm, (HX + 1.55, 1.55, 0.62), (0.38, 0.32, 0.28))
	# hitching rail
	box(bm, (HX + 2.05, 0.0, 0.85), (0.08, 1.85, 0.08))
	box(bm, (HX + 2.05, -0.9, 0.45), (0.08, 0.08, 0.9))
	box(bm, (HX + 2.05, 0.9, 0.45), (0.08, 0.08, 0.9))
	done()
	bm, done = part("Firewood", root, beam, 0.006)
	for i in range(7):
		box(bm, (HX - 0.55, -HY + 0.55, 0.12 + (i % 3) * 0.14), (0.55, 0.12, 0.12))
	box(bm, (HX - 0.55, -HY + 0.55, 0.08), (0.62, 0.55, 0.08))
	done()


def floor_and_bar(root, wood, beam, iron, stone):
	bm, done = part("Floor", root, wood, 0.003)
	n = 16
	w = (HX * 2.0 - 0.2) / n
	for i in range(n):
		x = -HX + 0.1 + (i + 0.5) * w
		box(bm, (x, 0.0, 0.045), (w - 0.01, HY * 2.0 - 0.28, 0.07))
	done()
	bm, done = part("Bar", root, wood, 0.009)
	box(bm, (-2.62, 0.1, 0.55), (0.62, 4.55, 1.0))
	box(bm, (-2.62, 0.1, 1.12), (0.82, 4.75, 0.09))
	box(bm, (-2.95, 0.1, 0.22), (0.1, 4.4, 0.16))
	# foot rail posts
	for y in (-1.8, -0.6, 0.6, 1.8):
		box(bm, (-2.18, y, 0.18), (0.06, 0.06, 0.22))
	done()
	bm, done = part("BarRail", root, iron, 0.003)
	bar(bm, (-2.18, -2.05, 0.28), (-2.18, 2.25, 0.28), 0.026, 8)
	done()
	bm, done = part("Shelves", root, beam, 0.007)
	for z in (1.52, 1.98, 2.42):
		box(bm, (-HX + 0.32, 0.1, z), (0.3, 4.15, 0.055))
	for y in (-1.9, 0.1, 2.1):
		box(bm, (-HX + 0.32, y, 1.95), (0.06, 0.06, 1.05))
	done()
	bm, done = part("Hearth", root, stone, 0.011)
	box(bm, (-2.45, -HY + 0.62, 0.16), (1.95, 0.95, 0.22))
	box(bm, (-3.25, -HY + 0.48, 1.15), (0.32, 0.58, 1.95))
	box(bm, (-1.65, -HY + 0.48, 1.15), (0.32, 0.58, 1.95))
	box(bm, (-2.45, -HY + 0.42, 2.18), (1.95, 0.52, 0.28))
	box(bm, (-2.45, -HY + 0.28, 1.15), (1.55, 0.16, 1.75))
	done()


def dressing(root, mats):
	bm, done = part("Bottles", root, mats["glass_g"], 0.002)
	for i in range(12):
		y = -1.85 + i * 0.34
		z = 1.58 + (i % 3) * 0.46
		lathe_at(
			bm,
			[(0.0, z), (0.042, z + 0.02), (0.048, z + 0.14), (0.028, z + 0.2), (0.016, z + 0.28), (0.018, z + 0.34)],
			8,
			(-HX + 0.32, y),
		)
	done()
	bm, done = part("BottlesDark", root, mats["glass_r"], 0.002)
	for i in range(8):
		y = -1.6 + i * 0.48
		lathe_at(bm, [(0.0, 2.46), (0.038, 2.48), (0.046, 2.64), (0.018, 2.76)], 8, (-HX + 0.32, y))
	done()
	bm, done = part("Kegs", root, mats["wood"], 0.01)
	for loc in ((-3.5, 2.55, 0.4), (-3.5, 2.98, 0.4), (-3.12, 2.76, 0.92)):
		lathe_at(
			bm,
			[(0.16, loc[2] - 0.3), (0.27, loc[2] - 0.2), (0.31, loc[2]), (0.27, loc[2] + 0.2), (0.16, loc[2] + 0.3)],
			12,
			(loc[0], loc[1]),
		)
	done()
	bm, done = part("Tables", root, mats["wood"], 0.009)
	spots = [(1.42, 1.78), (1.48, -1.62), (2.62, 0.12)]
	for x, y in spots:
		box(bm, (x, y, 0.76), (1.42, 0.88, 0.07))
		box(bm, (x, y, 0.72), (1.28, 0.08, 0.05))
		for sx, sy in ((-0.55, -0.32), (0.55, -0.32), (-0.55, 0.32), (0.55, 0.32)):
			box(bm, (x + sx, y + sy, 0.38), (0.07, 0.07, 0.76))
	done()
	bm, done = part("Benches", root, mats["wood"], 0.007)
	for x, y in spots:
		for sy in (0.64, -0.64):
			box(bm, (x, y + sy, 0.42), (1.32, 0.26, 0.07))
			box(bm, (x - 0.5, y + sy, 0.22), (0.06, 0.06, 0.4))
			box(bm, (x + 0.5, y + sy, 0.22), (0.06, 0.06, 0.4))
	done()
	bm, done = part("Stools", root, mats["wood"], 0.007)
	for y in (-1.5, -0.5, 0.5, 1.5):
		lathe_at(bm, [(0.14, 0.46), (0.16, 0.5), (0.16, 0.54)], 8, (-2.02, y))
		for a in range(3):
			ang = a * math.tau / 3.0
			box(bm, (-2.02 + math.cos(ang) * 0.1, y + math.sin(ang) * 0.1, 0.24), (0.045, 0.045, 0.46))
	done()
	bm, done = part("Tankards", root, mats["pewter"], 0.003)
	for x, y, z in ((1.28, 1.62, 0.86), (1.58, 1.9, 0.86), (1.4, -1.48, 0.86), (-2.38, -0.45, 1.2), (-2.42, 0.55, 1.2)):
		lathe_at(bm, [(0.038, z), (0.052, z + 0.02), (0.048, z + 0.12), (0.056, z + 0.14)], 8, (x, y))
		bar(bm, (x + 0.055, y, z + 0.04), (x + 0.055, y, z + 0.12), 0.01, 5)
	done()
	bm, done = part("Loft", root, mats["wood"], 0.007)
	box(bm, (-0.2, HY - 1.2, 2.42), (HX * 2.0 - 1.5, 2.2, 0.07))
	box(bm, (-0.2, HY - 2.28, 2.58), (HX * 2.0 - 1.7, 0.08, 0.38))
	done()
	bm, done = part("Ladder", root, mats["beam"], 0.005)
	box(bm, (2.92, HY - 2.32, 1.22), (0.055, 0.055, 2.38))
	box(bm, (3.32, HY - 2.32, 1.22), (0.055, 0.055, 2.38))
	for i in range(8):
		box(bm, (3.12, HY - 2.32, 0.26 + i * 0.3), (0.48, 0.045, 0.035))
	done()
	bm, done = part("Beams", root, mats["beam"], 0.01)
	for y in (-1.85, 0.0, 1.85):
		box(bm, (0.15, y, 2.95), (HX * 2.0 - 0.8, 0.13, 0.16))
	done()
	bm, done = part("Chandelier", root, mats["iron"], 0.004)
	bar(bm, (0.35, 0.05, 2.9), (0.35, 0.05, 2.32), 0.012, 6)
	for i in range(5):
		a = i * math.tau / 5.0
		px = 0.35 + math.cos(a) * 0.42
		py = 0.05 + math.sin(a) * 0.42
		bar(bm, (0.35, 0.05, 2.38), (px, py, 2.24), 0.01, 5)
		lathe_at(bm, [(0.0, 2.14), (0.048, 2.16), (0.042, 2.28), (0.018, 2.34)], 6, (px, py))
	done()
	bm, done = part("FireCoals", root, mats["coals"], 0.0)
	box(bm, (-2.45, -HY + 0.78, 0.34), (0.9, 0.34, 0.12))
	done()
	bm, done = part("Ember", root, mats["ember"], 0.0)
	sphere(bm, 0.16, (-2.45, -HY + 0.78, 0.52), 8, 6)
	for i in range(5):
		a = i * math.tau / 5.0
		sphere(bm, 0.03, (0.35 + math.cos(a) * 0.42, 0.05 + math.sin(a) * 0.42, 2.32), 6, 4)
	done()
	bm, done = part("FireTools", root, mats["iron"], 0.003)
	bar(bm, (-1.55, -HY + 0.95, 0.2), (-1.55, -HY + 0.95, 1.35), 0.012, 6)
	bar(bm, (-1.42, -HY + 0.95, 0.2), (-1.42, -HY + 0.95, 1.2), 0.012, 6)
	box(bm, (-1.55, -HY + 0.95, 1.38), (0.08, 0.04, 0.04))
	box(bm, (-1.42, -HY + 0.95, 1.22), (0.12, 0.03, 0.03))
	done()
	bm, done = part("Pegs", root, mats["beam"], 0.004)
	for y in (-1.2, -0.4, 0.4, 1.2):
		box(bm, (HX - 0.28, y, 1.55), (0.12, 0.04, 0.04))
	done()
	bm, done = part("Cloaks", root, mats["cloth"], 0.005)
	box(bm, (HX - 0.42, -1.2, 1.15), (0.08, 0.28, 0.7))
	box(bm, (HX - 0.42, 0.4, 1.2), (0.08, 0.24, 0.62))
	done()
	bm, done = part("Casks", root, mats["wood"], 0.008)
	for loc in ((-3.4, -0.8, 0.38), (-3.4, -0.2, 0.38)):
		lathe_at(
			bm,
			[(0.14, loc[2] - 0.26), (0.22, loc[2] - 0.16), (0.24, loc[2]), (0.22, loc[2] + 0.16), (0.14, loc[2] + 0.26)],
			10,
			(loc[0], loc[1]),
		)
	done()
	bm, done = part("Plates", root, mats["pewter"], 0.003)
	for x, y in ((1.22, 1.5), (1.62, -1.7), (2.5, 0.28)):
		lathe_at(bm, [(0.0, 0.82), (0.08, 0.83), (0.09, 0.86)], 8, (x, y))
	done()


def dwarf(name, pose, mats, apron=False, helm=False):
	root = empty(name)
	sit = pose == "sit"
	pelvis = 0.5 if sit else 0.62
	head_z = pelvis + 0.58
	# skin: head, nose, hands, ears
	bm, done = part("Body", root, mats["skin"], 0.005, smart=True)
	sphere(bm, 0.125, (0.0, 0.03, head_z), 12, 10, 1.08, 0.98, 1.12)
	lathe_at(bm, [(0.0, head_z - 0.02), (0.035, head_z - 0.01), (0.04, head_z + 0.02), (0.018, head_z + 0.05)], 8, (0.0, 0.14))
	sphere(bm, 0.028, (-0.12, 0.02, head_z + 0.02), 6, 5, 0.6, 1.1, 1.2)
	sphere(bm, 0.028, (0.12, 0.02, head_z + 0.02), 6, 5, 0.6, 1.1, 1.2)
	# hands
	sphere(bm, 0.055, (-0.32, 0.16, pelvis + 0.08), 8, 6, 1.1, 1.3, 0.7)
	sphere(bm, 0.055, (0.32, 0.16, pelvis + 0.08), 8, 6, 1.1, 1.3, 0.7)
	done()
	bm, done = part("Eyes", root, mats["eye"], 0.0)
	sphere(bm, 0.022, (-0.04, 0.11, head_z + 0.02), 6, 5)
	sphere(bm, 0.022, (0.04, 0.11, head_z + 0.02), 6, 5)
	done()
	bm, done = part("Brow", root, mats["beard"], 0.003)
	box(bm, (0.0, 0.11, head_z + 0.07), (0.16, 0.04, 0.035))
	done()
	bm, done = part("Beard", root, mats["beard"], 0.004, smart=True)
	lathe_at(
		bm,
		[(0.04, head_z - 0.04), (0.13, head_z - 0.08), (0.15, head_z - 0.2), (0.1, head_z - 0.34), (0.04, head_z - 0.42)],
		10,
		(0.0, 0.08),
	)
	box(bm, (0.0, 0.13, head_z - 0.02), (0.16, 0.05, 0.04))
	box(bm, (-0.05, 0.1, head_z - 0.28), (0.06, 0.08, 0.22))
	box(bm, (0.05, 0.1, head_z - 0.3), (0.06, 0.08, 0.24))
	done()
	bm, done = part("Hair", root, mats["beard"], 0.004)
	sphere(bm, 0.14, (0.0, -0.02, head_z + 0.08), 10, 8, 1.15, 1.0, 0.55)
	done()
	bm, done = part("Clothes", root, mats["cloth"], 0.007, smart=True)
	lathe_at(
		bm,
		[(0.16, pelvis - 0.08), (0.22, pelvis), (0.24, pelvis + 0.22), (0.2, pelvis + 0.42), (0.16, pelvis + 0.5)],
		12,
		(0.0, 0.0),
	)
	box(bm, (0.0, 0.14, pelvis + 0.48), (0.28, 0.08, 0.08))
	# arms
	for sx in (-1.0, 1.0):
		lathe_at(
			bm,
			[(0.055, pelvis + 0.42), (0.07, pelvis + 0.28), (0.06, pelvis + 0.12)],
			8,
			(sx * 0.26, 0.02),
		)
	if not sit:
		lathe_at(bm, [(0.08, 0.12), (0.09, 0.34), (0.085, pelvis - 0.04)], 8, (-0.11, 0.0))
		lathe_at(bm, [(0.08, 0.12), (0.09, 0.34), (0.085, pelvis - 0.04)], 8, (0.11, 0.0))
	done()
	if sit:
		bm, done = part("Legs", root, mats["cloth"], 0.006)
		box(bm, (-0.11, 0.12, 0.5), (0.14, 0.32, 0.12))
		box(bm, (0.11, 0.12, 0.5), (0.14, 0.32, 0.12))
		box(bm, (-0.11, 0.26, 0.28), (0.12, 0.12, 0.36))
		box(bm, (0.11, 0.26, 0.28), (0.12, 0.12, 0.36))
		done()
	bm, done = part("Belt", root, mats["leather"], 0.004)
	lathe_at(bm, [(0.22, pelvis + 0.02), (0.235, pelvis + 0.06), (0.22, pelvis + 0.1)], 10, (0.0, 0.0), cap=False)
	box(bm, (0.0, 0.22, pelvis + 0.06), (0.08, 0.04, 0.07))
	box(bm, (-0.14, 0.18, pelvis + 0.02), (0.08, 0.05, 0.1))
	box(bm, (0.14, 0.16, pelvis + 0.0), (0.07, 0.04, 0.08))
	done()
	bm, done = part("Boots", root, mats["leather"], 0.006)
	if sit:
		lathe_at(bm, [(0.05, 0.02), (0.09, 0.04), (0.08, 0.14)], 8, (-0.11, 0.34))
		lathe_at(bm, [(0.05, 0.02), (0.09, 0.04), (0.08, 0.14)], 8, (0.11, 0.34))
		box(bm, (-0.11, 0.42, 0.05), (0.16, 0.22, 0.08))
		box(bm, (0.11, 0.42, 0.05), (0.16, 0.22, 0.08))
	else:
		lathe_at(bm, [(0.05, 0.0), (0.09, 0.03), (0.08, 0.16)], 8, (-0.11, 0.04))
		lathe_at(bm, [(0.05, 0.0), (0.09, 0.03), (0.08, 0.16)], 8, (0.11, 0.04))
		box(bm, (-0.11, 0.12, 0.05), (0.16, 0.22, 0.08))
		box(bm, (0.11, 0.12, 0.05), (0.16, 0.22, 0.08))
	done()
	if apron:
		bm, done = part("Apron", root, mats["leather"], 0.005)
		box(bm, (0.0, 0.16, pelvis + 0.08), (0.34, 0.05, 0.72))
		box(bm, (0.0, 0.14, pelvis + 0.4), (0.4, 0.04, 0.07))
		done()
	if helm:
		bm, done = part("Helm", root, mats["iron"], 0.004)
		lathe_at(
			bm,
			[(0.0, head_z + 0.02), (0.15, head_z + 0.04), (0.16, head_z + 0.16), (0.05, head_z + 0.24)],
			12,
			(0.0, 0.0),
		)
		box(bm, (0.0, 0.15, head_z + 0.0), (0.2, 0.04, 0.07))
		done()
	bm, done = part("Mug", root, mats["pewter"], 0.003)
	hand = (0.32, 0.2, pelvis + 0.1)
	lathe_at(bm, [(0.032, hand[2]), (0.046, hand[2] + 0.02), (0.044, hand[2] + 0.1), (0.05, hand[2] + 0.12)], 8, (hand[0], hand[1]))
	done()
	return root


def build_tavern(mats):
	root = empty("SM_Tavern")
	foundation(root, mats["stone"])
	walls(root, mats["plaster"], mats["wood"], mats["beam"])
	door_and_windows(root, mats["wood"], mats["iron"], mats["glass"])
	roof(root, mats["slate"], mats["beam"], mats["stone"])
	sign_and_porch(root, mats["wood"], mats["beam"], mats["iron"], mats["slate"])
	floor_and_bar(root, mats["wood"], mats["beam"], mats["iron"], mats["stone"])
	dressing(root, mats)
	return root


def main():
	clear_scene()
	mats = {
		"stone": mat("TavernStone", "tavern_stone", (1.0, 0.95, 0.9), 0.9),
		"wood": mat("TavernWood", "tavern_wood", (1.0, 1.0, 1.0), 0.74),
		"beam": mat("TavernBeam", "tavern_beam", (1.0, 1.0, 1.0), 0.88),
		"plaster": mat("TavernPlaster", "tavern_plaster", (1.0, 1.0, 1.0), 0.92),
		"slate": mat("TavernSlate", "tavern_slate", (1.0, 1.0, 1.0), 0.62),
		"iron": mat("TavernIron", "tavern_iron", (1.0, 1.0, 1.0), 0.38, metal=0.75),
		"glass": mat("TavernGlass", tint=(1.0, 0.52, 0.2), rough=0.12, emit=(1.0, 0.42, 0.1, 1.6), alpha=0.62),
		"glass_g": mat("BottleGreen", tint=(0.1, 0.26, 0.12), rough=0.18, emit=(0.04, 0.16, 0.06, 0.3), alpha=0.68),
		"glass_r": mat("BottleRed", tint=(0.3, 0.06, 0.07), rough=0.2, emit=(0.22, 0.04, 0.04, 0.35), alpha=0.68),
		"coals": mat("Coals", tint=(0.08, 0.04, 0.02), rough=0.9, emit=(1.0, 0.32, 0.06, 1.5)),
		"ember": mat("Ember", tint=(1.0, 0.42, 0.1), rough=0.35, emit=(1.0, 0.38, 0.06, 3.4)),
		"pewter": mat("Pewter", "tavern_iron", (1.15, 1.05, 0.9), 0.32, metal=0.7),
		"skin": mat("DwarfSkin", "dwarf_skin", (1.0, 1.0, 1.0), 0.58),
		"cloth": mat("DwarfCloth", "dwarf_cloth", (1.0, 1.0, 1.0), 0.86),
		"beard": mat("DwarfBeard", "dwarf_beard", (1.0, 1.0, 1.0), 0.94),
		"leather": mat("DwarfLeather", "dwarf_leather", (1.0, 1.0, 1.0), 0.78),
		"eye": mat("DwarfEye", tint=(0.05, 0.04, 0.04), rough=0.25),
	}
	cloth_b = mat("DwarfClothB", "dwarf_cloth", (0.45, 0.5, 0.72), 0.86)
	cloth_c = mat("DwarfClothC", "dwarf_cloth", (0.85, 0.55, 0.28), 0.86)
	beard_g = mat("DwarfBeardGrey", "dwarf_beard", (0.7, 0.68, 0.62), 0.92)

	tavern = build_tavern(mats)
	bkeep = dwarf("SM_DwarfBartender", "stand", mats, apron=True)
	pa = dwarf("SM_DwarfPatronA", "sit", {**mats, "cloth": cloth_b, "beard": beard_g}, helm=True)
	pb = dwarf("SM_DwarfPatronB", "sit", {**mats, "cloth": cloth_c})
	pc = dwarf("SM_DwarfPatronC", "stand", {**mats, "cloth": cloth_b, "beard": beard_g}, helm=True)
	bkeep.location = (10.0, 0.0, 0.0)
	pa.location = (12.0, 0.0, 0.0)
	pb.location = (14.0, 0.0, 0.0)
	pc.location = (16.0, 0.0, 0.0)

	os.makedirs(os.path.dirname(BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	print("SAVED", BLEND)
	for root, name in (
		(tavern, "vale_tavern.glb"),
		(bkeep, "dwarf_bartender.glb"),
		(pa, "dwarf_patron_a.glb"),
		(pb, "dwarf_patron_b.glb"),
		(pc, "dwarf_patron_c.glb"),
	):
		kept = root.location.copy()
		root.location = (0.0, 0.0, 0.0)
		export_glb(root, name)
		root.location = kept


if __name__ == "__main__":
	main()

"""Render review for the tiling texture sets: each set on a wall and a floor at the game's own scale, under a cool raking
moonlight and a weak fill, seen from 6 m and from 22 m (the distance where a set either reads as stone or as a grid).

  tools/blender/run.sh texture_review.py -- --out DIR [--tex DIR] oss_ashlar:3.125 oss_ruin:2.5 oss_brick:2.0 oss_floor:4.5

<set>:<metres per tile> (1 / the material's uv1_scale). Writes DIR/<set>_near.png and DIR/<set>_far.png.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "art", "textures")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[args.index("--out") + 1] if "--out" in args else "/tmp"
TEX = args[args.index("--tex") + 1] if "--tex" in args else TEX                # (a folder of older maps: the before)
SETS = [a for a in args if ":" in a]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.resolution_x = 960
    sc.render.resolution_y = 600
    sc.view_settings.view_transform = "AgX" if "AgX" in [v.identifier for v in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.025, 0.05, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = w


def material(name, tile):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0 / tile, 1.0 / tile, 1.0 / tile)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])

    def img(kind, non_color):
        p = os.path.join(TEX, "%s_%s.png" % (name, kind))
        if not os.path.exists(p):
            return None
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(p)
        n.image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
        n.projection = "BOX"
        n.projection_blend = 0.2
        nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
        return n

    a = img("albedo", False)
    ao = img("ao", True)
    if a is not None:
        if ao is not None:
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            nt.links.new(a.outputs["Color"], mix.inputs[6])
            nt.links.new(ao.outputs["Color"], mix.inputs[7])
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        else:
            nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    r = img("rough", True)
    if r is not None:
        nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    n = img("normal", True)
    if n is not None:
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def scene_for(name, tile):
    reset()
    m = material(name, tile)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.object
    floor.data.materials.append(m)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 4, 4))
    wall = bpy.context.object
    wall.scale = (40, 1, 8)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)     # object coordinates in metres
    wall.data.materials.append(m)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(52), 0, math.radians(-38)))
    sun = bpy.context.object
    sun.data.energy = 2.2
    sun.data.color = (0.66, 0.78, 1.0)
    sun.data.angle = math.radians(0.5)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(66), 0, math.radians(-30)))
    fill = bpy.context.object
    fill.data.energy = 0.5
    fill.data.color = (0.58, 0.64, 0.86)
    fill.data.use_shadow = False
    bpy.ops.object.light_add(type="POINT", location=(-3.0, 1.5, 1.6))
    lamp = bpy.context.object
    lamp.data.energy = 140
    lamp.data.color = (1.0, 0.62, 0.32)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.data.lens = 24
    return cam


def shoot(cam, at, look, path):
    cam.location = Vector(at)
    d = Vector(look) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("wrote", path)


os.makedirs(OUT, exist_ok=True)
for s in SETS:
    nm, t = s.split(":")
    cam = scene_for(nm, float(t))
    shoot(cam, (0, -2.0, 1.7), (0, 4, 2.0), os.path.join(OUT, nm + "_near.png"))
    shoot(cam, (-6, -18.0, 3.0), (0, 4, 2.0), os.path.join(OUT, nm + "_far.png"))

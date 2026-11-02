"""Export the three prop meshes to glTF, feet at the origin, without preview lights."""

import os

import bpy
import bmesh


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLEND = os.path.join(ROOT, "art", "blender", "vale_props.blend")
OUT = os.path.join(ROOT, "art", "models")


def baked_meshes(empty_name: str, names: set):
	empty = bpy.data.objects[empty_name]
	origin = empty.matrix_world.translation.copy()
	made = []
	for child in empty.children_recursive:
		if child.type != "MESH" or child.name not in names:
			continue
		bm = bmesh.new()
		bm.from_mesh(child.data)
		bm.transform(child.matrix_world)
		bmesh.ops.translate(bm, verts=list(bm.verts), vec=-origin)
		me = bpy.data.meshes.new(child.name + "_exp")
		bm.to_mesh(me)
		bm.free()
		if child.data.materials:
			me.materials.append(child.data.materials[0])
		obj = bpy.data.objects.new(child.name, me)
		bpy.context.scene.collection.objects.link(obj)
		made.append(obj)
	return made


def export(objects, filename: str) -> None:
	bpy.ops.object.select_all(action="DESELECT")
	for obj in objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = objects[0]
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
	print("EXPORTED", path)


def main() -> None:
	bpy.ops.wm.open_mainfile(filepath=BLEND)
	export(baked_meshes("Lantern", {"Post", "Ironwork", "Glass", "Ember"}), "lantern.glb")
	export(baked_meshes("Brazier", {"Plinth", "Bowl"}), "brazier.glb")
	export(baked_meshes("Menhir", {"Stone"}), "menhir.glb")


if __name__ == "__main__":
	main()

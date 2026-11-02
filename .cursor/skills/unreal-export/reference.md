# Blender ↔ Unreal reference

## Units

| Blender | Unreal |
| --- | --- |
| 1 metre | 100 uu (cm) |
| Character ~1.8 m | ~180 uu tall |
| Lantern 0.3 m | ~30 uu |

If the mesh is 100× wrong, it is **units**, not “Nanite” or LODs. If it lies flat, it is **axis / unapplied rotation**, not lighting.

## Axis

- Blender viewport: Z-up.
- glTF: Y-up. Exporter `+Y Up` converts positions in the file.
- Unreal: Z-up. Importers convert from glTF.
- Umbral C++ remaps Godot Y-up `(X,Y,Z)` → UE `(X, Z, Y)` via `Umbral::FromGodot`. Do not invent a third remap on top of a bad export.

## Unapplied scale (worst silent bug)

Object Mode scale 2.0 with Dimensions 2 m means size lives in the transform. Export / armature / modifiers disagree. Always `Ctrl+A` → All Transforms so Scale is 1,1,1 and size lives in the mesh.

## PBR map cheat sheet

| Map | Color space | Notes |
| --- | --- | --- |
| Base Color / Albedo | sRGB | Keep night cloth from crushing to ~0.1 mean |
| Roughness | Non-Color | |
| Metallic | Non-Color | |
| Normal | Non-Color | Tangent; check green channel in UE |
| Emissive | sRGB / HDR | Small values; UE bloom is not Godot glow |

## FBX vs glTF for UE 5.8

- Static environment / props: glTF/GLB is first-class; material instances from project glTF settings (5.7+).
- Animation-heavy characters: FBX still the conservative choice.
- Never mix an ad-hoc import Uniform Scale of 0.01 **and** a Blender centimetre scene — pick one contract and measure.

## External docs

- Blender Manual — glTF 2.0 addon (`export_yup`, Apply Modifiers, Principled only)
- Epic — Physical Lighting Units (candela / lumen / unitless)
- Epic — Bloom / Auto Exposure (threshold vs intensity; Manual for art direction)

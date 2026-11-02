---
name: unreal-export
description: >-
  Correct Blender → Unreal Engine 5.8 mesh/material export (glTF/GLB or FBX).
  Use when exporting for UmbralReachesUE, importing into Unreal, fixing scale/axis,
  PBR materials, or when the user mentions Blender Unreal export, GLB for UE, or FBX.
---

# Blender → Unreal (correct)

**Port contract (memorise the check, not magic checkboxes):** Blender metres → Unreal centimetres. **1 Blender metre must measure 100 Unreal units.** Axis wrong → mesh lies on its face. Units wrong → 100× too big/small. Fix at export; never “scale it in the level and ship.”

Sources: Blender glTF manual (Y Up + Apply Modifiers), Epic physical light/units docs, UE 5.7+ glTF material-instance import, FMX/UE 5.8 teaching notes.

## When to use which format

| Asset | Prefer | Why |
| --- | --- | --- |
| Static props, nights, foliage cards | **GLB** | Matches Umbral Godot dump + runtime `Content/Raw` loader |
| Skeletal / complex anim | **FBX** | Safer skin/clip path in UE today |
| Editable textures sidecar | glTF Separate | Rare here — prefer packed GLB |

Umbral runtime loads GLB via `UmbralMesh::Attach` from `Content/Raw/Models` (and `Content/Imported` dumps). Keep that path unless the user asks for cooked `UStaticMesh`.

## Blender pre-flight (every export)

1. Scene units: **Metric**, Unit Scale **1.0** (1 BU = 1 m).
2. Read **Item → Dimensions**. Door ~1×2.1 m; lantern ~0.3 m; wall module on a real grid. Wrong size → scale in Blender, then apply.
3. `Ctrl+A` → **All Transforms**. Scale must read 1,1,1; rotation 0 (or intentional).
4. Origin: feet/bottom for props; grip for handhelds. Same convention every piece.
5. Quads for authored meshes; merge by distance ~0.0001 m; recalculate outside normals.
6. Materials: **Principled BSDF only**. Bake procedurals to images. Non-Color for roughness/metallic/normal.
7. Tangents on if a normal map exists.
8. Name `SM_<Asset>` (or Umbral short names already in Raw: `brazier.glb`, `robe_torso.glb`, …).

### Do not

- Leave unapplied object scale (breaks modifiers, armatures, and engine import).
- Export Blender-only node graphs (Noise → Ramp → Mix Shader) expecting UE to rebuild them.
- Draco-compress GLB for this project (runtime loader / interchange risk).
- Put `.blend` under Godot `art/models/` (`.gdignore` lives on `art/blender/` for a reason).
- Rewrite wanderer/shade meshes — `umbral-donts` wins.

## glTF / GLB settings (Blender 4.x)

```
Format: glTF Binary (.glb)
Include: Selected Objects (when shipping one asset)
Transform: +Y Up          # export_yup=True — glTF is Y-up; Blender is Z-up
Data → Mesh → Apply Modifiers: ON   # export_apply=True
Normals: ON
UVs: ON
Tangents: ON (if normal maps)
Materials: Export
Images: Automatic
Compression: OFF
```

Python / batch (same flags Umbral already uses for Godot):

```python
bpy.ops.export_scene.gltf(
    filepath=out_glb,
    export_format='GLB',
    export_apply=True,
    export_yup=True,
    use_selection=True,
)
```

`+Y Up` rewrites positions into the glTF buffer. Leaving it off ships Z-up data that engines display on their back.

## FBX settings (if skeletal / anim)

```
Scale 1.00
Apply Scalings: FBX All
Forward: -Z Forward
Up: Y Up
Apply Unit: ON
Selected Objects: as needed
```

Still verify **100 units ≈ 1 m** in UE. Do not invent a second scale factor “because a tutorial said 0.01.”

## Materials that survive

glTF / UE expect:

- Base Color (sRGB)
- Metallic / Roughness (linear; ORM packing OK: R unused/AO, G roughness, B metallic)
- Normal (tangent, +Y; UE DirectX often needs green flip — verify in viewport)
- Emissive only where intentional (HDR emissive will bloom hard under Metal LDR)

UE 5.7+ prefers **material instances** from glTF archetypes over one-off generated materials. For Umbral’s runtime PMC path, textures still land through `UmbralSurf::LoadTexture` + `M_AlbedoLit` / specialty mats — keep albedo readable (mean ~0.3–0.5 linear for cloth under night lights; crushed ~0.09 baseColor looks black once lit).

## Verify loop (iterate every time)

```
Export GLB → drop / load in UE → measure → fix Blender → re-export
```

1. Import or runtime-load next to a known 100-unit reference (or mannequin).
2. Details / bounds: expected centimetres = Blender metres × 100.
3. Standing upright, correct forward (Umbral: Godot −Z forward ↔ `Umbral::YawGodot`).
4. Materials not checkerboard; normals not inverted; no 100× pivot offset.
5. If wrong: fix **source**, re-export. Do not leave a compensatory scale on the actor.

## Umbral dual-target note

Same GLB usually feeds Godot `art/models/` and UE `Content/Raw/Models/`. Export once with the flags above; copy into both trees when the asset is shared. Night mass still comes from Godot dump (`tools/export_unreal_meshes.gd`) into `Content/Imported/` — do not hand-rebuild sanctuary as unique hero meshes.

## Route after export

- Art bans / glow budget → `umbral-donts`
- Modeling craft → `umbral-blender` then specialist skills
- Playing / packing the UE app → `umbral-unreal`
- Godot-only import → `godot-export` + `umbral-pipeline`

## Deeper reference

- Axis, scale traps, ORM, normal green: [reference.md](reference.md)

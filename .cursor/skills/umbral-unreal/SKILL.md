---
name: umbral-unreal
description: >-
  Run, pack, light, and iterate the Umbral Reaches Unreal 5.8.4 Mac Metal port.
  Use when working in UmbralReachesUE, packing the Mac .app, fixing UE lighting/materials,
  DumpViews screenshots, Metal shader failures, or matching Godot nights without Lumen.
---

# Umbral Unreal

Sibling port at `/Users/luke/UmbralReachesUE`. Godot stays playable at Downloads `Umbral Reaches.app`. Engine: **UE 5.8** at `/Users/Shared/Epic Games/UE_5.8`. Owner plays the Mac app under `/Users/luke/Downloads/UmbralReachesUE/`.

**Read `umbral-donts` first** (gothic lights only, glow budget, no wanderer/shade rewrite). Art export: `unreal-export`. Godot truths: `umbral-nights`, `umbral-player`.

## Iterate loop (every visual/gameplay fix)

Do not stop at “compiled.” Close the loop. **Prefer the fast path** — full cook is ~90s and only needed when cooked assets change.

| Change type | Command | Typical time |
| --- | --- | --- |
| C++ / `Content/Raw` only | `Scripts/FastTest.sh bin` | ~35s (UBT + binary swap into Downloads app) |
| Same, run from project Content | `Scripts/FastTest.sh editor` | ~30–60s (editor module + `-game`) |
| Materials / config / first ship | `Scripts/FastTest.sh pack` or full UAT cook | ~90s+ |

```
edit → Scripts/FastTest.sh bin → wait SHOTS ready → read /tmp/umbral-ue-shots/*.png → fix again
```

1. Prefer one hypothesis per cycle (light units, material bind, camera, cull).
2. Judge from **PNG DumpViews**, not the editor viewport alone.
3. Quote Finder `touch` time after `bin`/`pack` so the owner knows which build is live.
4. Do not claim 1:1 with Godot until shots match sanctuary/stair/vale references.
5. Do not invent audio or `crystal.glb`. Missing audio stays silent; clusters stay without that mesh.

## Pack (Mac) — binding recipe

Archive directories often miss cooked content. **Ship from StagedBuilds:**

```sh
ENGINE="/Users/Shared/Epic Games/UE_5.8"
PROJECT="/Users/luke/UmbralReachesUE/UmbralReaches.uproject"
"$ENGINE/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun \
  -project="$PROJECT" -platform=Mac -clientconfig=Development \
  -build -cook -stage -pak

STAGED="$PROJECT/../Saved/StagedBuilds/Mac/UmbralReaches.app"
# actual path:
STAGED="/Users/luke/UmbralReachesUE/Saved/StagedBuilds/Mac/UmbralReaches.app"
DEST="/Users/luke/Downloads/UmbralReachesUE/Mac/UmbralReaches.app"
pkill -f '/UmbralReaches.app/Contents/MacOS/UmbralReaches' 2>/dev/null || true
ditto "$STAGED" "$DEST"
# Raw textures edited on disk must be present under the app tree too:
# DEST/Contents/UE/UmbralReaches/Content/Raw/...
codesign --force --deep --sign - "$DEST"
touch "$DEST"
date "+Finder %H:%M:%S"
nohup "$DEST/Contents/MacOS/UmbralReaches" -windowed -ResX=1600 -ResY=900 \
  > /tmp/umbral-ue-run.log 2>&1 &
```

Optional helper: `Scripts/PackMac.sh` (still **ditto StagedBuilds** if archive looks empty). After launch, `UmbralBoot::DumpViews` writes `/tmp/umbral-ue-shots/{spawn,stair,lava}.png` (~2.2 s). Confirm with `DIAG SHOT` in `~/Library/Logs/UmbralReaches/UmbralReaches.log`.

### Do not

- Headless-rebake Godot `main.tscn` / `vale.tscn` for UE work.
- pkill the owner’s **Godot** editor.
- Trust `-archive` alone without checking the `.app` has `Content/Paks`.
- Run as “lux” intensities while `r.DefaultFeature.LightUnits=0`.

## Lighting contract (Unitless, no Lumen)

Project forces **Unitless** lights (`DefaultEngine.ini` / settings). Lumen is off / incompatible with the look path we use on Mac Metal.

| Rule | Detail |
| --- | --- |
| Scale | `Umbral::Light(GodotEnergy) = GodotEnergy * 130` — **not** ×2200 |
| Moon | Soft directional; hard moon shadows crush the wanderer — bias high or cast off while matching Godot fill |
| Bloom | Godot glow **0.62 ≠** UE `BloomIntensity`. Use ~**0.06–0.22** + HDR threshold ~1.15 |
| Exposure | **Manual** AE for DumpViews; histogram AE blacks sanctuary then blows sky |
| Sky mats | `M_VortexSky` / `M_ValeAurora` HDR can white-out Metal LDR — vertex-color unlit fallback until retuned |
| Grade | `M_Grade` SceneTexture / WeightedBlendable → invalid Metal ShaderMap → black frame. Drive grade with ColorGain/Sat/Contrast/Gamma/Vignette |
| Albedo | `M_AlbedoLit` = Godot PNG × VC tint. Sync `art/textures` → `Content/Raw/Textures` (FastTest `bin` rsyncs into the app). Do **not** brighten robe PNG or replace it with a solid tint |
| Triplanar | Godot stone/bark/leather/staff use `uv1_world_triplanar`. Sanctuary/stair glTF UVs are 0–1 — `UmbralSurf::ApplyTriplanarUVs` with Godot `uv1_scale` (stone 0.25, rock 0.12, ground 0.08). Robe keeps mesh UVs × (2, 2.4) |
| Runtime PNG | Load via ImageWrapper BGRA → uncompressed `TC_VectorDisplacementmap` + box mips (Epic CreateTransient has mip0 only). Normals: `LoadTexture(path, false)` |
| Robe cloth | `M_RobeCloth` WPO shredded on Metal. Prefer `M_AlbedoLit` + `robe_albedo` / magic flecks in VC + piece rotation |
| Cull | `r.ViewDistanceScale` floor ≥ **0.45** on stair (0.12 ate sanctuary) |

Fill lights: cast **shadows off** for hero spots / player rim / lantern unless intentionally blocking. Gothic = window spots, not bay meshes.

## Movement / camera (copy Epic — do not invent)

Source of truth: UE 5.8 `Templates/TP_ThirdPerson/.../TP_ThirdPersonCharacter.cpp`, Epic “Setting Up Character Movement”, Spring Arm docs. Prefer those over improvised yaw/offset math.

**Pattern A (explore — matches Godot wander):**
| Setting | Value |
| --- | --- |
| `bUseControllerRotationYaw` | false |
| `bOrientRotationToMovement` | true |
| `bUseControllerDesiredRotation` | false |
| SpringArm `bUsePawnControlRotation` | true |
| Camera `bUsePawnControlRotation` | false |
| Camera relative transform | **zero** (OTS lives on SocketOffset) |

**Pattern B (aim/cast):** yaw follow controller, orient-to-movement off. Toggle only while casting — never both on.

**Mesh facing:** Epic mannequin RelRot yaw **-90** (asset faces +Y). Our VisualRoot is **+90** — glTF forward after (X,Z,Y) is local **−Y**, so the sign flips vs the template.

**OTS (Godot numbers → SocketOffset):** arm length `370`, SocketOffset `(0, 107, 30)`, boom Z `155`. Do not also offset the Camera component. Land-dip may nudge SocketOffset.Z only.

**Spawn:** Pattern A leaves the body at last move yaw. Sync `SetActorRotation(yaw=ControlRotation.Yaw)` in BeginPlay or DumpViews shows a side profile.

**Staff:** shaft is glTF +Y → UE +Z. `SetWorldRotation(ActorQuat * LocalTilt)` — **not** VisualRoot quat (−90 tips the shaft). Match loadout by name prefix (`weapon_main*`); `MakeUniqueObjectName` suffixes break exact `==`.

## Coordinates

```
Godot (X, Y-up, Z) → Umbral::FromGodot → UE (X, Z, Y)*100
Yaw: Umbral::YawGodot(radians)
Feet: Umbral::StandOn(ground, capsuleHalfHeight)
```

Dump spawn cam: prefer live player Camera component.

## Content layout

| Path | Role |
| --- | --- |
| `Content/Raw/Models/*.glb` | Runtime props / robe / staff |
| `Content/Raw/Textures/*` | Runtime PNGs (loaded from disk — copy into staged app after edit) |
| `Content/Imported/*.glb` | Night dumps from Godot |
| `Content/Materials/M_*` | Cooked parents; Metal-broken ones need code fallbacks |
| `Source/UmbralReaches/*` | C++ — five subsystem services, not a Godot autoload clone name-for-name |

Required models audit: `UmbralAssets` — do not re-add `crystal.glb` as required.

## Feature parity posture

Port Godot behaviour (gloom, bolts, braziers, mirrors, shades, HUD Cinzel, push_pos → SetPush, flame/smoke cards, fog volumes, SkyFlare, gamepad) into UE. Silent missing audio is OK. Keep iterating visuals until sanctuary reads; do not declare done on compile green.

## Shot triage

| Symptom | Likely cause |
| --- | --- |
| Pure black frame | Grade WeightedBlendable / bad PP mat on Metal |
| White-out | Light ×~2200 or HDR sky/emissive under Manual AE |
| Checkerboard mesh | Material parent missing or Albedo param unset |
| White static / shredded cloth | WPO robe mat / bad world-unit wave |
| Silhouette only | Dark albedo × Unitless night; need fill + brighter albedo |
| Empty mid-distance | ViewDistanceScale / cull margins |
| Archive app “runs” but old look | Didn’t ditto fresh StagedBuilds + Raw |

## Related

- [iterate-checklist.md](iterate-checklist.md) — copy/paste cycle
- `unreal-export` — Blender side
- `umbral-donts` / `umbral-nights` / `umbral-player`

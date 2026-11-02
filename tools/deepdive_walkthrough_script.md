# Umbral Reaches — Deepdive Walkthrough Script

Watch with: `~/Downloads/umbral_deepdive_stair.mp4`.
Pause and note timestamps. Goal: one issue list, no fixes yet.

Crimson Vale has been removed — Stair of Ascension only until a new night is built.

---

## Stair of Ascension (demo autopilot)

Demo follows `Demo/WP*` markers: sanctuary → gate → kindle foot → stair → landing kindle → ascend → summit → threshold kindle → edge → gaze.

| Beat | What to watch | Likely issue class |
| --- | --- | --- |
| A0 Title / spawn | Grade flash, title card, mouse capture, gloom bar | UI / grade |
| A1 Sanctuary | Floor contacts, lanterns (four only), gothic = lights not mesh | Lighting / gothic don’ts |
| A2 Gate / path | Boot vs robe hem while walking, OTS framing, staff trail | Cloth / camera / VFX |
| A3 Kindle foot | Interact prompt, flame light-up, LightGrid gloom drain | Interaction / gloom |
| A4 Stair climb | Capsule vs steps, foot plant, robe aft lag vs flat back | Collision / cloth |
| A5 Landing kindle | Second brazier, enemy wretch near path, shadow acne | Combat / shadows |
| A6 Ascend sprint | Sprint FOV kick, cloth at run, glow bloom blowouts | Camera / glow budget |
| A7 Summit platform | No portal (Vale gone); sky vortex must animate | Sky / summit |
| A8 Threshold kindle | Last flame, gloom state, hollow risk if dark | Gloom |
| A9 Edge / gaze | Far cull pops (lava/surface), particle thinning | Culling / particles |

**Checklist**

- [ ] Boots poke past hem on plant (lead / trail)
- [ ] Coat trails aft toward camera (lag) or stays flat sheet
- [ ] Chest / torso balloon from cloth shader
- [ ] Glow over budget (bloom wash, HDR blow)
- [ ] Lava / floor disappear up close or at range
- [ ] Sky vortex frozen (TIME not advancing)
- [ ] Gothic bead-arches or level meshes sneaking back
- [ ] Interact fails at kindle markers
- [ ] Enemy clips / floats / wrong layer
- [ ] HUD / gloom / crosshair wrong

---

## After the watch

1. Fill timestamps into an issue list (night, time, symptom).
2. Sort by player-facing severity.
3. Fix in place; do **not** rebake `main.tscn` for script/shader/player work.
4. Pack Mac app after visual/gameplay fixes.

Re-run: `tools/deepdive_walkthrough.sh`

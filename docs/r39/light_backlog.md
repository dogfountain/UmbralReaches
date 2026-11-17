# Light, night look, VFX and animation: backlog (r39-anim)

Resume here. Tick = committed on branch r39-anim. NOTHING was run in an engine (the seat has no Godot): every item needs the lead's
import, the suite, a film at 60 and 144 Hz, and frame times against the regions_a numbers. The docs say where to see each item
and what it costs: `light_animation_vfx.md` (light, sky, weather, VFX, the living night), `animation_smoothing.md` (smoothing), and
`folk_and_animals.md` (the ambient people, the pets, the horses, the wanderer's life).

The bar (brief): smoothness first (damped, crossfaded, interpolated), volume and variety, end to end (indoors, fast travel, bosses,
reload, Living Night off), NO performance cost (bake, pool, sleep by distance, no per-frame allocation, no new shadowed lights,
no mid-play builds), documented.

- [x] 1. Villager acts: ambient folk (sweeper, fiddler, dancer, porter with a sack, water-bearer, three children at tag and hide and seek, a watchman's round with a lantern, a mourner, a net-mender, two talking on logs), waves at the wanderer by the village's regard, nods, eclipse and alarm reactions, ten idle gestures for every standing villager (four old, six new), walk de-sync
- [x] 2. Animals: three dogs (follow, greet, sit, sniff, bark at foes, hide in the eclipse), two cats on roofs (watch, groom, stretch, leap), horses stroll their paddocks and face a buyer; (birds scattering, crows at graves, owls, bats: already the wildlife system's)
- [x] 3. The wanderer's life: ten idle acts by the night round him, limp when hurt, breath after a sprint, lantern raised and brighter in the dark, looking at landmarks
- [x] 4. A full sky: moon phase by night count, eclipse sky, constellations, aurora nights, cloud deck lit from below (shooting stars: already phenomena.gd)
- [x] 5. Weather: wet ground, puddle glints, drips, fires gutter and hiss, halos, lightning on every landmark, dawn grey and mist, per-night opening front (fronts, rain, wind and storms already weather.gd)
- [x] 6. VFX library: cast runes, spell rings, statuses, pickups, level-up column, hits and kills (hit_reads), tells (telegraph_glow), kindling (kindling_surge), boss phase marks (arena_light)
- [x] 7. Interiors: the door dissolves the outdoor night, rooms with no light are given one (the rooms' own fixtures, door ambient and fog: already Interiors and weather.gd)
- [x] 8. The lantern: brighter in the dark (+40 percent), raised in the dark and when peering, gutters with the gloom (gloom_world.gd), swings (character_rig.gd)
- [x] 9. Boss arenas: five palettes, three phases each, set-piece lights on the rim, the phase mark, the moon dimmed
- [x] 10. Palette: grass and leaf desaturated with a value shoulder, the grade's green saturation eased, region grade by biome, canopy near-fade narrowed
- [~] 11. The far-leaf dither (shader half DONE, builder half routed to the world seat, see the cross-team need below): the engine's visibility-range dither (FADE_SELF on every ranged mesh, atmosphere.gd) is a coarse screen-door pattern over 6 to 10 m; the foliage shader now thins the near-camera dither (1.6 to 1.1 m) but a per-instance shader fade for tree crowns (as the undergrowth's `fade_end`) is the real fix: it needs tree_gen to set `fade_end` per crown MultiMesh (world seat: core/world/realm/flora)
- [x] 12. Bats come to every lit fire (fire_bats.gd, one draw call, the bat orbit shader); owls watch the moths and bats round a fire (life_birds.gd)
- [x] 13. Crows at boss arenas (rims added in LifePlace.crow_roosts)
- [ ] 14. Dog and cat meshes of their own (the pets wear the wildlife's fox body, scaled)
- [ ] 15. Voxel ruins albedo and light response (the black kit boxes: a world-seat material job)
- [ ] 16. The black quads on the saltmarket ground (close_saltmarket.png): not the tracks (track.gdshader draws dark shapes at 0.07) but some scatter material: world seat to find
- [ ] 17. The summit orb cap and NPC rim light (critique F-8, F-5)
- [x] 18. Warm-up: every night material and burst preset behind the loading cover (night_warm.gd, night_fx.gd, a guard test); the first-view hitches of the OTHER systems (84 ms worst at hearth) still need a measured look

## Cross-team needs
- World seat: dog and cat meshes (LifeKit kinds) for the pets; the black scatter quads (saltmarket); voxel ruin materials; `fade_end` on tree crowns; stage anchors for the folk in other towns (the folk stand only in Hearthward: positions come from `village_cast.gd` NODES, so a town's walking nodes would give it its own sweeper, fiddler and children).
- Opening seat: nothing.
- Story seat: the regard that makes the folk wave is the number of village restorations (`VillageState.data().restored`); a finer regard value would sharpen it.


## Cross-team need: tree crowns' distance fade (the far-leaf dither) - for the world seat (tree builder)
The engine's `VISIBILITY_RANGE_FADE_SELF` (set on every ranged mesh by atmosphere.gd and by the tree builder) dithers a crown out over its margin with a coarse screen-door pattern, and draws it
in the transparent pass. The foliage shader now has the finer replacement the undergrowth already has: a per-pixel interleaved-gradient dither keyed to the camera distance, no engine fade.
It is OFF until the builder sets one instance uniform per crown MultiMesh. The exact change (where tree crowns are emitted, core/world/realm/flora_emit.gd next to `_set_range`):

```gdscript
# in flora_emit.gd, beside the tag == "c" branch of _set_range: a tag for tree crowns (e.g. "t"), with `re` the crown's range
static func _set_crown_range(mmi: MultiMeshInstance3D, re: float) -> void:
	mmi.set_instance_shader_parameter(&"crown_fade_end", re)          # realm_foliage.gdshader: dither over re .. re + 6 m
	mmi.set_meta(&"fade_end", true)                                   # the fade guard must not add an engine fade to it (fade_guard.gd reads this meta)
	mmi.visibility_range_end = re + FADE_BAND                          # culled at re + 6 m, nothing drawn past it
	mmi.visibility_range_end_margin = 0.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
```
Call it for every crown (non-ground card) MultiMesh the flora emits with the range it uses today (the end it passes to `visibility_range_end` now, minus 6 m so the dither ends where the old fade did). Trunks and solid pieces keep the engine fade
(their pieces are solid, sparse and hidden by the crowns' own dither). Check: the same tree-line views at 40 to 120 m before and after, in a still frame and walking: no screen-door band, no pop at the cull.


## Resume state (end of round three)
Done and committed: everything ticked above. Open, in order of value:
1. Film and measure everything (the lead): the first thing to verify is that the whole thing parses (the import) and that the quick tier passes, including `night_life`.
2. The tree crowns' distance dither: the builder half (cross-team need above).
3. Dog and cat meshes; the black quads and the voxel ruins (world seat).
4. More weather states (the Weather node's FRONTS table is weather.gd's: a front with its own sky look would be a new row plus a `SkyLife` read), more folk roles (a washerwoman at the well, a candle-bearing pilgrim at the chapel, children's skipping rope), a first-view hitch measurement at Hearthward with the warm-up in.
5. Frame-strip checks of the folk's act changes at 60 and 144 Hz: if any pops, the crossfade length in folk_actor.gd (0.28 s) and the envelope in the pose is where to tune.


## Reduce Flashes and the colour-blind telegraph (routed)
Access.flash() now scales: the lightning (`weather.gd` `_thunder`: the flash value, so the sky flash, bolt, cloud veil and ambient surge all follow), the enemy hit flash and its squash (`enemy.gd`), the boss bar's phase flash (`boss_arena.gd`),
every Vfx flash light (`Vfx.light`) and the hit star (`Vfx.impact`), the magic bolt's lights and muzzle flash, the level-up burst (colour and `ratio`), the objective line's pulse, the stamina meter, skill bar and growth card flashes,
and in the night's own systems: NightFx's flashy presets (their count), the kindle, arena-phase and level rings, the registry pulse (every landmark card's flare), the level column, the telegraph light's last-quarter flicker.
Not scaled, on purpose: the glade secret's mouth flash (`site_glade.gd` `_flash`): it is the puzzle's visible phrase, a cue and not a flash; the opening seat should decide whether it needs a calmer form.
Access.telegraph() now colours the telegraph glow (amber and landing rings), the hurt ring and spark presets (`NightFx.DANGER`, so the warm-up replays the shifted colours). SpellFx.danger already used it.
Checked, nothing found: a boss-intro white-out and a ward pulse as shader terms were not found (searched core/enemy/boss_frame.gd, boss_title.gd, skill_ward.gd, spell_fx.gd).
Pre-existing on master, not mine: `ui/settings_menu.gd` is 1002 lines against a baseline of 0 (lint).

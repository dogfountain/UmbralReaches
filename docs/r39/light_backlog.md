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
- [ ] 11. The far-leaf dither: the engine's visibility-range dither (FADE_SELF on every ranged mesh, atmosphere.gd) is a coarse screen-door pattern over 6 to 10 m; the foliage shader now thins the near-camera dither (1.6 to 1.1 m) but a per-instance shader fade for tree crowns (as the undergrowth's `fade_end`) is the real fix: it needs tree_gen to set `fade_end` per crown MultiMesh (world seat: core/world/realm/flora)
- [x] 12. Bats come to every lit fire (fire_bats.gd, one draw call, the bat orbit shader); owls reacting to light remain (the wildlife's own state machine in life_birds.gd: a "draw to a lit fire" state is the next step)
- [ ] 13. Crows at boss arenas (LifePlace.crow_roosts takes graves and the henge: add the arenas' rims)
- [ ] 14. Dog and cat meshes of their own (the pets wear the wildlife's fox body, scaled)
- [ ] 15. Voxel ruins albedo and light response (the black kit boxes: a world-seat material job)
- [ ] 16. The black quads on the saltmarket ground (close_saltmarket.png): not the tracks (track.gdshader draws dark shapes at 0.07) but some scatter material: world seat to find
- [ ] 17. The summit orb cap and NPC rim light (critique F-8, F-5)
- [ ] 18. First-view hitches at Hearthward (84 ms worst in regions_a hearth): shader and material pre-warm behind the loading cover

## Cross-team needs
- World seat: dog and cat meshes (LifeKit kinds) for the pets; the black scatter quads (saltmarket); voxel ruin materials; `fade_end` on tree crowns; stage anchors for the folk in other towns (the folk stand only in Hearthward: positions come from `village_cast.gd` NODES, so a town's walking nodes would give it its own sweeper, fiddler and children).
- Opening seat: nothing.
- Story seat: the regard that makes the folk wave is the number of village restorations (`VillageState.data().restored`); a finer regard value would sharpen it.

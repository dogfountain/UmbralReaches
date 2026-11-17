# Lighting and visuals critique (seat 4)

Method and limits: read-only. I viewed about 20 captures at full size (regions_a/b, places) and read atmosphere.gd, light_policy.gd, light_director.gd, grade.gdshader. NOT available: the `villagers/` and `ui/` capture folders are empty (run.log only), there are no combat/hit/spell frames at all, and the boss arena stills are broken (see F-12). Luminance numbers below are my estimates from the constants, not measured pixels. Paths: captures are under `.../968888c4-.../scratchpad/play/`.

## Verdict

The night is already readable and handsome up close (close_hearth.png is the best frame in the set: warm windows, brazier pool, clear blue key, a readable player). The weaknesses are (a) the night is lit almost entirely by ONE cool key plus a shadowless fill, so everything not near a fire is the same blue-green mass; (b) local light is short-ranged and the budget is small, so places do not read from afar; (c) the kit-built ruins and the grass fight the grade; (d) the new bosses have no night-lit evidence. Luke's brighter-night / dimmer-moon instinct is right in direction, but the lever that matters is the unshadowed fill + ambient, not the moon disc.

## 1. Places that have light (region by region)

Code facts: braziers use ILLUM `beacon` [0.55, 1.05] (light_policy.gd:16), lamps 0.62, player lantern 0.55, kept lamp 0.48x energy and 0.9x range (:27), village lights 1.0. LightDirector keeps only BUDGET [14, 24, 36] local lights by detail (light_director.gd:19), and realm lights fade from 46 m (light_policy.gd:312). Only one fire casts a shadow.

| Region | Capture | Lit? Motivated? Pools? Reads from afar? |
|---|---|---|
| Hearthward | close_hearth, over_hearth, region_hearth_0 | Best in game. Window glow, brazier, lanterns, tiles take warm pool with moon shadows. Motivated and guiding. From afar (vista_hearth_from_south, vista_realm_from_se) it vanishes: a couple of window specks and one pink dot. The spawn town is not a beacon. |
| Moor camp | region_moor_0 | Camp fire is the only light; good pool, reads, motivated. But the lit patch is the only readable area; the road onward is a dark tunnel under a canopy (P2 canopy black). |
| Thorn Henge | region_thornwood_0, arena_thornwarden | Four orange cone flames on plinths, tiny red pools. Flames are bright but the floor pools are weak, so the arena edge is not defined by light. Red ring telegraph is a 1-2 px line (F-9). |
| Fen | region_fen_0 | One bright white spot on the far horizon (moon flare or lamp, ambiguous), blue wisps. Nothing guides the player to the black tower; the only warm points are 2-3 pixel embers. |
| Rift | region_rift_0 | Lava crevice orange reads well and is motivated. Rest is near-black blue silhouettes. Fine for mood; walls in shadow are unreadable. |
| Foundry | region_foundry_0 | Furnace mouth glows but throws no visible light on the pit lip or path; a forge should light its surroundings. Add a pool (F-4). |
| Ossuary/Necropolis | region_ossuary_0, region_necropolis_0 | Warm light only at screen edge; the graveyard is a flat blue plane with black box tombs. No grave lights, no candles on tombs. Dead area for guidance. |
| Saltmarket | close_saltmarket | Warm window lights, a few lanterns; reads as a settlement. Lights are too small and too low in energy to pool on the paving; the ground is lit only by the moon. |
| Glade | region_glade_0 | Small orange lantern glow near the ground, hanging lantern unlit (cage dark, no glow on its tree). A hanging lantern that gives no light is unmotivated dressing. |
| Summit/orb | vista_realm_from_se | The summit orb is the only landmark that reads at distance. It is bloomed hot white and over-bright; everything else in the vista is a uniform blue field. |

Summary: lights are motivated almost everywhere, but pooling radius is small, there is no mid-distance guidance, and no region except the summit reads from afar. Recommended: raise the light kinds in section 2 and give the 6-8 landmark places a tall emissive element (a lit tower window, a column of hearth smoke lit from below) that survives the fog.

## 2. Luke's question: brighter night, darker moon?

Current balance (atmosphere.gd), my arithmetic for a horizontal surface:
- Key: MOON_ENERGY 1.5 (:138), colour (0.66,0.78,1.0), elevation 46 deg. Horizontal irradiance = 1.5 sin46 = 1.08.
- Fill: FILL_ENERGY 0.6 (:163), shadowless, elevation 24 deg, from the opposite bearing. Horizontal = 0.6 sin24 = 0.24. Because it casts no shadow it also lights the moon's shadows, so moon-shadow floor is about 0.24 + ambient.
- Ambient: ambient_light_energy 0.125 (:112), COLOR source (0.24,0.22,0.34), sky contribution 0. About 0.03 effective.
- Exposure 1.0 (:115; the .tres says 0.84 but the code overwrites it), AgX tonemap, glow threshold 1.15.
- So lit ground ~1.35, shadow ground ~0.27 : ratio about 5:1 (2.3 stops). That is a fairly contrasty night, closer to "moon is a sun" than to a lifted gloom. It is why the frames show crisp black tree shadows (region_moor_0 canopy, region_ossuary_0 tomb shadow) with no shape inside them.
- Then the grade (grade.gdshader): black_crush 0.055, vignette 0.42, saturation 1.42, split-toning with shadow_tint (0.02,0.04,0.22) crushes the darks further and the tint pushes everything to one hue.
- Local lights are 0.48 to 1.0 x authored energy. Relative to the moon a lantern pool must beat 1.35 on the ground at 2-3 m to look warm; it does for braziers, not for lamps at 0.62.

Option A (what Luke asked): lower moon, raise ambient/fill.
- Readability: up in shadows and canopy; paths and pickups stay visible farther. Mood: loses the single-light drama if you overdo it; flatter. Contrast: lit-to-shadow ratio drops (good for a game with enemies in trees, bad if it hits 2:1).
- It also reduces the moon's fog scatter and the hard black voxel ruins.

Option B: keep the moon, raise only local lights. Warm pools pop, mood kept, but the unlit majority of the world (the bulk of play) does not improve. Insufficient alone.

Option C (recommended): A and B, tilted toward fill/ambient, with warm local lights lifted in proportion so warm/cool contrast is kept (the game's identity). Concrete values, all free (constants only):

| Parameter | Old | New | Effect |
|---|---|---|---|
| MOON_ENERGY (atmosphere.gd:138) | 1.5 | 1.2 | key -20%; shadows still cast, less glare on pale stone |
| MOON_FOG (:140) | 0.35 | 0.28 | less blue veil in the froxels as the key drops |
| FILL_ENERGY (:163) | 0.6 | 0.85 | lifts moon shadows and back-lit faces (+0.10 horizontal) |
| FILL_COLOR (:164) | (0.58,0.64,0.86) | (0.60,0.68,0.92) | slightly bluer-teal, keeps hue separation from grass |
| FILL_ELEVATION (:165) | 24 | 32 | a higher fill also reaches canopy undersides, ground in tree shade |
| ambient_light_energy (:112) | 0.125 | 0.19 | lifts true-dark crevices and canopy interiors |
| ambient_light_color (:114) | (0.24,0.22,0.34) | (0.26,0.27,0.40) | less purple, more blue-teal so dark areas stop reading violet-black |
| volumetric_fog_ambient_inject (:108) | 0.06 | 0.10 | distance haze carries lift to the far field |
| ILLUM beacon (light_policy.gd:16) | 0.55 | 0.75 | brazier pools win against the higher fill |
| ILLUM lamp | 0.62 | 0.85 | windows/candles pool on the ground |
| ILLUM village | 1.0 | 1.2 | village windows read at 25-30 m |
| ILLUM kept_lamp | 0.48 / 0.9 | 0.65 / 1.0 | player-kindled lamps are the player's guidance and are dim |
| grade black_crush (grade.gdshader:21) | 0.055 | 0.035 | stops a 10% crushed floor undoing the lift |
| grade vignette (:25) | 0.42 | 0.34 | edges are where enemies come from |

Expected look: horizontal lit ~1.08 -> about 0.96 + fill; shadow floor 0.27 -> about 0.42; ratio about 3.2:1 (1.7 stops); sky/aurora untouched. Shadows keep a visible silhouette but you can see roots and enemies inside them; paths read without becoming grey. Warm pools stay at least 2x the surrounding lit ground. Keep exposure at 1.0; do not touch AgX contrast (the comment at :116-119 says contrast 1.5 dulled it).

"Darker, smaller moon": the moon's visible disc and flare are in vortex.gdshader (see :116-117; Luke already toned it down 30%). Do not shrink them further; the disc is a navigation cue (and the summit orb already overpowers it, see F-8). The perceived brightness is the key light, which the table above handles.

Do not: add more shadow casters, enable SSIL (+2.8-5.6 ms per the file header), raise froxel resolution, or enable dynamic resolution. All the changes above are uniform/constant edits with zero frame-time effect; verify only one thing, that glow (threshold 1.15) does not start to catch bright wet stone when ambient rises. Test at the 8 hardest frames: region_moor_0, region_thornwood_0, region_ossuary_0, region_fen_0, close_hearth, close_saltmarket, region_glade_0, vista_realm_from_se.

## 3. Overall visuals

F-1 (P1) Single-hue night. Almost every non-lit surface lands in one blue/teal band: split toning (grade.gdshader:12-17) plus hue_pull 0.28 plus saturation 1.42. Evidence: region_ossuary_0.png, region_necropolis_0.png, close_saltmarket.png. Lifts value (section 2) but also add hue variety: let split_amount drop 0.22 -> 0.16 so wood, moss and dirt keep their own colour. Effort S, perf none.

F-2 (P1) Grass is the loudest object in the frame. Saturated emerald with a bright blade tip (region_ossuary_0, region_necropolis_0, region_fen_0, close_hearth) at luminance higher than the path, owing to green_lo=155 which exempts greens from the cool pull. It pulls the eye away from pickups, paths and enemies and clashes with the rest of the blue world. Fix: tint the grass shader/albedo toward (0.30,0.42,0.30) x 0.8, or lower the green exemption to green_lo 165 so it takes a part of hue_pull. Effort S, perf none.

F-3 (P1) Two art styles on the ground. The voxel/box-kit ruins (fen tower in region_fen_0, towers in region_rift_0, tombs in region_necropolis_0, black mass in region_ossuary_0) are flat black blocks with 1-bit stepped edges and almost no light response, next to hand-painted stone, textured tiles and good timber (close_hearth). They read as placeholders. At minimum give them a moon-facing albedo floor: raise their albedo from the near-black to ~0.12-0.16 and add the stone detail normal the other masonry uses. Effort M, perf none.

F-4 (P2) Foundry furnace, glade lantern, graveyard have light sources with no light cast (region_foundry_0, region_glade_0, region_ossuary_0). Add an OmniLight3D with `base` meta and kind `lamp` or `fill` (energy ~1.4, range ~7, color (1.0,0.55,0.25)); they join the budget and distance fade automatically. Effort S, perf: a few budgeted lights, within BUDGET.

F-5 (P2) Characters are dark on dark. Saltmarket villagers (close_saltmarket) in near-black coats walk on blue paving; only a faint rim separates them. Player at close_hearth reads because of the brazier rim light, the lantern pool and the staff. Fix: raise the villager rig's moon response (rim/fresnel) or a small `hero_fill` rim on NPCs near the player; the fill increase in section 2 helps for free. Effort S-M.

F-6 (P2) Black quad decals on the ground in close_saltmarket (about 15 hard black diamonds/rectangles on the gravel, bottom right). They look like missing-texture footprints or dropped geometry. Check the decal material (alpha/colour, probably unshaded black). Effort S.

F-7 (P2) Distance. vista_realm_from_se and vista_realm_from_sw: the far field is a blue-grey ceiling of rounded tree-blobs with no light structure; the only focus is the summit orb. Fog depth curve 0.48, begin 30 m (atmosphere.gd:74-91) is already generous; the lack of far light is the problem, not fog. Add 6-8 emissive-only beacons (window clusters, a lit watchtower top) that are not Light3D (so no budget cost), as small emissive meshes with `visibility_range` far.

F-8 (P3) Summit orb in vista_realm_from_se blooms to a pure white 8-ray star, brighter than anything and out of palette. Cap its emission to ~2.5 and warm-tint (1.0,0.9,0.7) so it reads as a beacon rather than a lens flare. Effort S.

## 4. VFX and combat readability

Evidence is thin: no hit, spell or telegraph frames in the set. What I can see:
- F-9 (P1) Thornwarden arena (region_thornwood_0, arena_thornwarden): the red danger ring is a 1-2 px line, low alpha, on dark gravel. Telegraphs are the most important combat read at night. Fix in `core/vfx/danger_zone.gdshader`: add a filled inner disc (alpha 0.18) with a bright rim 6-8 cm wide, and pulse it; keep emission around 3.0 so glow (0.62, threshold 1.15) picks it up. Effort S, perf none (decal count unchanged).
- Ascended Warden arena (arena_ascended_warden.png): the amber ring decals around the four braziers read well and are the model to copy: closed ring, saturated, readable from 15 m.
- The glow budget (levels 0 and 1 only, atmosphere.gd:216-218) is correct; the cone flames on plinths (region_thornwood_0) are good, readable silhouettes.
- F-10 (P2) Request: capture a combat strip (player hit, enemy hit flash, one spell, one boss telegraph) in the night grade. Without it I cannot sign off hit feedback. The grade's `hurt` flash (hot pink/red full-screen, grade.gdshader:157) is strong; arena_thornwarden shows a heavy magenta wash and vignette across the entire frame, which at that intensity hides the ground telegraphs it should help you dodge. Cap hurt wash at 0.4 and keep it to the screen edges.

## 5. Animation as seen

No villager or wanderer strips exist (villagers/ is empty). From what I can see:
- F-11 (P2) Saltmarket crowd (close_saltmarket): four figures walk in the same direction at the same pace in a loose line, arms at their sides, identical pose; they look like a procession, not a market. Needs idle variety (stoppers, turning heads, hand to hood) and speed variance of +-15%. A feet check: contact looks plausible in the still but I cannot judge sliding from one frame.
- The boss strips (cs3/anchoress_strip.png, ascended_warden_strip.png) are studio-lit grey, not the night, and 14 px tall in the 2880 px strip: unreadable for judging animation. The Anchoress poses (stone swing, raised arm) have clear anticipation and a gesture silhouette; the Warden barely changes between frames: a bell with a halo that floats and shifts a few degrees. The Warden needs a bigger rest-to-strike shape change (arms spread, halo flares).
- The abbot0_strip.png render shows excellent cloak/gold design but in a studio light; its night read is untested.

## Other critiques

F-12 (P1, QA) The boss arena captures are broken and cannot support any judgement: arena_bone_abbot.png is a camera upside-down against a blue wall; arena_r37_anchoress.png is blocked by a spruce branch; arena_thornwarden.png carries a screen-wide hurt wash. The new bodies (Abbot, Warden, Anchoress, Crown, Thornwarden) have never been seen in the real grade in this evidence set. Fix the capture camera (offset to 14-18 m, 8 m up, look at boss) and re-shoot with the boss at full height and the player near. Until then treat the bosses' night legibility as unverified: the Warden's pale ivory/gold should pop; the Anchoress's brown robe (anchoress_strip) will likely sink into the ground.

F-13 (P2) Dark-canopy tunnels. region_moor_0: top 60% of the frame is black leaf mass with a hard stipple pattern (dither/LOD fade visible at full size). The canopy interior should take the ambient lift from section 2; if the stipple is canopy_shell.gdshader's fade, make the transition begin farther and be a smooth alpha.

F-14 (P3) Perf evidence is clean: places avg 8.44 ms at 118-119 fps; worst frames 47-84 ms appear at the first frame of a location (region_hearth worst 84.5 ms, close_hearth worst 77 ms, vista_hearth worst 77 ms): these are one-off, but the stutter priority says look: likely first-draw shader/pipeline compile on the first view of lit shaders. Pre-warm the hearth brazier, lamp and window-light materials in the loading cover. Effort M.

## Priority list

1. P1 Section 2 constants (MOON 1.2, FILL 0.85, ambient 0.19, ILLUM lifts, black_crush 0.035): S, free.
2. P1 Fix boss arena capture and re-verify night read (F-12).
3. P1 Grass saturation/value (F-2); P1 voxel ruins (F-3); P1 single-hue grade (F-1).
4. P1 Telegraph ring weight (F-9), cap hurt wash (F-10).
5. P2 give lit-but-castless sources a light (F-4), far beacons (F-7), black decals (F-6), NPC rim (F-5), crowd variety (F-11).
6. P3 summit orb cap (F-8); first-frame hitch pre-warm (F-14).

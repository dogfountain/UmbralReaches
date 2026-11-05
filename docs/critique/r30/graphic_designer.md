# r30 critique: graphic / art direction

Lens: characters and creatures, bosses, wildlife, environment and props, materials, lighting and
the grade, VFX, UI and type, silhouette at night, consistency. Read-only pass. No project file was
changed except this one.

Evidence was rendered with an isolated HOME (`/private/tmp/claude-501/art_home`) into
`/private/tmp/claude-501/art_shots/` (abbreviated below as `S/`):
- `S/studio_<kind>_0|1.png` and `S/studio_sheet.png`: zz/combat_studio (every kind and boss, moonlit studio, front 3/4 and side). Crops: `S/m_humanoid.png`, `S/m_quad.png`, `S/c_burrower.png`.
- `S/ig_<set>_<n>.png`: a scratch copy of zz/combat_shots (`S/gd/cs.gd`, written to /tmp) through the real camera and grade. Best frame: `S/ig_boss_warden_1.png`.
- `S/boss.avi` (Movie Maker, zz/trailer `--only=boss_reveal,boss_game,boss_wide,boss_low,fight_side,fight_otc`), frames in `S/tr_full/f_NN.png`, sheet `S/tr_sheet_s.png`, montages `S/m_abbot_ig.png`, `S/m_vfx.png`.
- `S/look_*.png`: a scratch copy of zz/look_shots. `S/m_env.png`, `S/look_tavern.png`.
- `S/ui_ui_1920x1080_*.png`: zz/ui_shot at 1920x1080. `S/m_ui.png`, `S/c_hud.png`.

## Verdict

Luke is right: the bosses are bad, and the reason is structural. None of the three has a body of
its own. `BossKit.embiggen` (core/enemy/boss_kit.gd:208) scales a rank-and-file enemy 1.8 to 2.2
times: same proportions, same tube count, same skin texel size, the same HunchRig or QuadRig, the
same twitchy idle. So a boss looks like a toy enlarged. Every enemy is built from one kit
(CreatureMesh tubes and blobs, rigid per joint). Three habits in that kit sink the whole bestiary:
1. **Cloth is made of cones.** Robes, veils, sleeves, hair and rag skirts are separate tubes that
   taper to a point. The Abbot's cassock reads as a picket fence, the Warden's robe as a bundle of
   icicles, the Chanter's as a broom.
2. **One wet-plastic material.** Skin, bark, bone and chitin all get the same glossy flesh shader
   with a crinkled-foil normal map, plus an unlit violet rim.
3. **The palette fights the grade.** Every boss signature is violet: eyes, halo, reliquary,
   grave-fire, rim light, HOLY telegraphs. The grade pulls 236-360 deg into the 205-236 blue band at
   full strength, so in game all of it becomes the world's own blue. The Warden reads navy on navy.

The environment and the grade have a strong identity: the vortex sky, azure moonlight and ember
accents. The UI is tidy but typographically split. The enemy cast is the weakest part of the frame,
and it is the most fixable, because everything is procedural and cached by GenCache salt.

## Findings

Severity: **Critical** (the asset reads wrong, or as broken), **High** (clearly hurts the read),
**Medium** (a visible quality gap), **Low** (polish).

### 1. Critical: the bosses are scaled-up grunts, not designed bosses
Evidence: core/enemy/boss_kit.gd:208-229 (`embiggen`: `rig.scale *= s`). thornwarden.gd:38
(Leaper x2.0), bone_abbot.gd:46 (Ossuant x1.8), ascended_warden.gd:38 (Husk x2.2).
core/enemy/enemy_body.gd:163-437: the bosses take the humanoid/quad builders with a few `if abbot`
/ `if warden` add-ons. Shots: `S/studio_thornwarden_0|1.png`, `S/studio_bone_abbot_0.png`,
`S/studio_ascended_warden_0.png`.

Problem:
- Scaling copies the proportions and the detail density of a 1.6 m grunt. Big things should carry
  more, smaller detail, and different mass (heavier base, smaller head relative to body, longer
  stride).
- Tubes of 4-9 sides and 8x12 blobs are faceted at 2x and at boss camera distances.
- Skin detail repeats every `detail_tile` 0.18 m in mesh space (enemy_body.gd:139), so on a boss it
  repeats every 0.36-0.4 m in the world. The wrinkles double in size and read as a blown-up toy.
- Idle sway, twitch and breathing run at grunt frequency (hunch_rig.gd:129-134). A 4 m priest that
  twitches like a wretch has no weight.

Fix (procedural):
- Give each boss its own builder: `_thornwarden_parts`, `_abbot_parts`, `_warden_parts`. They
  should share helpers, not the grunt body. Per-asset recipes are below.
- In `embiggen`, also set `material.detail_tile = 0.18 / s` on the boss material (they already have
  their own material per kind), and raise tube `sides` / blob `segs` by about x1.6 for boss builds.
- Add an `anim_rate` on HunchRig/QuadRig, set to `1/sqrt(s)` by embiggen, that multiplies delta in
  `_tick_poses` and the sway frequencies. Set twitch to 0 on all bosses. Big means slow and
  deliberate.

### 2. Critical: cloth, hair and veils are tapering tubes, so robes read as rods and icicles
Evidence: creature_mesh.gd:220-230 (`strand`: radius tapers and `radii[segs-1] = 0.0`).
enemy_body.gd:182-192 (Abbot/Warden robe: 18 separate 5-sided tubes on the pelvis, end radius 0.03).
enemy_body.gd:285-296, 372-392, 538-541 (stole, sleeves, veil: all `strand`). kin_look.gd:199-210
(Chanter robe, 16 tubes). Shots: `S/studio_ascended_warden_0.png` (a hedgehog of violet spikes with
the skeleton showing through the gaps), `S/studio_bone_abbot_0.png` (cassock = black slats, bare
feet between them), `S/m_humanoid.png` bottom-left (Chanter), `S/ig_boss_warden_1.png` (in game: a
cage of blue bars).

Problem: cloth has no surface. Each panel is a cone with a gap to the next, so light catches every
edge as a separate rod. The panels are rigid on the pelvis joint, so legs and feet stride through
them (Abbot side view). The wretch's "lank hair" and the Warden's veil read as spikes for the same
reason.

Fix:
- Add `CreatureMesh.skirt(center, rx, rz, length_front, length_back, flare, folds, rows=8, cols=28)`:
  one lofted, closed surface. Radius `r(θ, t) = lerp(top, top+flare, t^1.5) * (1 + 0.08*sin(folds*θ + noise))`
  gives real vertical folds. Hem length per column = base + fbm noise (torn hem); cut deep tears by
  skipping 2-3 columns over the last 30% only. Render it double-sided (rag channel, cull disabled in
  a cloth variant of flesh.gdshader).
- Add `CreatureMesh.ribbon(root, dir, length, width, droop, twist)`: a flat 2-sided strip with
  constant width to 85% of its length, then a short taper. Use it for veils, stoles, sleeves, hair
  and rag strips in place of `strand`.
- Drive the skirt hem with the wanderer's robe approach: robe_skin.gdshader already drapes over the
  forward knee from hip/knee uniforms (HANDOFF r29 B). Feed the boss's hip/knee rotations into the
  same uniforms so the cassock moves with the legs instead of being cut through by them.
- For the Warden, see 3c (no legs at all).

### 3. Critical: the grade erases every boss's signature colour
Evidence: world/post/grade_material.tres:9-11 (band 205-236, `hue_pull = 1.0`) with grade.gdshader
lines 70-96 (only warm 8-66 deg, saturated reds and 85-200 deg keep their hue). The enemy palette:
- flesh rim `rim_col` (0.45,0.32,0.9) at flesh.gdshader:17, about 253 deg
- Ossuant/Abbot eyes (1.1-1.2, 0.5, 2.6-2.8), about 257 deg (enemy_body.gd:119,121)
- boss glow mats (enemy_body.gd:147): Warden halo (1.5,0.75,3.2), Abbot reliquary (1.3,0.6,2.8)
- `BossKit.HOLY` (1.4,0.6,2.6) (boss_kit.gd:10), `GRAVE_FIRE` (1.1,0.5,2.4) (bone_abbot.gd:20),
  flesh `burn_col`

All of these sit at 255-266 deg and are pulled to 236: azure, the same hue as the moonlit world.
Shots: `S/ig_boss_warden_1.png` (the studio's violet robe and halo come out cobalt and ice-white,
navy against a navy fen), `S/m_abbot_ig.png` (the Abbot's eyes and reliquary blue-white).

Problem: the bosses have no colour identity in game, and no figure/ground separation. The only
hues the grade lets through for a focal accent are ember/amber/gold (bright), saturated red, and
green-teal. The enemy cast uses none of them deliberately, except the Chanter (green) and the Mite
(teal), which are, tellingly, the two best reads at distance.

Fix (the grade is the lead's: recommend, don't restyle). Either:
- (a) **Design to the grade (preferred, art-side only):** give each boss an accent in a protected
  band. Abbot: candle-gold (matches the ossuary's candles). Warden: white-gold "holy" (warm
  near-white is protected). Thornwarden: ember (already) plus moss green. Recolour HOLY and
  GRAVE_FIRE to match.
- (b) **Lead option:** protect saturated, bright violet emissive pixels (hue 250-300, S > 0.6,
  V > 0.5), the way r29 protected lit reds. That costs one more smoothstep term in grade.gdshader
  and leaves dull violets (the sky's magenta cast) pulled as now.

### 4. High: one glossy "wet flesh" material for skin, bone, bark and chitin
Evidence: flesh.gdshader:68-69 (roughness 0.32-0.48, specular 0.42-0.55 for everything that is not
rag). skin_tex.gd:35-43 (normal strengths 5-6 for husk/leaper/thorn/crawler at 128 px).
enemy_body.gd:607-608 (Thornwarden bark plates are `bone` 0.85 and so get the glossy bone path).
Shots: `S/studio_thornwarden_0.png` (bark shines like lacquer), `S/c_burrower.png` (crinkled-foil
carapace), `S/studio_husk_0.png`.

Problem: no material separation. Bark, bone, chitin, dead skin and wet maw all share the same sheen.
Strong cellular normals at that gloss read as crumpled tinfoil, not hide.

Fix:
- Add uniforms `rough_flesh`, `rough_bone`, `spec_scale` and a `bark` channel (COLOR.a = 0.5, or a
  UV2 bit). Bark 0.85-0.95 rough, specular 0.2. Dry husk skin 0.7. Bone 0.55-0.65. Keep the wet look
  (0.3) only for the maw, eyes, glands and the spitter.
- Halve the normal strength for husk, leaper, thorn and crawler (6 -> 3).
- Add a cavity term: darken by `1 - hgt` in the creases and keep highlights on the ridges only.

### 5. High: the rim light is unlit violet emission, so bodies become neon and then go blue
Evidence: flesh.gdshader:71 and 82-83 (`EMISSION += rim_col * pow(1-ndv,3) * rim_amount`,
rim_amount 0.35-0.75 per kind at enemy_body.gd:114-122). Shots: every studio shot (purple outlines
on the top edges), `S/ig_boss_warden_1.png`.

Problem: emission ignores the light rig, so a body in shadow still glows at its silhouette: a
hologram look. In game the grade turns it blue (finding 3), so it adds nothing against a blue night.

Fix: move the rim into the lit path (a `light()` term gated by the moon's NdotL) or multiply it by a
cheap "lit" factor. Change its hue to a protected warm (an ember back-rim, very low, about 0.15).
Warm against cold is the classic separation, and the grade leaves it alone. Bosses can keep a
stronger rim in their own accent colour.

### 6. High: rigid per-joint parts give mannequin limbs with cracks at every joint
Evidence: enemy_body.gd:44-73 (`dress`: one MeshInstance3D per socket); limbs are
`CreatureMesh.limb` tubes per bone (enemy_body.gd:362-433). Shots: `S/studio_wretch_0.png` (rings
at elbow and knee, straight cylinder shins), `S/studio_husk_0.png` (trunk legs with a break at the
knee), `S/studio_spitter_0.png` (a stick figure).

Problem: each segment is a separate cylinder whose end caps open and close as the joint bends. No
muscle flows from torso to limb (no deltoid into arm, no glute into thigh). This is the main reason
the humanoids look like dolls.

Fix (two levels):
- Cheap: overlap. Extend every limb tube 15-20% into its parent, and add a joint "sleeve" blob
  (radius x1.1) at elbow, knee, shoulder and hip, so a bend shows flesh, not a gap. Add a deltoid
  blob at the top of the upper arm and a gluteal mass on the pelvis.
- Right: skin it. The wanderer already bakes generated parts into ONE skinned mesh on a runtime
  Skeleton3D (core/player/wanderer_body.gd, `build`). Use the same bake for enemies, with
  two-bone weights in a 6-8 cm band around each joint, so knees and elbows bend smoothly. One draw
  per enemy instead of about 14, which also pays for the extra boss tessellation in finding 1.

### 7. High: QuadRig legs give the Leaper and the Thornwarden a coffee-table side view
Evidence: core/enemy/quad_rig.gd:58-61 (two segments: the knee goes out sideways `sx * upper_len`,
then the shin goes straight down `-(body_height + 0.08)`); enemy_body.gd:675-704 (shins end in a
point; the toes are tiny claws). Shots: `S/m_quad.png` bottom row (Leaper and Thornwarden side
views: a horizontal sausage on four vertical posts), `S/studio_leaper_0.png`.

Problem: from the side the hips sit inside the belly and four equal posts drop from it. The
"heavy haunches" in the doc comment don't exist. Pointed shins stab into terrain like stilts.

Fix:
- Give QuadRig an optional third segment (`hock`) on the hind legs: hip under the spine, knee
  forward, hock back, long metatarsal, a foot pad. Forelegs: shoulder blade, elbow back, wrist.
- Set front/back body heights apart (`front_height`, `rear_height`) so a leaper is
  shoulder-high and a warden is chest-high.
- Give every foot a pad or hoof blob (and for the Thornwarden, splayed root toes).
- Gait: the walk should be a lateral-sequence walk, not a diagonal trot, below about 3 m/s.

### 8. High: no colour or value key per family: every enemy is the same mid mauve-grey
Evidence: enemy_body.gd:114-122 (skins 0.46-0.72, all desaturated mauve). Shots: `S/studio_sheet.png`
(under the warm lamp they are all peach), `S/ig_*` (under the moon they are all blue-grey).

Problem: at 15 m in greyscale you cannot tell a wretch from a husk except by shape, and from a
spitter only by its cyan sac. Bosses do not stand out from their own minions by value.

Fix: set a value and accent key, in bands the grade keeps (finding 3):
- Wretch: dark charcoal body, pale face (the darkest kin).
- Husk: sickly yellow-green bloat (the green band is protected).
- Spitter: pale with teal glands.
- Crawler / Mite / Burrower: dark chitin with teal (mite) or amber (burrower) lights.
- Leaper: near-black with ember eyes and an ember belly.
- Ossuant: dark husk flesh under bright bone (see its section).

Bosses get the brightest value in their arena (Abbot bone-white with gold, Warden white-gold) or
the darkest with a hot core (Thornwarden).

### 9. Medium: glow parts are flat unshaded blobs that read as stickers or light bulbs
Evidence: spitter.gd:62-68 (the throat sac is a `SphereMesh` with `ProcMesh.glow_mat`: an unshaded
flat disc). enemy_body.gd:228 (the husk's "chest hollow" is a glow blob mid-belly).
enemy_body.gd:299-301 (the Abbot reliquary). The warden halo is unshaded sausages (546-560). Shots:
`S/m_humanoid.png` top-left (spitter: a cyan plate on its chest), `S/studio_husk_0.png` (a light
bulb in the belly, the brightest thing on the body), `S/m_env.png` top-right (glowing mushrooms).

Fix: make glow come through form. Put the sac in the flesh material with a membrane term
(emission x fresnel-inverse, so the thick middle is darker and the thin edge glows), veins over it,
and a pulse. Turn the husk's bulb into a dim seam glow along the stitched belly cut
(enemy_body.gd:230). Keep pure unshaded glow for eyes only.

### 10. Medium: one animation set; bosses cast with a claw rake
Evidence: hunch_rig.gd:137-196 (the same `_legacy_pose` for every humanoid: hunch, rake, twitch).
ascended_warden.gd:121-122 (the fan of orbs fires on `strike()`: a two-handed downward claw rake).
bone_abbot.gd:47 posture. The crozier hangs from hand_r and swings with the arm: `S/studio_bone_abbot_0.png`
holds it like a downward cane, its hook behind the head.

Fix: add pose verbs to HunchRig:
- `orant`: arms raised, palms out, chest open; for the Warden's fan and judgement.
- `staff_hold`: right forearm level, hand counter-rotated to keep the shaft vertical (the Abbot,
  the Chanter); the crozier sweep becomes a two-handed swing of the staff, not a rake.
- `float`: no gait at all, a slow bob and drift (the Warden).

Bosses at `anim_rate < 1` (finding 1). Windups for bosses should be held poses with a readable
anticipation (a 0.3 s stillness at the top), not the grunt's tremble.

### 11. Medium: robed enemies share the wanderer's silhouette
Evidence: the Chanter (robe, hood, staff with a light: kin_look.gd:194-238) and the Warden (dark
robe) against the wanderer (dark robe, hood, staff with an orb). Shots: `S/m_humanoid.png`
bottom-left versus the wanderer in `S/tr_full/f_23.png`.

Problem: at night, at 15 m, "dark robed figure with a glowing staff" is the player's own read. A
Chanter in the corner of the eye reads as an ally or a mirror.

Fix: break the shape. The Chanter is hunched and bone-thin, its hood a deep cowl that juts forward
(not the tall cone it has now), its staff light green and low. The Warden floats and is pale. The
wanderer stays the only upright dark robe with a staff. (Do not touch the wanderer: umbral-donts.)

### 12. Medium: the danger colour is the ambient warm accent
Evidence: `BossKit.THORN` (2.6,0.5,0.1) and the ember telegraphs (A r29) share their hue with lava
rivers, lanterns, braziers and windows. Shots: `S/m_env.png` and `S/tr_full/f_10.png` (lava
stripes on every hillside, orange zone fills on the ground).

Problem: "red-orange on the ground = step out" is also "lava stripe / lantern pool" around the
Stair, so telegraphs lose pop near the warm set dressing.

Fix (with A): keep ember for the fill. Give telegraphs a distinct *form*: a pulsing hard outer ring
plus a sweep, which the danger_zone shader can do, and a white-hot leading edge, so they read by
motion and edge, not hue. Keep lava a deeper, darker orange (lower V, crust-dominant) so it never
matches the telegraph's brightness.

### 13. Medium: the grade's sharpen, grain and saturation make the frame crawl
Evidence: grade_material.tres:7-8, 19, 22 (sharpen 1.85, clamp 0.11, saturation 1.6, grain 0.038).
Shots: `S/c_hud.png` (ground and grass become salt-and-pepper), `S/look_tavern.png` (gravel and
stone sizzle), the studio skins (foil).

Problem: the unsharp mask plus grain plus x1.6 saturation turn every high-frequency texture into
chroma noise. That fights the enemy detail maps and makes the moving camera shimmer (E's 9-px grid
is fixed, but the sharpen remains the amplifier).

Fix (lead's call): sharpen about 1.0 with clamp 0.06, grain about 0.02 (luma-only, not RGB), and
saturation about 1.35. The look comes from the hue pull and the split tone, not from the crunch.

### 14. Medium: boss spikes and zone VFX are overexposed primitives
Evidence: boss_kit.gd:107-121 and 186-191 (one claw-cone spike, StandardMaterial albedo 0.82 with a
violet emission that the grade turns blue; thorn spikes 0.16 albedo). Shots: `S/tr_full/f_30.png`
(white traffic cones on white discs in the Abbot's pit), `S/m_vfx.png`.

Fix:
- Bone spikes: a cluster of 3-5 different, curved, ribbed shards (femurs, ribs, a jaw) with a
  dark, dirty base that blends into the floor; pale-gold rim, no violet.
- Thorn spikes: braided brambles (2-3 twisted tubes with barbs), dark bark, ember at the tips.
- Both should erupt with a dust/shard burst and leave a decal crack for 2 s.

### 15. Medium: UI type is split across three families, one of them platform-dependent
Evidence: headers in Cinzel (ui/fonts/Cinzel.ttf). Body text in a `SystemFont` (Georgia / Palatino
/ Liberation Serif / DejaVu: ui/codex.gd:103, ui/growth.gd:253, core/life/secrets/panel.gd:35),
which renders differently on the Linux pack. The dialogue body has no font override, so it uses the
Godot default sans (ui/dialogue.gd:144 `_text` RichTextLabel has no font override; only `_name` and `_sub` get Cinzel, lines 124, 174). The hotbar
icons are modern flat line icons. Shots: `S/m_ui.png`, `S/c_hud.png`, `S/ui_ui_1920x1080_dialogue.png`.

Fix (with F):
- Bundle one OFL text serif next to Cinzel (EB Garamond or Cormorant Garamond), set it in a project
  Theme as the default font, and drop SystemFont.
- Keep Cinzel for titles and names only.
- Give the controls card a 40% dark backing plate. It currently sits straight on bright sky
  (`S/c_hud.png`).
- Redraw the hotbar glyphs with the same engraved/rune line as the rune circle (2 px strokes,
  slightly irregular), rather than material-style icons.

### 16. Low: environment notes
- Wall stone (`S/look_tavern.png`): the albedo's diagonal smears repeat identically on every block,
  the brick pattern in the texture does not line up with the modelled blocks, and the stone goes
  teal (the grade protects 85-200 deg, so any green in stone stays). Rotate/offset UVs per block
  (hash of the block centre) and pull the albedo's green.
- Glowing mushrooms (`S/m_env.png`): unshaded near-white. They outshine enemy eyes at the same
  distance. Drop to about 40% energy and shade the cap's top.
- Not an art issue, but seen twice: the loading warm-up "show" (every kin plus VFX orbs, with HP
  bars) stays standing at spawn in harness runs (`S/look_spawn.png`, the first frame of
  `S/ig_boss_thorn`). Check it is gone in a real boot.

## Per asset

Each entry: what reads now, then the concrete procedural fix. "Shape" fixes go in enemy_body.gd /
kin_look.gd and are re-cached automatically through the GenCache salt.

### Thornwarden (boss, Thorn Henge). Grade: poor
Now: a Leaper at x2 (`S/studio_thornwarden_0|1.png`, `S/m_quad.png` bottom-right).
- From the side, a sausage on four posts.
- The "bark plates" are two rows of nine identical glossy pill-bug segments (enemy_body.gd:605-608).
- The antler crown is two wire-thin beams (radius 0.026 x hs, line 720), smaller in mass than the
  head. It reads as insect antennae.
- The "ember crack through the chest" (lines 610-611) sits under the jaw as a glowing stick, like a
  cigarette.
- The head is small, a Leaper's skull.
- Nothing ties it to a henge, a hedge or thorns except colour.

Make it:
- **A stag-boar of the hedge.** Forequarters 1.4x the hindquarters, the head carried low, a hump
  at the withers. Thick three-segment legs ending in splayed root-toes that grip the ground (and
  cast contact shadows).
- **Head:** a long bone-white deer skull mask over the snout (the focal value), ember eyes deep in
  the sockets.
- **Crown:** recursive antler with 3 branching levels, beam radius about 0.06 x hs, total span
  2.5-3x the head width, with braided bramble wound through it. A bramble mane trails along the
  spine: twisted tube pairs with barbs.
- **Bark:** curved shingles of varying size laid like roof tiles from spine to flank, rough and
  matte (finding 4), with moss and lichen in the green band at the seams.
- **Ember heart:** a vertical split in the sternum between bark plates, lit from inside: emission
  only in the crack, glow brightening in phase 2. Move it from the throat to the chest.
- **Animation:** a heavy walk, the head lowering before the pounce, a rear-up on the hind legs
  with the crown thrown back as the phase-2 roar, dust on landing.

### Bone Abbot (boss, Ossuary pit). Grade: poor
Now (`S/studio_bone_abbot_0.png`, `S/m_abbot_ig.png`, `S/tr_full/f_16|17.png`):
- **Mitre:** two flattened cones front and back, diverging (enemy_body.gd:484-502). From any 3/4
  view they read as rabbit ears.
- **Cassock:** separate black slats with bare feet striding through them (finding 2).
- **Crozier:** hangs from the swinging hand like a cane, pointing down, its hook behind the head
  (lines 506-526).
- **Colour:** in game the bone blooms to a flat blue-white, the eyes and reliquary turn blue.
- **Body:** a scaled Ossuant; the bone armour and the flesh share one value.

Make it:
- **Mitre:** one closed, tall, shield-section hat: front and back plates converging to a single
  peak and joined at the sides. Vertebrae run along the seam, two lappets (ribbons, finding 2) fall
  behind, and one burning sigil sits on the brow.
- **Silhouette:** a tall narrow triangle: mitre peak, broad cope over the shoulders (a skirt-like
  cape from the shoulders, finding 2), cassock to the ground. Rolled hem, torn only at the back.
- **Crozier:** carried vertically with `staff_hold` (finding 10), the hook above the mitre so the
  outline reads crozier + mitre, a small skull at the crook with a candle-gold flame.
- **Reliquary:** a caged lantern with a warm candle-gold core (protected), lighting its own ribs
  from inside. Add an OmniLight3D (about 2 m, no shadows) so the Abbot lights the pit floor and
  itself.
- **Colour:** bone in 3 values (a dirty ivory base, pale highlights, dark cracks), a near-black
  cassock with a gold-thread hem band (emissive thread at low energy).
- **Animation:** slow, upright (hunch 0.1), no twitch, a sway like a swinging censer; the Requiem
  is the `orant` pose with the crozier raised.

### Ascended Warden (boss, summit dais). Grade: poor
Now (`S/studio_ascended_warden_0|1.png`, `S/ig_boss_warden_1.png`):
- A Husk frame at x2.2 inside a hedgehog of violet cones (robe, sleeves, veil are all `strand`
  spikes), with a flat disc for a yoke (enemy_body.gd:291).
- Skeleton legs and ribs show through the gaps.
- Its halo is a dotted ring of sausages with spikes, like barbed wire.
- In game: navy on navy, the halo blue-white.
- It walks with a hunched shuffle and fires its fan with a claw rake.

Make it, the final boss:
- **Silhouette and mass:** it does not walk. A floating bell-shaped robe (finding 2 `skirt`) whose
  hem hovers 0.3 m over the dais, trailing long tatters (ribbons) that drift behind on a slow
  vertex wave. No legs are built at all. Elongated: arms 1.3x, a small head.
- **Mask:** one blank, oval, white-gold mask (warm near-white is protected by the grade). Two slit
  eyes, a hairline crack (the existing crack, made thinner).
- **Halo / mandorla:** a solid thin torus behind the head plus 12-16 radial blades like a sun-wheel,
  rotating slowly. In phase 3 the ring breaks: segments drift apart on tweened offsets and the gaps
  glow. Give it an OmniLight3D (warm-white, no shadow) so the dais is lit by the boss (the handoff
  notes the dais is lit only by the player's lantern).
- **Hands:** long open hands with 4 fingers; `orant` pose for every cast; the blink is a fold into
  the robe, not a rake.
- **Colour:** pale robe (a light value against the dark sky) with gold hem runes; the white-gold
  accent replaces HOLY violet.

### Wretch. Grade: fair
Now (`S/studio_wretch_0|1.png`):
- Good: the hunch, the long hooked claws, the open jaw.
- Bad: straight cylinder legs with rings at the knees, the hair a fan of dark cones, peach-mauve
  skin like the rest, feet as slippers.

Fix:
- Bent knees with a calf mass.
- Hair and shawl as ribbons.
- A darker, near-charcoal skin with a pale face mask, so it reads by its head.
- Toes splayed with claws (it is barefoot and digging in).
- Taper the waist more (gaunt).

### Husk. Grade: fair
Now (`S/studio_husk_0|1.png`):
- Good: the bloat, the stitched seam, the bandages.
- Bad: the glowing belly bulb is the focal point (enemy_body.gd:228); the legs are banded trunks
  like stovepipes; the small head is lost behind the trapezius.

Fix:
- Move the glow into the seam.
- More sag: the belly hangs over the belt, folds overlapping.
- Short thick forearms with heavy hands.
- One dragging foot turned in (it has a limp in the rig).
- Sickly yellow-green skin.

### Spitter. Grade: weak
Now (`S/m_humanoid.png` top-left):
- A stick figure with a flat cyan disc on the chest (spitter.gd:62-68).
- The long forward neck reads, but the body is the thinnest, most mannequin-like of the set.

Fix:
- A membrane throat sac in the flesh shader (finding 9) that visibly swells on the lob windup.
- Crouched, frog-like haunches (it keeps its distance and strafes: give it a sideways crab stance).
- Glands along the spine are good; make them pulse in sequence toward the throat before a spit.

### Crawler. Grade: fair
Now (`S/m_quad.png` top-left): a spider read that works at distance; four eyes and mandibles OK.
Bad: glossy foil chitin, tube legs without joints or feet.

Fix:
- Matte chitin with a lacquered edge only.
- Banded leg joints.
- Leg tips as hooked claws that touch the ground.
- Lower the body between the knees (spiders hang).

### Leaper. Grade: weak
Now (`S/m_quad.png` top-middle, bottom-middle): coffee-table side view (finding 7); body a
sausage; dorsal spines a comb.

Fix:
- Hind hocks and haunches (finding 7), a deep chest and a tucked waist.
- Spines graded large at the shoulders, small to the tail.
- A long, lean, sight-hound skull.
- Ember eyes and an ember belly line.
- Mid-air pose: forelegs reaching, hind legs trailing, already in QuadRig.

### Ossuant. Grade: fair, the best of the humanoids
Now (`S/m_humanoid.png` top-middle): the bone armour reads (skull mask, pauldrons, outer ribs,
fauld). Bad:
- The flesh underneath is the same peach as the bone, so armour and body merge.
- The head spikes read as a punk crown.
- Its violet eyes go blue in game.

Fix:
- Dark, dried-husk flesh under bright bone (value split).
- Spikes swept back like a helm crest.
- Eyes candle-gold or pale green.
- The "heap" state (ossuant.gd:73-77) should drop the bones as separate pieces, not tip the rig over.

### Bulwark. Grade: fair
Now (`S/m_humanoid.png` top-right): helm and pauldrons OK. The door-shield is a picket fence with
gaps between the planks (kin_look.gd:150-155) and is narrower than the body.

Fix:
- Planks edge to edge (no gaps), one taller than the others, scorched.
- Three iron bands with rivets (already), a dented boss.
- 1.3x wider, so it covers 70% of the front: the shield IS the silhouette.
- Shield-on-ground idle pose.

### Chanter. Grade: fair
Now (`S/m_humanoid.png` bottom-left): the green light reads, and that hue is protected. Bad:
- The hood is a tall dunce cone (kin_look.gd:212-213).
- The robe is rods (finding 2).
- It shares the wanderer's silhouette (finding 11).

Fix:
- A deep cowl jutting forward over a bone-thin face.
- A skirt robe hitched and torn.
- The staff held low and forward with a swinging censer-cage.
- More hunch.

### Burrower. Grade: weak
Now (`S/c_burrower.png`): the "shovel claws" are round cones plus a squashed blob that reads as a
mushroom cap or a pancake at the foot (kin_look.gd:258-263). The carapace is foil bubbles.

Fix:
- Spatulate claws: three flattened claws (squash 0.25 across) fanned into a spade, with a
  keratin edge.
- An earth crust as matte, irregular clods with soil stuck in the plate seams.
- An eyeless ridged snout (already). The amber glow should leak from under the carapace rim, not
  sit on top.

### Mite. Grade: good
Now (`S/studio_mite_0.png`): a swarm of teal lights reads exactly as designed, and teal is
protected. Only: matte its chitin and make the sac pulse out of phase across the swarm.

### Shade
Not reviewed for change: the owner rejected rewrites of the shade (umbral-donts). Leave it.

### Wanderer (player)
Not for change (umbral-donts). For reference: it reads as a navy robe with a cool rim and a bright
orb. The enemy fixes above (value keys, protected accents, no robed staff silhouettes) keep it the
only figure of its kind in the frame.

### Wildlife
creature.gdshader animates one smooth mesh per creature in the vertex shader, with a low rim
(0.12 x) and proper horn/eye channels. It is technically the cleanest creature pipeline in the
project: the enemies should learn from its single-mesh approach (finding 6). Minor: the white hart
was fixed by D in r29.

## Top 10 to do first

1. Give the three bosses their own builders (Thornwarden stag-boar with a big antler crown, Abbot
   with a closed mitre and an upright crozier, Warden floating with a bell robe and a mandorla), not
   `embiggen` on a grunt. (Findings 1 and 3a; the per-asset recipes.)
2. Add `CreatureMesh.skirt()` and `ribbon()`, and rebuild every robe, veil, sleeve, hair and rag
   with them. Drive the hems from hip/knee like robe_skin. (Finding 2)
3. Move enemy and boss accents into the grade's protected bands (candle-gold, white-gold, ember,
   green-teal) and drop violet. Or the lead protects bright saturated violet. (Finding 3)
4. Split flesh.gdshader roughness/specular per material (bark, bone, dry skin, wet), and halve the
   normal strength. (Finding 4)
5. Replace the unlit violet rim with a lit, low, warm back-rim. (Finding 5)
6. Overlap joints now; then bake enemies into one skinned mesh like wanderer_body.gd. (Finding 6)
7. QuadRig hind hocks, front/rear heights and real feet: the Leaper and the Thornwarden stop being
   tables. (Finding 7)
8. Bosses: `detail_tile / scale`, about x1.6 tessellation, `anim_rate = 1/sqrt(scale)`, no twitch,
   and `orant` / `staff_hold` / `float` poses. (Findings 1 and 10)
9. A value and colour key per family, darkest to brightest; bosses own the extreme value in their
   arena. Give the Abbot and the Warden their own lights. (Finding 8)
10. Glow through form: the spitter's sac membrane, the husk's seam, and the boss spikes as
    bone/bramble clusters, not white cones. (Findings 9 and 14)

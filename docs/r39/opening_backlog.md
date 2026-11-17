# Opening / progression / systems backlog (resume file)

Tick as done. Branch r39-opening. Rules: no Godot, lint clean, small commits, no attribution.

- [x] 1 Opening: title card + music cue, narration to new canon, first-steps flow into first fire, post-ending New Game variant
- [x] 2 Horses (whistle, care, tack, bags, courier, race all done): run-to-you whistle, saddlebags + stash UI, courier runs + best-time board, race at Hearthward, stable upgrades, mounted interact/kindle, horse care tied to bond
- [x] 3 Map (filters + trail + marks + folding + charcoal sketch + inked landmarks + landmark names through the placer done): charcoal reveal, landmarks inked when seen, discovery banners, legend + filters, label de-collision, controller cursor
- [x] 4 Death and return: embers to recover, toll at the fire, return sequence
- [x] 5 Progression (vows, curve, Long Ledger, gear-gap hint, enemy plates all done): level-up choices (perks per path), skill/gear vs danger review, recommended levels everywhere, endgame loop (Deeper Night)
- [x] 6 Night summary screen + ending credits reading the Chronicle
- [x] 7 Fast-travel network UI + bell/peal tracking in the journal
- [x] 8 Accessibility (shake/flash/subtitles/palette, presets, remap parity: triggers + protected menu buttons) and settings
- [x] 9 UX pass across menus/HUD (Count pad paging, Gear pad shortcuts, device-aware footers, remap parity)
- [x] 10 Save migrations + corrupted-save fallback
- [x] 11+ remaining critique items (section 34 of opening_systems.md: done, answered, or routed)

## Cross-team needs (the lead routes these)
- **Animation / light seat**: a rider body (or the wanderer's rig in a plain cloak) for the three race rivals (`core/world/mount/horse_race_field.gd` builds three riderless horses; a rider would parent to the rig the way `Horse._claim_visual` does). Gate dressing for the race: pairs of lantern posts at each gate as emissive cards in the existing far-glow MultiMesh, no new lights (gates are chosen at run time by `horse_race.gd` `_lay`; ask me for a baked list once the lead has ridden the courses and picked fixed gates).
- **Sound seat**: named hooks to fill. Race: herald beat ticks (`UiSound` "tab" x3 and "quest_new" at GO, in `horse_race.gd` `_countdown`), gate pass ("confirm"), finish and place (none yet), crowd on the green. Ledger: a posting sound and the rank chime (`long_ledger.gd` uses "quest_done"). Map: a charcoal-stroke scratch when the sketch opens (none). Replace `UiSound.play(self, kind)` calls with the seat's own kinds.
- **Story seat**: lines for Fennick's race ritual (`horse_race_data.gd` HERALD, WON, PLACED, LATE, FALSE_START, OUT are placeholders in the game's voice, written here: replace freely); a ledger-keeper at the Keg who reads the Long Ledger aloud and names the ranks (`long_ledger_data.gd` RANK_LINES); the Hearthward Cup as a mention in the Keg's talk; quest lines that point a wanderer at the stable and the Race page.
- **World seat**: a ledger board prop at the Keg's door (interaction can open the Count's fourth page: `TallyPanel` page 3); a start line and bunting at the Hearthward rail; confirm open ground within 150 m of the palfrey post (the races' gates are laid there).
- **Flashes that do not yet multiply by `Access.flash()`** (Reduce Flashes sets it to 0.25; only the photo shutter, `core/story/photo_mode.gd:198`, uses it). To route, each should multiply its peak alpha, energy or colour overshoot by `Access.flash()`:
  - Lightning, sky: `core/life/wildlife/weather.gd:731` (`CloudFlash` shader `flash`, value `f`), `:732` (bolt mesh `flash`), `:1008` and `:1012` (the cloud veil's `flash * _flash_gain`), and the ambient surge `:285` (`flash * OFF_AMBIENT_FLASH * _flash_gain`); the per-strike gain is set at `:750` and `:782`, the simplest single place is to fold `Access.flash()` into `_flash_gain` there. Local cloud flashes: `_cloud_flash`, `:814`.
  - Enemy hit flash: `core/enemy/enemy.gd:1868` (`hit_flash` shader parameter `_hit_fx`), and the telegraph squash/brighten from `_flash` at `:1872` (scale `1.0 + _flash * 0.4`).
  - Boss bar phase flash: `core/world/boss_arena.gd:76` (`_flash`, set at `:64`) drawn at `:85` and `:91` as an overshoot to Color(1.6, 0.9, 1.8) and (1.6, 1.0, 2.0); the callers are `:160` and `:164`.
  - Hit and impact stars: `core/vfx/vfx.gd:610` calling `_flash_star` (`:633`), an unshaded additive quad in the hit's colour; scale the colour alpha.
  - Spell muzzle and bolt lights: `core/player/magic_bolt.gd:337` (`flash.light_energy = 2.4`, tween to 0 at `:340`), and the bolt light energies at `:188`, `:235`, `:270`.
  - Level-up burst: `core/life/progression/hearth.gd:270` `_ding` (a 60-mote burst in Color(2.4, 1.7, 0.8): scale the colour and the count).
  - Objective line pulse on a new line: `core/story/objective_line.gd:176` `_flash` (modulate overshoot to Color(1.4, 1.1, 0.8)).
  - Stamina meter flash: `core/player/stamina.gd:107` `flash()` read by `ui/breath_meter.gd:44`; and the skill bar's cooldown flash, `core/skills/skill_book.gd:517` `flash(i)`; the Kindling card flash, `ui/growth_card.gd:32` (`var flash`).
  - The glade secret's flash, `core/life/secrets/site_glade.gd:203` `_flash(idx)`.
  - Search was by name ("flash", "lightning", "hit_flash"); a shader that pulses without the word (fire kindle burst, ward pulse, boss-intro white-out) should be checked by the light/animation seat against `Access.flash()`.
- **Enemy / VFX seat**: route telegraph colours through `Access.telegraph(color)` and flash alpha through `Access.flash()` (open since the Comfort settings).
- **Lead**: first-import risks, in order: (1) new `class_name`s (`HorseRace`, `LongLedger`, `MapSketch`, `FeatureTips`) need the editor's import pass to register; (2) new `.uid` files will be created for the new scripts; (3) `ui/world_map_shaders.gd` FOG_SHADER gained a `sketch_tex` sampler (set in `Landmarks.attach` when the map opens); (4) `horse.gd` gained `rival` and `stables.gd` builds three parked rivals (check the loading-screen time).

## Not done / next
- A rider body for the rivals, gate dressing, race sounds (cross-team, above).
- A ledger board prop at the Keg (cross-team).
- Everything must be run: nothing in sections 27 to 34 has been executed.

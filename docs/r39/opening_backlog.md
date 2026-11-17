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
- **Enemy / VFX seat**: route telegraph colours through `Access.telegraph(color)` and flash alpha through `Access.flash()` (open since the Comfort settings).
- **Lead**: first-import risks, in order: (1) new `class_name`s (`HorseRace`, `LongLedger`, `MapSketch`, `FeatureTips`) need the editor's import pass to register; (2) new `.uid` files will be created for the new scripts; (3) `ui/world_map_shaders.gd` FOG_SHADER gained a `sketch_tex` sampler (set in `Landmarks.attach` when the map opens); (4) `horse.gd` gained `rival` and `stables.gd` builds three parked rivals (check the loading-screen time).

## Not done / next
- A rider body for the rivals, gate dressing, race sounds (cross-team, above).
- A ledger board prop at the Keg (cross-team).
- Everything must be run: nothing in sections 27 to 34 has been executed.

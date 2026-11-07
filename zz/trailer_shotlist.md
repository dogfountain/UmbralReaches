# Umbral Reaches: action trailer, shot list

Directed in `zz/trailer.gd` (the sequencer), cast in `zz/trailer_shots_*.gd`, helpers in `zz/trailer_cam.gd`.
Camera styles: GAME (the game's own camera), TOP (fixed north-up at 55-65 deg), FP (true first person), CIN (slow, collision-checked, eased).
Render a shot alone: `--shot=<id>` or `--shots=a,b`; list them: `--list`. `tools/trailer.sh` renders and assembles.

## Feature inventory (what the cut must show)

Spells: Rift Bolt (Lash), Ember Lance (charge, Perfect), Umbral Nova (Marks), Lantern Ward, Rift Step; learned: Tether, Umbral Well, Familiar; ranks and the three oaths (Kindling).
Gear and the painted icon set, the medieval spell bar, the character screen. Staff arts (heavy blow, parry).
Horses: palfrey, garron, fen pony, draught, weir cob; mount, gallop, jump, dismount.
Regions: Hearthward, Thornwood, Henge, Crypt/Ossuary, Necropolis, Mere, Foundry, Orchard, Quarry, Moor, Holds, Summit and the Crowns; Marches: Weirford, Sorrow, Fallen Hierarch, Siege Lines, Stillwater and the Lamp Spire, Anchorholds, Saltmarket, White Pans; Southern Downs, Grandmother Oak, Well of Echoes.
Bosses: Bone Abbot (Tallies, Requiem), Thornwarden (heart-knot intermission), Ascended Warden, Anchoress, Hierarch's Voice; the Shutter and the seven other bell keepers; slowed killing blow.
The eight bells, escort and defend steps, the Hearth and the ash tithe, Gloom and the Shade, kindled lamps and fires, weather (storm, mist, rain), wildlife (plover flock, herds), villagers and stalls, map and minimap and compass, loot beams and bags, the Keg, world events, traversal (vault, ledge-grab, wall-kick, double jump, slide).

## Cut (id, style, seconds, what happens). Fade = short cross-fade into the next clip.

### Act I: the last fire (about 17 s)
| # | id | style | s | what |
|---|----|-------|---|------|
| 1 | cold | CIN | 1.4 | black, THE SKY TURNS INWARD, crane over the green (kept) |
| 2 | village | CIN | 2.4 | Hearthward at night: villagers and market stalls, a slow dolly through the square |
| 3 | tavern | CIN | 1.4 | the Keg breaks into song (kept) |
| 4 | run_game | GAME | 1.8 | sprint up the road, double jump (kept) |
| 5 | spellbar | GAME | 2.2 | HUD on: painted spell bar, minimap, compass; Rift Bolt fired from the run |
| 6 | hearth_tithe | UI | 1.8 | the Hearth tab: grave ash, the tithe |
| 7 | kindling | UI | 2.0 | the Kindling: spell ranks and the oaths |
| 8 | gear | UI | 1.8 | the character screen, painted gear icons |

### Act II: what climbs comes down hollow (about 33 s)
| 9 | card_dark | CARD | 0.8 | WHAT CLIMBS COMES DOWN HOLLOW (kept) |
| 10 | fight_otc | GAME | 3.0 | bolts into the pack, the Lash, an Ember Lance thrown (kept) |
| 11 | fp_lance | FP | 2.0 | the lance drawn in first person (kept) |
| 12 | fight_top | TOP | 3.0 | top-down brawl: Nova detonates Marks, Rift Step out of the press (kept) |
| 13 | spell_ward | CIN | 2.2 | Lantern Ward flares, foes thrown back off its edge |
| 14 | spell_arcana | TOP | 2.4 | Umbral Well drags the pack in, the Familiar fights, Tether |
| 15 | gloom_shade | GAME | 2.4 | walking out of the light: Gloom closes, the Shade hunts |
| 16 | loot | CIN | 2.2 | a foe falls, the loot bag and its beam, the wanderer takes it |
| 17 | fight_side | CIN | 2.6 | side-on two-shot fight (kept) |
| 18 | vault | CIN | 1.6 | vault over a low wall (kept) |
| 19 | grab | CIN | 2.0 | ledge grab and climb (kept) |
| 20 | fp_run | FP | 1.6 | first-person run, jump, slide (kept) |
| 21 | storm | CIN | 1.8 | the storm: forked lightning over the open road (kept) |
| 22 | rain_mist | CIN | 1.6 | drizzle then mist rolling over the moor |
| 23 | wildlife | CIN | 1.5 | plover flock lifts (kept) |

### Act III: the realm widens (about 45 s)
| 24 | card_realm | CARD | 0.8 | THE REALM WIDENS |
| 25 | horse_mount | CIN | 2.0 | the Pilgrim's Palfrey: step, stirrup, swing over |
| 26 | horse_gallop | GAME | 2.4 | gallop west along the road, the game's camera |
| 27 | horse_jump | CIN | 1.6 | a leap, side-on, mid-gallop |
| 28 | horse_breeds | CIN | 2.0 | all five breeds in a line, the lens passes along |
| 29-37 | thornwood, necropolis, mere, foundry, orchard, quarry, moor, holds, crowns | CIN | 1.1-1.3 each | the old Realm in a run of slow vistas |
| 38 | lamp_kindle | CIN | 2.0 | Weirford bridge: the wanderer lights the lamp (warmth earned) |
| 39 | weirford | CIN | 1.8 | the mill and the weir, villagers on their rounds |
| 40 | stillwater | CIN | 1.4 | the cold lake under the Lamp Spire |
| 41 | lamp_spire | FP | 1.8 | climbing the beacon tower |
| 42 | anchorholds | CIN | 1.4 | hermit cells cut into the cliff |
| 43 | hierarch | CIN | 1.6 | the toppled Hierarch, a hill of stone |
| 44 | siege | CIN | 1.3 | the siege lines |
| 45 | saltmarket | CIN | 1.2 | the salt hamlet |
| 46 | pans | CIN | 1.2 | the White Pans |
| 47 | oak | CIN | 1.4 | the Grandmother Oak |
| 48 | well | CIN | 1.6 | the Well of Echoes |
| 49 | bells | CIN | 2.0 | a bell of the eight, its keeper (the Shutter) at the Spire's foot |
| 50 | escort | GAME | 2.0 | the escort step: the ferry passenger walks with the wanderer |
| 51 | defend | TOP | 2.2 | the defend step: waves at the graft |
| 52 | map | UI | 1.6 | the world map with its pins |
| 53 | roam | CIN | 1.6 | a world event: a procession on the road |

### Act IV: descend (about 24 s)
| 54 | card_depths | CARD | 0.8 | DESCEND (kept) |
| 55 | thorn_reveal | CIN | 2.2 | the Thornwarden wakes in the henge |
| 56 | thorn_knots | TOP | 2.2 | the heart-knot intermission: three knots to burn |
| 57 | boss_reveal | CIN | 2.4 | the Bone Abbot turns (kept) |
| 58 | boss_game | GAME | 2.4 | the fight on the game's camera (kept) |
| 59 | boss_wide | CIN | 2.4 | the Requiem from the corner (kept) |
| 60 | warden | CIN | 2.0 | the Ascended Warden rises over the summit deck |
| 61 | anchoress | CIN | 2.0 | the Anchoress swings her anchor |
| 62 | hierarch_voice | TOP | 2.2 | the Speaking Crown's edict |
| 63 | final_blow | CIN | 2.8 | a boss falls: the killing blow in slow motion |

### Finale (4.5 s)
| 64 | finale | CIN | 4.5 | the wanderer small against the valley, the camera tilts to the vortex, UMBRAL REACHES (kept) |

Total at these lengths is about 125 s; the assembly trims trailing frames of montage shots to land near 110 s.

## Not shown
(see the report; anything cut for cause is listed there)

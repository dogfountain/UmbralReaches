# Twelve one-time quests (r38)

Luke, 14 Nov 2026: "there's too little content in the game." Twelve authored, one-time stories in the Outer
Marches and the Southern Downs, built only from systems that exist (quest step kinds, pickups, lamps, secrets,
named rares and elites, escort and defend). None repeats; the five dailies are untouched. Data:
`core/story/quest_chains_r38_east.gd`, `_south.gd`, `_west.gd`, listed in `quest_chains.gd` under `# --- tales ---`.
Test: `zz/quests_r38_test.tscn`.

Two small engine hooks, both in `core/story`: a quest with `found_at` / `found_r` is offered by nobody and starts when
the wanderer walks up to its body or grave (`quest_world.gd`, `_found`); a quest with `stands` leaves a prop standing
where it ended, and `found_prop` marks where a found quest begins. The hauler's tally is a choice (a pickup's conversation,
as the Founder's bells are).

| Quest | Giver / turn-in | Where | Steps | The turn | Reward |
|---|---|---|---|---|---|
| What the Hauler Carried (FOUND) | Pip | body at the Brine Road's end, the crust, the strongroom | letter from the body; open the clerk's strongroom (valves); take the tally, whole or torn; hand in | the hauler did not run: he counted what the Order took, and Marl signed for it | 22 ash, relic fragment, gear |
| The Last Good Pan | Nella Crake | Saltmarket to the second pan field | seed-salt; carry it (60 s); defend the pan 70 s; hand in | the rakers never meant to trample it; they wait to be told it is done | 24 ash, relic fragment, gear |
| Orrin's Barrel (horse) | Orrin Vail; Dorrit Marl | Saltmarket, the road, both gates, the Grey Heron | clear 3 of the road's hollowed; take the keg; carry it across the Marches (75 s); hand in | the "salt" is Maud Vail's ashes, owed three nights at the Heron | 26 ash, ember shard, gear |
| The Bitter Mother | Teasel Dray | drying shed, Pump Tower, the pans | take the first brine-wife's skimmer; read the marks on the Pump Tower; put the Brine-Wife to rest (elite); lay the skimmer; hand in | not mad: she shut a gate on the tithe-gang and stayed to keep it shut | 30 ash, relic fragment, ember shard, gear (r3) |
| The Drover's Tally (FOUND, ride) | Dunstan Pike | body on the downs, Wat's fold by the Flint-Hound's round | tally-stick; look at the fold's gate; put down the Flint-Hound; hand in | Wat did not run; he stayed, and the hound keeps his fold shut | 24 ash, relic fragment, gear |
| The Long Round (both gates, horse) | Old Fennick | the Pilgrims' Road, either side of both gates | kindle the road-lantern inside the West Gate; beyond it; beyond the East Gate; look at the fallen gate lantern; hand in | Fennick shut the gate himself, on the Warden's word, and has lit the road for those he shut out | 28 ash, ember shard, gear |
| Iron for the Hundred and Two | Bryn Gale | Weirford forge to the war-band's grave in the Siege Lines | take the hot tags; carry (55 s); set them on the grave; put down Captain Varr (elite); hand in | 103 tags: the extra is Bryn's own, made for a muster he did not go to | 32 ash, 2 relic fragments, gear (r3) |
| Gran Ide's Lantern | Wren | siege_track from the bridge to the palisade gate | escort Gran Ide; kindle the gate-post lantern; defend the lamp 45 s; hand in | Gran cooked for the Lines; the last order was to light the gate, and she went in instead | 26 ash, relic fragment, gear |
| A Lamp for the Palm (FOUND, route) | Tolliver | mason's grave under the Empty Plinth to the Fallen Hierarch's hand | lamp from the grave; carry it south along the haul (65 s); set it in the palm; hand in | the palm always faced up and nothing was ever put in it | 30 ash, relic fragment, ember shard, gear (r3) |
| The Cutters' Pledge | Jory Quell | the Saints' Quarry | clerk's roll; put down 5 cutters at work; find the cutters' nook; hand in | the cutters struck; Jory alone cut the last step | 26 ash, relic fragment, gear |
| A Staff for Each | Sister Agathe | south track, oss_lane, the Pilgrims' Landing, the ranks | gather 3 staves; put back 4 risen at the Landing; set staves at the ranks; hand in | the pilgrims were told to leave their staves "for the bridge"; they were not turned back | 26 ash, relic fragment, gear (r3, Tally set) |
| Three Niches | Ysolt | the Lanternless Moor | kindle the south niche; defend the middle niche 45 s; kindle the north niche; read its name; hand in | the north niche carries Ysolt's own name, cut ready | 28 ash, ember shard, gear |

Found in the world: What the Hauler Carried, The Drover's Tally, A Lamp for the Palm. Horse or a route not otherwise
taken: Orrin's Barrel, The Drover's Tally, The Long Round, A Lamp for the Palm. End at or pass a boss's ground without the boss:
Iron for the Hundred and Two and Gran Ide's Lantern (the Siege Lines ring), A Lamp for the Palm (the Hierarch's hand),
A Staff for Each (the Ossuary's Landing).

Near Saltmarket (being rescaled): Pip, Nella, Orrin, Teasel and the seed, barrel and skimmer pickups (they follow Marl's fire).
Near an outpost: Ysolt, Jory, Agathe; Weirford: Bryn, Wren, Tolliver, Dorrit.

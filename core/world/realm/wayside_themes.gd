extends RefCounted
## The wayside's data (realm_wayside.gd plans, wayside_kit.gd builds): what kinds of small places stand between the
## landmarks, which of them each region favours, and the named ones a region keeps (Luke, 15 Nov: "increase the world's
## density ... something worth walking to always in view"). Pure data. Load by path:
##   const Themes := preload("res://core/world/realm/wayside_themes.gd")

## kind -> how it is planned:
##   r      footprint radius (m): the ground it needs clear of ways, sites and camps
##   rise   the most the ground may rise across that footprint (m)
##   ctx    where it may stand: "way" (beside a way, read from it), "open" (off the ways), "wood" (in a clearing it cuts)
##   glade  the clearing (tree-free radius, m) it asks for in a wood (RealmFlora.tree_clear)
##   tall   elsewhere, the tree-free radius a tall place keeps (no crown through a cross, a saint, a chimney)
##   wet    stands at a shore with water in front (jetties)
##   note   can be one of a region's named places (a discovery); cache: can hold a box; lore: carriers it can host
##   creep  plants the flora grows round it (flora_layers.gd): [species, count, inner, outer] in m from its middle
const KINDS := {
	"wall": {"r": 6.5, "dress": true, "rise": 1.6, "ctx": ["way", "open"], "glade": 0.0, "lore": ["rune"],
		"creep": [["bramble", 3, 2.0, 7.0], ["tallgrass", 10, 1.0, 7.5], ["fern", 3, 1.5, 6.0]]},
	"fold": {"r": 5.6, "dress": true, "rise": 1.0, "ctx": ["open"], "glade": 0.0, "note": true, "cache": true,
		"creep": [["bramble", 4, 4.2, 6.5], ["flowers", 6, 0.0, 3.0], ["tallgrass", 8, 4.0, 7.0]]},
	"cottage": {"tall": 4.5, "r": 5.2, "rise": 0.9, "ctx": ["open", "wood", "way"], "glade": 9.5, "note": true, "cache": true, "lore": ["page"],
		"creep": [["bramble", 5, 1.5, 5.5], ["fern", 6, 3.0, 7.0], ["tallgrass", 10, 0.5, 6.5], ["shrub", 1, 4.0, 7.0]]},
	"shrine": {"tall": 2.5, "r": 2.6, "dress": true, "rise": 0.7, "ctx": ["way", "open", "wood"], "glade": 6.0, "note": true, "lore": ["rune", "notice"],
		"creep": [["flowers", 7, 1.2, 3.6], ["tallgrass", 4, 1.5, 4.0]]},
	"stones": {"tall": 2.5, "r": 3.2, "dress": true, "rise": 1.4, "ctx": ["open", "way", "wood"], "glade": 6.0, "note": true, "lore": ["rune"],
		"creep": [["heather", 5, 0.8, 4.0], ["tallgrass", 5, 0.8, 4.0], ["fern", 2, 1.0, 3.5]]},
	"circle": {"tall": 6.5, "r": 7.2, "rise": 1.2, "ctx": ["open", "wood"], "glade": 10.0, "note": true, "cache": true, "lore": ["rune"],
		"creep": [["flowers", 10, 0.0, 4.6], ["heather", 8, 6.6, 9.0], ["tallgrass", 6, 6.5, 9.0]]},
	"cairns": {"r": 4.4, "dress": true, "rise": 2.4, "ctx": ["open", "way"], "glade": 0.0, "note": true, "cache": true,
		"creep": [["heather", 6, 0.5, 5.0], ["tallgrass", 4, 0.5, 5.0]]},
	"cart": {"r": 3.6, "dress": true, "rise": 0.8, "ctx": ["way"], "glade": 0.0, "note": true, "cache": true, "lore": ["page"],
		"creep": [["tallgrass", 8, 0.5, 4.5], ["flowers", 2, 1.0, 4.0]]},
	"camp": {"r": 4.6, "rise": 0.8, "ctx": ["open", "wood", "way"], "glade": 8.5, "note": true, "cache": true, "lore": ["page"],
		"creep": [["tallgrass", 6, 4.0, 7.0], ["fern", 4, 4.0, 7.5]]},
	"well": {"r": 3.6, "rise": 0.7, "ctx": ["way", "open"], "glade": 0.0, "note": true,
		"creep": [["flowers", 5, 2.0, 4.5], ["moss", 6, 1.5, 3.5], ["tallgrass", 5, 2.5, 5.0]]},
	"graves": {"r": 4.6, "dress": true, "rise": 0.9, "ctx": ["open", "way", "wood"], "glade": 7.5, "note": true, "lore": ["grave"],
		"creep": [["tallgrass", 4, 3.0, 6.0], ["flowers", 6, 0.5, 5.0], ["bramble", 2, 4.0, 6.5]]},      # (tall grass among the stones hid them)
	"woodpile": {"r": 3.6, "dress": true, "rise": 0.8, "ctx": ["wood", "way", "open"], "glade": 6.5, "cache": true,
		"creep": [["litter", 6, 0.5, 4.5], ["fern", 4, 2.5, 5.5]]},
	"statue": {"tall": 2.5, "r": 3.2, "dress": true, "rise": 0.8, "ctx": ["way", "open", "wood"], "glade": 6.0, "note": true, "lore": ["notice"],
		"creep": [["bramble", 2, 1.5, 4.0], ["tallgrass", 6, 1.0, 4.5], ["moss", 4, 0.5, 2.5]]},
	"blocks": {"r": 5.0, "dress": true, "rise": 1.0, "ctx": ["open", "way"], "glade": 0.0, "note": true, "cache": true,
		"creep": [["tallgrass", 8, 0.5, 6.0], ["bramble", 2, 1.0, 5.0], ["moss", 4, 0.5, 4.0]]},
	"lookout": {"tall": 6.0, "r": 4.2, "rise": 1.4, "ctx": ["open"], "glade": 9.0, "note": true, "cache": true,
		"creep": [["bramble", 3, 3.0, 6.0], ["tallgrass", 6, 3.0, 6.5]]},
	"battle": {"r": 5.2, "rise": 1.4, "ctx": ["open", "way"], "glade": 0.0, "note": true, "cache": true, "lore": ["grave"],
		"creep": [["tallgrass", 8, 0.0, 6.0], ["heather", 4, 0.0, 6.0]]},
	"debris": {"r": 5.0, "dress": true, "rise": 3.0, "ctx": ["open", "way"], "glade": 0.0, "note": true,
		"creep": [["deadbush", 4, 1.0, 6.0], ["cinders", 6, 0.0, 5.0], ["ashdrift", 4, 0.0, 6.0]]},
	"barrow": {"r": 5.4, "dress": true, "rise": 1.2, "ctx": ["open"], "glade": 8.0, "note": true, "cache": true, "lore": ["rune"],
		"creep": [["heather", 10, 3.8, 7.0], ["tallgrass", 6, 3.5, 7.0], ["flowers", 3, 0.0, 2.5]]},
	"charcoal": {"r": 4.4, "dress": true, "rise": 0.9, "ctx": ["wood", "open"], "glade": 8.0, "note": true, "cache": true,
		"creep": [["litter", 6, 2.5, 6.0], ["fern", 6, 4.5, 7.5]]},
	"farm": {"r": 6.0, "dress": true, "rise": 1.0, "ctx": ["open", "way"], "glade": 0.0, "note": true,
		"creep": [["tallgrass", 12, 0.0, 7.0], ["flowers", 6, 0.0, 7.0]]},
	"milestone": {"r": 1.3, "rise": 0.6, "ctx": ["way"], "glade": 0.0, "lore": ["waystone"],
		"creep": [["tallgrass", 4, 0.6, 2.2], ["flowers", 2, 0.6, 2.0]]},
	"jetty": {"r": 3.0, "dress": true, "rise": 1.0, "ctx": ["open", "way"], "glade": 0.0, "wet": true, "note": true, "cache": true,
		"creep": [["reeds", 8, 1.5, 6.0], ["cattail", 4, 1.5, 5.0]]},
	"lowwall": {"r": 6.0, "dress": true, "rise": 1.2, "ctx": ["way", "open"], "glade": 0.0,
		"creep": [["bramble", 3, 1.5, 6.0], ["tallgrass", 8, 0.5, 6.5], ["fern", 2, 1.0, 5.0]]},
	"marker": {"r": 2.8, "dress": true, "rise": 0.9, "ctx": ["way", "open", "wood"], "glade": 5.0,
		"creep": [["tallgrass", 5, 0.5, 3.5], ["flowers", 3, 0.5, 3.0]]},
	"stele": {"tall": 2.5, "r": 2.6, "dress": true, "rise": 0.8, "ctx": ["way", "open", "wood"], "glade": 5.5, "note": true,
		"creep": [["tallgrass", 5, 0.8, 3.5], ["moss", 3, 0.5, 2.0], ["fern", 2, 1.0, 3.5]]},
	"pier": {"r": 3.6, "dress": true, "rise": 1.0, "ctx": ["open", "wood", "way"], "glade": 5.5,
		"creep": [["bramble", 2, 1.0, 4.0], ["fern", 3, 1.0, 4.0], ["tallgrass", 4, 0.5, 4.0]]},
	"ruinshrine": {"tall": 4.5, "r": 4.2, "dress": true, "rise": 0.9, "ctx": ["way", "open", "wood"], "glade": 8.0, "note": true, "cache": true, "lore": ["rune"],
		"creep": [["bramble", 3, 2.0, 5.5], ["fern", 4, 2.0, 6.0], ["tallgrass", 6, 1.5, 6.0], ["flowers", 3, 2.0, 5.0]]},
	"drowned": {"r": 3.6, "dress": true, "rise": 3.0, "ctx": ["open"], "glade": 0.0, "sunk": true,
		"creep": [["reeds", 6, 3.0, 6.5], ["lily", 6, 2.5, 7.0]]},
	"bones": {"r": 4.2, "dress": true, "rise": 2.2, "ctx": ["open"], "glade": 0.0, "note": true,
		"creep": [["tallgrass", 6, 0.0, 5.0], ["deadbush", 1, 1.0, 4.0]]},
}

## Region id -> the kinds it favours, by where they stand. A region not listed falls back to its biome.
const REGIONS := {
	# --- the Far Reaches -------------------------------------------------------------------------
	"greyfell": {"way": {"milestone": 2, "cairns": 2, "battle": 2, "shrine": 1, "wall": 1},
		"open": {"battle": 3, "cairns": 3, "stones": 1, "wall": 2, "bones": 2, "lookout": 1, "camp": 1}},
	"lanternwood": {"way": {"shrine": 2, "milestone": 1, "camp": 1, "stones": 1, "woodpile": 1, "stele": 1},
		"open": {"stones": 2, "shrine": 2, "camp": 1, "graves": 1, "cottage": 1, "woodpile": 1},
		"wood": {"stones": 2, "shrine": 2, "camp": 1, "graves": 1, "cottage": 1, "circle": 1, "ruinshrine": 1, "pier": 1}},
	"kingsbarrows": {"way": {"milestone": 2, "stones": 2, "graves": 1, "cairns": 1},
		"open": {"barrow": 4, "stones": 3, "circle": 1, "graves": 1, "cairns": 1, "wall": 1, "lookout": 1}},
	"reedmere": {"way": {"milestone": 1, "graves": 1, "cart": 1, "shrine": 1},
		"open": {"jetty": 3, "graves": 1, "stones": 1, "camp": 1, "cottage": 1, "drowned": 2, "marker": 1}},
	"fallow": {"way": {"cart": 2, "milestone": 1, "well": 1, "wall": 2, "farm": 1, "graves": 1},
		"open": {"farm": 3, "wall": 3, "graves": 2, "well": 1, "cottage": 2, "fold": 1, "lowwall": 2, "marker": 1}},
	"arches": {"way": {"blocks": 2, "statue": 1, "milestone": 1, "cart": 1, "shrine": 1},
		"open": {"blocks": 3, "statue": 1, "wall": 2, "cottage": 1, "camp": 1, "well": 1, "lookout": 1, "pier": 2, "stele": 1}},
	"southwood": {"way": {"woodpile": 2, "camp": 1, "shrine": 1, "cart": 1, "milestone": 1},
		"open": {"charcoal": 3, "woodpile": 2, "camp": 2, "stones": 1, "graves": 1, "shrine": 1},
		"wood": {"charcoal": 3, "woodpile": 3, "camp": 2, "stones": 1, "graves": 1, "shrine": 1, "cottage": 1}},
	"bellfall": {"way": {"debris": 2, "cairns": 1, "milestone": 1, "battle": 1},
		"open": {"debris": 4, "bones": 2, "cairns": 1, "battle": 1, "lookout": 1}},
	"lastlight": {"way": {"graves": 2, "milestone": 2, "cart": 2, "shrine": 1, "well": 1},
		"open": {"graves": 1, "camp": 2, "wall": 2, "well": 1, "farm": 1, "cottage": 1, "lowwall": 1, "marker": 1}},
	"nave": {"way": {"statue": 2, "blocks": 2, "milestone": 1, "shrine": 1},
		"open": {"blocks": 3, "statue": 3, "graves": 1, "jetty": 1, "camp": 1, "cottage": 1, "drowned": 2, "ruinshrine": 1}},
	"cairns": {"way": {"cairns": 4, "milestone": 1, "stones": 1, "shrine": 1},
		"open": {"cairns": 6, "stones": 2, "circle": 1, "bones": 1, "camp": 1, "lookout": 1}},
	# --- the Outer Marches and the downs ------------------------------------------------------------
	"downs": {"way": {"milestone": 1, "cart": 1, "wall": 1, "cairns": 1},
		"open": {"fold": 3, "wall": 2, "stones": 1, "barrow": 1, "well": 1, "cairns": 1, "bones": 1, "marker": 1}},
	"sorrow": {"way": {"shrine": 1, "camp": 1, "woodpile": 1, "milestone": 1},
		"open": {"camp": 2, "woodpile": 1, "cottage": 1, "jetty": 1, "graves": 1},
		"wood": {"camp": 2, "woodpile": 2, "cottage": 1, "shrine": 1, "stones": 1}},
	"siege": {"way": {"cart": 2, "battle": 1, "graves": 1},
		"open": {"battle": 3, "bones": 1, "camp": 1, "graves": 1, "wall": 1}},
	"plinth": {"way": {"blocks": 1, "milestone": 1, "shrine": 1, "stele": 1}, "open": {"blocks": 2, "statue": 1, "stones": 1, "wall": 1, "pier": 1}},
	"stillwater": {"way": {"shrine": 1, "milestone": 1}, "open": {"jetty": 2, "camp": 1, "cottage": 1, "stones": 1}},
	"anchorholds": {"way": {"cairns": 2, "shrine": 1}, "open": {"cairns": 2, "shrine": 1, "stones": 1}},
	"saltpans": {"way": {"cart": 2, "milestone": 1}, "open": {"cart": 1, "bones": 1, "camp": 1, "blocks": 1}},
	"oak": {"way": {"shrine": 1, "camp": 1}, "open": {"stones": 1, "camp": 1, "woodpile": 1, "shrine": 1},
		"wood": {"stones": 1, "camp": 1, "woodpile": 1, "shrine": 1}},
	"well": {"way": {"cairns": 1, "milestone": 1}, "open": {"cairns": 2, "stones": 1, "fold": 1}},
	# --- the first doubling's ground and the old valley: already dense; a light hand on what is left open ----
	"road": {"way": {"milestone": 3, "shrine": 2, "cart": 2, "graves": 2, "statue": 1, "stele": 1, "marker": 1}, "open": {"wall": 1, "graves": 1, "lowwall": 1, "pier": 1}},
	"thornwood": {"way": {"woodpile": 1, "shrine": 1, "pier": 1}, "open": {"woodpile": 2, "camp": 1, "stones": 1, "pier": 1, "stele": 1}, "wood": {"woodpile": 2, "camp": 1, "stones": 1, "ruinshrine": 1}},
	"fen": {"way": {"graves": 1, "marker": 1}, "open": {"graves": 2, "stones": 1, "drowned": 2}},
	"crags": {"way": {"cairns": 2}, "open": {"cairns": 2, "bones": 1}},
	"moor": {"way": {"cairns": 2}, "open": {"cairns": 2, "stones": 2, "bones": 1}},
	"quarry": {"open": {"blocks": 3, "cart": 1}},
	"foundry": {"open": {"debris": 3, "blocks": 1}},
	"orchard": {"way": {"cart": 1}, "open": {"woodpile": 2, "wall": 1, "cottage": 1}},
	"mere": {"open": {"jetty": 2, "graves": 1, "drowned": 1}},
	"holds": {"open": {"barrow": 2, "stones": 2}},
}

## Regions the wayside leaves alone: towns are dressed by their own builders, boss and set-piece ground by theirs.
const SKIP := ["hearth", "chapel", "henge", "rift", "ossuary", "summit", "glade", "necropolis", "barrows", "orchard", "ashrift"]

## Biome fallback (a region with no entry above).
const BIOMES := {
	"meadow": {"way": {"milestone": 2, "shrine": 2, "cart": 2, "wall": 2, "well": 1, "marker": 1, "lowwall": 1}, "open": {"wall": 3, "cottage": 2, "fold": 1, "well": 1, "stones": 1, "lowwall": 2, "marker": 1}},
	"heath": {"way": {"milestone": 2, "cairns": 2, "shrine": 1, "stones": 1, "stele": 1}, "open": {"cairns": 2, "stones": 3, "fold": 2, "wall": 2, "barrow": 1, "marker": 1, "stele": 1}},
	"oldforest": {"way": {"shrine": 2, "camp": 2, "woodpile": 2, "pier": 1, "stele": 1}, "open": {"camp": 2, "woodpile": 2, "stones": 2, "cottage": 1, "pier": 1, "ruinshrine": 1, "marker": 1}},
	"fen": {"way": {"graves": 1, "shrine": 1, "marker": 1}, "open": {"graves": 2, "jetty": 2, "stones": 1, "drowned": 2, "marker": 1}},
	"crag": {"way": {"cairns": 2, "milestone": 1}, "open": {"cairns": 2, "stones": 2, "bones": 1, "pier": 1}},
	"ruin": {"way": {"statue": 2, "blocks": 2, "shrine": 1, "lowwall": 1, "stele": 1}, "open": {"cottage": 2, "blocks": 2, "wall": 2, "pier": 2, "ruinshrine": 1, "marker": 1}},
	"ash": {"way": {"debris": 2}, "open": {"debris": 3, "bones": 1, "pier": 1}},
	"salt": {"way": {"cart": 1}, "open": {"cart": 1, "bones": 1, "marker": 1}},
}

## Towns and hamlets: [centre, radius]. Nothing of the wayside's stands inside one (its own builders dress it).
const TOWNS := [
	[Vector2(0.0, 36.0), 46.0],          # Hearthward
	[Vector2(-200.0, 68.0), 34.0],       # Weirford
	[Vector2(214.0, 95.0), 26.0],        # Saltmarket
	[Vector2(322.0, 44.0), 50.0],        # Lastlight (RealmReaches.TOWN_E)
	[Vector2(-160.0, 300.0), 44.0],      # Fallowmere (RealmReaches.TOWN_F)
	[Vector2(-140.0, 350.0), 34.0],      # ... its drowned strips and the scarecrow field (the villagers' walks)
	[Vector2(-316.0, 290.0), 36.0],      # Reedholm (its landing and the meres' walks)
]

## The named places each region keeps: a discovery (its name and line show on the first visit), a writing at it
## (wayside_texts.gd id, its carrier picked from the kind), a box sometimes. Matched to a planned place of one of
## `kinds` in the region (the nearest to `near` when given); unmatched ones are left out of the night.
const NAMED := {
	"greyfell": [
		{"id": "gf_muster", "name": "The Muster Stones", "line": "the garrison was counted here every dawn", "kinds": ["circle", "stones"], "lore": "wy_gf_muster", "box": true},
		{"id": "gf_sentry", "name": "Sentry's Rest", "line": "a watch fire nobody lit again", "kinds": ["battle", "camp"], "lore": "wy_gf_sentry"},
		{"id": "gf_signal", "name": "The Signal Cairn", "line": "to be lit when the sky came", "kinds": ["lookout", "cairns"], "lore": "wy_gf_signal", "box": true}],
	"lanternwood": [
		{"id": "lw_mosswife", "name": "The Mosswife's Shrine", "line": "an offering a night, for the light that grows", "kinds": ["shrine"], "lore": "wy_lw_mosswife"},
		{"id": "lw_hollow", "name": "Cutters' Hollow", "line": "the woodcutters' last night", "kinds": ["camp", "cottage", "woodpile"], "lore": "wy_lw_cutters", "box": true},
		{"id": "lw_stones", "name": "The Lantern Stones", "line": "the Rooted lit them without fire", "kinds": ["circle", "stones"], "lore": "wy_lw_stones"}],
	"kingsbarrows": [
		{"id": "kb_queen", "name": "The Queen's Mound", "line": "the one door that faces east", "kinds": ["barrow"], "lore": "wy_kb_queen", "box": true},
		{"id": "kb_robbers", "name": "The Robbers' Trench", "line": "they dug for gold and found a king", "kinds": ["barrow", "camp"], "lore": "wy_kb_robbers"},
		{"id": "kb_west", "name": "The Westward Stones", "line": "every one leans toward the sunset", "kinds": ["stones", "circle"], "lore": "wy_kb_west"}],
	"reedmere": [
		{"id": "rm_eelwife", "name": "Eel-Wife's Landing", "line": "her traps are still set", "kinds": ["jetty"], "lore": "wy_rm_eelwife", "box": true},
		{"id": "rm_graves", "name": "The Fishers' Graves", "line": "buried facing the water", "kinds": ["graves"], "lore": "wy_rm_graves"},
		{"id": "rm_stage", "name": "Old Holm Stage", "line": "the mere took the house and left the floor", "kinds": ["jetty", "cottage", "camp"], "lore": "wy_rm_stage"}],
	"fallow": [
		{"id": "fm_gleaners", "name": "The Gleaners' Graves", "line": "half the fields are graves", "kinds": ["graves"], "lore": "wy_fm_gleaners"},
		{"id": "fm_tithe", "name": "The Tithe Cart", "line": "it never reached the barn", "kinds": ["cart"], "lore": "wy_fm_tithe", "box": true},
		{"id": "fm_strip", "name": "The Long Strip", "line": "the last furrow is half a furrow", "kinds": ["farm", "wall"], "lore": "wy_fm_strip"}],
	"arches": [
		{"id": "la_yard", "name": "The Masons' Yard", "line": "squared stone for a span never raised", "kinds": ["blocks"], "lore": "wy_la_yard", "box": true},
		{"id": "la_fountain", "name": "The Dry Cistern", "line": "the water stopped when the sky did", "kinds": ["well"], "lore": "wy_la_cistern"},
		{"id": "la_overseer", "name": "The Overseer's Saint", "line": "he watched the arches go up, and down", "kinds": ["statue"], "lore": "wy_la_overseer"}],
	"southwood": [
		{"id": "sw_clamp", "name": "The Burners' Clamp", "line": "still warm, somehow", "kinds": ["charcoal"], "lore": "wy_sw_clamp", "box": true},
		{"id": "sw_holly", "name": "The Nail Shrine", "line": "the witch's price, paid in nails", "kinds": ["shrine", "stones"], "lore": "wy_sw_nails"},
		{"id": "sw_woodpile", "name": "Hob's Stack", "line": "cut for a winter that came early", "kinds": ["woodpile", "camp"], "lore": "wy_sw_hob"}],
	"bellfall": [
		{"id": "bf_shards", "name": "The Shard Field", "line": "pieces of a bell that fell out of the sky", "kinds": ["debris"], "lore": "wy_bf_shards", "box": true},
		{"id": "bf_ringers", "name": "The Ringers' Cairn", "line": "they came to ring it, and it rang them", "kinds": ["cairns", "bones"], "lore": "wy_bf_ringers"},
		{"id": "bf_watch", "name": "The Scorch Watch", "line": "the crater from its lip", "kinds": ["lookout", "battle"], "lore": "wy_bf_watch"}],
	"lastlight": [
		{"id": "ll_graves", "name": "The Turned-Back Graves", "line": "they reached the last lamp, and no further", "kinds": ["graves"], "lore": "wy_ll_graves"},
		{"id": "ll_halt", "name": "Carters' Halt", "line": "the carts waited for the gate to open", "kinds": ["camp", "cart"], "lore": "wy_ll_halt", "box": true},
		{"id": "ll_well", "name": "The Pilgrims' Well", "line": "the last clean water before the mountain", "kinds": ["well"], "lore": "wy_ll_well"}],
	"nave": [
		{"id": "dn_saints", "name": "The Saints' Wait", "line": "carved for niches nobody built", "kinds": ["statue"], "lore": "wy_dn_saints"},
		{"id": "dn_lodge", "name": "The Masons' Lodge", "line": "they built the nave first", "kinds": ["cottage", "blocks"], "lore": "wy_dn_lodge", "box": true},
		{"id": "dn_floor", "name": "The Floorstones", "line": "the floor they meant to lay last", "kinds": ["blocks"], "lore": "wy_dn_floor"}],
	"cairns": [
		{"id": "tc_count", "name": "The Counting Cairn", "line": "somebody tried to count them", "kinds": ["cairns"], "lore": "wy_tc_count", "box": true},
		{"id": "tc_turning", "name": "The Turning Stone", "line": "where they turned for home", "kinds": ["stones", "circle"], "lore": "wy_tc_turning"},
		{"id": "tc_camp", "name": "The Last Camp", "line": "the fire before the turning", "kinds": ["camp", "lookout"], "lore": "wy_tc_camp"}],
	"downs": [
		{"id": "sd_fold", "name": "The Lost Fold", "line": "the flock came back without the shepherd", "kinds": ["fold"], "lore": "wy_sd_fold", "box": true}],
	"sorrow": [
		{"id": "so_ferry", "name": "The Ferry Stage", "line": "the ford before the bridge", "kinds": ["jetty", "camp", "cottage"], "lore": "wy_so_ferry"}],
	"siege": [
		{"id": "sg_sappers", "name": "The Sappers' Camp", "line": "they dug the rings by night", "kinds": ["camp", "battle"], "lore": "wy_sg_sappers", "box": true}],
	"plinth": [
		{"id": "pl_yard", "name": "The Rollers' Yard", "line": "ninety rollers, and one left over", "kinds": ["blocks", "statue"], "lore": "wy_pl_yard"}],
	"stillwater": [
		{"id": "st_boat", "name": "The Lamp-Boat Stage", "line": "where the lamplighters rowed out", "kinds": ["jetty", "camp"], "lore": "wy_st_boat"}],
	"saltpans": [
		{"id": "sp_carter", "name": "The Salt Carter", "line": "a load the Order never paid for", "kinds": ["cart"], "lore": "wy_sp_carter", "box": true}],
	"moor": [
		{"id": "mo_stumbled", "name": "The Stumbled", "line": "the moor kept them", "kinds": ["cairns", "stones", "bones"], "lore": "wy_mo_stumbled"}],
	"road": [
		{"id": "rd_rest", "name": "The Pilgrims' Rest", "line": "sit, and count the miles left", "kinds": ["milestone", "shrine"], "lore": "wy_rd_rest"}],
	"oak": [
		{"id": "ok_acorn", "name": "The Acorn Shrine", "line": "the Rooted left the first fruit here", "kinds": ["shrine", "stones"], "lore": "wy_ok_acorn"}],
	"anchorholds": [
		{"id": "ah_chain", "name": "The Chain Shrine", "line": "a link for every year walled in", "kinds": ["shrine", "cairns"], "lore": "wy_ah_chain"}],
}

## Unnamed writings: region -> [[wayside_texts id, kinds that may carry it]], given to planned places in order.
const LORE := {
	"greyfell": [["wy_gf_grave", ["battle", "graves", "cairns"]]],
	"lanternwood": [["wy_lw_way", ["milestone", "shrine"]]],
	"kingsbarrows": [["wy_kb_way", ["milestone", "stones"]], ["wy_kb_rune", ["barrow", "stones"]]],
	"reedmere": [["wy_rm_way", ["milestone", "shrine", "graves"]]],
	"fallow": [["wy_fm_way", ["milestone", "wall", "well"]], ["wy_fm_grave", ["graves"]]],
	"arches": [["wy_la_way", ["milestone", "blocks", "shrine"]]],
	"southwood": [["wy_sw_page", ["camp", "woodpile", "charcoal"]]],
	"bellfall": [["wy_bf_page", ["debris", "battle", "milestone"]]],
	"lastlight": [["wy_ll_way", ["milestone"]], ["wy_ll_page", ["cart", "camp"]]],
	"nave": [["wy_dn_notice", ["statue", "blocks", "milestone"]]],
	"cairns": [["wy_tc_way", ["milestone", "cairns", "stones"]]],
	"downs": [["wy_sd_way", ["milestone", "wall", "cairns"]]],
	"road": [["wy_rd_way", ["milestone"]], ["wy_rd_grave", ["graves"]]],
	"siege": [["wy_sg_page", ["cart", "battle", "camp"]]],
	"saltpans": [["wy_sp_way", ["milestone", "cart"]]],
}

## A box's loot by tier (LootChest): the wayside's are small, a handful of ash and now and then something more.
const LOOT := {
	"wood": [{"grave_ash": 6}, {"grave_ash": 7, "grave_iron": 1}, {"grave_ash": 6, "ash_bloom": 1}, {"grave_ash": 8}],
	"iron": [{"grave_ash": 11, "relic_fragment": 1}, {"grave_ash": 12, "grave_iron": 2}],
}


## The kinds a region favours where a place stands (ctx "way" / "open" / "wood"), with its biome as the fallback.
static func weights(region: String, biome: String, ctx: String) -> Dictionary:
	var t: Dictionary = REGIONS.get(region, BIOMES.get(biome, BIOMES["meadow"]))
	if t.has(ctx):
		return t[ctx]
	if ctx == "wood" and t.has("open"):
		return t["open"]
	return t.get("open", {})

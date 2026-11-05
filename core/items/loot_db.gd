extends RefCounted
## Loot (r33, WoW-style loot adapted to the night): item QUALITY for everything you can carry,
## the great ones' fixed loot tables, the rares' table, what a chest adds, and what vendors pay.
## Pure data and pure functions. Load by path (no class_name):
##   const LootDB := preload("res://core/items/loot_db.gd")
##
## Quality is one scale for gear AND satchel items (0..4, the same as GearDB.RARITY):
##   0 Worn (grey)   1 Kindled (amber)   2 Hallowed (pale blue)   3 Reliquary (violet)   4 Umbral (rose)
## Its colour is used everywhere a thing is named: tooltips, the satchel's slot borders, the gear
## panel, the shop, the loot window and the shaft of light a drop stands in (gear_drop.gd,
## loot_bag.gd). quality_color(q) is the one place the colours come from.
##
## Loot tables (gear_runtime.gd lays them as a loot bag you open with E, ui/loot_window.gd):
##   BOSS_TABLE[boss id]   three named pieces (GearDB.NAMED); the first kill gives one you do not
##                         own, plus a set piece (GearRuntime.roll_drop("boss")), ember shards and a
##                         LEGEND_CHANCE chance at an Umbral legend you have not found
##   RARE_TABLE            the named pool every rare draws from on its FIRST fall (per rare id),
##                         plus a Hallowed+ piece and shards every time. See gear_runtime.gd
##                         drop_rare() for the call the enemies use.

const GearDB := preload("res://core/items/gear_db.gd")

const QUALITY_NAMES := ["Worn", "Kindled", "Hallowed", "Reliquary", "Umbral"]


static func quality_color(q: int) -> Color:
	return GearDB.rarity_color(q)


static func quality_name(q: int) -> String:
	return String(QUALITY_NAMES[clampi(q, 0, 4)])


## A satchel item's quality (ItemDB id). An explicit "quality" in its def wins; otherwise by kind.
const ITEM_QUALITY := {
	"grave_ash": 0, "ember_shard": 1, "relic_fragment": 2, "ash_bloom": 1, "grave_iron": 1,
	# elite bounties (core/life/encounters/elites.gd): a cut above the found charms
	"hobbs_knuckles": 3, "lisles_tally": 3, "briar_antler": 3, "heart_stone": 3, "cinder_censer": 3, "scraped_face": 3,
}
const KIND_QUALITY := {"material": 1, "charm": 2, "core": 3, "relic": 4, "trophy": 4}


static func item_quality(id: String) -> int:
	var d: Dictionary = ItemDB.DEFS.get(id, {})
	if d.has("quality"):
		return clampi(int(d.quality), 0, 4)
	if ITEM_QUALITY.has(id):
		return int(ITEM_QUALITY[id])
	return int(KIND_QUALITY.get(String(d.get("kind", "material")), 1))


## The great ones: three named pieces each (GearDB.NAMED ids).
const BOSS_TABLE := {
	"thornwarden": ["heartwood_cup", "henge_mantle", "briarwick_glass"],
	"bone_abbot": ["counting_cord", "charnel_glass", "bone_collar"],
	"ascended_warden": ["edict_stole", "latch_cord", "sky_cage"],
}
## Any boss without its own table (a later night's) draws from these.
const BOSS_FALLBACK := ["heartwood_cup", "counting_cord", "edict_stole", "charnel_glass"]
const LEGEND_CHANCE := 0.15
const BOSS_SHARDS := 4

## Rares: the named pool (first fall of each rare id), and what every fall gives.
const RARE_TABLE := ["digger_glass", "bone_cincture", "mirewick_stole", "corpse_cradle", "tollmans_ring", "widow_veil"]
const RARE_SHARDS := Vector2i(2, 4)
const RARE_FRAG_CHANCE := 0.25
## A rare's own extra named piece (rare id -> GearDB.NAMED id), when the enemies pass adds one.
const RARE_OWN := {}

## A chest's gear source (loot_chest.gd's tier) and what the bag adds on top of the chest's own loot.
const CHEST_SRC := {"wood": "tough", "iron": "elite", "reliquary": "elite"}
const CHEST_EXTRA := {
	"wood": {"ember_shard": 1},
	"iron": {"ember_shard": 2, "grave_iron": 1},
	"reliquary": {"ember_shard": 3, "relic_fragment": 1},
}

## What a vendor pays, in grave ash (WoW's vendor price). Unique things (relics, trophies, charms,
## cores) are never sold; grave ash is the coin itself.
const SELL_ITEM := {"ember_shard": 1, "relic_fragment": 5, "ash_bloom": 1, "grave_iron": 2}
const BUYBACK_CAP := 8


static func sell_price_piece(p: Dictionary) -> int:
	return 2 + 3 * clampi(int(p.get("rarity", 0)), 0, 4) + int(p.get("level", 0)) + (4 if String(p.get("named", "")) != "" else 0)


static func sell_price_item(id: String) -> int:
	return int(SELL_ITEM.get(id, 0))

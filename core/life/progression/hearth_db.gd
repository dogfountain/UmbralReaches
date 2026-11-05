extends RefCounted
## The Hearthfire (progression; docs/enshrouded/progression.md): Hearthward's own fire, on the
## green, grows as the valley is kindled, and the village grows round it. Pure data and pure
## functions; the runtime is hearth.gd, the menu is the Kindling's HEARTH tab (ui/growth.gd), the
## merchants are core/life/village/village_shop.gd. Load by path (no class_name).
##
## What the Hearthfire does at each tier:
##   - every kindled fire's sanctuary (LightGrid radius) reaches further: the valley's light grows
##   - the wanderer holds more Gloom (how long you can stay out in the dark)
##   - Rested lasts longer (comfort: the tier and every homecoming in Hearthward)
##   - Hearthward's people open their trades: Hild's forge (I), Bet Reed's garden (II), Brannoc's
##     hand-bells at the fires (III: walk between kindled fires), the beacon (IV)
## Raising a tier needs fires kindled (and, later, the valley's keepers down), grave ash and relic
## fragments, and it is done only at Hearthward's fire.
##
## State (Travel.system_state("hearth")):
##   tier    int                     the Hearthfire, 0..4
##   works   {id -> true}            Hild's works and Brannoc's bells, bought once
##   meals   {kind -> {id, left}}    what the wanderer has eaten, by kind (seconds left)
##   rested  float                   seconds of Rested left
##   gleaned int                     kills counted toward the Ash-Gleaner's second pinch

## Hearthward's fire: the brazier on the green. Within this many metres of HOME counts.
const HOME := Vector2(0.0, 33.0)
const HOME_R := 9.0

const TIERS: Array[Dictionary] = [
	{"name": "Banked", "reach": 0.0, "gloom": 0.0, "comfort": 0,
		"text": "Hearthward's fire as you found it: banked low, kept alive by Col's logs and nobody's faith."},
	{"name": "Drawing", "reach": 1.0, "gloom": 8.0, "comfort": 2, "need": "kindled:1", "need_text": "one valley fire kindled",
		"ash": 16, "frag": 0, "opens": "smith",
		"text": "The green's fire draws on its own. Hild has heat to spare for your work.",
		"lore": "Feed it what you took off the hollowed. It was theirs; it was always going to be warmth."},
	{"name": "Roaring", "reach": 2.0, "gloom": 16.0, "comfort": 4, "need": "kindled:2", "need_text": "two valley fires kindled",
		"ash": 26, "frag": 1, "opens": "herbs",
		"text": "Bet Reed's beans come up in the warmth. She has a garden again, and things to brew from it.",
		"lore": "A fire you can hear from the Keg's door. Nan says it sounds like rain falling upward."},
	{"name": "Blazing", "reach": 3.0, "gloom": 24.0, "comfort": 6, "need": "kindled:3,bosses:1", "need_text": "three fires kindled and one keeper down",
		"ash": 36, "frag": 2, "opens": "bells",
		"text": "Brannoc has hand-bells for every fire you have lit. Ring one at a fire and walk to another.",
		"lore": "\"I cast forty for the Stair. I can cast four for the fires.\" He cast five. Nobody asked about the fifth."},
	{"name": "Beacon", "reach": 4.5, "gloom": 34.0, "comfort": 9, "need": "kindled:4,bosses:2", "need_text": "all four valley fires kindled and two keepers down",
		"ash": 48, "frag": 2, "opens": "beacon",
		"text": "Hearthward is a beacon. Every fire in the valley leans toward it, and the dark leans away.",
		"lore": "Maud says she can see it from her window without the candle. She lights the candle anyway."},
]

## The trades that open with the Hearthfire. `who` is the village merchant id (ui/shop.gd).
const SERVICES := {
	"smith": {"name": "Hild's forge", "who": "hild", "tier": 1, "glyph": "ferrule",
		"text": "Hild forges fire-baskets and bellows for the valley's braziers, and smelts ash for your gear."},
	"herbs": {"name": "Bet Reed's garden", "who": "bet", "tier": 2, "glyph": "branch", "needs": "v:reed_home", "needs_text": "Bet Reed home in Hearthward",
		"text": "Bet brews tonics from her beans and the fen's herbs: stronger and longer than the Keg's food."},
	"bells": {"name": "Brannoc's hand-bells", "who": "", "tier": 3, "glyph": "bell",
		"text": "Hang a bell at every kindled fire. At any of them, ring and walk to another (the Kindling, HEARTH)."},
	"beacon": {"name": "The beacon", "who": "", "tier": 4, "glyph": "hearth",
		"text": "Rested lasts as long again, and every kindled fire reaches its furthest."},
}

## Hild's works: bought once at her forge, lasting. fx are UpgradeDB.mods keys (PathsDB.add_fx).
const WORKS: Array[Dictionary] = [
	{"id": "baskets", "name": "Iron fire-baskets", "glyph": "hearth", "price": 18, "tier": 1,
		"text": "Hild forges baskets for the valley's braziers: every kindled fire's sanctuary reaches 1 m further.",
		"fx": {"reach_add": 1.0}, "say": "Iron round a fire keeps it fed from below. Same as people."},
	{"id": "bellows", "name": "Bellows for the fires", "glyph": "coals", "price": 22, "tier": 2,
		"text": "A pair of bellows hung at every brazier: fire takes the Gloom off you and mends you 25% faster.",
		"fx": {"lit_mult": 1.25}, "say": "Grandmother's pattern. Squeeze it like you mean it."},
	{"id": "ferrule_iron", "name": "Shod the staff", "glyph": "ferrule", "price": 26, "tier": 2, "frag": 1,
		"text": "A band of tempered iron under the orb: +6% damage from every spell.",
		"fx": {"power": 0.06}, "say": "Hold still. ...There. It'll ring when you swing it. That's the temper, not me."},
	{"id": "grate", "name": "A fire-grate for the green", "glyph": "cord", "price": 30, "tier": 3, "frag": 1,
		"text": "Hearthward's fire burns on a proper grate: Rested lasts 25% longer, and +10 Gloom held.",
		"fx": {"rest_add": 0.25, "gloom_add": 10.0}, "say": "A fire on the ground is a camp. On a grate, it's a home."},
	# r33 gathering: grave-iron from the fen and the barrows (core/items/gather.gd)
	{"id": "fire_dogs", "name": "Grave-iron fire-dogs", "glyph": "hearth", "price": 10, "tier": 1, "mats": {"grave_iron": 4},
		"text": "Hild casts fire-dogs from grave-iron for every brazier: each kindled fire reaches 0.5 m further, and +6 Gloom held. Takes 4 grave-iron.",
		"fx": {"reach_add": 0.5, "gloom_add": 6.0}, "say": "Coffin-iron. Holds heat like it's sorry for something."},
]

## Smelting: Hild turns grave ash into the gear smith's ember shards (equipment system), when that
## system is in the build. `rate` ash per shard.
const SMELT := {"ash": 6, "shards": 1, "tier": 1}

## Food and drink (timed buffs): one of each KIND at once, up to `belly` dishes (2, 3 with the
## Pilgrim's Appetite). A dish of a kind already eaten replaces it. Seconds are play time.
const KINDS := {"hearty": "Hearty", "warming": "Warming", "sharp": "Sharp"}
const BELLY := 2
const MEALS: Array[Dictionary] = [
	# the Kindled Keg's slate
	{"id": "bread", "who": "keep", "kind": "hearty", "name": "Black bread and dripping", "glyph": "mound", "price": 2, "secs": 360.0,
		"fx": {"gloom_add": 12.0}, "text": "Hearty: +12 Gloom held for 6 minutes.",
		"say": "Yesterday's. It was yesterday's yesterday, too."},
	{"id": "stew", "who": "keep", "kind": "warming", "name": "Fen-eel stew", "glyph": "well", "price": 3, "secs": 360.0,
		"fx": {"dark_mult": 0.9}, "text": "Warming: Gloom gathers 10% slower for 6 minutes.",
		"say": "Don't ask where Ostrin caught them. He won't tell you either."},
	{"id": "mulled", "who": "keep", "kind": "sharp", "name": "Mulled ale", "glyph": "cinder", "price": 3, "secs": 300.0,
		"fx": {"power": 0.06}, "text": "Sharp: +6% damage from every spell for 5 minutes.",
		"say": "Hot enough to argue with. Drink it before it starts."},
	# Bet Reed's garden (the Hearthfire II, and Bet home)
	{"id": "honey", "who": "bet", "kind": "hearty", "name": "Bramble-honey cake", "glyph": "heart", "price": 5, "secs": 540.0,
		"fx": {"gloom_add": 22.0}, "text": "Hearty: +22 Gloom held for 9 minutes.",
		"say": "Tobin kept the bees. They kept on without him. So did I."},
	{"id": "feverfew", "who": "bet", "kind": "warming", "name": "Feverfew tonic", "glyph": "rosary", "price": 5, "secs": 540.0,
		"fx": {"dark_mult": 0.85, "lit_mult": 1.15}, "text": "Warming: Gloom gathers 15% slower, and fire takes it off 15% faster, for 9 minutes.",
		"say": "Bitter. Good. The sweet ones never did anybody any good."},
	{"id": "rue", "who": "bet", "kind": "sharp", "name": "Bitter rue", "glyph": "branch", "price": 6, "secs": 480.0,
		"fx": {"cd": -0.07, "power": 0.04}, "text": "Sharp: spells recover 7% sooner and hit 4% harder, for 8 minutes.",
		"say": "Rue for remembering. You'll want to remember something, the way you look."},
	# r33 gathering: dishes that take ash-blooms as well as ash ("mats")
	{"id": "posset", "who": "keep", "kind": "warming", "name": "Ash-bloom posset", "glyph": "well", "price": 1, "secs": 480.0, "mats": {"ash_bloom": 2},
		"fx": {"dark_mult": 0.88, "lit_mult": 1.1}, "text": "Warming: Gloom gathers 12% slower, and fire takes it off 10% faster, for 8 minutes. Takes 2 ash-blooms.",
		"say": "Hot milk, bloom and a lie about the brandy. Drink it while it still glows."},
	{"id": "bloomcake", "who": "bet", "kind": "hearty", "name": "Bloom-and-honey bannock", "glyph": "heart", "price": 2, "secs": 660.0, "mats": {"ash_bloom": 3},
		"fx": {"gloom_add": 28.0}, "text": "Hearty: +28 Gloom held for 11 minutes. Takes 3 ash-blooms.",
		"say": "The flowers only open in the dark. So do I, these days."},
]

## r33 gathering trades: repeatable, at a merchant (shown as shop rows through village_shop.gd's
## hook; hearth.gd trade_rows / trade). "mats" are taken with the ash; "gives" go in the satchel.
const TRADES: Array[Dictionary] = [
	{"id": "smelt_iron", "who": "hild", "service": "smith", "name": "Smelt grave-iron into ember shards", "glyph": "cinder", "price": 1,
		"mats": {"grave_iron": 2}, "gives": {"ember_shard": 2},
		"text": "Hild renders 2 grave-iron and a pinch of ash into 2 ember shards: far cheaper than smelting ash alone."},
	{"id": "bloom_tonic", "who": "bet", "service": "herbs", "name": "Distil ash-blooms into a relic fragment", "glyph": "rosary", "price": 4,
		"mats": {"ash_bloom": 6}, "gives": {"relic_fragment": 1},
		"text": "Bet boils six ash-blooms down to a hard pale bead the fires take as a relic fragment."},
]


static func trade(id: String) -> Dictionary:
	for t: Dictionary in TRADES:
		if t.id == id:
			return t
	return {}


## "" when `mats` ({item id -> n}) are all carried, else what is missing.
static func mats_why(mats: Dictionary) -> String:
	for id: String in mats:
		var have := Travel.count(id)
		if have < int(mats[id]):
			return "Needs %d %s (you carry %d)." % [int(mats[id]), String(ItemDB.def(id).get("name", id)).to_lower(), have]
	return ""

## Rested (the comfort buff): standing 3 s at Hearthward's fire or inside the Kindled Keg.
## Lasts REST_BASE + REST_PER_COMFORT a comfort point (x the Long Rest / grate / beacon bonuses).
const REST_BASE := 240.0
const REST_PER_COMFORT := 30.0
const REST_STAND := 3.0
const REST_FX := {"dark_mult": 0.88, "cd": -0.04}
## The Keg (RealmLayout.TAVERN), grown a little so its doorstep counts.
const KEG := Rect2(10.0, 25.6, 16.0, 9.2)

## Unremembering (taking every Path step back) costs this much ash a step, at Hearthward's fire.
const UNREMEMBER_PER := 3


static func tier(hs: Dictionary) -> int:
	return clampi(int(hs.get("tier", 0)), 0, TIERS.size() - 1)


static func works(hs: Dictionary) -> Dictionary:
	var w: Variant = hs.get("works", {})
	return w if w is Dictionary else {}


static func work(id: String) -> Dictionary:
	for w: Dictionary in WORKS:
		if w.id == id:
			return w
	return {}


static func meal(id: String) -> Dictionary:
	for m: Dictionary in MEALS:
		if m.id == id:
			return m
	return {}


static func meals(hs: Dictionary) -> Dictionary:
	var m: Variant = hs.get("meals", {})
	return m if m is Dictionary else {}


static func service_open(hs: Dictionary, id: String) -> bool:
	var s: Dictionary = SERVICES.get(id, {})
	return not s.is_empty() and tier(hs) >= int(s.tier)


## Comfort: the Hearthfire's own, plus one for every homecoming in Hearthward (`restored` =
## VillageState's restored ids), plus one for each of Hild's works.
static func comfort(hs: Dictionary, restored: int) -> int:
	return int(TIERS[tier(hs)].comfort) + restored + works(hs).size()


## Seconds a full Rested lasts. `rest_add` is the summed bonus (Long Rest, the grate).
static func rest_secs(hs: Dictionary, restored: int, rest_add: float) -> float:
	var s := REST_BASE + REST_PER_COMFORT * float(comfort(hs, restored))
	if service_open(hs, "beacon"):
		rest_add += 1.0
	return s * (1.0 + rest_add)


## Sanctuary reach added to every kindled fire (metres): the tier and any works / Path steps
## (`reach_add` from the mods table).
static func reach(hs: Dictionary, reach_add: float) -> float:
	return float(TIERS[tier(hs)].reach) + reach_add


## Everything the Hearthfire, Hild's works, meals and Rested add to the mods table `m`.
static func apply(m: Dictionary, hs: Dictionary) -> void:
	var t := tier(hs)
	if t > 0:
		m["gloom_add"] = float(m.get("gloom_add", 0.0)) + float(TIERS[t].gloom)
		m["bent"] = true
	for id: String in works(hs):
		_fx(m, work(id).get("fx", {}))
	for kind: String in meals(hs):
		var e: Variant = meals(hs)[kind]
		if e is Dictionary and float((e as Dictionary).get("left", 0.0)) > 0.0:
			_fx(m, meal(String((e as Dictionary).get("id", ""))).get("fx", {}))
	if float(hs.get("rested", 0.0)) > 0.0:
		_fx(m, REST_FX)
		m["rested"] = true


static func _fx(m: Dictionary, fx: Dictionary) -> void:
	for key: String in fx:
		var v := float(fx[key])
		if key.ends_with("_mult"):
			m[key] = float(m.get(key, 1.0)) * v
		else:
			m[key] = float(m.get(key, 0.0)) + v
	if not fx.is_empty():
		m["bent"] = true


## Whether `pos` is at Hearthward's fire (the green) or inside the Kindled Keg.
static func at_home(pos: Vector3) -> bool:
	return Vector2(pos.x, pos.z).distance_to(HOME) <= HOME_R or KEG.has_point(Vector2(pos.x, pos.z))


static func fmt_secs(s: float) -> String:
	var n := maxi(0, int(ceil(s)))
	return "%d:%02d" % [n / 60, n % 60]

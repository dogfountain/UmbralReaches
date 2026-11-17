extends RefCounted
## Progression data: everything grave ash buys at a kindled fire (the Kindling, ui/growth.gd), and
## the one function that turns a save into live modifiers (`mods`). Pure and static; preload it.
##
## Ash flow (ItemDB): 1 a kill, 25 a boss. Gates count bosses slain, so the menu opens up with the
## map: tier I before the Thornwarden (about 15-25 ash: 2-3 picks), tier II after one boss (+25 and
## the fen/Ossuary packs: 2-3 picks of 14-20), tier III after two (2-3 picks of 24-30). Everything
## costs about 620 ash; a full run earns about a third of it, so builds differ.
##
## State (Travel.system_state("progression")):
##   ranks  {upgrade id -> rank}      embers, spells ("bolt".."step") and rites (rank 1)
##   oaths  {"1"|"2"|"3" -> "a"|"b"}  one vow per tier (forswearing clears it, no refund)
##   worn   [charm item ids]          charms worn (slots: 2, +1 with the Charm Cord)
##   known  [spell ids]               spells learned beyond the stock five (tether, well, familiar)
##   loadout [4 spell ids]            hotbar slots 1..4 (slot 0 is Rift Bolt), swapped at a fire
##   core   "core_*" | ""             the staff core in the orb (Prism, Lodestar, Cinder, Rime)
##   spent  int                       ash fed to the fire, all time (other systems may read it)
##   tier   int                       upgrades owned (ranks + oaths), a coarse power level

## Live modifiers, recomputed by the runtime (kindling.gd) whenever the state changes. The skill
## subclasses under skills/ read this at cast time.
static var live: Dictionary = {}

const EMBERS: Array[Dictionary] = [
	{"id": "warmth", "name": "Hearth-Warmth", "glyph": "hearth", "max": 3, "cost": [6, 14, 24], "gate": [0, 0, 2],
		"per": "+15 Gloom held before the dark takes shape.",
		"lore": "Edda's coals kept a whole village warm one night. A pinch of them keeps you."},
	{"id": "banked", "name": "Banked Coals", "glyph": "coals", "max": 3, "cost": [8, 16, 26], "gate": [0, 1, 2],
		"per": "Gloom gathers 12% slower in the dark and by the Rift.",
		"lore": "A fire banked at dusk is still alive at dawn. So are you, longer."},
	{"id": "will", "name": "Kindled Will", "glyph": "will", "max": 3, "cost": [10, 18, 30], "gate": [0, 1, 2],
		"per": "+10% damage from every spell.",
		"lore": "Ash to ember, ember to flame. The hollowed gave this warmth up; spend it hard."},
	{"id": "quick", "name": "Quickened Flame", "glyph": "quick", "max": 2, "cost": [14, 28], "gate": [1, 2],
		"per": "Every spell recovers 7% sooner.",
		"lore": "Dry tinder catches at a breath."},
	{"id": "cord", "name": "Charm Cord", "glyph": "cord", "max": 1, "cost": [16], "gate": [1],
		"per": "Wear a third charm.",
		"lore": "A bootlace from Edda's forge, blackened, strong enough for one more keepsake."},
]

## Skill ranks: [name, effect] per rank. Costs and gates are shared by all five.
const SPELL_COST := [8, 16, 26]
const SPELL_GATE := [0, 1, 2]
const SPELLS: Array[Dictionary] = [
	{"id": "bolt", "name": "Rift Bolt", "glyph": "bolt", "color": Color("#A98BFF"), "ranks": [
		["Keen", "Bolts fly 20% faster, burst wider (1.8 to 2.3 m) and bend toward a foe near your aim."],
		["Deep Marks", "The Rift Lash leaves 3 Marks, bursts 0.8 m wider, and its rune drags foes in to the burst."],
		["Through", "Ordinary bolts pass through bodies, marking each one. The Lash still bursts."]]},
	{"id": "lance", "name": "Ember Lance", "glyph": "lance", "color": Color("#FF7A4A"), "ranks": [
		["Quick Draw", "Charges 25% faster. Let go on the white snap of a full charge for a Perfect throw: +30% damage."],
		["Wide Ember", "Bursts 1 m wider; a tap hits 25% harder; the burst throws three cinders that burst again where they land."],
		["Cinder Scar", "A full charge leaves the ground burning for 3 s: it scorches and Marks whatever stands in it."]]},
	{"id": "nova", "name": "Umbral Nova", "glyph": "nova", "color": Color("#C04DFF"), "ranks": [
		["Wider Ring", "The ring reaches 7.2 m (was 6), and an echo follows it half a second later: 0.5 damage and another shove."],
		["Short Wick", "Recovers in 5.5 s (was 7). Every Mark it detonates sends a mote home to you: it mends 2 Wounds."],
		["Undertow", "Whatever the ring catches past 2.5 m is dragged in to you instead of thrown out."]]},
	{"id": "ward", "name": "Lantern Ward", "glyph": "ward", "color": Color("#FFB347"), "ranks": [
		["Long Wick", "Burns 3 s longer (10 s), and its flame pulses every 2 s, throwing foes back off its edge."],
		["Close Watch", "Recovers in 17 s (was 24). While you stand in its light, your other spells recover 30% faster."],
		["Mirror Flame", "Spit that reaches the ward's light is turned back on the nearest spitter, and Marks it."]]},
	{"id": "step", "name": "Rift Step", "glyph": "step", "color": Color("#7FA8FF"), "ranks": [
		["Long Stride", "Reaches 9.5 m (was 7.5), and you arrive with a shock that throws back every foe within 2.5 m."],
		["Slip", "Untouchable for 0.6 s after the tear (was 0.35), and your first bolt within 1.5 s is a Rift Lash."],
		["Rend", "The tear you leave bursts a moment later: 1.5 damage and a Mark to all within 3 m."]]},
	# learned at the Kindling (LEARN), then ranked like the five; they take a hotbar slot (LOADOUT)
	{"id": "tether", "name": "Rift Tether", "glyph": "tether", "color": Color("#5FE3D0"), "learn": {"cost": 14, "gate": 0},
		"text": "Throw a rift chain at the foe nearest your aim (18 m at first): it is Marked and dragged to you. The great ones drag you to them instead.",
		"lore": "The ferrymen of the fen kept a hooked chain for the dead who would not lie down. The Rift kept the chain.",
		"ranks": [
		["Long Chain", "Reaches 24 m, and what it drags arrives staggered."],
		["Fork", "The chain forks to a second foe within 6 m of the first and drags both."],
		["Reel", "A foe dragged in with Marks on it bursts at your feet: 1 damage per Mark to all within 2.5 m (the Marks are spent)."]]},
	{"id": "well", "name": "Umbral Well", "glyph": "well", "color": Color("#8A6CFF"), "learn": {"cost": 20, "gate": 1},
		"text": "Open a well of dark where you aim (22 m). At first, for 3 s it drags foes to its heart, slows them and Marks them each second; then it collapses: 1 damage, +0.5 per Mark. An Ember Lance burst over it lights a Maelstrom.",
		"lore": "Brother Anselm wrote that the Rift is not a hole but a mouth. He wrote it twice, the second time smaller.",
		"ranks": [
		["Deeper Pull", "Wider (5.5 m, was 4.5) and stronger, and it holds 4 s."],
		["Hungry Dark", "It swallows spit that comes near, and the collapse throws it back as shards at the nearest foes."],
		["Event Horizon", "The collapse detonates every Mark inside it, as Umbral Nova does."]]},
	{"id": "familiar", "name": "Bound Shade", "glyph": "familiar", "color": Color("#C9B8FF"), "learn": {"cost": 24, "gate": 1},
		"text": "Bind a shade for 14 s. At first it circles you and darts at the foe nearest your aim every 1.1 s: 0.5 damage and a Mark.",
		"lore": "Not every shade is hungry. Some only want to be useful again.",
		"ranks": [
		["Keen Eyes", "It darts every 0.75 s, and its darts seek."],
		["Twin Shades", "Bind two."],
		["Last Breath", "When its time runs out it dives at the nearest foe and bursts: 2 damage, and every Mark within 3 m detonates."]]},
	# r36 Act II: Brannoc teaches it when the peal is answered (The Founder's Peal turn-in); the
	# Kindling teaches it after that too, should the gift be lost to an old save
	{"id": "peal", "name": "Founder's Peal", "glyph": "peal", "color": Color("#E8C27A"), "learn": {"cost": 16, "gate": 2, "story": "founders_peal"},
		"text": "Strike the bell in you: a stroke goes out in a 75-degree cone, 9 m. Every foe in it takes 1 damage and a Mark, and a lesser foe is staggered while a great one keeps its feet; spit in it is knocked from the air.",
		"lore": "\"Mother said every bell has one note it was cast for, and one it learns. The one it learns is the one you hear.\" Brannoc Bellwright.",
		"ranks": [
		["Wide Stroke", "The cone opens to 110 degrees and reaches 11 m."],
		["Resonance", "A foe already Marked takes a second Mark, and 0.5 more damage for each Mark it carried."],
		["Great Bell", "The stroke rings twice as hard on the great ones, and every foe it strikes is slowed by half for 2 s."]]},
]
## Hotbar: slot 0 is always Rift Bolt; the other four take any known spell (swapped at a fire).
const SLOT_ACTIONS: Array[StringName] = [&"skill_bolt", &"skill_lance", &"skill_nova", &"skill_ward", &"skill_step"]
const SLOT_KEYS := ["LMB", "RMB / R", "Q", "F", "C"]


## The key (or, on a pad, the button) a loadout slot casts with, as rebound: SLOT_KEYS are only the defaults.
static func slot_key(i: int) -> String:
	if i < 0 or i >= SLOT_KEYS.size():
		return "?"
	return InputSetup.live_label(String(SLOT_ACTIONS[i]), Settings.using_pad, String(SLOT_KEYS[i]))


const LOADOUT_DEFAULT := ["lance", "nova", "ward", "step"]
const STOCK := ["bolt", "lance", "nova", "ward", "step"]

## Staff cores: one sits in the orb and changes every Rift Bolt. Forged at a fire from relic
## fragments and ash, or found. "" is the Hollow Core the staff was cut with.
const CORES: Array[Dictionary] = [
	{"id": "", "name": "Hollow Core", "glyph": "core", "tint": Color("#A98BFF"),
		"text": "The violet the staff was cut with. Bolts mark and burst; nothing more, nothing less.",
		"lore": "The orb was empty when you woke with it. Something in the Rift filled it."},
	{"id": "core_prism", "name": "Prism Core", "glyph": "prism", "tint": Color("#BDF2FF"), "forge": {"frag": 2, "ash": 14},
		"text": "Each bolt splits into three a few strides out: the fan strikes for 0.45 damage and a Mark each. The Lash flies whole.",
		"lore": "Ground from a reliquary's crystal. Light that goes in once comes out three times."},
	{"id": "core_lodestar", "name": "Lodestar Core", "glyph": "lodestar", "tint": Color("#FFD86A"), "forge": {"frag": 2, "ash": 18},
		"text": "A bolt that strikes a foe leaps on to the next within 9 m, twice, at 70% damage each leap.",
		"lore": "Pilgrims followed a star to the Stair. This one follows them back."},
	{"id": "core_cinder", "name": "Cinder Core", "glyph": "cinder", "tint": Color("#FF7A3A"),
		"text": "Bolts set foes burning: 0.3 damage every half second for 2 s. An Ember Lance on a Marked foe kindles the Marks (Kindled Rift).",
		"lore": "A coal from the Rift that will not go out, and would rather not be held."},
	{"id": "core_rime", "name": "Rime Core", "glyph": "rime", "tint": Color("#9FD8FF"),
		"text": "Bolts chill: foes slow by 30% for 2 s, and the third chill freezes them in place for 1.2 s. The Lance and Nova hit a frozen foe twice as hard (Shatter).",
		"lore": "Fen ice from under the drowned graves, that does not melt in the hand."},
]
## Cores lying in the world (the rest are forged).
const CORE_SPOTS := {
	"core_cinder": {"at": Vector2(12.0, 4.0), "where": "the Rift's rim, east of the Crossing"},
	"core_rime": {"at": Vector2(92.0, -8.0), "where": "the Hollow Fen's coldest pool"},
}

## Oaths: one of two per tier. Swearing costs ash; forswearing is free but the ash is gone.
const OATHS: Array[Dictionary] = [
	{"tier": 1, "cost": 12, "gate": 0,
		"a": {"id": "hearth", "name": "Oath of the Hearth", "glyph": "hearth",
			"text": "A fire takes the Gloom off you and mends the plate 60% faster; a ward takes the Gloom off faster, and does not mend.",
			"lore": "Stay by the fire. That is the whole of the Kindlers' teaching."},
		"b": {"id": "hollow", "name": "Oath of the Hollow", "glyph": "hollow",
			"text": "A kill beside you, within 28 m, mends 4 more Wounds.",
			"lore": "Take back from them what the sky took from them."}},
	{"tier": 2, "cost": 20, "gate": 1,
		"a": {"id": "lash", "name": "Oath of the Lash", "glyph": "bolt",
			"text": "Rift Bolt's Lash comes every 2nd bolt in a chain, not every 3rd.",
			"lore": "Strike, and strike harder. The Rift does not wait."},
		"b": {"id": "pyre", "name": "Oath of the Pyre", "glyph": "lance",
			"text": "Ember Lance charges 30% faster, and a full charge hits 50% harder.",
			"lore": "One great fire, not many small ones."}},
	{"tier": 3, "cost": 30, "gate": 2,
		"a": {"id": "tally", "name": "Oath of the Tally", "glyph": "tally",
			"text": "Umbral Nova deals 1.5 damage for every Mark it detonates (was 1).",
			"lore": "Count them, as the Abbot did. Then make the count mean something."},
		"b": {"id": "door", "name": "Oath of the Open Door", "glyph": "door",
			"text": "Rift Step recovers twice as fast, and every step mends 3 Wounds.",
			"lore": "Aurel held the door. Walk through it, and back, and through."}},
]

## Rites: one per relic or trophy, bought once, needing it in the satchel.
const RITES: Array[Dictionary] = [
	{"id": "bramble", "needs": "thorn_heart", "name": "Bramble Ward", "glyph": "bramble", "cost": 18,
		"text": "Lantern Ward snags what crosses its light in brambles: slowed hard for a moment, and Marked once.",
		"lore": "The Thorn Heart still beats. Plant it by a fire and see what grows."},
	{"id": "deep", "needs": "bone_reliquary", "name": "Deep Reliquary", "glyph": "skull", "cost": 22,
		"text": "Implosion drags from 13 m (was 9.5). Wake lingers 5 s (was 3) over a wider field.",
		"lore": "The reliquary holds more than one count. Open it further."},
	{"id": "count", "needs": "abbot_crown", "name": "The Count", "glyph": "crown", "cost": 20,
		"text": "Every Mark Umbral Nova detonates takes 0.6 s off its recovery.",
		"lore": "Osric never lost count. Neither will you."},
	{"id": "sky", "needs": "ascension_seal", "name": "Open Sky", "glyph": "sigil", "cost": 40,
		"text": "Every spell recovers 15% sooner, and you hold 20 more Gloom.",
		"lore": "The door is shut. What it was holding back is yours to spend."},
]

## Charms (ItemDB kind "charm"): effect per charm, applied while worn.
const CHARM_FX := {
	"charm_candle": {"dark_mult": 0.9},
	"charm_thread": {"step_range": 1.5},
	"charm_lampglass": {"ward_life": 2.0},
	"charm_bead": {"kill_relief": 2.0},
	"charm_clapper": {"power": 0.08},
	"charm_ring": {"lance_charge": 0.85},
	# elite bounties (encounters system pays them out; they are never laid in the world)
	"hobbs_knuckles": {"lash_power": 0.25},
	"lisles_tally": {"mark_dmg": 0.25},
	"briar_antler": {"step_briar": 1.0},
	"heart_stone": {"gloom_add": 10.0, "lit_mult": 1.15},
	"cinder_censer": {"lance_blast": 0.6},
	"scraped_face": {"cd": -0.05},
	# build charms (found in the world): each bends a spell toward a way of fighting
	"charm_hook": {"hook": 1.0},
	"charm_rosary": {"rosary": 1.0},
	"charm_jar": {"jar": 1.0},
	# quest charms (the village's quests award them; never laid in the world)
	"charm_ferrule": {"step_cd": 0.8, "ferrule": 1.0},
	"charm_waystone": {"ward_life": 1.5, "well_life": 1.5},
	"charm_chalk": {"chalk": 1.0},
}
## Charms the village's quests award (core/story, agent E): who gives them, shown while unearned.
const QUEST_CHARMS := {
	"charm_ferrule": "Quest: Hild, at the forge",
	"charm_waystone": "Quest: Oswin, on the Pilgrims' Road",
	"charm_chalk": "Quest: the Kindled Keg's missing ale",
}
## Charms won from the encounters system's elites: where the bounty walks (shown while unclaimed).
const ELITE_CHARMS := {
	"hobbs_knuckles": "Bounty: Hobb, Who Knocks Thrice, on the east road",
	"lisles_tally": "Bounty: Brother Lisle, the Counted, on the fen descent",
	"briar_antler": "Bounty: the Briar Hart, in the deep Thornwood",
	"heart_stone": "Bounty: Old Sunk, Three Stones, in the south fen pools",
	"cinder_censer": "Bounty: the Cinder Cantor, on the Rift's rim",
	"scraped_face": "Bounty: the Faceless Penitent, in the Deeper Night",
}
## Where each charm lies (x, z on the Realm map), and the region named while it is still lost.
const CHARM_SPOTS := {
	"charm_candle": {"at": Vector2(-20.6, 46.6), "where": "Hearthward, by Maud's window"},
	"charm_thread": {"at": Vector2(-42.0, 20.5), "where": "the Shrine of the Lost"},
	"charm_lampglass": {"at": Vector2(76.0, 8.0), "where": "the Hollow Fen, by the drowned graves"},
	"charm_bead": {"at": Vector2(85.0, -51.0), "where": "the Barrow Field, by the lay brothers' lodge"},
	"charm_clapper": {"at": Vector2(-10.5, 6.0), "where": "the Rift's rim, near the Last Bell"},
	"charm_ring": {"at": Vector2(-96.0, 42.0), "where": "the Thornwood, at the woodcutter's hut"},
	"charm_hook": {"at": Vector2(58.0, -20.0), "where": "the Hollow Fen, where the ferry rope still hangs"},
	"charm_rosary": {"at": Vector2(-64.0, 46.0), "where": "the Chapel of the First Kindling"},
	"charm_jar": {"at": Vector2(-56.0, -36.0), "where": "the Thornwood, below the henge"},
}
const BASE_SLOTS := 2
const GearStats := preload("res://core/items/gear_stats.gd")   # gear: the one hook (mods, below)


static func ember(id: String) -> Dictionary:
	for e: Dictionary in EMBERS:
		if e.id == id:
			return e
	return {}


static func spell(id: String) -> Dictionary:
	for s: Dictionary in SPELLS:
		if s.id == id:
			return s
	return {}


static func core(id: String) -> Dictionary:
	for c: Dictionary in CORES:
		if String(c.id) == id:
			return c
	return {}


## A spell that is learned at the Kindling before it can be ranked or slotted.
static func learnable(id: String) -> bool:
	return spell(id).has("learn")


## r35: the stock spells after Rift Bolt are taught by the story (kindling.gd teach(): the Keep,
## the first kill, the first seal, the first great one). Progression state "taught" holds them; a
## save from before staging (no "taught" key) knows all four. zz/ harness scenes know all four too,
## unless one opts in to staging with Engine meta "staged_spells".
const TAUGHT_LATER := ["lance", "nova", "ward", "step"]


static func taught(st: Dictionary) -> Array:
	var t: Variant = st.get("taught", null)
	if not (t is Array) or _harness_all():
		return TAUGHT_LATER.duplicate()
	var out: Array = []
	for id: String in TAUGHT_LATER:
		if (t as Array).has(id):
			out.append(id)
	return out


static func _harness_all() -> bool:
	if Engine.has_meta(&"staged_spells"):
		return false
	var tree := Engine.get_main_loop() as SceneTree
	var cs := tree.current_scene if tree else null
	return cs != null and cs.scene_file_path.begins_with("res://zz/")


## Spells the wanderer can cast: Rift Bolt, the stock spells the story has taught, and any learned.
static func known(st: Dictionary) -> Array:
	var out: Array = ["bolt"] + taught(st)
	var k: Variant = st.get("known", [])
	if k is Array:
		for id: Variant in k:
			if not out.has(String(id)) and not spell(String(id)).is_empty():
				out.append(String(id))
	return out


static func knows(st: Dictionary, id: String) -> bool:
	return known(st).has(id)


## The four swappable hotbar slots (1..4), validated: unknown or doubled ids fall back.
static func loadout(st: Dictionary) -> Array:
	var raw: Variant = st.get("loadout", [])
	var out: Array = []
	var k := known(st)
	for i in 4:
		var id := String((raw as Array)[i]) if raw is Array and i < (raw as Array).size() else ""
		if id == "" or id == "bolt" or not k.has(id) or out.has(id):
			id = ""
		out.append(id)
	# fill gaps with the defaults first, then anything known and unslotted
	for i in 4:
		if out[i] != "":
			continue
		for cand: String in [LOADOUT_DEFAULT[i]] + LOADOUT_DEFAULT + k:
			if cand != "bolt" and k.has(cand) and not out.has(cand):
				out[i] = cand
				break
	return out


## The core in the orb ("" = the Hollow Core). Only an owned core counts.
static func core_of(st: Dictionary) -> String:
	var c := String(st.get("core", ""))
	if c == "" or core(c).is_empty() or Travel.count(c) <= 0:
		return ""
	return c


static func rite(id: String) -> Dictionary:
	for r: Dictionary in RITES:
		if r.id == id:
			return r
	return {}


static func oath_tier(tier: int) -> Dictionary:
	for o: Dictionary in OATHS:
		if int(o.tier) == tier:
			return o
	return {}


static func rank(st: Dictionary, id: String) -> int:
	return int((st.get("ranks", {}) as Dictionary).get(id, 0))


static func oath(st: Dictionary, tier: int) -> String:
	return String((st.get("oaths", {}) as Dictionary).get(str(tier), ""))


static func has_oath(st: Dictionary, oath_id: String) -> bool:
	for o: Dictionary in OATHS:
		var pick := oath(st, int(o.tier))
		if pick != "" and String((o[pick] as Dictionary).id) == oath_id:
			return true
	return false


static func slots(st: Dictionary) -> int:
	return BASE_SLOTS + rank(st, "cord")


static func worn(st: Dictionary) -> Array:
	var w: Variant = st.get("worn", [])
	return w if w is Array else []


## Cost and gate of the next rank of an ember / spell / rite id. {} when maxed.
static func next_of(st: Dictionary, id: String) -> Dictionary:
	var r := rank(st, id)
	var e := ember(id)
	if not e.is_empty():
		if r >= int(e.max):
			return {}
		return {"cost": int(e.cost[r]), "gate": int(e.gate[r]), "rank": r + 1}
	if not spell(id).is_empty():
		if r >= 3:
			return {}
		return {"cost": int(SPELL_COST[r]), "gate": int(SPELL_GATE[r]), "rank": r + 1}
	var ri := rite(id)
	if not ri.is_empty():
		if r >= 1:
			return {}
		return {"cost": int(ri.cost), "gate": 0, "rank": 1, "needs": String(ri.needs)}
	return {}


## Everything the save buys, as numbers the runtime and the skills apply.
static func mods(st: Dictionary) -> Dictionary:
	var m := {
		"power": 1.0 + 0.1 * rank(st, "will"),
		"cd": 1.0 - 0.07 * rank(st, "quick"),
		"gloom_add": 15.0 * rank(st, "warmth"),
		"dark_mult": 1.0 - 0.12 * rank(st, "banked"),
		"lit_mult": 1.0,
		"kill_relief": 0.0,
		"step_range": 0.0,
		"ward_life": 0.0,
		"lance_charge": 1.0,
		"lance_blast": 0.0,
		"lash_power": 1.0,
		"mark_dmg": 0.0,
		"step_briar": false,
		"lash_every": 3,
		"pyre": false, "tally": false, "door": false,
		"bramble": rank(st, "bramble") > 0,
		"deep": rank(st, "deep") > 0,
		"count": rank(st, "count") > 0,
		"core": core_of(st),
		"hook": false, "rosary": false, "jar": false, "ferrule": false, "chalk": false,
		"step_cd": 1.0, "well_life": 0.0,
	}
	for s: Dictionary in SPELLS:
		m[String(s.id)] = rank(st, String(s.id))
	if rank(st, "sky") > 0:
		m.cd -= 0.15
		m.gloom_add += 20.0
	if has_oath(st, "hearth"):
		m.lit_mult = 1.6
	if has_oath(st, "hollow"):
		m.kill_relief += 4.0
	if has_oath(st, "lash"):
		m.lash_every = 2
	if has_oath(st, "pyre"):
		m.pyre = true
		m.lance_charge *= 0.7
	if has_oath(st, "tally"):
		m.tally = true
	if has_oath(st, "door"):
		m.door = true
	for c in worn(st):
		if Travel.count(String(c)) <= 0:
			continue
		var fx: Dictionary = CHARM_FX.get(String(c), {})
		m.dark_mult *= float(fx.get("dark_mult", 1.0))
		m.step_range += float(fx.get("step_range", 0.0))
		m.ward_life += float(fx.get("ward_life", 0.0))
		m.kill_relief += float(fx.get("kill_relief", 0.0))
		m.power += float(fx.get("power", 0.0))
		m.lance_charge *= float(fx.get("lance_charge", 1.0))
		m.lance_blast += float(fx.get("lance_blast", 0.0))
		m.lash_power += float(fx.get("lash_power", 0.0))
		m.mark_dmg += float(fx.get("mark_dmg", 0.0))
		m.gloom_add += float(fx.get("gloom_add", 0.0))
		m.lit_mult *= float(fx.get("lit_mult", 1.0))
		m.cd += float(fx.get("cd", 0.0))
		if float(fx.get("step_briar", 0.0)) > 0.0:
			m.step_briar = true
		m.step_cd *= float(fx.get("step_cd", 1.0))
		m.well_life += float(fx.get("well_life", 0.0))
		for flag: String in ["hook", "rosary", "jar", "ferrule", "chalk"]:
			if float(fx.get(flag, 0.0)) > 0.0:
				m[flag] = true
	GearStats.apply(m)   # gear (core/items/gear_stats.gd): worn gear folds in here, last
	return m


## A modifier from the live table, or `d` before the runtime has filled it.
static func get_mod(key: String, d: Variant) -> Variant:
	return live.get(key, d)


## Number of things owned: every rank, rite and oath (a coarse power level for other systems).
static func tier_of(st: Dictionary) -> int:
	var n := 0
	for k in (st.get("ranks", {}) as Dictionary):
		n += int(st.ranks[k])
	n += (st.get("oaths", {}) as Dictionary).size()
	n += known(st).size() - STOCK.size()
	return n

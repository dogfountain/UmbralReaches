extends RefCounted
## East Marches: the tasks of Saltmarket and the Lamplighters' Spire (docs/r37_expansion.md), in the
## quest_chains.gd manner (one const a task; the shared tables list them in their `# --- east ---`
## blocks). Existing step kinds only: slay (rares), carry, cond, gather, turnin.
##
##   salt_sweep    Dead Men's Salt (Marl)       six of the hollowed that walk the White Pans
##   salt_widow    The Salt-Widow (Marl)        a named rare of the pans
##   spire_coal    The Lamplighters' Coal (Ardel)  carry a coal from the hamlet's fire up the Spire and light the
##                                              great lamp (the lamp is the player's to light: pillar 2)
##   anchor_names  Names From the Rock (Teasel)  three cell-slates in the Anchorholds
##   anchor_vow    The Vow Unbroken (Teasel)    the Anchoress, on the cliff terrace
## House style (docs/LORE.md): terse, concrete, dark.

const DeepB := preload("res://core/story/quest_chains_deepen_b.gd")   ## the deepened tasks (docs/QUEST_DEPTH.md)
const SALT_SWEEP := {"name": "Dead Men's Salt", "giver": "marl", "where": "Marl Pannick, at Saltmarket's fire", "zone": "saltmarket",
	"offer": true,
	"text": "The pans don't stop for a night or a Night. Salt comes up white or it comes up wrong, and lately it comes up with footprints in it. They walk out of the flats at dusk, the ones who raked too long. Put six of them down so my people can rake in peace.",
	"steps": [
		{"kind": "slay", "of": 6, "region": "saltpans", "label": "Pan-walkers", "at": Vector2(228.0, 168.0),
			"text": "Put down the hollowed walking the White Pans ({n}/{of})"},
		{"kind": "turnin", "who": "marl", "text": "Tell Marl the pans are quiet"},
	],
	"reward": {"ash": 14},
	"choose": [{"slot": "lantern", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
	"outcome": {"": "Marl salted the doorstep, which is what Saltmarket does instead of saying thank you."}}

const SALT_WIDOW := DeepB.SALT_WIDOW        ## deepened: quest_chains_deepen_b.gd

const SPIRE_COAL := DeepB.SPIRE_COAL        ## deepened: quest_chains_deepen_b.gd

const ANCHOR_NAMES := {"name": "Names From the Rock", "giver": "teasel", "where": "Teasel Dray, at the drying shed", "zone": "anchorholds",
	"offer": true,
	"text": "My sister Wren went into the Anchorholds with the hermits, to pray. They walled her in with the rest. Each cell had a slate by the door: a name, a count of days. Bring me what's written. I'd like to know how long she lasted. I'd like to know it wasn't the full count.",
	"steps": [
		{"kind": "gather", "of": 3, "text": "Find the three cell-slates in the Anchorholds: the scree, the lower cells, the cliff chapel's steps ({n}/{of})"},
		{"kind": "turnin", "who": "teasel", "text": "Bring the slates to Teasel"},
	],
	"reward": {"ash": 20, "items": {"relic_fragment": 1}},
	"choose": [{"slot": "vestment", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
	"outcome": {"": "Teasel read them all twice. Wren's said: SEVEN DAYS, AND THEN I HEARD THE BELL. She folded the slate away and did not say what bell."}}

const ANCHOR_VOW := {"name": "The Vow Unbroken", "giver": "teasel", "where": "Teasel Dray, at the drying shed", "zone": "anchorholds",
	"offer": true, "avail": "qd:anchor_names",
	"text": "The one who walled them in is still up there. The Anchoress. She took the vow first and she keeps it hardest: no door, no sky, no leaving. The rest came out, hollow, when the wall cracked. She stayed. Go up to the terrace and tell her the vow's done.",
	"steps": [
		{"kind": "cond", "cond": "boss:r37_anchoress", "past": "The Anchoress is already at rest.", "at": Vector2(214.0, -132.0),
			"text": "Put the Anchoress to rest on the Anchorholds' cliff terrace"},
		{"kind": "turnin", "who": "teasel", "text": "Tell Teasel the vow is done"},
	],
	"reward": {"ash": 30, "items": {"relic_fragment": 2}},
	"choose": [{"slot": "focus", "rarity": 3}, {"slot": "girdle", "rarity": 3}, {"slot": "vestment", "rarity": 3}],
	"outcome": {"": "Teasel went out at dawn to the foot of the cliff and stood where the anchor chain used to hang. She didn't say anything. She stayed until the wind turned."}}

const COAL_ARDEL := {"quest": "spire_coal", "step": 0, "near": Vector2(218.0, 98.0), "camp": "ardel", "kind": "coal", "name": "a lamplighter's coal", "verb": "Take",
	"say": "A coal from the hamlet's fire, in an iron dish with a handle worn smooth by Ardel's own hand. It burns steady. It wants a wick. Go."}
const PAGE_A := {"quest": "anchor_names", "step": 0, "near": Vector2(184.0, -98.0), "kind": "slate", "name": "a cell-slate", "verb": "Read",
	"say": "A slate propped against a cell door, scree up to its sill. A name that is not Wren's, and a count: ELEVEN DAYS. The eleventh is scratched twice, as if the hand was shaking."}
const PAGE_B := {"quest": "anchor_names", "step": 0, "near": Vector2(222.0, -100.0), "kind": "slate", "name": "a cell-slate", "verb": "Read",
	"say": "A slate in the lower cells, face down in the dust. WREN OF SALTMARKET. SEVEN DAYS, AND THEN I HEARD THE BELL. Under it, in a harder hand: she did not hear it. There was no bell."}
const PAGE_C := {"quest": "anchor_names", "step": 0, "near": Vector2(204.0, -102.0), "kind": "slate", "name": "a cell-slate", "verb": "Read",
	"say": "The last slate, at the foot of the chapel steps, the day-count run on past the slate's edge onto the stone. Whoever cut it did not stop. The wall is cut with days."}

extends RefCounted
## The Star-Fall Crater (core/world/realm/wonders/star_crater.gd, in the White Pans): one task from Saltmarket, in the
## quest_chains.gd manner. Existing step kinds only: visit, gather (a pickup), cond (the secret), turnin.
##
##   star_lamp   What the Surveyor Left (Marl)   walk out to the Lamp, find the surveyors' stake-book on the glass,
##                                               climb the slabs to the platform under the star and open the case
## The lead adds to the shared tables:
##   QUESTS   "star_lamp": StarCrater.STAR_LAMP      (after "salt_widow" in ORDER, in the `# --- east ---` block)
##   PICKUPS  STAR_BOOK                              (quest "star_lamp", step 1)
## House style (docs/LORE.md): terse, concrete, dark.

const STAR_LAMP := {"name": "What the Surveyor Left", "giver": "marl", "where": "Marl Pannick, at Saltmarket's fire", "zone": "saltpans",
	"offer": true, "avail": "qd:salt_sweep",
	"text": "Out on the pans there's a light that never goes down. The Order's man, Ostric, came to measure it the year it fell and never came back to say what he'd measured. We call it the Lamp. It stands in a ring of glass a few hundred paces off the track. Bring me what Ostric kept. I'd like to know if he's still counting.",
	"steps": [
		{"kind": "visit", "at": Vector2(178.0, 146.0), "r": 16.0, "label": "The Star-Fall", "text": "Walk out onto the White Pans to the Lamp: a crater of black glass, west of the salt track"},
		{"kind": "gather", "of": 1, "text": "Find the surveyors' stake-book on the glass floor ({n}/{of})"},
		{"kind": "cond", "cond": "secret:looted:star_crater", "at": Vector2(178.0, 146.0), "label": "The Fallen Star",
			"past": "Ostric's case has already been opened.",
			"text": "Climb the glass slabs to the platform under the star and open Ostric's case"},
		{"kind": "turnin", "who": "marl", "text": "Take what Ostric kept back to Marl"},
	],
	"reward": {"ash": 26, "items": {"relic_fragment": 1}},
	"choose": [{"slot": "focus", "rarity": 2}, {"slot": "lantern", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
	"outcome": {"": "Marl read the slate by the fire and then held it a while without reading. \"It's not a wound,\" he said. \"I told them it was not a wound.\" He put it on the shelf above the salt, where the good things go."}}

const STAR_BOOK := {"quest": "star_lamp", "step": 1, "near": Vector2(176.0, 153.0), "kind": "book", "name": "the surveyors' stake-book", "verb": "Take",
	"say": "A leather book, fused half into the glass and warm as a hand. Stakes, depths, a column of dates that stops at the first turning. The last page is only one word, over and over: UP."}

extends RefCounted
## The Pilgrims' Threshold (core/world/realm/rift/threshold.gd): the task that leads the player to the Pilgrims' Chapel
## at the foot of the pilgrims' stair, cut into the rift's west wall (core/world/realm/rift/chapel.gd; the Cinder Way). In the quest_chains.gd manner; the lead lists
## THRESHOLD_CHAPEL in QUESTS and ORDER (the `rift` ledger chapter, after the crossing's tasks) and nothing else: there
## are no pickups (the reward is the secret's own reliquary and the page cut into the kneeling stone).
##
##   threshold_chapel  The Pilgrims' Chapel (Joram)  Joram was told at the first fire of a chapel the pilgrims cut
##                                                    at the last cool stone before the crossing; the player goes down the
##                                                    Descent off the rim to the Foot, takes the branch along the wall, and opens the reliquary
## Chapel: the chamber's middle is ChapelKit ORIGIN + 3 m into the wall: (-17.4, -12, -36.85). The reliquary is the
## secret `last_landing` (core/life/secrets/site_threshold.gd: State "looted"). Existing step kinds only.
## House style (docs/LORE.md): terse, concrete, dark.

const CHAPEL := Vector2(-17.4, -36.85) + Endgame.O2       ## (the Threshold stands in the far north-east: Endgame)

const THRESHOLD_CHAPEL := {"name": "The Pilgrims' Chapel", "giver": "oswin", "where": "Joram, a pilgrim, at Hearthward", "zone": "rift",
	"offer": true,
	"text": "They told us at the first fire the pilgrims cut a chapel at the bottom of the rift, where the stair comes down off the rim and the fire has gone to crust. Not the Order's, theirs: the last cool stone before the crossing. A path goes off along the wall to its door. What they carried over they left on the stone first. Go and see it's still there. Leave a candle.",
	"steps": [
		{"kind": "visit", "at": CHAPEL, "r": 1.8, "label": "The Pilgrims' Chapel",
			"text": "Take the pilgrims' stair down off the rim to its foot, and the path along the west wall to the chapel's door"},
		{"kind": "cond", "cond": "secret:looted:last_landing", "at": CHAPEL, "label": "The pilgrims' reliquary", "past": "The reliquary is already open.",
			"text": "Open the pilgrims' reliquary, and read the kneeling stone"},
		{"kind": "turnin", "who": "oswin", "text": "Tell Joram what the chapel holds"},
	],
	"reward": {"ash": 22, "items": {"relic_fragment": 1}},
	"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
	"outcome": {"": "Joram held the page a long time and did not read it aloud. \"They left their names,\" he said. \"I thought there would be more light.\""}}

const QUESTS := {"threshold_chapel": THRESHOLD_CHAPEL}
const ORDER := ["threshold_chapel"]

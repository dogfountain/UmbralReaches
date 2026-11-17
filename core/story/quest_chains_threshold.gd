extends RefCounted
## The Pilgrims' Threshold (core/world/realm/rift/threshold.gd): the task that leads the player to the Pilgrims' Chapel
## under the west wall's starfall (core/world/realm/rift/chapel.gd). In the quest_chains.gd manner; the lead lists
## THRESHOLD_CHAPEL in QUESTS and ORDER (the `rift` ledger chapter, after the crossing's tasks) and nothing else: there
## are no pickups (the reward is the secret's own reliquary and the page cut into the kneeling stone).
##
##   threshold_chapel  The Pilgrims' Chapel (Joram)  Joram was told at the first fire of a chapel the pilgrims cut
##                                                    where the light falls into the starwater; the player goes down the
##                                                    Pilgrims' Stair round the crossing's third tower and the quay, through the falling light, and opens the reliquary
## Chapel: the chamber's middle is ChapelKit ORIGIN + 3 m into the wall: (-17.4, -12, -36.85). The reliquary is the
## secret `last_landing` (core/life/secrets/site_threshold.gd: State "looted"). Existing step kinds only.
## House style (docs/LORE.md): terse, concrete, dark.

const CHAPEL := Vector2(-17.4, -36.85) + Endgame.O2       ## (the Threshold stands in the far north-east: Endgame)

const THRESHOLD_CHAPEL := {"name": "The Pilgrims' Chapel", "giver": "oswin", "where": "Joram, a pilgrim, at Hearthward", "zone": "rift",
	"offer": true,
	"text": "They told us at the first fire the pilgrims cut a chapel where the light falls into the starwater. Not the Order's, theirs. There is a stair wound round the third tower of the crossing, down to the water, and a quay along the wall. The light comes down across the door like a curtain, and you walk through it. What they carried down they left on the stone. Go and see it's still there. Leave a candle.",
	"steps": [
		{"kind": "visit", "at": CHAPEL, "r": 1.8, "label": "The Pilgrims' Chapel",
			"text": "Take the stair round the crossing's third tower down to the starwater, follow the quay, and step through the light into the chapel"},
		{"kind": "cond", "cond": "secret:looted:last_landing", "at": CHAPEL, "label": "The pilgrims' reliquary", "past": "The reliquary is already open.",
			"text": "Open the pilgrims' reliquary, and read the kneeling stone"},
		{"kind": "turnin", "who": "oswin", "text": "Tell Joram what the chapel holds"},
	],
	"reward": {"ash": 22, "items": {"relic_fragment": 1}},
	"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
	"outcome": {"": "Joram held the page a long time and did not read it aloud. \"They left their names,\" he said. \"I thought there would be more light.\""}}

const QUESTS := {"threshold_chapel": THRESHOLD_CHAPEL}
const ORDER := ["threshold_chapel"]

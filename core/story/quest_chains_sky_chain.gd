extends RefCounted
## The Sky Chain (core/world/realm/wonders/sky_chain.gd): Elspeth Fane, the Founder's journeywoman at the Pits, was
## taught the count of the links by the Founder himself and has never seen the end of it. She sends the player
## up the anchor's stair to read the wardens' tally at the bitter end. House style (docs/LORE.md): terse, dark.
##
##   chain_count   The Count of Links (Elspeth)   climb the anchor's stair, read the tally stone at the bitter end,
##                                                 tell her what it says (the box at the tally is the site's secret)
## The lead lists "chain_count" in quest_chains.gd's QUESTS (a block marked `# --- sky chain ---`), after "founder_clapper"
## in ORDER, and merges PICKUPS below into quest_chains.gd's PICKUPS.

const CHAIN_COUNT := {"name": "The Count of Links", "giver": "elspeth", "where": "Elspeth Fane, at her fire in the Founder's Pits", "zone": "crags",
	"offer": true, "avail": "qd:founder_slag",
	"text": "The Founder cast the chain in these pits and counted every link aloud as it cooled: a thousand and nine. I carried the tongs. He made me swear to see it counted again when it was done. I never went up. Climb the anchor's stair, west of here under the Crowns, and read what the wardens cut at the bitter end. Come back and tell me the number.",
	"steps": [
		{"kind": "visit", "at": Vector2(62.0, -118.0), "r": 9.0, "label": "The Sky Chain's anchor",
			"text": "Go to the foot of the Sky Chain's anchor, under the Crowns west of the Pits"},
		{"kind": "find", "text": "Climb the stair to the deck and read the wardens' tally at the bitter end"},
		{"kind": "turnin", "who": "elspeth", "text": "Tell Elspeth Fane the count"},
	],
	"reward": {"ash": 22, "items": {"relic_fragment": 1}},
	"choose": [{"slot": "focus", "rarity": 2}, {"slot": "girdle", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
	"outcome": {"": "Elspeth said the number over twice, the way you test a coin. \"One short,\" she said. \"He used to say the sky would take one back. I thought it was a joke.\""}}

const PICKUPS := {
	"chain_tally": {"quest": "chain_count", "step": 1, "near": Vector2(92.6, -129.5), "kind": "slate", "name": "the wardens' tally", "verb": "Read",
		"say": "A stone at the bitter end, cut in tallies of five, row on row. ONE THOUSAND AND NINE, and under it in a newer hand: counted again, one short. Counted again. One short."},
}

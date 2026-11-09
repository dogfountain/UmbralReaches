extends RefCounted
## The Upward Falls (core/world/realm/wonders/upward_falls.gd): one task from Weirford's miller, in the
## quest_chains.gd manner (data only, no class_name). The lead lists it in quest_chains.gd's west-marches blocks:
##   QUESTS    "wf_upward": R37UF.QUESTS.wf_upward     ORDER   after "wf_wheel" (Osk's second task)
##   PICKUPS   "wf_gauge": R37UF.PICKUPS.wf_gauge
##   wf_upward The Water Goes Up (Osk the miller): the mill's head is falling because the river is leaving upstream.
##             Find the hydrographers' gauge at the weir's foot, climb the broken stair and stand in the spray.
## House style (docs/LORE.md): terse, concrete, dark.

const QUESTS := {
	"wf_upward": {"name": "The Water Goes Up", "giver": "osk", "where": "Osk the miller, at the weir mill", "zone": "sorrow",
		"offer": true, "avail": "qd:wf_wheel",
		"text": "The wheel turns, but the head's dropping a finger a week. The river isn't going dry. It's going somewhere. Below the drowned shrine the Order built a weir that taught the water to climb, and it climbs yet. The hydrographers left a gauge at its foot. Bring it down, and then go up their stair and see where my river goes.",
		"steps": [
			{"kind": "visit", "at": Vector2(-207.0, -8.0), "r": 12.0, "label": "The Upward Falls", "text": "Follow the Sorrow upstream to the Order's weir"},
			{"kind": "find", "text": "Find the hydrographers' gauge at the weir's foot"},
			{"kind": "cond", "cond": "secret:found:upward_falls", "at": Vector2(-207.0, -18.0), "label": "The weir's deck", "past": "You have already stood in the spray.",
				"text": "Climb the hydrographers' stair, three torn flights on the west face, and stand in the spray"},
			{"kind": "turnin", "who": "osk", "text": "Tell Osk where the river goes"},
		],
		"reward": {"ash": 26, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "focus", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"outcome": {"": "Osk read the gauge twice and set it on the sill by the wheel. \"Up,\" he said. \"All of it, up.\" He listened to the water under the floor a while. \"Then it'll come down somewhere. It has to. Everything does.\""}},
}

const PICKUPS := {
	"wf_gauge": {"quest": "wf_upward", "step": 1, "near": Vector2(-198.0, -6.0), "kind": "mark", "name": "the hydrographers' gauge", "verb": "Take",
		"say": "A brass staff scored in hands and fingers, laid in the shallows below the weir as if set down for a moment. The top mark reads WATER, and under it, in a surveyor's cramped hand: NOT FALLING. RISING. DO NOT CHART."},
}

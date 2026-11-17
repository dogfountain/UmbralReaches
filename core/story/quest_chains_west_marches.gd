extends RefCounted
## West Marches: four chains from Weirford (data only, no class_name; the shared tables in
## quest_chains.gd take these in their west-marches blocks). Step kinds as quest_chains.gd's header.
##   wf_wheel   The Stopped Wheel (Osk the miller): put down the Drowned Reeve, bring the sluice key from the drowned shrine
##   wf_watch   The Lamp on the Lines (Captain Cassel): carry a signal lamp to the siege tower, put down the Gate-Breaker
##   wf_lights  Lights for the Sunk (Sister Ennis): three votive boats off the banks, set at the drowned shrine
##   wf_crown   The Voice in the Head (Old Tolliver): three rubbings off the colossus, then silence the Speaking Crown
## House style (docs/LORE.md): terse, concrete, dark.

const DeepB := preload("res://core/story/quest_chains_deepen_b.gd")   ## the deepened tasks (docs/QUEST_DEPTH.md)
const ZONES := [["weirford", "Weirford"], ["sorrow", "The Sorrow's Banks"], ["plinth", "The Empty Plinth"], ["siege", "The Siege Lines"]]

const ORDER := ["wf_wheel", "wf_watch", "wf_lights", "wf_crown"]

const GIVER_NAMES := {"osk": "Osk the miller", "cassel": "Captain Cassel", "ennis": "Sister Ennis", "tolliver": "Old Tolliver",
	"dorrit": "Dorrit Marl", "bryn": "Bryn Gale", "wren": "Sedge", "gwyn": "Gwyn the ostler"}

const RARE_IDS := ["drowned_reeve", "moss_mason", "gate_breaker"]

const QUESTS := {
	"wf_wheel": {"name": "The Stopped Wheel", "giver": "osk", "where": "Osk the miller, at the weir mill", "zone": "weirford",
		"offer": true,
		"text": "The wheel has turned nine winters because the river would not let it stop. Now the sluice-gate is seized in its frame, the drowned have their hands in the fords above, and their Reeve walks the bank collecting tolls nobody owes. Osk grinds the town's barley, not the abbey's flour, and the town is running out.",
		"steps": [
			{"kind": "slay", "of": 1, "rares": ["drowned_reeve"], "label": "The Drowned Reeve", "at": Vector2(-224.0, -28.0),
				"text": "Put down the Drowned Reeve, on his beat along the Sorrow's west bank"},
			{"kind": "find", "text": "Take the sluice key from the drowned shrine in the Sorrow"},
			{"kind": "turnin", "who": "osk", "text": "Bring the sluice key to Osk at the weir mill"},
		],
		"reward": {"ash": 16, "items": {"grave_iron": 1}},
		"choose": [{"slot": "focus", "rarity": 1}, {"slot": "girdle", "rarity": 1}],
		"outcome": {"": "Osk threw the sluice and the wheel took the weight. He stood and listened to it for a minute. What he said was the price of flour."}},
	"wf_watch": {"name": "The Lamp on the Lines", "giver": "cassel", "where": "Captain Cassel, at the Weirford watch post", "zone": "weirford",
		"offer": true,
		"text": "The Marches' war-band never stood down, and nobody at Weirford has seen the Lines in nine years. Cassel will not send four men to count them. He will send a lamp: carried to the top of the siege tower and left burning, so that whatever is out there knows it is being watched. The Gate-Breaker walks the outer earthwork between the lamp and the road home.",
		"steps": [
			{"kind": "find", "text": "Take a lit signal lamp from the rack at the Weirford watch post"},
			{"kind": "carry", "from": "wf_signal_lamp", "to": Vector2(-172.0, 128.0), "r": 7.0, "time": 200.0, "label": "Signal lamp",
				"lost": "The signal lamp has gone out. Cassel's rack has another.",
				"text": "Carry the signal lamp to the siege tower in the Siege Lines before it dies ({t} s)"},
			{"kind": "slay", "of": 1, "rares": ["gate_breaker"], "label": "The Gate-Breaker", "at": Vector2(-241.0, 142.0),
				"text": "Put down the Gate-Breaker, on its round of the earthwork"},
			{"kind": "turnin", "who": "cassel", "text": "Tell Captain Cassel the lamp is on the Lines"},
		],
		"reward": {"ash": 22},
		"choose": [{"slot": "vestment", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"": "Cassel climbed to the post's roof that night and looked south for a long time. \"There,\" he said, to nobody. \"That's a lamp.\""}},
	"wf_lights": DeepB.WF_LIGHTS,
	"wf_crown": DeepB.WF_CROWN,
}

const PICKUPS := {
	"wf_sluice_key": {"quest": "wf_wheel", "step": 1, "near": Vector2(-208.0, -37.8), "kind": "mark", "name": "the sluice key", "verb": "Take",
		"say": "An iron key as long as a forearm, wedged between two stones of the shrine's plinth. OSK, scratched on the bow. The river has worn it smooth and left it exactly where a miller would look."},
	"wf_signal_lamp": {"quest": "wf_watch", "step": 0, "near": Vector2(-228.0, 67.0), "kind": "lantern_lit", "name": "a signal lamp", "verb": "Take",
		"say": "A hooded lamp on the Watch's rack, filled and lit, the flame leaning south as though it knew. Cassel's mark on the hood. Go."},
	"wf_rub_hand": {"quest": "wf_crown", "step": 0, "near": Vector2(-231.1, 189.9), "kind": "page", "name": "an edict, on the thumb", "verb": "Rub",
		"say": "Cut in the thumb's side, in the Order's square hand, backwards: THE FIRST EDICT. LET NONE LOOK DOWN. You take it on a leaf of bark with the heel of a coal. It comes up black and perfect."},
	"wf_rub_shoulder": {"quest": "wf_crown", "step": 0, "near": Vector2(-183.3, 174.0), "kind": "page", "name": "an edict, on the shoulder", "verb": "Rub",
		"say": "Along the collar of the stone cope, the Second: LET NONE SPEAK BUT THROUGH ME. The mason ran out of room and the last word is carved on the fold below, where nobody would read it."},
	"wf_rub_lip": {"quest": "wf_crown", "step": 0, "near": Vector2(-191.1, 152.9), "kind": "page", "name": "an edict, on the lip", "verb": "Rub",
		"say": "Cut small along the jaw's rim, almost under the moss: THE THIRD. HOLD THE NOTE. There is a child's thumbprint in the wet stone at the end of the line, a long time dry."},
}

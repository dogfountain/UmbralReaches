extends RefCounted
## West Marches: four chains from Weirford (data only, no class_name; the shared tables in
## quest_chains.gd take these in their west-marches blocks). Step kinds as quest_chains.gd's header.
##   wf_wheel   The Stopped Wheel (Osk the miller): put down the Drowned Reeve, bring the sluice key from the drowned shrine
##   wf_watch   The Lamp on the Lines (Captain Cassel): carry a signal lamp to the siege tower, put down the Gate-Breaker
##   wf_lights  Lights for the Sunk (Sister Ennis): three votive boats off the banks, set at the drowned shrine
##   wf_crown   The Voice in the Head (Old Tolliver): three rubbings off the colossus, then silence the Speaking Crown
## House style (docs/LORE.md): terse, concrete, dark.

const ZONES := [["weirford", "Weirford"], ["sorrow", "The Sorrow's Banks"], ["hierarch", "The Fallen Hierarch"], ["siege", "The Siege Lines"]]

const ORDER := ["wf_wheel", "wf_watch", "wf_lights", "wf_crown"]

const GIVER_NAMES := {"osk": "Osk the miller", "cassel": "Captain Cassel", "ennis": "Sister Ennis", "tolliver": "Old Tolliver",
	"dorrit": "Dorrit Marl", "bryn": "Bryn Gale", "wren": "Wren", "gwyn": "Gwyn the ostler"}

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
			{"kind": "carry", "from": "wf_signal_lamp", "to": Vector2(-236.0, 170.0), "r": 7.0, "time": 200.0, "label": "Signal lamp",
				"lost": "The signal lamp has gone out. Cassel's rack has another.",
				"text": "Carry the signal lamp to the siege tower in the Siege Lines before it dies ({t} s)"},
			{"kind": "slay", "of": 1, "rares": ["gate_breaker"], "label": "The Gate-Breaker", "at": Vector2(-196.0, 162.0),
				"text": "Put down the Gate-Breaker, on its round of the outer earthwork"},
			{"kind": "turnin", "who": "cassel", "text": "Tell Captain Cassel the lamp is on the Lines"},
		],
		"reward": {"ash": 22},
		"choose": [{"slot": "vestment", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"outcome": {"": "Cassel climbed to the post's roof that night and looked south for a long time. \"There,\" he said, to nobody. \"That's a lamp.\""}},
	"wf_lights": {"name": "Lights for the Sunk", "giver": "ennis", "where": "Sister Ennis, on Weirford Bridge", "zone": "weirford",
		"offer": true,
		"text": "The river took thirty from Weirford the winter the sky turned, and none were buried. Ennis sets a lit boat on the water for each of them every night. Three of the boats are gone: they drifted, or were taken, and lie on the banks above the town. The sunk are counting. They are three short.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Find the three votive boats on the Sorrow's banks ({n}/{of})"},
			{"kind": "place", "text": "Set the boats on the drowned shrine's altar in the river"},
			{"kind": "turnin", "who": "ennis", "text": "Tell Sister Ennis the roll is whole"},
		],
		"reward": {"ash": 18, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "lantern", "rarity": 1}, {"slot": "focus", "rarity": 1}],
		"outcome": {"": "Ennis counted aloud to thirty and her voice did not catch. Then she sat down on the parapet and did not say anything for a long while."}},
	"wf_crown": {"name": "The Voice in the Head", "giver": "tolliver", "where": "Old Tolliver, at the stall in Weirford's square", "zone": "weirford",
		"offer": true, "avail": "qd:wf_wheel",
		"text": "They cut a hollow in the Hierarch's head so that one voice could be heard across the Marches, and sat a boy in it to hold the note. The statue fell. The note did not stop. Tolliver helped cut the hollow, and wants it quiet. He needs three rubbings of the colossus's carved edicts, from the hand, the shoulder and the lip, to know which of them the voice is still speaking. Then someone has to go in.",
		"steps": [
			{"kind": "gather", "of": 3, "text": "Take three rubbings of the Hierarch's edicts: the hand, the shoulder, the lip ({n}/{of})"},
			{"kind": "visit", "at": Vector2(-203.0, -86.0), "r": 7.0, "text": "Stand at the mouth of the skull"},
			{"kind": "cond", "cond": "boss:r37_hierarch", "at": Vector2(-214.0, -104.0), "label": "The Speaking Crown", "past": "The skull is already quiet.",
				"text": "Silence the Speaking Crown, in the Fallen Hierarch's skull"},
			{"kind": "turnin", "who": "tolliver", "text": "Tell Tolliver the horn is quiet"},
		],
		"reward": {"ash": 34, "items": {"relic_fragment": 2}},
		"choose": [{"slot": "focus", "rarity": 3}, {"slot": "vestment", "rarity": 3}, {"slot": "girdle", "rarity": 3}],
		"outcome": {"": "Tolliver held the rubbings a long time, then put them on the stall's fire one by one. \"Nobody should have to read those again,\" he said. \"Least of all the boy.\""}},
}

const PICKUPS := {
	"wf_sluice_key": {"quest": "wf_wheel", "step": 1, "near": Vector2(-208.0, -37.8), "kind": "mark", "name": "the sluice key", "verb": "Take",
		"say": "An iron key as long as a forearm, wedged between two stones of the shrine's plinth. OSK, scratched on the bow. The river has worn it smooth and left it exactly where a miller would look."},
	"wf_signal_lamp": {"quest": "wf_watch", "step": 0, "near": Vector2(-228.0, 67.0), "kind": "lantern_lit", "name": "a signal lamp", "verb": "Take",
		"say": "A hooded lamp on the Watch's rack, filled and lit, the flame leaning south as though it knew. Cassel's mark on the hood. Go."},
	"wf_votive_a": {"quest": "wf_lights", "step": 0, "near": Vector2(-226.0, -6.0), "kind": "lantern", "name": "a votive boat", "verb": "Take",
		"say": "A boat of bark the length of a hand, a stub of tallow in it, beached in the reeds on the west bank. A name has been scratched in the keel, and then scratched out, and then written again."},
	"wf_votive_b": {"quest": "wf_lights", "step": 0, "near": Vector2(-184.0, -30.0), "kind": "lantern", "name": "a votive boat", "verb": "Take",
		"say": "A votive boat on the east bank, snagged in an alder root. It is dry. The tallow is whole. It never lit, and it was never going to be taken by anyone but a river."},
	"wf_votive_c": {"quest": "wf_lights", "step": 0, "near": Vector2(-200.0, 20.0), "kind": "lantern", "name": "a votive boat", "verb": "Take",
		"say": "The last of the three, upside down in the shallows below the ford. Under it the tallow has gone grey and the bark has gone black. Someone small made it."},
	"wf_votive_place": {"quest": "wf_lights", "step": 1, "near": Vector2(-205.0, -40.0), "kind": "place", "name": "the drowned shrine's altar", "verb": "Set the boats on",
		"say": "You set them in a row on the shrine's altar, with the water to your knees. The wicks catch from nothing. For a moment the whole shallows is lit from underneath, and it is not a pleasant light, and it is not a cruel one."},
	"wf_rub_hand": {"quest": "wf_crown", "step": 0, "near": Vector2(-234.0, -82.0), "kind": "page", "name": "an edict, on the thumb", "verb": "Rub",
		"say": "Cut in the thumb's side, in the Order's square hand, backwards: THE FIRST EDICT. LET NONE LOOK DOWN. You take it on a leaf of bark with the heel of a coal. It comes up black and perfect."},
	"wf_rub_shoulder": {"quest": "wf_crown", "step": 0, "near": Vector2(-229.0, -75.0), "kind": "page", "name": "an edict, on the shoulder", "verb": "Rub",
		"say": "Along the collar of the stone cope, the Second: LET NONE SPEAK BUT THROUGH ME. The mason ran out of room and the last word is carved on the fold below, where nobody would read it."},
	"wf_rub_lip": {"quest": "wf_crown", "step": 0, "near": Vector2(-204.0, -92.0), "kind": "page", "name": "an edict, on the lip", "verb": "Rub",
		"say": "Cut small along the jaw's rim, almost under the moss: THE THIRD. HOLD THE NOTE. There is a child's thumbprint in the wet stone at the end of the line, a long time dry."},
}

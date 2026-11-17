extends RefCounted
## The four doors' payoffs (docs/STORY.md "the doors"): a second task at each threshold, offered once the first is handed in. It begins with a watch (the door's
## night after the choice), then the door's answer read as a scene whose words follow the pick made there (three scenes each), and a last choice, take what was
## left or leave it, and the giver's own words for each. Three steps, a vigil, a place and a turn-in; the leaves are the earlier task's. House style
## (docs/LORE.md). Registered through quest_chains_added.gd. No class_name.

const ORDER := ["wr_door_kings_after", "ds_door_castellum_after", "ds_door_witch_after", "er_door_nave_after"]

const QUESTS := {
	"wr_door_kings_after": {"name": "What Came Up the Stair", "giver": "siany", "zone": "westreach", "offer": true, "avail": "qd:wr_door_kings",
		"where": "Siany, at the Reedholm jetty",
		"text": "The door you decided is not finished with you. It has had a night to answer, and it has answered. Go back at dusk, keep the light through one more watch, read what it left, and carry what you will to Siany.",
		"steps": [
			{"kind": "vigil", "at": Vector2(-345.0, 167.0), "r": 9.0, "time": 45.0, "gloom": 0.5, "label": "The King's Barrow door", "noun": "door", "prop": "lantern_lit",
				"waves": [{"at": 10.0, "kinds": ["husk"], "n": 2, "say": "The threshold remembers what you chose, and the dark leans in to see how it holds."}, {"at": 28.0, "kinds": ["gaunt"], "n": 2, "say": "Something on the far side of the door has noticed the quiet, and is considering it."}],
				"held": "The night passes at the door without accident. Something has been laid on the step in the dark.", "away": "Go back to the door. A watch is kept at the place it was set.",
				"text": "Keep one more watch at The King's Barrow door ({t} s)"},
			{"kind": "place", "text": "Read what the door left, and decide whether to carry it away"},
			{"kind": "turnin", "who": "siany", "text": "Tell Siany what the door gave back"},
		],
		"alt": {"take": {2: "Tell Siany you carried it away"}, "leave": {2: "Tell Siany you left it for the door"}},
		"reward": {"ash": 28, "items": {"relic_fragment": 1}},
		"choose": [{"set": "kindler", "slot": "girdle", "rarity": 2}, {"set": "bell", "slot": "lantern", "rarity": 2}],
		"outcome": {"take": "Siany unwrapped the cloth on the jetty and looked at each thing for a long time, and said nothing. 'The Kings paid the lamp-book's debt,' she said at last. 'They always did pay what they owed. I had forgotten.' She wrote an entry, small, and closed the book.",
			"leave": "'You left it.' Siany nodded slowly. 'That is the correct answer. A gift to the dead is the one gift you do not carry home.' She lit the jetty lamp, a second time that night, for no reason she could say.",
			"": "The door gave what it gave, and was left."}},
	"ds_door_castellum_after": {"name": "What the Water Wanted", "giver": "penn", "zone": "deepsouth", "offer": true, "avail": "qd:ds_door_castellum",
		"where": "Reeve Penn, at the tithe barn's porch",
		"text": "The door you decided is not finished with you. It has had a night to answer, and it has answered. Go back at dusk, keep the light through one more watch, read what it left, and carry what you will to Penn.",
		"steps": [
			{"kind": "vigil", "at": Vector2(-60.0, 346.0), "r": 9.0, "time": 45.0, "gloom": 0.5, "label": "The castellum", "noun": "door", "prop": "lantern_lit",
				"waves": [{"at": 10.0, "kinds": ["husk"], "n": 2, "say": "The threshold remembers what you chose, and the dark leans in to see how it holds."}, {"at": 28.0, "kinds": ["gaunt"], "n": 2, "say": "Something on the far side of the door has noticed the quiet, and is considering it."}],
				"held": "The night passes at the door without accident. Something has been laid on the step in the dark.", "away": "Go back to the door. A watch is kept at the place it was set.",
				"text": "Keep one more watch at The castellum ({t} s)"},
			{"kind": "place", "text": "Read what the door left, and decide whether to carry it away"},
			{"kind": "turnin", "who": "penn", "text": "Tell Penn what the door gave back"},
		],
		"alt": {"take": {2: "Tell Penn you carried it away"}, "leave": {2: "Tell Penn you left it for the door"}},
		"reward": {"ash": 28, "items": {"ember_shard": 1}},
		"choose": [{"set": "kindler", "slot": "girdle", "rarity": 2}, {"set": "bell", "slot": "lantern", "rarity": 2}],
		"outcome": {"take": "Penn held it up to the lamp in the tithe barn's porch and studied it like a coin. 'Water,' he said. 'A thing the Order spent four thousand arches to carry, and it came down to this much, and it is not nothing.' He put it in the reeve's strongbox, the one that is never opened, and locked it.",
			"leave": "'You left it,' said Penn. His face did something complicated. 'A reeve does not like to leave a thing owed. I will have to learn.' He wrote in the book, under the last column, a line that closed with a blank.",
			"": "The door gave what it gave, and was left."}},
	"ds_door_witch_after": {"name": "What the Witch Gave Back", "giver": "hesper", "zone": "deepsouth", "offer": true, "avail": "qd:ds_door_witch",
		"where": "Hesper Lark, at the farmhouse door",
		"text": "The door you decided is not finished with you. It has had a night to answer, and it has answered. Go back at dusk, keep the light through one more watch, read what it left, and carry what you will to Hesper.",
		"steps": [
			{"kind": "vigil", "at": Vector2(224.0, 360.0), "r": 9.0, "time": 45.0, "gloom": 0.5, "label": "The Hollow-Witch's door", "noun": "door", "prop": "lantern_lit",
				"waves": [{"at": 10.0, "kinds": ["husk"], "n": 2, "say": "The threshold remembers what you chose, and the dark leans in to see how it holds."}, {"at": 28.0, "kinds": ["gaunt"], "n": 2, "say": "Something on the far side of the door has noticed the quiet, and is considering it."}],
				"held": "The night passes at the door without accident. Something has been laid on the step in the dark.", "away": "Go back to the door. A watch is kept at the place it was set.",
				"text": "Keep one more watch at The Hollow-Witch's door ({t} s)"},
			{"kind": "place", "text": "Read what the door left, and decide whether to carry it away"},
			{"kind": "turnin", "who": "hesper", "text": "Tell Hesper what the door gave back"},
		],
		"alt": {"take": {2: "Tell Hesper you carried it away"}, "leave": {2: "Tell Hesper you left it for the door"}},
		"reward": {"ash": 28, "items": {"relic_fragment": 1}},
		"choose": [{"set": "kindler", "slot": "girdle", "rarity": 2}, {"set": "bell", "slot": "lantern", "rarity": 2}],
		"outcome": {"take": "Hesper held it in both hands and smelled it. 'A loaf,' she said, or 'a key,' or 'a cup of milk', for it was whatever the witch had meant it to be, and it was exactly right for her. 'I was afraid of her for nine winters,' she said. 'I think she was afraid of me, a little. It is a comfort to be wrong in a kind direction.'",
			"leave": "'You left it.' Hesper wiped her hands on her apron. 'A gift a stranger does not carry is the only kind a stranger can safely have been given.' She put the kettle on, which was, you gathered, what she did when she was moved.",
			"": "The door gave what it gave, and was left."}},
	"er_door_nave_after": {"name": "What the Ringers Rang", "giver": "maudlin", "zone": "eastreach", "offer": true, "avail": "qd:er_door_nave",
		"where": "Sister Maudlin, at Lastlight's shrine",
		"text": "The door you decided is not finished with you. It has had a night to answer, and it has answered. Go back at dusk, keep the light through one more watch, read what it left, and carry what you will to Maudlin.",
		"steps": [
			{"kind": "vigil", "at": Vector2(300.0, 154.0), "r": 9.0, "time": 45.0, "gloom": 0.5, "label": "The Drowned Nave's west step", "noun": "door", "prop": "lantern_lit",
				"waves": [{"at": 10.0, "kinds": ["husk"], "n": 2, "say": "The threshold remembers what you chose, and the dark leans in to see how it holds."}, {"at": 28.0, "kinds": ["gaunt"], "n": 2, "say": "Something on the far side of the door has noticed the quiet, and is considering it."}],
				"held": "The night passes at the door without accident. Something has been laid on the step in the dark.", "away": "Go back to the door. A watch is kept at the place it was set.",
				"text": "Keep one more watch at The Drowned Nave's west step ({t} s)"},
			{"kind": "place", "text": "Read what the door left, and decide whether to carry it away"},
			{"kind": "turnin", "who": "maudlin", "text": "Tell Maudlin what the door gave back"},
		],
		"alt": {"take": {2: "Tell Maudlin you carried it away"}, "leave": {2: "Tell Maudlin you left it for the door"}},
		"reward": {"ash": 28, "items": {"ember_shard": 1}},
		"choose": [{"set": "kindler", "slot": "girdle", "rarity": 2}, {"set": "bell", "slot": "lantern", "rarity": 2}],
		"outcome": {"take": "Maudlin held it to the shrine candle and looked at it a long time. 'A boy's thumb,' she said. 'He was eleven.' She set it on the shrine, among the candles, where it belonged. 'He is not lost,' she said. 'He is only out. It is a very different thing, and I should have known.'",
			"leave": "'You left it.' Maudlin bowed her head. 'Where it was left. For the ones it was left for.' She did not turn to the road, this time. She turned, for the first time in nine winters, to the Nave.",
			"": "The door gave what it gave, and was left."}},
}

const PICKUPS := {
	"wr_door_kings_after_place": {"quest": "wr_door_kings_after", "step": 1, "near": Vector2(-343.8, 167.8), "kind": "place", "name": "what the door left", "verb": "Read", "conv": "story_wr_door_kings_after",
		"say": "What the door left."},
	"ds_door_castellum_after_place": {"quest": "ds_door_castellum_after", "step": 1, "near": Vector2(-58.8, 346.8), "kind": "place", "name": "what the door left", "verb": "Read", "conv": "story_ds_door_castellum_after",
		"say": "What the door left."},
	"ds_door_witch_after_place": {"quest": "ds_door_witch_after", "step": 1, "near": Vector2(225.2, 360.8), "kind": "place", "name": "what the door left", "verb": "Read", "conv": "story_ds_door_witch_after",
		"say": "What the door left."},
	"er_door_nave_after_place": {"quest": "er_door_nave_after", "step": 1, "near": Vector2(301.2, 154.8), "kind": "place", "name": "what the door left", "verb": "Read", "conv": "story_er_door_nave_after",
		"say": "What the door left."},
}

const CONVS := {
	"story_wr_door_kings_after": {"name": "The King's Barrow door", "start": [["qat:wr_door_kings_after:1", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [["qp:wr_door_kings:seal", "The stone is rolled across, and has not moved. But at the foot of it, in the dew, there is a small pile of things laid there in the night: a tarnished crown-ring, a child's tooth on a thread, a pewter cup. Offerings, or returns. Somebody on the other side of the stone has been tidying."], ["qp:wr_door_kings:ajar", "The door is ajar, and a long thin line of light goes down the nine steps, and somebody has come up them in the night. There are prints in the dust, very tall, going out onto the heather and stopping at the lamp, a hand's breadth from it, and turning round. They went back down."], ["qp:wr_door_kings:call", "You called, and somebody sat down. In the night someone has come up, and sat on the top step, and waited. They have left the black chair's cushion there, dented, and a single white flower, which has no business growing in barrow-light."], ["", "The door has answered, and its answer is on the step."]], "who": "", "choices": [
			{"text": "Take what was left, and carry it to Siany.", "to": "take"},
			{"text": "Leave it. It was left for the barrow.", "to": "leave"},
			{"text": "Not yet.", "to": ""}]},
		"take": {"say": "You gather it, carefully, into your cloth. It is not much. It weighs, you think, rather more than it should.", "who": "", "do": "qp:wr_door_kings_after:take,qa:wr_door_kings_after", "next": ""},
		"leave": {"say": "You leave it where it lies, and step back, and the light on the step brightens, a very little, with what might be gratitude.", "who": "", "do": "qp:wr_door_kings_after:leave,qa:wr_door_kings_after", "next": ""},
		"gone": {"say": "The door stands as you left it.", "who": "", "next": ""}}},
	"story_ds_door_castellum_after": {"name": "The castellum", "start": [["qat:ds_door_castellum_after:1", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [["qp:ds_door_castellum:run", "The sluice ran, and the Arches carried water for as long as a held breath. In the cistern, the wet mark has gone: where it lay there is now a small, perfectly round pool, a yard across, with a pebble at its centre, and the pool does not drain."], ["qp:ds_door_castellum:keep", "The sluice is shut, and the wheel is locked, and the cistern is dry. But on the bailiff's chair the ledger has turned itself over to a fresh page, and on it, in a hand that is not the bailiff's, are written a single column of figures, each smaller than the last, that close: they sum to nothing, and they are exactly right."], ["qp:ds_door_castellum:name", "The bailiff's name is cut on the chair, and the wet mark in the cistern has shrunk to a coin. Somebody has laid a pewter cup beside it, dry, and set a stone across the cup's mouth, in the manner of a keeper who wishes it known he is coming back."], ["", "The door has answered, and its answer is on the step."]], "who": "", "choices": [
			{"text": "Take the pebble, the page, or the cup, and bring it to Penn.", "to": "take"},
			{"text": "Leave it for the water.", "to": "leave"},
			{"text": "Not yet.", "to": ""}]},
		"take": {"say": "You take the one thing the castellum has left, and it is light in your hand, and cool, and damp.", "who": "", "do": "qp:ds_door_castellum_after:take,qa:ds_door_castellum_after", "next": ""},
		"leave": {"say": "You leave it where it lies. Somewhere under the floor of the castellum, in the old dark, something very large turns over in its sleep and is still.", "who": "", "do": "qp:ds_door_castellum_after:leave,qa:ds_door_castellum_after", "next": ""},
		"gone": {"say": "The door stands as you left it.", "who": "", "next": ""}}},
	"story_ds_door_witch_after": {"name": "The Hollow-Witch's door", "start": [["qat:ds_door_witch_after:1", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [["qp:ds_door_witch:leave", "The nail stands, and the door is shut, and on the step there is a small round loaf in a cloth, still warm, with a thumbprint pressed in the crust. A payment received is acknowledged: a loaf for a nail. The farm, miles off, has not had a thin year since."], ["qp:ds_door_witch:pull", "The nail is drawn, and the black ring is unwound from the door, and on the step lies a single iron key, rust-red, as long as your hand. It opens nothing you know of. It is warm. Behind the door the counting has stopped, and in its place a very small, very steady sound, like someone sleeping."], ["qp:ds_door_witch:knock", "You knocked, and a light was lit, and it is still lit: the golden line under the door has not gone out. On the step in the night someone has left a clay cup of milk and a handful of oats, for whoever came, and the cup has been drunk from, a little."], ["", "The door has answered, and its answer is on the step."]], "who": "", "choices": [
			{"text": "Take the loaf, the key or the cup, and bring it to Hesper.", "to": "take"},
			{"text": "Leave it. It was not for you.", "to": "leave"},
			{"text": "Not yet.", "to": ""}]},
		"take": {"say": "You gather it, and it is warm, and nothing about it is menacing, which is the strangest thing about it.", "who": "", "do": "qp:ds_door_witch_after:take,qa:ds_door_witch_after", "next": ""},
		"leave": {"say": "You leave it on the step. The door does not so much as creak. But the light under it brightens, and then, courteously, dims.", "who": "", "do": "qp:ds_door_witch_after:leave,qa:ds_door_witch_after", "next": ""},
		"gone": {"say": "The door stands as you left it.", "who": "", "next": ""}}},
	"story_er_door_nave_after": {"name": "The Drowned Nave's west step", "start": [["qat:er_door_nave_after:1", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [["qp:er_door_nave:second", "Two candles burn on the Nave's step, and the second rope has answered the first, and the water between them is perfectly still. On the lintel the seventh ringer's mark, the open door, has been recut in fresh stone, and under it a new line in the same hand, small and glad: HE RANG IT TWICE."], ["qp:er_door_nave:take", "The candle is taken, and the step is bare, and the Nave is dark. But on the step, where the candle stood, there is a ring of wax, perfectly round, and in it, pressed, a thumb-print: a boy's. The seventh ringer has come out, and gone away, and left his print where the light was."], ["qp:er_door_nave:names", "The names are said, and the ropes have settled. On the lintel, the six names have each had a small mark added beside the bell: an open door, the same as the seventh's. Whoever it was that cut them did not hurry. The marks are clean, and level, and as warm as the stone around them."], ["", "The door has answered, and its answer is on the step."]], "who": "", "choices": [
			{"text": "Take the wax ring, the print or the open door, and bring it to Maudlin.", "to": "take"},
			{"text": "Leave it for the ringers.", "to": "leave"},
			{"text": "Not yet.", "to": ""}]},
		"take": {"say": "You lift it, with the greatest care, and it comes away whole.", "who": "", "do": "qp:er_door_nave_after:take,qa:er_door_nave_after", "next": ""},
		"leave": {"say": "You leave it where it is. From the dark of the nave, one rope is drawn, very softly, once: thanks.", "who": "", "do": "qp:er_door_nave_after:leave,qa:er_door_nave_after", "next": ""},
		"gone": {"say": "The door stands as you left it.", "who": "", "next": ""}}},
}

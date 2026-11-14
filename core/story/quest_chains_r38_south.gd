extends RefCounted
## tales, the south: four one-time tales of the Southern Downs, the March Wall's gates, Weirford and the Siege Lines
## (data only, no class_name; quest_chains.gd lists each in the blocks marked `# --- tales ---`).
##   drover_tally  The Drover's Tally   FOUND: a drover's body on the downs, his tally-stick; ride east to the fold the Flint-Hound
##                                      still keeps (Dunstan)
##   long_round    The Long Round       Fennick: kindle the road-lanterns either side of the West Gate and beyond the East Gate,
##                                      and bring back the lantern he shut the gate on (across the whole Realm; a horse's errand)
##   bryn_iron     Iron for the Hundred and Two   Bryn Gale: the war-band's tags carried hot to their grave in the Siege Lines, and Captain Varr
##   wren_gran     Gran Ide's Lantern   Wren: walk her gran down siege_track to the palisade gate, kindle its post, keep the lamp
## `found_at` tasks start when the wanderer comes within `found_r` (quest_world.gd). House style: terse, concrete, dark.

const QUESTS := {
	"drover_tally": {"name": "The Drover's Tally", "giver": "dunstan", "zone": "downs", "offer": true,
		"where": "a drover's body on the southern downs, east of the cairns",
		"found_at": Vector2(58.0, 229.0), "found_r": 7.0, "found_prop": "staff",
		"found_say": "A drover lies on the chalk with his crook beside him, bleached to the colour of the downs. A tally-stick is tucked into his belt.",
		"text": "A drover lies out on the chalk east of the cairns with a tally-stick in his belt. Dunstan has said one name on these downs, once, while the cairns went up: Wat, who never lost one. The stick may say what became of the flock.",
		"steps": [
			{"kind": "find", "text": "Take the tally-stick from the drover's belt"},
			{"kind": "find", "text": "Ride east along the chalk to Wat's fold, by the Flint-Hound's round, and look at its gate"},
			{"kind": "slay", "of": 1, "rares": ["flint_hound"], "at": Vector2(110.0, 222.0), "label": "The Flint-Hound",
				"text": "Put down the Flint-Hound, who has kept Wat's fold shut nine winters"},
			{"kind": "turnin", "who": "dunstan", "text": "Tell Dunstan what Wat left on the stick"},
		],
		"reward": {"ash": 24, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "lantern", "rarity": 2}],
		"stands": {"at": Vector2(58.0, 229.0), "kind": "cairn"},
		"outcome": {"": "Dunstan read the stick with his thumb, notch by notch, to the end. \"Forty-one out,\" he said, \"forty-one in.\" He went out to the downs with a spade and did not come back till the cairn over Wat was as high as his chest."}},
	"long_round": {"name": "The Long Round", "giver": "fennick", "zone": "road", "offer": true, "avail": "kindled:1",
		"where": "Old Fennick, on his round in Hearthward",
		"text": "Fennick lights the lamps of Hearthward every night, and has since the Night. The road-lanterns out past the March Wall he lights no longer: he says his knees, and the Wall. He wants three kindled, one inside the West Gate, one outside it, one beyond the East Gate, and the lantern at the East Gate looked at. The round is a long one. Do not walk it, if you have a horse.",
		"steps": [
			{"kind": "cond", "cond": "secret:lamps:rd_post_-132", "at": Vector2(-132.0, 62.0), "label": "The road-lantern inside the West Gate",
				"text": "Kindle the road-lantern on the Pilgrims' Road inside the March Wall's West Gate"},
			{"kind": "cond", "cond": "secret:lamps:rd_post_-176", "at": Vector2(-176.0, 64.0), "label": "The road-lantern beyond the West Gate",
				"text": "Go out through the West Gate and kindle the road-lantern beyond it, toward Weirford"},
			{"kind": "cond", "cond": "secret:lamps:rd_post_170", "at": Vector2(170.0, 66.0), "label": "The road-lantern beyond the East Gate",
				"text": "Cross the Realm to the East Gate and kindle the road-lantern on the far side of it"},
			{"kind": "find", "text": "Look at the lantern fallen at the East Gate's outer post"},
			{"kind": "turnin", "who": "fennick", "text": "Tell Fennick what the lantern says"},
		],
		"reward": {"ash": 28, "items": {"ember_shard": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "vestment", "rarity": 2}, {"slot": "girdle", "rarity": 2}],
		"outcome": {"": "Fennick turned the tag over, and over again. \"I shut it,\" he said. \"On the Warden's word. And lit the road in the dark for them I'd shut out, so that it would look like I hadn't.\" He walked the round that night as far as the Wall, and stood a long while at the gate, and went through."}},
	"bryn_iron": {"name": "Iron for the Hundred and Two", "giver": "bryn", "zone": "weirford", "offer": true, "avail": "kindled:1",
		"where": "Bryn Gale, at the Weirford forge",
		"text": "Bryn did the Lines' iron once, and has never said what for. It was tags: a hundred and two, stamped with a name each, forged before the war-band marched so that nobody would lie in the Lines unnamed. They never went. The tags have hung on the smithy wall nine winters. They want to be at the war-band's grave while the iron still rings.",
		"steps": [
			{"kind": "find", "text": "Take the box of iron tags from Bryn's anvil, hot from the quench"},
			{"kind": "carry", "from": "bryn_tags", "to": Vector2(-176.0, 148.0), "r": 12.0, "time": 55.0, "label": "Iron tags",
				"lost": "The tags have gone cold and dull in the box. Bryn will warm them again.",
				"text": "Carry the tags to the war-band's grave in the Siege Lines while the iron rings ({t} s)"},
			{"kind": "place", "text": "Set the tags on the war-band's grave"},
			{"kind": "cond", "cond": "elite:siege_captain", "at": Vector2(-200.0, 128.0), "label": "Captain Varr", "past": "Captain Varr is already at rest.",
				"text": "Put down Captain Varr, who still gives the order to go in"},
			{"kind": "turnin", "who": "bryn", "text": "Tell Bryn the Hundred and Two are named"},
		],
		"reward": {"ash": 32, "items": {"relic_fragment": 2}},
		"choose": [{"slot": "focus", "rarity": 3}, {"slot": "girdle", "rarity": 3}, {"slot": "vestment", "rarity": 3}],
		"stands": {"at": Vector2(-176.0, 148.0), "kind": "slabs"},
		"outcome": {"": "Bryn counted what you brought back, one tag, and put it on the anvil. B. GALE. Not for a grave: for a muster. \"I made my own,\" he said. \"I forged it with the rest, and I did not go. I have been waiting nine winters for somebody to ask why.\" He hung it on the hook by the door, where it could be seen."}},
	"wren_gran": {"name": "Gran Ide's Lantern", "giver": "wren", "zone": "weirford", "offer": true, "avail": "kindled:1",
		"where": "Wren, at the well in Weirford",
		"text": "Wren's gran sits on the bridge facing south every night and will not say why. She cooked for the Lines before the war-band went in. Wren is not allowed past the second stone and so cannot walk her; Wren says she can. Walk her gran to the palisade gate, give her a lamp to leave there, and bring her back.",
		"steps": [
			{"kind": "escort", "at": Vector2(-206.0, 110.0), "label": "Gran Ide", "hp": 22.0,
				"path": [Vector2(-218.0, 66.0), Vector2(-215.0, 84.0), Vector2(-208.0, 99.0), Vector2(-206.0, 110.0)],
				"ambush": {1: {"kinds": ["wretch"], "n": 2}, 2: {"kinds": ["wretch", "husk"], "n": 2}},
				"rig": {"seed": 7312, "sex": "f", "age": "old", "garment": "dress", "shawl": true, "hood": true, "hair": "bun", "l": "lantern"},
				"text": "Walk Gran Ide from the bridge down siege_track to the Lines' palisade gate; keep what rises off her"},
			{"kind": "cond", "cond": "secret:lamps:sg_gate_w", "at": Vector2(-210.6, 113.0), "label": "The gate-post lantern", "text": "Kindle the lantern on the palisade gate's west post"},
			{"kind": "defend", "at": Vector2(-206.0, 112.0), "time": 45.0, "hp": 22.0, "label": "Gran's lamp", "noun": "lamp", "prop": "lantern_lit",
				"waves": [{"at": 6.0, "kinds": ["husk", "wretch"], "n": 2, "say": "Conscripts get up out of the earthwork, drawn to the light."},
					{"at": 26.0, "kinds": ["husk", "wretch"], "n": 3, "say": "More, in a line, as they were drilled."}],
				"lost": "The lamp is knocked from its post. Gran sets it up again, and her mouth is a line.", "held": "Gran Ide hums one low note, and the note from the hill goes flat under it, as if sung down a half-tone by a friend.",
				"text": "Stand with Gran at the gate while she says her piece; keep the lamp lit ({t} s)"},
			{"kind": "turnin", "who": "wren", "text": "Tell Wren her gran said her piece"},
		],
		"reward": {"ash": 26, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"stands": {"at": Vector2(-206.0, 112.0), "kind": "ward"},
		"outcome": {"": "Gran Ide sat on the bridge until morning. She had cooked for the Lines, and the last order at the gate was to light it, and she had gone in instead. Wren says she knew all along. Osk says that is not how it works. Wren says that is how it works."}},
}

const PICKUPS := {
	"drover_stick": {"quest": "drover_tally", "step": 0, "near": Vector2(58.5, 228.0), "kind": "slate", "name": "a drover's tally-stick", "verb": "Take",
		"say": "A tally-stick, forty-one notches down one edge and forty-one down the other, every notch struck through but the last. Cut on the flat: WAT. OUT 41, IN 41. HOUND HAS THE FOLD AT THE WELL. TELL DUN I DIDN'T LOSE ONE."},
	"drover_fold": {"quest": "drover_tally", "step": 1, "near": Vector2(104.0, 219.0), "kind": "cairn", "name": "the fold's gate-cairn", "verb": "Look at",
		"say": "The gate-cairn is stacked as a shepherd stacks it to say shut, and it is shut. Behind it the chalk is laid in rows of forty-one small mounds, bone and wool, and not one is out of its row. Nothing has been taken. Somewhere on the downs a low sound begins, which is a dog being told to stay."},
	"gate_lantern": {"quest": "long_round", "step": 3, "near": Vector2(178.0, 71.0), "kind": "lantern", "name": "the East Gate's lantern", "verb": "Look at",
		"say": "A shut-lantern fallen from the outer post and left lying, the horn pane clouded with nine winters. A tag is wired to the bail in a hand you have seen on Hearthward's poles: SHUT AT DUSK ON THE WARDEN'S WORD. F. The wick has been trimmed, in the dark, by someone who could not make himself light it."},
	"bryn_tags": {"quest": "bryn_iron", "step": 0, "near": Vector2(-174.0, 70.4), "kind": "mark", "name": "the box of iron tags", "verb": "Take",
		"say": "A box of black iron tags on a ring, still hot from the quench, each one stamped with a name. They ring faintly against one another as you lift them, like a very small bell. Bryn does not look at the box."},
	"bryn_grave": {"quest": "bryn_iron", "step": 2, "near": Vector2(-176.0, 147.0), "kind": "place", "name": "the war-band's grave", "verb": "Set the tags on",
		"say": "You hang the tags along the grave's rail, name by name. A hundred and two ring. The ring has one more on it than the rail has hooks, a tag that says B. GALE, not for a grave: for a muster. The captain's stone, VARR, cut over, has a fresh cut across it, as if someone had been trying to rub it out."},
}

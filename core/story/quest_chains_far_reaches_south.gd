extends RefCounted
## The Deep South's tasks (docs/far_reaches.md "The Reaches' tasks"; data only, no class_name; quest_chains.gd lists each in the
## blocks marked `# --- the reaches ---`). Fallowmere's people give and close them; they carry the wanderer across the low fields,
## under the Long Arches and into the Southwood. Existing step kinds only; every step names a place.
##   ds_water_road     The Water Road (Reeve Penn)         MAIN: the Order's beacons relit (Fallow, Arches), Spill in the dry channel,
##                                                         the water-keeper's log at the castellum (the dungeon hook: HOOKS.castellum)
##   ds_unmade         The One I Didn't Make (Dilly)       the coat read (clues), the chalk lines followed (tracks), the Tithe-Taker; turn the scarecrow to the road or burn the coat
##   ds_witchs_price   The Witch's Price (Hesper Lark)     the burners' marks (tracks), the older nails (clues), a nail driven into the Hollow-Witch's stone: a choice
##                                                         (the dungeon hook: HOOKS.witchs_hollow)
##   ds_clapper        Cobb's Clapper (Cobb Lark)          the plough's clapper hung in the castellum's water-bell; hold it while it tolls
## The boss dungeon of the south is one of the castellum or the hollow (another lane's); both have a hook. House style: terse,
## concrete, dark.

const ZONE := ["deepsouth", "The Deep South"]

## Where a thread ends at a dungeon's entrance (see the west file's HOOKS).
const HOOKS := {
	"castellum": {"quest": "ds_water_road", "step": 2, "at": Vector2(-60.0, 346.0), "r": 16.0, "cond": "q:ds_water_road:2", "done": "qd:ds_water_road"},
	"witchs_hollow": {"quest": "ds_witchs_price", "step": 3, "at": Vector2(224.0, 360.0), "r": 12.0, "cond": "q:ds_witchs_price:3", "done": "qd:ds_witchs_price"},
}

const QUESTS := {
	"ds_water_road": {"name": "The Water Road", "giver": "penn", "zone": "deepsouth", "offer": true,
		"where": "Reeve Penn, in the tithe barn's porch at Fallowmere",
		"text": "The harvest at Fallowmere was called by fire. The Order kept beacons on the scarp, and when the barley stood the reeve lit the first, and the second answered over the Arches, and the carts came up the water road to the barn. Nobody has lit a beacon in nine winters, and nobody has come. Penn does not believe the carts are coming. He believes that if the beacons stood lit, whoever is coming would know where.",
		"steps": [
			{"kind": "cond", "cond": "secret:lamps:vista_beacon_fallow", "at": Vector2(-116.0, 250.0), "label": "The Fallow Beacon", "past": "You have already kindled the Fallow Beacon.",
				"text": "Climb the scarp over the hamlet and kindle the Fallow Beacon"},
			{"kind": "slay", "of": 1, "rares": ["aqueduct_hound"], "at": Vector2(-12.0, 360.0), "label": "Spill, the Aqueduct's Hound",
				"text": "Put down Spill in the dry channel under the Long Arches, which keeps the castellum's door"},
			{"kind": "find", "text": "Read the water-keeper's last page at the castellum, at the water road's west end"},
			{"kind": "cond", "cond": "secret:lamps:vista_beacon_arches", "at": Vector2(40.0, 249.0), "label": "The Arches Beacon", "past": "You have already kindled the Arches Beacon.",
				"text": "Climb to the Arches Beacon on the scarp and kindle it, so the second answers the first"},
			{"kind": "turnin", "who": "penn", "text": "Tell Reeve Penn both beacons burn"},
		],
		"reward": {"ash": 40, "items": {"relic_fragment": 2, "ember_shard": 1}},
		"choose": [{"set": "kindler", "slot": "lantern", "rarity": 3}, {"set": "kindler", "slot": "focus", "rarity": 3}, {"set": "kindler", "slot": "vestment", "rarity": 3}],
		"outcome": {"": "Penn climbed to the barn's loft with his tally-stick and watched the two beacons burn until dawn, one over the hamlet and one over the Arches, each in sight of the other. Nothing came down the water road. At first light he wrote the day's tithe in the roll: two fires, kept. Then he went out and told the strips, one by one, that somebody had lit the way."}},
	"ds_unmade": {"name": "The One I Didn't Make", "giver": "dilly", "zone": "deepsouth", "offer": true,
		"where": "Dilly, on the green at Fallowmere",
		"text": "Dilly makes the scarecrows, and every one faces the road so the fields know somebody is looking. One in the far strips faces the house, wears a reeve's coat of the old Order cut, and she did not make it. It walks when nobody is watching the fields, her mam says. Dilly has asked everyone to deal with it, and everyone has asked Dilly to keep out of the far strips. She has been three times, to look at its face.",
		"steps": [
			{"kind": "clues", "at": Vector2(-118.0, 351.0), "r": 8.0, "need": 2, "label": "The scarecrow nobody made",
				"text": "Look the scarecrow over, in the last of the far strips: its coat, its face, its pockets ({n}/{of} read)",
				"clues": [
					{"key": "seams", "at": Vector2(-120.0, 349.5), "name": "the coat's seams", "text": "A reeve's coat of the old Order's cut, gone green at the seams. The lining has a name worked into it in red thread, small, where only the wearer would feel it: HALE. Not Penn."},
					{"key": "face", "at": Vector2(-116.0, 353.0), "prop": "slate", "name": "the chalk face", "text": "The face is in chalk, on the sack: Dilly's chalk, in Dilly's hand. A small plain face. She drew it a year ago on another scarecrow, and it has been carrying the drawing about ever since."},
					{"key": "pocket", "at": Vector2(-121.0, 353.5), "name": "the coat's pocket", "text": "A pocket stuffed with seed corn, a button with the reeve's seal, and a tally-stick cut once, deep: HALE. COUNTED. EAST. The coat was not stolen. It was left."},
				]},
			{"kind": "tracks", "r": 12.0, "label": "The chalk lines",
				"text": "Follow the chalk lines down the far strips to where the coat's wearer walks ({n}/{of})",
				"marks": [
					{"at": Vector2(-128.0, 360.0), "text": "A chalk line across a furrow, one stroke, a child's width. It runs on to the next furrow and starts again, as if the hand had to be lifted at every ridge."},
					{"at": Vector2(-150.0, 369.0), "text": "A small plain face drawn on a grave-marker, then drawn again beside it, then again. Nine faces in a row. All of them look at the house."},
					{"at": Vector2(-168.0, 377.0), "text": "The chalk stops at a coat-shaped hollow in the long grass. Somebody was lying here, in the Order's green, and has just got up."},
				]},
			{"kind": "slay", "of": 1, "rares": ["tithe_taker"], "at": Vector2(-176.0, 380.0), "label": "The Tithe-Taker",
				"text": "Put down the Tithe-Taker, who has been wearing the reeve's coat in the far fields"},
			{"kind": "place", "text": "Decide the coat on its pole: turn it to the road, or burn it"},
			{"kind": "turnin", "who": "dilly", "text": "Tell Dilly what you did with the coat"},
		],
		"alt": {"turn": {4: "Tell Dilly it faces the road"}, "burn": {4: "Tell Dilly the coat is ash"}},
		"reward": {"ash": 22, "items": {"relic_fragment": 1}},
		"choose": [{"slot": "focus", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"leaves": {"turn": {"at": Vector2(-119.0, 350.0), "prop": "staff"}, "burn": {"at": Vector2(-119.0, 350.0), "prop": "coal"}},
		"outcome": {
			"turn": "Dilly drew a new face on the sack, a small plain one, and tied the coat back on its pole herself. 'That is Hale's coat,' Penn said at the barn door, not to anyone. 'Hale was reeve before me. He wore it to the Stair, to be counted.' Dilly said the scarecrow was hers now and it faced the road, like the others. The reeve said nothing, and stood a long time looking at his own field, and in the morning went out and straightened the pole.",
			"burn": "You took the coat off the pole and burned it in the furrow, where the chalk was thickest. The sack stands bare on its marker, and Dilly has not drawn a face on it. 'It is just a scarecrow now,' she said, and did not sound as if she believed it. Penn watched the smoke go up from the barn's loft, and said Hale would not have minded a fire. Then he went to find out which of the coats on his own pegs was his.",
			"": "Dilly drew a new face on the sack, a small plain one, and tied the coat back on its pole herself."}},
	"ds_witchs_price": {"name": "The Witch's Price", "giver": "hesper", "zone": "deepsouth", "offer": true,
		"where": "Hesper Lark, at the farmhouse door in Fallowmere",
		"text": "The well at Fallowmere is sweet and the bread is grey, and the Larks have had nine winters to learn which they mind. In the Southwood a witch lives in the roots of a fallen oak, and her price is paid in nails: you drive one into her stone yourself, and she takes what it costs. Hesper has the nail. She does not want to learn what it costs her. She wants somebody else to drive it, and to ask the question she cannot find the words for.",
		"steps": [
			{"kind": "find", "text": "Take the door-nail out of the farmhouse's own post"},
			{"kind": "tracks", "r": 12.0, "label": "The burners' marks",
				"text": "Take the burners' marks east into the Southwood, past the ruin where the clamps still smoke ({n}/{of})",
				"marks": [
					{"at": Vector2(148.0, 306.0), "text": "A charcoal X on an oak, shoulder-high, and another on the next. The burners marked the way in so the cart could find its way out."},
					{"at": Vector2(158.0, 318.0), "text": "A hazel wand set upright in the leaf-mould, a rag knotted on it, the knot a burner's. Somebody has re-tied the rag since. The rag is new."},
					{"at": Vector2(168.0, 331.0), "text": "The burners' ruin. A clamp still smokes, banked under turf and left. The marks run through it without turning and out the far side, the way a man walks who has already decided."},
					{"at": Vector2(196.0, 346.0), "text": "A boot, charred through at the toe, set neat at the foot of an oak with its laces tied. Nobody is in it. It faces the hollow."},
					{"at": Vector2(214.0, 356.0), "text": "The marks end at a stone as high as a door, bristling with nails. A light in a window in the trunk behind it. The last X is cut in the stone itself."},
				]},
			{"kind": "clues", "at": Vector2(220.0, 358.0), "r": 8.0, "need": 2, "label": "The older nails",
				"text": "Read the older nails in the witch's stone: who paid, and for what ({n}/{of} read)",
				"clues": [
					{"key": "mother", "at": Vector2(218.5, 355.5), "name": "a nail through apron-linen", "text": "A nail through a scrap of apron-linen, rusted to a thread. A Lark's weave, thirty winters old. The linen has a loaf worked into the hem. Hesper's mother asked for something here, and bread has been grey at Fallowmere since."},
					{"key": "coat", "at": Vector2(224.0, 355.0), "prop": "mark", "name": "a nail through a reeve's button", "text": "A nail through a pewter button with the reeve's seal. Newer. Nine winters, no more. Somebody asked on the reeve's behalf, and the far strips filled with the dead the same night."},
					{"key": "crust", "at": Vector2(218.0, 361.0), "name": "a nail through a crust", "text": "A nail through a crust of grey bread, turned to stone. The bread does not rot here. It is the only thing at the stone that is not afraid of the price."},
				]},
			{"kind": "place", "text": "Drive the nail into the stone at the Hollow-Witch's door, and ask"},
			{"kind": "turnin", "who": "hesper", "text": "Tell Hesper what the witch took"},
		],
		"alt": {"bread": {4: "Tell Hesper the bread will rise"}, "strips": {4: "Tell Hesper the far strips will lie down"}, "nothing": {4: "Tell Hesper you asked nothing"}},
		"reward": {"ash": 26, "items": {"ember_shard": 1}},
		"choose": [{"slot": "lantern", "rarity": 2}, {"slot": "vestment", "rarity": 2}],
		"leaves": {"bread": {"at": Vector2(-171.5, 306.5), "prop": "loaf"}, "strips": {"at": Vector2(-146.0, 337.0), "prop": "cairn"}, "nothing": {"at": Vector2(-169.0, 303.5), "prop": "mark"}},
		"outcome": {
			"bread": "The bread rose at dawn, light as a held breath, and it tastes of the Southwood's smoke. Cobb will not eat it. Hesper eats it a slice at a time, for the length of the loaf, and does not say what it cost, and the draught from the door-post whistles a note she has started to hum. A loaf sits on the sill for whoever comes.",
			"strips": "The far strips went flat in the night, every marker settling at once like a held breath let go. In the morning the field was only a field, and Wystan stood at its edge a long time with his spade on his shoulder. Hesper's bread stayed grey. 'Cheap at the price,' Wystan said, and he was the only one who said it. A cairn stands at the field's edge where the markers were.",
			"nothing": "Hesper heard you had asked nothing, and sat down on the step with her hands in her apron. 'She'll want paying anyway,' she said. 'She'll come for the nail.' She did not say what she would pay. The post whistles at night where the nail was, and a nail-head stands bright in the earth by the step that nobody has put there.",
			"": "Hesper held the door shut with her foot, and said nothing."}},
	"ds_clapper": {"name": "Cobb's Clapper", "giver": "cobb", "zone": "deepsouth", "offer": true,
		"where": "Cobb Lark, at his fields' gate in Fallowmere",
		"text": "The plough turned up a bell clapper in the south strip, the Order's mark on the iron. The Reeve said put it back, and Cobb did, and it came up again the next spring a furrow nearer the arches. A clapper wants its bell. The nearest the Order kept in the south is the castellum's water-bell, which rang the sluices open each dawn until the water stopped. Cobb will not carry it himself. He says it gets heavier the nearer the arches you go.",
		"steps": [
			{"kind": "find", "text": "Take the Order's clapper from the south strip's furrow"},
			{"kind": "place", "text": "Hang the clapper in the water-bell at the castellum, at the Long Arches' west end"},
			{"kind": "defend", "at": Vector2(-65.0, 350.5), "time": 40.0, "hp": 22.0, "label": "The water-bell", "noun": "bell", "prop": "bell_bare",
				"waves": [{"at": 6.0, "kinds": ["crawler", "husk"], "n": 2, "say": "Things come up the dry channel toward the sound."},
					{"at": 24.0, "kinds": ["husk", "gaunt"], "n": 3, "say": "More, out from under the arches, as if called to a muster."}],
				"lost": "The bell is knocked from its bracket. The clapper lies in the dust and will have to be hung again.", "held": "The water-bell rings out its dawn and goes quiet.",
				"text": "Hold the castellum while the water-bell tolls, and keep what answers it off the bell ({t} s)"},
			{"kind": "turnin", "who": "cobb", "text": "Tell Cobb the clapper has its bell"},
		],
		"reward": {"ash": 24, "items": {"ember_shard": 1}},
		"choose": [{"slot": "girdle", "rarity": 2}, {"slot": "focus", "rarity": 2}],
		"outcome": {"": "The bell rang once, a flat dry note over the whole valley, and in the dry channel under the arches something very like water ran for the length of a breath. Cobb did not hear it from his field. In the morning the south strip's stones lay in a row at his gate, as though somebody had walked them there, and the clapper's furrow was a smooth line pointing at the arches. He ploughed straight across it, and it stayed ploughed."}},
}

const PICKUPS := {
	"ds_keeper_log": {"quest": "ds_water_road", "step": 2, "near": Vector2(-60.0, 352.0), "kind": "page", "name": "the water-keeper's log", "verb": "Read",
		"say": "The last page of the water-keeper's log, nailed inside the castellum door where the next keeper would see it: THE WATER STOPPED AT THE SECOND BELL. I OPENED EVERY SLUICE AND IT DID NOT COME. THE BEACON ON THE SCARP IS TO BE LIT WHEN THE WATER RETURNS AND NOT BEFORE. Under it, in another hand, in charcoal: LIT IT ANYWAY. IT MAY HELP SOMEONE FIND US."},
	"ds_unmade_turn": {"quest": "ds_unmade", "step": 3, "near": Vector2(-118.0, 351.0), "kind": "place", "name": "the scarecrow's pole", "verb": "Deal with", "conv": "ds_nail_door",
		"say": "The scarecrow's pole."},
	"ds_nail": {"quest": "ds_witchs_price", "step": 0, "near": Vector2(-169.8, 305.0), "kind": "mark", "name": "the door-nail", "verb": "Take",
		"say": "A square-headed nail of the Order's smith, drawn out of the farmhouse's own door-post. It leaves a hole you could put a finger in, and a draught. Hesper holds the door shut with her foot, and does not look at it."},
	"ds_witch_door": {"quest": "ds_witchs_price", "step": 3, "near": Vector2(222.5, 359.0), "kind": "place", "name": "the witch's door", "verb": "Drive the nail into", "conv": "ds_nail_door",
		"say": "The witch's door."},
	"ds_clapper": {"quest": "ds_clapper", "step": 0, "near": Vector2(-157.0, 333.0), "kind": "clapper", "name": "the Order's clapper", "verb": "Take",
		"say": "A clapper of black iron as long as your forearm, the head worn bright where it struck for three hundred years. It lay in the furrow with its shank toward the arches, and it is warm, and it is heavier than it was a step ago."},
	"ds_bell": {"quest": "ds_clapper", "step": 1, "near": Vector2(-65.0, 350.5), "kind": "bell_bare", "name": "the water-bell", "verb": "Hang the clapper in",
		"say": "The castellum's water-bell hangs in its bracket under the lowest roof, the rope long since rotted, the green of the bronze eaten down to the metal where the dawn ringer's hands were. You wedge the clapper in its eye. It swings on its own, a little, in no wind, and finds the lip."},
}

const CONVS := {
	"ds_nail_door": {"name": "The Hollow-Witch's Door", "start": [["qat:ds_unmade:3", "coat"], ["qat:fm_tithe:3", "roll"], ["qat:ds_charcoal:2", "coals"], ["!qat:ds_witchs_price:3", "gone"], ["", "at"]], "nodes": {
		"coat": {"say": "The scarecrow nobody made stands in its strip in the reeve's coat, HALE worked in red thread inside the collar. The pole is a grave-marker. The face is Dilly's. There is a good deal of coat, and it was somebody's.", "who": "", "choices": [
			{"text": "Turn the pole to face the road, coat and all.", "to": "turn"},
			{"text": "Take the coat off and burn it in the furrow.", "to": "burn"},
			{"text": "Not yet.", "to": ""},
		]},
		"turn": {"say": "You turn the pole in its socket, a quarter and then a half, until the sack face looks down the strips toward the hamlet's lamps. The chalk smile has smudged in the damp. Nothing in the field is walking.", "who": "", "do": "qp:ds_unmade:turn,qa:ds_unmade", "next": ""},
		"burn": {"say": "The coat comes off the pole in one piece, a shape with nobody in it. You lay it in the furrow where the chalk is thickest and put a light to the hem. It burns the way wet wool burns, slowly, without a sound, and the smoke goes up the strips toward the barn.", "who": "", "do": "qp:ds_unmade:burn,qa:ds_unmade", "next": ""},
		"roll": {"say": "The roll lies open on the board, eleven winters of strips in the clerk's hand and, on top of them, three bundles of sticks. A lamp has been trimmed beside it by somebody who did not stay to see it read. The barn is listening.", "who": "", "choices": [
			{"text": "Read the roll out as it stands, every name, the reeve's too.", "to": "full"},
			{"text": "Strike the reeve's own line, and read the rest.", "to": "strike", "if": "qc:fm_tithe:penn"},
			{"text": "Not yet.", "to": ""},
		]},
		"full": {"say": "You read it, strip by strip, name by name, Penn's at the last. Your voice carries to the barn's dark end and the barn does not answer. Out in the far strips something lies down, and a lamp stays on the board.", "who": "", "do": "qp:fm_tithe:full,qa:fm_tithe", "next": ""},
		"strike": {"say": "You score his line through with the clerk's knife, one stroke, twelve winters of OWED gone under it. Then you read the rest. The roll is whole without it, which is not the same as whole.", "who": "", "do": "qp:fm_tithe:strike,qa:fm_tithe", "next": ""},
		"coals": {"say": "A man in a soot-black coat sits against the stack's far side, a rake across his knees, and does not look up. Hob's clamp is banked under turf, red at the seams. The last charcoal-burner keeps it the way the dead keep a promise, without being asked.", "who": "", "choices": [
			{"text": "Ask his leave for one coal, and leave the clamp banked.", "to": "spare"},
			{"text": "Draw the clamp and take what it holds.", "to": "take"},
			{"text": "Not yet.", "to": ""},
		]},
		"spare": {"say": "You say it out loud, and wait. He does not look up. He turns the rake over once on his knees, which is leave, and you lift one coal from the seam in the horn cup. The clamp stays red behind you. He keeps the beacons, Penn said. He will keep this.", "who": "", "do": "qp:ds_charcoal:spare,qa:ds_charcoal", "next": ""},
		"take": {"say": "You rake the turf back and draw the clamp, and the coals roll out red onto the grey ground, a night's work gone to a heap in a breath. The man in the soot-black coat stands up. He looks at the heap, not at you, and walks into the smoke, and the stack goes on smoking without him.", "who": "", "do": "qp:ds_charcoal:take,qa:ds_charcoal", "next": ""},
		"at": {"say_if": [["qc:ds_witchs_price:mother", "The witch's door is a slab of root-plate with a standing stone set against it, bristling with nails driven through scraps of cloth. A Lark's apron-linen is among the oldest. A window in the trunk's hollow is lit with wax. Nobody answers. The price is to drive the nail yourself, and to ask."], ["qc:ds_witchs_price:coat", "The witch's door is a slab of root-plate with a standing stone set against it, bristling with nails. One of them goes through a reeve's button. A window in the trunk's hollow is lit with wax. Nobody answers. The price is to drive the nail yourself, and to ask."], ["", "The witch's door is a slab of root-plate with a standing stone set against it, bristling with nails driven through scraps of cloth: the oldest rusted to nothing, the newest bright. A window in the trunk's hollow is lit with wax. Nobody answers. The price is to drive the nail yourself, and to ask."]], "who": "", "choices": [
			{"text": "Ask that the bread rise.", "to": "bread"},
			{"text": "Ask that the far strips lie down.", "to": "strips"},
			{"text": "Drive it, and ask nothing.", "to": "nothing"},
			{"text": "Not yet.", "to": ""},
		]},
		"bread": {"say": "You drive the nail through a scrap of Hesper's apron-linen, three blows, and say it: let the bread rise. The stone takes the nail the way wet clay takes a thumb. The lit window goes out, and comes back.", "who": "", "do": "qp:ds_witchs_price:bread,qa:ds_witchs_price", "next": ""},
		"strips": {"say": "You drive the nail through a scrap of Hesper's apron-linen, three blows, and say it: let the far strips lie down. The stone takes the nail. Far off to the north-west, in the dark, something very large settles like a sleeper turning over.", "who": "", "do": "qp:ds_witchs_price:strips,qa:ds_witchs_price", "next": ""},
		"nothing": {"say": "You drive the nail, three blows, and ask nothing. The stone takes it as it takes any nail. The window does not go out. In the hollow somebody laughs once, very quietly, as a person does who has been paid in advance.", "who": "", "do": "qp:ds_witchs_price:nothing,qa:ds_witchs_price", "next": ""},
		"gone": {"say": "The stone is thick with nails, and one of them is yours. The window is lit, and nobody comes to it.", "who": "", "next": ""},
	}},
}

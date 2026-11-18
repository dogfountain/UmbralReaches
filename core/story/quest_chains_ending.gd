extends RefCounted
## The ending's last walk (docs/STORY.md "after the door"): once the keep has told the ending, he asks one more thing of the wanderer: walk the
## valley once more, now that the sky has stopped, and tell him what it looks like. Five places, each a scene whose words follow what the
## wanderer chose (the third edict, the lamps, the roll, the horn, the wall, the candle, the boots, the knocks), and then the keep, who says one of
## six verdicts and, after it, the credits. All of it is `say_if` over the picks, so every combination reads as its own epilogue.
## Listed by quest_chains.gd under `# --- the long walk ---`; the credits are keep nodes in dialogue_db.gd (CREDITS here). No class_name.

const ORDER := ["long_walk"]

const QUESTS := {
	"long_walk": {"name": "The Long Walk", "giver": "keep", "zone": "hearth", "offer": true, "avail": "flag:ending_told",
		"where": "The keep of the Kindled Keg",
		"text": "The door is shut and the sky has stopped. The keep has poured every night for nine winters and cannot go out to see what he poured for. He asks you to walk the valley once more, slowly, with nothing chasing you: the Stair's foot, the Chapel, the Glade, Maud's door, the road. To stand at each and tell him what is there now. That is all. It is the only favour he has ever asked.",
		"steps": [
			{"kind": "place", "text": "Stand at the Stair's foot and look up"},
			{"kind": "place", "text": "Stand in the Chapel of the First Kindling, at the First Hearth"},
			{"kind": "place", "text": "Stand at the Shrine of the Lost in the Glimmer Glade"},
			{"kind": "place", "text": "Stand at Maud's door on the green"},
			{"kind": "place", "text": "Stand at the first lamp-post of the road, below the Chapel lane"},
			{"kind": "turnin", "who": "keep", "text": "Tell the keep what the valley looks like"},
		],
		"reward": {"ash": 30, "items": {"relic_fragment": 2, "ember_shard": 2}},
		"choose": [{"set": "kindler", "slot": "lantern", "rarity": 3}, {"set": "bell", "slot": "vestment", "rarity": 3}, {"set": "tally", "slot": "focus", "rarity": 3}],
		"outcome": {"": "The keep listened to every word with his cloth in his hand, and then put it down. 'Pour you one,' he said. 'On the house. On the valley. And Fennick has the palfrey at the rail, if you wanted to run the Cup, now there is no hurry. The Count has the page.'"}},
}

const PICKUPS := {
	"lw_stair": {"quest": "long_walk", "step": 0, "near": Vector2(-1.5, 17.0), "kind": "place", "name": "the Stair's foot", "verb": "Look up from", "conv": "story_walk_stair", "say": "The Stair's foot."},
	"lw_chapel": {"quest": "long_walk", "step": 1, "near": Vector2(-78.0, 51.0), "kind": "place", "name": "the First Hearth", "verb": "Stand at", "conv": "story_walk_chapel", "say": "The First Hearth."},
	"lw_glade": {"quest": "long_walk", "step": 2, "near": Vector2(-45.0, 17.5), "kind": "place", "name": "the Shrine of the Lost", "verb": "Stand at", "conv": "story_walk_glade", "say": "The Shrine of the Lost."},
	"lw_maud": {"quest": "long_walk", "step": 3, "near": Vector2(-13.0, 41.5), "kind": "place", "name": "Maud's door", "verb": "Stand at", "conv": "story_walk_maud", "say": "Maud's door."},
	"lw_road": {"quest": "long_walk", "step": 4, "near": Vector2(-75.0, 62.0), "kind": "place", "name": "the first lamp-post", "verb": "Stand at", "conv": "story_walk_road", "say": "The first lamp-post of the road."},
}

const CONVS := {
	"story_walk_stair": {"name": "The Stair's Foot", "start": [["qat:long_walk:0", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [
			["qp:aurel_edicts:follow,qp:lamp_road:stair", "You look up. Every lamp on the road behind you leans toward the mountain, and at its top there is no vortex: only the Crowns, black on a sky with stars in it. The stone of the third edict, you know, says that he follows. The stairs, four thousand and one of them, are silent, and look, for the first time, like steps."],
			["qp:aurel_edicts:follow", "You look up. The sky has stopped turning, and at the top of the Stair, where there was a door, there is a long clear dark with stars. You know what the third stone says now. It says he follows. The Stair, you think, has never looked so much like something a man might walk down."],
			["qp:aurel_edicts:scratch", "You look up. The sky has stopped turning. The third stone is scratched to a smear, and the Stair above you is only a stair: four thousand and one steps to nowhere in particular. It is a clean, plain, unaccompanied sort of quiet, and you do not know whether to be glad of it."],
			["qp:aurel_edicts:leave", "You look up. The sky has stopped turning. The third stone says what it says, and the Stair above you says nothing at all. It is a very great, very patient flight of steps, and somebody meant it kindly."],
			["", "You look up. The sky has stopped turning. The Stair rises into a clean dark, and the Crowns stand black against the stars. Nothing climbs. Nothing comes down."]], "who": "", "do": "qa:long_walk", "next": ""},
		"gone": {"say": "The Stair rises into the dark.", "who": "", "next": ""}}},
	"story_walk_chapel": {"name": "The First Hearth", "start": [["qat:long_walk:1", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [
			["qd:aurel_edicts,qp:lamp_road:home", "The First Hearth is warm in the roofless nave, and the road beyond the wall is a long hand of small lights. Perrin is on his bench at the yard gate, copying nothing, and he lifts his head as you pass, and nods. The faceless saints have, you think, the very faintest of expressions."],
			["qd:aurel_edicts", "The First Hearth is warm in the roofless nave. Perrin is on his bench at the yard gate, with his book shut on his knee. The faceless saints look out over the nave, and for once they do not seem to be turning away."],
			["", "The First Hearth is warm in the roofless nave, and nobody is praying. The saints look out over it, faceless. A very small, very old apron hangs on a nail, and the coals in it, if you hold your hand flat, are still warm."]], "who": "", "do": "qa:long_walk", "next": ""},
		"gone": {"say": "The Hearth burns.", "who": "", "next": ""}}},
	"story_walk_glade": {"name": "The Shrine of the Lost", "start": [["qat:long_walk:2", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [
			["qp:name_on_roll:entered,qp:pell_stitches:own", "The Shrine of the Lost is bright with candles. A little red shoe hangs on its nail with two grey stitches and one red, and by the shrine, on the step, someone has set a tin Open Door, bright, not burned. Ione is asleep on a bench with her hood over her face and her fire gone to coals. You do not wake her."],
			["qp:name_on_roll:mother", "The Shrine of the Lost is bright with candles. On the step, in a ring of pebbles, a tin Open Door, polished. Ione Marsh is gone from her fire, and in the morning, someone says, she will be at the Tally post with a nail and her mother's name above hers. The little red shoe hangs on its nail, newly mended."],
			["qd:pell_stitches", "The Shrine of the Lost is bright with candles, and the little red shoe on its nail has a new stitch in it, still bright. Nobody is here. Nobody has been. The thread is grey, and there is a needle on the step."],
			["", "The Shrine of the Lost is bright with candles and ribbons, and the blue ones lift a little in the wind. Nobody has come for the shoe. The glimmers, in the dark under the trees, are only light the sky did not swallow, and they are very many."]], "who": "", "do": "qa:long_walk", "next": ""},
		"gone": {"say": "The shrine's candles burn.", "who": "", "next": ""}}},
	"story_walk_maud": {"name": "Maud's Door", "start": [["qat:long_walk:3", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [
			["qp:three_knocks:open,qp:col_boots:wear", "Maud's door is open, and the candle in her window has gone out because it is no longer needed. Across the green a young man in a pair of old boots, one of them leaking, crosses the grass without looking where he treads. He is humming."],
			["qp:three_knocks:open", "Maud's door stands open to the green, and the candle in her window is out. There is a very small shape asleep by her fire, and she has put a blanket over it. She sees you, and puts a finger to her lips."],
			["qp:three_knocks:answer", "Maud sits at her door with her hands in her lap, and a voice, her own, says her name on the step, and goes. She nods, as one does at a neighbour. It is enough of a visit."],
			["qp:three_knocks:shut", "Maud's door is barred. The candle is out. She has gone to bed at last, and the bar is still down, and the green, you think, is very quiet round it."],
			["", "Maud's candle is still in the window, though there is nobody now to see it from the sky. Habit is the last thing to go."]], "who": "", "do": "qa:long_walk", "next": ""},
		"gone": {"say": "The door is shut against the night.", "who": "", "next": ""}}},
	"story_walk_road": {"name": "The First Lamp-Post", "start": [["qat:long_walk:4", "here"], ["", "gone"]], "nodes": {
		"here": {"say_if": [
			["qp:lamp_road:stair,qp:horn_end:sung", "The lamps of the road lean at the mountain, the whole way east, like an argument won. Far past the Lines, very faintly, a long note that had been holding for nine winters has stopped at last on its final word. Somebody, a long way off, is sleeping out loud."],
			["qp:lamp_road:home,qp:vow_cell:name", "The lamps of the road all face Hearthward, the whole way east, like a hand held out. Far past the Lines, on a cliff road, a woman is saying a name softly as she kneads, and somewhere up in the rock a very dry voice says it back."],
			["qp:lamp_road:stair", "The lamps of the road lean at the mountain, the whole way to Lastlight and beyond. Nobody is walking it. They are lit for no one in particular, which is what a road is for."],
			["qp:lamp_road:home", "The lamps of the road all face Hearthward, the whole way east. A pilgrim is coming down it in the dark, late, with a staff, and he does not look up at the sky. He looks at the lamps, one after another, and walks on, and the lamps let him."],
			["", "The road runs east in the dark, and the lamps along it are cold. Somebody, one day, will light them. It was not, you think, a bad road. It was only waiting."]], "who": "", "do": "qa:long_walk", "next": ""},
		"gone": {"say": "The road runs on.", "who": "", "next": ""}}},
}

## The credits: told at the keep after the verdict, in the world's own voice, as narration (no speaker). Tiers are the six verdicts.
const CREDITS := {
	"verdict": [
		["qp:aurel_edicts:follow,qp:horn_end:sung,qp:vow_cell:name", "It is a mercy, then. The door he held for you he has let go of, and he followed. The note in the skull is finished, and the woman in the wall has been called by her name. I did not think the valley had that in it. Sit. It is a very good night."],
		["qp:aurel_edicts:follow,qp:horn_end:sung|qp:aurel_edicts:follow,qp:vow_cell:name|qp:aurel_edicts:follow,qp:vow_cell:bread", "It is nearly a mercy. He followed, and a good deal of what hung on him was let down gently. The rest, we will carry. We are good at carrying."],
		["qp:aurel_edicts:leave", "You left the stone as it was cut. That is a hard sort of fairness, and the best the valley could do. We will not forget what it says. We will not pretend it says what we wish."],
		["qp:aurel_edicts:scratch,qp:horn_end:broke|qp:aurel_edicts:scratch,qp:vow_cell:break", "The third stone is a smear and the horn is broken and the wall is down. You have taken things out of the world that were holding it, and left it standing. I will not say it was wrong. I will say it was a great deal of silence."],
		["qp:aurel_edicts:scratch", "You scratched the stone, and nobody will know what it said. It is a kind of freedom. It is also a kind of loneliness. We will bear it."],
		["", "The door is shut, and the sky has stopped. That is the whole of it. Whatever else was owed, I will leave it to a better ledger than mine. Sit. Drink."]],
	"lines": [
		"The valley was cold, and then it was not. That is the whole of the Reaches' story.",
		"Hild keeps the forge hot. Fennick lights the lamps he can reach, and weeps at the ones he cannot. Nan has put out a mug.",
		"Edda's fire is still burning on the altar, as it has burned, and the Kindlers go on tending it, and ask no one what they believe.",
		"The Founder's bells hang where she hung them, and one of them, at least, has been rung the right way up.",
		"The Hierarch is gone through. Or he is following. Or he was never anything but a man who held a door, and could not say why.",
		"Somewhere past the Lines, a baker walks bread up a cliff, and a cantor listens, and a woman writes a name on a post.",
		"The wanderer, who had no face, walked the whole way, and came back warm.",
		"The sky is still. The cold stays. It no longer pulls.",
		"Hearthward keeps its fire.",
	],
}

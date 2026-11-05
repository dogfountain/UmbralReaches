extends RefCounted
## Every readable text of the Realm (docs/LORE.md is the canon behind them). RealmLore places a
## carrier (grave marker, waystone, tablet, lectern page, notice, letter) for each entry; the
## wanderer reads it with E in the reading panel (ui/codex.gd) and it goes into the journal.
## Keep entries terse: one to three sentences, under ~300 characters. No class_name: preload by path.
##
## entry = {region, kind, title, text [, series, part]}
##   region: a RealmLayout region id (hearth, road, chapel, glade, thornwood, fen, barrows, rift)
##   kind: grave | waystone | tablet | rune | page | notice | plaque | lectern | letter | ledger
##   series/part: a multi-part story (SERIES), shown in the journal in part order, gaps kept.

const TEXTS := {
	# --- Hearthward -------------------------------------------------------------------------------
	"hw_notice_keep": {"region": "hearth", "kind": "notice", "title": "Notice",
		"text": "BY ORDER OF THE KEEP: no fire to be let die after dusk. A cold hearth is an open door."},
	"hw_notice_lost": {"region": "hearth", "kind": "notice", "title": "Notice",
		"text": "LOST: Pell, nine winters, red hood. Last seen walking north toward the light. Do not follow."},
	"hw_notice_stair": {"region": "hearth", "kind": "notice", "title": "Notice",
		"text": "Pilgrims: the Stair is closed. The Keg has beds. Pay in ash or in news."},
	"hw_well": {"region": "hearth", "kind": "plaque", "title": "Hearth Well",
		"text": "Dug when the abbey still sent water-blessings. The water stayed. The blessings did not."},
	"hw_maud": {"region": "hearth", "kind": "plaque", "title": "Maud's door",
		"text": "Old Maud keeps one candle in the window. She says her son will see it from the sky and come down."},
	"hw_shrine": {"region": "hearth", "kind": "tablet", "title": "Hearth shrine",
		"text": "Saint Edda, keep our coals. Let the dark knock and find no latch."},
	"hw_green": {"region": "hearth", "kind": "tablet", "title": "Hearthstone",
		"text": "Here the village carried the first coals home from the chapel: in pots, in hands, in mouths when the pots broke."},
	"hw_forge": {"region": "hearth", "kind": "plaque", "title": "Edda's forge",
		"text": "Edda shod the abbey's mules and mended its censers. When the sky went in, she struck the first spark."},
	"hw_reed": {"region": "hearth", "kind": "grave", "title": "A garden grave",
		"text": "Tobin Reed, who let his fire go out to see the stars. He saw them."},
	"hw_harrow": {"region": "hearth", "kind": "plaque", "title": "The Harrows' house",
		"text": "Chalked on the lintel: GONE UP WITH THE BLESSING. The door was left unbarred, as the priests asked."},
	"hw_stair_foot": {"region": "hearth", "kind": "tablet", "title": "Stair-foot stone",
		"text": "The Stair of Ascension began here. Four thousand steps, every one blessed. There are fewer now."},
	"hw_wright": {"region": "hearth", "kind": "plaque", "title": "The Wrights' door",
		"text": "Scratched low in the planks, at a child's height: WE ARE AT THE KEG. COME IN THE BACK. DON'T KNOCK THREE TIMES."},
	"hw_cobb_barn": {"region": "hearth", "kind": "plaque", "title": "Cobb's barn",
		"text": "Old Cobb fired his own barn the first night, so the dark would have to cross it. It did not cross. It went round."},
	"hw_maud_1": {"region": "hearth", "kind": "letter", "title": "A letter, never sent", "series": "maud", "part": 1,
		"text": "Hobb. The candle is still lit. I trim it at dusk and again when I wake. If it is bright up there, look for the one small light. Mother."},
	"hw_maud_2": {"region": "hearth", "kind": "letter", "title": "A letter, never sent", "series": "maud", "part": 2,
		"text": "Hobb. I planted your beans, though there is no sun to grow them. The keep says I should sleep at the Keg. I told him the window would go dark."},
	"hw_maud_3": {"region": "hearth", "kind": "letter", "title": "A letter, never sent", "series": "maud", "part": 3,
		"text": "Hobb. Someone knocked tonight. Three slow knocks, the way you used to. I did not open. I am sorry. I am sorry. The candle stayed lit."},

	# --- Chapel of the First Kindling ---------------------------------------------------------
	"ch_hearth": {"region": "chapel", "kind": "plaque", "title": "The First Hearth",
		"text": "Here Edda laid her forge-coals on the bare altar, and the gloom came to the door and went no further."},
	"ch_edda_saint": {"region": "chapel", "kind": "plaque", "title": "Saint Edda the Kindler",
		"text": "Her face was cut away by the Order's penitents. 'No face should turn from the sky.'"},
	"ch_corvin": {"region": "chapel", "kind": "plaque", "title": "Saint Corvin",
		"text": "Who carried fire to the fen burials so the sunk dead would have light. They took his face, and his hands."},
	"ch_litany_1": {"region": "chapel", "kind": "lectern", "title": "The Kindler's Litany, I", "series": "litany", "part": 1,
		"text": "Fire is not a prayer. Fire is a refusal."},
	"ch_litany_2": {"region": "chapel", "kind": "lectern", "title": "The Kindler's Litany, II", "series": "litany", "part": 2,
		"text": "Feed it what the dark leaves behind. Ash to ember, ember to flame."},
	"ch_litany_3": {"region": "chapel", "kind": "lectern", "title": "The Kindler's Litany, III", "series": "litany", "part": 3,
		"text": "When the last fire fails, the sky will have us all. Be the fire that does not fail."},
	"ch_ansel": {"region": "chapel", "kind": "grave", "title": "Brother Ansel", "series": "ansel", "part": 3,
		"text": "Brother Ansel of the Order. He came to scrape the saints and stayed to tend the fire. Forgiven."},
	"ch_ansel_1": {"region": "chapel", "kind": "page", "title": "Ansel's confession", "series": "ansel", "part": 1,
		"text": "I took the smith-saint's face, as I was ordered. Then I saw what she had been carved holding: tongs, and in their jaws a coal, and it was warm. The chisel stayed on the floor."},
	"ch_ansel_2": {"region": "chapel", "kind": "page", "title": "Ansel's confession", "series": "ansel", "part": 2,
		"text": "The Order sent for me twice. The first time I sent back a pot of coals. The second messenger stayed, and learned to bank a fire."},
	"ch_edda_grave": {"region": "chapel", "kind": "grave", "title": "A plain stone",
		"text": "EDDA. No saint here. Only a smith who would not look up."},
	"ch_door": {"region": "chapel", "kind": "plaque", "title": "Dedication stone",
		"text": "Raised as the Chapel of the Open Sky, Year of Ascent 312. The word SKY is chiselled out; HEARTH is scratched in."},
	"ch_yard": {"region": "chapel", "kind": "grave", "title": "Pilgrims' row",
		"text": "Nine pilgrims who reached the fire too late. Buried facing the chapel, not the sky."},

	# --- The Pilgrims' Road ---------------------------------------------------------------------
	"rd_gate_w": {"region": "road", "kind": "plaque", "title": "The West Gate",
		"text": "Beyond this stone every soul belongs to the sky. By edict of the Hierarch Aurel. Pilgrims called the valley the Reaches; since the Night, the marches call it the Umbral Reaches."},
	"rd_way_12": {"region": "road", "kind": "waystone", "title": "Waystone",
		"text": "XII miles to the Stair. Walk light: the sky is listening."},
	"rd_way_9": {"region": "road", "kind": "waystone", "title": "Waystone",
		"text": "IX miles. Leave a stone for those who went before. Take none."},
	"rd_way_6": {"region": "road", "kind": "waystone", "title": "Waystone",
		"text": "VI miles. Here the Order washed the pilgrims' feet, so they would ascend clean."},
	"rd_way_3": {"region": "road", "kind": "waystone", "title": "Waystone",
		"text": "III miles. Hearthward: last bread, last bed, last fire before the Stair."},
	"rd_way_e8": {"region": "road", "kind": "waystone", "title": "Waystone",
		"text": "From the eastern marches, VIII miles. The fen road is closed. Do not ask why."},
	"rd_way_e11": {"region": "road", "kind": "waystone", "title": "Waystone",
		"text": "XI miles. Ring the bell if you can still walk. Someone will come. (No bell hangs from the hook.)"},
	"rd_gate_e": {"region": "road", "kind": "plaque", "title": "The East Gate",
		"text": "Pilgrims of the marches, give up your lanterns here. The Stair will light you."},
	"rd_grave_stone": {"region": "road", "kind": "grave", "title": "A roadside grave",
		"text": "A pilgrim, name unknown, who sat down by the road and would not get up. We gave her a stone pillow."},
	"rd_grave_cobb": {"region": "road", "kind": "grave", "title": "The Cobb brothers",
		"text": "Here lie the Cobb brothers. One went up. One stayed. Both are here."},
	"rd_shrine": {"region": "road", "kind": "plaque", "title": "Roadside shrine",
		"text": "'Mother of the Open Sky, lift us lightly.' Scratched beneath, newer: 'She dropped them.'"},
	"rd_cart": {"region": "road", "kind": "plaque", "title": "A broken cart",
		"text": "Chalked on the tailboard: GONE AHEAD. FOLLOW THE BELLS. There were no bells."},
	"rd_lamp": {"region": "road", "kind": "plaque", "title": "Road lamp",
		"text": "The road lamps burned blessed oil. On the Night the flames all leaned the same way, up, toward the summit, and went out."},
	"rd_edict_1": {"region": "road", "kind": "plaque", "title": "Edict of the Open Door, I", "series": "edicts", "part": 1,
		"text": "FIRST EDICT. Every soul upon this road is the sky's. Lanterns are for those who doubt. Leave your doubt at the gate."},
	"rd_edict_2": {"region": "road", "kind": "plaque", "title": "Edict of the Open Door, II", "series": "edicts", "part": 2,
		"text": "SECOND EDICT. On the Night, let no fire burn below the Stair, that the sky may see only the faithful. Hearths to be put out at the bell."},

	# --- Wenna's journal (nine pages: road -> chapel -> village -> glade -> fen -> barrows -> the door)
	"jn_1": {"region": "road", "kind": "page", "title": "Wenna's journal, i", "series": "wenna", "part": 1,
		"text": "Mother sold the goat for the road-fee. The priests say at the top the sky opens like a hand. I want to see the hand."},
	"jn_2": {"region": "road", "kind": "page", "title": "Wenna's journal, ii", "series": "wenna", "part": 2,
		"text": "Bells, banners, a choir that never stops. A man said the Hierarch is already halfway up the sky. Mother walks faster now."},
	"jn_3": {"region": "chapel", "kind": "page", "title": "Wenna's journal, iii", "series": "wenna", "part": 3,
		"text": "The sky turned inward, like water down a drain. The bells on the Stair stopped one by one, from the top down."},
	"jn_4": {"region": "hearth", "kind": "page", "title": "Wenna's journal, iv", "series": "wenna", "part": 4,
		"text": "A smith-woman has fire in the old chapel. The shadows will not cross it. The abbey men call her a heretic. I am warm."},
	"jn_5": {"region": "glade", "kind": "page", "title": "Wenna's journal, v", "series": "wenna", "part": 5,
		"text": "The glade is full of small lights. The keep says they are what the lost left behind. I looked for Mother's."},
	"jn_6": {"region": "fen", "kind": "page", "title": "Wenna's journal, vi", "series": "wenna", "part": 6,
		"text": "They sink the hollowed in the fen now; the crypt is full. I am going to find Mother's stone. If this is found, I was not afraid."},
	"jn_7": {"region": "barrows", "kind": "page", "title": "Wenna's journal, vii", "series": "wenna", "part": 7,
		"text": "The brothers' mounds are sealed with iron. One seal is broken, and the bars are bent outward. I did not stay to see what bent them."},
	"jn_8": {"region": "fen", "kind": "page", "title": "Wenna's journal, viii", "series": "wenna", "part": 8,
		"text": "I found her stone. Her name, and three stones laid on it as the Abbot ordered. The heart-stone was rolled off. The mud beside it has footprints, going north."},
	"jn_9": {"region": "fen", "kind": "page", "title": "Wenna's journal, ix", "series": "wenna", "part": 9,
		"text": "The door under the abbey stands open, and something below is counting in Mother's voice. I have one candle. Keep a fire for me. W."},

	# --- The Glimmer Glade ------------------------------------------------------------------------
	"gl_shrine": {"region": "glade", "kind": "plaque", "title": "Shrine of the Lost",
		"text": "Leave a light for the ones who walked into the sky. They cannot come down, but they can see."},
	"gl_names": {"region": "glade", "kind": "tablet", "title": "A name-stone",
		"text": "For Ida, Ruth and little Pell. We kept the door open."},
	"gl_glimmers": {"region": "glade", "kind": "tablet", "title": "A carved stone",
		"text": "The glimmers are not spirits. They are only the light the sky did not swallow. It is enough. Scratched under it: The keep says otherwise. The keep says a lot."},
	"gl_hollow": {"region": "glade", "kind": "tablet", "title": "A carved stone",
		"text": "Hollow is not dead. Hollow is emptied. Do not grieve the shade; grieve the warmth."},
	"gl_ribbons": {"region": "glade", "kind": "tablet", "title": "The ribbon stakes",
		"text": "Ribbons tied by those who stayed behind. Red for the children, white for the old, blue for the ones who went up singing."},
	"gl_shoe": {"region": "glade", "kind": "plaque", "title": "A small shoe",
		"text": "A child's shoe with red thread at the heel. Pell's, the keep says. Someone keeps mending it, and the stitches are new."},

	# --- The Barrow Field and the Hollow Fen --------------------------------------------------------
	"br_seal": {"region": "barrows", "kind": "plaque", "title": "Sealed barrow",
		"text": "Sealed by order of Abbot Osric. The lay brothers sleep until the sky calls them. Do not wake what is waiting."},
	"br_rooted": {"region": "barrows", "kind": "rune", "title": "Old barrow",
		"text": "The mound was the Rooted's before the brothers took it. The old dead lie face down, toward the earth."},
	"br_descent": {"region": "barrows", "kind": "waystone", "title": "Waymark",
		"text": "To the Ossuary. The Abbot counts his faithful. He has not stopped counting."},
	"br_broken": {"region": "barrows", "kind": "plaque", "title": "A broken seal",
		"text": "The Abbot's iron is bent outward, and the slab lies in the grass face down. Whatever slept here heard a call. It was not the sky's."},
	"br_tally_1": {"region": "barrows", "kind": "ledger", "title": "The Tally, a leaf", "series": "tally", "part": 1,
		"text": "Tally of the faithful awaiting the call on this shelf, by the hand of Brother Lisle: one thousand and forty. The Abbot bids me count again."},
	"br_tally_2": {"region": "barrows", "kind": "ledger", "title": "The Tally, a leaf", "series": "tally", "part": 2,
		"text": "One thousand and forty-one. A count does not go up in a crypt. I told the Abbot. He thanked me and bade me count again."},
	"br_tally_3": {"region": "fen", "kind": "ledger", "title": "The Tally, a leaf", "series": "tally", "part": 3,
		"text": "The count is wrong every night now, and the Abbot is glad of it. He says the faithful are gathering. I have stopped going down."},
	"br_tally_4": {"region": "fen", "kind": "ledger", "title": "The Tally, a leaf", "series": "tally", "part": 4,
		"text": "Brother Lisle went down to count. Add him. Beneath, in another hand, very neat: ONE THOUSAND AND NINETY."},
	"fen_stones": {"region": "fen", "kind": "grave", "title": "Drowned grave",
		"text": "Weighted with three stones, as the Abbot ordered: one for the eyes, one for the mouth, one for the heart."},
	"fen_marta": {"region": "fen", "kind": "grave", "title": "Drowned grave",
		"text": "Here sank Marta Vell, hollowed. She came back twice. Use more stones."},
	"fen_noname": {"region": "fen", "kind": "grave", "title": "Drowned grave",
		"text": "No name. The fen keeps its own register."},
	"fen_corvin": {"region": "fen", "kind": "grave", "title": "Corvin's lamp-post",
		"text": "Brother Corvin hung a lamp here for the sunk dead. The lamp is gone. Something still lights it some nights."},
	"fen_rite": {"region": "fen", "kind": "plaque", "title": "Corvin's rite",
		"text": "Scratched into the post: a light for the eyes, so they see the way; a light for the mouth, so they need not call; a light for the heart, so it keeps."},
	"fen_pilgrim": {"region": "fen", "kind": "plaque", "title": "A cloak on the path",
		"text": "A staff, a bowl, a cloak spread flat over nothing. The hollowed leave their clothes where they stood up and walked out of them."},
	"fen_brothers": {"region": "fen", "kind": "waystone", "title": "The Brothers' Way",
		"text": "Way of the Lay Brothers, to the mounds. Walk in silence: the dead are listening for their names."},

	# --- The Ashen Rift's rim ----------------------------------------------------------------------
	"rim_bell": {"region": "rift", "kind": "plaque", "title": "A fallen bell",
		"text": "A bell off the Stair, cracked, its tongue torn out. The bells stopped from the top down. This one rang last, and longest."},
	"rim_edict_3": {"region": "rift", "kind": "plaque", "title": "Edict of the Open Door, III", "series": "edicts", "part": 3,
		"text": "THIRD EDICT, cut the morning of the Night: I will hold the door until the last of you is through. Aurel, Hierarch. Under it, later, in another hand: One is still on the Stair."},

	# --- The Thornwood ------------------------------------------------------------------------------
	"tw_climbs": {"region": "thornwood", "kind": "rune", "title": "Old-tongue tablet",
		"text": "Cut deep, in the old tongue: WHAT CLIMBS COMES DOWN HOLLOW."},
	"tw_ring": {"region": "thornwood", "kind": "rune", "title": "Old-tongue tablet",
		"text": "The Ring was here before the abbey and before the road. The keeper in it keeps the oaks. It kept them from the axes, too."},
	"tw_heart": {"region": "thornwood", "kind": "rune", "title": "Old-tongue tablet",
		"text": "The keeper's heart is in the thorn. Cut it and the wood will bleed, and stop bleeding, and forget you."},
	"tw_saint": {"region": "thornwood", "kind": "plaque", "title": "A fallen saint",
		"text": "A saint of the Open Sky, pulled down and left face-first in the moss. The Rooted do not forgive axes."},
	"tw_boundary": {"region": "thornwood", "kind": "tablet", "title": "Boundary stone",
		"text": "Abbey land, Year of Ascent 290. Beyond lie the Thornwood and its idolaters. Burn what you must."},
	"tw_cutter": {"region": "thornwood", "kind": "tablet", "title": "Woodcutter's mark",
		"text": "Three notches, then a cross, then nothing. The thorns grew over the rest."},
	"tw_axe": {"region": "thornwood", "kind": "notice", "title": "Abbey woodsmen",
		"text": "WOODSMEN: fell from the bounds westward. Wages doubled after the third man. Do not cut after dark. Do not cut the thorn."},
	"tw_song_1": {"region": "thornwood", "kind": "rune", "title": "The Song of the Ring, i", "series": "song", "part": 1,
		"text": "In the old tongue: We cut no oak. We asked the thorn to stand where the axe would come."},
	"tw_song_2": {"region": "thornwood", "kind": "rune", "title": "The Song of the Ring, ii", "series": "song", "part": 2,
		"text": "The thorn asked a heart to root in. We gave one. The root took the Ring, and the Ring took the hill."},
	"tw_song_3": {"region": "thornwood", "kind": "rune", "title": "The Song of the Ring, iii", "series": "song", "part": 3,
		"text": "Keeper, keep. Do not climb. What climbs comes down hollow, and we have no more hearts to give."},
	"tw_song_4": {"region": "thornwood", "kind": "rune", "title": "The Song of the Ring, iv", "series": "song", "part": 4,
		"text": "The last verse is chiselled away. Over the scars, in the Order's square hand: IDOLATRY. BURN IT. It did not burn."},
	# --- r31 places to find (core/world/realm/realm_pois.gd) ---------------------------------------
	"poi_belfry": {"region": "fen", "kind": "plaque", "title": "The Drowned Belfry",
		"text": "SAINT CORVIN'S BELL. Rung once for every one of the sunk, so the fen would know to keep them. The rope is rotted through. Something still rings it, some nights."},
	"poi_belfry_top": {"region": "fen", "kind": "rune", "title": "Scratched on the bell-frame",
		"text": "Four hundred and twelve. I rang them all. The Abbot sent word to stop counting aloud. I rang the next one twice."},
	"poi_charcoal": {"region": "thornwood", "kind": "notice", "title": "Burners' tally",
		"text": "CHARCOAL FOR THE FOUNDER'S FURNACE: forty clamps, oak only, no thorn. Paid by the bell. The last three clamps were never opened. They are still burning."},
	"poi_almonry": {"region": "road", "kind": "plaque", "title": "The Almonry",
		"text": "Here the abbey gave bread to the road. ONE LOAF, ONE BLESSING, ONE NIGHT. The almoner kept the loft key on his belt, and the loft full, for the day the pilgrims came back down."},
	"poi_almoner": {"region": "road", "kind": "ledger", "title": "The almoner's book",
		"text": "Loaves given up the Stair: nine thousand. Loaves given down it: none. I have stopped baking. I have not stopped unlocking the door at dusk."},
	"poi_watch": {"region": "crags", "kind": "tablet", "title": "The Watchers' Shelf",
		"text": "THE ORDER'S WATCH ON THE OPEN SKY. Light the cage when the sky turns. It turned. The cage was lit for nine nights. On the tenth there was nobody left to carry oil up."},
	"poi_watch_log": {"region": "crags", "kind": "page", "title": "A watcher's slate",
		"text": "From here you can see every fire in the valley. I count them before I sleep. Fewer each night. Tonight, one, and the one I am sitting beside."},
}

## Multi-part stories, in journal order. `count` = parts in the world.
const SERIES := {
	"wenna": {"title": "Wenna's Journal", "count": 9,
		"blurb": "Pages of a pilgrim girl's journal, scattered from the West Gate to the fen."},
	"maud": {"title": "Letters to Hobb", "count": 3,
		"blurb": "Old Maud's letters to her son, who went up the Stair. None were sent."},
	"litany": {"title": "The Kindler's Litany", "count": 3,
		"blurb": "Read aloud from the chapel's lecterns while the First Hearth was tended."},
	"ansel": {"title": "Brother Ansel", "count": 3,
		"blurb": "A penitent sent to scrape the saints' faces, who stayed."},
	"edicts": {"title": "Edicts of the Open Door", "count": 3,
		"blurb": "Hierarch Aurel's three edicts for the Night of the Open Door."},
	"tally": {"title": "The Abbot's Tally", "count": 4,
		"blurb": "Leaves of the count Abbot Osric kept of his waiting dead."},
	"song": {"title": "The Song of the Ring", "count": 4,
		"blurb": "The Rooted's verses on the Thornwood's stones, round the hill of the Ring."},
}

## Region ids in the journal's order, with the names and lines the region banner shows.
const REGION_ORDER := ["hearth", "road", "chapel", "glade", "thornwood", "henge", "fen", "barrows", "ossuary", "rift", "summit", "crags"]
const PLACE_INFO := {
	"hearth": {"name": "Hearthward", "line": "the last kindled village",
		"text": "The road's last village before the Stair. Its fires were carried home from the chapel in pots and hands; the Kindled Keg keeps the last of them. Most cottages have gone quiet."},
	"road": {"name": "The Pilgrims' Road", "line": "twelve miles of the faithful, walking",
		"text": "The paved way the pilgrims walked in from the West and East Gates, waystones counting down the miles to the Stair. Lined now with those who sat down and did not get up."},
	"chapel": {"name": "Chapel of the First Kindling", "line": "where the dark stopped at the door",
		"text": "Raised as the Chapel of the Open Sky, a house for washing pilgrims. Edda laid her coals on its altar and the gloom would not come in. Roofless, its saints defaced; the hearth still warm."},
	"glade": {"name": "The Glimmer Glade", "line": "the light the sky did not swallow",
		"text": "A clearing where the Rooted left offerings. Now a shrine to the lost: candles, ribbons, names, and a door left open for whoever comes back."},
	"thornwood": {"name": "The Thornwood", "line": "the Rooted's oaks, and what keeps them",
		"text": "The old oak valley of the Rooted, cut into by the abbey's axes and boundary walls. Their tablets still stand, turned away from the Ring."},
	"henge": {"name": "Thorn Henge", "line": "the Ring on the hill",
		"text": "The Rooted's ring of stones, and the Thornwarden bound into it to keep the oaks. It serves neither the sky nor the fire."},
	"fen": {"name": "The Hollow Fen", "line": "where the crypt's overflow was sunk",
		"text": "Low water-meadow. When the Ossuary was full, the hollowed were sunk here under three stones: eyes, mouth, heart. Some came back."},
	"barrows": {"name": "The Barrow Field", "line": "sealed until the sky calls",
		"text": "The Rooted's barrows, taken for the abbey's lay brothers and sealed with the Abbot's iron. The way down to the Ossuary begins here."},
	"ossuary": {"name": "The Ossuary", "line": "the Abbot is still counting",
		"text": "The crypt beneath the abbey, where Abbot Osric stacked and numbered the dead to wait for the sky's call."},
	"rift": {"name": "The Ashen Rift", "line": "where the Stair stood",
		"text": "Four thousand blessed steps, and then the wound. The Stair broke on the Night and the lava rose in it. The Crossing is what is left."},
	"summit": {"name": "Summit of Ascension", "line": "the door, held open",
		"text": "The Order's cathedral of the Open Sky, and the dais where Hierarch Aurel opened the door. He is still there."},
	"crags": {"name": "The Crowns", "line": "the rim the sky drains over",
		"text": "The mountain wall at the valley's north edge. The sky turns inward over it, slowly, like water round a drain."},
}

## Names for landmarks, graves and waystones (labels for builders, tests and docs).
const PLACES := {
	"hearth_green": "Hearthward Green",
	"hearth_well": "Hearth Well",
	"maud": "Maud's Cottage",
	"harrow": "The Harrows' House",
	"reed": "Reed Cottage",
	"cobb": "Cobb's Barn",
	"forge": "Edda's Forge",
	"hearth_shrine": "The Hearth Shrine",
	"chapel": "Chapel of the First Kindling",
	"chapel_yard": "The Kindlers' Yard",
	"road_gate_w": "The West Gate",
	"road_gate_e": "The East Gate",
	"road_shrine": "Shrine of the Open Sky",
	"glade_shrine": "Shrine of the Lost",
	"barrows": "The Brothers' Mounds",
	"fen_graves": "The Drowned Graves",
	"thorn_bound": "The Abbey Bounds",
	"woodsmen": "The Woodsmen's Camp",
	"rim_bell": "The Last Bell",
}

## What the reading prompt and the journal call each kind of carrier.
const KIND_NAMES := {"grave": "grave marker", "waystone": "waystone", "rune": "old carving", "page": "page",
	"notice": "notice", "plaque": "inscription", "lectern": "lectern", "letter": "letter", "ledger": "ledger leaf",
	"tablet": "carved stone"}


static func entry(id: String) -> Dictionary:
	return TEXTS.get(id, {})


static func text(id: String) -> String:
	return String(TEXTS.get(id, {}).get("text", ""))


static func ids_in(region: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in TEXTS:
		if String(TEXTS[id].region) == region:
			out.append(id)
	return out


## Entry ids of a series, by part.
static func series_ids(series: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in TEXTS:
		if String(TEXTS[id].get("series", "")) == series:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return int(TEXTS[a].part) < int(TEXTS[b].part))
	return out


static func kind_name(kind: String) -> String:
	return String(KIND_NAMES.get(kind, "inscription"))


static func place_name(region: String) -> String:
	return String(PLACE_INFO.get(region, {}).get("name", region.capitalize()))

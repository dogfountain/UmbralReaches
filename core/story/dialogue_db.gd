extends RefCounted
## Conversations (docs/STORY.md). House style (docs/LORE.md): terse, concrete, dark; nobody explains
## the world, they complain about it, mourn it, or warn you off it.
##
## A conversation: {name, portrait (DwarfRig options), start: [[cond, node], ...] (first match),
##                  nodes: {id: node}}
## A node: say (text) or say_if ([[cond, text], ...], first match; the last should have cond ""),
##         who (speaker name override; "" = narration), do ("flag:x,flag:y" set on entering),
##         next (node id, or "" to end), choices ([{text, to, if?, do?, once?}]: `to` "" ends;
##         `if` hides it; `once` hides it after it was picked).
## Conditions are QuestDB.test terms (with the task terms of quest_book.gd: q:, qat:, qd:, qp:, att:,
## ash:, secret:, secrets:). Actions in `do`: flag:x / flag:-x, and quest_book.gd's (qs: qa: qc: qp:
## att: give: grant: pay: shop: scene:). {kindled} and {ash} in text become the counts.
## Load by path: const DialogueDB := preload("res://core/story/dialogue_db.gd")

const QuestDB := preload("res://core/story/quest_db.gd")
const R38E := preload("res://core/story/quest_chains_r38_east.gd")   ## the hauler's tally is a choice (its pickup opens this)
const FRW := preload("res://core/story/quest_chains_far_reaches_west.gd")   ## the Reaches' pickups that open a conversation (a choice, a small puzzle)
const FRS := preload("res://core/story/quest_chains_far_reaches_south.gd")
const FRE := preload("res://core/story/quest_chains_far_reaches_east.gd")

const EndingQ := preload("res://core/story/quest_chains_ending.gd")   ## the long walk, its five scenes and the credits

const DeepB := preload("res://core/story/quest_chains_deepen_b.gd")   ## the countries' and the Marches' choices, made at a place (their pickups open these)

const KEEP_PORTRAIT := {"seated": false, "seed": 5150, "apron": true, "hat": "bare", "rag": true}

const _CONV := {
	"keep": {
		"name": "The Keep",
		"portrait": KEEP_PORTRAIT,
		"start": [["boss:ascended_warden,!flag:ending_told", "end_1"], ["qd:long_walk,!flag:credits_told", "credits_v"], ["qd:names_under,!flag:epilogue_told", "epi_1"], ["flag:deeper,!flag:deeper_met", "ng_1"], ["!flag:met_keep", "meet_1"], ["qat:keg_thief:4", "thief_report"], ["", "hub"]],
		"nodes": {
			# --- first meeting (the night's only errand until this is done) ------------------
			"meet_1": {"say": "Shut the door. No, leave it. The fire's done arguing with the dark tonight.", "next": "meet_2"},
			"meet_2": {"say": "You walked in off the road with a lit lantern. That makes you kindled, or mad. Either way, you drink — and you listen.", "next": "meet_hub"},
			"meet_hub": {"say": "This night has a shape. Ask me for it, or leave and learn it the hard way.", "choices": [
				{"text": "Where do I start?", "to": "start_1"},
				{"text": "What happened to this valley?", "to": "lore_1", "once": true},
				{"text": "Who holds it?", "to": "three_1", "once": true},
				{"text": "I'll find my own way.", "to": "meet_brief"},
			]},
			"lore_1": {"say": "The Order of the Open Sky taught that the sky was a door, and the faithful could climb through it. Nine winters ago, on the Night, their Hierarch opened it from the top of the Stair. It opened inward. It's been drinking ever since: the light first, then the warm, then the people.", "next": "lore_2"},
			"lore_2": {"say": "Edda put coals from her forge on a bare altar and the dark stopped at the door. Every fire since is hers. Yours too, now.", "next": "meet_hub"},
			"three_1": {"say": "Three. Something in the Ring on the western hill that keeps the oaks; the Rooted call it the Thornwarden. The Abbot under the abbey, still counting his dead.", "next": "three_2"},
			"three_2": {"say": "And whatever stands at the top of the Stair with the door open. The ward on the Crossing won't let you near it till the other two are down: a heart out of the Ring, a crown out of the crypt.", "next": "meet_hub"},
			"start_1": {"say": "First: the braziers. Four of them — the north meadow, glade shrine, Barrow Field, the fen below it. Kindle them. Light is somewhere to stand when the dark leans on you.", "next": "start_2"},
			"start_2": {"say": "Then pick a door. Thorn seal on the Thornwood edge, west. Or the gallery seal in the crypt, south down the Waiting Field's road. Both, then the door's own price, which Brannoc knows, before the Crossing will take you up to shut the sky's door.", "do": "flag:met_keep,teach:ward", "choices": [
				{"text": "Another question.", "to": "meet_hub"},
				{"text": "I'll go.", "to": "meet_end"},
			]},
			"meet_brief": {"say": "Then hear it once. Kindle the four braziers. Break the thorn seal west, or the gallery seal south, past the Waiting Field — both, then Brannoc's bells, then the Crossing, then the door at the top. The rest of Hearthward can wait until you've heard that.", "do": "flag:met_keep,teach:ward", "next": "meet_end"},
			"meet_end": {"say": "Fire stays. Hollows do not. Come back with news; we pay in ale. The village will have work for you once you've stepped out.", "do": "flag:met_keep,teach:ward", "next": ""},
			# --- the hub, every visit after ---------------------------------------------------
			"hub": {"say_if": [
				["flag:ending_told", "The kindled one. Your stool, your mug. The fire draws by itself now; I've nothing to do but pour."],
				["boss:thornwarden,boss:bone_abbot,peal:1", "Heart and crown, and a bell behind you. I heard it from here. The door will know that voice, and so will the one who holds it."],
				["boss:thornwarden,boss:bone_abbot", "Heart and crown, both. The ward will know them. Brannoc says the door won't, not without his mother's bells. He's been saying it into his cup all night. Ask him."],
				["boss:thornwarden", "Thorn Heart. Still beating? Then the wood will forget you soon enough."],
				["boss:bone_abbot", "The Abbot's crown. Did he count you? He counts everyone."],
				["seal:henge", "The thorn seal's broken. The Thornwarden will have felt it. So did the oaks."],
				["seal:oss_gallery", "The gallery's open. Down there they'll want counting. Don't let them."],
				["qp:slow_way:truth", "Ostrin's father's lantern is burning on my counter. I don't move it. Nobody moves it."],
				["att:keep:3", "The kindled one. Your stool's warm; I kept it that way. Sit."],
				["", "Back, and still kindled. Sit if you're sitting."],
			], "choices": [
				{"text": "What now?", "to": "next"},
				{"text": "What's on the slate?", "to": "slate"},
				{"text": "You look troubled, keep.", "to": "thief_ask", "if": "!q:keg_thief,flag:met_keep"},
				{"text": "About your ale thief...", "to": "thief_where", "if": "qat:keg_thief:0|qat:keg_thief:1|qat:keg_thief:2|qat:keg_thief:3"},
				{"text": "Any news?", "to": "news"},
				{"text": "Tell me again about the three.", "to": "three_again"},
				{"text": "What about the ones past the Lines?", "to": "others_1", "if": "bosses:1", "once": true},
				{"text": "Does he ever speak to the ones who climb?", "to": "voice_1", "if": "bosses:1,flag:aurel_boss_thornwarden|bosses:1,flag:aurel_boss_bone_abbot", "once": true},
				{"text": "Who are you, keep?", "to": "who_1", "once": true},
				{"text": "Goodbye.", "to": "bye"},
			]},
			"credits_v": {"say_if": EndingQ.CREDITS.verdict, "who": "", "next": "credits_1"},
			"credits_1": {"say": EndingQ.CREDITS.lines[0], "who": "", "next": "credits_2"},
			"credits_2": {"say": EndingQ.CREDITS.lines[1], "who": "", "next": "credits_3"},
			"credits_3": {"say": EndingQ.CREDITS.lines[2], "who": "", "next": "credits_4"},
			"credits_4": {"say": EndingQ.CREDITS.lines[3], "who": "", "next": "credits_5"},
			"credits_5": {"say": EndingQ.CREDITS.lines[4], "who": "", "next": "credits_6"},
			"credits_6": {"say": EndingQ.CREDITS.lines[5], "who": "", "next": "credits_7"},
			"credits_7": {"say": EndingQ.CREDITS.lines[6], "who": "", "next": "credits_8"},
			"credits_8": {"say": EndingQ.CREDITS.lines[7], "who": "", "next": "credits_9"},
			"credits_9": {"say": EndingQ.CREDITS.lines[8], "who": "", "do": "flag:credits_told", "next": ""},
			"others_1": {"say": "Two more, if you count them, out where the towns are. A cantor's note in the skull of a fallen god, and a hermit who walled herself in to pray the sky still. Not the valley's to keep. The sky's leftovers. I'd not go looking for either. But there are people out there who'd ask you to.", "next": "others_2"},
			"others_2": {"say": "Cantor Lowe, at the Siege Lines, and Tamsin Hale, who walks bread up the cliff road. They'd tell you what they are. I never learned. I stay with the fire.", "next": "hub"},
			"voice_1": {"say": "You've heard him. Don't tell me; I can see it in how you hold the lantern. He talks to the ones who climb. He's civil. That is the worst of it. Whatever's up there at the top has manners.", "next": "hub"},
			"next": {"say_if": [
				["boss:ascended_warden", "Now? Now nothing. Sit. Let the valley learn not to be pulled at. It'll take a while; it's been a while. Past the Lines, the towns have been waiting longer: Reedholm, Fallowmere, Lastlight. Corle, Penn, Maudlin. Ask Brannoc, he's had the letters."],
				["boss:thornwarden,boss:bone_abbot,!peal:1", "Not up yet. The door hears bells, not crowns. One of the Founder's eight will do for the door; the rest are for the one behind it. Ruan's, at the Holds, is the nearest. Brannoc will tell you what each is worth."],
				["boss:thornwarden,boss:bone_abbot,!qd:founders_peal", "A bell answered. Good. Tell Brannoc the door will hear it; he's been waiting to be told. Then the ward on the Crossing will take you."],
				["boss:thornwarden,boss:bone_abbot,!seal:summit", "Across the Crossing. There's a ward at the landing with guards that don't sleep. Clear them and it'll let heart and crown through. It was cut to let nobody else."],
				["boss:thornwarden,boss:bone_abbot", "Up. Whatever's at the top is halfway into the sky and stuck there. Make it let go of the door."],
				["boss:thornwarden", "The crown, then. South on the Waiting Field's road, past the tomb, to the bridge, and over it into the gallery. Mind the bones that stand up."],
				["boss:bone_abbot", "The heart, then. West road, past the glade, up the hill to the Ring. The thorn seal first."],
				["seal:henge", "Into the Ring. Cut out the heart. Don't let it sing to you."],
				["seal:oss_gallery", "Down to the charnel floor. The Abbot's on his mound. When he falls, something rises; bring it out."],
				["", "The thorn seal on the Thornwood edge, or the gallery under the abbey. The braziers first, if you've sense."],
			], "next": "hub"},
			"news": {"say_if": [
				["kindled:4", "All four braziers burning. First time since the Door. I can see the meadow fire from my door."],
				["kindled:3", "Three of four. One more and I'll stop counting them out loud."],
				["kindled:2", "Two of four. Folk have started looking up from their mugs. Not far up. Up."],
				["kindled:1", "{kindled} of four burning. I can see one from the door, if I squint. Keep going."],
				["", "Not one of the four lit. The dark's patient. Not that patient."],
			], "next": "news_2"},
			"news_2": {"say_if": [
				["qp:three_knocks:open,boss:ascended_warden", "Maud's door is off the bar. Two bowls on her table, and one is always empty and always washed. The candle's out. She doesn't need it."],
				["qp:three_knocks:answer,boss:ascended_warden", "Maud kept her candle. She says it'll do for the both of them. Something answers to her voice now, from the east road, and goes away again. She's content with that."],
				["qp:three_knocks:shut,boss:ascended_warden", "Maud's candle went out last night. She put it out herself, and the bar is still down, and the knocking stopped when the sky did. She sleeps. She says she doesn't want to know why."],
				["boss:ascended_warden", "Maud's candle went out last night. She put it out herself. Said he wasn't coming, and she was tired."],
				["elite:hobb", "The knocking's stopped on the east road. Maud still sits up for it. Habit's the last thing to go."],
				["qp:three_knocks:open", "Maud's door has been on the latch since you sat up at it. Nan says there's a second bowl on the table, and nobody's let her see why."],
				["qp:three_knocks:answer", "Maud answers the knock herself now, through the planks, in her own voice. It doesn't come in. It says her name first, and she says his."],
				["qp:three_knocks:shut", "Maud's bar stays down. Three knocks at dusk, three at dawn. She counts them the way I count barrels."],
				["secret:found:cairn,!boss:ascended_warden", "You found his stones up on the Crowns. Don't tell her. She'd go up there."],
				["qp:forty_first:faith", "Joram kneels at the forty-first stone every night. Fennick lights him a lamp. Nobody's told him. Nobody's going to."],
				["qp:slow_way:mercy", "Ostrin's stool is empty at dusk. He's down at the fen's fire with a lit lamp, and comes back at dawn and says nothing. I leave the stool."],
				["qp:drowned_bell:hung", "The fen tower rang a stroke last night. Nobody rang it. Brannoc swears he never stirred, and he sleeps like a dropped sack."],
				["qp:spire_lamps:burning", "Fennick says there's a lamp burning on the Spire. I can't see it. He walks to the green's edge every dusk and stands looking."],
				["qp:ring_heart:rooted", "Wyck sang the last verse at his fire, out loud, with a name in it. Hesk heard it from the road and sat down on the verge."],
				["qp:names_yard:confess", "Abel cut where each slate was hidden, under the names. Folk walk the long way round to read the hiders."],
				["secrets:3", "Folk say you've been opening the places the Order sealed. The Order sealed them for a reason. Usually a bad one."],
				["qp:forty_first:truth", "Joram stopped counting. Sits at the road's rest with his staff against the wall, looking down the west road the other way. First pilgrim I ever saw do that."],
				["bosses:2", "The bells. Brannoc swears he heard one in his sleep. Brannoc swears a lot."],
				["boss:bone_abbot", "Ostrin went quiet when he heard the Abbot was down. Quiet's better than what he was."],
				["boss:thornwarden", "Hesk went out to the wood's edge at dawn. Came back and ordered two. Didn't drink either."],
				["", "Pell's mother was in again. Nine winters, red hood. I said what I always say."],
			], "next": "hub"},
			"slate": {"say": "Ale, a round for the room, a rumour. Ash on the counter first.", "do": "shop:keep", "next": ""},
			"thief_ask": {"say": "Somebody's at the back keg after I bank the fire. Not much. A mug a night. But a mug a night's a barrel a winter, and no more barrels are coming up the road.", "choices": [
				{"text": "I'll find your thief.", "to": "thief_yes", "do": "qs:keg_thief"},
				{"text": "It's one mug.", "to": "thief_no", "do": "att:keep:-1"},
			]},
			"thief_yes": {"say": "Out the back, by the chimney. Whoever it is spills. I'm not a fool; I just don't go out there in the dark.", "next": "hub"},
			"thief_no": {"say": "Spoken like somebody who doesn't pay for barrels.", "next": "hub"},
			"thief_where": {"say_if": [
				["qat:keg_thief:3", "Chalk circles, you say, and the ale walking to the green's fire? Nan. It's always Nan. Go and ask her, gently. She bites."],
				["qat:keg_thief:1|qat:keg_thief:2", "Circles in chalk? Drops of ale across the green? Follow them, then. I'm not getting down on my knees at my age."],
				["", "Behind the Keg. By the chimney. Look down; thieves never look down."],
			], "next": "hub"},
			"thief_report": {"say": "Well? Who's drinking my ale?", "choices": [
				{"text": "It's Nan. She leaves a mug by the green's fire, for Pell, for when she comes back.", "to": "rep_told", "if": "qp:keg_thief:told", "do": "qc:keg_thief,att:keep:2,give:grave_ash:8"},
				{"text": "It was me. Put it on my slate. (10 ash)", "to": "rep_covered", "if": "qp:keg_thief:covered", "do": "pay:10,qc:keg_thief,att:keep:1,att:nan:1"},
				{"text": "Rats.", "to": "rep_rats", "if": "qp:keg_thief:rats", "do": "qc:keg_thief,att:keep:-1"},
				{"text": "...It's Nan. She does it for Pell.", "to": "rep_told", "if": "!qp:keg_thief:told", "do": "qp:keg_thief:told,qc:keg_thief,att:keep:2,att:nan:-3,give:grave_ash:8"},
				{"text": "Rats. Gnawing all down the chimney wall, a crust chewed to the rind.", "to": "rep_wrong", "if": "qp:keg_thief:wrong", "do": "qc:keg_thief,att:keep:-1"},
			]},
			"rep_told": {"say": "Nan. ...For Pell. I'd have known from the circles. Well. I'm not taking a mug off a child for that. I'll put one out myself, from now on. Here, for your trouble. Don't tell her I went soft. She'll come in on her own tomorrow and tell me the rest, and I'll pretend it's news.", "next": "hub"},
			"rep_covered": {"say": "You. A mug a night, quiet, by the back door. ...Right. Ten ash, and I'm watching you. There's a chalk circle behind the Keg I'm not scrubbing off, and I don't know why.", "next": "hub"},
			"rep_wrong": {"say_if": [
				["qc:keg_thief:latch", "Rats. Then I'll trap them. ...Odd rats, that put the bung back. Never mind. I'll set the trap."],
				["", "Rats. Then I'll trap them. A big one. Something small has been at my stores all winter."],
			], "next": "hub"},
			"rep_rats": {"say": "Rats. That drink ale, and draw circles. ...I'll set a trap, then. A big one. Behind the Keg, where the ale was spilled.", "next": "hub"},
			"three_again": {"say_if": [
				["boss:ascended_warden", "Were three. The Thornwarden in the Ring, Osric under the abbey, Aurel at the top. Now there's a story, and a Keg to tell it in."],
				["", "The Thornwarden in the Ring, west. The Abbot under the abbey, down the fen. And whatever holds the door at the top. Heart and crown open the ward; nothing shuts the door but you."],
			], "next": "hub"},
			"who_1": {"say": "The keep. That's the whole of it. My grandfather kept, and his. My folk dug the Keg's cellar when the Rooted still buried face down on that hill, before anybody built a Stair to climb. It'll be here after.", "next": "who_2"},
			"who_2": {"say": "I serve the kindled. Not the unlit. Not because I'm cruel; because a cold hearth is an open door, and I've only the one.", "next": "hub"},
			"bye": {"say_if": [
				["boss:ascended_warden", "Door's open. Ours, I mean. The other one's shut."],
				["boss:thornwarden,boss:bone_abbot", "Go on, then. Bring it down."],
				["", "Fire stays. Hollows do not."],
			], "next": ""},
			# --- the Deeper Night (the cracked bell rung) ---------------------------------------
			"ng_1": {"say_if": [
				["qp:the_latch:latched", "You latched it. I know you did. And still the bell rang, top first, wrong way up. Something up there has a key."],
				["qp:the_latch:broken", "You broke the latch. Brannoc showed me the halves. And still the bell rang top first. Something's hung a new door."],
				["qp:the_latch:open", "You left it on the latch, for the ones coming home. Something else came through it. I heard the bell, top first."],
				["", "You rang it. ...I heard it. Wrong way up, top first, the way they stopped."],
			], "do": "flag:deeper_met,flag:met_keep", "next": "ng_2"},
			"ng_2": {"say": "The fire's leaning again. Sit; it's going to be a long one. Then go and do it all twice.", "next": "hub"},
			# --- the end, after the Ascended Warden ------------------------------------------
			"end_1": {"say": "You're back. Then it's true. The fire went straight up the chimney an hour ago, like it used to.", "next": "end_2"},
			"end_2": {"say": "Aurel?", "choices": [
				{"text": "He let go of the door.", "to": "end_3"},
				{"text": "He was hollow. He had been for a long time.", "to": "end_3b"},
				{"text": "He was waiting for me.", "to": "end_3c"},
			]},
			"end_3": {"say": "Let go. After all that holding. ...Then the door's shut.", "next": "end_4"},
			"end_3b": {"say": "Hollow and still holding. That's faith for you. ...Then the door's shut.", "next": "end_4"},
			"end_3c": {"say": "Then he waited for nothing. You're here. Sit. ...The door's shut. Nobody else is coming through it, either way.", "next": "end_4"},
			"end_4": {"say": "The ones that went all the way through don't come back. The ones that came down hollow can lie down now. And Maud can put out her candle and sleep.", "next": "end_4b"},
			"end_4b": {"say_if": [
				["qp:slow_way:truth", "Ostrin hasn't let that lantern go out. Says his father can see it now."],
				["qp:forty_first:truth", "That pilgrim of yours went home. First one I ever saw. There'll be others, now."],
				["qp:keg_thief:told|qp:keg_thief:covered|qp:keg_thief:rats", "Nan's put a mug out by the green's fire again. I've stopped counting the barrels."],
				["", "The village will want to tell you things. Let them."],
			], "next": "end_4m"},
			"end_4m": {"say_if": [
				["qp:three_knocks:open", "Maud's door has been open since you sat up at it. Hobb lay down by her fire the night the door shut. She says he's no trouble."],
				["qp:three_knocks:gone", "Maud sat up for a knock that never came. When the door shut she put out the candle, and slept."],
				["qp:three_knocks:answer", "Maud answers the knock herself, in her own voice, and something on the step says her name back, and goes. She says that's enough of a visit."],
				["qp:three_knocks:shut", "Maud's candle went out the same night as the sky. She said she was tired. The bar's still down; I'd not touch it."],
				["", "Maud's candle's still in the window. Habit's the last thing to go."],
			], "next": "end_4n"},
			"end_4n": {"say_if": [
				["qp:long_round:stood", "Fennick lit the gate lantern himself at dawn. Never has. He says it's the one he wasn't let."],
				["qp:long_round:lit", "Fennick walked through the East Gate by your lantern's light at dawn, and did not look back."],
				["", "Fennick's pole went by the door as the sun came up. First time he's put it out at dawn."],
			], "next": "end_4f"},
			"end_4f": {"say_if": [
				["qp:forty_days:carried", "There's a tin door on a cord on your staff. I won't ask. One of that company's still on the Stair, they say. I don't know whose."],
				["qp:forty_days:buried", "The Ninth Company's buried at Aldo's root, Wyck says. Late. Forty days late. They got there."],
				["", "Wyck counts the Stair's dead of an evening. He has stopped saying the number."],
			], "next": "end_4s"},
			# the story's long tasks: what the road, the roll, the horn, the wall and the third stone came to
			"end_4s": {"say_if": [
				["qp:aurel_edicts:follow", "Perrin the scribe burned his copy-book the night the sky stopped. 'And then I follow,' he says, at the fire. 'He did.' I've told him it was your doing. He says it was the clause's."],
				["qp:aurel_edicts:scratch", "Perrin took the scratched stone hard. Then he sat down and began to copy the third edict, from memory, in a clean hand. I don't ask who for."],
				["qp:aurel_edicts:leave", "Perrin has stopped copying. He sits with the book shut. Says he's been told what the stone says, and it was the thing he was afraid of, and it is a great relief."],
				["qp:lamp_road:stair", "The road's lit, west to east, every lamp leaning at the mountain. Odile Frane walks it at dusk with an empty oil-can. Says it's the longest argument she's ever won."],
				["qp:lamp_road:home", "The road's lit, west to east, every lamp turned to Hearthward. First pilgrim down it last night wept at the Stair-foot post. Odile said that's what it's for."],
				["qp:name_on_roll:entered", "There's a line in the Tally cut in a hand nobody knows. Ione Marsh says it's the wanderer's. I said I'd never heard of a thing like that. She said, neither had she. She's kept the tin door."],
				["qp:name_on_roll:mother", "Ione Marsh stood at the Tally post a long while, her mother's name above hers. Then she went and slept in a bed, which she hasn't, she says, since she was five."],
				["", "Ione Marsh keeps her fire small in the glade. Says it's all right if nobody comes."],
			], "next": "end_4t"},
			"end_4t": {"say_if": [
				["qp:horn_end:sung", "They say the Siege Lines are quiet. The note in the skull stopped, the way a note should: on its last line. Lowe sleeps now. Out loud."],
				["qp:horn_end:left", "The skull's still singing, past the Lines. Lowe has set a second stool by the first. They say it's the loveliest noise in the valley. They say it's not meant to stop."],
				["qp:horn_end:broke", "Somebody broke the Speaking Crown's horn. It still sounds, thin and cracked. Cantor Lowe's said he can hear what the note was for now. He can't say it."],
				["qp:vow_cell:bread", "Tamsin Hale's bread is taken every night up the cliff road. She's never been thanked in words. She keeps a polished chain-link on a nail by her oven."],
				["qp:vow_cell:name", "Somebody said the Anchoress's name through her wall, and she said it back. They're saying it in the Anchorholds. Tamsin has taken to saying it, softly, when she kneads."],
				["qp:vow_cell:break", "The Anchoress's wall is down. Tamsin leaves the bread in the open now. Some mornings it's gone. Some mornings there's a stone on the cloth, to say it was seen."],
				["", "Out past the Lines a cantor and a baker still keep their small vigils. I don't think they're done."],
			], "next": "end_4c"},
			# r36 Act II: what the bells say about the night (all eight, then the ones left where they hung)
			"end_4c": {"say_if": [
				["bells:8", "Eight bells. Brannoc rang the chimney tongue till his arm gave out, then rang it with the other. Nobody asked him to stop."],
				["qp:bell_spire:rung", "A lamp on the Spire and a bell at its foot, out in the Marches. Folk went toward it from the Lines. Toward it, mind. Not away."],
				["qp:bell_moor:rung,qp:bell_mere:rung", "Cadoc's ferry bell and the moor's fog bell, both, ringing out there in the dark. Folk are coming down the road toward them. Coming down."],
				["qp:bell_necropolis:rung", "Agathe sent word. The Waiting Field heard its one stroke and lay down. All of them. Facing any way they liked."],
				["", "Not all eight. Brannoc says his mother would have wanted the set. He says it like he'll go and fetch the rest himself."],
			], "next": "end_5"},
			# r36 Act III: the epilogue, after the names are cut under the door
			"epi_1": {"say_if": [
				["qp:the_latch:latched", "Latched. Brannoc told me. Nothing new goes up now, and nothing new comes through. The sky's a lid. I sleep under it fine."],
				["qp:the_latch:broken", "Broken. Brannoc told me. No door, then. Just the sky, the way it was before anybody climbed. I keep looking up. I think I'll stop."],
				["", "On the latch. Brannoc told me. The ones still up there can come home if they want to. Two came down the road last night. One of them asked for a room."],
			], "next": "epi_2"},
			"epi_2": {"say_if": [
				["qp:drowned_bell:hung,qd:full_peal", "And all eight of her bells, and the fen tower's, with its tongue back. It rang when the eighth did, under the water, like a man clearing his throat."],
				["qd:full_peal", "And all eight of her bells, the one for the Marches too. I heard the last of them from here. Brannoc's not been sober since. Neither have I."],
				["", "Brannoc's still short of bells. He'll have them off you yet, if you stay."],
			], "next": "epi_2w"},
			"epi_2w": {"say_if": [
				["qp:wr_stand_down:burned", "Reedholm's order is ash on the fell shrine. Aud Corle keeps the book open past the last line anyway."],
				["qp:wr_stand_down:sealed", "Reedholm's order lies sealed on the fell shrine. Aud Corle says a sealed thing is a kept one."],
				["qd:wr_stand_down", "Reedholm has read the courier's order aloud. Aud Corle closed the lamp book on it."],
				["", "Nothing from Reedholm yet. Aud Corle's book is open on a courier nobody has finished."],
			], "next": "epi_2s"},
			"epi_2s": {"say_if": [
				["qd:ds_water_road", "Fallowmere has two beacons burning on the scarp. Reeve Penn writes it in the tithe roll: fires, kept."],
				["", "Fallowmere's scarp is dark. Reeve Penn is still waiting for a cart."],
			], "next": "epi_2e"},
			"epi_2e": {"say_if": [
				["qp:er_ringers_candle:douse", "Lastlight's candle is out. Sister Maudlin has stopped facing the gate."],
				["qd:er_ringers_candle", "A candle burns at the drowned Nave's door. Sister Maudlin has stopped facing the gate."],
				["", "Lastlight's shrine still faces the shut gate. Sister Maudlin has not turned round."],
			], "next": "epi_3"},
			"epi_3": {"say": "The names are cut. Your stool's your stool. That's the whole of it. Stay as long as you like; the fire won't go out without you now.", "do": "flag:epilogue_told", "next": ""},
			"end_5": {"say": "Sit. First round's for the kindled. Second's for the lost. The third's yours.", "do": "flag:ending_told", "next": ""},
		},
	},
	"hesk": {
		"name": "Hesk the Woodcutter",
		"portrait": {"seated": true, "seed": 911, "hat": "helm"},
		"start": [["boss:thornwarden,!flag:hesk_after", "after"], ["flag:met_hesk", "hub"], ["", "meet"]],
		"nodes": {
			"meet": {"say": "Mind the oaks west of the road. They remember axes. I'd know; mine's the hut by the abbey wall.", "do": "flag:met_hesk", "next": "hub"},
			"hub": {"say_if": [
				["qp:unpaid_toll:hild,qd:unpaid_toll", "Hild reground the axe. Bright both sides now, and I won't use it. It hangs over my door where I can see the edge. Well?"],
				["qd:keeper_wards,qp:unpaid_toll:cairn", "I walked out to the Holds. Gammer Ruan was at her fire. She said my brother's name before I could, and set a bowl down for me. I ate it. Well?"],
				["qp:unpaid_toll:cairn,qd:unpaid_toll", "I walked out to his cairn. The axe was on it, edge down, and a second stone beside it that wasn't mine. The Rooted leave those. First one I've ever seen left for one of ours. Well?"],
				["qp:ring_heart:rooted,boss:thornwarden", "Wyck sang it with a name in it. I heard it on the road. My grandmother's people had a name for it. I never knew it. I think it was hers. Well?"],
				["secret:open:oak", "You went in the hollow oak. I can tell. You've got that look, like the wood looked back."],
				["flag:deeper,!boss:thornwarden", "The wood's awake again. Something rang wrong last night and every oak heard it. Well?"],
				["att:hesk:2", "You're all right, for a kindled. Sit. Well?"],
				["boss:thornwarden", "The wood's quiet. I keep listening for it anyway. Well?"],
				["", "Well?"],
			], "choices": [
				{"text": "Tell me about the Ring.", "to": "ring_1"},
				{"text": "What guards the thorn seal?", "to": "seal"},
				{"text": "Nothing. Drink.", "to": ""},
			]},
			"ring_1": {"say": "The Rooted raised it before the road. My grandmother's people. Buried their dead face down. Said what climbs comes down hollow.", "next": "ring_2"},
			"ring_2": {"say": "The thing in the Ring keeps the wood. Not for the sky, not for the fire. For the wood. The abbey sent axes. It sent them back.", "next": "hub"},
			"seal": {"say_if": [
				["seal:henge", "Nothing now. You saw to that. The hill's open, up the old pilgrim stair to the stones."],
				["", "Wretches and crawlers on the Thornwood edge, along the west way past the glade. Put the lot to rest and the seal comes apart like wet bark."],
			], "next": "hub"},
			"after": {"say": "You cut it out. ...The wood's quieter. I went to the edge this morning and nothing looked at me. I don't know if that's better.", "do": "flag:hesk_after", "next": ""},
		},
	},
	"harrow": {
		"name": "Ostrin Harrow",
		"portrait": {"seated": false, "seed": 911 + 8 * 37, "hat": "hood"},
		"start": [["qat:slow_way:5", "lantern"], ["boss:bone_abbot,!flag:harrow_after", "after"], ["flag:met_harrow", "hub"], ["", "meet"]],
		"nodes": {
			"meet": {"say": "Harrow. The house with the door off its hinges is ours. Was.", "do": "flag:met_harrow", "next": "meet_2"},
			"meet_2": {"say": "Mother went up with the bells. Father went after her the slow way, down the fen.", "next": "hub"},
			"hub": {"say_if": [
				["qp:slow_way:truth", "The lantern's lit. I trim it every hour. The keep says I'm wasting oil. The keep can shut up."],
				["qp:slow_way:mercy", "Still cold, the lantern on the counter. He'll want it when he comes up. And a lit one at the fen's fire, every dusk; I walk it down myself. He'll see it. He'll come up."],
				["flag:deeper,!boss:bone_abbot", "They're counting again down there. I can hear it through the floor. Don't tell me it's the ale."],
				["secret:open:crypt", "You went in the drowned crypt. Father used to say the fen keeps what it takes, and keeps it wet. Drinking, or asking?"],
				["", "Drinking, or asking?"],
			], "choices": [
				{"text": "The fen?", "to": "fen"},
				{"text": "Your father went down the fen?", "to": "father", "if": "!q:slow_way,flag:met_keep"},
				{"text": "About your father...", "to": "father_where", "if": "q:slow_way,!qd:slow_way"},
				{"text": "How do I reach the Ossuary?", "to": "oss"},
				{"text": "Neither.", "to": ""},
			]},
			"father": {"say": "After Mother went up with the bells he took the lantern and went down. Said if the light was up there, whatever was left was down there, and somebody ought to keep it company.", "next": "father2"},
			"father2": {"say": "Six winters gone. Out on the fen, by the fen brazier below the barrows' descent. If you go that way... bring me the lantern. Whatever's holding it.", "choices": [
				{"text": "I'll find him.", "to": "father_yes", "do": "qs:slow_way,att:harrow:1"},
				{"text": "Some things stay lost.", "to": "father_no"},
			]},
			"father_yes": {"say": "Don't tell me what you find till you've found it. I'll be here. I'm always here.", "next": "hub"},
			"father_no": {"say": "That's what the keep says. Then he pours me another.", "next": "hub"},
			"father_where": {"say_if": [
				["qat:slow_way:3|qat:slow_way:4", "You've got it. And it's lit? Then don't run with it. I've seen a flame go out on a man who ran, and the man went after."],
				["qat:slow_way:2", "You've done it, then. I can see it on you. Bring me the lantern. Just the lantern."],
				["qat:slow_way:1", "Something's standing over it. I heard it in your voice. Do what you have to."],
				["", "Out on the fen, past the fen brazier below the barrows' descent. A tin lantern with our name scratched on the base."],
			], "next": "hub"},
			"lantern": {"say": "That's it. That's his. ...Lit, too. You carried it lit all that way. Was it him? Tell me.", "choices": [
				{"text": "It was him. Hollow. I put him to rest.", "to": "truth", "do": "qp:slow_way:truth,att:harrow:2"},
				{"text": "Just the lantern, in the reeds. No sign of him.", "to": "mercy", "do": "qp:slow_way:mercy"},
			]},
			"truth": {"say": "...Good. Good. He'd have hated standing. Put it on the counter where I can see it. He kept it lit for Mother; I'll keep it lit for him. Every hour I'll trim it.", "next": "keepsake"},
			"mercy": {"say": "No sign. ...Then he's still walking, somewhere down there. That's something. The one you carried, I'll set at the fen's fire for him, lit, so he can see his way up. This one, I'll keep on the counter, cold, till he comes for it.", "next": "keepsake"},
			"keepsake": {"say": "He left a few things in the house, and I can't carry all of them, and you walked a fen for me. Take one. Something that's seen the dark and come out the other side of it. Go on.", "choices": [
				{"text": "His lamp-glass.", "to": "keepsake_done", "do": "qc:slow_way:0"},
				{"text": "His old coat.", "to": "keepsake_done", "do": "qc:slow_way:1"},
				{"text": "His belt.", "to": "keepsake_done", "do": "qc:slow_way:2"},
			]},
			"keepsake_done": {"say": "Good. Wear it down the road. It knows the way, better than I do.", "next": ""},
			"fen": {"say": "Osric's brothers sank the hollowed there under three stones. Eyes, mouth, heart. When the crypt filled they ran short of stones. Some came back.", "next": "hub"},
			"oss": {"say_if": [
				["boss:bone_abbot", "Nobody's counting down there now. You saw to that. I don't go. Neither should you."],
				["seal:oss_gallery", "You've been. Then you've seen him counting. Finish it."],
				["", "South, down the Waiting Field's road and along the brow, past the tomb. A stone bridge crosses the quarry to the gate hall; the gallery beyond it is sealed, and the dead in it want counting."],
			], "next": "hub"},
			"after": {"say": "The Abbot's down? Then nobody's counting them anymore. Good. Let them lose count. Let Father lose count.", "do": "flag:harrow_after", "next": "hub"},
		},
	},
	"brannoc": {
		"name": "Brannoc Bellwright",
		"portrait": {"seated": true, "seed": 911 + 7 * 37, "hat": ""},
		"start": [["boss:ascended_warden,!flag:brannoc_after", "after"], ["flag:met_brannoc", "hub"], ["", "meet"]],
		"nodes": {
			"meet": {"say": "Mother cast the three on the rim. I cast the forty small ones for the Stair, and the big one for the summit. I heard them stop, top first.", "do": "flag:met_brannoc", "next": "meet_2"},
			"meet_2": {"say": "The summit's was bigger than this room. Whatever's up there holding the door never rang it.", "next": "hub"},
			"hub": {"say_if": [
				["flag:deeper,!boss:ascended_warden", "Somebody rang the cracked one. Top first. That's the way they stopped; that's no way to ring anything. You want something?"],
				["qd:founder_peal,!boss:ascended_warden", "Elspeth's tongue is in my chimney, warming. Cast in Mother's mould. When you go up, the bell in his hand rings her way now. Wrong for him. You want something?"],
				["qat:founder_peal:2", "That's Elspeth's wrapping. I'd know her knots in the dark. Give it here, then. You want something?"],
				["secret:solved:bells", "Somebody rang Mother's peal on the rim, the great bell first, bottom to top. You? Nobody's rung it since she died. You want something?"],
				["qp:drowned_bell:kept", "Grandfather's tongue's by the bench. It doesn't ring. I check it. Don't tell me it's an iron bar; I know what it is."],
				["qp:drowned_bell:hung", "You hung it back. Then it's ringing for the sunk again, and I'll hear it. I do, some nights, through the floor. One stroke. Don't tell me to stop listening."],
				["att:brannoc:2", "Sit down, sit down. You stood the room a round; that buys you my good ear. Which one's that. This one."],
				["", "You want something, or just the company of a man who can't hear well?"],
			], "choices": [
				{"text": "How do I reach the summit?", "to": "reach"},
				{"text": "What happens if it falls?", "to": "falls"},
				{"text": "Who's up there?", "to": "who", "if": "bosses:1", "once": true},
				{"text": "Which bell first?", "to": "bell_first", "if": "boss:thornwarden,boss:bone_abbot,!peal:1"},
				{"text": "Where do the others hang?", "to": "bell_where", "if": "boss:thornwarden,boss:bone_abbot,!peal:1"},
				{"text": "Is the peal all there is to do?", "to": "far_work", "if": "peal:1"},
				{"text": "The company.", "to": ""},
			]},
			"far_work": {"say": "Mother hung the bells for the road, not the door. The letters came to me, nine winters of them from past the Lines, and I never answered. Past the Lines they'll want ringing for other reasons. Reedholm, west: Aud Corle has the last courier's order, still sealed. Fallowmere, south: Reeve Penn wants his beacons lit. Lastlight, east: Sister Maudlin keeps a candle for ringers nobody let in. Three people, three errands. Go and be a stranger to them.", "next": "hub"},
			"bell_where": {"say": "Seven for the road, and each hangs at the last fire of its country. Ruan at the Holds. Jory at the Quarry. Ysolt on the moor. Elspeth in the Pits, her own tenor. Linnet in the Orchard. Agathe at the Field's gate. Cadoc on the Mere. Something sits in every one. And the eighth she cast for the country the Order shut out, at the Spire in the Marches. One opens the door. The rest are for him: ring a bell where it hangs and he feels it a little; carry its tongue home to my chimney and he feels it a great deal.", "next": "hub"},
			"bell_first": {"say_if": [
				["!qd:spire_coal,!qp:bell_spire:rung,!qp:bell_spire:carried", "Ruan's, at the Holds, is nearest: the Kin Bell, in her oak. Something rings it at night with hands. Put it down, then ring the bell or lift the tongue. Ring it where it hangs and the country quiets. Carry it here and he holds the door with less."],
				["!qp:bell_spire:rung,!qp:bell_spire:carried", "One's enough for the door. Any one. The Spire's, in the Marches, is the one I'd like heard: she cast it for the ones the Order shut out. But I'll not make you cross the Lines for my mother's sake."],
				["", "One is answered. I heard it. Now the others, in whatever order the road allows, as many as you've legs for. Each one is a hand off the door."],
			], "next": "hub"},
			"reach": {"say_if": [
				["boss:ascended_warden", "Reach it? There's nothing up there now but his bell, and it's rung. I'd know its voice anywhere. Sit down."],
				["", "Across the Crossing, what's left of the Stair. A ward at the landing wants proof you've beaten the other two. Heart and crown. Then the dais, under the sky."],
			], "next": "hub"},
			"who": {"say": "I cast the Hierarch's bell. Aurel's. If that's him up there, still holding the door, I cast it for nothing.", "next": "hub"},
			"falls": {"say_if": [
				["boss:ascended_warden", "He did. One bell, the right way up. I'd cast another just to hear it twice."],
				["", "The door shuts. Maybe a bell rings. I'd like to hear one ring again, the right way up."],
			], "next": "hub"},
			"after": {"say_if": [
				["qp:drowned_bell:hung", "I heard it. One bell, from the bottom, the right way up. And under it, a long way down in the fen, a second. Grandfather's. You did that, too."],
				["", "I heard it. One bell. From the bottom, the right way up. You did that."],
			], "do": "flag:brannoc_after", "next": "hub"},
		},
	},
	# r36 Act III: the latch-stone under the door (quest the_latch, step 1)
	"door_latch": {
		"name": "The Door",
		"start": [["!qat:the_latch:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The door hangs in the sky over the dais, shut, its edge a line of nothing against the stars. Under it the latch-stone has a slot the shape of the Ascension Seal. The Seal is warm in your hand.", "who": "", "choices": [
				{"text": "Latch it. Nothing new goes up, and nothing new comes through.", "to": "latched"},
				{"text": "Leave it on the latch, for the ones still climbing.", "to": "open"},
				{"text": "Break the latch on the stone.", "to": "broken"},
				{"text": "Not yet.", "to": ""},
			]},
			"latched": {"say": "The Seal goes into the slot and turns. Somewhere a long way up, a bolt goes home. The cold that leaned on your back stops leaning.", "who": "", "do": "qp:the_latch:latched,qa:the_latch", "next": ""},
			"open": {"say": "You lay the Seal in the slot and do not turn it. The door stays shut. It would open, now, from the other side, to a hand that wanted it to.", "who": "", "do": "qp:the_latch:open,qa:the_latch", "next": ""},
			"broken": {"say": "You set the Seal on the stone and bring the staff down on it. It breaks clean, like a bell cast too cold. Overhead the line of the door fades out of the sky, and there are only stars.", "who": "", "do": "qp:the_latch:broken,qa:the_latch", "next": ""},
			"gone": {"say": "The latch-stone. What's done is done.", "who": "", "next": ""},
		},
	},
	# deepen A (docs/QUEST_DEPTH.md): the choices the deepened tasks make at a place in the world (the pickup's `conv`)
	"yard_cut": {
		"name": "The Yard's wall",
		"start": [["!qat:names_yard:2", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The wall by Edda's stone is bare but for the numbers the Order cut and Abel scraped off. The chisel lies on the sill with the three slates. Maren Coyle. Tam. Sister Ide. You can cut them as they were named, or as they were hidden.", "who": "", "choices": [
				{"text": "Cut each name, and under it where its slate hid, so the hiders are named too.", "to": "confess"},
				{"text": "Cut the three names. Deep, and no more.", "to": "deep"},
				{"text": "Not yet.", "to": ""},
			]},
			"confess": {"say": "MAREN COYLE, who sang the low part: the choir hid her. TAM, the carter's boy: a carter hid him. SISTER IDE, who kept the bees: a sister hid her, and was not found. You cut until the chisel is warm. It takes longer than the names did. Behind you in the dark, somebody who is not Abel reads them out under their breath.", "who": "", "do": "qp:names_yard:confess,att:abel:1,qa:names_yard", "next": ""},
			"deep": {"say": "MAREN COYLE. TAM. SISTER IDE. Three names, as deep as the stone will take, and nothing round them. They will outlast the wall.", "who": "", "do": "qp:names_yard:deep,qa:names_yard", "next": ""},
			"gone": {"say": "The names are cut in the wall by Edda's stone.", "who": "", "next": ""},
		},
	},
	"belfry_tongue": {
		"name": "The belfry's bell",
		"start": [["!qat:drowned_bell:3", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The clapper lies in the reeds where the water dropped it, a yard of black iron, cold, humming when you lift it. The bell hangs over you with its mouth open and nothing in it. Brannoc wants the tongue. The bell would like it back.", "who": "", "choices": [
				{"text": "Take the tongue to Brannoc.", "to": "kept"},
				{"text": "Hang it back in the bell.", "to": "hung"},
				{"text": "Not yet.", "to": ""},
			]},
			"kept": {"say": "The iron is heavy and does not stop humming until you wrap it. Behind you the belfry rings once, from nothing, the way a house settles.", "who": "", "do": "qp:drowned_bell:kept,qa:drowned_bell", "next": ""},
			"hung": {"say": "You wade up to the sill, lift the tongue, and fit it in its loop. It hangs true. The bell speaks once, under the water, a long low note, and the fen goes quiet round it the way a room does when someone is finally asked.", "who": "", "do": "qp:drowned_bell:hung,qa:drowned_bell", "next": ""},
			"gone": {"say_if": [["qp:drowned_bell:hung", "The tongue hangs in the drowned bell again."], ["", "The bell hangs mouth open over the water, and nothing in it."]], "who": "", "next": ""},
		},
	},
	"spire_cradle": {
		"name": "The Spire's lamp",
		"start": [["!qat:spire_lamps:3", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The lamp sits in the Spire's cradle, small and steady, and the sky has turned once over it. The Order kept it burning to watch the sky by. Nobody is left to watch.", "who": "", "choices": [
				{"text": "Leave it burning. Whoever climbs next will find it lit.", "to": "burning"},
				{"text": "Put it out. It is a long way up to burn for no one.", "to": "out"},
				{"text": "Not yet.", "to": ""},
			]},
			"burning": {"say": "You leave the flame in its cradle. From up here you can see the whole valley, and the green's fire, and one lamp on a pole moving slowly along the road, very small.", "who": "", "do": "qp:spire_lamps:burning,qa:spire_lamps", "next": ""},
			"out": {"say": "You pinch the wick. The dark comes in at once from the Crowns, as if it had been standing at the edge of the light with its hat in its hand.", "who": "", "do": "qp:spire_lamps:out,qa:spire_lamps", "next": ""},
			"gone": {"say_if": [["qp:spire_lamps:burning", "The lamp burns in the cradle."], ["", "The cradle is dark."]], "who": "", "next": ""},
		},
	},
	"heart_whose": {
		"name": "The Thorn Heart",
		"start": [["!qat:ring_heart:3", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The Heart lies in the roots, a knot of bark the size of two fists, still warm, and caught in it like a splinter, a thorn as long as a finger. Round it, in the Rooted's hand, worn nearly smooth, a name or a title. Wyck will want a thorn. He will want to know whose it was.", "who": "", "choices": [
				{"text": "It was nobody's. A thing the Rooted made to keep a wood.", "to": "nobody"},
				{"text": "It was somebody's. Someone gave it, and kept nothing back.", "to": "rooted"},
				{"text": "Not yet.", "to": ""},
			]},
			"nobody": {"say": "You take the thorn. The bark round the worn place goes soft and lets you, and you do not read what it says. The wood is very quiet.", "who": "", "do": "qp:ring_heart:nobody,qa:ring_heart", "next": ""},
			"rooted": {"say": "You take the thorn and read the worn place by touch. A name is a shape under the thumb. You do not say it. The oaks all round you lean, a hair, to hear.", "who": "", "do": "qp:ring_heart:rooted,qa:ring_heart", "next": ""},
			"gone": {"say": "The Heart is cut. The roots have gone still.", "who": "", "next": ""},
		},
	},
	"toll_axe": {
		"name": "The bell-post",
		"start": [["!qat:unpaid_toll:3", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say_if": [
				["qc:unpaid_toll:haft", "The axe-head hangs on its hook, bright on one side, and fits the split haft you read: the butt burned with Hesk's family's mark. The edge has been kept sharp by hands that did not know whose it was. Hesk will not use it. Hild could set the edge. A cairn could hold it."],
				["", "The axe-head hangs on its hook by the bell's. Bright on one side, kept sharp. It is Hesk's brother's; it has to be. Hild could set the edge. A cairn could hold it."],
			], "who": "", "choices": [
				{"text": "Take it to Hild. A forge can set an edge.", "to": "hild"},
				{"text": "Lay it on his brother's cairn.", "to": "cairn"},
				{"text": "Not yet.", "to": ""},
			]},
			"hild": {"say": "You lift the head off its hook. It is heavier than it looks, and the bright side is warm. Hild will know what to do with a thing that has been kept sharp and never used.", "who": "", "do": "qp:unpaid_toll:hild,qa:unpaid_toll,att:hild:1", "next": ""},
			"cairn": {"say": "You lift the head off its hook and carry it as you would carry something asleep. There is a cairn in the oaks near the road where a woodcutter's brother is. You lay the axe on it, edge down.", "who": "", "do": "qp:unpaid_toll:cairn,qa:unpaid_toll,att:hesk:1", "next": ""},
			"gone": {"say": "The hook is empty.", "who": "", "next": ""},
		},
	},
	"tally_judge": {
		"name": "The last Tally post",
		"start": [["!qat:bead_count:2", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "Under ADD HIM the figure ONE THOUSAND AND NINETY is cut, and beside it a thumb has smeared a nought. Brother Lisle counted twice and both times it went up. The beads in your hand say 1,041. Is Lisle one of the dead, or the man who counted them?", "who": "", "choices": [
				{"text": "Add him. He was counted. The dead are owed their number: 1,090.", "to": "add", "if": "qc:bead_count:p4"},
				{"text": "Strike him. He went down to count, and was never theirs: 1,089.", "to": "strike", "if": "qc:bead_count:board"},
				{"text": "Leave it as it was written. It isn't mine to judge.", "to": "stand"},
				{"text": "Not yet.", "to": ""},
			]},
			"add": {"say": "You take a nail to the post and scratch a plain line under ADD HIM: yes. A cold hand seems to rest on yours, to be thanked. 1,090. Lisle is among them.", "who": "", "do": "qp:bead_count:add,qa:bead_count,att:abel:1", "next": ""},
			"strike": {"say": "You scrape the glad ADD HIM off with the point of your knife and cut one stroke through the ninety. Under it, small, you write Lisle's own words: I COUNTED TWICE. 1,089. The post looks lighter.", "who": "", "do": "qp:bead_count:strike,qa:bead_count,att:abel:1", "next": ""},
			"stand": {"say": "You leave the post as it is. The numbers sit on it, glad and wrong, or right. Not yours to say.", "who": "", "do": "qp:bead_count:stand,qa:bead_count", "next": ""},
			"gone": {"say": "The post is cut. Lisle's line is the last on it.", "who": "", "next": ""},
		},
	},
	"maud_door": {
		"name": "Maud's door",
		"start": [["!qat:three_knocks:2", "gone"], ["elite:hobb", "hobb_gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The bar is down. Three knocks have come and the step is quiet. Close on the other side of the planks, something breathes the way a man does who has walked a long way. Behind you, in the window, Maud is sitting up with the candle, not looking at you. 'If it doesn't say my name,' her letter said, 'I won't lift it.'", "who": "", "choices": [
				{"text": "Lift the bar. Let him in.", "to": "open"},
				{"text": "Leave the bar down. Sit with it till morning.", "to": "shut"},
				{"text": "Say her name through the door, in her voice: 'Hobb. It's Mam. Say it first.'", "to": "answer"},
				{"text": "Not yet.", "to": ""},
			]},
			"open": {"say": "The bar comes up. He is standing on the step in a coat that was his own, and he looks at the candle and not at you. He walks in past you and sits down on the boards by her fire, coat over his face. He does not lie down. Maud covers his shoulders. She does not say thank you. She says: he always did sit like that.", "who": "", "do": "qp:three_knocks:open,qa:three_knocks,att:nan:1", "next": ""},
			"shut": {"say": "You leave the bar down, and sit with your back to the door. It knocks once more and then lies against the wood on the other side. At dawn it is gone. The chalk on the step has been rubbed out by something that did not step over it.", "who": "", "do": "qp:three_knocks:shut,qa:three_knocks", "next": ""},
			"answer": {"say": "Your voice goes through the planks in an old woman's cadence you did not know you had. 'Hobb. It's Mam. Say it first.' A long wait. Then something says a word, wrongly, and tries again, and gets it. It does not ask to be let in. It stands there until the candle gutters, and goes away down the east road.", "who": "", "do": "qp:three_knocks:answer,qa:three_knocks,att:nan:1", "next": ""},
			"hobb_gone": {"say": "The bar is down. Nothing knocks. You sit the night out against the planks, and the step stays quiet, and in the window Maud trims the candle for nobody on the road. Whatever came down the east road is not coming. She will sit up for it anyway.", "who": "", "do": "qp:three_knocks:gone,qa:three_knocks,att:nan:1", "next": ""},
			"gone": {"say_if": [["qp:three_knocks:gone", "The bar is down, and the step is quiet."], ["qp:three_knocks:open", "The door is on the latch."], ["qp:three_knocks:answer", "The bar is down, and the step is quiet."], ["", "The bar is down."]], "who": "", "next": ""},
		},
	},
	"ninth_token": {
		"name": "Aldo's root",
		"start": [["!qat:forty_days:2", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say_if": [
				["qc:forty_days:whole", "Aldo's root, and the long mound under it, and his name cut in the wood: ALDO OF THE NINTH. HE WALKED THE WHOLE ROAD. The spade is still standing. In your hands: the ash and tin of the burned tokens, and one whole one, on its cord, worn smooth by a thumb. Bury it with him, or keep it."],
				["", "Aldo's root, and the long mound under it, and his name cut in the wood: ALDO OF THE NINTH. HE WALKED THE WHOLE ROAD. The spade is still standing. In your hands: the ash and tin of the burned tokens."],
			], "who": "", "choices": [
				{"text": "Bury it all with Aldo, the whole token too.", "to": "buried", "if": "qc:forty_days:whole"},
				{"text": "Bury the ash with Aldo. Keep the whole token.", "to": "carried", "if": "qc:forty_days:whole"},
				{"text": "Bury what you found with Aldo.", "to": "buried", "if": "!qc:forty_days:whole"},
				{"text": "Not yet.", "to": ""},
			]},
			"buried": {"say": "You dig with the Ninth's own spade and put them in: ash, tin, and the whole door on its cord if you found it, with Aldo's. You turn the earth face down, as Wyck would, so that nothing climbs out. The wood remembers what the company could not carry.", "who": "", "do": "qp:forty_days:buried,qa:forty_days", "next": ""},
			"carried": {"say": "You bury the ash, and keep the whole one. The cord is warm from the lean-to pole. It does not feel like tin. You do not know why you are keeping it, and you put it away without looking at it again.", "who": "", "do": "qp:forty_days:carried,qa:forty_days", "next": ""},
			"gone": {"say": "The mound is turned. The spade is gone from beside it.", "who": "", "next": ""},
		},
	},
	# r36 Act II: The Kin Bell (quest bell_holds, step 1; the pickup opens this)
	"bell_holds": {
		"name": "The Kin Bell",
		"start": [["!qat:bell_holds:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "A small bronze bell in the oak's fork on a rope of plaited bark. The Rooted carved their knot above it: they never asked for it, and kept it anyway.", "who": "", "choices": [
				{"text": "Ring it here, for the kin.", "to": "rung"},
				{"text": "Lift the tongue out, for Hearthward.", "to": "carried"},
				{"text": "Leave it for now.", "to": ""},
			]},
			"rung": {"say": "You ring it slow, the way dusk is rung. Far off in the Holds a door opens. Then another.", "who": "", "do": "qp:bell_holds:rung,qa:bell_holds", "next": ""},
			"carried": {"say": "You lift the tongue out of its loop. Bark and lichen come away on the iron, and it hangs from your hand like a sleeper's arm. The Holds' bell hangs dumb.", "who": "", "do": "qp:bell_holds:carried,qa:bell_holds", "next": ""},
			"gone": {"say_if": [["qp:bell_holds:carried", "The bell hangs dumb and empty; the loop is bare where you took the tongue."], ["", "The bell hangs where you left it, tongue and all."]], "who": "", "next": ""},
		},
	},
	# r36 Act II: The Mason's Bell (quest bell_quarry, step 1; the pickup opens this)
	"bell_quarry": {
		"name": "The Mason's Bell",
		"start": [["!qat:bell_quarry:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "An iron bell slung from the crane's arm, the rope tied off at the stop stroke and cut above the knot. The block under it carries every cutter's mark in the quarry.", "who": "", "choices": [
				{"text": "Ring it here, for the cutters.", "to": "rung"},
				{"text": "Lift the tongue out, for Hearthward.", "to": "carried"},
				{"text": "Leave it for now.", "to": ""},
			]},
			"rung": {"say": "You ring stop. The quarry, which has never been quiet, goes quiet. Somewhere a pick is set down on stone.", "who": "", "do": "qp:bell_quarry:rung,qa:bell_quarry", "next": ""},
			"carried": {"say": "You lift the tongue out of its loop. Stone dust is ground into the iron, grey in every pit of it, and your palm comes away white. The bell hangs dumb.", "who": "", "do": "qp:bell_quarry:carried,qa:bell_quarry", "next": ""},
			"gone": {"say_if": [["qp:bell_quarry:carried", "The bell hangs dumb and empty; the loop is bare where you took the tongue."], ["", "The bell hangs where you left it, tongue and all."]], "who": "", "next": ""},
		},
	},
	# r36 Act II: The Wayfarer's Bell (quest bell_moor, step 1; the pickup opens this)
	"bell_moor": {
		"name": "The Wayfarer's Bell",
		"start": [["!qat:bell_moor:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The fog bell on its post, green with weather. The ground round it is worn to stone by people who walked here in the murk and stood waiting for it to ring.", "who": "", "choices": [
				{"text": "Ring it here, for the moor.", "to": "rung"},
				{"text": "Lift the tongue out, for Hearthward.", "to": "carried"},
				{"text": "Leave it for now.", "to": ""},
			]},
			"rung": {"say": "You ring it into the dark, slow, a step's length apart. Out on the moor something stops walking toward the bog.", "who": "", "do": "qp:bell_moor:rung,qa:bell_moor", "next": ""},
			"carried": {"say": "You lift the tongue out of its loop. Fog has beaded on it and runs cold down your wrist. The bell hangs dumb; the moor does not notice.", "who": "", "do": "qp:bell_moor:carried,qa:bell_moor", "next": ""},
			"gone": {"say_if": [["qp:bell_moor:carried", "The bell hangs dumb and empty; the loop is bare where you took the tongue."], ["", "The bell hangs where you left it, tongue and all."]], "who": "", "next": ""},
		},
	},
	# r36 Act II: The Tenor (quest bell_foundry, step 1; the pickup opens this)
	"bell_foundry": {
		"name": "The Tenor",
		"start": [["!qat:bell_foundry:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The Founder's tenor, mouth-down in the casting pit as she left it. Her mark on the shoulder is an open hand. Your palm fits it.", "who": "", "choices": [
				{"text": "Ring it here, for the pits.", "to": "rung"},
				{"text": "Lift the tongue out, for Hearthward.", "to": "carried"},
				{"text": "Leave it for now.", "to": ""},
			]},
			"rung": {"say": "You ring the Tenor where it was cast. The slag heaps hum back at it, every one, a note lower.", "who": "", "do": "qp:bell_foundry:rung,qa:bell_foundry", "next": ""},
			"carried": {"say": "You lift the tongue out of its loop. It is still warm from the pits, and the iron ticks as it cools in your hand. The Tenor hangs dumb.", "who": "", "do": "qp:bell_foundry:carried,qa:bell_foundry", "next": ""},
			"gone": {"say_if": [["qp:bell_foundry:carried", "The bell hangs dumb and empty; the loop is bare where you took the tongue."], ["", "The bell hangs where you left it, tongue and all."]], "who": "", "next": ""},
		},
	},
	# r36 Act II: The Harvest Bell (quest bell_orchard, step 1; the pickup opens this)
	"bell_orchard": {
		"name": "The Harvest Bell",
		"start": [["!qat:bell_orchard:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The harvest bell, dug half out of the ash, a bronze apple branch cast round its waist. One apple is worn bright by thumbs.", "who": "", "choices": [
				{"text": "Ring it here, for the orchard.", "to": "rung"},
				{"text": "Lift the tongue out, for Hearthward.", "to": "carried"},
				{"text": "Leave it for now.", "to": ""},
			]},
			"rung": {"say": "You ring the harvest in. Nothing to bring in. The burned rows listen anyway, the way trees do.", "who": "", "do": "qp:bell_orchard:rung,qa:bell_orchard", "next": ""},
			"carried": {"say": "You lift the tongue out of its loop. Ash comes off it like flour, and under the ash the iron is stained the colour of a burned apple. The bell hangs dumb.", "who": "", "do": "qp:bell_orchard:carried,qa:bell_orchard", "next": ""},
			"gone": {"say_if": [["qp:bell_orchard:carried", "The bell hangs dumb and empty; the loop is bare where you took the tongue."], ["", "The bell hangs where you left it, tongue and all."]], "who": "", "next": ""},
		},
	},
	# r36 Act II: The Passing Bell (quest bell_necropolis, step 1; the pickup opens this)
	"bell_necropolis": {
		"name": "The Passing Bell",
		"start": [["!qat:bell_necropolis:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "The Passing Bell on its frame, the new rope coiled at its foot. The rope is braided hair: grey, brown, a child's yellow.", "who": "", "choices": [
				{"text": "Ring it here, for the field.", "to": "rung"},
				{"text": "Lift the tongue out, for Hearthward.", "to": "carried"},
				{"text": "Leave it for now.", "to": ""},
			]},
			"rung": {"say": "One stroke. For all of them. The ranks of the Waiting Field do not turn to face the mountain. For once.", "who": "", "do": "qp:bell_necropolis:rung,qa:bell_necropolis", "next": ""},
			"carried": {"say": "You lift the tongue out of its loop. Names are scratched in the lip of the bell, hundreds, small and crooked, and your thumb finds them on the way out. The bell hangs dumb.", "who": "", "do": "qp:bell_necropolis:carried,qa:bell_necropolis", "next": ""},
			"gone": {"say_if": [["qp:bell_necropolis:carried", "The bell hangs dumb and empty; the loop is bare where you took the tongue."], ["", "The bell hangs where you left it, tongue and all."]], "who": "", "next": ""},
		},
	},
	# The Shut-Out Bell (quest bell_spire, step 1; the pickup opens this)
	"bell_spire": {
		"name": "The Shut-Out Bell",
		"start": [["!qat:bell_spire:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "A bell hung low on a black oak post at the Spire's foot, the lamp-wick wrapped round its tongue cut through. Round the shoulder, in a small hand: FOR WHOEVER IS OUTSIDE.", "who": "", "choices": [
				{"text": "Ring it here, for the Marches.", "to": "rung"},
				{"text": "Lift the tongue out, for Hearthward.", "to": "carried"},
				{"text": "Leave it for now.", "to": ""},
			]},
			"rung": {"say": "You ring it once, plainly, as you would knock. The note goes out over the lake and does not come back. Somewhere past the Lines a door is opened from inside.", "who": "", "do": "qp:bell_spire:rung,qa:bell_spire", "next": ""},
			"carried": {"say": "You lift the tongue out of its loop. The wick comes away in your fingers, grey and soft with nine winters, and the iron under it is warm. The bell hangs dumb over the lake.", "who": "", "do": "qp:bell_spire:carried,qa:bell_spire", "next": ""},
			"gone": {"say_if": [["qp:bell_spire:carried", "The bell hangs dumb and empty; the loop is bare where you took the tongue."], ["", "The bell hangs where you left it, tongue and all."]], "who": "", "next": ""},
		},
	},
	# r36 Act II: The Ferry Bell (quest bell_mere, step 1; the pickup opens this)
	"bell_mere": {
		"name": "The Ferry Bell",
		"start": [["!qat:bell_mere:1", "gone"], ["", "at"]],
		"nodes": {
			"at": {"say": "Corvin's ferry bell on its post at the water's edge, weed on the bronze below the line the mere rose to. CALL AND WAIT, cut in the post.", "who": "", "choices": [
				{"text": "Ring it here, for the mere.", "to": "rung"},
				{"text": "Lift the tongue out, for Hearthward.", "to": "carried"},
				{"text": "Leave it for now.", "to": ""},
			]},
			"rung": {"say": "You ring for the ferry. Out on the black water an oar dips, once, and does not come closer. It does not need to.", "who": "", "do": "qp:bell_mere:rung,qa:bell_mere", "next": ""},
			"carried": {"say": "You lift the tongue out of its loop. It is slick with mere water, and smells of reeds and a long time under. The bell hangs dumb across the black water.", "who": "", "do": "qp:bell_mere:carried,qa:bell_mere", "next": ""},
			"gone": {"say_if": [["qp:bell_mere:carried", "The bell hangs dumb and empty; the loop is bare where you took the tongue."], ["", "The bell hangs where you left it, tongue and all."]], "who": "", "next": ""},
		},
	},
	"r38_tally": R38E.CONVS["r38_tally"],
	"wr_order": FRW.CONVS["wr_order"], "wr_herons": FRW.CONVS["wr_herons"], "ds_nail_door": FRS.CONVS["ds_nail_door"], "er_slate": FRE.CONVS["er_slate"],
	# --- the story's long tasks ---
	# --- deepen B ---
	"qb_holds_turf": DeepB.CONVS["qb_holds_turf"], "qb_keeper_wards": DeepB.CONVS["qb_keeper_wards"], "qb_oak_song": DeepB.CONVS["qb_oak_song"], "qb_quarry_last": DeepB.CONVS["qb_quarry_last"], "qb_moor_shrine": DeepB.CONVS["qb_moor_shrine"], "qb_orchard_press": DeepB.CONVS["qb_orchard_press"], "qb_field_ranks": DeepB.CONVS["qb_field_ranks"], "qb_mere_light": DeepB.CONVS["qb_mere_light"], "qb_mere_ferryman": DeepB.CONVS["qb_mere_ferryman"], "qb_well_answer": DeepB.CONVS["qb_well_answer"], "qb_salt_widow": DeepB.CONVS["qb_salt_widow"], "qb_spire_coal": DeepB.CONVS["qb_spire_coal"], "qb_seventh_day": DeepB.CONVS["qb_seventh_day"], "qb_shepherd_strays": DeepB.CONVS["qb_shepherd_strays"], "qb_wf_lights": DeepB.CONVS["qb_wf_lights"], "qb_wf_crown": DeepB.CONVS["qb_wf_crown"], "qb_long_round": DeepB.CONVS["qb_long_round"],
}

## The story seat's conversations (the places' choices, quest_chains_added.gd) merge in once, at first use.
const Added := preload("res://core/story/quest_chains_added.gd")
static var CONV: Dictionary = _merge(_CONV, Added.convs())


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := a.duplicate()
	d.merge(b)
	return d


## Narration beats (non-blocking subtitles).
const OPENING := [
	"The road ran out of pilgrims a long time ago. Past Hearthward there is only the dark, and the sky it opened.",
	"Over the Crowns the sky turns inward. The cold comes down the mountain to meet you.",
	"There is light in the Kindled Keg. Find the keep. He will tell you what this night is for.",
]
## A New Game after an ending (core/util/profile.gd keeps the count): the same three beats, spoken by someone who has been here.
const OPENING_AGAIN := [
	"The road ran out of pilgrims once, and you walked it to its end. The sky has turned a little more since.",
	"The door you shut has a latch, and a latch is not a wall. The cold comes down the mountain to meet you again.",
	"There is light in the Kindled Keg. They will not remember you. The fire will. Find the keep.",
]
const ENDING := [
	"The sky stops turning.",
	"Somewhere above the Crowns, a bell rings once. From the bottom up.",
	"The cold stays. It no longer pulls.",
]


## The node a conversation opens on for this world state.
static func start_node(conv_id: String, ws: Dictionary) -> String:
	var c: Dictionary = CONV.get(conv_id, {})
	for pair: Array in c.get("start", []):
		if QuestDB.test(String(pair[0]), ws):
			return String(pair[1])
	return ""


static func node(conv_id: String, node_id: String) -> Dictionary:
	return ((CONV.get(conv_id, {}) as Dictionary).get("nodes", {}) as Dictionary).get(node_id, {})


## The line a node says for this world state (say, or the first matching say_if).
static func text_of(n: Dictionary, ws: Dictionary) -> String:
	var t := String(n.get("say", ""))
	if n.has("say_if"):
		for pair: Array in n.say_if:
			if QuestDB.test(String(pair[0]), ws):
				t = String(pair[1])
				break
	return t.replace("{kindled}", str(int(ws.get("kindled", 0)))).replace("{ash}", str(Travel.count("grave_ash")))


## The choices shown for a node: [{text, to, do, key}], filtered by `if` and `once` (seen picks).
static func choices_of(conv_id: String, node_id: String, n: Dictionary, ws: Dictionary, picked: Dictionary) -> Array:
	var out: Array = []
	var i := 0
	for ch: Dictionary in n.get("choices", []):
		var key := "%s/%s/%d" % [conv_id, node_id, i]
		i += 1
		if ch.has("if") and not QuestDB.test(String(ch["if"]), ws):
			continue
		if ch.get("once", false) and picked.has(key):
			continue
		out.append({"text": ch.text, "to": ch.get("to", ""), "do": ch.get("do", ""), "key": key})
	return out


## Integrity: every target exists, every condition parses, every node says something. [] = fine.
static func audit() -> Array:
	var bad: Array = []
	for cid: String in CONV:
		var c: Dictionary = CONV[cid]
		var nodes: Dictionary = c.nodes
		for pair: Array in c.start:
			if not nodes.has(String(pair[1])):
				bad.append("%s: start -> missing %s" % [cid, pair[1]])
			var e := QuestDB.audit_cond(String(pair[0]))
			if e != "":
				bad.append("%s: %s" % [cid, e])
		for nid: String in nodes:
			var n: Dictionary = nodes[nid]
			if not n.has("say") and not n.has("say_if"):
				bad.append("%s/%s: says nothing" % [cid, nid])
			if n.has("say_if"):
				var last: Array = n.say_if[n.say_if.size() - 1]
				if String(last[0]) != "":
					bad.append("%s/%s: say_if has no fallback" % [cid, nid])
				for pair2: Array in n.say_if:
					var e2 := QuestDB.audit_cond(String(pair2[0]))
					if e2 != "":
						bad.append("%s/%s: %s" % [cid, nid, e2])
			var nx := String(n.get("next", ""))
			if nx != "" and not nodes.has(nx):
				bad.append("%s/%s: next -> missing %s" % [cid, nid, nx])
			if not n.has("next") and not n.has("choices"):
				bad.append("%s/%s: neither next nor choices" % [cid, nid])
			for ch: Dictionary in n.get("choices", []):
				var to := String(ch.get("to", ""))
				if to != "" and not nodes.has(to):
					bad.append("%s/%s: choice -> missing %s" % [cid, nid, to])
	return bad

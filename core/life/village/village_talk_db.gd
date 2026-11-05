extends RefCounted
## What Hearthward's people say (village system; no class_name). Same shape as the story's
## DialogueDB (docs/STORY.md): {name, start: [[cond, node], ...], nodes: {id: node}}; a node has
## `say` or `say_if` ([[cond, text], ...], first match, last unconditional), optional `do`,
## and `next` or `choices` ([{text, to, if?, do?, once?}]). A say_if entry may carry a third element,
## actions run when that line is the one said ([cond, text, do]: a line said once, then retired).
## Conditions: VillageState.test (QuestDB
## terms + v:, met:, ash:, hollows:, and the task terms q:, qat:, qd:, qp:, att:, secret:, secrets:).
## Actions in `do`: met:x, v:x (a village flag), and quest_book.gd's (qs: qa: qc: qp: att: give:
## grant: pay: shop:). Text: {ash}, {hollows}, {kindled}.
## House style (docs/LORE.md): terse, concrete, dark. Load by path.

const CONV := {
	"hild": {"name": "Hild", "start": [["!met:hild", "meet"], ["qat:edda_tongs:1", "tongs_back"], ["", "hub"]], "nodes": {
		"meet": {"say": "Mind the sparks. They're the only warm thing in the valley that still bites.", "next": "meet2"},
		"meet2": {"say": "Edda was my grandmother. She carried coals from this hearth to the chapel. I keep it in. Somebody has to.", "do": "met:hild", "next": "hub"},
		"hub": {"say_if": [
			["boss:ascended_warden", "Feel that? The sky's stopped pulling at the bellows. First night in years the fire draws on its own."],
			["qp:edda_tongs:forge,qd:edda_tongs,att:hild:3", "Her tongs sit right in the hand. Like they waited for a smith who'd stop crying long enough to pick them up."],
			["qp:edda_tongs:stone,qd:edda_tongs", "Abel says her stone's been warm since you laid the tongs on it. Abel says a lot of things. I went and felt it."],
			["bosses:2", "Two of the three down. I'm forging hinges again. People only want hinges when they mean to stay."],
			["bosses:1", "One of them down. The iron takes a temper again. Grandmother would say it was listening."],
			["kindled:1", "You've been lighting braziers. I can tell. The coals sit up straighter."],
			["", "Heat, hammer, quench. The dark doesn't come near a forge that's working."],
		], "choices": [
			{"text": "What are you making?", "to": "make"},
			{"text": "Tell me about Edda.", "to": "edda", "once": true},
			{"text": "You look like you want something.", "to": "ask", "if": "!q:edda_tongs,met:hild"},
			{"text": "About Edda's tongs...", "to": "tongs_where", "if": "qat:edda_tongs:0|qat:edda_tongs:2"},
			{"text": "Can you make something for me?", "to": "", "do": "shop:hild", "if": "v:svc_smith"},
			{"text": "Could you forge for me?", "to": "forge_later", "if": "!v:svc_smith,met:hild"},
			{"text": "How is the village?", "to": "village"},
			{"text": "Goodbye.", "to": ""},
		]},
		"ask": {"say": "Grandmother's tongs. She lifted the coals in them till the jaws burned black, then carried the rest in her apron. When she died Abel laid them on her stone in the Kindlers' Yard. I want them back on this anvil, and I can't fetch them. I'd sit down by her and not get up.", "choices": [
			{"text": "I'll fetch them.", "to": "ask_yes", "do": "qs:edda_tongs,att:hild:1"},
			{"text": "Fetch your own dead.", "to": "ask_no", "do": "att:hild:-1"},
		]},
		"ask_yes": {"say": "West past the sexton's dig, through the gate, to the far end of the Yard. Hers is the stone with the candles. Don't let Abel talk you out of it.", "next": "hub"},
		"ask_no": {"say": "Fair. Everybody's got their own to carry.", "next": "hub"},
		"tongs_where": {"say_if": [
			["qat:edda_tongs:2", "Lay them on the stone. Don't say anything to her. She never liked speeches."],
			["", "The Kindlers' Yard. West, past Abel's dig, through the gate. Her stone has candles on it. Abel keeps them lit; he'd tell you he doesn't."],
		], "next": "hub"},
		"tongs_back": {"say": "You've got them. Let me hold them. ...The cloth's Abel's. He wrapped the handles so they wouldn't rust in the wet.", "next": "tongs_choice"},
		"tongs_choice": {"say": "I could work with these. Make you something for that staff: a ferrule, Edda's iron on the end of it. Or they go back on her stone, where Abel says they belong. You fetched them. You say.", "choices": [
			{"text": "Forge with them. Edda would.", "to": "forge_yes", "do": "qp:edda_tongs:forge,qc:edda_tongs,grant:charm_ferrule:relic_fragment:2,att:hild:2,att:abel:-1"},
			{"text": "Put them back on her stone.", "to": "stone_yes", "do": "qp:edda_tongs:stone,qa:edda_tongs,att:hild:1"},
		]},
		"forge_yes": {"say": "Then she's working again. ...Here. Shoe your staff with it. Every time it strikes stone, that's her, saying no.", "next": "hub"},
		"stone_yes": {"say": "...Yes. You're right, and I hate it. Take them back to her and lay them on the stone. I'll go and look at them, sometimes.", "next": ""},
		"forge_later": {"say": "Not on this fire. The green's banked so low I'd be beating cold iron. Feed the Hearthfire on the green, at the brazier there. When it draws on its own, I'll have heat to spare for you.", "next": "hub"},
		"make": {"say_if": [
			["v:harrow_roof", "A latch for the Harrows' door. Wenna wants one she can bar from the inside."],
			["v:harrow_frame", "Nails for the Harrows' rafters. Col's doing the roof. Badly."],
			["v:wrights_home", "Pot hooks for the Wrights. Theirs went up the Stair with old Wright's faith."],
			["", "Nails. Nobody needs them. I make them anyway. A forge that stops is a door left open."],
		], "next": "hub"},
		"edda": {"say": "She'd tell you she was no saint. A smith who wouldn't look up. When the bells stopped she lifted the coals in her tongs till the jaws burned black, then carried the rest to the chapel in her apron. Burned her hands to the bone.", "next": "edda2"},
		"edda2": {"say": "The penitents scraped her face off the chapel wall. The shrine on the green kept one. Go and look, if you want to see where I get my chin.", "next": "hub"},
		"village": {"say_if": [
			["secrets:3", "You've been in the places the Order shut up. You smell of old incense and older stone. Wash before you sit near my coals."],
			["v:pell", "Pell came back down. Sits by the fire and doesn't blink. Maud brings her soup. Nobody asks where she's been."],
			["v:wenna", "The Ashby girl came up out of the crypt with one candle. She doesn't talk about the counting."],
			["v:reed_home", "Bet Reed's back in her house. Talks to the beans. Talks to Tobin, under them."],
			["v:wrights_home", "The Wrights went home. First smoke from that chimney since the Night. Fennick cried. Don't tell him I said."],
			["", "Quiet. Maud's candle, the Keg, me. Fennick lights lamps for people who aren't there."],
		], "next": "hub"},
	}},
	"fennick": {"name": "Old Fennick", "start": [["!met:fennick", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Mind the pole. Every lamp in Hearthward, lit by this hand, every night since the Night. Not one has stayed lit till morning.", "next": "meet2"},
		"meet2": {"say": "There's no morning. I know. I light them anyway.", "do": "met:fennick", "next": "hub"},
		"hub": {"say_if": [
			["boss:ascended_warden", "The flames stand straight now. Before, they all leaned north, toward the summit, like they wanted to go up. Now they just burn."],
			["qp:forty_first:faith", "Oswin's at the head of the rim road, kneeling by the old waystone. I light a lamp for him on my way past. He thanks the lamp."],
			["qp:forty_first:truth", "Oswin passed me on the west road with no staff, going the wrong way, smiling. First pilgrim I ever saw go home."],
			["v:lamps_all", "Every lamp I own is lit. I walk the round twice for the pleasure of it."],
			["v:lamps_more", "Longer round tonight. Oil came from somewhere. I didn't ask the ash-wife where."],
			["kindled:4", "Your braziers: all four, from the road. I count them on my round and lose count on purpose."],
			["kindled:3", "Your braziers: three from the road. I count them on my round."],
			["kindled:2", "Your braziers: I can see two from the road. I count them on my round."],
			["", "Lamps don't keep the dark out. They tell it where we are, and that we're not afraid. That's the theory."],
		], "choices": [
			{"text": "Why light them at all?", "to": "why", "once": true},
			{"text": "Can I help?", "to": "help"},
			{"text": "Goodbye.", "to": ""},
		]},
		"why": {"say": "The Order said lanterns were for doubters. The night the sky turned, every lamp on the road leaned toward the summit and went out. Mine didn't. I was asleep under the Keg's bench, drunk.", "next": "why2"},
		"why2": {"say": "Doubt's a fine fuel. Burns low and long.", "next": "hub"},
		"help": {"say_if": [
			["v:oil2|v:lamps_all", "You've done it already. Every lamp I've got is burning."],
			["", "Oil. Grisel the ash-wife trades grave ash for it. More oil, a longer round. More lamps lit, fewer things knocking."],
		], "next": "hub"},
	}},
	"oswin": {"name": "Oswin", "start": [["!met:oswin", "meet"], ["qat:forty_first:1", "stone"], ["qat:forty_first:0", "walking"], ["", "hub"]], "nodes": {
		"meet": {"say": "Is the Stair open? They told me at the West Gate it was closed. I've walked nine years. It can't be closed.", "next": "meet2"},
		"meet2": {"say": "I'll rest here. Just till the bells start again.", "do": "met:oswin", "next": "hub"},
		"hub": {"say_if": [
			["qp:forty_first:faith,boss:ascended_warden", "There was a bell. One. They said it was the door shutting. I think it was my turn, and I wasn't there. I'll wait for the next."],
			["qp:forty_first:faith", "Forty-one. I touch it every night. The Stair's just down the road, and the door's at the top. They'll ring for me when it's my turn."],
			["boss:ascended_warden", "There was a bell. One. From the bottom up, they're saying. I think I'll go home. Wherever that was."],
			["seal:summit", "The ward on the Crossing is broken, they say. Then the way's open. Then why am I still sitting here?"],
			["bosses:1", "You've been up there. Is anyone at the top? Are they waiting for us?"],
			["", "I count the waystones in my sleep. Forty-one to the Stair. Then four thousand steps. Then the door."],
		], "choices": [
			{"text": "You count the waystones?", "to": "count", "if": "!q:forty_first"},
			{"text": "The Stair is gone.", "to": "gone", "once": true, "if": "!q:forty_first"},
			{"text": "Where are you from?", "to": "from", "once": true},
			{"text": "Rest well.", "to": ""},
		]},
		"count": {"say": "Forty-one waystones from the West Gate to the Stair road. I've touched forty. The last stands at the head of the rim road, where it goes down to the Stair. They say it isn't safe. Nothing's safe. Would you walk me there? My eyes aren't what they were, in the dark.", "choices": [
			{"text": "I'll walk with you.", "to": "go", "do": "qs:forty_first,att:oswin:1"},
			{"text": "Not tonight.", "to": "hub"},
		]},
		"go": {"say": "Bless you. Not too fast. I'll be right behind you.", "next": ""},
		"walking": {"say_if": [
			["att:oswin:1", "I'm here. Forty paces behind, if you count like a pilgrim. Lead on."],
			["", "Lead on. I'll keep up."],
		], "choices": [
			{"text": "Stay close.", "to": ""},
			{"text": "Go back to the road's rest. Another night.", "to": "not_tonight", "do": "qx:forty_first"},
		]},
		"not_tonight": {"say": "Another night, then. The stone's waited this long. So have I.", "next": ""},
		"stone": {"say": "Forty-one. ...It's only a stone. I thought it would be warm.", "next": "stone2"},
		"stone2": {"say": "Is it up there? The Stair, the door, the light. You've seen more of this valley than I have. Tell me true.", "choices": [
			{"text": "The Stair is broken. The door drank everyone who climbed. Go home, Oswin.", "to": "truth", "do": "qp:forty_first:truth,att:oswin:1,qc:forty_first"},
			{"text": "It's up there. Wait here. They'll ring for you.", "to": "faith", "do": "qp:forty_first:faith,qc:forty_first"},
		]},
		"truth": {"say": "...Nine years. I knew. I think I knew at the West Gate. Thank you for saying it out loud. Take this: a chip off the first stone. I won't need to count any more.", "next": ""},
		"faith": {"say": "Then I'll wait. A pilgrim's good at waiting. A chip off the first stone, for your trouble. I'll keep the forty-first.", "next": ""},
		"gone": {"say_if": [
			["boss:ascended_warden", "I know. I've known for years, I think."],
			["", "Gone? Blessed things don't go. They go up."],
		], "next": "hub"},
		"from": {"say": "Westward, past the gate with the edict on it. My wife went ahead the year before the Night. She said she'd keep a place for me. I set out after. I walk slow.", "next": "hub"},
	}},
	"nan": {"name": "Nan Wright", "start": [["!met:nan", "meet"], ["qat:keg_thief:2", "thief"], ["", "hub"]], "nodes": {
		"meet": {"say": "You're not allowed to knock. That's the rule. If you knock three times we don't open.", "next": "meet_face"},
			"meet_face": {"say": "You haven't got a face under there. That's all right. Pell's hands went cold before she went. I didn't mind them.", "next": "meet2"},
		"meet2": {"say": "I chalk the doorsteps. Circles. Things can't step over a circle. Probably.", "do": "met:nan", "next": "hub"},
		"hub": {"say_if": [
			["qp:keg_thief:told,qd:keg_thief", "The keep puts a mug out by the fire himself now. He says it's for the rats. He winks when he says it, which is worse."],
			["qp:keg_thief:covered,qd:keg_thief", "I still put the mug out. You squared it. I drew you a circle on the Keg's step; you're inside it now."],
			["qp:keg_thief:rats,qd:keg_thief", "Rats! He set a trap behind the Keg. It caught Fennick's boot."],
			["!att:nan:-1", "I'm not talking to you. You tell."],
			["v:pell", "Pell's back. She won't play. Her hands are cold even by the fire. I lent her my shawl."],
			["v:wrights_home", "We live at home again. Da chops wood all night. Mam says it's so the chimney never stops."],
			["", "We sleep at the Keg, in the back. The keep says the back's safest. The dark only knows the front."],
		], "choices": [
			{"text": "Who taught you the circles?", "to": "circles", "once": true},
			{"text": "Where's Pell?", "to": "pell", "if": "!v:pell"},
				{"text": "Pell turned back. She wrote 'gone home'.", "to": "pell_home", "if": "secret:found:pell,!v:pell", "once": true},
			{"text": "The chalk circles by the fire. Yours?", "to": "thief", "if": "qat:keg_thief:2"},
			{"text": "Go home, Nan.", "to": ""},
		]},
		"circles": {"say": "Nobody. I just know. Mam says it's nonsense and then she steps round them.", "next": "hub"},
		"pell": {"say": "She went north. Toward the light. I saw. She said it was warm up there. It isn't warm anywhere.", "next": "hub"},
			"pell_home": {"say": "Gone home? ...Then why isn't she here? This is home. I've been putting the mug out the whole time.", "next": "hub"},
		"thief": {"say": "...You've been following my circles. I knew you were. You walk like a grown-up.", "next": "thief2"},
		"thief2": {"say": "It's for Pell. When she comes back down she'll be cold, and the fire's not enough, so I bring a mug and put a circle round it so nothing else drinks it. The keep counts his barrels. I know he does.", "choices": [
			{"text": "I'll have to tell the keep.", "to": "told", "do": "qp:keg_thief:told,qa:keg_thief,att:nan:-2"},
			{"text": "Your secret's safe. I'll square it with the keep.", "to": "covered", "do": "qp:keg_thief:covered,qa:keg_thief,att:nan:2"},
			{"text": "I'll tell him it was rats.", "to": "rats", "do": "qp:keg_thief:rats,qa:keg_thief,att:nan:1"},
		]},
		"told": {"say": "...Fine. Tell him. Grown-ups always tell. Pell's going to be cold, then.", "next": ""},
		"covered": {"say": "Promise? Cross the circle? ...All right. Here. A bit of my chalk. Draw round yourself when it knocks.", "do": "grant:charm_chalk:relic_fragment:1", "next": ""},
		"rats": {"say": "Rats don't drink ale. ...He'll believe it, though. He believes in rats.", "next": ""},
	}},
	"col": {"name": "Col Wright", "start": [["", "hub"]], "nodes": {
		"hub": {"say_if": [
			["boss:ascended_warden", "Burning less wood tonight. Don't need as much. Still chopping it."],
			["qp:edda_tongs:forge,qd:edda_tongs", "Hild's got her grandmother's tongs going. You can hear the difference from here. Don't ask me what it is."],
			["att:col:2", "You again. Good. Grab the other end of this, would you? No? Worth asking."],
			["", "Every log on the fire's one more hour the door stays shut. That's the sum of it."],
		], "choices": [
			{"text": "Good to see you home.", "to": "home", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"home": {"say": "Nine years under the Keg's stair with the barrels. Nan thought the house was full of them. The hollows. It was only dust. Mostly.", "do": "met:col", "next": "hub"},
	}},
	"bet": {"name": "Bet Reed", "start": [["", "hub"]], "nodes": {
		"hub": {"say_if": [
			["boss:ascended_warden", "I told Tobin the stars weren't worth it. Now I'd give a lot to see one."],
			["v:reed_roof", "Somebody paid for slates. The rain only comes in at the back now. Like a gentleman."],
			["qd:names_yard", "Abel carved three names in the Yard. I went to see if one was Tobin's. It wasn't. I came home and wrote his on the bean-pole."],
			["", "Tobin let the fire go out to see the stars. He saw them. I buried him under the beans."],
		], "choices": [
			{"text": "Why did you come back?", "to": "why", "once": true},
			{"text": "Is the garden giving anything?", "to": "", "do": "shop:bet", "if": "v:svc_herbs"},
			{"text": "What grows here?", "to": "garden_later", "if": "!v:svc_herbs"},
			{"text": "Goodbye.", "to": ""},
		]},
		"garden_later": {"say": "Nothing, in this cold. Beans want warmth from below. Get the green's fire roaring and I'll have honey and rue for you. Bitter ones. The good ones.", "next": "hub"},
		"why": {"say": "I sheltered with the lay brothers at the Barrow lodge. They count, all night, under their breath. I'd sooner dig a dead man's garden than listen to that.", "do": "met:bet", "next": "hub"},
	}},
	"wenna": {"name": "Wenna Ashby", "start": [["!met:wenna", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "You're the one who went down. After me. I heard you in the dark while he was counting.", "next": "meet2"},
		"meet2": {"say": "Mother was there. She said my name the way she used to, and then she said a number. I kept the candle lit. That's all I did.", "do": "met:wenna", "next": "hub"},
		"hub": {"say_if": [
			["boss:ascended_warden", "I wrote one more page. You needn't find it. It says: the door is shut, Mother. Come down."],
			["qp:slow_way:truth", "Ostrin let me trim his father's lantern on the Keg's counter. That's the most he's said to me. I think it was a lot, for him."],
			["v:harrow_roof", "The Harrows' house has a roof. I sleep there. I leave the candle in the window, like Maud."],
			["", "One candle. I've trimmed it a hundred times. I'm afraid of what happens when it's gone."],
		], "choices": [
			{"text": "Your journal...", "to": "journal", "once": true},
			{"text": "Rest, Wenna.", "to": ""},
		]},
		"journal": {"say": "You found the pages? Keep them. I don't want to read what I was.", "next": "hub"},
	}},
	"pell": {"name": "Pell", "start": [["", "hub"]], "nodes": {
		"hub": {"say": "(She does not answer. Her hands are held to the fire. One foot is bare. The other shoe has new stitches.)", "next": "hub2"},
		"hub2": {"say_if": [
			["met:pell", "(She does not look up.)"],
			["", "(Very quietly, to the fire:) It isn't warm up there.", "met:pell"],
		], "next": ""},
	}},
	"wyck": {"name": "Wyck", "start": [["!met:wyck", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Don't step on that. Bird. I bury them face down, so they don't fly up. The Rooted did that, before the abbey taught otherwise.", "next": "meet2"},
		"meet2": {"say": "What climbs comes down hollow. I've never climbed anything. Look at me. Still full.", "do": "met:wyck", "next": "hub"},
		"hub": {"say_if": [
			["boss:ascended_warden", "The sky's let go. The birds came down to the fire last night and just sat. I didn't bury any. First night."],
			["secret:open:oak", "You found the hollow oak. The Rooted kept their dead in there standing up. Did you knock first? You should knock."],
			["boss:thornwarden", "The thorn's stopped beating. The oaks are quieter. Like a dog that's lost its master. Careful of them a while."],
			["seal:henge", "You broke the seal on the Ring. The Thornwarden felt it. So did I, in my teeth."],
			["", "The Thornwarden keeps the wood. Not for us, not against us. Leave the oaks standing and it'll mostly let you be."],
		], "choices": [
			{"text": "Tell me about the Thornwarden.", "to": "warden", "once": true},
			{"text": "Why live out here?", "to": "why", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"warden": {"say": "The Rooted asked a thorn to stand where the axe would come. It asked for a heart to root in. Nobody sings the next verse. The abbey chiselled it off.", "next": "hub"},
		"why": {"say": "The village keeps fires. Fires draw the hollowed like moths. I keep a small one. Small fires don't interest anything.", "next": "hub"},
	}},
	"abel": {"name": "Abel", "start": [["!met:abel", "meet"], ["qat:names_yard:1", "names"], ["", "hub"]], "nodes": {
		"meet": {"say": "Another grave? Not yours. Not yet. I dig one every night. Somebody always needs it by morning.", "next": "meet2"},
		"meet2": {"say": "Edda's stone is mine to keep. I trim her candles. She'd have hated that.", "do": "met:abel", "next": "hub"},
		"hub": {"say_if": [
			["qp:edda_tongs:stone,qd:edda_tongs,!v:abel_tongs", "You brought her tongs back. I sat with her an hour after. Don't tell Hild I cried; she'll want to know what about.", "v:abel_tongs"],
			["qp:edda_tongs:forge,qd:edda_tongs,!att:abel:0", "Her tongs are on Hild's anvil now, I hear. Well. Edda never could leave iron alone. Neither can that girl."],
			["boss:ascended_warden", "Nobody came down last night. First night in years I dug and nobody needed it. I'll fill it in tomorrow. Maybe."],
			["qd:names_yard", "Maren, Tam, Ide. I say them over when I dig. The Order would have me count. I'd sooner call the roll."],
			["secret:open:barrow", "You opened a barrow. I can tell; the field smells different. Put the lids back on the ones you didn't need."],
			["hollows:10", "You've come back from the fire {hollows} times. I've stopped digging for you. It seemed rude."],
			["hollows:3", "Back again. {hollows} times now. You come back the way they do. Only you come back warm."],
			["boss:bone_abbot", "The Abbot's down. The dead he kept will need somewhere to lie. I'll be digging a while."],
			["", "The Order wanted the dead stacked and counted. I lay them flat and leave them be. That's the difference."],
		], "choices": [
			{"text": "Whose grave is that?", "to": "whose"},
			{"text": "Is there anything I can do?", "to": "ask", "if": "!q:names_yard"},
			{"text": "About the name-slates...", "to": "slates", "if": "qat:names_yard:0"},
			{"text": "Goodbye.", "to": ""},
		]},
		"ask": {"say": "Digging, no. Names, yes. The Order took the names off the dead and gave them numbers. A few of the faithful scratched the names back on slates and hid them where the brothers wouldn't look: the Glimmer Glade, the chapel lane, the Barrow Field. Bring me the names. I'll cut them proper.", "choices": [
			{"text": "I'll find them.", "to": "ask_yes", "do": "qs:names_yard,att:abel:1"},
			{"text": "The dead don't care what they're called.", "to": "ask_no", "do": "att:abel:-1"},
		]},
		"ask_yes": {"say": "Read them out loud when you find them. That's half the work.", "next": "hub"},
		"ask_no": {"say": "No. But I do, and I'm the one with the spade.", "next": "hub"},
		"slates": {"say": "The glade, by the shrine. The chapel lane, west along the road. Out in the Barrow Field, past the east way. A slate in each, unless the hollowed have been sitting on them.", "next": "hub"},
		"names": {"say": "You read them? Say them, then. ...Maren Coyle, who sang the low part. Tam, the carter's boy. Sister Ide, who kept the bees.", "next": "names2"},
		"names2": {"say": "I'll cut them on the wall by Edda's stone tonight, deep enough to outlast me. Here: ash, for your trouble, and a bit of something from a coffin that wasn't empty enough.", "choices": [
			{"text": "I read them out loud where I found them, like you said.", "to": "confess", "do": "att:abel:1,qp:names_yard:confess,qc:names_yard"},
			{"text": "Cut them deep.", "to": "deep", "do": "qp:names_yard:deep,qc:names_yard"},
		]},
		"confess": {"say": "Out loud. Good. Then they've been called once already, and the cutting's only the second time. You did them a kindness. Not many get one.", "next": "hub"},
		"deep": {"say": "As deep as the stone goes.", "next": "hub"},
		"whose": {"say_if": [
			["v:pell", "Nobody's. I dug it for Pell the night she walked north. Then she came back. I'm leaving it open in case she changes her mind."],
			["", "Whoever comes down next. They do come down, sometimes. They knock. You don't open."],
		], "next": "hub"},
	}},
	"grisel": {"name": "Grisel", "start": [["!met:grisel", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Grave ash. Bring it here. Ash to ember, ember to flame: the last warm thing a body gives up shouldn't be wasted.", "next": "meet2"},
		"meet2": {"say": "Oil for the lamps, rope for the well, slates, thatch. Whatever the village needs to stay lit. You pay in what you took off the hollowed.", "do": "met:grisel", "next": "hub"},
		"hub": {"say_if": [
			["att:grisel:3", "My best customer. Don't let it go to your head; it's all going to mine. ({ash} ash in your satchel.)"],
			["qd:names_yard", "Abel's carving names now. Waste of good stone, I told him. Then I went and read them. ({ash} ash in your satchel.)"],
			["", "Ash, then. Let's see it. ({ash} in your satchel.)"],
		], "choices": [
			{"text": "Show me your wares.", "to": "", "do": "shop:grisel"},
			{"text": "What does the village need?", "to": "needs"},
			{"text": "Where does the ash go?", "to": "ash", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"needs": {"say_if": [
			["!v:oil,!v:lamps_more", "Oil, first. Fennick's round is three lamps short and he'd sooner die than say so."],
			["!v:well", "Rope for the well. Water's water, even when it tastes of nothing."],
			["v:reed_home,!v:reed_roof", "Slates for Bet Reed. Her roof's a sieve, and she's too proud to say so."],
			["!v:oil2,!v:lamps_all,v:oil|!v:oil2,!v:lamps_all,v:lamps_more", "More oil. Every lamp, not just the near ones. Light's cheap. Dark's dear."],
			["v:harrow_frame,!v:harrow_roof", "Thatch for the Harrows. Rafters with no roof is just a cage."],
			["", "Nothing I can sell you. What it needs now is time, and I can't sell you that."],
		], "next": "hub"},
		"ash": {"say": "Into the lamps, the forge, the mortar. Ash holds heat. Ash holds a wall up. Ash is what's left when the fire's done with you, and it's still good for something. Like me.", "next": "hub"},
		"poor": {"say": "That's not enough ash. Come back with more. They're not hard to find.", "next": "hub"},
		"none": {"say": "Nothing left the village needs from you tonight. Keep your ash. Spend it at the fires.", "next": ""},
	}},
}

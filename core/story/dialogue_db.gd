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

const KEEP_PORTRAIT := {"seated": false, "seed": 5150, "apron": true, "hat": "bare", "rag": true}

const CONV := {
	"keep": {
		"name": "The Keep",
		"portrait": KEEP_PORTRAIT,
		"start": [["boss:ascended_warden,!flag:ending_told", "end_1"], ["flag:deeper,!flag:deeper_met", "ng_1"], ["!flag:met_keep", "meet_1"], ["qat:keg_thief:3", "thief_report"], ["", "hub"]],
		"nodes": {
			# --- first meeting --------------------------------------------------------------
			"meet_1": {"say": "Shut the door. No, leave it. The fire's done arguing with the dark tonight.", "next": "meet_2"},
			"meet_2": {"say": "You walked in off the road with a lit lantern. That makes you kindled, or mad. Either way, you drink.", "next": "meet_hub"},
			"meet_hub": {"say": "Ask, then. Questions are free. Beds cost ash.", "choices": [
				{"text": "What happened to this valley?", "to": "lore_1", "once": true},
				{"text": "Who holds it?", "to": "three_1", "once": true},
				{"text": "Where do I start?", "to": "start_1"},
				{"text": "I'll find my own way.", "to": "meet_end"},
			]},
			"lore_1": {"say": "Somebody opened the sky at the top of the Stair. It opened inward. It's been drinking ever since: the light first, then the warm, then the people.", "next": "lore_2"},
			"lore_2": {"say": "Edda put coals from her forge on a bare altar and the dark stopped at the door. Every fire since is hers. Yours too, now.", "next": "meet_hub"},
			"three_1": {"say": "Three. Something in the Ring on the western hill that keeps the oaks; the Rooted call it the Thornwarden. The Abbot under the abbey, still counting his dead.", "next": "three_2"},
			"three_2": {"say": "And whatever stands at the top of the Stair with the door open. The ward on the Crossing won't let you near it till the other two are down: a heart out of the Ring, a crown out of the crypt.", "next": "meet_hub"},
			"start_1": {"say": "The braziers. Four of them: the Stair's foot, the shrine in the glade, the Barrow Field, the fen under the Ossuary. Light them and you've somewhere to stand when the dark leans on you.", "next": "start_2"},
			"start_2": {"say": "Then pick a door. The thorn seal on the Thornwood edge, west. Or the gallery seal down in the crypt, through the fen door. Both, before you're done.", "do": "flag:met_keep,teach:ward", "choices": [
				{"text": "Another question.", "to": "meet_hub"},
				{"text": "I'll go.", "to": "meet_end"},
			]},
			"meet_end": {"say": "Fire stays. Hollows do not. Come back with news; we pay in ale.", "do": "flag:met_keep,teach:ward", "next": ""},
			# --- the hub, every visit after ---------------------------------------------------
			"hub": {"say_if": [
				["flag:ending_told", "The kindled one. Your stool, your mug. The fire draws by itself now; I've nothing to do but pour."],
				["boss:thornwarden,boss:bone_abbot", "Heart and crown, both. I can smell the henge on you, and the crypt. The ward will know them."],
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
				{"text": "You look troubled, keep.", "to": "thief_ask", "if": "!q:keg_thief"},
				{"text": "About your ale thief...", "to": "thief_where", "if": "qat:keg_thief:0|qat:keg_thief:1|qat:keg_thief:2"},
				{"text": "Any news?", "to": "news"},
				{"text": "Tell me again about the three.", "to": "three_again"},
				{"text": "Who are you, keep?", "to": "who_1", "once": true},
				{"text": "Goodbye.", "to": "bye"},
			]},
			"next": {"say_if": [
				["boss:ascended_warden", "Now? Now nothing. Sit. Let the valley learn not to be pulled at. It'll take a while; it's been a while."],
				["boss:thornwarden,boss:bone_abbot,!seal:summit", "Across the Crossing. There's a ward at the landing with guards that don't sleep. Clear them and it'll let heart and crown through. It was cut to let nobody else."],
				["boss:thornwarden,boss:bone_abbot", "Up. Whatever's at the top is halfway into the sky and stuck there. Make it let go of the door."],
				["boss:thornwarden", "The crown, then. Down from the Barrow Field, through the fen door, into the gallery. Mind the bones that stand up."],
				["boss:bone_abbot", "The heart, then. West road, past the glade, up the hill to the Ring. The thorn seal first."],
				["seal:henge", "Into the Ring. Cut out the heart. Don't let it sing to you."],
				["seal:oss_gallery", "Down to the charnel floor. The Abbot's on his mound. When he falls, something rises; bring it out."],
				["", "The thorn seal on the Thornwood edge, or the gallery under the abbey. The braziers first, if you've sense."],
			], "next": "hub"},
			"news": {"say_if": [
				["kindled:4", "All four braziers burning. First time since the Door. I can see the Stair-foot glow from the step."],
				["kindled:3", "Three of four. One more and I'll stop counting them out loud."],
				["kindled:2", "Two of four. Folk have started looking up from their mugs. Not far up. Up."],
				["kindled:1", "{kindled} of four burning. I can see one from the door, if I squint. Keep going."],
				["", "Not one of the four lit. The dark's patient. Not that patient."],
			], "next": "news_2"},
			"news_2": {"say_if": [
				["boss:ascended_warden", "Maud's candle went out last night. She put it out herself. Said he wasn't coming, and she was tired."],
				["secret:found:cairn,!boss:ascended_warden", "You found his stones up on the Crowns. Don't tell her. She'd go up there."],
				["elite:hobb", "The knocking's stopped on the east road. Maud still sits up for it. Habit's the last thing to go."],
				["qp:forty_first:faith", "Oswin kneels at the forty-first stone every night. Fennick lights him a lamp. Nobody's told him. Nobody's going to."],
				["secrets:3", "Folk say you've been opening the places the Order sealed. The Order sealed them for a reason. Usually a bad one."],
				["qp:forty_first:truth", "Oswin went home. Walked out the west road without his staff. First pilgrim I ever saw go the other way."],
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
				["qat:keg_thief:2", "Chalk circles, you say? Nan. It's always Nan. Go and ask her, gently. She bites."],
				["qat:keg_thief:1", "Circles in chalk? Follow them, then. I'm not getting down on my knees at my age."],
				["", "Behind the Keg. By the chimney. Look down; thieves never look down."],
			], "next": "hub"},
			"thief_report": {"say": "Well? Who's drinking my ale?", "choices": [
				{"text": "It's Nan. She leaves a mug by the green's fire, for Pell, for when she comes back.", "to": "rep_told", "if": "qp:keg_thief:told", "do": "qc:keg_thief,att:keep:2,give:grave_ash:8"},
				{"text": "It was me. Put it on my slate. (10 ash)", "to": "rep_covered", "if": "qp:keg_thief:covered", "do": "pay:10,qc:keg_thief,att:keep:1,att:nan:1"},
				{"text": "Rats.", "to": "rep_rats", "if": "qp:keg_thief:rats", "do": "qc:keg_thief,att:keep:-1"},
				{"text": "...It's Nan. She does it for Pell.", "to": "rep_told", "if": "!qp:keg_thief:told", "do": "qp:keg_thief:told,qc:keg_thief,att:keep:2,att:nan:-3,give:grave_ash:8"},
			]},
			"rep_told": {"say": "Nan. ...For Pell. Well. I'm not taking a mug off a child for that. I'll put one out myself, from now on. Here, for your trouble. Don't tell her I went soft.", "next": "hub"},
			"rep_covered": {"say": "You. A mug a night, quiet, by the back door. ...Right. Ten ash, and I'm watching you.", "next": "hub"},
			"rep_rats": {"say": "Rats. That drink ale, and draw circles. ...I'll set a trap, then. A big one.", "next": "hub"},
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
			"ng_1": {"say": "You rang it. ...I heard it. Wrong way up, top first, the way they stopped.", "do": "flag:deeper_met,flag:met_keep", "next": "ng_2"},
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
			], "next": "end_5"},
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
		"start": [["qat:slow_way:3", "lantern"], ["boss:bone_abbot,!flag:harrow_after", "after"], ["flag:met_harrow", "hub"], ["", "meet"]],
		"nodes": {
			"meet": {"say": "Harrow. The house with the door off its hinges is ours. Was.", "do": "flag:met_harrow", "next": "meet_2"},
			"meet_2": {"say": "Mother went up with the bells. Father went after her the slow way, down the fen.", "next": "hub"},
			"hub": {"say_if": [
				["qp:slow_way:truth", "The lantern's lit. I trim it every hour. The keep says I'm wasting oil. The keep can shut up."],
				["qp:slow_way:mercy", "Still cold, the lantern. He'll want it when he comes up. He'll come up."],
				["flag:deeper,!boss:bone_abbot", "They're counting again down there. I can hear it through the floor. Don't tell me it's the ale."],
				["secret:open:crypt", "You went in the drowned crypt. Father used to say the fen keeps what it takes, and keeps it wet. Drinking, or asking?"],
				["", "Drinking, or asking?"],
			], "choices": [
				{"text": "The fen?", "to": "fen"},
				{"text": "Your father went down the fen?", "to": "father", "if": "!q:slow_way"},
				{"text": "About your father...", "to": "father_where", "if": "q:slow_way,!qd:slow_way"},
				{"text": "How do I reach the Ossuary?", "to": "oss"},
				{"text": "Neither.", "to": ""},
			]},
			"father": {"say": "After Mother went up with the bells he took the lantern and went down. Said if the light was up there, whatever was left was down there, and somebody ought to keep it company.", "next": "father2"},
			"father2": {"say": "Six winters gone. Out on the fen, by the fen brazier under the Ossuary's fen door. If you go that way... bring me the lantern. Whatever's holding it.", "choices": [
				{"text": "I'll find him.", "to": "father_yes", "do": "qs:slow_way,att:harrow:1"},
				{"text": "Some things stay lost.", "to": "father_no"},
			]},
			"father_yes": {"say": "Don't tell me what you find till you've found it. I'll be here. I'm always here.", "next": "hub"},
			"father_no": {"say": "That's what the keep says. Then he pours me another.", "next": "hub"},
			"father_where": {"say_if": [
				["qat:slow_way:2", "You've done it, then. I can see it on you. Bring me the lantern. Just the lantern."],
				["qat:slow_way:1", "Something's standing over it. I heard it in your voice. Do what you have to."],
				["", "Out on the fen, past the fen brazier under the Ossuary's door. A tin lantern with our name scratched on the base."],
			], "next": "hub"},
			"lantern": {"say": "That's it. That's his. ...Was it him? Tell me.", "choices": [
				{"text": "It was him. Hollow. I put him to rest.", "to": "truth", "do": "qp:slow_way:truth,qc:slow_way,att:harrow:2"},
				{"text": "Just the lantern, in the reeds. No sign of him.", "to": "mercy", "do": "qp:slow_way:mercy,qc:slow_way"},
			]},
			"truth": {"say": "...Good. Good. He'd have hated standing. Light it. Put it on the counter where I can see it. He kept it lit for Mother; I'll keep it lit for him.", "next": ""},
			"mercy": {"say": "No sign. ...Then he's still walking, somewhere down there. That's something. I'll keep it on the counter, cold, till he comes for it.", "next": ""},
			"fen": {"say": "Osric's brothers sank the hollowed there under three stones. Eyes, mouth, heart. When the crypt filled they ran short of stones. Some came back.", "next": "hub"},
			"oss": {"say_if": [
				["boss:bone_abbot", "Nobody's counting down there now. You saw to that. I don't go. Neither should you."],
				["seal:oss_gallery", "You've been. Then you've seen him counting. Finish it."],
				["", "Barrow Field, then down the fen. There's a door on the fen side now, a stair up into the gallery. The gallery's sealed; the dead in it want counting."],
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
				["att:brannoc:2", "Sit down, sit down. You stood the room a round; that buys you my good ear. Which one's that. This one."],
				["", "You want something, or just the company of a man who can't hear well?"],
			], "choices": [
				{"text": "How do I reach the summit?", "to": "reach"},
				{"text": "What happens if it falls?", "to": "falls"},
				{"text": "Who's up there?", "to": "who", "if": "bosses:1", "once": true},
				{"text": "The company.", "to": ""},
			]},
			"reach": {"say_if": [
				["boss:ascended_warden", "Reach it? There's nothing up there now but his bell, and it's rung. I'd know its voice anywhere. Sit down."],
				["", "Across the Crossing, what's left of the Stair. A ward at the landing wants proof you've beaten the other two. Heart and crown. Then the dais, under the sky."],
			], "next": "hub"},
			"who": {"say": "I cast the Hierarch's bell. Aurel's. If that's him up there, still holding the door, I cast it for nothing.", "next": "hub"},
			"falls": {"say_if": [
				["boss:ascended_warden", "He did. One bell, the right way up. I'd cast another just to hear it twice."],
				["", "The door shuts. Maybe a bell rings. I'd like to hear one ring again, the right way up."],
			], "next": "hub"},
			"after": {"say": "I heard it. One bell. From the bottom, the right way up. You did that.", "do": "flag:brannoc_after", "next": "hub"},
		},
	},
}

## Narration beats (non-blocking subtitles).
const OPENING := [
	"The road ends here. Past the last village there is only the Stair, and the sky it opened.",
	"Over the Crowns the sky turns inward. The cold comes down the mountain to meet you.",
	"There is light in the Kindled Keg.",
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

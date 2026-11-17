extends Node
## Aurel's voice through the night. The Hierarch is the one the whole story is about, and until now he said nothing
## until the last bar. He speaks now, to the last of the pilgrims, from the sky: a subtitle line under the world and one low
## stroke of the bell an octave down (bell_voice.gd), each line once per cycle (a flag, `aurel_<id>`, saved with the story,
## filed per Deeper Night). He is courteous, patient, and wrong the way a kind man is wrong. Lines wait for a quiet moment
## (no conversation, no boss fight, MIN_GAP seconds since the last) and never talk over each other.
##
## What brings a line (TRIGGERS, below): the first fire, all four, each of the five bosses falling, the first bell answered,
## the Rift and the summit entered, the first time the wanderer is hollowed, the Reaches' threads closed, the road's lamps
## lit, the edicts restored or scratched out (the choice the third edict's scribe leaves, quest `aurel_edicts`), the Deeper
## Night. `fight(boss, key)` is the same voice inside the Warden's arena, as boss emotes (ascended_warden.gd, warden_peal.gd).
## Added by the story director. No class_name.

const BellVoice := preload("res://core/story/bell_voice.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
const QuestDB := preload("res://core/story/quest_db.gd")
const Story := preload("res://core/story/story.gd")

const MIN_GAP := 75.0              ## seconds between two lines on the open ground
const GOLD := Color(1.0, 0.9, 0.62)

## id -> the line (a subtitle: spoken, so quoted). Written to the house style: terse, concrete, dark.
const LINES := {
	"fire_1": "A fire below the Stair. I left word there should be none. ...Keep it. It will be something to walk back to.",
	"fire_4": "Four fires, and the dark leaning on every one. I did not mean it to lean. I meant it to open.",
	"idle": "Do you hear it turning? It is not a storm. It is a breath held for nine winters, and I am the one holding it.",
	"hollowed": "You came back from that. They never do. ...Unless you were never wholly in it. Come up, and let me see your face.",
	"boss_thornwarden": "The root is cut. It held the valley down a thousand years; I held the sky up nine. Neither of us was thanked.",
	"boss_bone_abbot": "Osric counted them for me. A faithful man. Eleven thousand, and each one meant to come through. Now nobody is counting.",
	"boss_r37_hierarch": "That was my voice in the horn. A boy held the note for me, nine winters. I never asked him to. ...I never asked.",
	"boss_r37_anchoress": "She prayed the sky still. It did not still. Do not think the prayer failed. The door failed. I built it.",
	"bell": "A bell, rung the right way up. Her mother's order. She always did know the order of things.",
	"bells_3": "Three of them now, and I am lighter. I do not know what it is I am letting go of. Is it the door?",
	"rift": "You are on the Stair. Four thousand steps and the last of them gone. Come up the way you came. I will not call it again.",
	"summit": "Nearer. Say nothing; the door listens better to silence. I have had nine winters to learn it.",
	"reaches": "Come east and be counted. I wrote that. Did anyone? I think it was a clerk, who was afraid of me, and wrote it kindly.",
	"lamps": "Lamps on the road again. I forbade them. I stood on the Stair and forbade them, and the dark was grateful.",
	"edict_follow": "'Until the last of you is through, and then I follow.' You cut it back in. I had forgotten I said it. Thank you.",
	"edict_leave": "The edict stands as it was cut. I will not complain of it. It is what I was told I said.",
	"edict_scratch": "You scratched the third edict out. Then I promised nothing, and nothing is owed on either side.",
	"deeper": "Again. The bell was rung the wrong way up. I heard it from the sky, and I knew it was you.",
}

## id -> when. Each is polled by the signal that could make it true; the first line whose turn has come is said.
const WANT := {
	"fire_1": "kindled:1", "fire_4": "kindled:4", "boss_thornwarden": "boss:thornwarden", "boss_bone_abbot": "boss:bone_abbot",
	"boss_r37_hierarch": "boss:r37_hierarch", "boss_r37_anchoress": "boss:r37_anchoress", "bell": "bells:1", "bells_3": "bells:3",
	"reaches": "qd:wr_stand_down|qd:ds_water_road|qd:er_ringers_candle", "lamps": "qd:lamp_road",
	"edict_follow": "qp:aurel_edicts:follow", "edict_leave": "qp:aurel_edicts:leave", "edict_scratch": "qp:aurel_edicts:scratch",
	"deeper": "flag:deeper",
}

var story: Story
var _since := 0.0
var _pending: Array[String] = []
var _idle_t := 0.0
var _spk: AudioStreamPlayer
var _prof: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	story = get_parent() as Story
	Events.brazier_kindled.connect(func(_b: Node3D) -> void: poll.call_deferred())
	Events.boss_slain.connect(func(_id: String) -> void: poll.call_deferred())
	Events.quest_changed.connect(func(_i: String, _s: int, _d: bool) -> void: poll.call_deferred())
	Events.region_discovered.connect(_on_region)
	Events.hollowed.connect(func() -> void: say_once("hollowed"))
	_since = MIN_GAP * 0.5


func _on_region(id: String, kind: String) -> void:
	if kind == "region" and (id == "rift" or id == "summit"):
		say_once(id)


## Say every line whose condition now holds and which has not been said.
func poll() -> void:
	if story == null or not story.flag("met_keep"):
		return
	var ws := story.world()
	for id: String in WANT:
		if not _said(id) and QuestDB.test(String(WANT[id]), ws):
			say_once(id)


func _key(id: String) -> String:
	return "aurel_" + id


func _said(id: String) -> bool:
	return story.flag(_key(id)) or _pending.has(id)


## Queue a line (once). It is spoken as soon as the world is quiet enough.
func say_once(id: String) -> void:
	if story == null or not LINES.has(id) or _said(id):
		return
	if not story.flag("met_keep"):
		return
	_pending.append(id)


func _process(delta: float) -> void:
	_since += delta
	if story == null or not is_instance_valid(story.ui):
		return
	if _pending.is_empty():
		# the sky speaks once on its own, a long quiet walk after the keep has talked
		if story.flag("met_keep") and not _said("idle"):
			_idle_t += delta
			if _idle_t > 540.0:
				say_once("idle")
		return
	if _since < MIN_GAP or story.ui.narrating() or get_tree().paused or _boss_playing():
		return
	var id: String = _pending.pop_front()
	story.set_flag(_key(id))
	_since = 0.0
	story.ui.narrate(["Aurel: \"%s\"" % String(LINES[id])])
	BellVoice.ring(self, -12.0, -12.0, 0.2)
	_babble(String(LINES[id]))


## His voice is the same babble every voice in the valley has (docs/DECISIONS.md), an old man's, pitched down under the tolled bell:
## a few syllables a clause, spaced by the line's own punctuation.
func _babble(line: String) -> void:
	if _spk == null:
		_spk = Voice.speaker2d(self)
		_prof = Voice.profile("old_man", 4041)
		_prof["pitch"] = 0.62
	var t := 0.5
	for clause: String in line.replace("...", ". ").split(". "):
		var n := clampi(clause.split(" ").size() / 3, 1, 4)
		get_tree().create_timer(t, true).timeout.connect(func() -> void: Voice.say(_spk, _prof, n, 0.4, false, -4.0))
		t += 0.55 + 0.3 * float(n)


func _boss_playing() -> bool:
	var n := get_tree().get_first_node_in_group(&"boss_themes")
	return n != null and String(n.get("playing_id")) != ""


# --- inside the Warden's arena -----------------------------------------------------------------------

## The fight lines, by the third edict's pick: what he says as he wakes, as the door turns, and as it opens.
const FIGHT := {
	"wake": "Come up. I have kept the door for you. You are late.",
	"ascend": "Rise with me. No? Then stand in the lit places; the sky is not meant to fall on the faithful.",
	"ph2": "I was told the door is a mercy. Nobody who told me came back to say.",
	"ph3_follow": "Until the last of you is through, and then I follow. You wrote it back. Then let me follow.",
	"ph3_leave": "Until the last of you is through. It is all it ever said. I held. I held.",
	"ph3_scratch": "You scratched the promise out. Then I am not bound, and I am not kind.",
	"ph3_": "Until the last of you is through. ...Are you the last? Are you the last?",
	"dead_follow": "Through. ...I follow.",
	"dead_leave": "Through. Then the door may close. Somebody should have told me it was a door.",
	"dead_scratch": "Through. It was a door. It was always only a door.",
	"dead_": "Last one through. ...Who held it for you?",
}

static func edict_pick() -> String:
	return QuestBook.pick("aurel_edicts")


## A line of Aurel's inside the arena, as a quoted boss emote. `key` is a FIGHT key; "ph3" and "dead" take the edict's pick.
static func fight(boss: Node, key: String) -> void:
	var k := key
	if key == "ph3" or key == "dead":
		k = "%s_%s" % [key, edict_pick()]
	if not FIGHT.has(k):
		k = key + "_"
	if FIGHT.has(k):
		BossKit.emote(boss, "\"%s\"" % String(FIGHT[k]), GOLD)

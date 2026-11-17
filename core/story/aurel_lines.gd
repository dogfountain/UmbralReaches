extends RefCounted
## Aurel inside the Warden's arena (the same voice as aurel_voice.gd, split out so the boss scripts need not load the story
## director): by the third edict's pick (quest `aurel_edicts`, The Third Edict) what he says as he wakes, as the door turns, as it
## opens and as he falls, shown as quoted boss emotes. No class_name. Load by path: const AurelLines := preload("res://core/story/aurel_lines.gd")

const QuestBook := preload("res://core/story/quest_book.gd")
const GOLD := Color(1.0, 0.9, 0.62)

## The fight lines: what he says as he wakes, as the door turns, and as it opens.

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

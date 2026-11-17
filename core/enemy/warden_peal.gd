extends RefCounted
## The Founder's peal as the Ascended Warden wakes. The door needs one bell; every bell answered after it is a hand off
## him: a bell lifted out and carried to the Keg costs him 5% of his life, a bell rung where it hangs 3%. When he
## wakes the wanderer hears them come in, one by one, from the bottom up: each bell the night answered rings once (the bell's
## own name, rung or carried, the stroke a step higher than the last), then Aurel's wake line. No bells and the sky is silent.
## Called by ascended_warden.gd at the wake. No class_name.
##   WardenPeal.hold_factor(carried, rung, per_carried)   the multiplier on his life
##   WardenPeal.scene(boss, carried, rung, attuned, words) the staged emotes and strokes (timers; harmless if the boss is freed)

const BellVoice := preload("res://core/story/bell_voice.gd")
const AurelLines := preload("res://core/story/aurel_lines.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const QuestBook := preload("res://core/story/quest_book.gd")

const RING_HOLD := 0.03
const GAP := 2.3                      ## seconds between two bells
const FIRST := 3.2                    ## after the wake line


static func hold_factor(carried: int, rung: int, per_carried: float) -> float:
	return clampf(1.0 - per_carried * float(carried) - RING_HOLD * float(rung), 0.6, 1.0)


static func scene(boss: Node, carried: int, rung: int, attuned: bool, words: Array) -> void:
	if boss == null or not boss.is_inside_tree():
		return
	AurelLines.fight(boss, "wake")
	var t := FIRST
	var step := 0
	for id: String in Chains.BELLS:
		var p := QuestBook.pick(id)
		if p == "":
			continue
		var nm := String((Chains.QUESTS[id] as Dictionary).get("name", "A bell"))
		var line := "%s rings far below, in Hearthward's chimney." % nm if p == "carried" else "%s rings where it hangs, and its country goes quiet." % nm
		_later(boss, t, line, step, true)
		t += GAP
		step += 1
	if carried + rung > 0:
		var tail := "The Founder's peal is in him. He holds the door with less: %s." % ("%s carried, %s rung" % [_word(words, carried), _word(words, rung)])
		_later(boss, t, tail, mini(step, 7), true)
	elif attuned:
		_later(boss, t, "The founder's bell rings in you. The sky will hold.", 0, true)
	else:
		_later(boss, t, "No bell answers. The sky is quiet as a held breath.", 0, false)


static func _word(words: Array, n: int) -> String:
	return String(words[mini(n, words.size() - 1)]) if n > 0 and not words.is_empty() else "none"


static func _later(boss: Node, t: float, line: String, step: int, strike: bool) -> void:
	boss.get_tree().create_timer(t, true).timeout.connect(func() -> void:
		if not is_instance_valid(boss) or not boss.is_inside_tree():
			return
		BossKit.emote(boss, line, BossKit.EMOTE_COL)
		if strike:
			BellVoice.ring(boss, float([0, 2, 4, 5, 7, 9, 11, 12][mini(step, 7)]), -9.0))

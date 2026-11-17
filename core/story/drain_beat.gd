extends RefCounted
## The drain, shown (a new game, the first minutes). The opening says the cold comes down the mountain to meet you; this is
## the cold arriving. About a minute into the night the Gloom tide's own signal is raised for a few seconds with nothing hunting
## in it: the green's people stop and turn and go indoors, the Keg falls quiet and every face turns to the door, the road's
## walkers hurry, and the sky's one low stroke sounds (bell_voice.gd). Then it lets go, one line, and the village comes back
## out. It is the premise as a thing that happens to the place the wanderer is standing in, before the keep has said a word.
## Played once by story.gd after the opening's second line. Saved state: none (the opening plays once). No class_name.
##   DrainBeat.play(host, say)   a coroutine, fire and forget; `say` takes an Array of subtitle lines (the dialogue box's narrate)

const BellVoice := preload("res://core/story/bell_voice.gd")

const START_AFTER := 9.0           ## s after the opening's second line is spoken
const LENGTH := 11.0               ## s the village keeps indoors


static func play(host: Node, say: Callable) -> void:
	if host == null or not host.is_inside_tree():
		return
	var tree := host.get_tree()
	await tree.create_timer(START_AFTER).timeout
	if not host.is_inside_tree():
		return
	Events.gloom_tide.emit(true)
	BellVoice.ring(host, -24.0, -7.0)                  # the sky's one beat, two octaves down
	BellVoice.ring(host, -19.0, -13.0, 1.4)            # and its flat answer
	say.call(["Every door on the green closes at once, as if one hand had done it. The cold is not weather. It is attention."])
	await tree.create_timer(LENGTH).timeout
	if not host.is_inside_tree():
		return
	Events.gloom_tide.emit(false)
	say.call(["It lets go. Nobody on the green says anything for a while. Then someone laughs, too loudly, and the doors begin to open."])

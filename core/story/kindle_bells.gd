extends Node
## The rising peal: every fire the wanderer kindles rings the bell, each one higher than the last, bottom to top, the
## way the Founder's bells are rung. The first fire is the low stroke, the second a third above, the third a fifth, the
## fourth an octave: four fires make the phrase the ending's one great bell finishes. A fire past the four (the outposts', the
## Reaches' beacons) rings the low stroke softly. Added by the story director; reads its count (`kindled()`).
## Saved state: none. The count is the world's.

const BellVoice := preload("res://core/story/bell_voice.gd")
const Story := preload("res://core/story/story.gd")
const STEPS := [0.0, 4.0, 7.0, 12.0]

var story: Story
var _rung := 0                   ## the highest stroke rung this session


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	story = get_parent() as Story
	Events.brazier_kindled.connect(_on_kindled)


func _on_kindled(_b: Node3D) -> void:
	_ring.call_deferred()


func _ring() -> void:
	if not is_inside_tree() or story == null:
		return
	var k := story.kindled()
	if k < 1 or k > 4 or k <= _rung:
		BellVoice.ring(self, 0.0, -17.0, 0.6)         # a fire past the four, or one the count already holds: the low stroke, softly
		return
	_rung = k
	BellVoice.ring(self, STEPS[k - 1], -9.0, 0.6)
	if k == 4:
		# the whole phrase, once, bottom to top: the valley's four fires answered
		for j in 3:
			BellVoice.ring(self, STEPS[j], -14.0, 1.6 + 0.55 * float(j))
		BellVoice.ring(self, STEPS[3], -9.0, 3.4)

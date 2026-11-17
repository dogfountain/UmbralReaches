extends Node
## The wanderer has no voice and no face, but the sky's splinter in the violet orb is why the spells are the sky's (docs/LORE.md): the first time each
## spell is cast, one line of what it is to do it, as a subtitle, once ever (a story flag, `cast_<id>`, saved). Never during a conversation or a fight's
## first seconds; one at a time. It is the only place the wanderer's own side is said, and it never says it plainly. Added by the story director. No class_name.

const LINES := {
	"bolt": "The bolt leaves your hand the colour of the sky's wound. It does not feel like throwing. It feels like giving back.",
	"lance": "The lance is a held breath let out as a line. Something old in you knew the shape before you did.",
	"nova": "The nova opens like a door. You do not look at what is in the doorway.",
	"peal": "Her mother's order, bottom to top. The air rings like a thing that has been waiting to be struck right.",
	"step": "A step through the sky's side. For an instant the world is a room you are leaving, and the dark behind you is very pleased.",
	"tether": "You hold it by a thread you did not know you had. It holds you back, a little. That is how you know it is yours.",
	"ward": "The ward is a small, clean, warm light, and it is the only spell that does not feel borrowed.",
	"familiar": "Something small and violet comes when you call. It has your tilt of the head. You do not ask where it learned it.",
	"well": "The well opens under you and answers in your own voice, a long way down. You are almost sure it said your name.",
	"sealed": "The seal answers to a word you did not say. It is, you gather, the word you are made of.",
}

const Story := preload("res://core/story/story.gd")
const DialogueUI := preload("res://ui/dialogue.gd")

var _story: Story
var _t := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_story = get_parent() as Story
	Events.skill_cast.connect(_on_cast)


func _on_cast(id: StringName) -> void:
	var k := String(id)
	if not LINES.has(k) or _story == null:
		return
	var key := "cast_" + k
	if _story.flag(key):
		return
	var now := Time.get_ticks_msec()
	var ui := _story.ui as DialogueUI
	if now - _t < 20000 or ui == null or not is_instance_valid(ui) or ui.is_open() or ui.narrating():
		return
	_t = now
	_story.set_flag(key)
	ui.narrate([String(LINES[k])])

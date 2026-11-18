extends RefCounted
## A line for each vow sworn (the eighteen of core/life/progression/vows.gd): said as a subtitle with a bell and a held chord (`vow_sworn`), in the wanderer's own
## register, which is to say almost never: plain, one sentence, no explanation. Called from Vows.choose. No class_name.

const CueBank := preload("res://core/audio/cue_bank.gd")
const Spoken := preload("res://core/story/spoken.gd")

const LINES := {
	"tithe": "A fire is a thing you pay a little to, and it pays back.",
	"roads": "Every country you have not walked is a country somebody is waiting in.",
	"banked": "Go out while the fire burns. It is a short leash and a kind one.",
	"lore": "Sit down more often. The fire asks nothing and gives a great deal.",
	"horse": "A horse is the one creature in the valley that wants only to go where you are going.",
	"coin": "The Bearers count them. It is something, to be counted by someone.",
	"waiver": "The fire asks no toll to take you back. It does not need to. You will be back.",
	"luck": "A parcel is a promise somebody else made, and you keep it.",
	"hand": "What you gather, you gather one more of. Nothing here is plentiful but hands.",
	"lantern": "The lantern is the whole of what you carry. Carry it as if it were someone.",
	"emberroad": "You are kin to the road of fires. It will set you down clean.",
	"unburdened": "Every twenty-fifth, a wound mended. The dead are generous.",
	"spoils": "After a great one falls, the world is briefly fuller. Use it.",
	"cartographer": "You will draw the country with your boots, and be paid in ash.",
	"hardened": "The deadly country is only country that has not yet been argued with.",
	"count": "The Count's lantern. Every foe you put down is a name it will not have to read.",
	"longnight": "The night is long and you have decided it need not be quite so.",
	"keeper": "The door remembers who rang. You have been remembered before. You will be again.",
}


static func sworn(id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	CueBank.play(tree.current_scene, "vow_sworn", 0.0)
	var line := String(LINES.get(id, ""))
	if line != "":
		Spoken.plain(tree, line)

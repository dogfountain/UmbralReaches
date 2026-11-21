extends RefCounted
## What the guide (core/story/guide.gd) says, per step of the first act: the banner's "where" line, what Hearthward's
## people call out when the wanderer walks past (a bark: one line, once per person per step), and what they answer
## when asked "Which way?" in a conversation. House style (docs/LORE.md): terse, concrete; nobody explains the
## world, they point at it and complain. Directions are from Hearthward (the spawn fire, 0, 33): the meadow fire is
## north, the Ring west up the Thornwood's hill, the Ossuary south down the Waiting Field's road, the Keg east.
## Load by path (no class_name): const GuideLines := preload("res://core/story/guide_lines.gd")

## step id -> the banner's name for the step (the tracker keeps the whole sentence)
const SHORT := {
	"arrive": "Find the keep",
	"first_fire": "Kindle the meadow fire",
	"doors": "Pick a door",
	"thorn_seal": "Break the thorn seal",
	"thornwarden": "Cut the Thorn Heart",
	"oss_seal": "Break the gallery seal",
	"bone_abbot": "Take the Abbot's crown",
	"peal": "Brannoc's bells",
}

## step id -> the banner's second line (where it is)
const WHERE := {
	"arrive": "The Kindled Keg, east of the fire. The keep is behind the bar.",
	"first_fire": "North, up the lane past the last house. Light is somewhere to stand.",
	"doors": "The thorn seal west, up the Thornwood's hill, or the gallery seal south, down the Waiting Field's road.",
	"thorn_seal": "West, past the glade, up the hill in the Thornwood.",
	"thornwarden": "The Ring, on the Thornwood's hill.",
	"oss_seal": "South, down the Waiting Field's road, past the tomb, over the bridge.",
	"bone_abbot": "The Abbot's hall, at the bottom of the Ossuary.",
	"peal": "Brannoc drinks at the Kindled Keg.",
}

## step id -> lines a passer-by calls out (one is picked per person)
const BARKS := {
	"arrive": [
		"The keep's in the Keg. Lit door, east of the fire. He's been waiting on somebody with a lantern.",
		"You'll want the keep. The Kindled Keg, the big house with the lamps in it.",
		"Keg's that way. East. Follow the noise and don't touch the dice.",
		"Lantern-bearer. The keep said one would come. Kindled Keg, behind the bar.",
	],
	"first_fire": [
		"Meadow fire's gone cold. North up the lane, where the oaks start.",
		"North, out in the meadow. That brazier's not been fed since the sky went.",
		"You've a lantern. The meadow brazier needs it more than we do.",
	],
	"doors": [
		"Thorns west, bones south. I'd take neither. You'll take one.",
		"Thorn seal's up the western hill. The crypt door's south, past the Waiting Field. Both bite.",
		"West for the oaks that move. South-west for the dead that count. Pick.",
	],
	"thorn_seal": [
		"The thorn seal's west, on the Thornwood's hill. Mind the roots.",
		"West, past the glade. The hedge has a mouth. Something's stopped it.",
	],
	"thornwarden": [
		"The Ring's up the western hill. Don't stand where the stones lean.",
		"Thornwarden keeps the Ring. West, uphill. Cut its heart out and the wood forgets you.",
	],
	"oss_seal": [
		"The gallery's under the Waiting Field. Follow the coffin stones down the Lych Way.",
		"South, down the Waiting Field's road. The bridge, then the gate.",
	],
	"bone_abbot": [
		"The Abbot's at the bottom of the pit, counting. Don't answer him.",
		"Down the Counting Stair. All the way. He'll be the one with the crown.",
	],
	"peal": [
		"Brannoc's at the Keg, talking bells into his cup. Go and let him.",
		"The bellwright's son is at the Keg. He's been waiting on you to come back with both.",
	],
}

## step id -> the answer to "Which way?" in a conversation
const ANSWER := {
	"arrive": "The keep. The Kindled Keg, east of the fire: the lit door. He'll tell you what the night wants.",
	"first_fire": "Kindle the brazier in the north meadow, up the lane past the last house. A lit fire is somewhere to stand.",
	"doors": "Two doors. The thorn seal west, up the Thornwood's hill, or the gallery seal south, down the Waiting Field's road. Either. Both, in the end.",
	"thorn_seal": "West, past the Glimmer Glade, up the hill in the Thornwood. The seal is in the hedge's mouth.",
	"thornwarden": "The Ring on the western hill. The Thornwarden's in it, and the heart's in him.",
	"oss_seal": "South, down the Waiting Field's road and along the brow, past the tomb. A stone bridge crosses the quarry to the gate.",
	"bone_abbot": "The bottom of the Ossuary. The Abbot's hall. Take his crown and don't let him count you.",
	"peal": "Back to the Keg. Brannoc knows what the door wants now.",
}

## The choice villagers offer while the guide is on.
const ASK := "Which way?"

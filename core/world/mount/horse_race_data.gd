extends RefCounted
## The Hearthward races: the four courses, the field of rivals and the words of the start ritual. Pure data and small static
## helpers; the race itself is core/world/mount/horse_race.gd. Load by path (no class_name).
##
## A course is an ellipse laid on the ground from the Hearthward rail: `a` along `ang` (radians from north, clockwise), `b` across,
## `n` gates, `dir` the way round (1 clockwise, -1 not). The gates are chosen when the ritual starts (dry ground, no cliff) so a
## course never runs through a lake or up a wall. `pace` is the base speed of the field in m/s; the player's palfrey gallops 14.

const COURSES := {
	"green": {"name": "The Green Round", "a": 58.0, "b": 48.0, "n": 5, "ang": 0.6, "dir": 1, "pace": 10.4, "pay": 0.12,
		"line": "Once about the green and the keg's back wall. Children's race, said Fennick; the children are losing."},
	"hollow": {"name": "The Hollow Loop", "a": 92.0, "b": 62.0, "n": 6, "ang": 2.4, "dir": -1, "pace": 11.2, "pay": 0.13,
		"line": "Out through the oaks and round the hollow ground. Two bends are blind and one is a bog in a wet year."},
	"dash": {"name": "The Hearthward Dash", "a": 118.0, "b": 22.0, "n": 4, "ang": 4.0, "dir": 1, "pace": 12.0, "pay": 0.14,
		"line": "Out along the old lane, round a cairn, back. A long thin race, won in the straight and lost at the turn."},
	"long": {"name": "The Long Circuit", "a": 150.0, "b": 108.0, "n": 8, "ang": 5.3, "dir": -1, "pace": 12.5, "pay": 0.15,
		"line": "The whole country about the town. Eight gates, a hill, a ford. The Hearthward Cup is won here or nowhere."},
}
const ORDER := ["green", "hollow", "dash", "long"]
const FIELD := [0.93, 0.985, 1.04]                    ## each rival's share of the course's pace
const PLACE_PAY := [1.0, 0.6, 0.35, 0.15]             ## the purse, by place
const GATE_R := 10.0                                  ## a gate is passed within this many metres
const SPEED_GOLD := 12.0                              ## the gold time is the course's length at this speed (and a few seconds)

const RIDERS := ["Edda Marl", "Tobias Reed", "Wenna Foy", "Hob Sallow", "Maren Coyle", "Fitch the Carter", "Joss Harrow", "Ansel Thorn",
	"Brannoc's nephew", "Old Gwen", "Tamsin Vail", "Corvin Ashby", "Mabel Wade", "Orrin Fallow", "the Ringer's girl", "Sedge"]
const MOUNTS := ["Candle", "Biscuit", "Thistle", "Marrow", "Pennywhistle", "Bellows", "Saltwick", "Ragwort", "Duster", "Kettle",
	"Lantern", "Tinder", "Harebell", "Gorse", "Mutton", "Ladle"]
## The breeds the rivals wear (the models stand ready behind the loading screen: horse_race_field.gd).
const BREEDS := ["garron", "fenpony", "draught"]

const HERALD := [
	"Fennick walks the line with his lantern held low.",
	"Fennick counts the horses twice, as if one might have been added.",
	"The Keg has emptied onto the green. Someone is taking bets in grave ash.",
	"A child sits on the pump handle to see better and is told to get down.",
	"Fennick says the old words: round the gates, in order, and no man cuts a corner he cannot name.",
	"The riders tighten girths and say nothing. The horses say a great deal.",
	"Fennick lifts the lantern. The green goes quiet, which it has not done all night.",
	"Hild has come out of the forge to watch. She is not betting. She is, of course, betting.",
]
const SET := ["Ready.", "Hold.", "Hold it.", "Now."]
const WON := [
	"Hearthward cheers, and some of it is relief. Fennick presses the purse into your hand.",
	"First across, with a length to spare. The Keg pours one more than it should.",
	"You take the line with the whole green on its feet. Somebody has begun a song.",
	"The lantern drops and you are through it first. Fennick says, quietly, that he had hoped.",
	"A clean win. The other riders walk their horses in a ring and look at the ground.",
	"First home. The old women at the pump nod once, which is the most they give.",
]
const PLACED := [
	"Second, and close enough to feel it. Fennick pays what the second place is owed.",
	"Third across. The horse blows hard and does not regret it. Neither do you.",
	"Fourth, and still on your feet. The green applauds the finish, which is kind.",
]
const LATE := [
	"The field is long gone by the time you cross. Fennick hands you the small purse and a cloth for the horse.",
	"Last, and the lantern is nearly out. The horse is fine. The green says it was a good ride.",
]
const FALSE_START := [
	"You were over the line before the lantern fell. Two seconds on your time.",
	"Too early. Fennick marks it: two seconds.",
]
const OUT := [
	"You have left the saddle. The race goes on without you.",
	"Down from the horse: the race is called for you.",
]


## The path length of a course through its gates, from the line and back to it.
static func length_of(pts: Array[Vector3]) -> float:
	var s := 0.0
	for i in pts.size():
		s += Vector2(pts[i].x, pts[i].z).distance_to(Vector2(pts[(i + 1) % pts.size()].x, pts[(i + 1) % pts.size()].z))
	return s


## Gold, silver and bronze limits (seconds) for a course of this length.
static func limits(length: float) -> Array[float]:
	var g := length / SPEED_GOLD + 4.0
	return [g, g * 1.12, g * 1.32]


static func medal(length: float, secs: float) -> String:
	var l := limits(length)
	if secs <= l[0]:
		return "gold"
	if secs <= l[1]:
		return "silver"
	if secs <= l[2]:
		return "bronze"
	return "late"


static func place_word(i: int) -> String:
	return ["1st", "2nd", "3rd", "4th"][clampi(i, 0, 3)]

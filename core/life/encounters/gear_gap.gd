extends RefCounted
## The gear-gap hint. Item level changes nothing by itself (the Paths, spells, vows and sets are the power), but a wanderer in
## worn-out gear on deep ground is worth a word: the plate says when the average item level of the four slots (an empty slot
## counts nought) is well behind what a pawn of that ground's level calls for. The curve (opening_systems.md): a piece's
## item level is 8 + 7 per rarity + 3 per raise (+3 set, +4 named, +6 legend), a common piece 8 and a legend about 36, so the
## gear to expect at a pawn's level L is 8 + L (level 1: 9, level 30: 38). Behind by BEHIND or more, on ground rated Even or
## worse, is a hint; never in a town. Pure and static; load by path. Read twice a second at most (the minimap's place scan).
const GearStats := preload("res://core/items/gear_stats.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const BEHIND := 6


## The average item level of the four slots worn now (an empty slot is 0).
static func worn_level() -> int:
	var total := 0
	var pieces: Dictionary = GearStats.worn(GearStats.state())
	for slot: String in GearDB.SLOTS:
		if pieces.has(slot):
			total += GearDB.item_level(pieces[slot] as Dictionary)
	return roundi(float(total) / float(GearDB.SLOTS.size()))


## The item level a pawn of `level` calls for.
static func want(level: int) -> int:
	return 8 + level


## "" or a short note: `level` is the pawn's level where the wanderer stands, `band` Danger.band (0 haven .. 4 deadly).
static func note(level: int, band: int) -> String:
	if band < 2:
		return ""
	var have := worn_level()
	var need := want(level)
	if need - have < BEHIND:
		return ""
	if have == 0:
		return "No gear worn: ground like this wants item level %d" % need
	return "Gear behind: item level %d, ground like this wants %d" % [have, need]

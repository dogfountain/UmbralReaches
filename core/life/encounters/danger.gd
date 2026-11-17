extends RefCounted
## How dangerous a place is for THIS wanderer, in words and colours the player can read. The night's tiers (tiers.gd) say
## what a place is; the plate used to print their names ("Dusk", "Night"), which read as a clock. Here the plate says what a
## pawn of that ground is worth, set against the wanderer's own Remembrance: Haven, Gentle, Even, Perilous, Deadly.
##   plate(at)        "Even · Lv 9": the minimap's line under the region's name
##   band(at)         0..4, the plate's tint index (0 haven .. 4 deadly)
##   boss_level(tree, boss_id)   what a great one of that arena is worth (a pawn's level and a rank above)
##   warn_text(at)    the sentence the danger watch speaks on first entering a deadly country ("" = none)
## Pure and static; the wanderer's level is read from the progression state, never from the HUD.
## Load by path (no class_name): const Danger := preload("res://core/life/encounters/danger.gd")

const Access := preload("res://ui/access.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const LevelDB := preload("res://core/life/progression/level.gd")
const GearGap := preload("res://core/life/encounters/gear_gap.gd")

const HAVENS := ["hearth", "weirford", "saltmarket", "lastlight", "fallow"]      ## the towns' own ground: the dark does not come in
const NAMES := ["Haven", "Gentle", "Even", "Perilous", "Deadly"]
const COLORS := [Color(0.72, 0.9, 0.72), Color(0.66, 0.88, 0.62), Color(0.96, 0.86, 0.5), Color(1.0, 0.62, 0.34), Color(1.0, 0.36, 0.3)]
const BOSS_RANK := 2                               ## a great one stands this far above a pawn of its ground


static var _lv := 0
static var _lv_ms := -1000


## The wanderer's level (read at most twice a second: the enemy plates and the minimap ask every frame they draw).
static func player_level() -> int:
	var now := Time.get_ticks_msec()
	if now - _lv_ms > 500:
		_lv_ms = now
		_lv = int(LevelDB.info(Travel.system_state("progression"), Travel.bosses_slain.size()).get("level", 0))
	return _lv


## The level a plain pawn at `at` shows on its plate (the tier's band and the distance from the hub).
static func pawn_level(at: Vector3) -> int:
	return Tiers.level_for(Tiers.tier_at(at), at)


static func band(at: Vector3) -> int:
	if Tiers.region_id(at) in HAVENS:
		return 0
	return rate(pawn_level(at))


static func plate(at: Vector3) -> String:
	var b := band(at)
	return NAMES[b] if b == 0 else "%s · Lv %d" % [NAMES[b], pawn_level(at)]


## "Recommended level 14 (you are 9)" for a task's first step that has a place, or "" in a haven or when it has none.
static func task_hint(qd: Dictionary) -> String:
	for stp: Variant in qd.get("steps", []):
		if stp is Dictionary and (stp as Dictionary).get("at") is Vector2:
			var a: Vector2 = (stp as Dictionary).at
			var at := Vector3(a.x, 0.0, a.y)
			if band(at) == 0:
				return ""
			return "Recommended level %d (you are %d)" % [pawn_level(at), player_level()]
	return ""


## The gear-gap hint for the ground at `at` (core/life/encounters/gear_gap.gd): "" when the gear is not behind.
static func gear_note(at: Vector3) -> String:
	return GearGap.note(pawn_level(at), band(at))


## Where a pawn of `level` stands against the wanderer, as a band (the plate's own thresholds, for enemy plates).
static func rate(level: int) -> int:
	var d := level - player_level()
	if d <= -5:
		return 1
	if d <= 1:
		return 2
	if d <= 4:
		return 3
	return 4


static func color(b: int) -> Color:
	var c: Color = COLORS[clampi(b, 0, COLORS.size() - 1)]
	return Access.safe(["good", "good", "even", "warn", "bad"][clampi(b, 0, 4)], c)


## The great one of arena `boss_id`: its level, or 0 when no such arena stands.
static func boss_level(tree: SceneTree, boss_id: String) -> int:
	for a in tree.get_nodes_in_group(&"boss_arena"):
		var n := a as Node3D
		if n != null and "boss_id" in n and String(n.get("boss_id")) == boss_id:
			return pawn_level(n.global_position) + BOSS_RANK
	return 0


## " (suggested level 14; you are 9)" for the arena, or "" when unknown.
static func boss_hint(tree: SceneTree, boss_id: String) -> String:
	var l := boss_level(tree, boss_id)
	if l <= 0:
		return ""
	return "  Suggested level %d (you are %d)." % [l, player_level()]


static func warn_text(at: Vector3) -> String:
	if band(at) < 4:
		return ""
	var gear := gear_note(at)
	return "The dark is deeper here: a pawn of this ground is level %d, and you are %d. Fires are fewer. %sGo warily, or go back." % [pawn_level(at), player_level(), (gear + ". ") if gear != "" else ""]

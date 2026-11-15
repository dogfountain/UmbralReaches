extends RefCounted
## THE WANDERER'S LEVEL AND XP BAR (r33 progression; WoW's character level and rested XP, adapted).
## Load by path (no class_name):  const LevelDB := preload("res://core/life/progression/level.gd")
##
## The level is the Remembrance (paths_db.gd): the memory is the XP, and `XP` below is the only table of what each deed pays. Every level-up is one point to
## spend on a Path (the Kindling's PATHS tab, [K]); each of the great ones put down is one more.
## Max level PathsDB.MAX_LEVEL (30). XP to go from level L to L+1: PathsDB.need(L) = 60 + 20 L.
##
## --- FOR THE UI (the XP bar) ------------------------------------------------------------------
## The runtime is the Hearth node (core/life/progression/hearth.gd), group "hearth":
##   var h := get_tree().get_first_node_in_group("hearth")
##   h.xp_changed.connect(func(info: Dictionary) -> void: ...)   # every gain, level-up, rest
##   h.leveled_up.connect(func(level: int, points: int) -> void: ...)   # points: free to spend
##   var info: Dictionary = h.xp_info()                           # read any time
## Without the node (menus, tests): LevelDB.info(Travel.system_state("progression"), bosses).
## info = {
##   level: int          the Remembrance (0 .. max_level)
##   max_level: int
##   xp: int             all memory ever gathered
##   into: int           XP into this level        need: int   XP this level takes
##   frac: float         into / need (0..1; 1.0 at the cap)
##   rested: int         rested XP left: kill XP is doubled until it is spent (WoW's rested bonus)
##   rested_frac: float  where the rested marker sits on the bar: (into + rested) / need, capped 1
##   capped: bool        at max level
##   free_points: int    Path points not yet spent
##   last_gain: int      the most recent gain (incl. any rested bonus), last_why: String its source
## }
##
## --- XP sources (XP below; hearth.gd listens to Events) -----------------------------------------
##   kill: by the foe (GearRuntime.source_of): common 3, tough 5, elite 15, Deeper Night elite 25,
##         rare (meta &"rare_id") 40; a great one's own kill gives nothing extra (boss_slain does)
##   boss_slain 150, quest done 24 + 1.5 x its ash (quest_xp; a repeat pays half), seal broken 50, fire kindled 40, homecoming 30, keepsake 25,
##   discovery 20: the first time a place's banner shows (Events.zone_entered, by title)
##   gathering 5: an ash-bloom or grave-iron node (core/items/gather_node.gd)
## Rested: standing at Hearthward's fire or in the Keg (hearth.gd rest_here) grants the Rested buff
## AND fills the rested pool by half a level (REST_FILL), up to REST_CAP levels. While the pool
## lasts, every kill gives double XP (the bonus is taken from the pool). The pool survives a save.
##
## State (Travel.system_state("progression")): memory int, rested_xp int, seen {title -> true}.
## Old saves have no rested_xp / seen: they read as 0 / {}.

const PathsDB := preload("res://core/life/progression/paths_db.gd")

const XP := {"kill": 3, "tough": 5, "elite": 15, "umbral": 25, "rare": 40, "boss": 150,
	"quest": 60, "seal": 50, "kindle": 40, "home": 30, "keepsake": 25, "discover": 20, "gather": 5}
const REST_FILL := 0.5          ## levels of rested XP a rest adds
const REST_CAP := 1.5           ## most rested XP held, in levels (of the current level's need)
## Sources the rested pool doubles (kills only, as in WoW).
const RESTED_SOURCES := ["kill", "tough", "elite", "umbral", "rare"]


## What a task pays: more for a bigger errand (its ash is the measure of the work), and half as much
## the second time round for a daily (the same errand is not the same deed twice).
static func quest_xp(ash: int, repeat := false) -> int:
	var n := 24 + roundi(1.5 * float(maxi(0, ash)))
	return maxi(1, n / 2) if repeat else n


static func xp_for(source: String) -> int:
	return int(XP.get(source, 0))


static func info(ps: Dictionary, bosses: int) -> Dictionary:
	var mem := int(ps.get("memory", 0))
	var lv := PathsDB.level_of(mem)
	var capped := int(lv.level) >= PathsDB.MAX_LEVEL
	var need := maxi(1, int(lv.need))
	var into := int(lv.into)
	var rested := maxi(0, int(ps.get("rested_xp", 0)))
	return {"level": int(lv.level), "max_level": PathsDB.MAX_LEVEL, "xp": mem, "into": into, "need": need,
		"frac": 1.0 if capped else clampf(float(into) / float(need), 0.0, 1.0),
		"rested": rested, "rested_frac": 1.0 if capped else clampf(float(into + rested) / float(need), 0.0, 1.0),
		"capped": capped, "free_points": PathsDB.free_pts(ps, bosses), "last_gain": 0, "last_why": ""}


## How much a gain of `n` from `why` really gives, and how much of the rested pool it spends:
## [total, spent].
static func with_rested(ps: Dictionary, n: int, why: String) -> Array:
	var pool := maxi(0, int(ps.get("rested_xp", 0)))
	if pool <= 0 or not RESTED_SOURCES.has(why):
		return [n, 0]
	var bonus := mini(n, pool)
	return [n + bonus, bonus]


## The pool after a rest (the current level's need sets the fill and the cap).
static func rest_pool(ps: Dictionary) -> int:
	var lv := int(PathsDB.level_of(int(ps.get("memory", 0))).level)
	var need := PathsDB.need(lv)
	var pool := maxi(0, int(ps.get("rested_xp", 0))) + roundi(float(need) * REST_FILL)
	return mini(pool, roundi(float(need) * REST_CAP))

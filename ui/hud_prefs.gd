extends RefCounted
## HUD preferences (r33): what the minimap tracks, whether combat text and the unit frames show, and
## a request to bring the controls card back. Kept in hud.cfg next to settings.cfg (SaveDir, so tests
## with --save-dir never touch the real one). Static: the settings menu writes, the HUD reads.
## Load by path (no class_name): const HudPrefs := preload("res://ui/hud_prefs.gd")

const SaveDir := preload("res://core/util/save_dir.gd")
const FILE := "hud.cfg"

## Minimap tracking groups (WoW's tracking menu): each map_kind belongs to one.
const TRACK := {
	"quests": ["quest_available", "quest_turnin", "quest_target"],
	"rares": ["rare"],
	"travel": ["travel"],
	"gather": ["gather"],
	"town": ["vendor", "trainer"],
	"foes": ["foe"],
	"chests": ["chest"],
}
const TRACK_NAMES := {
	"quests": "Tasks", "rares": "Rare foes", "travel": "Fires & bells", "gather": "Gathering",
	"town": "Traders", "foes": "Foes nearby", "chests": "Chests nearby",
}

static var track := {"quests": true, "rares": true, "travel": true, "gather": true, "town": true, "foes": true, "chests": true}
static var combat_text := true
static var unit_frames := true
static var enemy_plates := false       ## world health bars over every foe, and the target frame on foes you only struck (off: the locked-on target only)
static var guide := true               ## the new player's guide (core/story/guide.gd): waypoint, pinned objective, prompts
static var card_request := 0           ## bumped by the settings menu: the HUD shows the controls card again
static var _loaded := false


## Every choice back to its default (Settings' Reset to Defaults), saved.
static func reset() -> void:
	ensure()
	for k: String in track:
		track[k] = true
	combat_text = true
	unit_frames = true
	enemy_plates = false
	guide = true
	save()


## The next ensure() reads the slot's file again (a new night, another slot, an erased save).
static func forget() -> void:
	_loaded = false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SaveDir.path(FILE)) != OK:
		return
	for k: String in track:
		track[k] = bool(cfg.get_value("track", k, true))
	combat_text = bool(cfg.get_value("hud", "combat_text", true))
	unit_frames = bool(cfg.get_value("hud", "unit_frames", true))
	enemy_plates = bool(cfg.get_value("hud", "enemy_plates", false))
	guide = bool(cfg.get_value("hud", "guide", true))


static func save() -> void:
	var cfg := ConfigFile.new()
	for k: String in track:
		cfg.set_value("track", k, bool(track[k]))
	cfg.set_value("hud", "combat_text", combat_text)
	cfg.set_value("hud", "unit_frames", unit_frames)
	cfg.set_value("hud", "enemy_plates", enemy_plates)
	cfg.set_value("hud", "guide", guide)
	SaveDir.save_atomic(cfg, SaveDir.path(FILE))


## Is a minimap kind tracked? Unknown kinds show.
static func tracks(kind: String) -> bool:
	ensure()
	for k: String in TRACK:
		if kind in (TRACK[k] as Array):
			return bool(track.get(k, true))
	return true


static func set_track(group: String, on: bool) -> void:
	ensure()
	track[group] = on
	save()


# --- the staged opening ----------------------------------------------------------------------

## A new game: the story has not had its arrival yet, and there is no progress in the save.
static var test_force := false          ## zz/opening_test: stage the opening in a headless run too
static func new_game_open() -> bool:
	var flags: Variant = Travel.story.get("flags", {})
	if flags is Dictionary and bool((flags as Dictionary).get("arrived", false)):
		return false
	return Travel.bosses_slain.is_empty() and Travel.seals_broken.is_empty() and Travel.lit_by_path.is_empty() and (test_force or DisplayServer.get_name() != "headless")


## The Gloom bar is not drawn until Gloom first rises above 0 (once per save; an older save already knows it).
static func gloom_known() -> bool:
	return bool(Travel.story.get("gloom_seen", false)) or not new_game_open_cached()


static var _new_game_cache := -1


static func new_game_open_cached() -> bool:
	if _new_game_cache < 0:
		_new_game_cache = 1 if new_game_open() else 0
	return _new_game_cache == 1


## The HUD asks this once as it builds: a fresh look at whether this is a new game.
static func reset_stage() -> void:
	_new_game_cache = -1


static func note_gloom(value: float) -> void:
	if value > 0.0005 and not bool(Travel.story.get("gloom_seen", false)):
		Travel.story["gloom_seen"] = true
		Travel.save_soon()

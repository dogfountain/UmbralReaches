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
	"quests": "Tasks", "rares": "Rare foes", "travel": "Waygates", "gather": "Gathering",
	"town": "Traders & teachers", "foes": "Foes nearby", "chests": "Chests nearby",
}

static var track := {"quests": true, "rares": true, "travel": true, "gather": true, "town": true, "foes": true, "chests": true}
static var combat_text := true
static var unit_frames := true
static var card_request := 0           ## bumped by the settings menu: the HUD shows the controls card again
static var _loaded := false


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


static func save() -> void:
	var cfg := ConfigFile.new()
	for k: String in track:
		cfg.set_value("track", k, bool(track[k]))
	cfg.set_value("hud", "combat_text", combat_text)
	cfg.set_value("hud", "unit_frames", unit_frames)
	cfg.save(SaveDir.path(FILE))


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

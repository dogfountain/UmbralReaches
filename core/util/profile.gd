extends RefCounted
## The player's profile: what belongs to the person, not to a save slot (profile.cfg beside settings.cfg). Today: how many
## times the night has been ended ("endings"), which a New Game reads to open differently (the second night's opening), and
## the best ride times of the road (see core/world/mount/courier.gd). Versioned: `version` is bumped when a key changes
## meaning, and a file that cannot be read is replaced by defaults, never an error.
## Load by path (no class_name): const Profile := preload("res://core/util/profile.gd")

const SaveDir := preload("res://core/util/save_dir.gd")
const FILE := "profile.cfg"
const VERSION := 1

static var endings := 0
static var best: Dictionary = {}          ## courier route id -> best seconds
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SaveDir.path(FILE)) != OK:
		return
	endings = int(cfg.get_value("profile", "endings", 0))
	var b: Variant = cfg.get_value("profile", "best", {})
	best = (b as Dictionary).duplicate() if b is Dictionary else {}


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "version", VERSION)
	cfg.set_value("profile", "endings", endings)
	cfg.set_value("profile", "best", best)
	SaveDir.save_atomic(cfg, SaveDir.path(FILE))


static func note_ending() -> void:
	ensure()
	endings += 1
	save()


static func forget() -> void:
	_loaded = false

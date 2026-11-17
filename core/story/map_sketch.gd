class_name MapSketch
extends Node
## The charcoal sketch of the world map: ground the wanderer has seen is drawn in as she walks. A grid on the map's own fog grid
## (5 m cells over the sheet, ui/world_map.gd: SHEET and FOG) of bytes, 0 unseen to 255 seen. Once a second a timer asks whether the
## wanderer has moved to another cell; only then is a soft disc of 38 m drawn into the grid (about 180 cells), and the map reads the
## grid as a texture when it is opened. Landmarks (ui/world_map_landmarks.gd) are marked seen when the grid at their place reaches 0.8,
## and the map inks them. The grid is saved as a compressed, base64 string in Travel.story["sketch"] (a few hundred bytes of
## mostly zeros), rewritten only when the grid changed (a compress of 23 KB, microseconds); an old save with a trail backfills the grid from it.
## Cost: a once-a-second timer, nothing per frame, no texture work in play (the map builds its texture on opening). A child of the
## story director (class MapSketch).

const ORIGIN := Vector2(-420.0, -214.0)
const CELL := 5.0
const W := 168                                          ## ceil(840 / 5)
const H := 137                                          ## ceil(682 / 5)
const SIGHT := 38.0
const VERSION := 1
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const KEY := "sketch"
const LM_KEY := "sketch_lm"

static var cells := PackedByteArray()
static var _dirty := false
static var _loaded := false

var _last := Vector2i(-9999, -9999)
var _timer: Timer


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	cells.resize(W * H)
	cells.fill(0)
	_load()


static func reset() -> void:
	_loaded = false
	cells = PackedByteArray()
	_dirty = false


static func _load() -> void:
	var s: Variant = Travel.story.get(KEY, null)
	if not (s is String) or String(s) == "":
		_backfill()
		return
	var raw := Marshalls.base64_to_raw(String(s))
	if raw.size() < 4:
		return
	var out := raw.decompress(W * H, FileAccess.COMPRESSION_DEFLATE) if raw.size() > 0 else PackedByteArray()
	if out.size() == W * H:
		cells = out


## An old save has a trail but no sketch: draw the sketch along what was walked.
static func _backfill() -> void:
	var t: Variant = Travel.story.get("trail", null)
	if not (t is Array):
		return
	var a := t as Array
	for i in range(0, a.size() - 1, 2):
		reveal(Vector2(float(a[i]), float(a[i + 1])))


const SECTORS := 24
const RINGS := 8

## Draw a disc of sight at world xz `at` into the grid, as far as the ground is seen: `eye` is the height of the wanderer's eye. The
## ground is read once per ring cell along 24 rays (192 samples of RealmLand.height_at, only when she has moved to another cell): a
## ring cell is seen when its ground rises to the highest angle yet met along that ray, so the far side of a ridge or cliff stays
## unsketched. Without an eye (a backfill from the trail) the disc is plain. True when any cell grew.
static func reveal(at: Vector2, eye := NAN) -> bool:
	ensure()
	var c := (at - ORIGIN) / CELL
	var r := SIGHT / CELL
	var seen := PackedByteArray()
	if not is_nan(eye):
		seen.resize(SECTORS * RINGS)
		for sct in SECTORS:
			var dir := Vector2.from_angle((float(sct) + 0.5) * TAU / float(SECTORS))
			var top := -INF
			for ring in RINGS:
				var d := SIGHT * float(ring + 1) / float(RINGS)
				var p := at + dir * d
				var ang := (RealmLand.height_at(p.x, p.y) - eye) / d
				if ang >= top - 0.02:
					seen[sct * RINGS + ring] = 1
				top = maxf(top, ang)
	var changed := false
	for j in range(maxi(int(c.y - r), 0), mini(int(c.y + r) + 1, H)):
		for i in range(maxi(int(c.x - r), 0), mini(int(c.x + r) + 1, W)):
			var off := Vector2(float(i) + 0.5, float(j) + 0.5) - c
			var d := off.length()
			if d > r:
				continue
			if not seen.is_empty() and d > 1.5:
				var sct := clampi(int(fposmod(off.angle(), TAU) / TAU * float(SECTORS)), 0, SECTORS - 1)
				var ring := clampi(int(d / r * float(RINGS)), 0, RINGS - 1)
				if seen[sct * RINGS + ring] == 0:
					continue
			var v := int((1.0 - smoothstep(r * 0.55, r, d)) * 255.0)
			var k := j * W + i
			if v > int(cells[k]):
				cells[k] = v
				changed = true
	if changed:
		_dirty = true
	return changed


## How much of the ground at world xz is sketched, 0 to 1.
static func at(x: float, z: float) -> float:
	ensure()
	var i := clampi(int((x - ORIGIN.x) / CELL), 0, W - 1)
	var j := clampi(int((z - ORIGIN.y) / CELL), 0, H - 1)
	return float(cells[j * W + i]) / 255.0


## Write the grid into the save string now (the save reads Travel.story).
static func flush() -> void:
	if not _dirty or not _loaded:
		return
	_dirty = false
	Travel.story[KEY] = Marshalls.raw_to_base64(cells.compress(FileAccess.COMPRESSION_DEFLATE))
	Travel.story["sketch_v"] = VERSION


func _ready() -> void:
	name = "MapSketch"
	reset()                                                  # a new run or slot reads its own story
	ensure()
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.one_shot = false
	_timer.autostart = true
	_timer.timeout.connect(_tick)
	add_child(_timer)
	call_deferred("_tick")


func _exit_tree() -> void:
	flush()


func _tick() -> void:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or p.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var here := Vector2(p.global_position.x, p.global_position.z)
	var cell := Vector2i(int((here.x - ORIGIN.x) / CELL), int((here.y - ORIGIN.y) / CELL))
	if cell != _last:
		_last = cell
		if reveal(here, p.global_position.y + 1.6):
			flush()                                   # a few microseconds: the grid is mostly zeros

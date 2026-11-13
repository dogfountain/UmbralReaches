extends RefCounted
## When cosmetic work that need not run every frame should run. A frame that carries a physics tick is the heavy
## one (the foes' and the wanderer's tick, the step, the transforms they moved: 2.5 to 4 ms more than a frame
## between ticks in a fight, fight_bench "FIGHT PARTS"), and the HUD's moving layers all came due on the same frame
## (each waited 25 ms from its own last draw, so they stayed in step: one frame in three drew five of them, about
## 1 ms, two times in three on a tick frame). `due` puts such work on the frames between ticks, and two halves of it
## on alternate ones.
## Load by path (no class_name): const FramePace := preload("res://core/util/frame_pace.gd")

const MIN_MS := 22            ## on its own frame: at least this long since its last run (40 a second at most)
const LATE_MS := 30           ## on any frame, tick or not, once this late (a frame rate where every frame ticks)

static var _frame := -1
static var _tick := -1
static var _ticked := false
static var _quiet := 0        ## frames without a tick, counted


## Did a physics tick run in this frame (before its _process calls)?
static func ticked() -> bool:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		var t := Engine.get_physics_frames()
		_ticked = t != _tick
		_tick = t
		if not _ticked:
			_quiet += 1
	return _ticked


## Should work last run at `last_ms` (Time.get_ticks_msec) run in this frame? `slot` 0 or 1: which of the alternate
## frames between ticks is its own.
static func due(last_ms: int, slot := 0) -> bool:
	var el := Time.get_ticks_msec() - last_ms
	if el < MIN_MS:
		return false
	if el >= LATE_MS:
		return true
	return not ticked() and (_quiet & 1) == (slot & 1)

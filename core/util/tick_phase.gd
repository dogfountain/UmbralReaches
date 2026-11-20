extends RefCounted
## Spread periodic ticks over the frames. A dozen systems keep a half-second (or quarter-second) timer, and every one of
## them started at the same moment at load and reset with `t = period`, so they all fired on the same frame: twice a
## second a frame ran 2 ms more scripts and the next frame came late (20 Nov, the fps pass: the 1% lows at
## r_orchard_save and r_barrows were frames 0.5 s apart). Each timer now starts at its own phase (from its owner's
## instance id) and keeps it: `next` adds the period instead of setting it, so two timers never drift into one frame.
## Load by path (no class_name): const TickPhase := preload("res://core/util/tick_phase.gd")


## A first wait in [0, period) that differs from owner to owner (the golden-ratio sequence of its instance id).
static func first(owner: Object, period: float) -> float:
	return period * fposmod(float(owner.get_instance_id() % 104729) * 0.618034, 1.0)


## The wait after a tick that fired with `left` (<= 0) still on its clock: the phase is kept; after a long frame (or a
## pause) that already covers a whole period it starts a fresh one instead of firing on the next frames to catch up.
static func next(left: float, period: float) -> float:
	left += period
	return left if left > 0.0 else period


## The same for a clock that counts up (`acc += dt; if acc >= period: tick`): what it keeps after the tick.
static func carry(acc: float, period: float) -> float:
	acc -= period
	return acc if acc < period else 0.0

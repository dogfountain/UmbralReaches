class_name Metrics
extends RefCounted
## World metrics: the one set of numbers every builder (OssKit pieces, summit stair, mage statue,
## lift, future tavern/cathedral kits) and every checker (WorldLanes, zz/lanes, zz/fit) reads.
## Change them here or nowhere. Player capsule: radius 0.3, height 1.8.

const UNIT := 0.5                 ## base grid; every kit dimension is a multiple
const WALL_RUN := 4.0             ## wall panel length
const STOREY := 3.0               ## floor-to-floor
const FLOOR_THICK := 0.3
const DOOR := Vector2(1.6, 2.6)   ## single door (width, height)
const DOOR_DOUBLE := Vector2(2.6, 3.4)
const WALKWAY_MIN := 1.6          ## narrowest walkway: two capsule widths + margin
const HEADROOM := 2.2
const RISER := 0.27               ## stair risers (step-up handles <= 0.45)
const TREAD := 0.72
const STEP_MAX := 0.45            ## player auto step-up
const SLOPE_MAX_DEG := 38.0       ## walkable ground
const FOUNDATION_BURY := 0.6      ## plinths go this far below the lowest ground
const CONTACT := 0.04             ## ground sits this far under a structure's underside


## Steps for a flight of `rise` metres: risers as close to RISER as possible.
static func steps_for(rise: float) -> int:
	return maxi(1, roundi(absf(rise) / RISER))


static func snap(v: float) -> float:
	return roundf(v / UNIT) * UNIT

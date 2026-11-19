class_name Groups
extends RefCounted
## Documented node groups. Prefer these over string literals so a typo fails at parse time.

const PLAYER := "player"
const INTERACTABLE := "interactable"
const LIGHT_SOURCE := "light_source"
const SHADE := "shade"
const ENEMY := "enemy"
const SAVEABLE := "saveable"
const CULL_SPAN := "cull_span"
const CULL_SMALL := "cull_small"
const CULL_FOLIAGE := "cull_foliage"
const CULL_SKIP := "cull_skip"
const OCCLUDER_TRUNK := "occluder_trunk"
const WARD_TARGET := "ward_target"    ## an escort walker / defend ward (WardTarget): foes sent at it go for it
const ENEMY_SHOT := "enemy_shot"
const BRAZIER := "brazier"            ## every Brazier (joins in _ready): Travel saves read lit fires from it
const NO_LEDGE := "no_ledge"          ## bodies the wanderer never catches a ledge on (trees: player_traversal._try_grab)
const CAMERA_PASS := "camera_pass"    ## bodies the camera's boom passes through (a great standing stone that dissolves near the lens: RockKit.fade_material)

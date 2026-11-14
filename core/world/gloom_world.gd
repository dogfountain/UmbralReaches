class_name GloomWorld
extends Node
## The world answers the Gloom (docs/PILLARS.md, pillar 1: the dark is the clock). The HUD meter says it in
## three states (under half, half to three quarters, over three quarters; ui/gloom_meter.gd); this node makes
## the night itself say it, with the same three steps and nothing popping:
##   the grade   the night cools, drains of colour and dims; the frame closes in. Fire and lamp light keep
##               their colour, so every kindled flame reads warmer against a grey-blue world (grade.gdshader,
##               `gloom_world`: one uniform, no new pass)
##   the fog     the depth haze draws in and goes cold (Environment fog_depth_end and fog_light_color)
##   the lantern the wanderer's own light shrinks and gutters; past three quarters it stumbles
##   the sound   the small living sounds thin out and a low, beating drone comes in (Ambience.gloom)
## `severity` is the eased state: a slow rate each way (it rises over about three seconds and lifts over about
## five, resting at a fire), through a curve that is faint under half, firm between half and three quarters
## and unmistakable above. Added by Zone.finish_zone_setup.

const RISE := 0.34                    ## severity per second going up
const LIFT := 0.2                     ## and going down: the dark leaves slower than it came
const FOG_END_LOSS := 0.72            ## the share of the depth fog's reach lost at full severity
const FOG_COLD := Color(0.16, 0.2, 0.33)
const LANTERN_E := 1.15               ## the wanderer's lantern at rest (the rig's own number)
const LANTERN_R := 4.7

var level := 0.0                      ## the eased Gloom share, 0..1
var severity := 0.0                   ## what the world shows, 0..1 (see curve)

var _target := 0.0
var _zone: Zone
var _mat: ShaderMaterial
var _env: Environment
var _amb: Ambience
var _fog_end := -1.0
var _fog_col := Color.BLACK
var _lantern: OmniLight3D
var _t := 0.0
var _fog_dirty := true


## The state curve: 0..1 from the Gloom share. About 0.1 at a fifth, 0.44 at 0.6, 0.9 at 0.9, 1 when full.
static func curve(g: float) -> float:
	return 0.28 * smoothstep(0.0, 0.5, g) + 0.45 * smoothstep(0.5, 0.75, g) + 0.27 * smoothstep(0.75, 1.0, g)


func setup(zone: Zone, mat: ShaderMaterial, env: Environment) -> void:
	_zone = zone
	_mat = mat
	_env = env
	process_priority = 100                    # after the rig has set its lantern for the frame
	Events.gloom_changed.connect(func(v: float, m: float) -> void: _target = clampf(v / maxf(m, 1.0), 0.0, 1.0))


func _process(delta: float) -> void:
	_t += delta
	var next := move_toward(level, _target, delta * (RISE if _target > level else LIFT))
	if not is_equal_approx(next, level):
		level = next
		severity = curve(level)
		_fog_dirty = true
		if _mat != null:
			_mat.set_shader_parameter("gloom_world", severity)
	if _fog_dirty:
		_fog_dirty = false
		_fog()
		_ambience()
	if severity > 0.002 or _lantern != null:
		_lantern_guttering()


func _fog() -> void:
	if _env == null or _zone == null:
		return
	if _fog_end < 0.0:
		_fog_end = _env.fog_depth_end
		_fog_col = _env.fog_light_color
	_env.fog_depth_end = lerpf(_fog_end, _fog_end * (1.0 - FOG_END_LOSS), severity)
	_env.fog_light_color = _fog_col.lerp(FOG_COLD, 0.55 * severity)


func _ambience() -> void:
	if _amb == null or not is_instance_valid(_amb):
		var host := _zone.get_node_or_null("Ambience") if _zone != null else null
		_amb = host as Ambience
	if _amb != null:
		_amb.gloom = severity


## Smaller, dimmer, and unsteady: between half and three quarters the flame leans and recovers; above three
## quarters it dips hard and sometimes nearly drowns, then comes back.
func _lantern_guttering() -> void:
	if _lantern == null or not is_instance_valid(_lantern):
		var pl := get_tree().get_first_node_in_group(Groups.PLAYER)
		_lantern = pl.find_child("LanternLight", true, false) as OmniLight3D if pl != null else null
		if _lantern == null:
			return
	var s := severity
	if s <= 0.002:                            # fully lifted: hand the light back to the rig
		_lantern.omni_range = LANTERN_R
		_lantern = null
		return
	var mid := smoothstep(0.3, 0.6, s)
	var hard := smoothstep(0.7, 1.0, s)
	var gutter := 0.5 + 0.5 * sin(_t * 2.3) * sin(_t * 0.71 + 1.3)           # a slow lean
	var dip := smoothstep(0.55, 0.95, sin(_t * 3.1) * sin(_t * 1.07 + 0.4) * 0.5 + 0.5)   # now and then it nearly goes
	var e := LANTERN_E * (1.0 - 0.38 * s) * (1.0 - 0.22 * mid * gutter - 0.5 * hard * dip)
	e *= 1.0 + 0.05 * sin(_t * 13.0) * (0.3 + s)
	_lantern.light_energy = maxf(e, 0.12)
	_lantern.omni_range = LANTERN_R * (1.0 - 0.5 * s) * (1.0 - 0.12 * hard * dip)

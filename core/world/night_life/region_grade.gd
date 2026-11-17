extends Node
## A GRADE THAT KNOWS WHERE IT IS (subtle). The night's colour grade (world/post/grade.gdshader) is one tint for the whole Realm; this
## eases three of its terms (the shadow tint, the mid tint and the saturation) toward a small offset by the biome of the region the
## wanderer stands in (RealmLayout.region_at, twice a second, eased at 0.5 per second so a walk from the heath into the wood is
## a minute-long drift, never a change): the old forest a deeper green-teal shade, the fen a teal-blue and a little paler, ruins cooler and
## stonier, the ash and the foundry warmer and greyer, the crags colder, the glade a touch more alive. The last tenth of the night warms
## the mid tint a little toward the grey before morning. Never brighter: the shadow tint's value is not raised, only its hue.
## Cost: three uniform writes a frame while it is easing, none when it has arrived. Settings.night_life off eases back to the base.
const Reg := preload("res://core/world/night_life/night_registry.gd")

## biome -> [shadow tint, mid tint, saturation]
const BIOME := {
	"oldforest": [Vector3(0.02, 0.055, 0.19), Vector3(0.20, 0.40, 0.92), 1.38],
	"fen": [Vector3(0.02, 0.05, 0.17), Vector3(0.17, 0.40, 0.80), 1.30],
	"ruin": [Vector3(0.04, 0.04, 0.21), Vector3(0.26, 0.32, 0.96), 1.36],
	"ash": [Vector3(0.05, 0.04, 0.17), Vector3(0.34, 0.33, 0.78), 1.24],
	"crag": [Vector3(0.02, 0.04, 0.23), Vector3(0.22, 0.37, 1.0), 1.36],
	"glade": [Vector3(0.02, 0.05, 0.21), Vector3(0.20, 0.40, 1.0), 1.5],
}

var _mat: ShaderMaterial
var _base_shadow := Vector3(0.02, 0.04, 0.22)
var _base_mid := Vector3(0.22, 0.36, 1.0)
var _base_sat := 1.42
var _shadow := Vector3.ZERO
var _mid := Vector3.ZERO
var _sat := 0.0
var _goal_shadow := Vector3.ZERO
var _goal_mid := Vector3.ZERO
var _goal_sat := 0.0
var _tick := 0.0
var _ready_ok := false


func _ready() -> void:
	var rect := get_parent().get_node_or_null("Grade/Rect") as ColorRect
	if rect != null and rect.material is ShaderMaterial:
		_mat = rect.material as ShaderMaterial
		var s: Variant = _mat.get_shader_parameter("shadow_tint")
		var m: Variant = _mat.get_shader_parameter("mid_tint")
		var v: Variant = _mat.get_shader_parameter("saturation")
		_base_shadow = s if s is Vector3 else _base_shadow
		_base_mid = m if m is Vector3 else _base_mid
		_base_sat = float(v) if v is float else _base_sat
	_shadow = _base_shadow
	_mid = _base_mid
	_sat = _base_sat
	_goal_shadow = _base_shadow
	_goal_mid = _base_mid
	_goal_sat = _base_sat
	_ready_ok = _mat != null


func _process(delta: float) -> void:
	if not _ready_ok:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_choose()
	var k := 1.0 - exp(-0.5 * delta)
	var ns := _shadow.lerp(_goal_shadow, k)
	var nm := _mid.lerp(_goal_mid, k)
	var nsat := lerpf(_sat, _goal_sat, k)
	if ns.is_equal_approx(_shadow) and nm.is_equal_approx(_mid) and is_equal_approx(nsat, _sat):
		return
	_shadow = ns
	_mid = nm
	_sat = nsat
	_mat.set_shader_parameter("shadow_tint", _shadow)
	_mat.set_shader_parameter("mid_tint", _mid)
	_mat.set_shader_parameter("saturation", _sat)


func _choose() -> void:
	_goal_shadow = _base_shadow
	_goal_mid = _base_mid
	_goal_sat = _base_sat
	if not Reg.enabled:
		return
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if player == null:
		return
	var r := RealmLayout.region_at(player.global_position.x, player.global_position.z)
	var biome := String(r.get("biome", ""))
	if BIOME.has(biome):
		var row: Array = BIOME[biome]
		_goal_shadow = row[0]
		_goal_mid = row[1]
		_goal_sat = float(row[2])
	# the grey before the morning: the mid tint warms a little
	var dawn := maxf(smoothstep(0.88, 1.0, Reg.clock), smoothstep(0.08, 0.0, Reg.clock))
	_goal_mid = _goal_mid.lerp(Vector3(0.30, 0.38, 0.82), 0.4 * dawn)

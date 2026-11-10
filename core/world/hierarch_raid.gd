extends Node3D
## The Speaking Crown's room, the floor inside the Fallen Hierarch's split skull (RealmLayout RAIDS
## "hierarch"; built by realm_pois_r37_west.gd, BossArena.room points here). The skull itself is the
## statue model; this node is what the fight changes in it:
##   room_begin(boss) / room_reset() / room_won()   BossArena's hooks
##   set_mood(m)         "fall" (phase II) and "sky" (phase III): the crown sheds, dust hangs in the horn
##   rain_stone(at, t)   a block of the crown falls onto `at`, landing as the red fill completes (visual only:
##                       the damage is the boss's BossKit.zone)
## Load by path (no class_name).

const Kit := preload("res://core/world/realm/r37_west_kit.gd")

var mood := ""
var centre := Vector3.ZERO
var radius := 20.0
var _stone_mesh: BoxMesh


## The horn's embers: four low warm lights round the inside of the skull, unshadowed, so its walls read as
## stone against the dark instead of one black mass (the floor's only other light is the fight's own).
func _ready() -> void:
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var l := OmniLight3D.new()
		l.name = "Ember%d" % i
		l.light_color = Color(1.0, 0.56, 0.3)
		l.light_energy = 2.4
		l.omni_range = 22.0
		l.shadow_enabled = false
		add_child(l)
		l.position = Vector3(cos(a), 0.0, sin(a)) * 15.5 + Vector3.UP * 4.5


func room_begin(_boss: Node) -> void:
	mood = "fight"


func room_reset() -> void:
	mood = ""


func room_won() -> void:
	mood = "won"
	for k in 7:
		var a := TAU * float(k) / 7.0
		var at := centre + Vector3(cos(a), 0.0, sin(a)) * radius * 0.7
		Vfx.burst(at + Vector3.UP * 2.0, Color(0.16, 0.14, 0.12, 0.8), {"count": 26, "life": 2.0, "speed": Vector2(0.5, 2.5), "size": 0.7, "gravity": 0.3, "radius": 3.0, "additive": false, "turbulence": true})
	Sfx.play_stream(BossKit.Synth.get_stream("stagger"), centre, 2.0, 0.5)


func set_mood(m: String) -> void:
	mood = m
	var n := 5 if m == "fall" else 8
	for k in n:
		var a := TAU * float(k) / float(n) + 0.3
		var at := centre + Vector3(cos(a), 0.0, sin(a)) * radius * 0.9
		Vfx.burst(at + Vector3.UP * 6.0, Color(0.18, 0.15, 0.12, 0.7), {"count": 20, "life": 1.8, "speed": Vector2(0.5, 2.0), "size": 0.6, "gravity": 0.4, "radius": 2.5, "additive": false, "turbulence": true})


func rain_stone(at: Vector3, delay: float) -> void:
	if _stone_mesh == null:
		_stone_mesh = BoxMesh.new()
		_stone_mesh.size = Vector3(1.6, 1.2, 1.4)
	var mi := MeshInstance3D.new()
	mi.mesh = _stone_mesh
	mi.material_override = Kit.mat("stone")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at + Vector3.UP * 16.0
	mi.rotation = Vector3(randf() * 3.0, randf() * 3.0, randf() * 3.0)
	var id := mi.get_instance_id()
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position:y", at.y + 0.5, maxf(delay, 0.2)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		var m := instance_from_id(id) as Node3D
		if m == null:
			return
		Vfx.burst(at + Vector3.UP * 0.3, Color(0.2, 0.17, 0.14, 0.8), {"count": 16, "life": 1.0, "speed": Vector2(1.0, 3.5), "size": 0.4, "gravity": 0.5, "radius": 1.6, "additive": false, "turbulence": true})
		m.queue_free())

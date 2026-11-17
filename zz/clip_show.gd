extends Node3D
## A boss's authored clips played through in a lit studio, for a movie:
##   godot --path . --write-movie /tmp/x.avi --fixed-fps 30 res://zz/clip_show.tscn -- [--kind=thornwarden]
## Walks, lopes, winds up and strikes, is staggered, howls and dies, with a slow camera. Never writes the save.
const Studio := preload("res://zz/combat_studio.gd")
var kind := "thornwarden"
var cur: Enemy
var cam: Camera3D
var t := 0.0
var step := -1
## [start s, what]
const PLAN := [[0.0, "idle"], [3.0, "walk"], [7.0, "run"], [11.0, "idle"], [12.0, "windup"], [13.4, "strike"], [15.2, "idle"],
	[16.2, "stagger"], [18.4, "howl"], [21.0, "idle"], [22.0, "windup"], [23.0, "strike"], [25.0, "death"], [29.0, "end"]]


func _ready() -> void:
	Travel._busy = true
	get_window().size = Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kind="): kind = a.trim_prefix("--kind=")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.42, 0.6)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.8, 1.0)
	moon.light_energy = 1.1
	moon.rotation = Vector3(-0.9, 0.9, 0)
	moon.shadow_enabled = true
	add_child(moon)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.6, 0.3)
	fire.light_energy = 3.0
	fire.omni_range = 14.0
	fire.position = Vector3(-5, 2.5, -4)
	add_child(fire)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.17, 0.2)
	fm.roughness = 0.95
	pm.material = fm
	floor_mi.mesh = pm
	add_child(floor_mi)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(80, 1, 80)
	cs.shape = bs
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true
	cur = (load(Studio.KINDS[kind]) as GDScript).new() as Enemy
	add_child(cur)
	cur.global_position = Vector3.ZERO
	cur.sleep()
	if cur._hp_bar: cur._hp_bar.visible = false
	for sk: Node in cur.find_children("*", "Skeleton3D", true, false):
		sk.process_mode = Node.PROCESS_MODE_ALWAYS          # asleep (no AI) the skeleton stopped too, and its spring cloth with it


func _process(d: float) -> void:
	t += d
	var h := maxf(cur.hp_bar_y, 1.0)
	var ang := -0.9 + 0.035 * t
	var look := Vector3(0, h * 0.5, 0)
	cam.global_position = look + Vector3(sin(ang), 0.16, -cos(ang)).normalized() * (h * 2.7 + 2.0)      # the whole of a tall boss in frame
	cam.look_at(look)
	while step + 1 < PLAN.size() and t >= float(PLAN[step + 1][0]):
		step += 1
		var what: String = PLAN[step][1]
		match what:
			"windup": cur._rig.call("telegraph", 1.4 if step < 6 else 1.0)
			"strike": cur._rig.call("strike")
			"stagger": cur._rig.call("stagger")
			"howl": cur._rig.call("howl", 2.2)
			"death": cur._rig.call("collapse", false)
			"end":
				get_tree().quit()
				return
	var what2: String = PLAN[maxi(step, 0)][1]
	var v := Vector3.ZERO
	if what2 == "walk": v = -cur.global_basis.z * cur.walk_speed * 0.42
	elif what2 == "run": v = -cur.global_basis.z * cur.walk_speed * 1.1
	cur._rig.animate(v, true, d)

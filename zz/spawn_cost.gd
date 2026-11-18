extends Node3D
## What one foe costs the frame it is built and the frame it is freed (frame pacing, 16 Nov: in play the rares,
## camps and ambushes build a foe near the wanderer and free one far off, 7-45 ms of scripts in one frame).
## Windowed (headless draws nothing, so mesh uploads and first-use pipelines would read zero), no Realm: a floor,
## a light and a camera on the spot. Each kind is built REPS times; per build it prints the script's new(), the
## add_child (its _ready: rig, meshes, collision, bar), the next frame (its first draw) and the free.
##   godot --path . res://zz/spawn_cost.tscn [-- --reps=3 --kinds=wretch,husk]
## Prints "SPAWNCOST <kind> #<n> new .. add .. frame .. free .. ms (nodes n)" and "SPAWNCOST done".
const KINDS := {
	"wretch": "res://core/enemy/wretch.gd", "husk": "res://core/enemy/husk.gd", "crawler": "res://core/enemy/crawler.gd",
	"leaper": "res://core/enemy/leaper.gd", "spitter": "res://core/enemy/spitter.gd", "ossuant": "res://core/enemy/ossuant.gd",
	"bulwark": "res://core/enemy/bulwark.gd", "chanter": "res://core/enemy/chanter.gd", "burrower": "res://core/enemy/burrower.gd",
	"mite": "res://core/enemy/mite.gd", "gaunt": "res://core/enemy/gaunt.gd", "quiller": "res://core/enemy/quiller.gd",
	"tollman": "res://core/enemy/tollman.gd", "pilgrim": "res://core/enemy/pilgrim.gd", "cinder": "res://core/enemy/cinder_caster.gd",
	"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd",
	"anchoress": "res://core/enemy/anchoress.gd", "warden": "res://core/enemy/ascended_warden.gd",
	"hobb": "res://core/life/encounters/elite_hobb.gd", "lisle": "res://core/life/encounters/elite_lisle.gd",
	"briar_hart": "res://core/life/encounters/elite_briar_hart.gd", "old_sunk": "res://core/life/encounters/elite_old_sunk.gd",
	"cinder_cantor": "res://core/life/encounters/elite_cinder_cantor.gd", "root_wife": "res://core/life/encounters/elite_root_wife.gd",
	"siege_captain": "res://core/life/encounters/elite_siege_captain.gd", "brine_wife": "res://core/life/encounters/elite_brine_wife.gd",
}
const Variants := preload("res://core/life/encounters/variants.gd")
var reps := 3
var order: Array = []
var ki := 0
var rep := 0
var step := 0
var e: Node3D
var row := {}
var t_frame := 0
var wait := 30                       ## frames before the first build (window, first pipelines)
var _held: Array[Resource] = []
var gap := 0                         ## --gap=N: frames between a free and the next build (does the warmth last?)
const MODELS := {"thornwarden": "res://art/models/bosses/vb_thornwarden.glb", "bone_abbot": "res://art/models/bosses/vb_bone_abbot.glb",
	"anchoress": "res://art/models/bosses/vb_anchoress.glb", "warden": "res://art/models/bosses/vb_ascended_warden.glb"}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--reps="):
			reps = int(a.trim_prefix("--reps="))
		elif a == "--hold":                          # the boss models held (as a scene cache would)
			for k: String in MODELS:
				_held.append(load(MODELS[k]))
		elif a.begins_with("--gap="):
			gap = int(a.trim_prefix("--gap="))
		elif a.begins_with("--kinds="):
			order = Array(a.trim_prefix("--kinds=").split(","))
	if order.is_empty():
		order = KINDS.keys()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = Vector2i(1280, 800)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mi.mesh = pm
	add_child(floor_mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	body.collision_layer = Layers.WORLD
	add_child(body)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.2, 7.0)
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.0, 0.0))
	cam.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	add_child(env)


func _process(_d: float) -> void:
	if wait > 0:
		wait -= 1
		return
	if ki >= order.size():
		print("SPAWNCOST done")
		get_tree().quit()
		set_process(false)
		return
	var kind := String(order[ki]).get_slice(":", 0)
	var look := String(order[ki]).get_slice(":", 1) if ":" in String(order[ki]) else ""       ## wretch:drowned = a variant look
	match step:
		0:                                           # build
			var sc := load(KINDS[kind]) as GDScript
			var cached := "model %s" % ("cached" if ResourceLoader.has_cached(MODELS[kind]) else "not cached") if MODELS.has(kind) else ""
			var t0 := Time.get_ticks_usec()
			e = sc.new() as Node3D
			if look != "":
				Variants.pre(e, look)
			var t1 := Time.get_ticks_usec()
			add_child(e)
			if look != "":
				Variants.dress(e, look)
			e.global_position = Vector3(0.0, 0.05, 0.0)
			var t2 := Time.get_ticks_usec()
			row = {"new": (t1 - t0) / 1000.0, "add": (t2 - t1) / 1000.0, "nodes": e.find_children("*", "", true, false).size() + 1, "cached": cached}
			t_frame = Time.get_ticks_usec()
			step = 1
		1:                                           # the frame after: its first draw and first process
			row.frame = (Time.get_ticks_usec() - t_frame) / 1000.0
			step = 2
		2, 3, 4, 5, 6, 7, 8, 9:                      # a few ordinary frames for comparison
			if step == 2:
				t_frame = Time.get_ticks_usec()
			step += 1
		10:
			row.steady = (Time.get_ticks_usec() - t_frame) / 1000.0 / 8.0
			var t0 := Time.get_ticks_usec()
			remove_child(e)
			e.free()
			row.free = (Time.get_ticks_usec() - t0) / 1000.0
			t_frame = Time.get_ticks_usec()
			step = 11
		11:
			row.after = (Time.get_ticks_usec() - t_frame) / 1000.0
			print("SPAWNCOST %-12s #%d new %6.2f  add %6.2f  frame %6.2f (steady %5.2f)  free %6.2f  after %6.2f ms  (nodes %d) %s" % [
				String(order[ki]), rep + 1, row.new, row.add, row.frame, row.steady, row.free, row.after, row.nodes, row.cached])
			rep += 1
			step = 0
			wait = gap
			if rep >= reps:
				rep = 0
				ki += 1

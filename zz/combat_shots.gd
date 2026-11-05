extends Node
## In-game combat frames through the real player camera (grade, fog, moonlight): the world loads,
## the player is put on open ground, the camps are cleared, and a scripted fight is spawned.
##   godot --path . res://zz/combat_shots.tscn -- --at=x,z [--yaw=deg] [--set=pack|boss_thorn|boss_abbot|boss_warden] [--name=n]
## Frames at fixed times after the fight starts -> shots/combat/ig_<name>_<i>.png
const SETS := {
	"pack": [["wretch", 5.5, -20.0], ["husk", 6.5, 15.0], ["crawler", 4.5, 40.0], ["spitter", 9.0, -45.0], ["wretch", 6.0, 60.0]],
	"crawler": [["crawler", 6.0, 0.0]],
	"boss_thorn": [["thornwarden", 9.0, 0.0]],
	"boss_abbot": [["bone_abbot", 7.0, 0.0]],
	"boss_warden": [["ascended_warden", 9.0, 0.0]],
	"warband": [["bulwark", 5.5, 0.0], ["chanter", 10.0, 8.0], ["wretch", 6.0, -50.0], ["wretch", 6.0, 55.0], ["mite", 4.5, 25.0], ["mite", 4.8, 30.0], ["mite", 4.2, 35.0]],
	"burrow": [["burrower", 9.0, 0.0], ["burrower", 10.0, 30.0]],
	# r31 (docs/enshrouded/enemies.md)
	"r31": [["gaunt", 7.0, -35.0], ["quiller", 11.0, 10.0], ["tollman", 9.0, 30.0], ["husk", 5.0, -5.0], ["gaunt", 7.5, 50.0]],
	"brood": [["brood_mother", 8.0, 0.0]],
}
const SCRIPTS := {
	"wretch": "res://core/enemy/wretch.gd", "husk": "res://core/enemy/husk.gd", "spitter": "res://core/enemy/spitter.gd",
	"crawler": "res://core/enemy/crawler.gd", "leaper": "res://core/enemy/leaper.gd", "ossuant": "res://core/enemy/ossuant.gd",
	"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd", "ascended_warden": "res://core/enemy/ascended_warden.gd",
	"bulwark": "res://core/enemy/bulwark.gd", "chanter": "res://core/enemy/chanter.gd", "burrower": "res://core/enemy/burrower.gd", "mite": "res://core/enemy/mite.gd",
	"gaunt": "res://core/enemy/gaunt.gd", "quiller": "res://core/enemy/quiller.gd", "tollman": "res://core/enemy/tollman.gd",
	"brood_mother": "res://core/enemy/brood_mother.gd",
}
var at := Vector2(58.0, 18.0)
var yaw := 0.0
var set_name := "pack"
var nm := ""
var times: Array[float] = [0.6, 1.6, 2.4, 3.2, 4.0, 5.2]
var p: Player
var t := -1.0
var ti := 0
var frames := 0
var main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.split("=")
		if v.size() < 2: continue
		match v[0]:
			"--at": at = Vector2(float(v[1].split(",")[0]), float(v[1].split(",")[1]))
			"--yaw": yaw = deg_to_rad(float(v[1]))
			"--set": set_name = v[1]
			"--name": nm = v[1]
			"--times":
				times.clear()
				for x in v[1].split(","): times.append(float(x))
	if nm == "": nm = set_name
	Travel._busy = true                                 # no save writes from this tool (as perf_tour)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/combat"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	frames += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	p.gloom = 0.0; p.wounds = 0.0
	if t < 0.0:
		if frames < 90 or not main.has_meta("summit_dressed"):
			return
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 90, at.y), Vector3(at.x, -40, at.y), Layers.WORLD)
		var h := p.get_world_3d().direct_space_state.intersect_ray(q)
		var ground: Vector3 = h.position if h else Vector3(at.x, 2.0, at.y)
		p.global_position = ground + Vector3.UP * 0.3
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.set_view(yaw, -0.12)
		for e in get_tree().get_nodes_in_group(Groups.ENEMY): (e as Node).queue_free()
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if c.name != "Grade": (c as CanvasLayer).visible = false
		var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		for row: Array in SETS[set_name]:
			var dir := fwd.rotated(Vector3.UP, deg_to_rad(float(row[2])))
			var spot := ground + dir * float(row[1])
			var hq := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 20.0, spot + Vector3.DOWN * 20.0, Layers.WORLD))
			if hq: spot = hq.position
			var e := (load(SCRIPTS[row[0]]) as GDScript).new() as Enemy
			main.add_child(e)
			e.global_position = spot + Vector3.UP * 0.1
			e.home = e.global_position
			if e.has_method("on_engaged"): e.call("on_engaged", p)
			e.wake()
		t = 0.0
		print("SHOTS fight at ", ground)
		return
	t += 1.0 / 60.0
	if ti < times.size() and t >= times[ti]:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/combat/ig_%s_%d.png" % [nm, ti]))
		ti += 1
	if ti >= times.size():
		print("SHOTS saved ", nm, " ", ti)
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		OS.kill(OS.get_process_id())

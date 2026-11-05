extends Node
## Where the mist banks are and how dense (critique D, r29), headless; quits by itself.
##   godot --headless --path . res://zz/critD_mist_probe.tscn
var main: Node
var done := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if Time.get_ticks_msec() > 150000:
		get_tree().quit(1)
	if done or main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null:
		return
	done = true
	var wx: Node = main.get_node("Wildlife").get_meta("weather")
	wx.force("mist", true)
	for i in 5:
		await get_tree().process_frame
	var env := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	print("MIST vol_fog ", env.volumetric_fog_enabled, " len ", env.volumetric_fog_length, " dens ", env.volumetric_fog_density)
	for b: Dictionary in wx.get("_banks"):
		var fv := b.node as FogVolume
		print("MIST bank %s at %s size %s dens %.3f visible %s" % [fv.name, fv.global_position.snapped(Vector3.ONE * 0.1), fv.size, (b.mat as FogMaterial).density, fv.visible])
	get_tree().quit(0)

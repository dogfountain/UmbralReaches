extends Node
## Which open spots are free of sanctuary light (LightGrid.repel) out to 16 m? (trailer arena pick)
var main: Node
func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(2.0).timeout
	for c: Vector2 in [Vector2(8, 48), Vector2(-22, 44), Vector2(0, 64), Vector2(-24, 58), Vector2(22, 58), Vector2(-30, 62), Vector2(-30, 14), Vector2(30, 40), Vector2(-40, 30)]:
		var lit := 0
		var n := 0
		for r in [0.0, 4.0, 8.0, 12.0, 16.0]:
			for k in 8:
				var a := TAU * float(k) / 8.0
				var pnt := Vector3(c.x + cos(a) * r, 0.0, c.y + sin(a) * r)
				n += 1
				if LightGrid.repel(pnt, 1.0) != Vector3.ZERO:
					lit += 1
		print("ARENA %s lit %d/%d" % [c, lit, n])
	get_tree().quit()

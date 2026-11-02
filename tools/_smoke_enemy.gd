extends SceneTree


func _initialize() -> void:
	var enemy: GDScript = load("res://core/enemy/enemy.gd")
	var wretch: GDScript = load("res://core/enemy/wretch.gd")
	var spawn: GDScript = load("res://core/enemy/enemy_spawner.gd")
	if enemy == null or wretch == null or spawn == null:
		push_error("SMOKE enemy scripts missing")
		quit(1)
		return
	if not load("res://core/enemy/health_bar.gdshader") is Shader:
		push_error("SMOKE health bar shader missing")
		quit(1)
		return
	var crawler_s: GDScript = load("res://core/enemy/crawler.gd")
	var leaper_s: GDScript = load("res://core/enemy/leaper.gd")
	if crawler_s == null or leaper_s == null:
		push_error("SMOKE crawler/leaper missing")
		quit(1)
		return
	var w: Object = wretch.new()
	if not w.has_method("take_hit"):
		push_error("SMOKE wretch missing take_hit")
		quit(1)
		return
	# Three hit points, one point per bolt: two hits must leave exactly one third.
	w.take_hit(1.0)
	w.take_hit(1.0)
	if not is_equal_approx(w.hp, 1.0):
		push_error("SMOKE wretch hp after two hits = %s, want 1.0" % w.hp)
		quit(1)
		return
	w.free()
	print("SMOKE enemy ok")
	quit(0)

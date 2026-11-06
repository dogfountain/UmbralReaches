extends Node
## Dumps the Realm's sites, raids and village nav once built (a working probe for the site dressing).
var main: Node
var t := 0.0


func _ready() -> void:
	Travel.set("_busy", true)
	get_window().size = Vector2i(800, 500)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if t > 100.0:
		OS.kill(OS.get_process_id())
	if main != null and main.has_meta("realm_done") and t > 3.0:
		var sp := (main as Node3D).get_world_3d().direct_space_state
		for s: Dictionary in WorldLanes.sites:
			var r: Rect2 = s.rect
			print("SITE %s rect=(%.0f,%.0f %.0fx%.0f) y=%.1f%s%s%s" % [s.name, r.position.x, r.position.y, r.size.x, r.size.y, float(s.floor_y),
				" circle" if s.has("circle") else "", " seg" if s.has("seg") else "", " hard" if s.get("hard", false) else ""])
		for p: Dictionary in WorldLanes.portals:
			print("PORTAL %s at=%s" % [p.name, p.at])
		var v := main.get_node_or_null("Village")
		if v:
			var nav: RefCounted = v.get("nav")
			print("NAV nodes=%d" % (nav.get("nodes") as Dictionary).size())
			for id: String in nav.get("nodes"):
				var q: Vector3 = nav.get("nodes")[id]
				print("NAVN %s %.1f %.1f %.1f" % [id, q.x, q.y, q.z])
			print("OUTPOST ", v.get("outpost_at"))
		for pt: Vector2 in [Vector2(0, 33), Vector2(-205, 66), Vector2(212, 92), Vector2(-208, 70)]:
			print("GROUND %s %.2f" % [pt, RealmLayout.ground(sp, pt.x, pt.y)])
		for k: Variant in RealmLayout.RAIDS:
			print("RAID ", k)
		for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
			print("BRAZIER %s %s" % [n.name, (n as Node3D).global_position])
		var Z := load("res://core/world/realm/dress_zones.gd") as GDScript
		for b: Array in Z.call("breaches"):
			var bp: Vector2 = b[0]
			print("BREACH %s y=%.2f  east=%.2f west=%.2f" % [bp, RealmLayout.ground(sp, bp.x, bp.y), RealmLayout.ground(sp, bp.x + 10.0, bp.y), RealmLayout.ground(sp, bp.x - 10.0, bp.y)])
		for rd: Dictionary in RealmLayout.RAIDS:
			var c: Vector2 = rd.c
			for a in 4:
				var q := c + Vector2.from_angle(a * PI * 0.5) * (float(rd.r) - 3.0)
				print("RAIDEDGE %s a=%d %s y=%.2f" % [rd.id, a, q, RealmLayout.ground(sp, q.x, q.y)])
		var host := main.get_node_or_null("SiteDress")
		if host:
			for z in host.get_children():
				print("DRESS ", z.name, " ", (z as Node3D).position, " kinds=", z.get_child_count())
		OS.kill(OS.get_process_id())

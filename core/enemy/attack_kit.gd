extends RefCounted
## Telegraphed area moves for ordinary enemies (bosses use BossKit.zone). The difference: a move
## here belongs to the enemy that made it. If that enemy is staggered, riposted or killed before
## the fill completes, the zone is cancelled with it (the red fades, nothing lands), so breaking a
## tell is a real answer. A Rift Step through a landing zone is a riposte, like a dodged strike.
## Load by path (no class_name):  const AttackKit := preload("res://core/enemy/attack_kit.gd")
##   zone(e, at, delay, gloom, opts)   SpellFx.danger opts ("radius", "half_angle", "rect", "yaw",
##                                      "color") plus "spikes" ("bone" | "thorn"), "h" (reach above
##                                      the zone), "bound" (false: lands even if the maker is
##                                      interrupted), "release" (bound only this many seconds: a
##                                      glob once thrown), "on_land" (Callable), "fx" (land style:
##                                      "blast" | "slam" | "sigil" | "acid" | "dirt")
##   linger(host, at, r, life, gloom, every, col)   a pool that hurts while you stand in it
##   lob(host, from, to, time, col)     a glob thrown on a visible arc (visual only)

const Synth := preload("res://core/vfx/synth.gd")
const RED := Color(2.6, 0.55, 0.1)          ## SpellFx.DANGER_RED: a red the night grade keeps
const ACID := Color(0.3, 1.6, 1.1)
const UMBRAL := Color(1.5, 0.5, 2.8)
const GLOAM := Color(0.75, 1.9, 0.45)          ## the Chanter's corpse-light (violet is the player's)

static var _glob_mesh: SphereMesh
static var _glob_tints := {}                    ## r34: colour (html) -> SphereMesh, for globs that are not acid


static func zone(e: Enemy, at: Vector3, delay: float, gloom: float, opts := {}) -> MeshInstance3D:
	if e == null or not e.is_inside_tree():
		return null
	var col: Color = opts.get("color", RED)
	var o := opts.duplicate()
	o["color"] = col
	o.erase("parent")
	o.erase("on_land")
	var mi := SpellFx.danger(at, delay, o)
	if mi == null:
		return null
	# bound for `release` seconds (default: until it lands): cancel_moves() frees the mesh, and a
	# freed mesh at landing time means the move was broken
	var release: float = delay if bool(opts.get("bound", true)) else 0.0
	release = minf(float(opts.get("release", release)), delay)
	var tree := e.get_tree()
	# timers hold ids, not the nodes: either may be freed before they fire
	var eid := e.get_instance_id()
	var mid := mi.get_instance_id()
	if release > 0.0:
		e.track_move(mi)
		if release < delay:
			tree.create_timer(release, false).timeout.connect(func() -> void:
				var en := instance_from_id(eid) as Enemy
				var m := instance_from_id(mid) as MeshInstance3D
				if en != null and m != null:
					en.untrack_move(m))
	var on_land: Callable = opts.get("on_land", Callable())
	tree.create_timer(delay, false).timeout.connect(func() -> void:
		if instance_from_id(mid) == null:
			return
		var e2 := instance_from_id(eid) as Enemy
		_land(at, opts, col)
		if on_land.is_valid():
			on_land.call()
		var p := tree.get_first_node_in_group(Groups.PLAYER) as Player
		if p and BossKit.inside(p.global_position, at, opts):
			if p.is_evading():
				if e2 != null and e2.is_alive():
					p.on_evaded(e2)
				else:
					HitText.pop(p.global_position + Vector3.UP * 2.0, "evaded", Color(0.6, 0.75, 1.0))
			else:
				p.take_wound(gloom, at)
				Vfx.burst(p.global_position + Vector3.UP * 1.1, Color(0.9, 0.12, 0.1), {"count": 12, "life": 0.3, "speed": Vector2(2.0, 4.0), "size": 0.04, "gravity": -4.0, "trail": 0.06}))
	return mi


static func _land(at: Vector3, opts: Dictionary, col: Color) -> void:
	var r: float = opts.get("radius", 1.0)
	var rect: Vector2 = opts.get("rect", Vector2.ZERO)
	var yaw: float = opts.get("yaw", 0.0)
	var b := Basis(Vector3.UP, yaw)
	var centre := at + (b * Vector3(0, 0, -rect.y) if rect != Vector2.ZERO else Vector3.ZERO)
	var span := maxf(r, rect.length())
	var fx: String = opts.get("fx", "blast")
	var spikes: String = opts.get("spikes", "")
	if spikes != "":
		var host := Vfx.host()
		if host is Node3D:
			BossKit.spikes(host, at, opts, spikes)
		Sfx.play_stream(Synth.get_stream("spike"), centre + Vector3.UP, -3.0, 1.15)
	match fx:
		"slam":
			Sfx.play_stream(Synth.get_stream("stagger"), centre, 0.0, 0.75)
			Vfx.burst(centre + Vector3.UP * 0.15, Color(0.16, 0.12, 0.1, 0.9), {"count": 26, "life": 0.8, "speed": Vector2(1.5, 4.0), "size": 0.18, "gravity": -5.0, "additive": false, "radius": span * 0.6})
			Vfx.ring(centre + Vector3.UP * 0.1, span, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6), 0.3, 0.12, Vector3.UP, 1.0)
		"sigil":
			Sfx.play_stream(Synth.get_stream("spike"), centre + Vector3.UP, -6.0, 1.5)
			Vfx.burst(centre + Vector3.UP * 0.3, col, {"count": 34, "life": 0.6, "speed": Vector2(1.5, 5.0), "size": 0.05, "gravity": 2.0, "ring": span, "trail": 0.08})
			SpellFx.column(centre, span * 0.7, 2.6, 0.4)
		"acid":
			Sfx.play("res://art/audio/spit.wav", centre, -2.0, 0.7)
			Vfx.burst(centre + Vector3.UP * 0.2, col, {"count": 28, "life": 0.5, "speed": Vector2(1.0, 3.5), "size": 0.06, "gravity": -7.0, "ring": span * 0.6})
		"dirt":
			Sfx.play_stream(Synth.get_stream("burrow"), centre, 0.0, 1.2)
			Vfx.burst(centre + Vector3.UP * 0.2, Color(0.2, 0.15, 0.11, 0.95), {"count": 40, "life": 0.9, "speed": Vector2(2.5, 6.5), "size": 0.12, "gravity": -11.0, "additive": false, "radius": span * 0.5})
		_:
			Sfx.play_stream(Synth.get_stream("stagger"), centre, -2.0, 0.9)
			Vfx.burst(centre + Vector3.UP * 0.3, col, {"count": 24, "life": 0.45, "speed": Vector2(2.0, 5.0), "size": 0.05, "gravity": -6.0, "ring": span * 0.8})
	Vfx.light(centre + Vector3.UP, Color(col.r * 0.3, col.g * 0.3, col.b * 0.3), 2.2, span + 2.0, 0.25)


## A pool that stays: the full zone shows for `life` seconds and fills `gloom` every `every`
## seconds you stand in it (not while Rift-Stepping). Spitter acid, the Abbot's grave-fire.
static func linger(at: Vector3, r: float, life: float, gloom: float, every: float, col: Color) -> MeshInstance3D:
	var mi := SpellFx.danger(at, 0.05, {"radius": r, "color": col, "hold": life})
	if mi == null:
		return null
	var tw := mi.create_tween()
	var n := int(life / every)
	if n <= 0:
		tw.tween_interval(life)                  # shorter than a tick (the loading warm-up's show pool): no empty tween
	for i in n:
		tw.tween_interval(every)
		tw.tween_callback(func() -> void:
			var tree := Engine.get_main_loop() as SceneTree
			var p := tree.get_first_node_in_group(Groups.PLAYER) as Player if tree else null
			if p == null or p.is_evading():
				return
			if BossKit.inside(p.global_position, at, {"radius": r, "h": 1.2}):
				p.take_wound(gloom, at))
	return mi


## A glob on a visible arc from `from` to `to` over `time` (the landing disc is the zone's job).
static func lob(from: Vector3, to: Vector3, time: float, col: Color) -> void:
	var host := Vfx.host()
	if host == null:
		return
	if _glob_mesh == null:
		_glob_mesh = SphereMesh.new()
		_glob_mesh.radius = 0.16
		_glob_mesh.height = 0.3
		_glob_mesh.radial_segments = 10
		_glob_mesh.rings = 5
		_glob_mesh.material = ProcMesh.glow_mat(ACID)
	var mi := MeshInstance3D.new()
	mi.mesh = _glob_mesh
	if not col.is_equal_approx(ACID):
		var k := col.to_html()
		if not _glob_tints.has(k):
			var gm := _glob_mesh.duplicate() as SphereMesh
			gm.material = ProcMesh.glow_mat(col)
			_glob_tints[k] = gm
		mi.mesh = _glob_tints[k]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = from
	var apex := maxf(from.y, to.y) + 1.6 + from.distance_to(to) * 0.12
	var tw := mi.create_tween()
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(mi):
			return
		var p := from.lerp(to, k)
		# a parabola through from, apex and to
		var h := lerpf(from.y, to.y, k) + (apex - maxf(from.y, to.y)) * 4.0 * k * (1.0 - k)
		mi.global_position = Vector3(p.x, h, p.z)
		mi.rotation.y = k * 9.0, 0.0, 1.0, maxf(time, 0.1))
	tw.tween_callback(mi.queue_free)
	Vfx.burst(from, col, {"count": 10, "life": 0.3, "speed": Vector2(1.0, 2.5), "size": 0.05, "gravity": -6.0})

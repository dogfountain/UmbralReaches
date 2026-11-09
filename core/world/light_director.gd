extends Node
## Every light in the night, governed in one place (Luke, 9 Nov: "do we have a fully globalised lighting system").
## LightPolicy holds the rules (class, distance fade, fog energy, who may cast, the brightness table); this node makes
## sure every light gets them, including the ~17 builders that never called it (bosses, rares, events, seals, mirrors,
## the watch, the grapple anchor) and anything spawned after the Realm's build.
##   1 GOVERN: a Light3D entering the world is classified at the end of its frame (builders set their metas just after
##     add_child). A light with no distance fade gets its class's fade, shadows follow the class policy (only the moon
##     and the hero window spots may cast, plus the one fire below), and a light a builder already put through the
##     table is left as tuned. A light with no `base` keeps its authored energy: governing never re-brightens.
##   2 BUDGET: of the local lights (lamps, window shafts, fills, glimmers, braziers, the Realm's own), only the nearest
##     BUDGET[detail] stay lit. The rest fade out through their own distance fade (its start eased in over ~0.4 s, so
##     nothing pops) and, once fully faded, the renderer skips them. Braziers count as nearer than they are (they are
##     the gameplay lights). Four lights on every window of a village (a Cursor pass, 9 Nov) can't happen again.
##   3 FIRE SHADOW: on high shadows and high detail, the nearest lit brazier within FIRE_SHADOW_R casts a shadow
##     (one dual-paraboloid map at most), its opacity eased in and out as the nearest one changes.
## Attached by world/main.gd. Load by path (no class_name). `--no-light-director` to A/B.

const BUDGET := [14, 24, 36]                ## local lights kept lit, by Settings.detail
const BUDGETED := [&"lamp", &"shaft", &"fill", &"hero_fill", &"glimmer", &"beacon", &"realm", &"river"]
const PRIORITY := {&"beacon": 0.6, &"shaft": 0.9, &"lamp": 1.0, &"hero_fill": 1.0, &"realm": 1.0, &"fill": 1.15,
	&"glimmer": 1.2, &"river": 1.3}          ## distance multipliers: lower = kept first
const EASE := 60.0                          ## m/s the fade start of a light being cut (or restored) moves
const TICK := 0.2                           ## s between budget passes
const FIRE_SHADOW_R := 14.0                 ## m: the nearest lit brazier this close casts
const FIRE_SHADOW_IN := 2.5                 ## shadow opacity per second (in and out)

var _lights: Array[Light3D] = []            ## budgeted lights
var _t := 0.0
var _fire: Light3D = null
var _stats := Vector3i.ZERO                 ## governed, budgeted in range, cut
var _no_fire := "--no-fire-shadow" in OS.get_cmdline_user_args()   ## A/B


static func attach(root: Node) -> void:
	if root.has_meta(&"light_director") or "--no-light-director" in OS.get_cmdline_user_args():
		return
	root.set_meta(&"light_director", true)
	var d := (load("res://core/world/light_director.gd") as GDScript).new() as Node
	d.name = "LightDirector"
	root.add_child(d)


func _ready() -> void:
	get_tree().node_added.connect(_on_added)
	for n in get_tree().root.find_children("*", "Light3D", true, false):
		_on_added(n)


func _on_added(n: Node) -> void:
	if n is Light3D and not (n is DirectionalLight3D):
		_govern_later.call_deferred(weakref(n))


func _govern_later(w: WeakRef) -> void:
	var l := w.get_ref() as Light3D
	if l == null or not l.is_inside_tree() or l.has_meta(&"ld_gov"):
		return
	l.set_meta(&"ld_gov", true)
	_stats.x += 1
	var kind := LightPolicy.classify(l)
	if kind == &"player_lantern" or kind == &"player_orb" or kind == &"moon":
		return                                   # the wanderer's own lights: LightPolicy set them; never cut
	if not l.distance_fade_enabled:
		LightPolicy.apply_fade(l)               # (an authored fade stays as it is)
	if not (kind == &"hero" and l.shadow_enabled):
		LightPolicy.apply_shadows(l)            # one shadow policy for every light
	if kind in BUDGETED and not _under_enemy(l):
		l.set_meta(&"ld_begin", l.distance_fade_begin)
		_lights.append(l)


## A boss's or a foe's own light (its telegraph, its lantern) is part of the fight: never budgeted.
static func _under_enemy(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p.is_in_group(Groups.ENEMY):
			return true
		p = p.get_parent()
	return false


func _process(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	_t -= dt
	if _t <= 0.0:
		_t = TICK
		_budget(at)
	_ease(at, dt)
	_fire_shadow(at, dt)


## Rank the lights in reach; mark the nearest BUDGET kept and the rest cut.
func _budget(at: Vector3) -> void:
	var cand: Array = []
	var i := 0
	while i < _lights.size():
		var l := _lights[i]
		if not is_instance_valid(l) or not l.is_inside_tree():
			_lights.remove_at(i)
			continue
		i += 1
		var reach := float(l.get_meta(&"ld_begin")) + l.distance_fade_length
		var d := at.distance_to(l.global_position)
		if not l.visible or d > reach + 2.0:
			l.set_meta(&"ld_cut", false)         # out of its own reach: nothing to decide
			continue
		cand.append([d * float(PRIORITY.get(l.get_meta(&"light_class"), 1.0)), l])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var keep: int = BUDGET[clampi(Settings.detail, 0, 2)]
	var cut := 0
	for k in cand.size():
		var l: Light3D = cand[k][1]
		var c := k >= keep
		l.set_meta(&"ld_cut", c)
		cut += 1 if c else 0
	_stats.y = cand.size()
	_stats.z = cut


## Move each light's fade start toward its target: its own (kept) or just inside the camera (cut), EASE m/s.
func _ease(at: Vector3, dt: float) -> void:
	for l in _lights:
		if not is_instance_valid(l):
			continue
		var own := float(l.get_meta(&"ld_begin"))
		var want := own
		if bool(l.get_meta(&"ld_cut", false)):
			want = maxf(0.0, at.distance_to(l.global_position) - l.distance_fade_length - 1.0)
		var cur := l.distance_fade_begin
		if absf(cur - want) > 0.01:
			l.distance_fade_begin = move_toward(cur, want, EASE * dt)


## The nearest lit brazier on high settings casts; the last one's shadow eases out.
func _fire_shadow(at: Vector3, dt: float) -> void:
	var on := Settings.shadow_quality > 1 and Settings.detail >= 2 and not _no_fire

	var best: Light3D = null
	if on:
		var bd := FIRE_SHADOW_R
		for l in _lights:
			if is_instance_valid(l) and l.visible and l.get_meta(&"light_class") == &"beacon" and not bool(l.get_meta(&"ld_cut", false)):
				var d := at.distance_to(l.global_position)
				if d < bd:
					bd = d
					best = l
	if best != _fire and _fire != null and is_instance_valid(_fire):
		_fire.shadow_opacity = move_toward(_fire.shadow_opacity, 0.0, FIRE_SHADOW_IN * dt)
		if _fire.shadow_opacity <= 0.0:
			_fire.shadow_enabled = false
			_fire = null
		return
	if best == null:
		return
	if _fire != best:
		_fire = best
		_fire.shadow_opacity = 0.0
		if _fire is OmniLight3D:
			(_fire as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		_fire.shadow_caster_mask = LightPolicy.FIRE_CASTERS    # no undergrowth in the fire's map (same look, far fewer draws)
		_fire.shadow_bias = 0.08
		_fire.shadow_normal_bias = 1.5
		_fire.distance_fade_shadow = FIRE_SHADOW_R
	_fire.shadow_enabled = true
	_fire.shadow_opacity = move_toward(_fire.shadow_opacity, 0.85, FIRE_SHADOW_IN * dt)


## (governed, local lights in reach, cut by the budget): perf_watch --fps-log prints it.
func stats() -> Vector3i:
	return Vector3i(_stats.x, _stats.y, _stats.z + (1000 if _fire != null and _fire.shadow_enabled else 0))

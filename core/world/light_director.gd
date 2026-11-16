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
##   3 FIRE SHADOW: on high shadows (any detail), the nearest fire (a lit brazier, a camp, outpost or hearth fire)
##     within FIRE_SHADOW_R casts a shadow
##     (one dual-paraboloid map at most), its opacity eased in and out as the nearest one changes.
## Attached by world/main.gd. Load by path (no class_name). `--no-light-director` to A/B.

const BUDGET := [14, 24, 36]                ## local lights kept lit, by Settings.detail
const BUDGETED := [&"lamp", &"shaft", &"fill", &"hero_fill", &"glimmer", &"beacon", &"realm", &"river"]
const PRIORITY := {&"beacon": 0.6, &"shaft": 0.9, &"lamp": 1.0, &"hero_fill": 1.0, &"realm": 1.0, &"fill": 1.15,
	&"glimmer": 1.2, &"river": 1.3}          ## distance multipliers: lower = kept first
const EASE := 60.0                          ## m/s the fade start of a light being cut (or restored) moves
const TICK := 0.2                           ## s between budget passes
const SLICES := 6                           ## frames a pass is spread over (~500 lights in one frame was a 0.4-0.6 ms spike)
const FIRE_SHADOW_R := 14.0                 ## m: the nearest lit brazier this close casts
const FIRE_SHADOW_IN := 2.5                 ## shadow opacity per second (in and out)

var _lights: Array[Light3D] = []            ## budgeted lights
var _own := {}                              ## light -> its own fade start (what a kept light eases back to)
var _prio := {}                             ## light -> PRIORITY multiplier
var _cut := {}                              ## light -> true while the budget cuts it
var _moving := {}                           ## light -> true while its fade start is easing (only these are touched a frame)
var _best: Light3D = null                   ## the nearest lit brazier in reach (the budget pass finds it)
var _t := 0.0
var _sweep := -1                            ## the next light the pass under way looks at (-1: none)
var _cand: Array = []                       ## the pass's lights in reach so far: [distance x priority, light, distance]
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
		_own[l] = l.distance_fade_begin
		_prio[l] = float(PRIORITY.get(kind, 1.0))
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
	if _t <= 0.0 and _sweep < 0:
		_t = TICK
		_sweep = 0
		_cand.clear()
	if _sweep >= 0:
		_budget(at)
	if not _moving.is_empty():
		_ease(at, dt)
	if _fire != null or _best != null:
		_fire_shadow(dt)


## Rank the lights in reach; mark the nearest BUDGET kept and the rest cut; find the nearest lit brazier.
## (Every 0.2 s: the per-frame work is only the lights still easing, Luke's PC being bound by the CPU.) A pass
## measures its lights over SLICES frames, then ranks and cuts them all at once on its last.
func _budget(at: Vector3) -> void:
	var i := _sweep
	var stop := i + ceili(float(_lights.size()) / float(SLICES))
	while i < _lights.size() and i < stop:
		var lv: Variant = _lights[i]             # (untyped: a freed light may not be assigned to a Light3D)
		if not is_instance_valid(lv) or not (lv as Light3D).is_inside_tree():
			_lights.remove_at(i)
			_own.erase(lv)
			_prio.erase(lv)
			_cut.erase(lv)
			_moving.erase(lv)
			continue
		var l := lv as Light3D
		i += 1
		var d := at.distance_to(l.global_position)
		if not l.visible or d > float(_own[l]) + l.distance_fade_length + 2.0:
			_set_cut(l, false)                       # out of its own reach: nothing to decide
			continue
		_cand.append([d * float(_prio[l]), l, d])
	_sweep = i
	if i < _lights.size():
		return
	_sweep = -1
	var cand: Array = []
	for c: Array in _cand:
		if is_instance_valid(c[1]):                 # (freed since it was measured)
			cand.append(c)
	_cand.clear()
	var fire_on := Settings.shadow_quality > 1 and not _no_fire   # (shadows High at any detail: one map, ~0.1 ms)
	var bd := FIRE_SHADOW_R
	_best = null
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var keep: int = BUDGET[clampi(Settings.detail, 0, 2)]
	var cut := 0
	for k in cand.size():
		var l: Light3D = cand[k][1]
		var c := k >= keep
		_set_cut(l, c)
		cut += 1 if c else 0
		if fire_on and not c and float(cand[k][2]) < bd and _is_fire(l):
			bd = float(cand[k][2])
			_best = l
	_stats.y = cand.size()
	_stats.z = cut
	if bool(_cut.get(_best, false)):
		_best = null


## A fire that may cast: a lit brazier (class beacon) or a light its builder marked `fire` (camp and outpost fires,
## the Marches' hearths, the tavern's and the Rooted Holds' hearths, the First Hearth).
static func _is_fire(l: Light3D) -> bool:
	return l.has_meta(&"fire") or l.get_meta(&"light_class", &"") == &"beacon"


func _set_cut(l: Light3D, c: bool) -> void:
	if bool(_cut.get(l, false)) != c:
		_cut[l] = c
		_moving[l] = true                        # (a cut light stays in the set: it follows the camera's distance)
	elif not c and l.distance_fade_begin != float(_own[l]):
		_moving[l] = true                        # kept but not yet back at its own fade start


## Move each easing light's fade start toward its target: its own (kept) or just inside the camera (cut), EASE m/s.
## A cut light keeps following the camera's distance, so it stays in the moving set while cut.
func _ease(at: Vector3, dt: float) -> void:
	for key: Variant in _moving.keys():
		if not is_instance_valid(key):
			_moving.erase(key)                       # (a freed light: never assigned to a typed Light3D)
			continue
		var l := key as Light3D
		var own := float(_own[l])
		var c := bool(_cut.get(l, false))
		var want := own
		if c:
			want = maxf(0.0, at.distance_to(l.global_position) - l.distance_fade_length - 1.0)
		var cur := l.distance_fade_begin
		if absf(cur - want) > 0.01:
			l.distance_fade_begin = move_toward(cur, want, EASE * dt)
		elif not c:
			_moving.erase(l)                         # back at its own: done


## The nearest lit brazier on high settings casts; the last one's shadow eases out.
func _fire_shadow(dt: float) -> void:
	var best := _best if is_instance_valid(_best) else null
	if best != _fire and _fire != null and is_instance_valid(_fire):
		_fire.shadow_opacity = move_toward(_fire.shadow_opacity, 0.0, FIRE_SHADOW_IN * dt)
		if _fire.shadow_opacity <= 0.0:
			_fire.shadow_enabled = false
			_fire = null
		return
	if _fire != null and not is_instance_valid(_fire):
		_fire = null
	if best == null:
		return
	if _fire != best:
		_fire = best
		_fire.shadow_opacity = 0.0
		if _fire is OmniLight3D:
			(_fire as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		_fire.shadow_caster_mask = LightPolicy.FIRE_CASTERS    # no terrain or undergrowth in the fire's map
		_fire.shadow_bias = 0.08
		_fire.shadow_normal_bias = 1.5
		_fire.distance_fade_shadow = FIRE_SHADOW_R
	_fire.shadow_enabled = true
	if _fire.shadow_opacity < 0.85:
		_fire.shadow_opacity = move_toward(_fire.shadow_opacity, 0.85, FIRE_SHADOW_IN * dt)


## The light casting the fire shadow now, or null (perf_watch --fps-log prints it).
func fire_light() -> Light3D:
	return _fire if _fire != null and is_instance_valid(_fire) and _fire.shadow_enabled else null


## (governed, local lights in reach, cut by the budget): perf_watch --fps-log prints it.
func stats() -> Vector3i:
	return Vector3i(_stats.x, _stats.y, _stats.z + (1000 if _fire != null and _fire.shadow_enabled else 0))

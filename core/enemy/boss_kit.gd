class_name BossKit
extends RefCounted
## Shared boss moves. Every boss attack is telegraphed on the ground first: the exact area fills
## red (SpellFx.danger) for the whole delay, then the move resolves. The fill reaching the edge is
## the dodge cue; nothing a boss does lands outside a zone you were shown.
##
## r33 (WoW encounter design, adapted): every named mechanic is also a CAST the HUD can show --
##   BossKit.cast(e, name, time, interruptible, done) -> Enemy.begin_cast(..., bound = false): a timed
##   bar ("Thornlash Volley", "Requiem", "Radiant Fan"...) whose `done` runs when the clock is up.
##   Read it off the boss like any foe: e.cast_info() -> {"name", "progress", "time", "left",
##   "interruptible"} (or e.cast_name / e.cast_elapsed / e.cast_time / e.cast_interruptible), and
##   Events.enemy_cast_started / enemy_cast_ended fire as casts begin and end. Interruptible boss casts
##   break on a heavy blow (Enemy.INTERRUPT_DMG, a charged bolt) or a burst on the open weak point.
## Each boss has: telegraphed ground zones (red fills for exactly the delay), add waves (add_wave, capped,
## the adds never leash), and (r35: no soft enrage any more) a signature of each
## sort -- one to interrupt, one to stand in or out of, one positional:
##   Thornwarden     Sap Mending (interrupt, or it heals) / Briar Snare + Thornlash lanes (out) /
##                   Bramble Lash (never stand behind it)
##   Bone Abbot      Raise the Faithful + the Requiem's reliquary (interrupt) / Requiem rings, cage,
##                   grave-fire (weave out) / Crozier Sweep (never stand before it)
##   Ascended Warden Radiant Fan + Call the Acolytes (interrupt) / Eclipse (stand IN the light) /
##                   Mandorla Flare (get under it: only its feet are safe)

const Synth := preload("res://core/vfx/synth.gd")
const THORN := Color(2.6, 0.5, 0.1)          ## r29: was (2.6, 0.32, 0.18), which the grade turned blue
const BONE := Color(2.2, 1.9, 1.4)
## Gold, not white-gold: the Warden's red on the summit's pale deck was a white sheet you could not tell from moonlit stone,
## and the Sky Breaks' deck-wide red hid the lit pylons' safe rings (violet is the player's own bolt colour)
const HOLY := Color(2.6, 1.5, 0.4)

const Hints := preload("res://ui/hints.gd")
const ClipRig := preload("res://core/enemy/clip_rig.gd")
const BOLT_CHIP := 0.7          ## r30: a boss takes this from a plain (non-heavy) Rift Bolt; Lance, Nova, Shatter stay full
const SIG_NEEDED := 2           ## a phase cannot end before its signature move has been shown this often
const INTRO := 1.8              ## seconds a boss stands, shelled, after it rises: the title card's grace

static var _spike_meshes := {}
const SPIKE_SHADER := preload("res://core/vfx/spike.gdshader")
static var _spike_mats := {}
static var _live: Array = []        ## [[zone mesh id, land time s], ...]: the zones still filling


## Pay the first-use costs of a boss's moves while the arena is still quiet: the danger-zone
## shader in each shape and colour, both spike meshes and their materials, the particle, ring and
## light presets the landings use, and the boss's synthesized sounds. `stage` 0..4 does one fifth of
## it (sounds, danger zones, rings, spike meshes, bursts and light), so an arena can spread the work
## over frames; -1 does it all. Anything drawn is a speck put in front of the camera for a few
## frames (culled things never compile), then freed.
## The bosses rebuilt in Blender (18 Nov, every model authored there): skeleton, mesh and clips in one glb each,
## worn with the villagers' look (tools/blender/vb_*.py).
const AUTHORED := {&"bone_abbot": "res://art/models/bosses/vb_bone_abbot.glb",
		&"r37_anchoress": "res://art/models/bosses/vb_anchoress.glb",
		&"ascended_warden": "res://art/models/bosses/vb_ascended_warden.glb",
		&"r37_hierarch": "res://art/models/bosses/vb_speaking_crown.glb",
		&"thornwarden": "res://art/models/bosses/vb_thornwarden.glb"}


static func warm(host: Node, stage := -1, boss := &"") -> void:
	if host == null or not host.is_inside_tree():
		return
	if stage == 0 and boss != &"":
		if AUTHORED.has(boss):                  # a Blender-authored boss (ClipRig, the villagers' look): its glb, instanced on a worker
			ResourceLoader.load_threaded_request(AUTHORED[boss])
			ClipRig.instance_ahead(AUTHORED[boss])
		else:
			EnemyBody.prefetch(boss)            # the boss's model and textures load on a worker, ready for the rig
	if stage == 0 or stage < 0:
		for k: String in ["chant", "stagger", "roar", "bone", "spike", "block", "growl"]:
			Synth.get_stream(k)
		ResourceLoader.load("res://art/audio/ward_chime.wav")
	var cam := host.get_viewport().get_camera_3d()
	var at := Vector3(0.0, 1.0, 0.0)
	if cam != null:
		at = cam.global_position - cam.global_basis.z * 3.0
	var cols: Array[Color] = [THORN, BONE, HOLY]
	for c in cols:
		if stage == 1 or stage < 0:
			SpellFx.danger(at, 0.2, {"radius": 0.02, "color": c, "hold": 0.0})
			SpellFx.danger(at, 0.2, {"radius": 0.02, "half_angle": 0.5, "color": c, "hold": 0.0})
			SpellFx.danger(at, 0.2, {"rect": Vector2(0.01, 0.02), "color": c, "hold": 0.0})
		if stage == 2 or stage < 0:
			Vfx.ring(at, 0.02, c, 0.2, 0.1, Vector3.UP, 1.2)
	for kind in ["bone", "thorn"]:
		if stage >= 0 and stage != 3:
			continue
		_spike_assets(kind)
		var sp := MeshInstance3D.new()
		sp.mesh = _spike_meshes[kind]
		sp.material_override = _spike_mats[kind]
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(sp)
		sp.global_position = at
		sp.scale = Vector3.ONE * 0.01
		host.get_tree().create_timer(0.3, false).timeout.connect(sp.queue_free)
	if stage >= 0 and stage != 4:
		return
	Vfx.burst(at, BONE, {"count": 4, "life": 0.3, "speed": Vector2(0.1, 0.2), "size": 0.01, "gravity": -6.0, "ring": 0.02})
	Vfx.burst(at, Color(0.08, 0.06, 0.06, 0.8), {"count": 4, "life": 0.3, "speed": Vector2(0.1, 0.2), "size": 0.01, "gravity": 0.6, "radius": 0.02, "additive": false, "turbulence": true})
	Vfx.light(at, Color(0.1, 0.1, 0.1), 0.01, 1.0, 0.1, 0)


## Build a throwaway copy of the boss as a speck in front of the camera so its rig, meshes and
## shaders are made and drawn once before the pull (a fresh boss cost ~130 ms on its first frame).
## It is out of every group and off every collision layer, and is freed after a few frames.
static func warm_rig(host: Node, script: GDScript) -> void:
	if host == null or script == null or not host.is_inside_tree():
		return
	var e := script.new() as Enemy
	if e == null:
		return
	e.process_mode = Node.PROCESS_MODE_DISABLED
	e.visible = false                       # built now (the cost is the model and its textures), drawn a beat later
	host.add_child(e)
	e.remove_from_group(Groups.ENEMY)
	e.collision_layer = 0
	e.collision_mask = 0
	e.scale = Vector3.ONE * 0.01
	# the health plate is sized in metres by its shader, not by the node's scale: left on, the "speck" drew a full-size
	# bar three metres in front of the lens (over a herd of deer, in the trailer) for the half second it lived
	var plate := e.get_node_or_null("HealthBar") as Node3D
	if plate != null:
		plate.visible = false
	var cam := host.get_viewport().get_camera_3d()
	e.global_position = (cam.global_position - cam.global_basis.z * 3.0) if cam != null else Vector3(0.0, 1.0, 0.0)
	var eid := e.get_instance_id()
	host.get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
		var e2 := instance_from_id(eid) as Enemy
		if e2 != null:
			e2.visible = true)               # the first draw (pipelines for the boss shader) is its own frame
	host.get_tree().create_timer(0.65, false).timeout.connect(e.queue_free)


## One dominant telegraph at a time: the zone landing soonest draws at full strength, ones landing
## 0.4 s or more after it are dimmed to an outline (the shader's `soft`), so the safe floor stays readable.
static func _rank() -> void:
	var now := Time.get_ticks_msec() * 0.001
	var keep: Array = []
	var first := INF
	for z: Array in _live:
		if instance_from_id(int(z[0])) != null and float(z[1]) > now - 0.05:
			keep.append(z)
			first = minf(first, float(z[1]))
	_live = keep
	for z: Array in _live:
		var mi := instance_from_id(int(z[0])) as MeshInstance3D
		if mi:
			mi.set_instance_shader_parameter(&"soft", clampf((float(z[1]) - first - 0.4) / 0.6, 0.0, 1.0))


## A telegraphed area that hurts the player if they are in it when the fill completes.
## shape opts are SpellFx.danger's ("radius", "half_angle", "rect", "yaw"), plus "holes" (safe
## pools: [[centre, radius], ...]), "spikes"
## ("bone" | "thorn" | "" for a plain blast), "h" (how far above the zone still counts) and "by"
## (the Enemy that made it: its cancel_moves() -- a phase change, its death, an arena reset --
## takes the zone back, the red fades and nothing lands).
static func zone(host: Node, at: Vector3, delay: float, gloom: float, opts := {}) -> void:
	if host == null or not host.is_inside_tree():
		return
	var col: Color = opts.get("color", THORN)
	var by := opts.get("by") as Enemy if opts.get("by") is Enemy else null
	var o := opts.duplicate()
	o["color"] = col
	o.erase("by")
	opts = o                                     # the timer below keeps no node, not even in a dict
	var mi := SpellFx.danger(at, delay, o)
	var mid := mi.get_instance_id() if mi != null else 0
	var bound := by != null and mi != null
	if mi != null:
		_live.append([mi.get_instance_id(), Time.get_ticks_msec() * 0.001 + delay])
		_rank()
	var by_id := by.get_instance_id() if by != null else 0
	if bound:
		by.track_move(mi)
	# timers hold ids, never nodes: a freed capture prints "Lambda capture was freed" at call time
	var hid := host.get_instance_id()
	host.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		var h := instance_from_id(hid) as Node
		if h == null or not h.is_inside_tree():
			return
		_rank()
		if bound and instance_from_id(mid) == null:
			return                               # taken back by its maker
		_land(h, at, opts, col)
		var mk := instance_from_id(by_id) as Enemy if by_id != 0 else null
		var g := gloom * (mk.dmg_mult if mk != null else 1.0)    # any ramp a boss sets (r35: no soft enrage)
		var p := h.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p and inside(p.global_position, at, opts):
			if p.is_evading():
				# a Rift Step through a boss's landing zone is a riposte, as through any other foe's
				var maker := instance_from_id(by_id) as Enemy if by_id != 0 else null
				if maker != null and maker.is_alive():
					p.on_evaded(maker)
				else:
					HitText.pop(p.global_position + Vector3.UP * 2.0, "evaded", Color(0.6, 0.75, 1.0))
			else:
				p.take_wound(g, at))


## Is `pos` in the zone (disc / cone / lane) at `at`?
static func inside(pos: Vector3, at: Vector3, opts: Dictionary) -> bool:
	var d := pos - at
	var h: float = opts.get("h", 1.6)
	if d.y > h or d.y < -1.2:
		return false
	# r31: "holes" ([[centre, radius], ...]) are safe pools inside the zone (the Warden's eclipse)
	for hole: Array in opts.get("holes", []):
		var hd := pos - (hole[0] as Vector3)
		if Vector2(hd.x, hd.z).length() <= float(hole[1]) and absf(hd.y) < 3.0:
			return false
	var yaw: float = opts.get("yaw", 0.0)
	var local := Basis(Vector3.UP, yaw).inverse() * Vector3(d.x, 0.0, d.z)
	var rect: Vector2 = opts.get("rect", Vector2.ZERO)
	if rect != Vector2.ZERO:
		return absf(local.x) <= rect.x and local.z <= 0.0 and local.z >= -rect.y * 2.0
	var r: float = opts.get("radius", 1.0)
	var flat := Vector2(local.x, local.z)
	if flat.length() > r:
		return false
	var half: float = opts.get("half_angle", PI)
	if half >= PI - 0.01 or flat.length() < 0.5:
		return true
	return absf(atan2(local.x, -local.z)) <= half


static func _land(host: Node, at: Vector3, opts: Dictionary, col: Color) -> void:
	var kind: String = opts.get("spikes", "")
	var rect: Vector2 = opts.get("rect", Vector2.ZERO)
	var yaw: float = opts.get("yaw", 0.0)
	var b := Basis(Vector3.UP, yaw)
	var r: float = opts.get("radius", 1.0)
	var centre := at + (b * Vector3(0, 0, -rect.y) if rect != Vector2.ZERO else Vector3.ZERO)
	var span := maxf(r, rect.length())
	var pl := host.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if pl != null:
		# a heavy landing is felt through the camera, more the nearer it falls (and only just, far off)
		pl.kick(0.3 * clampf(1.0 - pl.global_position.distance_to(centre) / (span + 9.0), 0.0, 1.0))
	if kind != "":
		spikes(host, at, opts, kind)
		Sfx.play_stream(Synth.get_stream("spike"), centre + Vector3.UP, 0.0, 1.0 if kind == "bone" else 0.8)
	else:
		Sfx.play("res://art/audio/ward_chime.wav", centre, -4.0, 0.6)
		Sfx.play_stream(Synth.get_stream("stagger"), centre, 0.0, 0.6)
	if rect == Vector2.ZERO:
		Vfx.burst(at + Vector3.UP * 0.3, col, {"count": 40, "life": 0.6, "speed": Vector2(2.0, 6.0), "size": 0.06, "gravity": -6.0, "ring": r})
		Vfx.ring(at + Vector3.UP * 0.1, r, col, 0.35, 0.1, Vector3.UP, 1.2)
	Vfx.light(centre + Vector3.UP, col, 3.0, span + 2.0, 0.3, 2)
	Vfx.burst(centre + Vector3.UP * 0.2, Color(0.08, 0.06, 0.06, 0.8), {"count": 16, "life": 1.0, "speed": Vector2(0.5, 2.0), "size": 0.45, "gravity": 0.6, "radius": span * 0.5, "additive": false, "turbulence": true})


static func _spike_assets(kind: String) -> void:
	if not _spike_meshes.has(kind):
		_spike_meshes[kind] = _build_thorn() if kind == "thorn" else _build_bone_spike()
	if not _spike_mats.has(kind):
		# r30: lit shards with a dirty base and burning tips in the boss's own accent (they were one
		# white claw-cone on a violet glow that the grade turned blue: traffic cones on white discs)
		var m := ShaderMaterial.new()
		m.shader = SPIKE_SHADER
		m.set_shader_parameter("accent", Color(1.0, 0.62, 0.22) if kind == "bone" else Color(1.0, 0.3, 0.06))
		m.set_shader_parameter("energy", 2.2 if kind == "bone" else 3.0)
		m.set_shader_parameter("rough", 0.6 if kind == "bone" else 0.85)
		_spike_mats[kind] = m


## Spikes that erupt over a zone, hold, and sink: bone (pale, for the Abbot) or thorn (dark bark).
static func spikes(host: Node, at: Vector3, opts: Dictionary, kind: String) -> void:
	var h := Vfx.host()
	if h == null:
		return
	_spike_assets(kind)
	var rect: Vector2 = opts.get("rect", Vector2.ZERO)
	var yaw: float = opts.get("yaw", 0.0)
	var b := Basis(Vector3.UP, yaw)
	var pts: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(at.snapped(Vector3.ONE * 0.1))
	if rect != Vector2.ZERO:
		var n := int(rect.y * 2.0 / 0.9)
		for i in n:
			var z := -float(i) / float(maxi(n - 1, 1)) * rect.y * 2.0
			pts.append(at + b * Vector3(rng.randf_range(-rect.x, rect.x) * 0.7, 0.0, z))
	else:
		var r: float = opts.get("radius", 1.0)
		var n := clampi(int(r * r * 1.1), 5, 26)
		for i in n:
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * r * 0.92
			pts.append(at + Vector3(cos(a) * rr, 0.0, sin(a) * rr))
	var space := (host as Node3D).get_world_3d().direct_space_state if host is Node3D else null
	for pt in pts:
		var g := pt
		if space:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pt + Vector3.UP * 1.5, pt + Vector3.DOWN * 2.5, Layers.WORLD))
			if not hit.is_empty():
				g = hit.position
		var mi := MeshInstance3D.new()
		mi.mesh = _spike_meshes[kind]
		mi.material_override = _spike_mats[kind]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(mi)
		var tall := rng.randf_range(0.7, 1.35) * (1.2 if kind == "thorn" else 1.0)
		var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.05, 0.35))
		mi.global_transform = Transform3D(tilt.rotated(Vector3.UP, rng.randf() * TAU), g + Vector3.DOWN * 0.1)
		mi.scale = Vector3(1.0, 0.02, 1.0)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(1.0, tall, 1.0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.55 + rng.randf() * 0.2)
		tw.tween_property(mi, "scale", Vector3(0.6, 0.02, 0.6), 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	var col := Color(0.85, 0.78, 0.66) if kind == "bone" else Color(0.2, 0.1, 0.08)
	var c := at + (b * Vector3(0, 0, -rect.y) if rect != Vector2.ZERO else Vector3.ZERO)
	Vfx.burst(c + Vector3.UP * 0.3, col, {"count": 30, "life": 0.7, "speed": Vector2(2.0, 5.0), "size": 0.06, "gravity": -10.0, "additive": false, "radius": maxf(rect.length(), float(opts.get("radius", 1.0))) * 0.6})


## Bone eruption: a cluster of 4 curved, ribbed shards (a femur, ribs, a broken tusk) of different
## heights out of a dark clod of earth, the tips smouldering candle-gold. About 1 m tall.
static func _build_bone_spike() -> ArrayMesh:
	var cm := CreatureMesh.new(4242)
	var earth := Color(0.13, 0.1, 0.08)
	cm.blob(Vector3(0, 0.02, 0), Vector3(0.3, 0.09, 0.26), Basis.IDENTITY, earth, 0.0, 0.35, 0.0, 6, 12)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4 * float(k % 2)
		var lean := Vector3(cos(a), 0.0, sin(a))
		var tall := 1.0 if k == 0 else 0.45 + 0.17 * float(k)
		var base := lean * (0.04 + 0.05 * float(k))
		var broken := k == 2                      # one snapped off, a flat jagged top
		var n := 16
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in n:
			var t := float(i) / float(n - 1)
			pts.append(base + Vector3.UP * tall * t + lean * (0.08 + 0.1 * float(k % 2)) * tall * t * t)
			var w := (0.085 - 0.012 * float(k)) * (1.0 - t * (0.55 if broken else 0.93))
			radii.append(w * (1.0 + 0.13 * sin(float(i) * 2.6)))           # growth ridges
		if not broken:
			radii[n - 1] = 0.0
		# grime up the root (earth-dark), clean ivory above; the two meet in a ridge of dirt
		var cut := 5
		cm.tube(pts.slice(0, cut + 1), radii.slice(0, cut + 1), 8, Color(0.3, 0.24, 0.17), 1.0, 0.15)
		cm.tube(pts.slice(cut), radii.slice(cut), 8, Color(0.8, 0.74, 0.6), 1.0, 0.1)
		cm.blob(pts[cut], Vector3(radii[cut] * 1.12, 0.03, radii[cut] * 1.12), Basis.IDENTITY, Color(0.22, 0.17, 0.12), 0.0, 0.3, 0.0, 4, 8)
		# a smouldering tip (or a glowing break)
		cm.blob(pts[n - 2] if not broken else pts[n - 1], Vector3(0.014, 0.025, 0.014), Basis.IDENTITY, Color(0.9, 0.7, 0.4), 1.0, 0.0, 1.0, 4, 6)
	return cm.commit()


## Thorn eruption: three brambles braided round each other, barbed all the way up, dark bark,
## ember at the tips and in the barbs' roots. About 1.2 m tall.
static func _build_thorn() -> ArrayMesh:
	var cm := CreatureMesh.new(4343)
	var bark := Color(0.16, 0.1, 0.07)
	cm.blob(Vector3(0, 0.02, 0), Vector3(0.26, 0.08, 0.24), Basis.IDENTITY, Color(0.1, 0.07, 0.05), 0.0, 0.35, 0.0, 6, 12)
	for s in 3:
		var ph := TAU * float(s) / 3.0
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		var n := 12
		for i in n:
			var t := float(i) / float(n - 1)
			var r := 0.07 * (1.0 - t * 0.6)
			pts.append(Vector3(cos(ph + t * 5.0) * r, t * (1.0 - 0.12 * float(s)), sin(ph + t * 5.0) * r))
			radii.append(0.045 * (1.0 - t) + 0.004 if i < n - 1 else 0.0)
		cm.tube(pts, radii, 6, bark, 0.0, 0.2)
		for i in range(2, n - 2, 2):
			var out := (pts[i] - Vector3(0, pts[i].y, 0)).normalized()
			cm.claw(pts[i], (out + Vector3(0, 0.6, 0)).normalized(), 0.1, 0.014, Vector3(0, 0.2, 0), Color(0.22, 0.14, 0.1))
		cm.blob(pts[n - 2], Vector3(0.014, 0.04, 0.014), Basis.IDENTITY, Color(0.8, 0.3, 0.1), 0.0, 0.0, 1.0, 4, 6)
	return cm.commit()


## Raise minions around `at` (they join the fight at once).
static func summon(host: Node, script: GDScript, at: Vector3, n: int, ring := 3.0, owner_id := "") -> Array[Enemy]:
	var out: Array[Enemy] = []
	if host == null:
		return out
	var space := (host as Node3D).get_world_3d().direct_space_state if host is Node3D else null
	for i in n:
		var a := TAU * float(i) / float(n) + randf() * 0.4
		var p := at + Vector3(cos(a) * ring, 0, sin(a) * ring)
		if space:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p + Vector3.DOWN * 6.0, Layers.WORLD))
			if hit.is_empty():
				continue
			p = hit.position
		var e := script.new() as Enemy
		e.set_meta(&"summoned_by", owner_id)
		e.set_meta(&"no_leash", true)            # r33: a boss's adds fight to the end, they never reset home
		e.hunt_leash = maxf(e.hunt_leash, 60.0)
		e.chase_range = maxf(e.chase_range, 30.0)
		e.can_call = false
		host.add_child(e)
		e.global_position = p + Vector3.UP * 0.05
		e.wake()
		SpellFx.rift_in(p)
		out.append(e)
	return out


## Scale an enemy into a boss: bigger rig and capsule, bar higher, knockback mostly ignored,
## longer and bigger telegraphs, a deep poise (sustained pressure still staggers it, rarely).
static func embiggen(e: Enemy, s: float) -> void:
	if e._rig:
		e._rig.scale *= s
	# r30: skin detail at a boss's own scale (it was the grunt's wrinkles blown up 2x, a toy look)
	EnemyBody.material(e.body_kind).set_shader_parameter("detail_tile", CreatureMesh.TILE / s)
	var col := e.get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := (col.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		cap.radius *= minf(s, 1.6)
		cap.height *= s
		col.shape = cap
		col.position.y = cap.height * 0.5
	e.boss = true
	e.hp_bar_y *= s
	e.strike_range *= minf(s, 1.7)
	e.light_averse = false
	e.sleep_range = 80.0
	e.chase_range = 40.0
	e.hunt_leash = 60.0
	e.windup_time = 0.7
	e.strike_arc = 70.0
	e.lunge = 6.0
	e.recover_time = 0.8
	e.poise = float(e.max_hp) * 0.22


## A great one's body is solid to the wanderer out to its robe's or flank's edge, not only its capsule (kept narrow so it
## fits its own arena's ways): one inside it (walked in, pushed in, landed in by a step) is eased out, so the lens is never
## in its body (the Anchoress's skirt filled the view, the camera inside it) and no blow is traded from within it.
static func keep_out(e: Enemy, delta: float) -> void:
	var p := e._p
	if p == null or not is_instance_valid(p) or p.is_evading():
		return
	if not e.has_meta(&"foot_r"):
		e.set_meta(&"foot_r", _footprint(e))
	var r := float(e.get_meta(&"foot_r"))
	var d := Vector2(p.global_position.x - e.global_position.x, p.global_position.z - e.global_position.z)
	var dy := p.global_position.y - e.global_position.y
	if d.length_squared() >= r * r or dy > e.hp_bar_y or dy < -2.0:
		return
	var out := d.normalized() if d.length() > 0.05 else Vector2(-sin(e.rotation.y), -cos(e.rotation.y))
	p.move_and_collide(Vector3(out.x, 0.0, out.y) * minf(r - d.length(), 6.0 * delta))


## The body's footprint radius: the narrower side of its meshes' box at rest (a staff or a tail on the long side), never
## less than its capsule.
static func _footprint(e: Enemy) -> float:
	var col := e.get_node_or_null("Collision") as CollisionShape3D
	var cap := (col.shape as CapsuleShape3D).radius if col != null and col.shape is CapsuleShape3D else 0.5
	var box := AABB()
	var first := true
	for mi in e._flesh:
		if mi == null or not is_instance_valid(mi) or mi.mesh == null:
			continue
		var bb := (e.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	if first:
		return cap
	return clampf(0.45 * minf(box.size.x, box.size.z), cap, 2.4)


## A boss rising (BossArena._begin -> on_engaged): it stands shelled ("warded") for INTRO seconds
## while the title card shows, roars at 2/3 of it, and only then may it attack. Before r30 the
## Thornwarden could pounce before the card had faded.
static func intro(e: Enemy, col: Color, dur := INTRO) -> void:
	dur = maxf(dur, BossFrame.HOLD)            # he stays where he rose while the camera is on him: no boss walks into the frame or the emote line
	e._ward_t = dur
	e._combo_left = 0
	if e._state != Enemy.DEAD:
		e._set_state(Enemy.RECOVER)
		e._state_t = -(dur - e.recover_time)
	var eid := e.get_instance_id()
	e.get_tree().create_timer(dur * 0.67, false).timeout.connect(func() -> void:
		var e2 := instance_from_id(eid) as Enemy
		if e2 != null and e2.is_alive():
			roar(e2, "", col))


## Boss damage rules (bosses call this from _absorb):
##  - a plain Rift Bolt deals BOLT_CHIP of its damage: charged and combo play (Lance, Nova, Shatter)
##    is how a boss is killed, not a held trigger;
##  - `floor_hp` > 0: the phase is not over until its signature move has been seen SIG_NEEDED
##    times; blows that would take it below are turned ("warded", the phase shell's look).
static func absorb(e: Enemy, dmg: float, from: Node, floor_hp: float) -> float:
	if from is MagicBolt and not (from as MagicBolt).heavy and not (from as MagicBolt).empowered:
		dmg *= BOLT_CHIP                          # the Lash (empowered) lands whole; a plain bolt pays the tax
		Hints.once(&"bolt_chip", "A great one takes a plain bolt at seven tenths. The Lash, the Lance, and the staff land whole.")
	# r34 raids: a floor holds only what is above it (a boss already below it -- set by a test, or a
	# phase that moved on -- is not made immortal by it). A boss held exactly AT the floor stays held:
	# the first blow clamps hp to the floor, and the next must not slip through before the signature.
	if floor_hp > 0.0 and e.hp > floor_hp - 0.01 and e.hp - dmg < floor_hp:
		var left := maxf(0.0, e.hp - floor_hp)
		var now := Time.get_ticks_msec()
		if now - int(e.get_meta(&"floor_pop", 0)) > 450:
			e.set_meta(&"floor_pop", now)
			HitText.pop(e.global_position + Vector3.UP * (e.hp_bar_y + 0.6), "warded", Color(0.8, 0.7, 1.0))
			Vfx.ring(e.global_position + Vector3.UP * (e.hp_bar_y * 0.55), 1.2, Color(0.5, 0.45, 0.6), 0.25, 0.06, Vector3.UP, 0.8)
		if left <= 0.0:
			deflect_fx(e, from)
		dmg = left
	return dmg


## take_hit on a foe whose processing is off: a boss held by its arena (walked out of) takes nothing
## (false); a sleeping foe wakes for the blow (true), or a kill from range would leave a frozen corpse
## (its dissolve tween pauses with the node).
static func wake_for_hit(e: Enemy) -> bool:
	if e.has_meta(&"arena_held"):
		return false
	e.wake()
	return true


## A Rift Step through a boss must not chain-stun it: the stagger cooldown holds, and a leap in the
## air is left alone. True when the riposte may land (the cooldown is then spent).
static func riposte_ok(e: Enemy) -> bool:
	if e._stagger_cd > 0.0 or e._state == Enemy.AIRBORNE:
		return false
	e._stagger_cd = Enemy.STAGGER_CD
	return true


## One clear cue for every blow a boss turns completely (a rooted, mounded or ascended intermission):
## a spark where the blow lands, a ringing note, a "warded" text, and (once per window) a line saying
## what to do instead. The caller also sets the `ward_hint` meta, which locks the boss bar.
static func warded_hit(e: Enemy, hint: String, col: Color, from: Node = null) -> void:
	deflect_fx(e, from)
	var now := Time.get_ticks_msec()
	if now - int(e.get_meta(&"ward_pop", 0)) > 600:
		e.set_meta(&"ward_pop", now)
		HitText.pop(e.global_position + Vector3.UP * (e.hp_bar_y + 0.6), "warded", Color(0.8, 0.75, 1.0))
		if hint != "":
			HitText.pop(e.global_position + Vector3.UP * (e.hp_bar_y + 1.0), hint, col)
	if hint != "" and now - int(e.get_meta(&"ward_emote", -100000)) > 12000:
		e.set_meta(&"ward_emote", now)
		emote(e, "Your blows ring off it: " + hint + ".", col)


## The spark and note of a turned blow (throttled: a held trigger must not machine-gun it).
static func deflect_fx(e: Enemy, from: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - int(e.get_meta(&"deflect_ms", 0)) < 110:
		return
	e.set_meta(&"deflect_ms", now)
	var at := e.global_position + Vector3.UP * (e.hp_bar_y * 0.55)
	var dir := Vector3.UP
	if from is Node3D:
		var d := (from as Node3D).global_position - e.global_position
		d.y = 0.0
		if d.length() > 0.05:
			dir = d.normalized()
			at += dir * 0.8
	Vfx.burst(at, Color(1.8, 1.6, 2.4), {"count": 14, "life": 0.3, "speed": Vector2(3.0, 7.0), "size": 0.03, "gravity": -9.0, "trail": 0.05, "dir": dir, "spread": 70.0})
	Vfx.ring(at, 0.9, Color(0.7, 0.6, 1.0), 0.2, 0.05, Vector3.UP, 0.8)
	Sfx.play_stream(Synth.get_stream("block"), at, -1.0, 1.5)


## True while the boss turns every blow (an intermission names its way out in the `ward_hint` meta).
static func is_warded(e: Enemy) -> bool:
	return e._ward_t > 0.0 or String(e.get_meta(&"ward_hint", "")) != ""


## The HP floor for a boss in `phase` (1-based) with `marks` (phase_marks()) that has shown its
## signature move `sig` times: just above the next mark (or 1 HP in the last phase) until
## SIG_NEEDED, then none.
static func phase_floor(e: Enemy, phase: int, marks: Array[float], sig: int) -> float:
	if sig >= SIG_NEEDED or e.has_meta(&"test_no_floor"):
		return 0.0
	if phase - 1 < marks.size():
		return marks[phase - 1] * float(e.max_hp) + 0.5
	return 1.0


## Between phases: the boss reels (its tells in flight are cancelled, its windup broken), a pale
## shell closes round it and blows are mostly turned ("warded") for `dur` seconds, then it roars.
## The pause is the player's breath; the roar is the cue that the next phase has begun.
static func transition(e: Enemy, line: String, col: Color, dur := 1.4) -> void:
	e._finish_cast(true, false)                  # r33: a cast in flight dies with the phase
	e.cancel_moves()
	pose_beat(e)
	e._combo_left = 0
	e._ward_t = dur
	if e._state != Enemy.AIRBORNE and e._state != Enemy.DEAD:
		e._set_state(Enemy.RECOVER)
		e._state_t = -(dur - e.recover_time)
	if e._rig and e._rig.has_method("stagger"):
		e._rig.call("stagger")
	var at := e.global_position + Vector3.UP * e.hp_bar_y * 0.5
	SpellFx.shell(at, e.hp_bar_y * 0.3, e.hp_bar_y * 0.75, Color(col.r * 0.4, col.g * 0.4, col.b * 0.4), dur)
	Vfx.burst(at, Color(0.05, 0.03, 0.06, 0.85), {"count": 30, "life": 1.2, "speed": Vector2(0.4, 1.6), "size": 0.4, "gravity": 0.8, "radius": 0.8, "additive": false, "turbulence": true})
	Sfx.play_stream(Synth.get_stream("stagger"), at, 2.0, 0.55)
	e.say("stagger", at, 1.0, 1.0)
	var eid := e.get_instance_id()
	e.get_tree().create_timer(dur * 0.55, false).timeout.connect(func() -> void:
		var e2 := instance_from_id(eid) as Enemy
		if e2 != null and e2.is_alive():
			roar(e2, line, col))


## Phase change: a roar, the eyes flare, a non-damaging shock ring, and the arena hears of it.
static func roar(e: Enemy, line: String, col: Color) -> void:
	e.say("phase", e.global_position + Vector3.UP * 2.0, 3.0, 1.0)          # the great one's own roar, long and low
	Sfx.play_stream(Synth.get_stream("roar"), e.global_position + Vector3.UP * 2.0, -2.0, 0.8)
	if line != "":
		Events.toast.emit(line)
	e._glint = 1.0
	var at := e.global_position
	Vfx.ring(at + Vector3.UP * 0.15, 9.0, col, 0.9, 0.06, Vector3.UP, 1.4)
	SpellFx.shell(at + Vector3.UP * e.hp_bar_y * 0.5, 0.5, 5.0, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5), 0.5)
	Vfx.burst(at + Vector3.UP * e.hp_bar_y * 0.6, col, {"count": 60, "life": 0.9, "speed": Vector2(3.0, 9.0), "size": 0.06, "gravity": -2.0, "trail": 0.1})
	Vfx.light(at + Vector3.UP * 2.0, col, 5.0, 14.0, 0.8, 2)
	var p := e.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p:
		p.kick(1.0)


## The first instant of a phase change: the world holds a breath on the boss's pose and the view
## jolts, before the shell closes and the roar follows.
static func pose_beat(e: Enemy) -> void:
	var p := e.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p:
		p.kick(0.8)
	if not TimeSlow.active():
		TimeSlow.request(e.get_tree(), 0.2, 0.3)
	Vfx.ring(e.global_position + Vector3.UP * 0.1, 3.5, Color(1.5, 1.4, 1.2), 0.3, 0.08, Vector3.UP, 1.2)


## A heavy blow or a weak-point burst on a great one: a longer crunch, a brighter flash, a jolt of the
## view. Plain bolts and staff taps stay quiet, so the heavy ones read.
static func hit_feel(e: Enemy, dmg: float, weak: bool) -> void:
	if not e.boss or (dmg < 2.5 and not weak):
		return
	e._hitstop = maxi(e._hitstop, 8 if weak else 6)
	e._flash = maxf(e._flash, 0.14)
	var p := e.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p:
		p.kick(clampf(0.3 + dmg * 0.1, 0.3, 0.8))
	if dmg >= 4.0 or weak:
		Vfx.ring(e.global_position + Vector3.UP * e.hp_bar_y * 0.55, 1.6, Color(1.8, 1.4, 0.8), 0.22, 0.06, Vector3.UP, 1.0)


## The death of a great one: the world goes slow as the killing blow lands, the view is thrown, the
## ground rings out, and a low bell tolls over the fall. The rig folds in Enemy._die; this is the weight.
static func fall(e: Enemy) -> void:
	if not e.boss:
		return
	var tree := e.get_tree()
	var at := e.global_position
	var mid := at + Vector3.UP * e.hp_bar_y * 0.5
	TimeSlow.request(tree, 0.12, 0.7)
	var p := tree.get_first_node_in_group(Groups.PLAYER) as Player
	if p:
		p.kick(1.0)
	Vfx.ring(at + Vector3.UP * 0.1, 14.0, Color(1.6, 1.3, 0.9), 1.2, 0.08, Vector3.UP, 1.4)
	Vfx.burst(mid, Color(1.8, 1.4, 0.8), {"count": 70, "life": 1.4, "speed": Vector2(2.0, 8.0), "size": 0.07, "gravity": 1.2, "trail": 0.1})
	Vfx.light(mid, Color(1.0, 0.8, 0.5), 6.0, 16.0, 1.2)
	Sfx.play_stream(Synth.get_stream("stagger"), mid, 4.0, 0.5)
	tree.create_timer(0.9, false).timeout.connect(func() -> void:
		Sfx.play("res://art/audio/ward_chime.wav", at, 5.0)
		Vfx.ring(at + Vector3.UP * 0.1, 18.0, Color(1.4, 1.2, 0.8), 1.6, 0.05, Vector3.UP, 1.2)
		var pl := tree.get_first_node_in_group(Groups.PLAYER) as Player
		if pl:
			pl.kick(0.4))


# --- r33: casts and add waves ---------------------------------------------------------

## r35: the soft enrage (a fight-length timer that ramped every blow and quickened every timer) is
## gone: a solo wanderer learns a boss by losing to it, and a timer punished exactly that.
const RAGE := Color(2.6, 0.35, 0.15)


## A named boss mechanic as a timed cast (see the header). `done` runs when the clock is up, unless
## it was interrupted (then the boss's _on_cast_interrupted hook runs instead).
static func cast(e: Enemy, cast_name: String, time: float, interruptible := false, done := Callable()) -> void:
	if e == null or not e.is_alive():
		return
	var yields: bool = e.has_meta(&"yield_cast") and e.cast_name == String(e.get_meta(&"yield_cast"))
	if e.casting() and e._cast_bound < 0 and not yields:
		# another timed cast holds the bar (a lash during a mending): this one goes unshown, never lost
		if done.is_valid():
			var eid := e.get_instance_id()
			e.get_tree().create_timer(time, false).timeout.connect(func() -> void:
				var who := instance_from_id(eid) as Enemy
				if who != null and is_instance_valid(who) and who.is_alive():
					done.call())
		return
	e.begin_cast(cast_name, time, interruptible, false, done)


## Raise a wave of adds round `at`, up to `cap` of this boss's adds alive at once. Returns the new ones.
static func add_wave(e: Enemy, script: GDScript, at: Vector3, n: int, cap: int, label := "", ring := 3.5) -> Array[Enemy]:
	var bid := String(e.get_meta(&"boss_id", ""))
	var alive := 0
	for m in e.get_tree().get_nodes_in_group(Groups.ENEMY):
		if m != e and (m as Node).get_meta(&"summoned_by", "__") == bid and m is Enemy and (m as Enemy).is_alive():
			alive += 1
	var k := mini(n, cap - alive)
	if k <= 0:
		return [] as Array[Enemy]
	var out := summon(e.get_parent(), script, at, k, ring, bid)
	for a in out:
		if label != "":
			a.set_meta(&"display_name", label)
		a._rally_t = 4.0
		a._set_state(Enemy.CHASE)
	return out


# --- r34 raids (docs/r34/raids_overworld.md): the boss emote line, the room, pushes ---------------
## API added in r34 (stable; the Bone Abbot's crypt may use it too):
##   BossKit.emote(e, text, col)    the raid-warning line under the boss bar (BossArena.emote), WoW's
##                                  "boss emote": what the boss is about to do, said before it does it
##   BossKit.arena(e) / room(e)     the BossArena the boss fights in / that arena's `room` node (or null)
##   BossKit.push(p, dir, speed, d) shove the player along `dir` (a gale, a shockwave) by moving and
##                                  colliding: walls and parapets still stop them

const EMOTE_COL := Color(1.0, 0.82, 0.45)


static func arena(e: Node) -> Node:
	if e == null or not e.is_inside_tree():
		return null
	for a in e.get_tree().get_nodes_in_group(&"boss_arena"):
		if a.get("_boss") == e:
			return a
	return null


static func room(e: Node) -> Node:
	var a := arena(e)
	if a == null:
		return null
	var r: Variant = a.get("room")
	return r as Node if r is Node and is_instance_valid(r) else null


## The boss says what comes: a raid-warning line under its bar (and a toast when there is no bar).
static func emote(e: Node, text: String, col := EMOTE_COL) -> void:
	if e == null:
		return
	if e is Node:
		(e as Node).set_meta(&"last_emote", text)
	var a := arena(e)
	if a != null and a.has_method("emote"):
		a.call("emote", text, col)
	else:
		Events.toast.emit(text)


## r35: world cues, not text. Light the lee of each shield (a standing stone, a lit pylon) against
## `from` for `life` s: a pale column of the same light the Mandorla's safe ground uses, plus a ring on
## the floor, so "get behind X" is something you see in the arena rather than read on the screen.
static func lee_marks(from: Vector3, shields: Array, life: float, col := Color(1.1, 1.3, 1.9), lee := 1.6) -> void:
	for s: Variant in shields:
		var at: Vector3 = s
		var d := at - from
		d.y = 0.0
		if d.length() < 0.5:
			continue
		var spot := at + d.normalized() * lee
		SpellFx.column(spot, 1.1, 5.0, life)
		Vfx.ring(spot + Vector3.UP * 0.08, 1.4, col, life, 0.22, Vector3.UP, 4.0)
		Vfx.ring(spot + Vector3.UP * 0.1, 0.6, col, life, 0.12, Vector3.UP, 3.0)
		# a pool of cool light on the floor: at night a column alone read as nothing on a dark deck
		Vfx.light(spot + Vector3.UP * 1.0, col, 6.0, 5.5, life, 2)


## Move the player along `dir` (flat) at `speed` m/s this frame, colliding with the world.
static func push(p: Player, dir: Vector3, speed: float, delta: float) -> void:
	if p == null or not p.is_inside_tree():
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		return
	p.move_and_collide(d.normalized() * speed * delta)

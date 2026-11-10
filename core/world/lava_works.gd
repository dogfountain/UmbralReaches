class_name LavaWorks
extends Node3D
## Makes the chasm lava a river held between rock: a subdivided surface (swells), a bank mask
## (distance from every shoreline and pier foot, sampled from the real collision once streamed
## areas have built) driving the shader's crust shelf and contact rim, rising embers, and two
## lava falls poured down the steepest chasm walls. Reuses the existing glow lights (no new ones).

const REACH := 7.0          ## metres over which the bank fades into open river
const CELL := 0.5            ## bank map resolution (1 m showed as a stair-stepped rim)

var _surface: MeshInstance3D
var _mat: ShaderMaterial
var _origin := Vector2.ZERO
var _size := Vector2.ONE
var _y := -15.5
var _last_solid := PackedByteArray()
var _slice := 0
const SLICE_US := 2500          ## bank mapping work per frame (perf: the second map was a 24 ms frame)


## Waits a frame once this frame's slice of mapping work is spent; true if it waited.
func _yield_if_spent() -> bool:
	if Time.get_ticks_usec() - _slice < SLICE_US:
		return false
	await get_tree().process_frame
	_slice = Time.get_ticks_usec()
	return true


static func attach(root: Node) -> LavaWorks:
	var s := root.get_node_or_null("Zone/Lava/Surface") as MeshInstance3D
	if s == null or not (s.material_override is ShaderMaterial):
		return null
	var w := LavaWorks.new()
	w.name = "LavaWorks"
	w._surface = s
	root.add_child(w)
	return w


func _ready() -> void:
	_mat = (_surface.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_surface.material_override = _mat
	var pm := _surface.mesh as PlaneMesh
	_y = _surface.global_position.y
	if pm:
		var m := pm.duplicate() as PlaneMesh
		m.subdivide_width = int(m.size.x / 1.5)
		m.subdivide_depth = int(m.size.y / 1.5)
		_surface.mesh = m
		_size = m.size
		_origin = Vector2(_surface.global_position.x - m.size.x * 0.5, _surface.global_position.z - m.size.y * 0.5)
	_mat.set_shader_parameter("bank_origin", _origin)
	_mat.set_shader_parameter("bank_size", _size)
	_embers()
	if Realm.enabled() and Realm.module_on("rift") and ResourceLoader.exists(RIFT):
		_realm_setup()
		return
	# streamed areas (the Ossuary's piers) build over the first seconds: map the banks twice
	get_tree().create_timer(2.5, false).timeout.connect(_map_banks)
	get_tree().create_timer(9.0, false).timeout.connect(_map_banks)
	get_tree().create_timer(3.0, false).timeout.connect(_falls)


const RIFT := "res://core/world/realm/realm_rift.gd"


## Under the Realm the rift module (RealmRift) builds the crossing's piers, islands and basalt in
## the river after this node is ready, and says where the falls go: wait for its meta
## "rift_lava" ({falls: [[z, side], ...]}) on the zone root, then map the banks (twice, for the
## streamed Ossuary) and pour the falls it asked for. Falls back to the old search after 60 s.
func _realm_setup() -> void:
	var root := get_parent()
	var t := 0.0
	while not root.has_meta("rift_lava") and t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	var spec: Dictionary = root.get_meta("rift_lava", {})
	await get_tree().create_timer(1.0, false).timeout
	_map_banks()
	get_tree().create_timer(8.0, false).timeout.connect(_map_banks)
	await get_tree().create_timer(0.5, false).timeout
	if spec.has("star_z"):
		_starwater(float(spec.star_z), float(spec.get("star_band", 5.0)))
	if spec.has("falls"):
		_falls_at(spec.falls)
	else:
		_falls()
	if spec.has("starfalls"):
		_falls_at(spec.starfalls, true)
	_bank_embers()


var _lava_z := Vector2(-INF, INF)          ## the z span that is still lava (embers keep to it)


## The Pilgrims' Threshold (realm_rift.gd STAR_Z): south of star_z the sheet is starwater. The shader
## turns there; the embers keep to the lava; the glow light over the threshold turns violet and the
## next one moves up the lava so no fire light spills onto the village rim.
func _starwater(star_z: float, band: float) -> void:
	_mat.set_shader_parameter("star_z", star_z)
	_mat.set_shader_parameter("star_band", band)
	_lava_z = Vector2(_origin.y, star_z - band)
	var root := get_parent()
	var lz := (_lava_z.x + _lava_z.y) * 0.5
	var half := (_lava_z.y - _lava_z.x) * 0.5
	for e: Node in [get_node_or_null("Embers"), root.get_node_or_null("Zone/Lava/Embers")]:
		var gp := e as GPUParticles3D
		if gp == null or not (gp.process_material is ParticleProcessMaterial):
			continue
		var pm := (gp.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		pm.emission_box_extents.z = half * 0.92
		gp.process_material = pm
		gp.global_position.z = lz
	var g0 := root.get_node_or_null("Zone/Lava/Glow0") as OmniLight3D
	if g0:
		g0.global_position = Vector3(0.0, -11.5, -27.0)
		g0.light_color = Color(0.52, 0.38, 1.0)
		g0.light_energy = 3.4
		g0.omni_range = 40.0
	var g1 := root.get_node_or_null("Zone/Lava/Glow1") as OmniLight3D
	if g1:
		g1.global_position = Vector3(0.0, -13.0, -58.0)


## Falls at the given [z, side] stations: at each, walk out from the river centre towards that
## wall to the last open lava before the rock, and pour from the lip above it (if the wall there
## rises far enough above the river to make a fall).
func _falls_at(list: Array, star := false) -> void:
	var space := get_world_3d().direct_space_state
	var n := 0
	for st: Array in list:
		var z: float = st[0]
		var side: float = st[1]
		var x := 0.0
		var open_x := INF
		var best := []
		while absf(x) < 44.0:
			x += side * 0.5
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, _y - 1, z), Layers.WORLD))
			if hit.is_empty() or (hit.position as Vector3).y < _y + 0.6:
				open_x = x
				continue
			if not String((hit.collider as Node).name).begins_with("Terrain"):
				if _is_chapel(hit.collider as Node):
					open_x = x                         # the Pilgrims' Chapel stands in the fall's way: the river's edge is its far side
				continue                               # basalt, cliffs, piers: look past them
			var hy: float = (hit.position as Vector3).y
			if absf(x - open_x) <= 6.0 and hy > _y + 7.0:
				best = [Vector3(open_x + side * 0.8, hy, z), Vector3(-side, 0, 0), hy - _y]
				break
		if best.is_empty():
			print("LAVA no fall at z %.0f side %d (no wall high enough)" % [z, int(side)])
			continue
		_fall(best[0], best[1], float(best[2]), star)
		n += 1
	print("LAVA %d %s poured for the rift" % [n, "starfalls" if star else "falls"])


## True for a collider under the Pilgrims' Chapel's node (rift/chapel.gd names it "StarwaterChapel").
func _is_chapel(n: Node) -> bool:
	for i in 4:
		if n == null:
			return false
		if n.name == &"StarwaterChapel":
			return true
		n = n.get_parent()
	return false


## A second, denser ember field low over the river near both banks (the rift reads hotter).
func _bank_embers() -> void:
	for side: float in [-1.0, 1.0]:
		var e := Vfx.emitter(Color(1.7, 0.5, 0.1), {"count": 140, "life": 4.0, "speed": Vector2(0.5, 1.8), "size": 0.045, "gravity": -0.4, "radius": 1.0, "turbulence": true, "explosive": 0.0})
		if e == null:
			continue
		e.name = "BankEmbers"
		var pm := (e.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(3.0, 0.2, 50.0)
		e.process_material = pm
		e.visibility_aabb = AABB(Vector3(-6, -1, -54), Vector3(12, 16, 108))
		e.preprocess = 4.0
		add_child(e)
		if _lava_z.y < 0.0:                       # under the Threshold: the lava reach only
			pm.emission_box_extents.z = (_lava_z.y - _lava_z.x) * 0.5 * 0.85
			e.global_position = Vector3(side * 14.0, _y + 0.3, (_lava_z.x + _lava_z.y) * 0.5)
		else:
			e.global_position = Vector3(side * 14.0, _y + 0.3, -64.0)
		e.emitting = true


func _map_banks() -> void:
	var t0 := Time.get_ticks_usec()
	_slice = Time.get_ticks_usec()
	var space := get_world_3d().direct_space_state
	var w := int(_size.x / CELL)
	var h := int(_size.y / CELL)
	var solid := PackedByteArray()
	solid.resize(w * h)
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = Layers.WORLD
	for j in h:
		if await _yield_if_spent():          # a few ms a frame: the map is not urgent, play is
			space = get_world_3d().direct_space_state
		for i in w:
			var x := _origin.x + (float(i) + 0.5) * CELL
			var z := _origin.y + (float(j) + 0.5) * CELL
			q.from = Vector3(x, _y + 1.2, z)
			q.to = Vector3(x, _y - 0.02, z)      # rock at or above the surface: the real shoreline
			solid[j * w + i] = 1 if not space.intersect_ray(q).is_empty() else 0
	if solid == _last_solid:
		# the re-map for streamed pieces (the Ossuary's piers) usually finds the same shore
		print("LAVA banks unchanged %dx%d (%d ms of rays)" % [w, h, (Time.get_ticks_usec() - t0) / 1000])
		return
	_last_solid = solid
	# two-pass chamfer distance transform (cells), then normalised to REACH
	var big := 1.0e6
	var d := PackedFloat32Array()
	d.resize(w * h)
	for k in w * h:
		d[k] = 0.0 if solid[k] == 1 else big
	for j in h:
		await _yield_if_spent()
		for i in w:
			var k := j * w + i
			if i > 0: d[k] = minf(d[k], d[k - 1] + 1.0)
			if j > 0: d[k] = minf(d[k], d[k - w] + 1.0)
			if i > 0 and j > 0: d[k] = minf(d[k], d[k - w - 1] + 1.414)
			if i < w - 1 and j > 0: d[k] = minf(d[k], d[k - w + 1] + 1.414)
	for j in range(h - 1, -1, -1):
		await _yield_if_spent()
		for i in range(w - 1, -1, -1):
			var k := j * w + i
			if i < w - 1: d[k] = minf(d[k], d[k + 1] + 1.0)
			if j < h - 1: d[k] = minf(d[k], d[k + w] + 1.0)
			if i < w - 1 and j < h - 1: d[k] = minf(d[k], d[k + w + 1] + 1.414)
			if i > 0 and j < h - 1: d[k] = minf(d[k], d[k + w - 1] + 1.414)
	var px := PackedByteArray()
	px.resize(w * h)
	var to_byte := 255.0 * CELL / REACH
	for k in w * h:
		px[k] = int(clampf(d[k] * to_byte, 0.0, 255.0))         # truncates, as set_pixel did
	var img := Image.create_from_data(w, h, false, Image.FORMAT_L8, px)
	_mat.set_shader_parameter("bank_tex", ImageTexture.create_from_image(img))
	print("LAVA banks mapped %dx%d in %d ms" % [w, h, (Time.get_ticks_usec() - t0) / 1000])


func _embers() -> void:
	var e := Vfx.emitter(Color(1.6, 0.55, 0.12), {"count": 220, "life": 5.0, "speed": Vector2(0.4, 1.4), "size": 0.05, "gravity": -0.25, "radius": 1.0, "turbulence": true, "explosive": 0.0})
	if e == null:
		return
	e.name = "Embers"
	var pm := e.process_material as ParticleProcessMaterial
	if pm:
		pm = pm.duplicate() as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(_size.x * 0.4, 0.2, _size.y * 0.42)
		e.process_material = pm
	e.visibility_aabb = AABB(Vector3(-_size.x * 0.5, -1, -_size.y * 0.5), Vector3(_size.x, 14, _size.y))
	add_child(e)
	e.global_position = Vector3(_origin.x + _size.x * 0.5, _y + 0.3, _origin.y + _size.y * 0.5)
	e.emitting = true


## Pour falls where a chasm wall rises steepest above the lava (searched, not hand-placed).
func _falls() -> void:
	var space := get_world_3d().direct_space_state
	var picks: Array = []
	for side: float in [-1.0, 1.0]:
		var best := [0.0, Vector3.ZERO, Vector3.ZERO]
		var z := -100.0
		while z <= -20.0:
			var x := 0.0
			var open_x := INF                       # last x over open lava (no collision below)
			while absf(x) < 44.0:
				x += side * 1.0
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, _y - 1, z), Layers.WORLD))
				if hit.is_empty() or (hit.position as Vector3).y < _y + 0.6:
					open_x = x
					continue
				var hy: float = (hit.position as Vector3).y
				var is_ground := String((hit.collider as Node).name).contains("Terrain")
				if is_ground and absf(x) > 6.0 and absf(x - open_x) <= 4.0 and hy > _y + 8.0 and hy - _y > float(best[0]):
					best = [hy - _y, Vector3(open_x + side * 0.8, hy, z), Vector3(-side, 0, 0)]
			z += 4.0
		if float(best[0]) > 0.0:
			picks.append(best)
	for b: Array in picks:
		_fall(b[1], b[2], float(b[0]))


const FALL_W := 3.2
const FALL_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// UV.x across the stream, UV.y metres along it from the source; FALL_AT = metres to the lip.
uniform vec3 hot : source_color = vec3(1.0, 0.36, 0.05);
uniform vec3 core : source_color = vec3(1.0, 0.72, 0.28);
uniform vec3 crust : source_color = vec3(0.16, 0.04, 0.02);
uniform float lip = 5.0;
uniform float total = 20.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }
float n(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	float m = UV.y;
	bool falling = m > lip;
	// slow crawl in the channel, a rush once it pours over the lip
	float run = falling ? (lip * 1.0 + (m - lip) * 0.45) : m;
	float sp = falling ? 3.0 : 0.7;
	float s = n(vec2(UV.x * 5.0, run * 0.9 - TIME * sp)) * 0.6 + n(vec2(UV.x * 11.0, run * 2.1 - TIME * sp * 1.6)) * 0.4;
	// a rounded tongue at the vent: the stream narrows to a point where it wells up
	float taper = mix(0.25, 1.0, smoothstep(0.0, 2.2, m));
	float u = clamp((UV.x - 0.5) / taper + 0.5, 0.0, 1.0);
	float side = falling ? 0.3 : 0.38;
	float edge = smoothstep(0.0, side, u) * smoothstep(1.0, 1.0 - side, u) * step(abs(UV.x - 0.5), 0.5 * taper);
	float src = smoothstep(0.0, 0.8, m);                         // wells up out of the vent
	float heat = falling ? smoothstep(0.25, 0.7, s * (0.55 + 0.45 * edge)) : smoothstep(0.3, 0.75, s);
	float v = heat * edge * src;
	// the channel carries a skin of crust, broken where it speeds up at the lip
	float vein = 1.0 - smoothstep(0.0, 0.08, abs(n(vec2(UV.x * 7.0, run * 1.6 - TIME * sp)) - 0.5));
	vec3 col = falling ? mix(hot, core, smoothstep(0.55, 0.95, s) * edge) : mix(crust, mix(hot, core, smoothstep(0.6, 0.95, s)), clamp(heat * 0.6 + vein * 0.8 + smoothstep(lip - 1.5, lip, m), 0.0, 1.0));
	ALBEDO = col * 1.6;
	ALPHA = clamp(falling ? v * 1.2 : edge * src, 0.0, 1.0);
}"""
## A fall of light into the starwater: threads and streaks of violet and pale light sliding down,
## sparks caught in them, a soft rill in the carved channel above the lip. Same UVs as FALL_SHADER.
const STARFALL_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec3 violet : source_color = vec3(0.36, 0.25, 0.78);
uniform vec3 pale : source_color = vec3(0.72, 0.72, 0.96);
uniform float lip = 5.0;
uniform float total = 20.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }
float n(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	float m = UV.y;
	bool falling = m > lip;
	float sp = falling ? 2.4 : 0.6;
	float taper = mix(0.25, 1.0, smoothstep(0.0, 2.2, m));
	float u = clamp((UV.x - 0.5) / taper + 0.5, 0.0, 1.0);
	float edge = smoothstep(0.0, 0.3, u) * smoothstep(1.0, 0.7, u) * step(abs(UV.x - 0.5), 0.5 * taper);
	float threads = n(vec2(UV.x * 18.0, m * 0.25 - TIME * sp * 0.3));
	float streak = smoothstep(0.55, 0.95, n(vec2(UV.x * 26.0, m * 0.6 - TIME * sp)));
	vec2 sc = vec2(UV.x * 40.0, m * 6.0 - TIME * sp * 6.0);
	float spark = step(0.995, h(floor(sc))) * (1.0 - smoothstep(0.08, 0.34, length((fract(sc) - 0.5) * vec2(1.0, 2.1)))) * (0.5 + 0.5 * sin(TIME * 2.0 + h(floor(sc)) * 40.0)) * smoothstep(0.2, 0.32, abs(UV.x - 0.5));   // a soft round mote that fades, never down the middle of the fall (where the doorway is)
	float body = falling ? (0.22 + 0.45 * threads + 0.55 * streak) : (0.4 + 0.4 * threads);
	float src = smoothstep(0.0, 0.8, m);
	float foot = 1.0 - smoothstep(total - 3.0, total, m) * 0.6;
	ALBEDO = mix(violet, pale, streak * 0.55 + spark) * (0.95 + spark * 1.6);
	ALPHA = clamp(edge * src * body * foot * 0.55 + spark * edge * 0.8, 0.0, 1.0);
}"""
const POOL_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 hot : source_color = vec3(1.0, 0.5, 0.12);
float h(vec2 p){ return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }
float n(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float a = atan(c.y, c.x);
	// churned froth where the fall plunges in: rings running outward, broken by noise
	float rings = 0.5 + 0.5 * sin(r * 14.0 - TIME * 4.0 + n(vec2(a * 3.0, r * 4.0)) * 4.0);
	float froth = n(vec2(a * 4.0 + TIME * 0.5, r * 6.0 - TIME * 2.0));
	float v = (1.0 - smoothstep(0.15, 1.0, r)) * mix(0.35, 1.0, rings * froth);
	ALBEDO = hot * (1.2 + 0.8 * (1.0 - r));
	ALPHA = clamp(v, 0.0, 1.0);
}"""


## A fall is one stream: it wells up from a vent on the shelf above, crawls to the lip, pours over
## and follows the actual cliff face down (sampled with rays at every metre, so it never hangs off
## the rock), plunges half a metre under the river and churns a froth pool where it lands.
## `top` is just past the river's edge at the wall's height, `out` points from the wall to the river.
func _fall(top: Vector3, out: Vector3, _height: float, star := false) -> void:
	var space := get_world_3d().direct_space_state
	var into := -out                                    # from the river towards the wall
	var z := top.z
	var ground := func(x: float, zz: float) -> float:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80, zz), Vector3(x, _y - 2.0, zz), Layers.WORLD))
		return (hit.position as Vector3).y if hit else _y
	# the lip: walking from the river into the wall, where the climb flattens out onto the shelf
	var x0 := top.x - into.x * 0.8
	var lip_x := x0
	var x := x0
	while absf(x - x0) < 16.0:
		x += into.x * 0.25
		var g0: float = ground.call(x, z)
		var g1: float = ground.call(x + into.x * 1.0, z)
		lip_x = x
		if g0 > _y + 6.0 and g1 - g0 < 0.3:
			break
	var lip_y: float = ground.call(lip_x, z)
	# the channel runs back only over ground at or above the lip (never uphill to it), 1.5-5 m
	var back := 1.5
	while back < 5.0 and float(ground.call(lip_x + into.x * (back + 0.5), z)) >= lip_y - 0.05:
		back += 0.5
	# each edge of the stream is sampled on its own, so it lies on the rock across a cross-slope
	var rows: Array = []                                 # per station: [channel x, NAN] or [NAN, face height]
	var lip_row := 0
	var widths: Array[float] = []
	var n_ch := int(back / 0.5)
	for i in n_ch + 1:
		var px := lip_x + into.x * (back - 0.5 * float(i))
		widths.append(lerpf(1.8, 2.6, float(i) / float(maxi(n_ch, 1))))   # widens towards the lip
		rows.append([px, -1.0])
	lip_row = rows.size() - 1
	rows.append([lip_x - into.x * 0.35, -2.0])          # rolling over the lip, not a crease
	widths.append(2.8)
	var hh := lip_y - 0.5
	while hh > _y - 0.6:
		rows.append([NAN, hh])
		widths.append(FALL_W)
		hh -= 0.5                                     # every half metre: no rock bump pokes through
	rows.append([NAN, _y - 0.6])
	widths.append(FALL_W + 0.4)
	var edge_pts: Array = [[], []]
	for e in 2:
		var last := lip_x
		for i in rows.size():
			var w: float = widths[i] * (-0.5 if e == 0 else 0.5)
			var ze := z + w
			var r: Array = rows[i]
			if not is_nan(float(r[0])):
				var px: float = r[0]
				if float(r[1]) == -2.0:
					(edge_pts[e] as Array).append(Vector3(px, maxf(lip_y - 0.12, float(ground.call(px, ze)) + 0.12), ze))
					continue
				var lift := 0.06 if i < lip_row else 0.1
				(edge_pts[e] as Array).append(Vector3(px, float(ground.call(px, ze)) + lift, ze))
				continue
			var h: float = r[1]
			# (the ray starts well out over the river: a building stood against the wall, the Pilgrims' Chapel, is hit from outside)
			var from := Vector3(x0 - into.x * 10.0, h, ze)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + into * 37.0, Layers.WORLD))
			if hit and absf((hit.position as Vector3).x - lip_x) < 30.0:        # (a building stood out from the wall is further off than rock)
				last = (hit.position as Vector3).x
			# never deeper into the rock than the lip: the sheet would fold back on itself
			if (last - lip_x) * into.x > 0.0:
				last = lip_x
			(edge_pts[e] as Array).append(Vector3(last + out.x * 0.4, h, ze))
	var lip := Vector3(lip_x, lip_y, z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := 0.0
	var lip_m := 0.0
	var ms: Array[float] = [0.0]
	for i in range(1, rows.size()):
		var c0: Vector3 = ((edge_pts[0][i - 1] as Vector3) + (edge_pts[1][i - 1] as Vector3)) * 0.5
		var c1: Vector3 = ((edge_pts[0][i] as Vector3) + (edge_pts[1][i] as Vector3)) * 0.5
		m += c0.distance_to(c1)
		ms.append(m)
		if i == lip_row:
			lip_m = m
	for i in rows.size() - 1:
		var v := [edge_pts[0][i], edge_pts[1][i], edge_pts[1][i + 1], edge_pts[0][i + 1]]
		var uv := [Vector2(0, ms[i]), Vector2(1, ms[i]), Vector2(1, ms[i + 1]), Vector2(0, ms[i + 1])]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.add_vertex(v[k])
	var foot_x: float = ((edge_pts[0][rows.size() - 1] as Vector3).x + (edge_pts[1][rows.size() - 1] as Vector3).x) * 0.5 - out.x * 0.4
	var path: Array[Vector3] = [((edge_pts[0][0] as Vector3) + (edge_pts[1][0] as Vector3)) * 0.5]
	var mi := MeshInstance3D.new()
	mi.name = ("StarFall%d" if star else "LavaFall%d") % get_child_count()
	mi.mesh = st.commit()
	var sh := Shader.new()
	sh.code = STARFALL_SHADER if star else FALL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("lip", lip_m)
	mat.set_shader_parameter("total", m)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	add_child(mi)
	# froth pool where it lands, and the splash
	var foot := Vector3(foot_x + out.x * 1.4, _y + 0.04, z)
	var pool := MeshInstance3D.new()
	pool.name = ("StarFallPool%d" if star else "LavaFallPool%d") % get_child_count()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6.5, 6.5) if star else Vector2(5.5, 5.5)
	pool.mesh = pm
	var psh := Shader.new()
	psh.code = POOL_SHADER.replace("vec3(1.0, 0.5, 0.12)", "vec3(0.55, 0.42, 1.0)").replace("render_mode unshaded,", "render_mode unshaded, blend_add,") if star else POOL_SHADER
	var pmat := ShaderMaterial.new()
	pmat.shader = psh
	pool.material_override = pmat
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	pool.global_position = foot
	var splash := Vfx.emitter(Color(0.8, 0.7, 1.8), {"count": 44, "life": 2.2, "speed": Vector2(0.4, 1.5), "size": 0.06, "gravity": -0.5, "radius": 1.4, "spread": 40.0, "turbulence": true}) if star \
		else Vfx.emitter(Color(1.8, 0.6, 0.1), {"count": 60, "life": 0.9, "speed": Vector2(1.0, 3.5), "size": 0.08, "gravity": 6.0, "radius": 1.2, "spread": 50.0})
	if splash:
		add_child(splash)
		splash.global_position = foot
		splash.emitting = true
	# the vent it wells out of
	var vent := Vfx.emitter(Color(0.7, 0.6, 1.6) if star else Color(1.6, 0.5, 0.1), {"count": 24, "life": 2.2, "speed": Vector2(0.3, 1.0), "size": 0.05, "gravity": -0.4, "radius": 0.8, "turbulence": true})
	if vent:
		add_child(vent)
		vent.global_position = path[0] + Vector3.UP * 0.1
		vent.emitting = true
	print("LAVA fall from %s over the lip at %s to the river (%.1f m of stream)" % [path[0].snapped(Vector3.ONE * 0.1), lip.snapped(Vector3.ONE * 0.1), m])

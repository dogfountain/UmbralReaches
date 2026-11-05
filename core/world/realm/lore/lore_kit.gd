extends RefCounted
## Shared builder for RealmLore's landmarks (no class_name: preload by path). One LoreKit per
## landmark: a holder node (meta "site", so StoneBodies leaves it alone and audits count it as a
## site's own), two OssKits (`k` architecture, always drawn; `p` small props, visibility-ranged),
## the ground sampler, site registration, inscriptions and the shared light budget.
## Everything is world space; holders sit at the origin.

const Inscription := preload("res://core/world/realm/lore/inscription.gd")
const LoreDB := preload("res://core/world/realm/lore_db.gd")
const LoreIndex := preload("res://core/world/realm/lore/lore_index.gd")
const LA := preload("res://core/world/realm/lore/lore_assets.gd")
const T := "res://art/textures/"
const KIT_PATH := "res://core/world/realm/lore/lore_kit.gd"
const UNIT_BOULDER := Vector3(1.0, 0.8, 0.9)     ## shared RockKit boulders, scaled per stone
const UNIT_SLAB := Vector3(0.6, 1.2, 0.25)
const MAX_LIGHTS := 12
const PROP_RANGE := 70.0           ## small props fade out past this

static var lights_used := 0
static var draws_total := 0                     ## mesh + multimesh instances added (all landmarks)
static var scraps: Array[String] = []           ## lore ids placed
static var site_names: Array[String] = []       ## sites this module registered
static var landmarks: Array[Dictionary] = []    ## {name, at, sites} for the report/test
static var _statues: Dictionary = {}
static var _rockkit: GDScript = null
static var _rk_checked := false
static var _pool: Dictionary = {}                ## small organic meshes shared by every landmark


## Drop the engine resources held in static vars (called when the night is torn down): statics
## outlive the renderer at quit ("RID allocations leaked at exit"). Rebuilt on next use.
static func release() -> void:
	_statues.clear()
	_pool.clear()

var holder: Node3D
var k := OssKit.new()
var p := OssKit.new()
var space: PhysicsDirectSpaceState3D
var rng := RandomNumberGenerator.new()
var my_sites: Array[String] = []
var _rocks: Dictionary = {}        ## RockKit mesh -> [[Transform3D, collide], ...] (MultiMeshes at finish)
var _mb: Dictionary = {}           ## material key -> LA.MB (UV-mapped quads: carved panels)
var _uvm: Dictionary = {}          ## material key -> SurfaceTool (appended UV meshes: thatch, slates)
var _uv_props: Dictionary = {}     ## material keys drawn as props (visibility-ranged)
var _plain: Array = []             ## [centre, normal, w, h, cell]: unlit carvings, unless letters() claims the face


static func begin(parent: Node, node_name: String, seed_n: int) -> RefCounted:
	ensure_mats()
	var lk: RefCounted = (load("res://core/world/realm/lore/lore_kit.gd") as GDScript).new()
	var h := Node3D.new()
	h.name = node_name
	h.set_meta("site", node_name.to_snake_case())
	parent.add_child(h)
	lk.set("holder", h)
	lk.set("space", h.get_world_3d().direct_space_state)
	(lk.get("rng") as RandomNumberGenerator).seed = seed_n
	(lk.get("k") as OssKit).keep_lanes = false
	(lk.get("p") as OssKit).keep_lanes = false
	return lk


static func reset() -> void:
	lights_used = 0
	draws_total = 0
	scraps.clear()
	site_names.clear()
	landmarks.clear()


# --- materials ------------------------------------------------------------------------------

## Extra materials, registered into OssKit's cache under "lore_*" keys so OssKit.commit() finds them.
static func ensure_mats() -> void:
	if OssKit._mats.has("lore_statue"):
		return
	# weathered stone (lore_assets STONE_SHADER): moss on the tops, damp at the foot, streaks
	OssKit._mats["lore_statue"] = LA.stone("oss_statue", 0.55, Color(0.9, 0.88, 0.86), 0.32, 0.25, 0.7)
	OssKit._mats["lore_moss"] = LA.stone("rockkit", 0.42, Color(1.0, 1.05, 0.92), 0.95, 0.7, 0.4)
	OssKit._mats["lore_rock"] = LA.stone("rockkit", 0.36, Color(1.05, 1.02, 0.98), 0.3, 0.3, 0.4)
	OssKit._mats["lore_tstone"] = LA.stone("oss_statue", 0.45, Color(1.18, 1.12, 1.04), 0.45, 0.4, 0.55)
	OssKit._mats["lore_rubble"] = LA.stone("oss_ashlar", 0.36, Color(1.4, 1.32, 1.22), 0.45, 0.45, 0.55)
	OssKit._mats["lore_tslate"] = LA.stone("oss_slate", 0.5, Color(1.7, 1.72, 1.8), 0.55, 0.0, 0.25)
	OssKit._mats["lore_plaster"] = LA.stone("oss_plaster", 0.4, Color(0.92, 0.88, 0.8), 0.0, 0.55, 0.8)
	OssKit._mats["lore_ashlar"] = LA.stone("oss_ashlar", 0.32, Color(1.3, 1.25, 1.2), 0.5, 0.45, 0.6)
	OssKit._mats["lore_slates"] = LA.stone("oss_slate", 1.3, Color(1.6, 1.62, 1.7), 0.5, 0.0, 0.0)
	OssKit._mats["lore_carve"] = LA.carve(false)
	OssKit._mats["lore_carve_cold"] = LA.carve(true)
	OssKit._mats["lore_carve_plain"] = LA.carve_plain()
	OssKit._mats["lore_thatch_uv"] = LA.thatch()
	OssKit._mats["lore_earth"] = _tri_mat("ground", 0.3, Color(0.6, 0.62, 0.54))
	OssKit._mats["lore_soil"] = _tri_mat("ground", 0.6, Color(0.36, 0.3, 0.26))
	OssKit._mats["lore_thatch"] = _tri_mat("bark", 0.9, Color(0.62, 0.52, 0.36))
	OssKit._mats["lore_char"] = _tri_mat("bark", 0.8, Color(0.17, 0.15, 0.14))
	OssKit._mats["lore_beam"] = _tri_mat("tavern_beam", 0.6, Color(1.5, 1.38, 1.25))
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.5, 0.4, 0.26)
	bronze.metallic = 0.35
	bronze.roughness = 0.5
	bronze.vertex_color_use_as_albedo = true
	bronze.rim_enabled = true
	bronze.rim = 0.2
	OssKit._mats["lore_bronze"] = bronze
	var cloth := StandardMaterial3D.new()
	cloth.albedo_texture = load(T + "dwarf_cloth_albedo.png")
	cloth.vertex_color_use_as_albedo = true
	cloth.roughness = 0.95
	cloth.uv1_triplanar = true
	cloth.uv1_world_triplanar = true
	cloth.uv1_scale = Vector3.ONE * 2.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	OssKit._mats["lore_cloth"] = cloth
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.78, 0.72, 0.6)
	paper.vertex_color_use_as_albedo = true
	paper.roughness = 0.9
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.rim_enabled = true
	paper.rim = 0.2
	OssKit._mats["lore_paper"] = paper
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.3, 0.34, 0.22)
	leaf.vertex_color_use_as_albedo = true
	leaf.roughness = 0.9
	OssKit._mats["lore_leaf"] = leaf
	# carved letters: a faint ember in the cut, well under the glow threshold (a cue, not a lamp)
	var rune := StandardMaterial3D.new()
	rune.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rune.albedo_color = Color(0.95, 0.45, 0.22)
	rune.vertex_color_use_as_albedo = true
	OssKit._mats["lore_rune"] = rune
	var cold := StandardMaterial3D.new()
	cold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cold.albedo_color = Color(0.45, 0.85, 0.95)
	cold.vertex_color_use_as_albedo = true
	OssKit._mats["lore_cold"] = cold
	var ember := StandardMaterial3D.new()
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.albedo_color = Color(1.0, 0.42, 0.12)
	ember.vertex_color_use_as_albedo = true
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.35, 0.08)
	ember.emission_energy_multiplier = 0.9
	OssKit._mats["lore_ember"] = ember


static func _tri_mat(tex: String, scale: float, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(T + tex + "_albedo.png")
	m.albedo_color = tint
	if ResourceLoader.exists(T + tex + "_normal.png"):
		m.normal_enabled = true
		m.normal_texture = load(T + tex + "_normal.png")
	if ResourceLoader.exists(T + tex + "_rough.png"):
		m.roughness_texture = load(T + tex + "_rough.png")
	if ResourceLoader.exists(T + tex + "_ao.png"):
		m.ao_enabled = true
		m.ao_texture = load(T + tex + "_ao.png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.vertex_color_use_as_albedo = true
	return m


# --- ground, sites, placement ---------------------------------------------------------------

func g(x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


func gv(x: float, z: float) -> Vector3:
	return Vector3(x, g(x, z), z)


## (min, max) ground under a rect, sampled every metre.
func g_range(r: Rect2) -> Vector2:
	var lo := INF
	var hi := -INF
	var nx := maxi(1, ceili(r.size.x))
	var nz := maxi(1, ceili(r.size.y))
	for i in nx + 1:
		for j in nz + 1:
			var y := g(r.position.x + r.size.x * float(i) / float(nx), r.position.y + r.size.y * float(j) / float(nz))
			lo = minf(lo, y)
			hi = maxf(hi, y)
	return Vector2(lo, hi)


## Register a WorldLanes site. Without `cut_y` the site never cuts the ground (an open-air landmark
## standing on the land as it is: graves, walls, waystones); buildings pass their own cut height.
func site(n: String, r: Rect2, floor_y: float, cut_y := NAN, hard := false) -> void:
	if is_nan(cut_y):
		cut_y = g_range(r).y + 0.5
	WorldLanes.register_site(n, r, floor_y, cut_y, hard)
	if not n in site_names:
		site_names.append(n)
		my_sites.append(n)


## True when a footprint keeps `margin` off every path and every registered site (other modules'
## and this module's own, except `ignore`).
static func clear_of(r: Rect2, margin := 1.0, ignore: Array = []) -> bool:
	var pts: Array[Vector2] = [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]
	var step := 1.5
	var x := r.position.x
	while x <= r.end.x:
		pts.append(Vector2(x, r.position.y))
		pts.append(Vector2(x, r.end.y))
		x += step
	var z := r.position.y
	while z <= r.end.y:
		pts.append(Vector2(r.position.x, z))
		pts.append(Vector2(r.end.x, z))
		z += step
	for q in pts:
		if RealmLayout.path_dist(q) < margin:
			return false
	for s in WorldLanes.sites:
		if String(s.name) in ignore:
			continue
		# r34: the raid floors by their circle (their 60 m boxes took the hill round them); every other
		# site by its box, as before, so the lore elsewhere stands exactly where it stood
		if WorldLanes.site_hits_rect(s, r, margin) if String(s.name).begins_with("raid_") else (s.rect as Rect2).grow(margin).intersects(r):
			return false
	return true


## What keeps a footprint from being clear (debug): "path" or the first site's name, or "".
static func blocker(r: Rect2, margin := 1.0) -> String:
	for q in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
		if RealmLayout.path_dist(q) < margin:
			return "path"
	for s in WorldLanes.sites:
		if (s.rect as Rect2).grow(margin).intersects(r):
			return String(s.name)
	return ""


## Register a small site round a point prop (square, `half` metres), floor at the local ground.
## Returns false (and registers nothing) when the spot is not clear.
func spot(n: String, at: Vector3, half := 0.8, margin := 0.6) -> bool:
	var r := Rect2(at.x - half, at.z - half, half * 2.0, half * 2.0)
	if not clear_of(r, margin):
		print("REALM_LORE skip %s at %s (not clear)" % [n, at.snapped(Vector3.ONE * 0.1)])
		return false
	site(n, r, at.y)
	return true


## Point on polyline `pts` (Vector2) at arc length `s`: [position, unit tangent].
static func along(pts: Array, s: float) -> Array:
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ln := a.distance_to(b)
		if acc + ln >= s or i == pts.size() - 2:
			var t := clampf((s - acc) / maxf(ln, 0.001), 0.0, 1.0)
			return [a.lerp(b, t), (b - a).normalized()]
		acc += ln
	return [pts[0], Vector2.RIGHT]


static func path_pts(id: String) -> Array:
	for p in RealmLayout.PATHS:
		if String(p.id) == id:
			return p.pts
	return []


## Point `off` metres to one side (+1 / -1) of path `id` at arc length `s`.
static func beside_path(id: String, s: float, side: float, off: float) -> Vector2:
	var a := along(path_pts(id), s)
	var t: Vector2 = a[1]
	return (a[0] as Vector2) + Vector2(-t.y, t.x) * side * off


## Search outward from `prefer` (rings every `step` m up to `radius`) for the nearest footprint
## (half extents `half`, centred on the point) that is clear of paths and sites (`margin`, sites
## named in `ignore` excepted) and whose ground varies by at most `max_rise`. `ok` (optional,
## Vector2 -> bool) can veto a point. Returns the xz, or Vector2.INF.
static func search_spot(space: PhysicsDirectSpaceState3D, prefer: Vector2, radius: float, half: Vector2, margin: float, max_rise: float, ignore: Array = [], step := 3.0, ok := Callable()) -> Vector2:
	var r := 0.0
	while r <= radius:
		var n := 1 if r == 0.0 else maxi(6, int(TAU * r / step))
		for i in n:
			var a := TAU * float(i) / float(n) + r * 0.37
			var q := prefer + Vector2(cos(a), sin(a)) * r
			var rc := Rect2(q - half, half * 2.0)
			if not RealmLayout.BOUNDS.grow(-8.0).encloses(rc):
				continue
			if ok.is_valid() and not bool(ok.call(q)):
				continue
			if not clear_of(rc, margin, ignore):
				continue
			var lo := INF
			var hi := -INF
			for ix in 3:
				for iz in 3:
					var y := RealmLayout.ground(space, rc.position.x + rc.size.x * float(ix) * 0.5, rc.position.y + rc.size.y * float(iz) * 0.5)
					lo = minf(lo, y)
					hi = maxf(hi, y)
			if hi - lo <= max_rise:
				return q
		r += step
	return Vector2.INF


## The first clear candidate (xz) as a registered spot site: its ground point, or Vector3.INF.
func spot_any(n: String, candidates: Array, half := 0.9, margin := 0.6, max_rise := 0.8) -> Vector3:
	for q: Vector2 in candidates:
		var at := gv(q.x, q.y)
		var r := Rect2(q.x - half, q.y - half, half * 2.0, half * 2.0)
		if clear_of(r, margin) and (g_range(r.grow(0.6)) as Vector2).y - (g_range(r.grow(0.6)) as Vector2).x <= max_rise:
			site(n, r, at.y)
			return at
	print("REALM_LORE skip %s (no clear spot of %d)" % [n, candidates.size()])
	return Vector3.INF


## A stele of the Order: a tall slab on a step, gabled, the Open Door carved over a lettered
## panel. Faces `yaw` (its text looks along local -z). Returns the panel centre.
func stele(at: Vector3, yaw: float, h := 2.1, key := "lore_tstone") -> Vector3:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, rng.randf_range(-0.03, 0.03))
	var base := at + Vector3.DOWN * 0.3
	k.box(key, base + b * Vector3(0, 0.25, 0), Vector3(1.25, 0.5, 0.7), b, true, 0.82)
	k.box(key, base + b * Vector3(0, 0.3 + h * 0.5, 0), Vector3(0.9, h, 0.32), b, true)
	half_disc(k, key, Transform3D(b, base + b * Vector3(0, 0.3 + h, 0)), 0.48, 0.0, 0.36, 2, true, 0.9)
	k.box(key, base + b * Vector3(0, 0.3 + h - 0.02, 0), Vector3(1.0, 0.08, 0.4), b, false, 0.85)
	var face := base + b * Vector3(0, 0.3 + h * 0.48, -0.165)
	panel(face, -b.z, 0.7, 0.8, LA.C_TEXT2)
	panel(base + b * Vector3(0, 0.3 + h * 0.86, -0.165), -b.z, 0.42, 0.42, LA.C_DOOR)
	cairn(p, at + b * Vector3(0.62, 0, -0.42), 0.35)
	return face


func note(n: String, at: Vector3) -> void:
	landmarks.append({"name": n, "at": at, "sites": my_sites.duplicate()})


# --- inscriptions and lights ----------------------------------------------------------------

## A readable carrier for LoreDB entry `id` at `at` (its sense sphere centre). The visual is built
## by the caller into the kit; this only adds the interactable.
func scrap(id: String, at: Vector3, mark := Vector3.INF) -> Node3D:
	if LoreIndex.entry(id).is_empty():
		push_error("RealmLore: no lore entry " + id)
		return null
	var s := Inscription.make(id)
	var gy := g(at.x, at.z)
	if at.y < gy + 0.15:
		at.y = gy + 0.3              # never under the ground (slopes, mounds)
	s.position = at                  # holders sit at the origin: local == world
	s.set("mark", mark)
	holder.add_child(s)
	if not id in scraps:
		scraps.append(id)
	return s


func light(n: String, at: Vector3, col: Color, e: float, r: float) -> OmniLight3D:
	if lights_used >= MAX_LIGHTS:
		return null
	lights_used += 1
	var l := OmniLight3D.new()
	l.name = n
	l.light_color = col
	l.omni_range = r
	l.light_energy = e
	l.shadow_enabled = false
	l.set_meta(&"light_class", "fill")
	l.set_meta(&"base", {"e": e, "r": r, "a": 1.0})
	holder.add_child(l)
	l.global_position = at
	LightPolicy.apply_fade(l)
	LightPolicy.apply_illumination(l)
	l.shadow_enabled = false
	return l


## Commit both kits under the holder. Prop meshes fade out past PROP_RANGE; every MultiMesh is
## marked site-owned so WorldLanes.cull_scatter never thins this landmark's own candles.
func finish() -> int:
	for pl: Array in _plain:
		panel(pl[0], pl[1], pl[2], pl[3], pl[4], false, Vector3.ZERO, true)
	_plain.clear()
	var draws := k.commit(holder, "Body") + _commit_rocks()
	var props := Node3D.new()
	props.name = "Props"
	holder.add_child(props)
	draws += p.commit(props, "PropBody")
	for key: String in _uvm:
		var mi := MeshInstance3D.new()
		mi.name = "UV_" + key
		mi.mesh = (_uvm[key] as SurfaceTool).commit()
		mi.material_override = OssKit.mat(key)
		(props if _uv_props.has(key) else holder).add_child(mi)
		draws += 1
	for key: String in _mb:
		var mi2 := MeshInstance3D.new()
		mi2.name = "Carved_" + key
		mi2.mesh = (_mb[key]).commit()
		mi2.material_override = OssKit.mat(key)
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		props.add_child(mi2)
		draws += 1
	for c in props.get_children():
		var gi := c as GeometryInstance3D
		if gi and gi.visibility_range_end <= 0.0:
			gi.visibility_range_end = PROP_RANGE
			gi.visibility_range_end_margin = 8.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for mmi in holder.find_children("*", "MultiMeshInstance3D", true, false):
		mmi.set_meta("site_owned", true)
	draws_total += draws
	return draws


# --- RockKit (assets module) ----------------------------------------------------------------

## The assets module's RockKit script, if present (loaded by path; no class_name).
static func rk() -> GDScript:
	if not _rk_checked:
		_rk_checked = true
		if ResourceLoader.exists("res://core/world/realm/rock_kit.gd"):
			var s := load("res://core/world/realm/rock_kit.gd") as GDScript
			if s and s.can_instantiate():
				_rockkit = s
	return _rockkit


static func style_of(key: String) -> String:
	return "mossy" if key == "lore_moss" else "granite"


## Queue a RockKit mesh instance (drawn as one MultiMesh per mesh at finish; convex collision).
func rock(mesh: Mesh, xf: Transform3D, collide := false) -> void:
	if not _rocks.has(mesh):
		_rocks[mesh] = []
	(_rocks[mesh] as Array).append([xf, collide])


func _commit_rocks() -> int:
	if _rocks.is_empty():
		return 0
	var node := Node3D.new()
	node.name = "Rocks"
	holder.add_child(node)
	var body := StaticBody3D.new()
	body.name = "RockBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	node.add_child(body)
	var n := 0
	for mesh: Mesh in _rocks:
		var xfs: Array = []
		var big := mesh.get_aabb().size.length() > 2.0
		for it: Array in _rocks[mesh]:
			xfs.append(it[0])
			if it[1]:
				var cs := CollisionShape3D.new()
				cs.shape = rk().call("collision_shape", mesh)
				cs.transform = it[0]
				body.add_child(cs)
		var mmi := OssKit.multimesh(mesh, xfs, null, big)
		mmi.name = "Rock%d" % n
		mmi.visibility_range_end = 140.0 if big else 60.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.set_meta("site_owned", true)
		node.add_child(mmi)
		n += 1
	return n


# --- UV meshes: roofs, carved panels ---------------------------------------------------------

## Append a UV-mapped mesh (lore_assets builders) into this landmark's surface for `key`.
func uv_add(key: String, mesh: ArrayMesh, xf: Transform3D, as_prop := false) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	if not _uvm.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_uvm[key] = st
	(_uvm[key] as SurfaceTool).append_from(mesh, 0, xf)
	if as_prop:
		_uv_props[key] = true


## A carved panel: atlas cell `cell` (LA.C_*) on a face centred at `c` with outward normal `n`,
## `w` x `h` metres, standing a few mm proud. `cold` = the Rooted's work (cold glint in the cuts).
## For a face lying flat (n up), `top` says which way the panel's top edge points.
func panel(c: Vector3, n: Vector3, w: float, h: float, cell: int, cold := false, top := Vector3.ZERO, plain := false) -> void:
	var key := "lore_carve_plain" if plain else ("lore_carve_cold" if cold else "lore_carve")
	if not _mb.has(key):
		_mb[key] = LA.MB.new()
	var nn := n.normalized()
	var up := Vector3.UP
	if top != Vector3.ZERO:
		up = top.normalized()
	elif absf(nn.y) > 0.85:
		up = Vector3.FORWARD
	var right := (-nn).cross(up).normalized()
	var vup := nn.cross(right).normalized()
	var r := LA.cell_uv(cell)
	var o := c + nn * 0.006
	var a := o - right * (w * 0.5) + vup * (h * 0.5)
	var b := o + right * (w * 0.5) + vup * (h * 0.5)
	var cc := o + right * (w * 0.5) - vup * (h * 0.5)
	var d := o - right * (w * 0.5) - vup * (h * 0.5)
	(_mb[key]).quad(a, b, cc, d, nn, r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y))


## A small organic mesh shared by every landmark (built once per run): tufts, pebbles, plants, logs.
static func pooled(key: String, fn: Callable) -> ArrayMesh:
	if not _pool.has(key):
		_pool[key] = fn.call()
	return _pool[key]


# --- solid organic meshes -------------------------------------------------------------------

## Add an organic mesh (CreatureMesh output) to kit `kit` and, if `solid`, its triangles to the
## kit's collision soup.
static func organic(kit: OssKit, key: String, mesh: ArrayMesh, xf: Transform3D, solid := false) -> void:
	kit.append_mesh(key, mesh, xf)
	if solid:
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			for q in v:
				kit.col_faces.append(xf * q)
		else:
			for i in idx:
				kit.col_faces.append(xf * v[i])


# --- small shapes ---------------------------------------------------------------------------

## A prism whose front/back faces are a half disc of radius r (n segments) sitting on local y0,
## thickness t along local z, in frame xf. n = 2 makes a gable (pointed top).
static func half_disc(kit: OssKit, key: String, xf: Transform3D, r: float, y0: float, t: float, n := 8, solid := true, shade := 1.0) -> void:
	var b := xf.basis
	var fz := b.z.normalized()
	var pts: Array[Vector3] = []
	for i in n + 1:
		var a := PI * float(i) / float(n)
		pts.append(Vector3(cos(a) * r, y0 + sin(a) * r, 0.0))
	for s: float in [-1.0, 1.0]:
		var off := Vector3(0, 0, s * t * 0.5)
		for i in n:
			kit.quad(key, xf * (Vector3(0, y0, 0) + off), xf * (pts[i] + off), xf * (pts[i + 1] + off), xf * (Vector3(0, y0, 0) + off), fz * s, solid, shade)
	for i in n:
		var a0 := pts[i]
		var a1 := pts[i + 1]
		var mid := (a0 + a1) * 0.5 - Vector3(0, y0, 0)
		var out := (b * Vector3(mid.x, mid.y, 0)).normalized()
		var h := Vector3(0, 0, t * 0.5)
		kit.quad(key, xf * (a0 - h), xf * (a1 - h), xf * (a1 + h), xf * (a0 + h), out, solid, shade * 0.95)


## Collision only (no visual): an oriented box into the kit's collision soup.
static func col_box(kit: OssKit, c: Vector3, size: Vector3, b: Basis) -> void:
	kit._box_col(c, b.x.normalized() * size.x * 0.5, b.y.normalized() * size.y * 0.5, b.z.normalized() * size.z * 0.5)


## A tumble of rough stones (rubble) around `at` over radius r.
func rubble(kit: OssKit, at: Vector3, r: float, n: int, key := "lore_tstone", solid := false) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var s := rng.randf_range(0.18, 0.5) * (1.0 - d / r * 0.5)
		var q := Vector3(at.x + cos(a) * d, 0.0, at.z + sin(a) * d)
		q.y = g(q.x, q.z) + s * 0.25 + (r - d) * 0.12 * rng.randf()
		var bas := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		kit.box(key, q, Vector3(s * 1.4, s * 0.8, s), bas, solid and s > 0.3, rng.randf_range(0.75, 1.0))


## A lumpy field stone (CreatureMesh blob) on the ground.
func stone(kit: OssKit, at: Vector3, size: Vector3, key := "lore_moss", solid := false, sink := 0.35) -> void:
	if rk() and maxf(size.x, maxf(size.y, size.z)) >= 0.3:
		# six shared boulders per style, scaled per stone: one MultiMesh draw for many stones
		var m: Mesh = rk().call("boulder", rng.randi() % 6, UNIT_BOULDER, style_of(key))
		var yb := Basis(Vector3.UP, rng.randf() * TAU)
		var o := at + Vector3.DOWN * (size.y * sink * 0.6)
		rock(m, Transform3D(yb * Basis.from_scale(size / UNIT_BOULDER), o), false)
		if solid:
			col_box(k, o + Vector3.UP * (size.y * 0.3), size * 0.8, yb)
		return
	var cm := CreatureMesh.new(rng.randi())
	cm.blob(Vector3.ZERO, size * 0.5, Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.22, 0.0, 6, 9)
	var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))), at + Vector3.UP * (size.y * (0.5 - sink)))
	organic(kit, key, cm.commit(), xf, solid)


## Pebble cairn (pilgrims' stones) at the foot of something.
func cairn(kit: OssKit, at: Vector3, h := 0.6, key := "lore_rock") -> void:
	var y := at.y
	var r := h * 0.55
	var layer := 0
	while r > 0.06 and layer < 6:
		var n := maxi(1, int(r * 9.0))
		for i in n:
			var a := TAU * float(i) / float(n) + rng.randf() * 0.5
			var s := clampf(r * 0.7, 0.07, 0.24) * rng.randf_range(0.8, 1.2)
			var q := at + Vector3(cos(a) * r * 0.7, 0.0, sin(a) * r * 0.7)
			q.y = y + s * 0.35
			if n == 1:
				q = Vector3(at.x, y + s * 0.4, at.z)
			var pv := rng.randi() % 8
			var peb := pooled("pebble%d" % pv, func() -> ArrayMesh:
				var cm := CreatureMesh.new(700 + pv)
				cm.blob(Vector3.ZERO, Vector3(0.6, 0.38, 0.5), Basis.IDENTITY, Color(1, 1, 1).darkened(0.035 * float(pv)), 0.0, 0.15, 0.0, 4, 7)
				return cm.commit())
			organic(kit, key, peb, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), q))
		y += clampf(r * 0.7, 0.07, 0.24) * 0.62
		r *= 0.62
		layer += 1


# --- grave markers, waystones, tablets ------------------------------------------------------

## Headstone at ground point `at`, facing `yaw` (its inscribed face looks along local -z rotated).
## style: 0 round-top, 1 cross, 2 gabled, 3 broken slab, 4 rough fen marker. Returns the face
## centre (for an inscription). `tilt` leans it (x forward/back, z sideways, radians).
func headstone(at: Vector3, yaw: float, style: int, h := 1.0, tilt := Vector2.ZERO, key := "lore_tstone", mound := false) -> Vector3:
	var lean := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt.x) * Basis(Vector3.BACK, tilt.y)
	var bury := 0.3
	var base := at + Vector3.DOWN * bury
	var xf := Transform3D(lean, base)
	var w := h * 0.55
	var t := 0.12 + h * 0.04
	match style:
		0:
			var body := h + bury - w * 0.5
			k.box(key, xf * Vector3(0, body * 0.5, 0), Vector3(w, body, t), lean, true)
			half_disc(k, key, xf, w * 0.5, body, t, 9, true)
			# a sunk panel border on the face
			k.box(key, xf * Vector3(0, body * 0.62, -t * 0.5), Vector3(w * 0.72, body * 0.42, 0.03), lean, false, 0.82)
		1:
			k.box(key, xf * Vector3(0, (h + bury) * 0.5, 0), Vector3(w * 0.32, h + bury, t), lean, true)
			k.box(key, xf * Vector3(0, bury + h * 0.68, 0), Vector3(w * 1.05, w * 0.3, t), lean, true)
			k.box(key, xf * Vector3(0, bury * 0.6, 0), Vector3(w * 0.8, 0.22, t + 0.14), lean, false, 0.85)
		2:
			var body2 := h + bury - w * 0.32
			k.box(key, xf * Vector3(0, body2 * 0.5, 0), Vector3(w, body2, t), lean, true)
			half_disc(k, key, xf, w * 0.5, body2, t, 2, true)
			k.box(key, xf * Vector3(0, body2 + 0.02, 0), Vector3(w * 1.12, 0.06, t + 0.06), lean, false, 0.85)
		3:
			# broken: a slab sheared off at an angle, the top piece lying in front
			var hh := h * 0.6 + bury
			k.box(key, xf * Vector3(0, hh * 0.5, 0), Vector3(w, hh, t), lean, true)
			k.box(key, xf * Vector3(w * 0.18, hh, 0), Vector3(w * 0.6, 0.14, t), lean * Basis(Vector3.BACK, 0.35), false)
			var lay := at + Basis(Vector3.UP, yaw) * Vector3(0.1, 0.06, -0.55)
			k.box(key, lay, Vector3(w, t, h * 0.45), Basis(Vector3.UP, yaw + rng.randf_range(-0.4, 0.4)), false, 0.9)
		_:
			if rk():
				var m: Mesh = rk().call("slab", rng.randi() % 6, UNIT_SLAB, style_of(key), 0.35, true)
				var ssz := Vector3(w * 0.85, h + bury, t * 1.4)
				rock(m, Transform3D(lean * Basis(Vector3.UP, PI) * Basis.from_scale(ssz / UNIT_SLAB), base), false)
				col_box(k, base + lean * Vector3(0, ssz.y * 0.5, 0), ssz * Vector3(0.85, 1.0, 0.85), lean)
			else:
				var cm := CreatureMesh.new(rng.randi())
				cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, (h + bury) * 0.55, 0), Vector3(0.02, h + bury, 0)]), PackedFloat32Array([w * 0.42, w * 0.38, w * 0.22]), 7, Color(1, 1, 1), 0.0, 0.25, 0.0, Vector2(1.0, 0.45))
				organic(k, "lore_moss", cm.commit(), xf, true)
	if style == 0 or style == 2 or style == 3:
		var ph := h * (0.3 if style == 3 else 0.42)
		var py := bury + h * (0.3 if style == 3 else 0.5)
		_plain.append([xf * Vector3(0, py, -t * 0.5), lean * Vector3(0, 0, -1), w * 0.66, ph, LA.C_TEXT if rng.randf() < 0.5 else LA.C_TEXT2])
	if mound:
		# a grave kerb: a low stone curb round the plot (one side sometimes sunk or missing), the
		# plot itself a slight earth swell inside it
		var yb := Basis(Vector3.UP, yaw)
		var pc := at + yb * Vector3(0, 0, -1.1)
		pc.y = g(pc.x, pc.z)
		for sx: float in [-1.0, 1.0]:
			if rng.randf() < 0.12:
				continue
			p.box(key, pc + yb * Vector3(sx * 0.42, 0.05, 0), Vector3(0.1, 0.26, 1.75), yb * Basis(Vector3.BACK, rng.randf_range(-0.06, 0.06)), false, rng.randf_range(0.8, 0.95))
		p.box(key, pc + yb * Vector3(0, 0.05, -0.85), Vector3(0.94, 0.26, 0.1), yb, false, 0.88)
		var cm2 := CreatureMesh.new(rng.randi())
		cm2.blob(Vector3.ZERO, Vector3(0.36, 0.08, 0.8), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.25, 0.0, 5, 9)
		organic(p, "lore_earth", cm2.commit(), Transform3D(yb, pc + Vector3.DOWN * 0.02))
	# moss and grass tufts at the foot
	for i in 3:
		var a := rng.randf() * TAU
		var tv := rng.randi() % 6
		var tuft := pooled("tuft%d" % tv, func() -> ArrayMesh:
			var cm3 := CreatureMesh.new(900 + tv)
			cm3.blob(Vector3.ZERO, Vector3(0.14, 0.06, 0.12), Basis.IDENTITY, Color(0.7, 0.85, 0.6).darkened(0.08 * float(tv % 3)), 0.0, 0.3, 0.0, 4, 6)
			for bl in 5:
				var ba := TAU * float(bl) / 5.0 + float(tv)
				cm3.tube(PackedVector3Array([Vector3(cos(ba) * 0.04, 0.0, sin(ba) * 0.04), Vector3(cos(ba) * 0.09, 0.12 + 0.03 * float(bl % 2), sin(ba) * 0.09)]), PackedFloat32Array([0.012, 0.002]), 3, Color(0.75, 0.88, 0.55), 0.0, 0.0)
			return cm3.commit())
		organic(p, "lore_leaf", tuft, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), at + Vector3(cos(a) * w * 0.5, 0.0, sin(a) * 0.14)))
	return xf * Vector3(0, bury + h * 0.55, -t * 0.5 - 0.05)


## Carved letters on a face: a sunk, lettered panel (the carve atlas) centred on `c`, on a face
## whose outward normal is `n`, `w` wide, about `rows` lines tall. Ember in the cuts: the night cue
## that it can be read. key "lore_cold" carves the Rooted's runes instead; "lore_paper" keeps
## chalk strokes (a cart's tailboard).
func letters(c: Vector3, n: Vector3, w: float, rows := 3, key := "lore_rune", cell := -1) -> void:
	if key == "lore_paper":
		var side := n.cross(Vector3.UP).normalized()
		var bas := Basis(side, Vector3.UP, n.normalized())
		for i in rows:
			var y := (float(i) - float(rows - 1) * 0.5) * -0.075
			var lw := w * (0.9 if i < rows - 1 else rng.randf_range(0.45, 0.75))
			var x := 0.0 if i < rows - 1 else -(w - lw) * 0.5
			p.box(key, c + side * x + Vector3.UP * y + n * 0.004, Vector3(lw, 0.016, 0.01), bas, false)
		return
	var cold := key == "lore_cold"
	for i in range(_plain.size() - 1, -1, -1):          # this face is read: no unlit twin under it
		if (_plain[i][0] as Vector3).distance_to(c) < 0.3:
			_plain.remove_at(i)
	if cell < 0:
		cell = (LA.C_RUNES if rng.randf() < 0.5 else LA.C_SPIRAL) if cold else (LA.C_TEXT if rng.randf() < 0.55 else LA.C_TEXT2)
	var h := clampf(float(rows) * 0.085 + 0.08, 0.16, w * 1.3)
	panel(c, n, w + 0.06, h, cell, cold)


## Waystone: a tapering milestone with a capstone, a sunk inscription panel facing `face_yaw`
## (the road), a pilgrims' cairn at its foot. Returns the panel centre.
func waystone(at: Vector3, face_yaw: float, h := 1.55, key := "lore_tstone") -> Vector3:
	var b := Basis(Vector3.UP, face_yaw) * Basis(Vector3.RIGHT, rng.randf_range(-0.04, 0.04)) * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05))
	var base := at + Vector3.DOWN * 0.35
	var xf := Transform3D(b, base)
	k.box(key, xf * Vector3(0, 0.2, 0), Vector3(0.78, 0.4, 0.62), b, true, 0.85)            # footing
	k.box(key, xf * Vector3(0, 0.35 + h * 0.3, 0), Vector3(0.58, h * 0.6, 0.44), b, true)
	k.box(key, xf * Vector3(0, 0.35 + h * 0.75, 0), Vector3(0.5, h * 0.32, 0.38), b, true, 0.95)
	k.box(key, xf * Vector3(0, 0.35 + h * 0.93, 0), Vector3(0.6, 0.1, 0.48), b, true, 0.88)    # cap
	half_disc(k, key, Transform3D(b, xf * Vector3(0, 0.35 + h * 0.98, 0)), 0.26, 0.0, 0.4, 2, false, 0.9)
	var panel := xf * Vector3(0, 0.35 + h * 0.62, -0.23)
	k.box(key, panel + b.z * 0.012, Vector3(0.4, 0.48, 0.04), b, false, 0.7)
	panel(panel - b.z * 0.012, -b.z, 0.34, 0.42, LA.C_MILE)
	# iron bell hook on the road side
	p.box("iron", xf * Vector3(0.3, 0.35 + h * 0.85, -0.05), Vector3(0.18, 0.03, 0.03), b, false)
	cairn(p, at + b * Vector3(0.55, 0.0, -0.35), 0.45)
	return panel - b.z * 0.25


## A lectern with a book/page (the journal pages, the Litany). Returns the reading point.
func lectern(at: Vector3, yaw: float, key := "lore_tstone", page := true) -> Vector3:
	var b := Basis(Vector3.UP, yaw)
	k.box(key, at + b * Vector3(0, 0.05, 0), Vector3(0.6, 0.12, 0.5), b, true, 0.85)
	k.box(key, at + b * Vector3(0, 0.55, 0), Vector3(0.26, 0.95, 0.24), b, true)
	var top := b * Basis(Vector3.RIGHT, -0.45)
	k.box(key, at + b * Vector3(0, 1.08, 0.02), Vector3(0.62, 0.08, 0.46), top, true, 0.92)
	if page:
		p.box("lore_paper", at + b * Vector3(-0.13, 1.13, 0.0), Vector3(0.24, 0.012, 0.32), top * Basis(Vector3.BACK, -0.06), false)
		p.box("lore_paper", at + b * Vector3(0.13, 1.13, 0.0), Vector3(0.24, 0.012, 0.32), top * Basis(Vector3.BACK, 0.06), false, 0.92)
		p.box("lore_rune", at + b * Vector3(-0.13, 1.14, 0.0), Vector3(0.16, 0.004, 0.012), top, false)
	return at + Vector3.UP * 1.0


## A loose page pinned to something or lying on a surface (normal `n`).
func page(at: Vector3, n: Vector3, yaw_jit := 0.2) -> void:
	var up := Vector3.UP if absf(n.y) < 0.9 else Vector3.BACK
	var side := n.cross(up).normalized()
	var bas := Basis(side, n.cross(side).normalized() * -1.0, n.normalized()) * Basis(Vector3.BACK, rng.randf_range(-yaw_jit, yaw_jit))
	p.box("lore_paper", at, Vector3(0.22, 0.3, 0.008), bas, false)
	for i in 4:
		p.box("lore_rune", at + n * 0.006 + bas.y * (0.08 - 0.045 * float(i)), Vector3(0.15, 0.008, 0.004), bas, false, 0.7)


## A pagan rune slab (old tongue), mossy, leaning; returns the face point.
func rune_stone(at: Vector3, yaw: float, h := 1.4) -> Vector3:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.05)) * Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08))
	if rk():
		var m: Mesh = rk().call("slab", rng.randi() % 6, UNIT_SLAB, "mossy", 0.3, true)
		var rsz := Vector3(0.85, h, 0.32)
		rock(m, Transform3D(b * Basis(Vector3.UP, PI) * Basis.from_scale(rsz / UNIT_SLAB), at + Vector3.DOWN * 0.08), false)
		col_box(k, at + b * Vector3(0, h * 0.5 - 0.08, 0), rsz * Vector3(0.9, 1.0, 0.9), b)
	else:
		var cm := CreatureMesh.new(rng.randi())
		var pts := PackedVector3Array([Vector3(0, -0.4, 0), Vector3(0, h * 0.35, 0), Vector3(0.03, h * 0.75, 0), Vector3(0.0, h, 0)])
		cm.tube(pts, PackedFloat32Array([0.42, 0.4, 0.34, 0.12]), 8, Color(1, 1, 1), 0.0, 0.12, 0.0, Vector2(1.0, 0.36))
		organic(k, "lore_moss", cm.commit(), Transform3D(b, at), true)
	# runes cut into the face, cold-glinting (a panel standing just proud of the slab's face)
	var face := at + b * Vector3(0, h * 0.5, -0.19)
	panel(face, -b.z, 0.5, minf(h * 0.55, 0.85), LA.C_RUNES if rng.randf() < 0.6 else LA.C_SPIRAL, true)
	return face - b.z * 0.6 + Vector3.DOWN * 0.3


# --- village props --------------------------------------------------------------------------

func barrel(kit: OssKit, at: Vector3, s := 1.0, lying := false, yaw := 0.0) -> void:
	var h := 0.85 * s
	var body := pooled("barrel", func() -> ArrayMesh:
		var cm := CreatureMesh.new(5)
		cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.425, 0), Vector3(0, 0.85, 0)]), PackedFloat32Array([0.27, 0.32, 0.27]), 14, Color(0.85, 0.72, 0.6), 0.0, 0.0)
		cm.blob(Vector3(0, 0.85, 0), Vector3(0.26, 0.015, 0.26), Basis.IDENTITY, Color(0.7, 0.58, 0.48), 0.0, 0.0, 0.0, 2, 12)
		for i in 12:
			var a := TAU * float(i) / 12.0
			cm.tube(PackedVector3Array([Vector3(cos(a) * 0.272, 0.02, sin(a) * 0.272), Vector3(cos(a) * 0.322, 0.425, sin(a) * 0.322), Vector3(cos(a) * 0.272, 0.83, sin(a) * 0.272)]), PackedFloat32Array([0.006, 0.006, 0.006]), 3, Color(0.4, 0.33, 0.27), 0.0, 0.0)
		return cm.commit())
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	if lying:
		xf = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5), at + Basis(Vector3.UP, yaw) * Vector3(0, 0.3 * s, h * 0.5))
	organic(kit, "wood", body, xf)
	col_box(kit, xf * Vector3(0, 0.425, 0), Vector3(0.5, h, 0.5), xf.basis.orthonormalized())
	var hoops := pooled("hoops", func() -> ArrayMesh:
		var hoop := CreatureMesh.new(3)
		for hy: float in [0.15, 0.5, 0.85]:
			var r := lerpf(0.275, 0.325, 1.0 - absf(hy - 0.5) * 2.0) + 0.008
			hoop.tube(PackedVector3Array([Vector3(0, 0.85 * hy - 0.025, 0), Vector3(0, 0.85 * hy + 0.025, 0)]), PackedFloat32Array([r, r]), 14, Color(0.5, 0.5, 0.52), 0.0, 0.0)
		return hoop.commit())
	organic(kit, "iron", hoops, xf)


func crate(kit: OssKit, at: Vector3, s := 0.6, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	kit.box("wood", at + Vector3.UP * (s * 0.5), Vector3(s, s, s), b, true, 0.8)
	for e: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		for sg: float in [-1.0, 1.0]:
			var f := b * (e * (s * 0.5 + 0.012) * sg)
			kit.box("wood", at + Vector3.UP * (s * 0.5) + f, Vector3(s * 1.02 if e.z != 0.0 else 0.04, s * 0.12, s * 1.02 if e.x != 0.0 else 0.04), b, false, 0.65)


## Post-and-rail fence a -> b (ground points); `gaps` leaves missing/fallen rails.
func fence(a: Vector3, b: Vector3, gaps := 0.15) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var n := maxi(1, int(d.length() / 1.9))
	var along := d.normalized()
	var bas := Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized())
	var posts: Array[Vector3] = []
	for i in n + 1:
		var q := a.lerp(b, float(i) / float(n))
		q.y = g(q.x, q.z)
		posts.append(q)
		var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08))
		p.box("lore_beam", q + Vector3.UP * 0.45, Vector3(0.11, 1.2, 0.11), bas * lean, true, rng.randf_range(0.7, 0.9))
	for i in n:
		for ry: float in [0.42, 0.82]:
			var q0 := posts[i] + Vector3.UP * ry
			var q1 := posts[i + 1] + Vector3.UP * ry
			if rng.randf() < gaps:
				if rng.randf() < 0.5:     # fallen rail on the ground
					var mid := (q0 + q1) * 0.5
					mid.y = g(mid.x, mid.z) + 0.04
					p.box("lore_beam", mid, Vector3(q0.distance_to(q1) * 0.9, 0.07, 0.09), Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * bas, false, 0.7)
				continue
			var dd := q1 - q0
			var ang := atan2(dd.y, Vector2(dd.x, dd.z).length())
			p.box("lore_beam", (q0 + q1) * 0.5, Vector3(dd.length() + 0.2, 0.08, 0.06), bas * Basis(Vector3.BACK, ang), false, rng.randf_range(0.72, 0.9))


## Dry-stone wall a -> b (ground points), `h` tall, broken in places (`ruin` 0..1).
func drystone(a: Vector3, b: Vector3, h := 1.0, ruin := 0.3, key := "lore_moss", kit: OssKit = null) -> void:
	var kk := kit if kit else k
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := d.length()
	var along := d.normalized()
	var side := along.cross(Vector3.UP).normalized()
	var x := 0.0
	while x < length:
		var sw := rng.randf_range(0.5, 0.9)
		var q := a + along * (x + sw * 0.5)
		var gy := g(q.x, q.z)
		var top := h * (1.0 - ruin * clampf(0.5 + 0.8 * sin(x * 0.7 + float(rng.randi() % 7)), 0.0, 1.0))
		if rng.randf() < ruin * 0.25:
			top = 0.25
		var y := gy - 0.2
		var course := 0
		while y < gy + top:
			var ch := rng.randf_range(0.22, 0.34)
			var wv := 0.62 - 0.08 * float(course)
			var c := q + along * rng.randf_range(-0.05, 0.05) + side * rng.randf_range(-0.04, 0.04)
			c.y = y + ch * 0.5
			kk.box(key, c, Vector3(sw - 0.04, ch, maxf(wv, 0.36)), Basis(Vector3.UP, atan2(-along.z, along.x) + rng.randf_range(-0.08, 0.08)) * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05)), true, rng.randf_range(0.72, 1.0))
			y += ch
			course += 1
		if top > 0.6:     # cope stones on edge
			var cq := q
			cq.y = y + 0.12
			kk.box(key, cq, Vector3(sw * 0.9, 0.26, 0.2), Basis(Vector3.UP, atan2(-along.z, along.x)), false, 0.85)
		if rng.randf() < ruin * 0.5:   # tumbled stones at the foot
			var fq := q + side * (rng.randf_range(0.6, 1.3) * (1.0 if rng.randf() < 0.5 else -1.0))
			fq.y = g(fq.x, fq.z) + 0.1
			kk.box(key, fq, Vector3(0.45, 0.24, 0.32), Basis.from_euler(Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)), false, 0.8)
		x += sw


func bench(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	p.box("lore_beam", at + b * Vector3(0, 0.44, 0), Vector3(1.6, 0.08, 0.38), b, true, 0.85)
	for sx: float in [-0.6, 0.6]:
		p.box("lore_tstone", at + b * Vector3(sx, 0.2, 0), Vector3(0.22, 0.42, 0.34), b, true, 0.8)


## A lantern on a post (unlit iron cage, cold glass) or lit (`lit` adds an ember glass pane).
func lamp_post(at: Vector3, yaw: float, lit := false) -> Vector3:
	var b := Basis(Vector3.UP, yaw)
	p.box("lore_beam", at + Vector3.UP * 1.1, Vector3(0.13, 2.6, 0.13), b, true, 0.75)
	p.box("lore_beam", at + b * Vector3(0, 2.3, -0.25), Vector3(0.08, 0.08, 0.6), b, false, 0.75)
	var lc := at + b * Vector3(0, 1.95, -0.48)
	p.box("iron", lc + Vector3.UP * 0.2, Vector3(0.26, 0.04, 0.26), b, false)
	p.box("iron", lc - Vector3.UP * 0.16, Vector3(0.22, 0.04, 0.22), b, false)
	for sx: float in [-0.1, 0.1]:
		for sz: float in [-0.1, 0.1]:
			p.box("iron", lc + b * Vector3(sx, 0.02, sz), Vector3(0.025, 0.36, 0.025), b, false)
	p.box("glow" if lit else "dark", lc, Vector3(0.17, 0.28, 0.17), b, false, 0.6 if lit else 0.4)
	return lc


# --- statues --------------------------------------------------------------------------------

## A robed saint carved in stone, ~2.1 m tall (feet at origin, facing -z), cached per variant.
## variant: 0 whole (the bowl of coals), 1 face cut away, 2 face and hands taken, 3 headless.
static func saint_mesh(variant: int) -> ArrayMesh:
	if _statues.has(variant):
		return _statues[variant]
	var hit := LA.GenCache.load_mesh("lore_saint|%d" % variant, KIT_PATH)
	if hit:
		_statues[variant] = hit
		return hit
	var cm := CreatureMesh.new(41 + variant)
	var stone := Color(1, 1, 1)
	var scar := Color(1.25, 1.2, 1.12)            # fresh-cut stone is paler
	# robe: a long bell that narrows to the shoulders, a little flattened front-back
	cm.tube(PackedVector3Array([Vector3(0, 0.0, 0), Vector3(0, 0.12, 0), Vector3(0, 0.6, 0.0), Vector3(0, 1.1, 0.01), Vector3(0, 1.45, 0.0), Vector3(0, 1.62, 0.0)]),
		PackedFloat32Array([0.4, 0.4, 0.33, 0.27, 0.25, 0.17]), 16, stone, 0.0, 0.06, 0.0, Vector2(1.0, 0.72))
	# drapery folds down the front and sides
	for i in 7:
		var a := lerpf(-1.3, 1.3, float(i) / 6.0) + PI * 1.5
		var top := Vector3(cos(a) * 0.2, 1.3, sin(a) * 0.15)
		var bot := Vector3(cos(a) * 0.38, 0.05, sin(a) * 0.3)
		cm.tube(PackedVector3Array([top, top.lerp(bot, 0.5) + Vector3(0, 0, 0), bot]), PackedFloat32Array([0.015, 0.035, 0.045]), 5, stone, 0.0, 0.1)
	# mantle over the shoulders
	cm.blob(Vector3(0, 1.5, 0.02), Vector3(0.3, 0.16, 0.22), Basis.IDENTITY, stone, 0.0, 0.08, 0.0, 6, 14)
	# hood
	cm.blob(Vector3(0, 1.74, 0.05), Vector3(0.16, 0.2, 0.17), Basis.IDENTITY, stone, 0.0, 0.08, 0.0, 7, 12)
	if variant <= 2:
		# head inside the hood; face forward (-z)
		cm.blob(Vector3(0, 1.73, -0.04), Vector3(0.11, 0.14, 0.11), Basis.IDENTITY, stone if variant == 0 else scar, 0.0, 0.05 if variant == 0 else 0.35, 0.0, 6, 10)
		if variant == 0:
			cm.blob(Vector3(0, 1.72, -0.14), Vector3(0.025, 0.04, 0.03), Basis.IDENTITY, stone, 0.0, 0.0, 0.0, 3, 5)   # nose
		else:
			# the cut face: flat gouged plane, chisel scars
			for j in 3:
				cm.blob(Vector3(lerpf(-0.05, 0.05, float(j) / 2.0), 1.73 - 0.03 * float(j), -0.13), Vector3(0.035, 0.05, 0.015), Basis(Vector3.BACK, 0.4), scar, 0.0, 0.4, 0.0, 3, 5)
	else:
		cm.blob(Vector3(0, 1.66, 0.02), Vector3(0.1, 0.05, 0.1), Basis.IDENTITY, scar, 0.0, 0.5, 0.0, 4, 8)   # neck stump
	# arms: upper arms down the sides, forearms forward to the bowl (or to stumps)
	for s: float in [-1.0, 1.0]:
		var sh := Vector3(0.24 * s, 1.47, 0.0)
		var el := Vector3(0.25 * s, 1.12, -0.06)
		cm.limb(sh, el, 0.09, 0.1, stone, Vector3(0.03 * s, 0, 0), 0.06)
		if variant == 2 and s > 0.0:
			cm.blob(el + Vector3(-0.02 * s, 0.0, -0.06), Vector3(0.09, 0.09, 0.08), Basis.IDENTITY, scar, 0.0, 0.4, 0.0, 4, 7)
			continue
		var hand := Vector3(0.07 * s, 1.08, -0.27)
		cm.limb(el, hand, 0.1, 0.11, stone, Vector3(0, -0.02, 0), 0.06)    # wide sleeve
		if variant < 2:
			cm.blob(hand + Vector3(0, 0.0, -0.04), Vector3(0.05, 0.045, 0.06), Basis.IDENTITY, stone, 0.0, 0.1, 0.0, 4, 6)
	if variant < 2:
		# the bowl of coals held before the breast
		cm.tube(PackedVector3Array([Vector3(0, 1.08, -0.33), Vector3(0, 1.16, -0.33), Vector3(0, 1.19, -0.33)]), PackedFloat32Array([0.07, 0.14, 0.15]), 12, stone, 0.0, 0.03)
	_statues[variant] = OssKit.with_lods(cm.commit())
	LA.GenCache.save_mesh("lore_saint|%d" % variant, KIT_PATH, _statues[variant])
	return _statues[variant]


## A saint on a plinth at ground point `at` facing `yaw`. Returns the plinth's front face point.
func saint(at: Vector3, yaw: float, variant: int, plinth := 0.7, s := 1.0, key := "lore_tstone") -> Vector3:
	var b := Basis(Vector3.UP, yaw)
	var bot := at.y - 0.4
	k.box(key, Vector3(at.x, (bot + at.y + plinth) * 0.5, at.z), Vector3(0.95, at.y + plinth - bot, 0.85) * Vector3(s, 1, s), b, true, 0.85)
	k.box(key, at + Vector3.UP * (plinth - 0.04), Vector3(1.08 * s, 0.1, 0.98 * s), b, true, 0.78)
	organic(k, "lore_statue", saint_mesh(variant), Transform3D(b.scaled(Vector3.ONE * s), at + Vector3.UP * plinth))
	col_box(k, at + Vector3.UP * (plinth + 1.0 * s), Vector3(0.6, 2.0, 0.55) * s, b)
	return at + b * Vector3(0, plinth * 0.5, -0.44 * s)


## A statue lying where it fell (yaw = direction its head points).
func fallen_saint(at: Vector3, yaw: float, variant: int, face_down := true) -> void:
	var lie := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, (PI * 0.5 if face_down else -PI * 0.5)) * Basis(Vector3.UP, rng.randf_range(-0.3, 0.3))
	var xf := Transform3D(lie, at + Vector3.UP * 0.22)
	organic(k, "lore_statue", saint_mesh(variant), xf)
	col_box(k, xf * Vector3(0, 0.9, 0), Vector3(0.5, 1.8, 0.4), lie)


## A cart (two spoked wheels, plank bed, shafts). broken: a wheel off and lying, the bed down on
## that corner. Returns the tailboard point.
func cart(at: Vector3, yaw: float, broken := false, load_kind := "") -> Vector3:
	var b := Basis(Vector3.UP, yaw)
	var tilt := Basis.IDENTITY
	if broken:
		tilt = Basis(Vector3.BACK, -0.22) * Basis(Vector3.RIGHT, 0.06)
	var bb := b * tilt
	var wr := 0.55
	var bed := at + Vector3.UP * (wr + 0.12 - (0.3 if broken else 0.0))
	p.box("lore_beam", bed, Vector3(1.3, 0.08, 2.2), bb, true, 0.8)
	for sx: float in [-1.0, 1.0]:
		p.box("lore_beam", bed + bb * Vector3(sx * 0.63, 0.22, 0), Vector3(0.06, 0.36, 2.2), bb, false, 0.72)
	p.box("lore_beam", bed + bb * Vector3(0, 0.22, 1.08), Vector3(1.3, 0.36, 0.06), bb, false, 0.7)
	for sx2: float in [-1.0, 1.0]:      # shafts down to the ground in front
		var s0 := bed + bb * Vector3(sx2 * 0.45, -0.05, -1.0)
		var s1 := at + b * Vector3(sx2 * 0.4, 0.06, -2.6)
		s1.y = g(s1.x, s1.z) + 0.06
		var dd := s1 - s0
		p.box("lore_beam", (s0 + s1) * 0.5, Vector3(0.08, 0.08, dd.length()), Basis.looking_at(dd.normalized(), Vector3.UP), false, 0.7)
	for sx3: float in [-1.0, 1.0]:
		var hub := at + b * Vector3(sx3 * 0.78, wr, 0.1)
		var wb := b * Basis(Vector3.BACK, 0.0)
		if broken and sx3 > 0.0:
			hub = at + b * Vector3(1.6, 0.07, 0.8)
			wb = b * Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, 0.3)
		else:
			p.box("iron", at + b * Vector3(sx3 * 0.6, wr, 0.1), Vector3(0.36, 0.07, 0.07), b, false)
		_wheel(hub, wb, wr)
	if load_kind == "hay":
		var cm := CreatureMesh.new(rng.randi())
		cm.blob(Vector3.ZERO, Vector3(0.6, 0.35, 1.0), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.3, 0.0, 6, 10)
		organic(p, "lore_thatch", cm.commit(), Transform3D(bb, bed + bb * Vector3(0, 0.3, 0)))
	elif load_kind == "sacks":
		for i in 4:
			var cm2 := CreatureMesh.new(rng.randi())
			cm2.blob(Vector3.ZERO, Vector3(0.25, 0.18, 0.36), Basis.IDENTITY, Color(0.75, 0.66, 0.52), 0.0, 0.2, 0.0, 5, 8)
			organic(p, "lore_cloth", cm2.commit(), Transform3D(bb * Basis(Vector3.UP, rng.randf_range(-0.6, 0.6)), bed + bb * Vector3(rng.randf_range(-0.3, 0.3), 0.2, -0.6 + 0.4 * float(i))))
	return bed + bb * Vector3(0, 0.25, 1.2)


func _wheel(hub: Vector3, b: Basis, r: float) -> void:
	# wheel plane: local y/z of `b`, axle along local x
	var n := 12
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var q0 := Vector3(0, sin(a0), cos(a0)) * r
		var q1 := Vector3(0, sin(a1), cos(a1)) * r
		var mid := (q0 + q1) * 0.5
		var tang := (q1 - q0).normalized()
		p.box("lore_beam", hub + b * mid, Vector3(0.08, 0.1, q0.distance_to(q1) + 0.03), b * Basis(Vector3.RIGHT, -atan2(tang.y, tang.z)), false, 0.7)
	for i in 6:
		var a := TAU * float(i) / 6.0
		p.box("lore_beam", hub + b * (Vector3(0, sin(a), cos(a)) * r * 0.5), Vector3(0.05, 0.05, r), b * Basis(Vector3.RIGHT, -a), false, 0.75)
	p.box("iron", hub, Vector3(0.22, 0.16, 0.16), b, false, 0.7)


## Scarecrow: a cross of poles, a sack head, a rag coat.
func scarecrow(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12))
	p.box("lore_beam", at + b * Vector3(0, 1.0, 0), Vector3(0.08, 2.4, 0.08), b, true, 0.7)
	p.box("lore_beam", at + b * Vector3(0, 1.55, 0), Vector3(1.5, 0.07, 0.07), b, false, 0.7)
	var cm := CreatureMesh.new(rng.randi())
	cm.blob(Vector3(0, 2.0, 0), Vector3(0.17, 0.2, 0.16), Basis.IDENTITY, Color(0.8, 0.7, 0.52), 0.0, 0.25, 0.0, 6, 8)
	cm.tube(PackedVector3Array([Vector3(0, 1.62, 0), Vector3(0, 1.2, 0), Vector3(0, 0.75, 0.04)]), PackedFloat32Array([0.26, 0.3, 0.33]), 9, Color(0.45, 0.4, 0.38), 0.0, 0.3, 0.0, Vector2(1.0, 0.55), 1.0)
	for s: float in [-1.0, 1.0]:
		cm.tube(PackedVector3Array([Vector3(0.1 * s, 1.56, 0), Vector3(0.45 * s, 1.52, 0), Vector3(0.72 * s, 1.36, 0.02)]), PackedFloat32Array([0.1, 0.09, 0.07]), 6, Color(0.42, 0.38, 0.36), 0.0, 0.3)
	organic(p, "lore_cloth", cm.commit(), Transform3D(b, at))
	var hat := CreatureMesh.new(rng.randi())
	hat.tube(PackedVector3Array([Vector3(0, 2.14, 0), Vector3(0, 2.18, 0), Vector3(0, 2.36, 0)]), PackedFloat32Array([0.32, 0.14, 0.04]), 10, Color(0.3, 0.27, 0.25), 0.0, 0.2)
	organic(p, "lore_cloth", hat.commit(), Transform3D(b * Basis(Vector3.RIGHT, 0.2), at))


## Fenced garden plot: soil rows, dead greens, stakes, a gate gap on side `gate` (0 n,1 e,2 s,3 w).
func garden(r: Rect2, gate := 2, scare := false) -> void:
	var y0 := g(r.get_center().x, r.get_center().y)
	var c := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a2: Vector2 = c[i]
		var b2: Vector2 = c[(i + 1) % 4]
		if i == gate:
			var m := (a2 + b2) * 0.5
			var dirv := (b2 - a2).normalized()
			fence(Vector3(a2.x, 0, a2.y), Vector3(m.x - dirv.x * 0.7, 0, m.y - dirv.y * 0.7), 0.1)
			fence(Vector3(m.x + dirv.x * 0.7, 0, m.y + dirv.y * 0.7), Vector3(b2.x, 0, b2.y), 0.1)
		else:
			fence(Vector3(a2.x, 0, a2.y), Vector3(b2.x, 0, b2.y), 0.18)
	var rows := maxi(2, int((r.size.y - 1.0) / 0.9))
	for j in rows:
		var z := r.position.y + 0.8 + float(j) * 0.9
		var x0 := r.position.x + 0.6
		var x1 := r.end.x - 0.6
		var mid := Vector3((x0 + x1) * 0.5, 0.0, z)
		mid.y = g(mid.x, mid.z)
		var cm := CreatureMesh.new(rng.randi())
		cm.tube(PackedVector3Array([Vector3(x0 - mid.x, 0, 0), Vector3(x1 - mid.x, 0, 0)]), PackedFloat32Array([0.24, 0.24]), 6, Color(1, 1, 1), 0.0, 0.25, 0.0, Vector2(1.0, 0.45))
		organic(p, "lore_soil", cm.commit(), Transform3D(Basis.IDENTITY, mid))
		var x := x0 + 0.3
		while x < x1 - 0.2:
			if rng.randf() < 0.7:
				var q := Vector3(x, 0, z + rng.randf_range(-0.05, 0.05))
				q.y = g(q.x, q.z) + 0.1
				var pv := rng.randi() % 6
				var plant := pooled("plant%d" % pv, func() -> ArrayMesh:
					var pm := CreatureMesh.new(800 + pv)
					var dead := pv < 4
					var col := Color(0.62, 0.55, 0.38) if dead else Color(0.8, 0.95, 0.7)
					for lf in 5:
						var a := TAU * float(lf) / 5.0 + float(pv)
						pm.blob(Vector3(cos(a) * 0.08, 0.04, sin(a) * 0.08), Vector3(0.1, 0.03, 0.06), Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.5 if not dead else -0.3), col, 0.0, 0.2, 0.0, 3, 6)
					return pm.commit())
				organic(p, "lore_leaf", plant, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q))
			x += 0.45
		if rng.randf() < 0.5:
			var st := Vector3(x0 + rng.randf() * (x1 - x0), 0, z)
			st.y = g(st.x, st.z)
			p.box("lore_beam", st + Vector3.UP * 0.4, Vector3(0.04, 0.9, 0.04), Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)), false, 0.7)
	if scare:
		var sq := Vector3(r.get_center().x + 0.3, 0, r.get_center().y + 0.2)
		sq.y = g(sq.x, sq.z)
		scarecrow(sq, rng.randf() * TAU)
	var _y := y0

extends Node3D
## r34 raid room: the Summit of Ascension's great deck (RealmLayout.RAIDS "summit": centre (0, -118),
## r 28, deck 27.35), the Ascended Warden's room. SummitDress builds the deck on its piers; this node
## (BossArena.room) carries what the fight changes (docs/r34/raids_overworld.md):
##   - four light pylons (PYLON_R): lit, each holds a ring of its light (RING_R) that is a sanctuary
##     from the falling sky and the eclipse, and a windbreak against the Gale. The Ascension snuffs
##     them all: stand in a dark pylon's ring for RELIGHT s to kindle it again;
##   - the two broken edges east and west (no parapet; SummitDress leaves the gaps), marked by edge
##     fires: the Gale of the Door blows you toward them;
##   - the falling sky (star(): a disc that fills, then a star strikes; never inside a lit ring);
##   - lighting: a cold shaft from the cirque over the deck, gold pylons, red edge fires; the deck goes
##     dark in the Ascension and burns white-gold in the Hierarch's last phase.
## Room API (BossArena / AscendedWarden): room_begin(boss), room_reset(), room_won(), snuff_all(),
## light_all(), lit_count(), pylon_points(lit_only), in_light(p), gale_shelter(from, p), star(at, boss),
## edge_points(), set_mood(m).

const RING_R := 3.2
const RELIGHT := 2.5
const PYLON_R := 17.0
const PYLON_ANGLES := [45.0, 135.0, 225.0, 315.0]      ## holder degrees (0 = east, 90 = south)
const EDGE_ANGLES := [0.0, 180.0]                      ## the broken edges (east, west)
const EDGE_HALF := 8.5                                 ## degrees each side of an edge's centre
const STAR_R := 2.6
const STAR_FALL := 1.7
const STAR_GLOOM := 18.0
const GOLD := Color(1.0, 0.84, 0.55)

var C := Vector3.ZERO                                  ## deck centre (world, at deck height)
var R := 28.0
var SX := 1.0                                          ## the deck's east-west stretch (an ellipse R * SX by R)
var pylons: Array[Pylon] = []
var mood := "rest"
var _boss: Node = null
var _key: SpotLight3D
var _edge_lights: Array[OmniLight3D] = []


## A light pylon: a stone obelisk with a gold flame crown. Its ring is where its light holds.
class Pylon extends Node3D:
	var lit := true
	var progress := 0.0
	var _flame: Node3D
	var _light: OmniLight3D
	var _ring: MeshInstance3D
	var _fill: MeshInstance3D
	var _ring_mat: StandardMaterial3D

	func setup(flame_mat: ShaderMaterial) -> void:
		var k := OssKit.new()
		k.keep_lanes = false
		k.box("stone", Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 2.0), Basis.IDENTITY, true, 0.85)
		k.box("stone", Vector3(0, 2.9, 0), Vector3(1.1, 4.8, 1.1), Basis.IDENTITY, true, 0.92)
		k.box("stone", Vector3(0, 5.4, 0), Vector3(1.5, 0.3, 1.5), Basis.IDENTITY, true, 0.8)
		k.box("iron", Vector3(0, 5.65, 0), Vector3(1.2, 0.2, 1.2), Basis.IDENTITY, false)
		k.commit(self, "PylonBody")
		# the crown is the brazier's crossed flame cards (world/brazier_flame.gdshader), not a flat
		# billboard: a hot pale core under an orange body, so it can not clip to a white blob
		_flame = Node3D.new()
		_flame.position = Vector3(0, 5.7, 0)
		add_child(_flame)
		for i in 2:
			var qm := QuadMesh.new()
			qm.size = Vector2(1.0, 1.8)
			qm.center_offset = Vector3(0, 0.85, 0)
			var card := MeshInstance3D.new()
			card.mesh = qm
			card.material_override = flame_mat
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			card.rotation.y = float(i) * PI * 0.5
			_flame.add_child(card)
		_light = OmniLight3D.new()
		_light.light_color = GOLD
		_light.light_energy = 2.4
		_light.omni_range = 12.0
		_light.shadow_enabled = false
		_light.position = Vector3(0, 6.4, 0)
		_light.set_meta(&"light_class", "fill")
		add_child(_light)
		LightPolicy.apply_fade(_light)
		# the ring of its light on the deck, and the fill that grows as you rekindle it
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_mat.albedo_color = Color(0.9, 0.62, 0.28, 0.5)
		_ring_mat.disable_fog = true
		var tm := TorusMesh.new()
		tm.inner_radius = RING_R - 0.12
		tm.outer_radius = RING_R
		tm.rings = 48
		_ring = MeshInstance3D.new()
		_ring.mesh = tm
		_ring.scale = Vector3(1, 0.1, 1)
		_ring.material_override = _ring_mat
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.position = Vector3(0, 0.06, 0)
		add_child(_ring)
		var cm := CylinderMesh.new()
		cm.top_radius = RING_R
		cm.bottom_radius = RING_R
		cm.height = 0.02
		cm.radial_segments = 40
		_fill = MeshInstance3D.new()
		_fill.mesh = cm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.albedo_color = Color(0.5, 0.36, 0.14, 0.12)
		fm.disable_fog = true
		_fill.material_override = fm
		_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fill.position = Vector3(0, 0.05, 0)
		add_child(_fill)
		set_lit(true, false)

	func set_lit(on: bool, animate := true) -> void:
		lit = on
		progress = 0.0
		_flame.visible = on
		_light.visible = on
		_fill.visible = on
		_fill.scale = Vector3.ONE
		_ring_mat.albedo_color = Color(0.9, 0.62, 0.28, 0.5) if on else Color(0.35, 0.4, 0.55, 0.3)
		if animate:
			var at := global_position + Vector3.UP * 5.8
			if on:
				Vfx.burst(at, Color(2.2, 1.7, 0.9), {"count": 50, "life": 0.8, "speed": Vector2(2.0, 6.0), "size": 0.06, "gravity": -3.0})
				Vfx.ring(global_position + Vector3.UP * 0.1, RING_R, Color(2.0, 1.6, 0.8), 0.6, 0.1, Vector3.UP, 1.5)
				Sfx.play("res://art/audio/ward_chime.wav", at, 0.0, 1.2)
			else:
				Vfx.burst(at, Color(0.1, 0.1, 0.14, 0.8), {"count": 30, "life": 1.2, "speed": Vector2(0.4, 1.6), "size": 0.4, "gravity": 0.6, "additive": false, "turbulence": true})

	## Standing in a dark pylon's ring: the fill grows toward the edge; RELIGHT s and it burns again.
	func tend(delta: float, inside: bool) -> bool:
		if lit:
			return false
		if inside:
			progress += delta
			_fill.visible = true
			_fill.scale = Vector3(maxf(progress / RELIGHT, 0.05), 1, maxf(progress / RELIGHT, 0.05))
			if progress >= RELIGHT:
				set_lit(true)
				HitText.pop(global_position + Vector3.UP * 6.8, "rekindled", GOLD, true)
				return true
		elif progress > 0.0:
			progress = maxf(0.0, progress - delta * 0.5)
			_fill.scale = Vector3(maxf(progress / RELIGHT, 0.05), 1, maxf(progress / RELIGHT, 0.05))
			_fill.visible = progress > 0.0
		return false


static func build(host: Node3D, centre: Vector3, radius: float, holder_basis: Basis, sx := 1.0) -> Node3D:
	var r := (load("res://core/world/summit_raid.gd") as GDScript).new() as Node3D
	r.name = "SummitRaid"
	r.set_meta("site", "summit_dais")                 # the deck's own furniture (zz/realm_audit)
	host.add_child(r)
	r.set("C", centre)
	r.set("R", radius)
	r.set("SX", sx)
	r.call("_build", holder_basis)
	return r


func _dir(deg: float) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(cos(a), 0.0, sin(a))


## The point at `deg`, `rad` out on the deck's ellipse (its x stretched by SX).
func _at(deg: float, rad: float) -> Vector3:
	var d := _dir(deg)
	return C + Vector3(d.x * SX, 0.0, d.z) * rad


func _build(_hb: Basis) -> void:
	var Glow := load("res://core/world/realm/unkindled_glow.gd")
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.albedo_texture = Glow.call("_tongue")
	fm.albedo_color = Color(1.0, 0.6, 0.24, 1.0)      # emissive cap (was 1.3, 0.78, 0.32)
	fm.disable_fog = true
	var card_mat := ShaderMaterial.new()
	card_mat.shader = load("res://world/brazier_flame.gdshader") as Shader
	card_mat.set_shader_parameter(&"fire_mid", Color(1.0, 0.5, 0.12))       # a gold crown: the brazier's card, warmer in the body
	for deg: float in PYLON_ANGLES:
		var p := Pylon.new()
		p.name = "Pylon%d" % pylons.size()
		add_child(p)
		p.global_position = _at(deg, PYLON_R)
		p.setup(card_mat)
		pylons.append(p)
	# the edge fires: a bowl at each end of the two broken edges, red, one light per edge
	var em := fm.duplicate() as StandardMaterial3D
	em.albedo_color = Color(1.0, 0.38, 0.14, 1.0)      # emissive cap (was 1.4, 0.5, 0.18)
	var k := OssKit.new()
	k.keep_lanes = false
	var spots: Array[Vector3] = []
	for deg: float in EDGE_ANGLES:
		for s: float in [-1.0, 1.0]:
			spots.append(_at(deg + s * (EDGE_HALF + 2.2) / SX, R - 1.0))
	for p in spots:
		k.box("stone", p + Vector3.UP * 0.45, Vector3(0.7, 0.9, 0.7), Basis.IDENTITY, true, 0.9)
		k.box("stone", p + Vector3.UP * 0.98, Vector3(1.05, 0.16, 1.05), Basis.IDENTITY, true, 0.8)
		k.box("iron", p + Vector3.UP * 1.12, Vector3(0.9, 0.14, 0.9), Basis.IDENTITY, false)
	var host := Node3D.new()
	host.name = "EdgeFires"
	add_child(host)
	k.commit(host, "EdgeBody")
	host.global_transform = Transform3D.IDENTITY
	var qm := QuadMesh.new()
	qm.size = Vector2(0.8, 1.3)
	qm.center_offset = Vector3(0, 0.6, 0)
	for p in spots:
		var f := MeshInstance3D.new()
		f.mesh = qm
		f.material_override = em
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(f)
		f.global_position = p + Vector3.UP * 1.17
	for deg: float in EDGE_ANGLES:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.4, 0.2)
		l.light_energy = 2.2
		l.omni_range = 10.0
		l.shadow_enabled = false
		l.set_meta(&"light_class", "fill")
		add_child(l)
		l.global_position = _at(deg, R - 1.5) + Vector3.UP * 2.0
		LightPolicy.apply_fade(l)
		_edge_lights.append(l)
	# a cold key light down the cirque onto the deck (no shadows: the budget)
	_key = SpotLight3D.new()
	_key.name = "CirqueShaft"
	_key.light_color = Color(1.0, 0.9, 0.76)
	_key.light_energy = 1.2
	_key.spot_range = 90.0
	_key.spot_angle = 38.0
	_key.spot_attenuation = 0.4
	_key.shadow_enabled = false
	_key.set_meta(&"light_class", "fill")
	add_child(_key)
	_key.global_position = C + Vector3(0.0, 42.0, -26.0)
	_key.look_at(C, Vector3.UP)
	LightPolicy.apply_fade(_key)
	print("SUMMIT_RAID room r %.1f: %d pylons at r %.1f, broken edges %s" % [R, pylons.size(), PYLON_R, EDGE_ANGLES])


# --- the room's state ---------------------------------------------------------------------------

func room_begin(boss: Node) -> void:
	_boss = boss
	light_all(false)
	set_mood("fight")


func room_reset() -> void:
	_boss = null
	light_all(false)
	set_mood("rest")


func room_won() -> void:
	_boss = null
	light_all(false)
	set_mood("won")


func set_mood(m: String) -> void:
	mood = m
	if _key == null:
		return
	var e: float = {"rest": 1.0, "fight": 1.3, "ascension": 0.5, "hierarch": 1.8, "won": 0.8}.get(m, 1.0)
	var col: Color = {"hierarch": Color(1.0, 0.86, 0.62), "ascension": Color(0.5, 0.55, 0.85)}.get(m, Color(1.0, 0.9, 0.76))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_key, "light_energy", e, 1.5)
	tw.tween_property(_key, "light_color", col, 1.5)
	for l in _edge_lights:
		tw.tween_property(l, "light_energy", 0.0 if m == "won" else (3.0 if m == "hierarch" else 2.2), 1.5)


func snuff_all() -> void:
	for p in pylons:
		if p.lit:
			p.set_lit(false)


func light_all(animate := true) -> void:
	for p in pylons:
		if not p.lit:
			p.set_lit(true, animate)


func snuff(p: Pylon) -> void:
	if p != null and p.lit:
		p.set_lit(false)


func lit_count() -> int:
	var n := 0
	for p in pylons:
		if p.lit:
			n += 1
	return n


func pylon_points(lit_only := true) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in pylons:
		if p.lit or not lit_only:
			out.append(p.global_position)
	return out


## The lit pylon whose ring holds `pos`, or null.
func in_light(pos: Vector3) -> Pylon:
	for p in pylons:
		if p.lit:
			var d := pos - p.global_position
			if Vector2(d.x, d.z).length() <= RING_R and absf(d.y) < 3.0:
				return p
	return null


## Sheltered from the Gale: a lit pylon stands between `from` and you, within 4 m of you.
func gale_shelter(from: Vector3, pos: Vector3) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(pos.x, pos.z)
	for p in pylons:
		if not p.lit:
			continue
		var c := Vector2(p.global_position.x, p.global_position.z)
		if c.distance_to(b) > 4.0:
			continue
		var ab := b - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if (a + ab * t).distance_to(c) < 1.6 and t > 0.4:
			return true
	return false


## The edge centres (world, on the deck rim) the Gale blows toward.
func edge_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for deg: float in EDGE_ANGLES:
		out.append(_at(deg, R))
	return out


## A falling star at `at` (moved out of any lit ring first): a disc fills, then the star strikes.
func star(at: Vector3, boss: Node, fall := STAR_FALL) -> void:
	var p := in_light(at)
	if p != null:
		var d := at - p.global_position
		d.y = 0.0
		at = p.global_position + (d.normalized() if d.length() > 0.1 else Vector3.RIGHT) * (RING_R + STAR_R + 0.3)
	var flat := at - C
	flat.y = 0.0
	var fe := Vector2(flat.x / SX, flat.z)                # on the ellipse's own scale
	if fe.length() > R - 0.5:
		fe = fe.normalized() * (R - 0.5)
		at = C + Vector3(fe.x * SX, 0.0, fe.y)
	at.y = C.y
	BossKit.zone(self, at, fall, STAR_GLOOM, {"by": boss if boss is Enemy else null, "radius": STAR_R, "color": BossKit.HOLY})
	# the star itself: a streak from the sky that lands as the disc fills
	var top := at + Vector3(randf_range(-6.0, 6.0), 26.0, randf_range(-6.0, 6.0))
	var aid := get_instance_id()
	get_tree().create_timer(maxf(fall - 0.25, 0.05), false).timeout.connect(func() -> void:
		var me := instance_from_id(aid) as Node3D
		if me == null:
			return
		Vfx.ribbon(PackedVector3Array([top, top.lerp(at, 0.5), at + Vector3.UP * 0.3]), 0.22, 0.05, Color(1.8, 1.3, 0.6), 0.3)
		Vfx.light(at + Vector3.UP * 1.5, Color(1.0, 0.85, 0.6), 3.0, STAR_R * 3.0, 0.4))


func _physics_process(delta: float) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if pl == null:
		return
	for p in pylons:
		if p.lit:
			continue
		var d := pl.global_position - p.global_position
		var inside := Vector2(d.x, d.z).length() <= RING_R and absf(d.y) < 3.0
		if p.tend(delta, inside) and _boss.has_method("on_pylon_lit"):
			_boss.call("on_pylon_lit", p)

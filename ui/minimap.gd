extends Control
## The minimap (r32): a round, painted map of the Realm in the HUD's bottom-right corner, turned so
## up is where the camera looks, the wanderer's arrow at its centre. M switches between near
## (55 m) and wide (120 m); a third press hides it.
##
## The ground is painted once from RealmLand's heightfield (hillshade, biome colours, worn paths,
## pools, the rift's lava, faint contours) on a worker thread as soon as the land exists: about
## 0.4 s off the main thread, then it is one texture and a canvas shader.
##
## Markers (re-read twice a second, drawn every frame):
##   - seal guards still standing (red rings: kill these to open a seal; clamped to the rim when far)
##   - the seals themselves while shut (a barred gate), bosses not yet slain (a crowned mark)
##   - fires: a gold flame lit, a hollow ember flame cold; landmark beacons in their own colour
##   - other enemies close by (small dull red dots), unopened chests close by (gold squares)
##   - r33: anything in group "map_marker" (meta map_kind / map_label / map_color, the shared contract):
##     quest_available "!", quest_turnin "?", quest_target (a ringed spot), rare (a moon-silver star),
##     travel (a waygate arch), gather (a sprig), vendor (a purse), trainer (an open book). The three
##     quest kinds stay pinned to the rim when far, like the guards; the rest show inside the dial.
##     Each kind can be untracked in the settings menu (ui/hud_prefs.gd, WoW's tracking menu).
## r33 (WoW): the place's name over the dial (RealmLayout.region_at) with the night's tier there, the
## moon on the rim where it hangs, and a clock under the dial if the night ever keeps one.
## Added by ui/hud.gd (one line). Hidden while paused, under the loading screen, and off the Realm.

const LANTERN := Color("#FFB347")
const EMBER := Color("#FF6A2A")
const INK := Color(0.93, 0.88, 0.8)
const RIM := Color(0.46, 0.34, 0.26)
const GUARD := Color(1.0, 0.27, 0.2)
const DIAM := 220.0                      ## on-screen diameter (px at the 1600 x 900 reference)
const MARGIN := 30.0
const RANGES := [55.0, 120.0]            ## metres from centre to rim
const PPM := 2.0                         ## painted map pixels per metre
const ENEMY_NEAR := 40.0
const CHEST_NEAR := 45.0
const ACTION := "minimap"
const Land := preload("res://core/world/realm/realm_land.gd")
const HudPrefs := preload("res://ui/hud_prefs.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const QUEST := Color(1.0, 0.82, 0.3)
const MARK_NEAR := 70.0                  ## non-quest map markers beyond this are not even listed
const QUEST_KINDS := ["quest_available", "quest_turnin", "quest_target"]
const AVAIL_NEAR := 40.0                 ## a quest giver's "!" shows within this (m)
const TIER_COL := [Color(0.95, 0.86, 0.62), Color(0.95, 0.78, 0.5), Color(1.0, 0.66, 0.4), Color(1.0, 0.52, 0.34),
	Color(1.0, 0.42, 0.3), Color(0.72, 0.66, 1.0), Color(0.66, 0.6, 1.0)]

const SHADER := """
shader_type canvas_item;
uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform vec2 centre_uv;
uniform vec2 right_uv;    // one rim radius along the camera's right, in uv
uniform vec2 fwd_uv;      // one rim radius along the camera's forward, in uv
uniform float fade = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 uv = centre_uv + p.x * right_uv - p.y * fwd_uv;
	vec3 col = texture(map_tex, uv).rgb;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) col = vec3(0.07, 0.055, 0.05);
	col *= mix(1.0, 0.5, smoothstep(0.62, 1.0, r));
	COLOR = vec4(col, fade * (1.0 - smoothstep(0.985, 1.0, r)));
}
"""

var _font: Font
var _ground: ColorRect
var _mat: ShaderMaterial
var _tex: ImageTexture
var _task := -1
var _img: Image
var _range_i := 0
var _hidden_by_key := false
var _alpha := 0.0
var _scan := 0.0
var _guards: Array = []
var _marks: Array = []                   ## {pos: Vector3, kind: String, col: Color}
var _right := Vector2.RIGHT              ## camera right / forward on the ground (x, z)
var _fwd := Vector2(0, -1)
var _you := Vector3.ZERO
var _facing := Vector2(0, -1)
var _origin := Vector2.ZERO              ## world xz of the map image's (0, 0)
var _size_m := Vector2.ONE
var _region := ""
var _tier := ""
var _tier_i := 0
var _clock := ""
var _moon: Node3D
var _new_marks := {}                     ## marker instance id -> seconds since it first showed (a ping)
var _seeded := false                     ## the first scan's markers were already there: no ping


func _ready() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -DIAM - MARGIN
	offset_right = -MARGIN
	offset_top = -DIAM - MARGIN - 26.0
	offset_bottom = -MARGIN - 26.0
	_font = load("res://ui/fonts/Cinzel.ttf")
	_ground = ColorRect.new()
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_ground.material = _mat
	_ground.show_behind_parent = true
	add_child(_ground)
	modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		if _hidden_by_key:
			_hidden_by_key = false
			_range_i = 0
		elif _range_i < RANGES.size() - 1:
			_range_i += 1
		else:
			_hidden_by_key = true
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_bake_step()
	var zone := get_tree().current_scene
	var hidden := _tex == null or _hidden_by_key or get_tree().paused \
		or (zone != null and zone.get_node_or_null("LoadingScreen") != null)
	_alpha = move_toward(_alpha, 0.0 if hidden else 1.0, delta * 4.0)
	modulate.a = _alpha
	if _alpha <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if cam == null or pl == null:
		return
	var bx := cam.global_basis.x
	var bz := cam.global_basis.z
	_right = Vector2(bx.x, bx.z).normalized() if Vector2(bx.x, bx.z).length() > 0.01 else _right
	_fwd = Vector2(-bz.x, -bz.z).normalized() if Vector2(bz.x, bz.z).length() > 0.01 else _fwd
	_you = pl.global_position
	var v := Vector2(pl.velocity.x, pl.velocity.z) if "velocity" in pl else Vector2.ZERO
	if v.length() > 0.6:
		_facing = v.normalized()
	var rad: float = RANGES[_range_i]
	_mat.set_shader_parameter("centre_uv", (Vector2(_you.x, _you.z) - _origin) / _size_m)
	_mat.set_shader_parameter("right_uv", _right * rad / _size_m)
	_mat.set_shader_parameter("fwd_uv", _fwd * rad / _size_m)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		_rescan()
	for k: int in _new_marks:
		_new_marks[k] = float(_new_marks[k]) + delta
	queue_redraw()


# --- markers ----------------------------------------------------------------------------------

func _rescan() -> void:
	_guards.clear()
	_marks.clear()
	for sp in get_tree().get_nodes_in_group(&"enemy_spawner"):
		if sp.has_method("seal_guards"):
			_guards.append_array(sp.call("seal_guards"))
	var guard_set := {}
	for g: Dictionary in _guards:
		guard_set[Vector3i(g.pos.round())] = true
	for s in get_tree().get_nodes_in_group(&"ward_seal"):
		var ws := s as WardSeal
		if ws and not ws.is_open():
			_marks.append({"pos": ws.global_position, "kind": "seal", "col": INK})
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var id := String(a.get("boss_id"))
		if id != "" and not Travel.bosses_slain.has(id):
			_marks.append({"pos": (a as Node3D).global_position, "kind": "boss", "col": GUARD})
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		var b := n as Node3D
		if b:
			_marks.append({"pos": b.global_position, "kind": "fire" if bool(b.get("lit")) else "ash", "col": LANTERN})
	for b in get_tree().get_nodes_in_group(&"landmark_beacon"):
		if is_instance_valid(b) and "anchor" in b:
			_marks.append({"pos": b.get("anchor"), "kind": "beacon", "col": _beacon_col(b)})
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e3 := e as Node3D
		if e3 == null or e3.global_position.distance_to(_you) > ENEMY_NEAR or (e3 as Node).has_meta(&"boss_id"):
			continue
		if guard_set.has(Vector3i(e3.global_position.round())):
			continue
		_marks.append({"pos": e3.global_position, "kind": "foe", "col": Color(0.75, 0.3, 0.26)})
	for c in get_tree().get_nodes_in_group(&"loot_chest"):
		var c3 := c as Node3D
		if c3 and not bool(c3.get("_opened")) and c3.global_position.distance_to(_you) < CHEST_NEAR:
			_marks.append({"pos": c3.global_position, "kind": "chest", "col": LANTERN})
	_scan_markers()
	_scan_place()


## r33: the shared map_marker contract (wow_rules.md): Node3D, meta map_kind, optional map_label /
## map_color. Quest kinds are kept at any range (pinned to the rim); the rest only near.
func _scan_markers() -> void:
	var live := {}
	for n in get_tree().get_nodes_in_group(&"map_marker"):
		var m := n as Node3D
		if m == null or not m.is_inside_tree() or not m.has_meta(&"map_kind"):
			continue
		if not m.is_visible_in_tree() and not m.has_meta(&"map_always"):
			continue
		var kind := String(m.get_meta(&"map_kind"))
		var quest := kind in QUEST_KINDS
		if not quest and m.global_position.distance_to(_you) > MARK_NEAR:
			continue
		var id := m.get_instance_id()
		live[id] = float(_new_marks.get(id, 0.0 if _seeded else 9.0))
		_marks.append({"pos": m.global_position, "kind": "m:" + kind, "col": m.get_meta(&"map_color", _kind_col(kind)),
			"label": String(m.get_meta(&"map_label", "")), "id": id})
	_new_marks = live
	_seeded = true


func _kind_col(kind: String) -> Color:
	match kind:
		"quest_available", "quest_turnin", "quest_target":
			return QUEST
		"rare":
			return Color(0.82, 0.88, 1.0)
		"travel":
			return Color(0.72, 0.56, 1.0)
		"gather":
			return Color(0.56, 0.86, 0.46)
		"vendor":
			return Color(1.0, 0.8, 0.42)
		"trainer":
			return Color(0.86, 0.8, 1.0)
	return INK


## r33: the place under you, its tier, a clock if anything keeps one, and the moon.
func _scan_place() -> void:
	var r: Dictionary = RealmLayout.region_at(_you.x, _you.z)
	_region = String(r.get("name", ""))
	_tier_i = Tiers.tier_at(_you) if _region != "" else 0
	_tier = String(Tiers.info(_tier_i).get("name", "")) if _region != "" else ""
	_clock = ""
	var ck := get_tree().get_first_node_in_group(&"night_clock")
	if ck and ck.has_method("clock_text"):
		_clock = String(ck.call("clock_text"))
	if not is_instance_valid(_moon):
		var zone := get_tree().current_scene
		_moon = zone.get_node_or_null("Moon") as Node3D if zone else null


## A beacon's own colour (as the compass reads it: its column's material).
func _beacon_col(b: Node) -> Color:
	for c in b.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.material_override is StandardMaterial3D:
			var col := (mi.material_override as StandardMaterial3D).albedo_color
			col.a = 1.0
			return col
	return LANTERN


## World xz -> local px from the map's centre; .z = 1 when it had to be pulled in to the rim.
func _place(p: Vector3, rim: float) -> Vector3:
	var d := Vector2(p.x - _you.x, p.z - _you.z) / float(RANGES[_range_i])
	var q := Vector2(d.dot(_right), -d.dot(_fwd)) * (DIAM * 0.5)
	var clamped := 0.0
	if q.length() > rim:
		q = q.normalized() * rim
		clamped = 1.0
	return Vector3(q.x, q.y, clamped)


func _draw() -> void:
	if _tex == null:
		return
	var c := size * 0.5
	var r := DIAM * 0.5
	# the frame: a dark ring with an engraved inner line
	draw_arc(c, r + 3.0, 0.0, TAU, 96, Color(0.06, 0.045, 0.04, 0.9), 6.0, true)
	draw_arc(c, r - 1.0, 0.0, TAU, 96, Color(RIM, 0.9), 1.5, true)
	draw_arc(c, r + 6.5, 0.0, TAU, 96, Color(RIM, 0.55), 1.0, true)
	# north on the rim
	var n := _place(_you + Vector3(0, 0, -100000.0), r + 1.0)
	var np := c + Vector2(n.x, n.y)
	draw_circle(np, 10.0, Color(0.06, 0.045, 0.04, 0.95))
	draw_arc(np, 10.0, 0.0, TAU, 24, Color(RIM, 0.9), 1.0, true)
	if _font:
		draw_string(_font, np + Vector2(-5.5, 5.5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, LANTERN)
	# marks: quiet ones first, guards last so nothing hides them
	for m: Dictionary in _marks:
		var kind := String(m.kind)
		if kind.begins_with("m:"):
			continue                              # map markers draw after, over the quiet ones
		if not HudPrefs.tracks(kind):
			continue
		var far_ok := kind in ["seal", "boss"]
		var q := _place(m.pos, r - 8.0)
		if q.z > 0.0 and not far_ok:
			continue
		var p := c + Vector2(q.x, q.y)
		var col: Color = m.col
		var a := 0.55 if q.z > 0.0 else 1.0
		match kind:
			"fire":
				_flame(p, Color(LANTERN, a))
			"ash":
				var fl := PackedVector2Array([p + Vector2(0, -8), p + Vector2(4, 1), p + Vector2(2.5, 4), p + Vector2(-2.5, 4), p + Vector2(-4, 1), p + Vector2(0, -8)])
				draw_colored_polygon(fl, Color(0.06, 0.045, 0.04, 0.8 * a))
				draw_polyline(fl, Color(EMBER, 0.9 * a), 1.3, true)
			"beacon":
				_diamond(p, 5.0, Color(col, a))
			"seal":
				_gate(p, Color(INK, a))
			"boss":
				_crown(p, Color(GUARD, a))
			"foe":
				draw_circle(p, 2.6, Color(col, 0.85))
			"chest":
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(col, 0.9))
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.1, 0.07, 0.04), false, 1.0)
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	_draw_markers(c, r, pulse)
	for g: Dictionary in _guards:
		var q := _place(g.pos, r - 7.0)
		var p := c + Vector2(q.x, q.y)
		if q.z > 0.0:
			draw_circle(p, 3.5, Color(GUARD, 0.75))
		else:
			draw_circle(p, 3.2, GUARD)
			draw_arc(p, 6.5, 0.0, TAU, 20, Color(GUARD, 0.8 * pulse), 1.5, true)
	# the wanderer: an arrow along where he is heading, turned into the map's frame
	var f := Vector2(_facing.dot(_right), -_facing.dot(_fwd))
	if f.length() < 0.01:
		f = Vector2(0, -1)
	f = f.normalized()
	var s := Vector2(-f.y, f.x)
	var tip := c + f * 9.0
	var arrow := PackedVector2Array([tip, c - f * 6.0 + s * 6.5, c - f * 3.0, c - f * 6.0 - s * 6.5])
	draw_colored_polygon(arrow, Color(0.06, 0.045, 0.04))
	var inner := PackedVector2Array([c + f * 7.0, c - f * 4.5 + s * 4.8, c - f * 2.0, c - f * 4.5 - s * 4.8])
	draw_colored_polygon(inner, Color(0.95, 0.9, 0.78))
	# range under the dial (and the clock, when the night keeps one)
	if _font:
		var t := "%d m" % int(RANGES[_range_i])
		if _clock != "":
			t = _clock + "   ·   " + t
		var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(_font, Vector2(c.x - w * 0.5, size.y + 22.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(INK, 0.6))
	_draw_moon(c, r)
	_draw_place(c, r)


## r33: the place's name on an engraved scroll over the dial (WoW's zone text), the tier under it.
func _draw_place(c: Vector2, r: float) -> void:
	if _region == "" or _font == null:
		return
	var pt := 16
	var w := _font.get_string_size(_region, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
	var sw := maxf(w + 34.0, 150.0)
	var top := c.y - r - 64.0
	var plate := Rect2(Vector2(c.x - sw * 0.5, top), Vector2(sw, 24))
	draw_rect(plate, Color(0.05, 0.038, 0.032, 0.88))
	draw_rect(plate, Color(RIM, 0.9), false, 1.5)
	for sx: float in [-1.0, 1.0]:
		var e := Vector2(c.x + sx * sw * 0.5, top + 12.0)
		draw_colored_polygon(PackedVector2Array([e + Vector2(0, -12), e + Vector2(sx * 9.0, 0), e + Vector2(0, 12)]), Color(0.05, 0.038, 0.032, 0.88))
		draw_polyline(PackedVector2Array([e + Vector2(0, -12), e + Vector2(sx * 9.0, 0), e + Vector2(0, 12)]), Color(RIM, 0.9), 1.5, true)
	var col: Color = TIER_COL[clampi(_tier_i, 0, TIER_COL.size() - 1)]
	draw_string_outline(_font, Vector2(plate.position.x, top + 18.0), _region, HORIZONTAL_ALIGNMENT_CENTER, sw, pt, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, Vector2(plate.position.x, top + 18.0), _region, HORIZONTAL_ALIGNMENT_CENTER, sw, pt, col)
	if _tier != "":
		draw_string_outline(_font, Vector2(plate.position.x, top + 38.0), _tier, HORIZONTAL_ALIGNMENT_CENTER, sw, 12, 4, Color(0, 0, 0, 0.75))
		draw_string(_font, Vector2(plate.position.x, top + 38.0), _tier, HORIZONTAL_ALIGNMENT_CENTER, sw, 12, Color(col, 0.75))


## r33: the moon on the rim, toward where it hangs (the zone's Moon light), a pale disc and crescent.
func _draw_moon(c: Vector2, r: float) -> void:
	if not is_instance_valid(_moon):
		return
	var back := _moon.global_basis.z                      # the light shines along -z: the moon is at +z
	var d := Vector2(back.x, back.z)
	if d.length() < 0.05:
		return
	var q := Vector2(d.normalized().dot(_right), -d.normalized().dot(_fwd))
	var p := c + q.normalized() * (r + 1.0)
	draw_circle(p, 9.0, Color(0.06, 0.045, 0.04, 0.95))
	draw_circle(p, 6.0, Color(0.86, 0.9, 1.0, 0.95))
	draw_circle(p + Vector2(2.6, -1.6), 5.0, Color(0.06, 0.045, 0.04, 0.95))


## r33: the map_marker glyphs. Quest kinds pin to the rim with a pointer; a new one pings.
func _draw_markers(c: Vector2, r: float, pulse: float) -> void:
	var labelled := 0
	var placed: Array[Rect2] = []                   # the name boxes already drawn this frame
	for m: Dictionary in _marks:
		var kind := String(m.kind)
		if not kind.begins_with("m:"):
			continue
		kind = kind.substr(2)
		if not HudPrefs.tracks(kind):
			continue
		# r33 merge: only what you are doing pins to the rim (hand-ins, targets); a giver's "!" shows
		# within AVAIL_NEAR only, as WoW's minimap does (Hearthward had a dozen "!" on the rim)
		var quest := kind in QUEST_KINDS and kind != "quest_available"
		if kind == "quest_available" and Vector2(m.pos.x - _you.x, m.pos.z - _you.z).length() > AVAIL_NEAR:
			continue
		var q := _place(m.pos, r - 10.0)
		if q.z > 0.0 and not quest:
			continue
		var p := c + Vector2(q.x, q.y)
		var col: Color = m.col
		var age := float(_new_marks.get(int(m.get("id", 0)), 9.0))
		if age < 2.4:
			var k := fposmod(age, 1.2) / 1.2
			draw_arc(p, 6.0 + k * 16.0, 0.0, TAU, 28, Color(col, 0.8 * (1.0 - k)), 2.0, true)
		if q.z > 0.0:
			# far: a small pointer on the rim, aimed out toward it
			var out := Vector2(q.x, q.y).normalized()
			var side := Vector2(-out.y, out.x)
			var tip := p + out * 7.0
			var tri := PackedVector2Array([tip, p - out * 2.0 + side * 5.0, p - out * 2.0 - side * 5.0])
			draw_colored_polygon(tri, Color(col, 0.9))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.08, 0.05, 0.02), 1.0, true)
			_glyph(kind, p - out * 9.0, Color(col, 0.85), 0.8)
			continue
		_glyph(kind, p, col, 1.0 if kind != "quest_target" else pulse)
		var label := String(m.get("label", ""))
		if label != "" and labelled < 2 and Vector2(q.x, q.y).length() < r * 0.4 and _font:
			var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			# r35: two pins a few metres apart wrote their names over each other ("OLD ZOOK" across
			# "THE HEARTHWARD FIRE"); the first keeps its name, a label that would touch it is dropped
			var box := Rect2(p + Vector2(-w * 0.5, 9.0), Vector2(w, 14.0)).grow(3.0)
			var free := true
			for b: Rect2 in placed:
				if b.intersects(box):
					free = false
					break
			if free:
				placed.append(box)
				labelled += 1
				draw_string_outline(_font, p + Vector2(-w * 0.5, 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
				draw_string(_font, p + Vector2(-w * 0.5, 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)


func _glyph(kind: String, p: Vector2, col: Color, s: float) -> void:
	var dark := Color(0.06, 0.045, 0.04, 0.92 * col.a)
	match kind:
		"quest_available", "quest_turnin":
			draw_circle(p, 7.5 * s, dark)
			draw_arc(p, 7.5 * s, 0.0, TAU, 24, Color(col, col.a * 0.9), 1.5, true)
			if _font:
				var t := "!" if kind == "quest_available" else "?"
				var pt := int(14 * s)
				var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
				draw_string(_font, p + Vector2(-w * 0.5, 5.5 * s), t, HORIZONTAL_ALIGNMENT_LEFT, -1, pt, col)
		"quest_target":
			draw_circle(p, 10.0 * s, Color(col, 0.18 * col.a))
			draw_arc(p, 10.0 * s, 0.0, TAU, 28, Color(col, col.a), 1.5, true)
			draw_circle(p, 3.0, col)
		"rare":
			var pts := PackedVector2Array()
			for k in 8:
				var a := -PI * 0.5 + TAU * float(k) / 8.0
				pts.append(p + Vector2(cos(a), sin(a)) * (8.0 if k % 2 == 0 else 3.2) * s)
			draw_colored_polygon(pts, col)
			pts.append(pts[0])
			draw_polyline(pts, dark, 1.0, true)
		"travel":
			draw_rect(Rect2(p + Vector2(-6, -3) * s, Vector2(12, 10) * s), dark)
			draw_arc(p + Vector2(0, -2) * s, 6.0 * s, PI, TAU, 14, col, 2.0, true)
			draw_line(p + Vector2(-6, -2) * s, p + Vector2(-6, 7) * s, col, 2.0)
			draw_line(p + Vector2(6, -2) * s, p + Vector2(6, 7) * s, col, 2.0)
			draw_circle(p + Vector2(0, 2) * s, 2.6 * s, Color(col, col.a * 0.7))
		"gather":
			draw_line(p + Vector2(0, 6) * s, p + Vector2(0, -5) * s, col.darkened(0.2), 1.5)
			for sx: float in [-1.0, 1.0]:
				var leaf := PackedVector2Array([p + Vector2(0, -1) * s, p + Vector2(sx * 6.0, -5.0) * s, p + Vector2(sx * 3.0, 1.0) * s])
				draw_colored_polygon(leaf, col)
		"vendor":
			draw_circle(p + Vector2(0, 1.5) * s, 6.0 * s, col)
			draw_rect(Rect2(p + Vector2(-2.5, -6.5) * s, Vector2(5, 3) * s), col)
			draw_line(p + Vector2(-3.5, -3.5) * s, p + Vector2(3.5, -3.5) * s, dark, 1.5)
			draw_circle(p + Vector2(0, 1.5) * s, 1.8 * s, dark)
		"trainer":
			var lp := PackedVector2Array([p + Vector2(0, -3) * s, p + Vector2(-7, -5) * s, p + Vector2(-7, 4) * s, p + Vector2(0, 6) * s])
			var rp := PackedVector2Array([p + Vector2(0, -3) * s, p + Vector2(7, -5) * s, p + Vector2(7, 4) * s, p + Vector2(0, 6) * s])
			draw_colored_polygon(lp, col)
			draw_colored_polygon(rp, col.darkened(0.15))
			draw_line(p + Vector2(0, -3) * s, p + Vector2(0, 6) * s, dark, 1.2)
		_:
			_diamond(p, 4.5 * s, col)


func _diamond(p: Vector2, d: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), col)


func _flame(p: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(4, 1), p + Vector2(2.5, 4), p + Vector2(-2.5, 4), p + Vector2(-4, 1)]), col)


func _gate(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p - Vector2(6, 5), Vector2(12, 10)), Color(0.06, 0.045, 0.04, 0.9 * col.a))
	for i in 3:
		var x := -4.0 + 4.0 * i
		draw_line(p + Vector2(x, -4), p + Vector2(x, 4), col, 1.5)
	draw_line(p + Vector2(-6, -5), p + Vector2(6, -5), col, 1.5)


func _crown(p: Vector2, col: Color) -> void:
	draw_circle(p, 7.5, Color(0.06, 0.045, 0.04, 0.9 * col.a))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 3.5), p + Vector2(-5, -3), p + Vector2(-2.5, 0), p + Vector2(0, -4.5), p + Vector2(2.5, 0), p + Vector2(5, -3), p + Vector2(5, 3.5)]), col)


# --- the painted ground -------------------------------------------------------------------------

func _bake_step() -> void:
	if _tex != null:
		return
	if _task == -1:
		if Land._h.is_empty():
			return
		_origin = RealmLayout.BOUNDS.position
		_size_m = RealmLayout.BOUNDS.size
		_task = WorkerThreadPool.add_task(_paint)
	elif WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -2
		if _img:
			_tex = ImageTexture.create_from_image(_img)
			_mat.set_shader_parameter("map_tex", _tex)
			_img = null


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


const BIOME_COL := {
	"meadow": Color(0.42, 0.47, 0.27), "glade": Color(0.36, 0.5, 0.4), "oldforest": Color(0.23, 0.31, 0.2),
	"fen": Color(0.3, 0.35, 0.29), "ash": Color(0.27, 0.21, 0.19), "heath": Color(0.5, 0.42, 0.3),
	"crag": Color(0.46, 0.44, 0.42), "ruin": Color(0.43, 0.39, 0.33),
}


## Worker thread: reads RealmLand's finished static arrays only (nothing writes them after build).
func _paint() -> void:
	var w := int(_size_m.x * PPM)
	var h := int(_size_m.y * PPM)
	var step := 1.0 / PPM
	# biome colours on a 2 m lattice, blended per pixel (biome_at is the costly call)
	var bs := 2.0
	var bw := int(_size_m.x / bs) + 2
	var bh := int(_size_m.y / bs) + 2
	var bcol := PackedColorArray()
	bcol.resize(bw * bh)
	for j in bh:
		for i in bw:
			var b := RealmLayout.biome_at(_origin.x + i * bs, _origin.y + j * bs)
			bcol[j * bw + i] = BIOME_COL.get(b, BIOME_COL.meadow)
	var hs := PackedFloat32Array()
	hs.resize(w * h)
	for y in h:
		var z := _origin.y + (y + 0.5) * step
		for x in w:
			hs[y * w + x] = Land.height_at(_origin.x + (x + 0.5) * step, z)
	var wear: PackedFloat32Array = Land._wear_g
	var lava_y := RealmLayout.LAVA_Y
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var light := Vector3(-0.55, 0.75, -0.4).normalized()          # from the north-west, as maps are lit
	var d := 2                                                     # derivative span in px (1 m)
	for y in h:
		var z := _origin.y + (y + 0.5) * step
		var y0 := maxi(y - d, 0)
		var y1 := mini(y + d, h - 1)
		for x in w:
			var wx := _origin.x + (x + 0.5) * step
			var hc := hs[y * w + x]
			var hx := hs[y * w + mini(x + d, w - 1)] - hs[y * w + maxi(x - d, 0)]
			var hz := hs[y1 * w + x] - hs[y0 * w + x]
			var nrm := Vector3(-hx, 2.0, -hz).normalized()
			var shade := clampf(nrm.dot(light) * 1.25, 0.25, 1.25)
			var fx := (wx - _origin.x) / bs
			var fz := (z - _origin.y) / bs
			var i0 := clampi(int(fx), 0, bw - 2)
			var j0 := clampi(int(fz), 0, bh - 2)
			var tx := clampf(fx - i0, 0.0, 1.0)
			var tz := clampf(fz - j0, 0.0, 1.0)
			var col := bcol[j0 * bw + i0].lerp(bcol[j0 * bw + i0 + 1], tx).lerp(
				bcol[(j0 + 1) * bw + i0].lerp(bcol[(j0 + 1) * bw + i0 + 1], tx), tz)
			# height: the high ground paler
			col = col.lerp(Color(0.72, 0.66, 0.56), clampf((hc - 4.0) / 30.0, 0.0, 0.45))
			col = col * shade
			# worn paths
			if not wear.is_empty():
				var gfx := clampf((wx - Land.GX0) / Land.STEP, 0.0, Land.GNX - 1.001)
				var gfz := clampf((z - Land.GZ0) / Land.STEP, 0.0, Land.GNZ - 1.001)
				var gi := floori(gfx)
				var gj := floori(gfz)
				var gtx := gfx - gi
				var gtz := gfz - gj
				var wv := lerpf(lerpf(wear[gj * Land.GNX + gi], wear[gj * Land.GNX + gi + 1], gtx),
					lerpf(wear[(gj + 1) * Land.GNX + gi], wear[(gj + 1) * Land.GNX + gi + 1], gtx), gtz)
				wv = smoothstep(0.08, 0.35, wv)
				if wv > 0.0:
					col = col.lerp(Color(0.78, 0.68, 0.5) * clampf(shade, 0.8, 1.1), wv * 0.85)
			# water and lava
			if hc < Land.WATER_Y + 0.05 and Land.in_water(wx, z):
				col = Color(0.2, 0.3, 0.36).lerp(Color(0.32, 0.42, 0.46), clampf(shade - 0.6, 0.0, 1.0))
			elif hc < lava_y + 1.2:
				col = Color(0.85, 0.3, 0.08).lerp(Color(1.0, 0.62, 0.22), clampf(sin(wx * 0.4) * sin(z * 0.35) * 0.5 + 0.5, 0.0, 1.0) * 0.4)
			# contours every 4 m
			var cl := absf(fposmod(hc + 2.0, 4.0) - 2.0)
			if cl < 0.12 and hc > lava_y + 2.0:
				col = col.darkened(0.18)
			img.set_pixel(x, y, col)
	_paint_crossing(img)
	_img = img


## The Crossing is not in the heightfield (it stands over the lava): its deck as a stone line.
func _paint_crossing(img: Image) -> void:
	var pts: Array[Vector2] = [Vector2(0, -7), Vector2(0, -21), Vector2(-13, -30), Vector2(-1.8, -40),
		Vector2(-8.3 + 6.5, -50), Vector2(-8.3, -56.5), Vector2(-14.8, -50), Vector2(-8.3, -43.5), Vector2(0, -62), Vector2(0, -71)]
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var n := int(a.distance_to(b) * PPM * 2.0) + 1
		for s in n + 1:
			var p := a.lerp(b, float(s) / float(n))
			var cx := int((p.x - _origin.x) * PPM)
			var cy := int((p.y - _origin.y) * PPM)
			for oy in range(-3, 4):
				for ox in range(-3, 4):
					var px := cx + ox
					var py := cy + oy
					if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
						continue
					var d := Vector2(ox, oy).length()
					if d <= 3.2:
						img.set_pixel(px, py, Color(0.62, 0.58, 0.52) if d < 2.2 else Color(0.2, 0.16, 0.14))

extends RefCounted
## THE LIVING NIGHT'S WARM-UP (behind the loading cover). Everything the night draws that the engine would otherwise build or compile the first time
## it appears in play (a pipeline for a material, a particle emitter and its process material, a MultiMesh's first buffer) is drawn here once, in
## view of the warm camera the loading screen tours with (ui/loading_screen.gd calls `show` where it shows the combat set):
##   the far card, the ground pool, the moth, the mist bank, the puddle glint (each its real material, on a real MultiMesh with per-instance colour),
##   the level-up column, the log and the net, a dog and a cat (the wildlife fox body and its creature shader), a bat (its orbit shader),
##   and every particle burst preset of night_fx.gd in every colour it is thrown in (the emitters are built and pooled now).
## The nodes are returned for the loading screen to free with its other warm-up nodes. `COVERED` names every file under core/world/night_life and
## core/life/folk that builds a material or throws a burst and says how it is covered here: zz/night_life_test.tscn fails if a file that does is not
## listed, so a new system cannot add an unwarmed material. Static; load by path.

const NightFx := preload("res://core/world/night_life/night_fx.gd")
const Signatures := preload("res://core/world/night_life/light_signatures.gd")
const Moths := preload("res://core/world/night_life/light_moths.gd")
const Banks := preload("res://core/world/night_life/fog_banks.gd")
const Weather := preload("res://core/world/night_life/weather_life.gd")
const Library := preload("res://core/world/night_life/vfx_library.gd")
const Arena := preload("res://core/world/night_life/arena_light.gd")
const Stage := preload("res://core/life/folk/folk_stage.gd")
const Kit := preload("res://core/life/wildlife/life_kit.gd")

## file (basename) -> how it is covered
const COVERED := {
	"light_signatures.gd": "card_material and pool_material on one MultiMesh each (show)",
	"light_moths.gd": "material on a MultiMesh (show)",
	"fog_banks.gd": "material on a MultiMesh (show)",
	"weather_life.gd": "material on a MultiMesh (show); its drip and steam bursts are night_fx presets",
	"vfx_library.gd": "column_material on a quad (show); every burst is a night_fx preset",
	"folk_stage.gd": "log_material, net_material and iron_material (show)",
	"pets.gd": "the fox creature material, one instance (show)",
	"fire_bats.gd": "the bat orbit material, one instance (show)",
	"night_fx.gd": "every preset in every colour (show)",
	"hit_reads.gd": "night_fx presets",
	"folk_more.gd": "night_fx presets (chips, spark)",
	"kindling_surge.gd": "night_fx presets",
	"mystery_lights.gd": "night_fx presets",
	"telegraph_glow.gd": "night_fx presets",
	"wanderer_life.gd": "night_fx presets",
	"arena_light.gd": "night_fx presets (the arena palettes' colours)",
}


static func show(host: Node3D, c: Vector3, right: Vector3, fwd: Vector3) -> Array[Node]:
	var out: Array[Node] = []
	if not Settings.night_life:
		return out
	var up := Vector3.UP
	# the far card and the others on a MultiMesh with colours (the instanced path the night uses)
	_quad(host, out, Signatures.card_material(), false, c + up * 1.4 - right * 2.0, 0.6)
	_quad(host, out, Signatures.pool_material(), true, c + up * 0.05 - right * 0.5, 2.0)
	_quad(host, out, Moths.material(), false, c + up * 1.4 + right * 0.5, 0.3)
	_quad(host, out, Banks.material(), true, c + up * 0.4 + right * 2.0, 3.0)
	_quad(host, out, Weather.material(), true, c + up * 0.06 + right * 3.5, 1.5)
	# the level-up column (a single quad, billboard about the vertical)
	var col := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 3.0)
	col.mesh = q
	col.material_override = Library.column_material()
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(col)
	col.global_position = c + up * 1.5 + right * 5.0
	out.append(col)
	# the log and the net
	var lg := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 1.0
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	lg.mesh = cyl
	lg.material_override = Stage.log_material()
	host.add_child(lg)
	lg.global_position = c + up * 0.2 - right * 4.0
	out.append(lg)
	var nq := QuadMesh.new()
	nq.size = Vector2(1.0, 1.0)
	nq.orientation = PlaneMesh.FACE_Y
	var net := MeshInstance3D.new()
	net.mesh = nq
	net.material_override = Stage.net_material()
	host.add_child(net)
	net.global_position = c + up * 0.3 - right * 5.2
	out.append(net)
	var anvil := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.28, 0.2, 0.62)
	anvil.mesh = bx
	anvil.material_override = Stage.iron_material()
	host.add_child(anvil)
	anvil.global_position = c + up * 0.5 - right * 6.2
	out.append(anvil)
	# a dog or a cat (the fox body) and a bat: each creature group with one instance
	var at := 0.0
	for kind: String in ["fox", "bat"]:
		var g := Kit.group(kind, 1)
		g.multimesh.custom_aabb = AABB(Vector3(-50, -10, -50), Vector3(100, 40, 100))
		host.add_child(g)
		g.global_position = Vector3.ZERO
		g.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), c + up * (0.0 if kind == "fox" else 2.0) + right * (6.0 + at)))
		g.multimesh.set_instance_custom_data(0, Color(0.5, 0.0, 0.0, 0.0) if kind == "fox" else Color(1.5, 0.6, 2.0, 0.0))
		out.append(g)
		at += 1.5
	# the bursts: one of each preset in each colour it is ever thrown in
	var n := 0
	for row: Array in NightFx.warm_list(Arena.PAL):
		NightFx.burst(c + up * (0.8 + 0.02 * float(n)) + fwd * 0.5, row[1], String(row[0]), Vector3.ZERO, 0.25)
		n += 1
	return out


## One instance of `mat` on a MultiMesh with per-instance colour (the way the night uses each), `flat` lying on the ground, at `at`, `size` metres.
static func _quad(host: Node3D, out: Array[Node], mat: Material, flat: bool, at: Vector3, size: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	if flat:
		quad.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), at))
	mm.set_instance_color(0, Color(1.0, 1.0, 1.0, 0.5))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-2000, -400, -2000), Vector3(4000, 1200, 4000))
	host.add_child(mi)
	mi.global_position = Vector3.ZERO
	out.append(mi)

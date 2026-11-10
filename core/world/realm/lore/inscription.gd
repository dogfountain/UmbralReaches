extends LoreScrap
## A LoreScrap whose stone, page or board is part of a landmark's merged mesh (RealmLore builds it
## into the landmark's OssKit), so it adds no draw calls of its own. Reads a LoreDB entry: the
## prompt names what it is ("Read the waystone"). Reading records it in the journal (CodexStore)
## and opens the reading panel (ui/codex.gd, group "codex"); with no codex in the scene it falls
## back to one toast "Title: text", wrapped for the HUD's toast label.
## Until it is read, a small ember glint hovers over it (visible to ~26 m): the night cue that
## something here can be read. It goes out once read (this session or an earlier one).

const LoreDB := preload("res://core/world/realm/lore_db.gd")
const LoreIndex := preload("res://core/world/realm/lore/lore_index.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const WRAP := 78
const GLINT_RANGE := 26.0

var lore_id := ""
var kind := "tablet"
var title := ""
var mark := Vector3.INF            ## world point of the carving (glint sits just above it)

static var _glint_mesh: QuadMesh
static var _glint_mat: ShaderMaterial


## Drop the engine resources held in static vars (called when the night is torn down): statics
## outlive the renderer at quit ("RID allocations leaked at exit"). Rebuilt on next use.
static func release() -> void:
	_glint_mesh = null
	_glint_mat = null
var _glint: MeshInstance3D


static func make(id: String) -> Node3D:
	var s: Node3D = (load("res://core/world/realm/lore/inscription.gd") as GDScript).new()
	var e := LoreIndex.entry(id)
	s.set("lore_id", id)
	s.set("kind", String(e.get("kind", "tablet")))
	s.set("title", String(e.get("title", "")))
	s.set("body", String(e.get("text", "")))
	s.name = "Lore_" + id
	return s


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	_read = CodexStore.has_read(lore_id)
	if not _read:
		_add_glint()


func interact_text() -> String:
	var key := Interactable.prompt_key()
	var what := "the " + LoreDB.kind_name(kind)
	return ("[%s]  Read %s" % [key, what]) if not _read else ("[%s]  Read %s again" % [key, what])


func interact(_by: Node) -> void:
	_read = true
	var fresh := CodexStore.record_read(lore_id)
	if _glint:
		_glint.queue_free()
		_glint = null
	if body == "":
		return
	var codex: Node = get_tree().get_first_node_in_group("codex") if is_inside_tree() else null
	if codex and codex.has_method("show_reading"):
		codex.call("show_reading", lore_id, self, fresh)
	else:
		Events.toast.emit(wrapped())


func wrapped() -> String:
	var words := ((title + ": ") if title != "" else "") + body
	var lines := PackedStringArray()
	var line := ""
	for w in words.split(" ", false):
		if line.length() + w.length() + 1 > WRAP and line != "":
			lines.append(line)
			line = w
		else:
			line = w if line == "" else line + " " + w
	if line != "":
		lines.append(line)
	return "\n".join(lines)


func _add_glint() -> void:
	if _glint_mesh == null:
		_glint_mesh = QuadMesh.new()
		_glint_mesh.size = Vector2(0.34, 0.34)
		var sh := Shader.new()
		sh.code = GLINT_SHADER
		_glint_mat = ShaderMaterial.new()
		_glint_mat.shader = sh
		_glint_mesh.material = _glint_mat
	_glint = MeshInstance3D.new()
	_glint.name = "Glint"
	_glint.mesh = _glint_mesh
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint.visibility_range_end = GLINT_RANGE
	_glint.visibility_range_end_margin = 4.0
	_glint.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_glint.set_instance_shader_parameter(&"phase", float(absi(lore_id.hash()) % 1000) * 0.0063)
	add_child(_glint)
	# `mark` is world space; RealmLore holders sit at the origin, so local = mark - position
	_glint.position = Vector3.UP * 0.75 if mark == Vector3.INF else (mark - position) + Vector3.UP * 0.32


## An ember mote: a soft core and a faint halo, breathing slowly, drifting a few centimetres.
## Billboarded, additive, unshaded; peak emission stays under the glow threshold except the
## pinpoint core (a cue, not a lamp).
const GLINT_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
instance uniform float phase = 0.0;
varying float pulse;
void vertex() {
	float t = TIME * 0.9 + phase * 6.2831;
	pulse = 0.55 + 0.45 * sin(t);
	vec3 drift = vec3(sin(t * 0.7) * 0.03, sin(t * 0.5 + 1.3) * 0.06, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3] + vec4(drift, 0.0));
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float core = smoothstep(0.22, 0.0, d);
	float halo = smoothstep(1.0, 0.1, d) * 0.22;
	vec3 col = vec3(1.0, 0.55, 0.22) * (core * 1.25 + halo) * pulse;
	ALBEDO = col;
	ALPHA = clamp(core + halo, 0.0, 1.0);
}
"""

class_name BootDiag
extends RefCounted
## One-shot night audit. Writes user://umbral_diag.log, push_error on fails, HUD toast + F3 line.

static var summary := ""
static var fail_count := 0
static var log_path := ""

const GLBS := [
	"res://art/models/brazier.glb",
	"res://art/models/lantern.glb",
	"res://art/models/menhir.glb",
	"res://art/models/staff.glb",
	"res://art/models/hand_lantern.glb",
	"res://art/models/boot.glb",
	"res://art/models/gauntlet.glb",
	"res://art/models/wretch_torso.glb",
	"res://art/models/wretch_head.glb",
	"res://art/models/husk_torso.glb",
	"res://art/models/husk_head.glb",
	"res://art/models/rock_a.glb",
	"res://art/models/stair_step.glb",
	"res://art/models/robe_torso.glb",
	"res://art/models/robe_hood.glb",
	"res://art/models/robe_sleeve.glb",
]

const TEXS := [
	"res://art/textures/robe_albedo.png",
	"res://art/textures/robe_magic.png",
	"res://art/textures/robe_normal.png",
]


const Check := preload("res://core/debug/check.gd")


static func run(root: Node) -> void:
	if root == null:
		push_error("BOOT_DIAG root null")
		summary = "FAIL root null"
		return
	if root.get_tree() == null:
		push_error("BOOT_DIAG tree null")
		summary = "FAIL tree null"
		return
	var lines: PackedStringArray = PackedStringArray()
	fail_count = 0
	_line(lines, "=== Umbral diag %s ===" % Time.get_time_string_from_system())
	_line(lines, "exe=%s" % OS.get_executable_path())
	_line(lines, "user=%s" % OS.get_user_data_dir())
	_line(lines, "standalone=%s debug=%s scene=%s" % [
		OS.has_feature("standalone"), OS.is_debug_build(), str(root.name)
	])
	_glbs(lines)
	_texs(lines)
	_player(root, lines)
	_dressed(root, lines)
	_grass(root, lines)
	summary = "%d FAIL  %s" % [fail_count, "ok" if fail_count == 0 else "see user://umbral_diag.log"]
	_line(lines, summary)
	_write(lines)
	if fail_count > 0:
		push_error("BOOT_DIAG %s" % summary)
		Events.toast.emit("DIAG: %d error(s). F3 · umbral_diag.log" % fail_count)
	else:
		print("BOOT_DIAG %s" % summary)
		Events.toast.emit("DIAG: meshes ok · grass tint logged. F3")


static func _glbs(lines: PackedStringArray) -> void:
	for path in GLBS:
		var inst := Check.scene(path)
		if inst == null:
			_fail(lines, "MISSING/LOAD %s" % path)
			continue
		var n := Check.mesh_count(inst)
		var names: PackedStringArray = PackedStringArray()
		if inst is MeshInstance3D:
			names.append(String(inst.name))
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			names.append(String(mi.name))
		if n == 0:
			_fail(lines, "EMPTY_MESH %s" % path)
		else:
			_line(lines, "GLB %s meshes=%d [%s]" % [path.get_file(), n, ", ".join(names)])
		inst.free()


static func _texs(lines: PackedStringArray) -> void:
	for path in TEXS:
		var tex := Check.res(path, Texture2D) as Texture2D
		if tex == null:
			_fail(lines, "MISSING/LOAD %s" % path)
			continue
		var w := tex.get_width()
		var h := tex.get_height()
		_line(lines, "TEX %s %dx%d" % [path.get_file(), w, h])
		if w < 512 or h < 512:
			_fail(lines, "TEX %s too small %dx%d" % [path.get_file(), w, h])


static func _player(root: Node, lines: PackedStringArray) -> void:
	var player := root.get_tree().get_first_node_in_group(Groups.PLAYER)
	if player == null:
		_fail(lines, "NO_PLAYER")
		return
	var visual := player.get_node_or_null("Visual")
	if visual == null:
		_fail(lines, "NO_VISUAL")
		return
	# the generated wanderer (core/player/wanderer_gen.gd) has no boot/gauntlet GLB pieces
	var keys := ["BootMesh", "GauntletMesh", "StaffMesh", "LanternMesh"] if DefaultLoadout.use_legacy else ["StaffMesh", "LanternMesh"]
	if visual.has_method("has_merged_body") and visual.has_merged_body():
		keys = ["Body", "ShadowProxy"]          # the gear is baked into one skinned mesh (wanderer_body.gd)
	for key in keys:
		var found := visual.find_children(key, "", true, false)
		if found.is_empty():
			_fail(lines, "PLAYER missing %s (glb did not attach)" % key)
		else:
			var meshes := 0
			for n in found:
				meshes += n.find_children("*", "MeshInstance3D", true, false).size()
				if n is MeshInstance3D:
					meshes += 1
			_line(lines, "PLAYER %s x%d meshes=%d" % [key, found.size(), meshes])
			if meshes == 0:
				_fail(lines, "PLAYER %s has no MeshInstance3D" % key)


static func _dressed(root: Node, lines: PackedStringArray) -> void:
	var braziers := 0
	var lamps := 0
	var menhirs := 0
	for n in root.find_children("DressedBrazier", "", true, false):
		braziers += 1
		_expect_prefix(n, "Plinth", lines)
		_expect_prefix(n, "Bowl", lines)
	for n in root.find_children("DressedLantern", "", true, false):
		lamps += 1
		_expect_prefix(n, "Post", lines)
		_expect_prefix(n, "Iron", lines)
		_expect_prefix(n, "Ember", lines)
	for n in root.find_children("*", "Node3D", true, false):
		if String(n.name).begins_with("Menhir"):
			menhirs += 1
	_line(lines, "DRESS braziers=%d lamps=%d menhirs=%d" % [braziers, lamps, menhirs])
	if braziers == 0:
		_fail(lines, "DRESS no DressedBrazier in scene")


static func _expect_prefix(model: Node, prefix: String, lines: PackedStringArray) -> void:
	var n := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with(prefix):
			n += 1
	if n == 0:
		_fail(lines, "DRESS %s missing prefix %s" % [model.name, prefix])


static func _grass(root: Node, lines: PackedStringArray) -> void:
	var chunks := 0
	var blades := 0
	var sample := Color.BLACK
	var tint := Vector3.ZERO
	var rim := Vector3.ZERO
	var got_tint := false
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		if not String(node.name).to_lower().begins_with("grass"):
			continue
		chunks += 1
		var mmi := node as MultiMeshInstance3D
		var sm := mmi.material_override as ShaderMaterial
		if sm:
			var t = sm.get_shader_parameter("tint")
			var r = sm.get_shader_parameter("rim_color")
			if t is Color:
				tint = Vector3(t.r, t.g, t.b)
			elif t is Vector3:
				tint = t
			if r is Vector3:
				rim = r
			elif r is Color:
				rim = Vector3(r.r, r.g, r.b)
			got_tint = true
		var mm := mmi.multimesh
		if mm:
			blades += mm.instance_count
			if mm.use_colors and mm.instance_count > 0:
				sample = mm.get_instance_color(0)
	_line(lines, "GRASS chunks=%d blades=%d tint=(%.2f,%.2f,%.2f) rim=(%.2f,%.2f,%.2f) instance0=%s" % [
		chunks, blades, tint.x, tint.y, tint.z, rim.x, rim.y, rim.z, str(sample)
	])
static func _line(lines: PackedStringArray, text: String) -> void:
	lines.append(text)
	print("DIAG ", text)


static func _fail(lines: PackedStringArray, text: String) -> void:
	fail_count += 1
	lines.append("FAIL " + text)
	push_error("DIAG " + text)


static func _write(lines: PackedStringArray) -> void:
	var f := FileAccess.open("user://umbral_diag.log", FileAccess.WRITE)
	if f == null:
		push_error("DIAG cannot write user://umbral_diag.log err=%s" % FileAccess.get_open_error())
		return
	f.store_string("\n".join(lines) + "\n")
	log_path = f.get_path_absolute()
	print("DIAG wrote ", log_path)

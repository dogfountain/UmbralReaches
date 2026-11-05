extends Node
## Loads every skills/progression script (B, r28) with the autoloads up: a fast compile check.
##   godot --headless --path . res://zz/skill_compile.tscn
func _ready() -> void:
	var paths := ["res://core/player/character_rig.gd", "res://core/skills/skill.gd", "res://core/skills/skill_book.gd", "res://core/skills/combo.gd", "res://core/skills/afflict.gd",
		"res://core/skills/aim.gd", "res://core/skills/tether_chain.gd", "res://core/skills/skill_tether.gd", "res://core/skills/umbral_well.gd",
		"res://core/skills/skill_well.gd", "res://core/skills/bound_shade.gd", "res://core/skills/skill_familiar.gd", "res://core/skills/orb_core.gd",
		"res://core/skills/skill_nova.gd", "res://core/player/magic_bolt.gd", "res://core/vfx/staff_sfx.gd",
		"res://core/life/progression/upgrade_db.gd", "res://core/life/progression/kindling.gd", "res://core/life/progression/icons.gd",
		"res://core/life/progression/core_pickup.gd", "res://core/life/progression/skills/bolt.gd", "res://core/life/progression/skills/lance.gd",
		"res://core/life/progression/skills/nova.gd", "res://core/life/progression/skills/ward.gd", "res://core/life/progression/skills/step.gd",
		"res://core/life/progression/fx/ward_aura.gd", "res://core/life/progression/fx/ember_cinders.gd", "res://core/items/item_db.gd",
		"res://ui/growth.gd", "res://ui/hotbar.gd", "res://ui/satchel.gd"]
	for extra in OS.get_cmdline_user_args():
		paths.append(extra)
	var bad := 0
	for p in paths:
		print("LOAD ", p)
		var s = load(p)
		if s == null or (s is GDScript and not (s as GDScript).can_instantiate()):
			print("COMPILE FAIL ", p)
			bad += 1
	print("COMPILE DONE bad=", bad)
	get_tree().quit()

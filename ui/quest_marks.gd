extends RefCounted
## Painted marks for the quest log, the quest offer and the codex lists: a task's kind (find, talk, slay ...),
## what it pays (ash, goods, a charm, gear), and the kind of thing a codex entry is (a grave, a page, a rune).
## The art is ui/icons/task, reward and lore, from tools/icon_kit/lore.py. Preload it where needed
## (`const QuestMarks := preload("res://ui/quest_marks.gd")`); no class_name.

const ICON := 30.0


static func task_art(kind: String) -> Texture2D:
	return IconArt.art("task", kind)


static func lore_art(kind: String) -> Texture2D:
	return IconArt.art("lore", kind)


## The one mark for a reward: ash first, then goods, then a charm; gear when a piece is on offer.
static func reward_art(r: Dictionary, gear := false) -> Texture2D:
	if gear:
		return IconArt.art("reward", "gear")
	if int(r.get("ash", 0)) > 0:
		return IconArt.art("reward", "ash")
	if not (r.get("items", {}) as Dictionary).is_empty():
		return IconArt.art("reward", "item")
	if String(r.get("charm", "")) != "":
		return IconArt.art("reward", "charm")
	return null


## A line with a small painted mark before it: an HBox added to `host` holding the icon and the label (the label
## takes the rest of the width and wraps). Returns the icon, so a caller that keeps the row can change it later.
static func row(host: Node, label: Label, tex: Texture2D, size := ICON, dim := false) -> TextureRect:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = tex
	ic.visible = tex != null
	ic.custom_minimum_size = Vector2(size, size)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		ic.modulate = Color(1, 1, 1, 0.5)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ic)
	h.add_child(label)
	host.add_child(h)
	return ic


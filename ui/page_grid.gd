extends RefCounted
## The character screen's one layout grid: every page (Gear, Charms, Relics, Staff, Kindling, Pack, the Journal's
## pages, Tasks) fills the same rectangle under the tab band, so no page floats small in an empty screen while
## another is crammed. A page's window takes the whole cell and lays its own content out inside it (lists on the
## left, the page or detail on the right, both expanding).
## Load by path (no class_name): const PageGrid := preload("res://ui/page_grid.gd")

const TOP := 148.0              ## under the band (ui/character_screen.gd BAND_H) and its gilt edge
const SIDE := 30.0
const BOTTOM := 30.0


## A full-rect MarginContainer holding the cell: add the page's window to it (it should fill: SIZE_EXPAND_FILL).
static func cell(parent: Node) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_top", int(TOP))
	m.add_theme_constant_override("margin_bottom", int(BOTTOM))
	m.add_theme_constant_override("margin_left", int(SIDE))
	m.add_theme_constant_override("margin_right", int(SIDE))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	return m


## Put a window that is added straight to a root (not through cell()) on the same rectangle.
static func place(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.offset_left = SIDE
	c.offset_right = -SIDE
	c.offset_top = TOP
	c.offset_bottom = -BOTTOM

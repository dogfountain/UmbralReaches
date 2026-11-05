extends RefCounted
## One type system for every screen (r30): Cinzel for titles and names only, one serif for all body
## text (dialogue lines, choices, subtitles, codex pages, the growth book). Body text used to be a
## per-screen SystemFont in three places and the Godot default sans in the dialogue box.
## Load by path (no class_name): const UIType := preload("res://ui/type.gd")

const TITLE_PATH := "res://ui/fonts/Cinzel.ttf"
## Bundle an OFL text serif (EB Garamond / Cormorant) here to stop depending on the platform's.
const BODY_PATH := "res://ui/fonts/body_serif.ttf"
const BODY_STACK := ["Georgia", "Palatino", "Book Antiqua", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"]

static var _title: Font
static var _body: Font


static func title() -> Font:
	if _title == null and ResourceLoader.exists(TITLE_PATH):
		_title = load(TITLE_PATH)
	return _title


static func body() -> Font:
	if _body == null:
		if ResourceLoader.exists(BODY_PATH):
			_body = load(BODY_PATH)
		else:
			var sf := SystemFont.new()
			sf.font_names = PackedStringArray(BODY_STACK)
			_body = sf
	return _body

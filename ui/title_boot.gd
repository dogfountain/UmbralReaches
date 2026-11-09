extends Node
## The project's first scene (project.godot run/main_scene). On a real launch it shows the title screen, lets
## the player pick Continue / New Game / a slot, points Travel at that slot, then loads the night
## (world/main.tscn) with its loading screen as before. Under a test or a harness flag (see
## TitleScreen.wanted()) it goes straight to the night with no title and the default slot, so every
## zz harness and `-- --demo` run behaves as it did.
## Also the place the game returns to after "Erase Saved Progress" (Travel.to_title()).

const TitleScreen := preload("res://ui/title_screen.gd")
const NIGHT := "res://world/main.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# between the title being freed and the night's loading screen drawing, nothing covers the window: the clear
	# colour is what shows. Godot's default is mid grey (a grey flash after Continue, Luke 9 Nov): the loading
	# screen's own near-black instead (ui/loading_screen.gd BG)
	RenderingServer.set_default_clear_color(Color(0.03, 0.02, 0.012))
	if not Travel.forced_title and not TitleScreen.wanted():
		_go.call_deferred()
		return
	Travel.forced_title = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var title := TitleScreen.new()
	title.name = "TitleScreen"
	add_child(title)
	title.chosen.connect(func(slot: int, fresh: bool) -> void:
		Travel.use_slot(slot, fresh)
		await get_tree().create_timer(0.25).timeout
		_go())


func _go() -> void:
	get_tree().change_scene_to_file(NIGHT)

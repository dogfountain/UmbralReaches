extends Node
## Writes the life system's generated sounds to res://art/audio/life/<kind>.wav (LifeSynth.build),
## then: godot --headless --path . --import --quit   so they are imported like any other asset.
##   godot --headless --path . res://zz/life_gen_audio.tscn
const LifeSynth := preload("res://core/life/wildlife/life_synth.gd")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LifeSynth.DIR))
	for kind: String in LifeSynth.KINDS:
		var t := Time.get_ticks_msec()
		var s := LifeSynth.build(kind)
		var err := s.save_to_wav(ProjectSettings.globalize_path(LifeSynth.DIR + kind + ".wav"))
		print("LIFE_AUDIO %s %.2f s err=%d (%d ms)" % [kind, s.get_length(), err, Time.get_ticks_msec() - t])
	get_tree().quit()

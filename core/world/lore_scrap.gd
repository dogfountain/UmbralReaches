class_name LoreScrap
extends Interactable
## A short inscription. One toast. E to read.


var body := ""
var _read := false


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)


func can_interact() -> bool:
	return true


func interact_text() -> String:
	var key := Interactable.prompt_key()
	return "[%s]  Read the inscription" % key if not _read else "[%s]  Read again" % key


func interact(_by: Node) -> void:
	_read = true
	if body != "":
		Events.toast.emit(body)


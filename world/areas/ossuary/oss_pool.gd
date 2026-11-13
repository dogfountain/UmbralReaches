class_name OssPool
extends Lava
## The Ossuary's still pool: where the chasm had lava, the pit has dark water. A fall from the bridge or a
## tier is not a death: the pool gives you back at the last ground you stood on, as the starwater does in
## the Rift (a Wound, the toast, a rift-in at the spot). No pull of its own, no burn.


func _on_body_entered(body: Node3D) -> void:
	var p := body as Player
	if p != null:
		p.lava_burn(LAVA_GLOOM * 0.5, true)

extends "res://core/life/progression/charm_pickup.gd"
## A staff core lying in the world (progression, r28): a glowing stone on a flat rock, like a
## charm (no light of its own: the glint and motes carry it at night). [E] takes it; with the
## Hollow Core in the orb it goes in at once (kindling.gd), otherwise it waits to be set at a fire
## (Kindling, Staff).


func interact(_by: Node) -> void:
	if Travel.count(item_id) > 0:
		return
	var had := String(Travel.system_state("progression").get("core", ""))
	Travel.give(item_id, 1)
	if had != "":
		Events.toast.emit("%s. Set it in the orb at a kindled fire: Kindling [K], Staff." % ItemDB.def(item_id).name)
	remove_from_group(Groups.INTERACTABLE)
	var tint: Color = ItemDB.def(item_id).get("tint", Color.WHITE)
	Vfx.burst(global_position + Vector3.UP * 0.55, Color(tint.r * 2.6, tint.g * 2.6, tint.b * 2.6), {"count": 40, "life": 0.7, "speed": Vector2(1.0, 4.0), "size": 0.045, "gravity": -2.0, "trail": 0.07})
	Sfx.play("res://art/audio/ward_chime.wav", global_position, -4.0, 0.9)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE * 0.01, 0.4)
	tw.parallel().tween_property(_glint, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)

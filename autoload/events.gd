extends Node
## Global event bus. Gameplay emits; UI, VFX and audio only listen.

signal gloom_changed(value: float, max_value: float)
signal interact_hint(text: String)          ## "" hides the prompt
signal brazier_kindled(brazier: Node3D)
signal shade_spawned()
signal enemy_killed(enemy: Node)
signal hollowed()
signal respawned(at: Vector3)
signal toast(text: String)
signal zone_entered(title: String, subtitle: String)
signal autopilot_reached(marker_name: String)
signal autopilot_finished()
signal benchmark_done(summary: String)
signal skill_cast(id: StringName)
signal skill_failed(id: StringName, reason: String)      ## F8 sampler result, pinned in the F3 overlay

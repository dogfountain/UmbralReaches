extends Node
## Global event bus. Gameplay emits; UI, VFX and audio only listen.

signal gloom_changed(value: float, max_value: float)
signal wounds_changed(value: float, max_value: float)   ## r35: the Wounds bar (Player.wounds); blows fill it, fire mends it
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
signal player_hurt(amount: float, from_pos: Vector3)   ## from_pos = Vector3.INF when unknown
signal skill_failed(id: StringName, reason: String)      ## F8 sampler result, pinned in the F3 overlay
signal seal_progress(id: String, cleared: int, total: int)
signal seal_broken(id: String)
signal boss_engaged(boss: Node, title: String)
signal boss_slain(id: String)
signal item_gained(id: String, amount: int, total: int)
signal gloom_tide(active: bool)                         ## encounters: the Gloom tide rises (true) / breaks or recedes (false)
signal quest_changed(id: String, step: int, done: bool)       ## story: a task started, moved on or was done (core/story/quest_book.gd)
# r33 world: zone discovery, the Ember Road (fire travel) and world events (core/world/...).
signal region_discovered(id: String, kind: String)            ## first entry ever: kind "region" (RealmLayout id) or "subzone" (id "sub_<spot>"); reward/XP hook
signal fire_travelled(from_fire: String, to_fire: String)      ## the Ember Road carried the wanderer between two lit fires (brazier node names)
signal world_event(id: String, phase: String, at: Vector3)     ## a world event (core/world/world_events.gd): phase "warn", "start", "wave", "won", "lost", "faded"; reward hook on "won"
# r33 enemies: cast bars (core/enemy/enemy.gd header documents the cast API)
signal enemy_cast_started(enemy: Node, cast: String, time: float, interruptible: bool)
signal enemy_cast_ended(enemy: Node, cast: String, interrupted: bool)
# r33 combat: the combat HUD feed (docs: the HUD contract at the top of core/skills/combat_state.gd)
signal combat_damage(target: Node, amount: float, crit: bool, school: StringName, at: Vector3)
signal status_changed(target: Node, id: StringName, stacks: int, time_left: float)   ## stacks 0 = gone
signal proc_triggered(id: StringName, reason: StringName)
signal cast_started(id: StringName, total: float)
signal cast_stopped(id: StringName, reason: StringName)    ## &"done" | &"moved" | &"interrupted" | &"cancel"
signal spell_queued(id: StringName)
signal target_changed(target: Node)                        ## null = cleared

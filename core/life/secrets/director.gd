extends Node
## Runtime side of the secrets (no class_name; built by secrets.gd under the Secrets host):
## - discovery: the first time the wanderer comes within a secret's radius it is "found" (banner,
##   a low hum, counted n / total);
## - elite guardians: each spec (State.elites) rises when its condition holds and the wanderer is
##   near, and stays down once killed (persisted);
## - live reactions: a boss falling plays its world change (Reactivity) and wakes sites that wait on
##   it; a seal breaking leaves its mark.

const State := preload("res://core/life/secrets/state.gd")
const Kit := preload("res://core/life/secrets/kit.gd")
const Pages := preload("res://core/life/secrets/pages.gd")
const Reactivity := preload("res://core/life/secrets/reactivity.gd")
const ELITE_WAKE := 26.0

var _t := 0.0
var _seal_t := 0.0
var _live := {}            ## elite id -> enemy node
var _heard := {}           ## secret id -> true: its far-off hum already sounded this session
const HEAR := 13.0         ## a low hum the first time you come within this of a secret's edge


## Leaving the tree (a new night, quitting): let go of everything the secrets keep in static
## script vars, so nothing that holds a server RID is freed after the servers shut down.
func _exit_tree() -> void:
	Kit.release()
	(load("res://core/life/secrets/beam.gd") as GDScript).call("release")
	(load("res://core/life/secrets/site_glade.gd") as GDScript).call("release")
	(load("res://core/life/secrets/site_r34.gd") as GDScript).call("release")     # r34 places
	Reactivity.release()
	State.release()


func _ready() -> void:
	Events.boss_slain.connect(_on_boss)
	Events.enemy_killed.connect(_on_kill)
	Events.seal_broken.connect(func(_id: String) -> void: _seal_t = 1.0)


func _process(delta: float) -> void:
	_t -= delta
	_seal_t -= delta
	if _seal_t <= 0.0:
		_seal_t = 2.5
		Reactivity.seal_marks(get_parent().get_parent(), get_parent(), true)
	if _t > 0.0:
		return
	_t = 0.25
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	var at := p.global_position
	for s in State.sites:
		if State.has("found", s.id):
			continue
		var c: Vector3 = s.at
		var dxz := Vector2(at.x - c.x, at.z - c.z).length()
		if not _heard.has(s.id) and dxz < float(s.get("r", 6.0)) + HEAR and absf(at.y - c.y) < 12.0:
			_heard[s.id] = true          # guidance without a marker: something hums nearby, once
			Kit.play("hum", c + Vector3.UP, -13.0, 0.62)
		if dxz < float(s.get("r", 6.0)) and absf(at.y - c.y) < 8.0:
			State.mark("found", s.id)
			Kit.play("hum", c, -6.0)
			State.banner("secret found  ·  %d of %d" % [State.found_count(), State.sites.size()], String(s.name))
	for e in State.elites:
		var id: String = e.id
		if State.has("elites", id) or _live.has(id):
			continue
		var w: Callable = e.when
		if w.is_valid() and not bool(w.call()):
			continue
		var ea: Vector3 = e.at
		if at.distance_to(ea) > ELITE_WAKE:
			continue
		var host := get_parent().get_parent()
		var en := Kit.spawn_elite(host, String(e.kind), ea, String(e.title))
		en.set_meta("secret_elite", id)
		_live[id] = en
		Kit.fx_dust(ea, Color(0.3, 0.3, 0.32, 0.8), 40)
		State.toast("%s rises." % e.title)
	for id: String in _live.keys():
		if not is_instance_valid(_live[id]):
			_live.erase(id)          # despawned (left behind): it rises again next time


func _on_kill(enemy: Node) -> void:
	if enemy == null or not enemy.has_meta("secret_elite"):
		return
	var id := String(enemy.get_meta("secret_elite"))
	if State.mark("elites", id):
		var at := (enemy as Node3D).global_position
		var rw: Dictionary = Pages.REWARDS.elite
		for item: String in rw:
			Travel.give(item, int(rw[item]), true)
		State.toast("%s is put down. It leaves a fistful of grave ash." % String(enemy.get_meta("elite", "The guardian")))
		Kit.play("chime", at, -3.0)
	_live.erase(id)


func _on_boss(id: String) -> void:
	var root := get_parent().get_parent()
	# the boss arena's own beat first; the world answers a moment later
	await get_tree().create_timer(3.0, false).timeout
	if not is_inside_tree():
		return
	Reactivity.apply(root, get_parent(), id, true)
	State.mark("react", id)
	State.refresh(true)

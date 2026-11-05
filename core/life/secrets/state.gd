extends RefCounted
## The secrets' runtime registry and persistent state (no class_name). Everything the player did is
## kept in Travel.system_state("secrets"):
##   solved  {puzzle: true}   bells, cist, rite
##   open    {id: true}       barrow, crypt, oak, bridge, postern (doors, bridges, gates)
##   looted  {cache: true}    rewards taken (each once)
##   pages   {page: true}     writings read
##   found   {secret: true}   secret places entered
##   elites  {id: true}       elite guardians put down
##   react   {boss: true}     world changes already played (the next load applies them silently)
##   marks   {seal: true}     seal-break marks laid
## Sites register a dictionary (see register()) so the director and zz/secrets_test can find them.

const Kit := preload("res://core/life/secrets/kit.gd")
const Pages := preload("res://core/life/secrets/pages.gd")
const GROUPS := ["solved", "open", "looted", "pages", "found", "elites", "react", "marks"]

static var sites: Array[Dictionary] = []
static var elites: Array[Dictionary] = []
static var host: Node3D
static var quiet := false          ## tests: no toasts / banners / saves


## Forget the registry (nodes, callables) when the secrets leave the tree. The save state stays.
static func release() -> void:
	sites.clear()
	elites.clear()
	host = null


static func st() -> Dictionary:
	var s := Travel.system_state("secrets")
	for g: String in GROUPS:
		if not (s.get(g) is Dictionary):
			s[g] = {}
	s["v"] = 1
	return s


static func has(group: String, id: String) -> bool:
	return (st()[group] as Dictionary).has(id)


static func mark(group: String, id: String, save := true) -> bool:
	var d: Dictionary = st()[group]
	if d.has(id):
		return false
	d[id] = true
	if save and not quiet:
		Travel.save_game()
	return true


static func toast(text: String) -> void:
	if not quiet:
		Events.toast.emit(text)


static func panel() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("secrets_panel") if tree else null


static func banner(top: String, name_text: String) -> void:
	var p := panel()
	if p and not quiet:
		p.call("banner", top, name_text)


## A site: {id, name, at: Vector3 (its heart), r: discovery radius, route: {from: Vector3, pts:
## Array[Vector3]} (a walk from the walked network, for the reachability test), goal: Vector3 (where
## the walk ends), sync: Callable(animate: bool) (re-read the state), node}.
static func register(d: Dictionary) -> void:
	for i in sites.size():
		if sites[i].id == d.id:
			sites[i] = d
			return
	sites.append(d)


static func site(id: String) -> Dictionary:
	for s in sites:
		if s.id == id:
			return s
	return {}


static func refresh(animate: bool) -> void:
	for s in sites:
		var f: Variant = s.get("sync")
		if f is Callable and (f as Callable).is_valid():
			(f as Callable).call(animate)


## Elite guardian spec: {id, kind, at, title, when: Callable() -> bool (may it rise now)}.
static func elite(d: Dictionary) -> void:
	elites.append(d)


## A readable writing of the secrets (Pages.TEXTS). Reading opens the panel and remembers it; until
## read a pale glint marks it (cold blue: these are not the Realm's ember-lit inscriptions).
static func reading(parent: Node, page: String, at: Vector3, verb := "Read") -> Node3D:
	var e := Pages.entry(page)
	var t := Kit.touch(parent, at, "", Callable(), 2.0)
	t.name = "Page_" + page
	var g: Node3D = null
	if not has("pages", page):
		g = Kit.glint(t, at + Vector3.UP * 0.35, Color(0.55, 0.8, 1.0), 0.3)
	t.set("prompt_fn", func() -> String:
		return "%s the %s%s" % [verb, String(e.get("kind", "inscription")), "" if not has("pages", page) else " again"])
	t.set("action", func(_by: Node) -> void:
		var fresh := mark("pages", page)
		if is_instance_valid(g):
			g.queue_free()
		var p := panel()
		if p:
			p.call("show_page", page, t, fresh)
		elif not quiet:
			Events.toast.emit("%s: %s" % [e.get("title", ""), e.get("text", "")]))
	return t


## A cache: gives Pages.REWARDS[id] once (persisted), then calls `opened` (visual change).
## `ready_fn` (optional) says whether it can be opened yet (a closed door, an unsolved puzzle).
static func cache(parent: Node, id: String, at: Vector3, what: String, opened: Callable, ready_fn := Callable()) -> Node3D:
	var t := Kit.touch(parent, at, "", Callable(), 2.0)
	t.name = "Cache_" + id
	t.set("prompt_fn", func() -> String:
		if has("looted", id):
			return ""
		if ready_fn.is_valid() and not bool(ready_fn.call()):
			return ""
		return "Open " + what)
	t.set("action", func(_by: Node) -> void:
		if ready_fn.is_valid() and not bool(ready_fn.call()):
			return                       # not open yet (no prompt shows either)
		take(id, at)
		if opened.is_valid():
			opened.call(true))
	return t


## Hand out a cache's reward (once). Returns true the first time.
static func take(id: String, at: Vector3) -> bool:
	if has("looted", id):
		return false
	var rw: Dictionary = Pages.REWARDS.get(id, {})
	var parts := PackedStringArray()
	for item: String in rw:
		Travel.give(item, int(rw[item]), false)
		parts.append("%s x%d" % [Pages.item_name(item), int(rw[item])])
	mark("looted", id)
	if not quiet:
		Kit.play("chime", at, -4.0)
		Kit.fx_sparks(at + Vector3.UP * 0.4, Color(1.2, 0.9, 0.5))
		toast("Found: " + ", ".join(parts))
	return true


static func found_count() -> int:
	var n := 0
	for s in sites:
		if has("found", s.id):
			n += 1
	return n

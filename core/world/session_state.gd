extends RefCounted
## The one list of process-lifetime `static var`s that hold *night* state, and the one place that
## resets them when a night is torn down (world/main.gd `_exit_tree`: quit, or the Deeper Night
## rebuilding the night in the same process). Load by path (no class_name):
##   const SessionState := preload("res://core/world/session_state.gd")
##
## Why: statics outlive the scene. A static that keeps a Node or a Callable dangles after the night
## is freed; a static registry that keeps the last build's entries makes the next build skip them
## (the Deeper Night lost a third of the Realm that way, see Realm.reset_registries). Every reset
## below is a typed call or a typed field write, so a rename fails at parse time instead of
## silently bringing the leak back.
##
## Rules (enforced by tools/run_tests.sh's static lint):
##   - No new `static var` typed Node / Node3D / Callable. The few that exist are listed in
##     NODE_REFS and are cleared here; prefer an instance node owned by the Zone.
##   - A new static that holds per-night state gets a line in `reset_night()` (or a `release()` in
##     its own file called from here). Pure caches of immutable Resources may stay static.
##
## Kept across a rebuild ON PURPOSE (not reset here; changing that changes gameplay):
##   UpgradeDB.live (core/life/progression/upgrade_db.gd)  recomputed by the Kindling runtime
##   Combo.feed / count / chain (core/skills/combo.gd)      the build sheet reads the run's totals
##   VillageShop._sold / _night (core/life/village/village_shop.gd)  restocks on its own per village night
##   CodexStore.* (core/world/realm/lore/codex_store.gd)   the Journal; persistence owns it
##   EnemySpawner._seal_camps / _seal_kills                seal bookkeeping, rewritten per seeding
##   ThornHenge.C / FOOT / STAIR_R / realm / stair_pts     set by use_realm() / build() every build
## Test-only hooks (tests set and clear them themselves; never touched by a night teardown):
##   VillageState.sandbox / kindled_override, SecretsState.quiet

const HudPrefs := preload("res://ui/hud_prefs.gd")
const SecretsState := preload("res://core/life/secrets/state.gd")
const Reactivity := preload("res://core/life/secrets/reactivity.gd")

## "file: var" for every static that holds a Node or a Callable. tools/run_tests.sh fails when a
## Node- or Callable-typed static appears that is not in this list.
const NODE_REFS := [
	"core/life/secrets/state.gd: host",
	"core/life/secrets/reactivity.gd: _host",
	"core/skills/afflict.gd: _inst",
	"core/enemy/enemy_spawner.gd: kind_hook",
	"core/enemy/enemy_spawner.gd: dress_hook",
]


## Drop everything the night that is leaving registered. Idempotent; children have already run
## their own `_exit_tree` by the time the night root calls this.
static func reset_night() -> void:
	# the Realm's site / lane / portal registries and its build profile (only a Realm build fills them)
	if Realm.enabled():
		Realm.reset_registries()
	# engine resources the world builders cache in statics (meshes, materials, shapes)
	Realm.release_caches()
	# Node refs: the secrets director releases these itself; again here so no night can leak them
	SecretsState.release()
	Reactivity.release()
	# the Encounters director installs these spawner hooks on _ready and only clears hold_for_rest
	# on exit; Callables bound to the freed director must not reach the next night's spawner
	# (a fresh boot has them unset, so this makes a rebuild match a fresh boot)
	EnemySpawner.kind_hook = Callable()
	EnemySpawner.dress_hook = Callable()
	EnemySpawner.hold_for_rest = false
	HudPrefs.forget()                # the HUD toggles live in the slot's file: read them again


## Names of NODE_REFS statics that still hold something live (for tests: empty after reset_night).
static func dangling() -> Array[String]:
	var out: Array[String] = []
	if SecretsState.host != null:
		out.append("secrets/state.gd: host")
	if Reactivity._host != null:
		out.append("secrets/reactivity.gd: _host")
	if EnemySpawner.kind_hook.is_valid():
		out.append("enemy_spawner.gd: kind_hook")
	if EnemySpawner.dress_hook.is_valid():
		out.append("enemy_spawner.gd: dress_hook")
	return out

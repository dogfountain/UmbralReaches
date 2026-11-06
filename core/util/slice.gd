class_name Slice
extends RefCounted
## The full night is the default (Luke, 2026-11-06). `-- --slice` on the command line, or the
## "full_night" Engine meta set to false (a test that wants the trimmed night), gives the 30-minute
## slice instead: horses, the Kindled Watch, roaming events, faction tiers, daily bounties, raid
## attunement and gear raise/reforge/salvage are hidden, not deleted. Item level, gear sets and
## rested XP are never gated by this.


static func full() -> bool:
	if Engine.has_meta(&"full_night"):
		return bool(Engine.get_meta(&"full_night"))
	return not ("--slice" in OS.get_cmdline_user_args())

class_name Slice
extends RefCounted
## The 30-minute slice: the newest r36 systems (horses, roaming events, daily bounties, raid
## attunement, gear upgrading) are hidden, not deleted. `-- --full` on the command line, the
## "full_night" Engine meta (tests set it before the world loads) or a "full_night" save flag
## restores everything. Item level, gear sets and rested XP are never gated by this.


static func full() -> bool:
	if Engine.has_meta(&"full_night") and bool(Engine.get_meta(&"full_night")):
		return true
	return "--full" in OS.get_cmdline_user_args()

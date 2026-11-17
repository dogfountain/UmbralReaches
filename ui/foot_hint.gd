extends RefCounted
## The footer of a menu, written for the device in hand. Every panel's foot line used to name keyboard keys only; a pad player
## read "[Esc] leave" on a screen that closes with B. `pick(keys, pad)` returns the pad's wording while a pad is the last device
## used (Settings.using_pad) and the keyboard's otherwise; `leave()` and `page()` are the two phrases nearly every panel ends with,
## built from the live bindings. Static; load by path (no class_name). Nothing here runs per frame: a panel calls it when it fills.

const TextDirector := preload("res://ui/text_director.gd")


static func pick(keys: String, pad: String) -> String:
	return pad if Settings.using_pad else keys


## "[Esc] leave" or "[B] leave" (the keyboard names the panel's own key too when given).
static func leave(own_action := "", own_key := "") -> String:
	if Settings.using_pad:
		return "[B] leave"
	if own_action != "":
		return "[%s] or [Esc] leave" % InputSetup.live_label(own_action, false, own_key)
	return "[Esc] leave"


## "[Q] [E] page" or "[LB] [RB] page".
static func page() -> String:
	return "[LB] [RB] page" if Settings.using_pad else "[Q] [E] page"


## A footer's size: never under 16 px, and it follows Settings > Text Scale (the objective, toasts and lessons already do). Call it when
## the panel fills, so a change in Settings reaches an open panel the next time it is shown.
static func style(l: Label, base := 16) -> void:
	l.add_theme_font_size_override("font_size", maxi(16, TextDirector.px(base)))

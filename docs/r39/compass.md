# The compass: show what matters now

Luke: "it displays too much info ... it shows too many fires." The old strip (`ui/compass.gd`) drew every landmark
beacon, the four nearest fires within 110 m (lit or cold, always) and the followed step, so most of the time it was a row of
gold diamonds. It now draws only what a glance needs. The filter is `ui/compass_feed.gd` (pure, static, called twice a second);
`ui/compass.gd` only draws. Density is a setting: Settings > Display > Heads-up display > Compass Detail (Minimal / Standard /
Full, saved in hud.cfg as `compass_density`, `ui/hud_prefs.gd`; default Standard).

## What shows, by kind (strongest first; a weaker mark on a stronger one gives way)

| Kind | Minimal | Standard | Full |
| --- | --- | --- | --- |
| Goal (the followed step) | always, any range, with its distance | same | same |
| Danger: a great one's arena not yet fallen, a rare foe awake (red wedge) | 70 m | 140 m (2) | 200 m (3) |
| Fire: nearest, only when one is wanted (Gloom over a third of the bar, or wounds under half): the nearest lit one is a cleanse, the nearest cold one a place to kindle | none | 170 m (1) | 220 m (2) |
| Fire when nothing is wanted | none | none | the nearest, within 60 m |
| Quest giver / turn-in (small diamond, hollow = giver, filled = turn-in) | none | 90 m (2) | 160 m (3) |
| Far beacons (the Wardens' lit towers, the Sleeper, boss lights...) | only if there is no goal, within 110 m, one tick | the 3 nearest as faint ticks to 300 m | up to 5 with a small diamond and a distance to 380 m |

- **Fade by distance**: full strength inside 60 % of a mark's range, nothing at the range; the goal never fades.
- **Merge**: marks within 17 px of a stronger one of the same kind fold into it with a count (x3); a weaker kind under a stronger
  one is dropped, so a crowd of fires or beacons is one icon.
- **One distance tab** under the strip: the goal's if there is one, else the mark nearest the centre of the strip that is an
  icon (not a tick).
- Quiet-HUD mode (`hud_rest.gd`) still dims the whole strip to a third while the night is calm.
- Marks fall out of the strip's 180 degrees: those behind pin to the nearest edge (goal only; others vanish at the edges).

## Check in the engine
- Walk Hearthward to the road with Gloom at 0: the strip shows the objective only (Standard adds faint beacon ticks, no fires).
- Let Gloom pass a third: the nearest fire appears, larger, with its distance. Kindle it, Gloom falls, the mark relaxes.
- Near an unslain boss arena (henge at (-86, -24), the Hierarch's ring (-206, 148), the Anchoress at (214, -132)): a red wedge.
- Switch to Minimal and Full in the menu and see the strip change at once (the compass rereads every half second).

# Unreal iterate checklist

Copy and tick each cycle:

```
Cycle goal: ________________________________

[ ] Hypothesis written (one primary)
[ ] Code / Raw / Material change applied
[ ] UAT BuildCookRun (-build -cook -stage -pak) SUCCESS
[ ] ditto StagedBuilds → Downloads …/UmbralReaches.app
[ ] Raw texture copies updated inside .app if PNG edited
[ ] codesign --force --deep --sign -
[ ] touch .app ; note Finder time ______
[ ] Relaunch -windowed 1600x900
[ ] DIAG SHOT spawn/stair/lava (or vale) fresh mtimes
[ ] Read PNGs (not only mean RGB — look for silhouette / static / washout)
[ ] Log skim: DIAG PLAYER, missing packages, ShaderMap
[ ] Next hypothesis or stop (parity improved: Y/N)
```

Mean RGB alone lies (grey fog can look “bright”). Prefer: robe readable, lantern pool on ground, stair steps lit, no checkerboard, no WPO static.

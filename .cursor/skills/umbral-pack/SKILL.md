---
name: umbral-pack
description: Pack script, shader, and player changes into the playable Mac app without rebaking scenes. Use when the user says deploy, pack, ship, play, relaunch, or after visual/gameplay edits they will test in Umbral Reaches.app.
---

# Pack the Mac app

The owner plays `/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app`. That bundle loads a **Linux** `.pck`, not a macOS export. After visual or gameplay changes, pack — do not ask them to run from the editor.

## Do not

- Headless-rebake `world/main.tscn` or `world/vale.tscn` (wipes MultiMesh AABBs).
- Export preset `macOS` or rewrite the Mach-O. Godot already signed the binary; later `lipo`/strip/rezip breaks Gatekeeper.
- `pkill` the owner's Godot editor.
- Rebake just to ship a script, shader, or player change.

## Pack

```sh
godot --headless --path /Users/luke/UmbralReaches --import --quit
godot --headless --path /Users/luke/UmbralReaches --export-pack "Linux" "/tmp/Umbral Reaches.pck"
cp "/tmp/Umbral Reaches.pck" "/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app/Contents/Resources/Umbral Reaches.pck"
codesign --force --deep --sign - "/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app"
touch "/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app"
date "+%H:%M:%S"
```

Godot is `/opt/homebrew/bin/godot` or `/Applications/Godot.app/Contents/MacOS/Godot`. Bundle id: `com.umbralreaches.prototype`.

## After pack

Tell them to **quit and relaunch**. Quote the Finder timestamp from `date`. Finder can keep an old icon for a bit — say so.

`godot --check-only` hangs. Do not use it to validate the pack.

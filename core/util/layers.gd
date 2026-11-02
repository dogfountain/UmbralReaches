class_name Layers
extends RefCounted
## 3D physics layers, matching [layer_names] in project.godot. Bit 0 is layer 1.

const WORLD := 1
const PLAYER := 2
const HURTBOX := 4
const INTERACT := 8
## Solid props (stones, bridge rails). The player collides with them; the camera spring arm
## (mask WORLD only) ignores them, so orbiting never snaps the view in against a rock.
const PROPS := 16

extends RefCounted
## Makes pausing the night cheap. `get_tree().paused = true` sends a PAUSED notification to every
## node that stops, over the whole tree: about 12 ms over 28 000 nodes, the hitch on the first frame
## of the settings, map and loot windows. A branch that is only scenery (meshes, colliders, lights,
## fog: no script, no sound, no particles, no timers) has nothing to stop, so `mark(root)` sets it to
## PROCESS_MODE_ALWAYS and the pause skips the notification for all of it. Run once, under the
## loading screen. A marked branch must never be given a moving, scripted or sounding child later,
## which would inherit ALWAYS and keep running behind a menu; spawners parent to the zone instead.

const SCENERY := {&"Node3D": true, &"MeshInstance3D": true, &"MultiMeshInstance3D": true, &"StaticBody3D": true,
	&"CollisionShape3D": true, &"CollisionPolygon3D": true, &"OccluderInstance3D": true, &"OmniLight3D": true,
	&"SpotLight3D": true, &"FogVolume": true, &"Marker3D": true, &"Area3D": true, &"Label3D": true, &"Sprite3D": true}
const BULK := 12                        ## a bare Node3D branch this big is built scenery, not an empty container


## Mark every scenery-only branch under `root`; returns how many nodes now sit under a marked branch.
static func mark(root: Node) -> int:
	if root == null:
		return 0
	var t0 := Time.get_ticks_usec()
	var covered := 0
	for c in root.get_children():
		covered += _mark(c)
	print("PAUSE_SCOPE %d nodes under scenery branches, %.1f ms" % [covered, float(Time.get_ticks_usec() - t0) / 1000.0])
	return covered


static func _mark(n: Node) -> int:
	if n.process_mode != Node.PROCESS_MODE_INHERIT:
		return 0                          # someone chose this node's mode already
	var size := _scenery_size(n)
	# a small bare Node3D is as likely a container that fills later as scenery: only its children are marked
	if size > 0 and (size >= BULK or n.get_class() != &"Node3D"):
		n.process_mode = Node.PROCESS_MODE_ALWAYS
		return size
	var covered := 0
	for c in n.get_children():
		covered += _mark(c)
	return covered


## The node count of the branch if all of it is scenery, else 0.
static func _scenery_size(n: Node) -> int:
	if n.get_script() != null or not SCENERY.has(StringName(n.get_class())) or n.process_mode != Node.PROCESS_MODE_INHERIT:
		return 0
	var size := 1
	for c in n.get_children():
		var s := _scenery_size(c)
		if s == 0:
			return 0
		size += s
	return size

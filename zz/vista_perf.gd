extends "res://zz/perf_tour.gd"
## perf_tour with views over the vistas pass's ground (the scarp, the Long Arches' valley, the Reedmere, the far
## ranges and the veils). Paired A/B: default against `-- --no-vistas --no-vista-sky` (vistas/vista_places.gd).
##   godot --path . res://zz/vista_perf.tscn -- --points-only --only=rv_ [--stress=2] [--no-vistas --no-vista-sky]


func _init() -> void:
	realm_points.append_array([
		["rv_arches_below", Vector3(22.0, NAN, 318.0), 0.0],        # north up the scarp to the Arches Beacon, the vortex behind
		["rv_scarp_lip", Vector3(30.0, NAN, 242.0), PI],             # south over the Long Arches' valley, the mist, the teeth
		["rv_downs_south", Vector3(-20.0, NAN, 215.0), PI],          # the downs to the scarp and the far south
		["rv_reedmere", Vector3(-250.0, NAN, 300.0), PI * 0.5],      # west over the meres to the gorge
		["rv_east_road", Vector3(250.0, NAN, 66.0), -PI * 0.5],      # the road into the East Reach
		["rv_fallow", Vector3(-150.0, NAN, 300.0), 0.0],             # Fallowmere up to the Fallow Beacon
	])

extends "res://Scripts/TileMain.gd"

var movement_bounds = Vector2(0,0)

func check_force(obj):
	# get difference in height
	var height_diff = (obj.TILEMAP_POS.z - TILEMAP_POS.z)
	
	# if this difference is lower than our bound
	# it means we still have a force that pushes us upwards!
	# (Why the "+1"? Because butterflies are always a block _underneath_ a player, so height difference is always at least 1)
	if height_diff < movement_bounds.y + 1:
		# so push the object upwards
		# (upward vector, being dragged)
		obj.move(Vector3(-1,-1,1), true, true)
		
		# also tell the object which butterfly it's affected by
		obj.butterflies = self

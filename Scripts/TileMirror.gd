extends "res://Scripts/TileMain.gd"

export (Vector2) var mirror_normal = Vector2(1,1)
export (bool) var closed = false

var vertical = false
var vertical_value = 0

var vertical_vecs = [Vector2(1,0), Vector2(0,1), Vector2(-1,0), Vector2(0,-1)]

func register_state():
	return {
		"obj": self,
		"mirror_normal": mirror_normal 
	}

func convert_dir_to_frame(vec):
	match vec:
		Vector2(1,0):
			return 0
		
		Vector2(0,1):
			return 1
		
		Vector2(-1,0):
			return 2
		
		Vector2(0,-1):
			return 3

func convert_dir_to_vec(forward_dir):
	match forward_dir:
		0:
			return Vector2(1,0)
		
		1: 
			return Vector2(0,1)
		
		2:
			return Vector2(-1,0)
		
		3:
			return Vector2(0,-1)

func hide_reflection():
	return
	
	$Player.hide()

func show_reflection(my_pos, player_pos, player_obj):
	var player_forward_vec = convert_dir_to_vec(player_obj.FORWARD_DIR)
	
	if my_pos.x != player_pos.x:
		player_forward_vec.x *= -1
	
	if my_pos.y != player_pos.y:
		player_forward_vec.y *= -1
	
	# TO DO: TUrned off temporarily, because I had more important stuff to work out
	return
	
	# show player in the mirror
	$Player.show()
	$Player.frame = convert_dir_to_frame(player_forward_vec)
	$Player.modulate = player_obj.modulate
	$Player.modulate.a = 0.5
	
	#$Player.frame = convert_dir_to_frame(vec)

func get_reflection_vector(vec):
	if vertical:
		# if it's a straight vector ... 
		if vec.z == 0:
			# if it comes from the right direction (reverse of mirror normal), make it completely vertical
			if vec.x == -mirror_normal.x and vec.y == -mirror_normal.y:
				return Vector3(-1*vertical_value, -1*vertical_value, vertical_value)
			
			# otherwise, don't allow a reflection (it hits the mirror at the closed side)
			else:
				return Vector3(0,0,0)
		
		# if it's a vertical vector, return it back to our current orientation
		else:
			return Vector3(mirror_normal.x, mirror_normal.y, 0)
	
	# if it's a horizontal vector, calculate a proper reflection
	else:
		# normalize both vectors
		# (and turn 3d into 2d; ignore Z-axis for now)
		var temp_normal = mirror_normal.normalized()
		var temp_vec = Vector2(vec.x, vec.y).normalized()
		
		if closed:
			# check if mirror normal points the same way
			# if not, this reflection is not allowed
			# NOTE: Someone said we should negate the normal, but I haven't found any need to do that?
			if temp_normal.dot(temp_vec) > 0:
				return Vector3(0,0,0)
		
		var reflec_vec = temp_vec - 2.0 * temp_normal.dot(temp_vec) * temp_normal
		
		return Vector3(reflec_vec.x, reflec_vec.y, 0)

func activate(dir = 1):
	if vertical:
		var ind = vertical_vecs.find(mirror_normal)
		
		# if dir = 1, increment it (and modulo)
		if dir == 1:
			if ind == 3:
				frame -= 3
				ind = 0
			else:
				frame += 1
				ind += 1
		
		# if dir = -1, decrement it (and modulo)
		elif dir == -1:
			if ind == 0:
				frame += 3
				ind = 3
			else:
				frame -= 1
				ind -= 1
		
		# finally, update actual mirror normal
		mirror_normal = vertical_vecs[ind]
	
	else:
		if mirror_normal == Vector2(1,1):
			frame += 1
			mirror_normal = Vector2(1,-1)
		else:
			frame -= 1
			mirror_normal = Vector2(1,1)
	
	root_node.update_sight_lines()

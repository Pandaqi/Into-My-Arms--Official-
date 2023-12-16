extends Sprite

var TILEMAP_POS = Vector3.ZERO
var CELL_TYPE = 0
var ind

var min_bounds = Vector3(0.5, 0.5, 0.5)
var max_bounds = Vector3(0.5, 0.5, 0.5)

var x_bounds
var y_bounds
var z_bounds

var sprites_behind = []
var sorting_visited = false

var light_value = 1.0
var base_modulate = Color(1.0, 1.0, 1.0)
var num_highlights = 0

var GRID = null

var root_node = null

# timers for any movement (moving, platforms, rotating, etc.)
# TO DO: Now, fall_tween_duration MUST BE EQUAL to move_tween_duration
#  => To seperate these, we should make a distinction in the move() function
#  => If the movement is vertical, use fall_tween, otherwise, use move_tween
var fall_tween_duration = 0.2
var move_tween_duration = 0.2
var rotation_speed = 0.2
var wanted_rotation_frame = 0

var tile_offset = Vector2(0, 32)

func update_bounds():
	var height = TILEMAP_POS.z
	
	# if it's a height movement ...
	# (which means we get a non-integer height along the way)
	var pos_3d = Vector3(TILEMAP_POS.x + height, TILEMAP_POS.y + height, height)
	if round(height) != height:
		# round the X and Y values to stay in their lane
		pos_3d.x = round(TILEMAP_POS.x + height)
		pos_3d.y = round(TILEMAP_POS.y + height)
	
		# TO DO: This is wrong, but rounding thisnumber DOES solve the falling-down-depth-flickering issue
		var round_precision = 5
		pos_3d.z = round(height*round_precision)/round_precision
	
	# finally, set the (psuedo) 3D dimensions of this object
	x_bounds = Vector2(pos_3d.x - min_bounds.x, pos_3d.x + max_bounds.x)
	y_bounds = Vector2(pos_3d.y - min_bounds.y, pos_3d.y + max_bounds.y)
	z_bounds = Vector2(pos_3d.z - min_bounds.z, pos_3d.z + max_bounds.z)
	
	if has_node("PosLabel"):
		$PosLabel.set_text(str(round(z_bounds.x*10)/10) + "," + str(round(z_bounds.y*10)/10))

func _ready():
	# when tile enters the tree, set the bounds once
	# (inheriting scripts might also call the function during the game, if needed)
	update_bounds()
	
	root_node = get_node("/root/Node2D")
	
	# cache main grid
	GRID = root_node.GRID

	# Set array to the maximum number of tiles that COULD be behind this tile
	sprites_behind.resize(root_node.total_tiles_in_level)
	
	
	

func v3_to_index(v3):
	return str(int(round(v3.x))) + "," + str(int(round(v3.y))) + "," + str(int(round(v3.z)))

func update_position_in_grid(new_position, old_position = null):
	# remove ourselves from the OLD position
	if not old_position == null:
		var trans_pos = v3_to_index(old_position)
		
		# if it is US in this position, remove us
		# (when undoing, it could be that something else takes this spot already)
		if GRID[trans_pos] == self:
			GRID.erase(trans_pos)
	
	# save our player number in the GRID
	# (negative values are for obstacles, positive values for tilemap tiles)
	GRID[v3_to_index(new_position)] = self

# this function can set ANY position directly,
# based on the TILEMAP_POS you input
func set_position_directly(pos):
	# update position in general grid
	# (old position, new position)
	update_position_in_grid(pos, TILEMAP_POS)
	
	# set TILEMAP_POS variable
	TILEMAP_POS = pos
	
	# set actual, visible position
	# grab reference tilemap
	var tilemap = get_node("/root/Node2D/EmptyTilemap")
	
	# actually set the position
	set_position( tilemap.map_to_world(Vector2(TILEMAP_POS.x, TILEMAP_POS.y)) + tile_offset )
	
	# call some functions to update new world state
	update_bounds()
	root_node.update_depth_sort = true
	root_node.check_blocking_objects()
	root_node.update_possible_moves()

func update_light_value():
	# if lights aren't enabled don't do anything
	if not root_node.lights_enabled:
		return
	
	# otherwise, get the list of lights (which is just their position, currently)
	var lights_list = root_node.lights_list
	
	# modulate according to light value
	var light_value = 0.0
	var max_light_distance = 2
	for light in lights_list:
		var pos_3d = Vector3(TILEMAP_POS.x + TILEMAP_POS.z, TILEMAP_POS.y + TILEMAP_POS.z, TILEMAP_POS.z)
		# MANHATTAN DISTANCE: var dist = abs(pos_3d.x - light.x) + abs(pos_3d.y - light.y) + abs(pos_3d.z - light.z)
		# EUCLIDIAN DISTANCE:
		var dist = (pos_3d - light).length()
		
		# also save the light value
		light_value += max(1.0 - dist*(1.0/max_light_distance), 0)
	
	# clamp the value
	light_value = clamp(light_value, 0.15, 1.0)
	
	# apply modulation
	modulate = Color(base_modulate.r * light_value, base_modulate.g * light_value, base_modulate.b * light_value, 1.0)

func _on_Tween_tween_completed(object, key):
	pass # Replace with function body.

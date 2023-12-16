extends "res://Scripts/TileMain.gd"

var is_moving = false
var move_dir = 1
onready var tween = $Tween

var movement_bounds = Vector2(0,0)
var movement_axis = 2
var movement_offset = 0 # used for calculating where we are in our movement (if we're still within bounds)
var should_activate = false
var player_above = null

func _ready():
	# always start at first bound
	# movement_offset = movement_bounds.x
	
	check_move_bounds()
	
	# elevators have half bounds on the Z-axis (up axis)
	min_bounds = Vector3(0.5, 0.5, 0)
	max_bounds = Vector3(0.5, 0.5, 0.5)
	
	# convert movement_axis to actual vector
	match movement_axis:
		0:
			movement_axis = Vector3(1, 0, 0)
		
		1:
			movement_axis = Vector3(0, -1, 0)
		
		2:
			movement_axis = Vector3(-1, -1, 1)
	
	# call parent ready
	._ready()

func register_state():
	return {
		"obj": self,
		"position": TILEMAP_POS,
		"custom_parameters": {
			"movement_offset": movement_offset,
			"move_dir": move_dir
		}
	}

func activate():
	# remember we're moving (this is reset once the position tween ends)
	is_moving = true
	
	# determine our moving direction
	var delta_pos = move_dir * movement_axis
	player_above = null
	
	# Check if there's something above us
	var above_ind = v3_to_index(TILEMAP_POS + Vector3(-1, -1, 1))
	if GRID.has(above_ind):
		var val = GRID[above_ind]
		
		if val.CELL_TYPE < 0 and not val.is_moving:
			player_above = val
	
	# Check if there's something in our path
	var next_ind = v3_to_index(TILEMAP_POS + delta_pos)
	if GRID.has(next_ind):
		# if we're checking the tile above us,
		# only return if we don't find a player
		if delta_pos.z == 1 and player_above != null:
			pass
		# otherwise, any tile will block us!
		else:
			return
	
	if player_above != null:
		player_above.move(delta_pos, true)
	
	movement_offset += move_dir
	
	# move the elevator
	var new_pos = TILEMAP_POS + delta_pos
	
	# this is a standard convertion to isometric
	# BUT with a Vector2(0, 32) added at the end, because our tiles have a weird center ...
	var screen_pos = Vector2( (new_pos.x - new_pos.y)*64, (new_pos.x + new_pos.y)*32) + tile_offset
	
	tween.interpolate_property(self, "position",
							   null, screen_pos,
							  fall_tween_duration, Tween.TRANS_LINEAR, Tween.TRANS_LINEAR)

	tween.interpolate_property(self, "TILEMAP_POS",
							   null, new_pos,
							   fall_tween_duration, Tween.TRANS_LINEAR, Tween.TRANS_LINEAR)
	
	tween.start()
	
	# update position in the global grid
	update_position_in_grid(new_pos, TILEMAP_POS)

func check_move_bounds():
	if move_dir == 1 and movement_offset >= movement_bounds[1]:
		move_dir = -1
		movement_offset = movement_bounds[1]
		return true
	
	elif move_dir == -1 and movement_offset <= movement_bounds[0]:
		move_dir = 1
		movement_offset = movement_bounds[0]
		return true
	return false

func _on_Tween_tween_completed(object, key):
	if key == ":TILEMAP_POS":
		# update blocking objects for players
		root_node.check_blocking_objects()
		
		# check if we're above/below our maximum bounds
		# if so, make sure our next move is in the other direction
		var changed_dir = check_move_bounds()
		
		if changed_dir:
			# if we are at the edge, stop moving and do one last sorting update
			is_moving = false
			
			update_bounds()
			root_node.update_depth_sort = true
			root_node.update_sight_lines()
		
		# if not, keep moving!
		# (but wait a frame, so the player can catch up => otherwise, the player falls through and imprecisions happen)
		else:
			should_activate = true
		
		# update possible moves, because elevator/platform
		# might have entered radius of player
		root_node.update_possible_moves()

func _process(delta):
	if should_activate:
		should_activate = false
		activate()
	
	if is_moving:
		if player_above != null:
			# never allow player_above to be below our own z_index
			if player_above.z_index < z_index:
				player_above.z_index = z_index+0.5
		
		update_bounds()
		get_node("/root/Node2D").update_depth_sort = true

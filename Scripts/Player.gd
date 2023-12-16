extends "res://Scripts/TileMain.gd"

### 
# INTERESTING LINKS
#
# Isometric height finding: https://stackoverflow.com/questions/21842814/mouse-position-to-isometric-tile-including-height
# Godot Ysort in tilemap: https://www.reddit.com/r/godot/comments/b1xtan/help_with_ysort_tilemap_kinematicbody2d/
#
# Godot demo (v2.1) for isometric lighting: https://github.com/godotengine/godot-demo-projects/tree/2.1/2d/isometric_light
# About PORTING that demo to v3.0: https://godotengine.org/qa/25920/2d-isometric-lighting
#
# Isometric drawing tools in Affinity Designer (v1.7): https://affinityspotlight.com/article/how-to-use-the-new-isometric-drawing-tools-in-affinity-designer-17/
#
# About intuitive axis-aligned movement in isometric games: https://ux.stackexchange.com/questions/80890/controlling-movement-direction-in-isometric-view



# Keep track of our current ROTATION ( = forward facing direction)
# Also keep track of our current POSITION
var FORWARD_DIR = 0
var cur_rotate_dir = 0
export (int) var STARTING_DIR = 0

export (int) var PLAYER_NUM = 0

# These variables are for checking the win-condition
# In order for something to be a "leap of faith", you need to:
#  => Step backward
#  => Fall for at least one block
var last_move_backward = false
var fall_counter = 0

# To make sure we don't move/rotate WHILE we're already doing that
var is_moving = false
var is_rotating = false

# Nodes we'll need often
onready var tween = get_node("Tween")
onready var view_drawer = get_node("/root/Node2D/PlayerView" + str(PLAYER_NUM))
var tilemap

var previous_blocking_objects = []

var blink_timer = null

# this variable saves the four "lines of sight" we generate (left/right/up/down)
var light_paths = [[],[],[],[]]

var button_cells = []
var elevator_cells = []
var mirror_cells = []

var other_player
var is_disabled = false
var wait_frames = 0

var highlighter_scenes = [null, null]
onready var tile_highlighter = preload("res://Effects/TileHighlighter.tscn")

onready var undo_manager = get_node("/root/Node2D/UndoManager")
var my_last_move = null

var butterflies = null
var butterfly_cells = []
var passthrough_cells = []

var fear_cells = [46, 62]
var is_stuck = false

var doubt_cells = []
var moved_by_input = false
var is_doubting = false
var cur_doubt_ind = -1

var ice_indicator = null
var warmth_threshold = 4
var CUR_STATUS = 'none'

func _ready():
	tilemap = get_parent()
	
	# initialize tilemap_pos
	var temp_pos = tilemap.world_to_map( get_position() )
	TILEMAP_POS.x = temp_pos.x
	TILEMAP_POS.y = temp_pos.y

	# and snap it to the position we found
	set_position( tilemap.map_to_world(Vector2(TILEMAP_POS.x, TILEMAP_POS.y)) + tile_offset )
	
	# grab height from our tilemap
	# tilemaps are named "LevelX" => we only want the X, parsed as an int
	TILEMAP_POS.z = int( tilemap.get_name().substr(5,1) )
	
	# color the sprite (player 1 and 2 have distinct colors)
	var player_colors = [Color(1.0, 83/255.0, 83/255.0), Color(193/255.0, 83/255.0, 1.0)]
	modulate = player_colors[PLAYER_NUM]
	
	base_modulate = player_colors[PLAYER_NUM]
	
	# start blink timer
	blink_timer = Timer.new()
	add_child(blink_timer)
	
	blink_timer.connect("timeout", self, "blink") 
	blink_timer.set_one_shot(false)
	blink_timer.set_wait_time(rand_range(3,8))
	blink_timer.start()
	
	# create two highlighter objects
	# (save reference, hide them for now)
	for i in range(2):
		# create new highligher instance
		var new_h = tile_highlighter.instance()
		
		# set color of highlighter to our player color
		new_h.modulate = base_modulate
		
		# add to root node (not player, because then it would be transformed )
		root_node.call_deferred("add_child", new_h)
		
		# save reference
		highlighter_scenes[i] = new_h
		
		# hide
		new_h.hide()
	
	###
	# initialize the last_move variable
	###
	my_last_move = TILEMAP_POS
	
	# call our parent ready function ("TileMain.gd")
	._ready()

func initialize(grid, other_player, button_cells, elevator_cells, mirror_cells, butterfly_cells, doubt_cells, passthrough_cells):
	# get root node
	# NOTE: It's important to do this BEFORE we remove ourselves,
	#       because "can't use get_node() with absolute paths from outside the active scene tree" (Godot error message)

	# remove ourselves from current tilemap
	get_parent().remove_child(self)
	root_node.add_child(self)
	
	# change tilemap to the reference one
	# (the others will soon be removed, after this function is called)
	tilemap = root_node.get_node("EmptyTilemap")
	
	# give ourselves the right metadata
	CELL_TYPE = -(PLAYER_NUM+1)
	
	# and keep a reference to the main grid for the game
	GRID = grid
	
	# I can set the forward direction from the editor
	# To make sure the player looks the right way at the START of a level
	# This code simply does that
	FORWARD_DIR = STARTING_DIR
	frame = FORWARD_DIR*2
	update_eyes()
	
	# save quick link to other player
	self.other_player = other_player

	# save a quick link to special cell types (takes more memory, but is better for performance)
	self.button_cells = button_cells
	self.elevator_cells = elevator_cells
	self.mirror_cells = mirror_cells
	self.butterfly_cells = butterfly_cells
	self.doubt_cells = doubt_cells
	self.passthrough_cells = passthrough_cells
	
	# save reference to ice indicator, if it exists
	if root_node.warmth_enabled:
		self.ice_indicator = get_node("/root/Node2D/GUI/IceIndicator")

	# save ourselves into the general GRID variable
	update_position_in_grid(TILEMAP_POS)
	
	# first distance calculation
	check_distance()
	
	# first move highlighter calculation
	root_node.update_possible_moves()
	
	# resize sprites behind array
	sprites_behind.resize(root_node.total_tiles_in_level)

func v3_to_index(v3):
	return str(int(round(v3.x))) + "," + str(int(round(v3.y))) + "," + str(int(round(v3.z)))

func blink():
	if not is_rotating:
		var cur_frame = $Eyes.frame % 3
		$AnimPlayerEyes.play("Blink " + str(cur_frame))
	
	# plan the next blink
	blink_timer.set_wait_time(rand_range(3,8))

func get_real_pos():
	return Vector3(TILEMAP_POS.x + TILEMAP_POS.z, TILEMAP_POS.y + TILEMAP_POS.z, TILEMAP_POS.z)

func activate_butterfly(val):
	val.check_force(self)
	show_status('butterflies')
	
	play_sound('butterflies-short')

func deactivate_butterfly():
	butterflies = null
	hide_status()

func stick():
	is_stuck = true
	show_status('fears')
	play_sound('fears', true)

func unstick():
	is_stuck = false
	hide_status()

func start_doubts(obj):
	is_doubting = true
	cur_doubt_ind = obj.ind
	
	show_status('doubts')

func stop_doubts():
	is_doubting = false
	cur_doubt_ind = -1
	
	hide_status()

func update_ice_indicator(dist):
	var inverse_dist = (warmth_threshold + 1) - dist
	for i in range(4):
		var node = ice_indicator.get_node("Sprite" + str(i+1))
		if i < inverse_dist:
			node.modulate.a = 1.0
		else:
			node.modulate.a = 0.25

func check_distance():
	###
	# CHECK DISTANCE TO OTHER PLAYER
	###
	# calculate distance (from real position) => MANHATTAN DISTANCE, not Euler
	var p1 = get_real_pos()
	var p2 = other_player.get_real_pos()
	var dist = abs(p1.x - p2.x) + abs(p1.y - p2.y) + abs(p1.z - p2.z)
	
	# update ice indicator, if it exists
	if ice_indicator != null:
		update_ice_indicator(dist)
	
	# if distance is lower than 1 ...
	if dist <= 1:
		# un-stuck both players
		if is_stuck: unstick()
		if other_player.is_stuck: other_player.unstick()
	
	# if distance is above the warmth threshold ...
	elif dist > warmth_threshold:
		# and we're playing an ice level
		if root_node.warmth_enabled:
			# we lose the game instantly!
			root_node.end_level(false, null, self)
	
	return dist

func show_status(stat_change):
	# choose the right frame
	var new_frame = 0
	if stat_change == 'doubts':
		new_frame = 2
	elif stat_change == 'fears':
		new_frame = 1
	elif stat_change == 'butterflies':
		new_frame = 0
	
	# save which status we switched to
	# (mostly needed for the undo system)
	CUR_STATUS = stat_change
	
	# set that frame
	$StatusIndicator.frame = new_frame
	
	# show indicator + play animation
	$StatusIndicator.show()
	$StatusIndicator/AnimationPlayer.play('Status Flicker')

func hide_status():
	# hide indicator + stop animation
	$StatusIndicator.hide()
	$StatusIndicator/AnimationPlayer.stop()
	
	# save that we have no status
	CUR_STATUS = 'none'

func _process(delta):
	# FOR DEBUGGING
	# (player 1 only, checks some things)
	if PLAYER_NUM == 0:
		var pos_3d_above = v3_to_index(TILEMAP_POS + Vector3(-1,-1,1))
		if GRID.has(pos_3d_above):
			var val = GRID[pos_3d_above]
			var other_player = (PLAYER_NUM + 1) % 2
			if val.CELL_TYPE == -(other_player+1):
				if val.z_bounds.x < z_bounds.y:
					print("Z BOUNDS NOT CORRECT")
	
	# If this player is disabled, don't do anything else
	if is_disabled or is_stuck:
		return
	
	# If we need to wait a few frames (for input),
	# check that and decrement wait_frames
	if wait_frames > 0:
		wait_frames -= 1

	#$PosLabel.set_text(v3_to_index(TILEMAP_POS))
	
	
	###
	# HANDLE MOVEMENT
	# (check gravity, or updating as we move)
	###
	
	# if we're NOT moving ...
	if not is_moving:
		# check if we should fall down because of gravity
		var pos_3d_below = TILEMAP_POS + Vector3(1,1,-1)
		var apply_gravity = true
		
		# if there is SOMETHING below us, disable the gravity for this tick
		if GRID.has(v3_to_index(pos_3d_below)):
			# check if it's the other player!
			# if we satisfied the "leap of faith" win condition, we win!
			var val_below = GRID[v3_to_index(pos_3d_below)]
			var other_player = (PLAYER_NUM + 1) % 2
			if val_below.CELL_TYPE == -(other_player+1):
				if last_move_backward and fall_counter >= 1:
					# tell the main node to end the level
					play_sound('game_win')
					get_node("/root/Node2D").end_level(true, get_position(), self )
			
			# in any case, if there's an object below us, reset gravity
			apply_gravity = false
			fall_counter = 0
		
		# if we're being influenced by butterflies, do NOT fall down
		if butterflies != null:
			apply_gravity = false
			
			# Instead, check if we still need to move up some more
			butterflies.check_force(self)

		if apply_gravity:
			move_down()
	else:
		# update our bounds, if we're moving
		update_bounds()
		
		# tell main node we're moving
		get_node("/root/Node2D").update_depth_sort = true

func next_sight_step(pos, dir, num_steps):
	var path = []
	
	# get the next block
	var next_block = pos + dir
	var ind = v3_to_index(next_block)
	
	# increase number of steps taken
	num_steps += 1
	
	# add the (3D) position to the path
	path.append( pos )
	
	# after X steps where nothing happened, the sight ray dies
	var max_steps = 6
	if num_steps > max_steps:
		return path
	
	# if there is SOMETHING here
	if GRID.has(ind):
		var val = GRID[ind]
		
		# if it's a mirror (type 1, 2 or 3)
		if val.CELL_TYPE in mirror_cells:
			# change light direction
			# also reset number of steps
			# and add the resulting path to the path we already found
			dir = val.get_reflection_vector(dir)
			
			# if dir returns an empty vector, this reflection is impossible/not allowed for some reason
			if dir.length() == 0:
				return path
		
			val.show_reflection( next_block, TILEMAP_POS, self )

			#dir = Vector3(-dir.y, dir.x, dir.z) # 90 degree angle to the RIGHT
			# dir = Vector3(0, 0, 1) # straight up
			
			path = path + next_sight_step(next_block, dir, 0)
		
		# if it's another player
		elif val.CELL_TYPE < 0:
			path.append( next_block)
			return path
		
		# if not, stop the ray
		else:
			return path
	
	# if there is NOTHING here, go to next step
	else:
		path = path + next_sight_step(next_block, dir, num_steps)
	
	return path

func hide_line_of_sight():
	view_drawer.create_line_of_sight(null)

func determine_line_of_sight():
	# for each of the four directions (left/right/up/down)
	# emit a "sight" ray
	var light_path
	var has_lost = false
	for i in range(4):
		var dir = get_custom_dir_vector(i)
		
		light_paths[i] = next_sight_step(TILEMAP_POS, dir, 0)
		
		# if this is the direction we're looking in ...
		if i == FORWARD_DIR:
			# if it's the other player ...
			var other_player = (PLAYER_NUM + 1) % 2
			
			# get cell at last light path index
			# (index -1 checks the LAST element in the array)
			var last_ind = v3_to_index(light_paths[i][-1])
			if GRID.has(last_ind) and GRID[last_ind].CELL_TYPE == -(other_player+1):
				# LOSE! LOSE! LOSE!
				has_lost = true
				play_sound("game_loss")
				get_node("/root/Node2D").end_level(false, null, self)
				break
			
			# TO DO: Only count this when the other (target) player is NOT moving?

	if has_lost:
		view_drawer.create_line_of_sight( light_paths[FORWARD_DIR] )

func get_action(action_name):
	return action_name + str(PLAYER_NUM)

func _input(ev):
	if is_disabled or is_stuck or wait_frames > 0:
		return
	
	if not is_rotating:
		if ev.is_action_released( get_action("left") ) and not ev.is_echo():
			rotate(-1)
		elif ev.is_action_released( get_action("right") ) and not ev.is_echo():
			rotate(1)
	
	if not is_rotating and not is_moving:
		if ev.is_action_released( get_action("forward") ):
			move_forward(1)
		elif ev.is_action_pressed( get_action("backward") ):
			move_forward(-1)

func rotate(rotate_dir, called_from_undo = false):
	if is_rotating or wait_frames > 0 or is_stuck:
		return
	
	# if this wasn't a "reverse rotate" through the undo manager ...
	if not called_from_undo:
		# save this move as a new one into the undo-manager
		undo_manager.register_state()
	
	# play the clickedyclack rotation sound
	play_sound('rotate2-edited')
	
	# disable rotating while we're playing the animation
	is_rotating = true
	
	# remember in which direction we're rotating
	cur_rotate_dir = rotate_dir
	
	# stop blinking animation
	$AnimPlayerEyes.stop()
	
	var next_frame = (frame + 8 + cur_rotate_dir) % 8
	tween.interpolate_property(self, 'wanted_rotation_frame',
							   frame, next_frame,
							   rotation_speed*0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()

func rotation_finished():
	# remember we're done rotating
	is_rotating = false
	
	# set the right forward direction
	FORWARD_DIR = int( frame * 0.5 )
	
	# tell the world sight lines should update
	root_node.update_sight_lines()
	
	# and update our possible moves
	root_node.update_possible_moves()
	
	#wait_frames = 0.0
	

func move_down():
	# if we have a negative height, we're below level bounds, and have thus lost the level
	if (TILEMAP_POS.z - 1) < 0:
		play_sound("game_loss")
		root_node.end_level(false, null, self)
		return

	# increase fall counter
	fall_counter += 1
	
	# disable moving (while we're moving/playing a tween)
	is_moving = true
	
	# find corresponding tile in the tilemap => use it to get the position
	var old_tilemap_position = TILEMAP_POS
	var new_tilemap_position = TILEMAP_POS + Vector3(1,1,-1)
	var cell_pos = tilemap.map_to_world(Vector2(new_tilemap_position.x, new_tilemap_position.y)) + tile_offset
	
	# now create a tween to move to our destination
	# (the tween object has a signal that's fired when we REACH the destination)
	tween.interpolate_property(self, "position", 
								null, cell_pos, 
								fall_tween_duration, Tween.TRANS_LINEAR, Tween.TRANS_LINEAR)
	
	update_position_in_grid(new_tilemap_position, old_tilemap_position)

	tween.interpolate_property(self, "TILEMAP_POS", 
								null, new_tilemap_position, 
								fall_tween_duration, Tween.TRANS_LINEAR, Tween.TRANS_LINEAR)


	tween.start()

func get_custom_dir_vector(vec):
	match vec:
		0:
			return Vector3(1,0,0)
		1:
			return Vector3(0,1,0)
		2:
			return Vector3(-1,0,0)
		3:
			return Vector3(0,-1,0)

func get_dir_vector():
	if FORWARD_DIR == 0:
		return Vector3(1,0,0)
	elif FORWARD_DIR == 1:
		return Vector3(0,1,0)
	elif FORWARD_DIR == 2:
		return Vector3(-1,0,0)
	elif FORWARD_DIR == 3:
		return Vector3(0,-1,0)

func check_tile_availability(pos):
	if GRID.has(v3_to_index(pos)):
		var val = GRID[v3_to_index(pos)]
		if not (val.CELL_TYPE in passthrough_cells):
			return false
	
	return true

func move(move_vec, being_dragged = false, butterfly_force = false):
	# find the right vector that corresponds with the direction we're facing
	var temp_pos = TILEMAP_POS + move_vec
	
	# if we're being dragged by another
	# override win conditions
	# and disable any effects we were having (like butterflies)
	if being_dragged:
		if not butterfly_force:
			deactivate_butterfly()
		last_move_backward = false
		fall_counter = 0.0
	
	###
	# CHECK IF WE'RE ALLOWED TO MOVE
	#  => Check for a tilemap cell in that direction
	#  => Check for a player in that direction
	# If not, break out of this function
	##
	
	# If there's something here, we can't move!
	# Also perform a more specific check, as there are things we can pass through
	if not check_tile_availability(temp_pos):
		# turn off particles, just in case
		$MovementParticles.emitting = false
			
		return

	###
	# ACTUALLY MOVE
	###
	
	wait_frames = 0.0
	
	# check if the other player is standing on top of us
	# => if so, drag them with us!
	var old_pos = TILEMAP_POS
	var ind_above = v3_to_index(old_pos + Vector3(-1, -1, 1))
	if GRID.has(ind_above):
		var other_player = (PLAYER_NUM + 1) % 2
		var val = GRID[ind_above]
		if val.CELL_TYPE == -(other_player+1):
			val.move(move_vec, true)
	
	#TILEMAP_POS = temp_pos
	
	update_position_in_grid(temp_pos, TILEMAP_POS)
	
	# disable moving (while we're moving/playing a tween)
	is_moving = true
	
	# find corresponding tile in the tilemap => use it to get the position
	var cell_pos = tilemap.map_to_world(Vector2(temp_pos.x, temp_pos.y)) + tile_offset
	
	# now create a tween to move to our destination
	# (the tween object has a signal that's fired when we REACH the destination)
	tween.interpolate_property(self, "position", 
								null, cell_pos, 
								move_tween_duration, Tween.TRANS_LINEAR, Tween.TRANS_LINEAR)

	# update the actual tilemap position (via a tween)
	tween.interpolate_property(self, "TILEMAP_POS", 
							   null, temp_pos,
								move_tween_duration, Tween.TRANS_LINEAR, Tween.TRANS_LINEAR)

	# start the tween
	tween.start()

func disableHighlighters():
	for i in range(2):
		highlighter_scenes[i].hide()

func register_state():
	return { 
		"obj": self, 
		"position": TILEMAP_POS, 
		"rotation": FORWARD_DIR,
		"status": CUR_STATUS,
		"custom_parameters": { 
			"is_doubting": is_doubting,
			"cur_doubt_ind": cur_doubt_ind,
			"butterflies": butterflies,
			"is_stuck": is_stuck,
			"fall_counter": fall_counter,
			"last_move_backward": last_move_backward
			}
		 }

func teleport_to_doubt():
	# find next teleporter in line
	# (take number of teleporter into account, could be 2 or 3)
	var dco = root_node.doubt_cell_objects
	var cur_teleport = null
	var max_tries = 10
	var num_tries = 0

	while(cur_teleport == null):
		cur_doubt_ind = (cur_doubt_ind + 1) % 3
		cur_teleport = dco[cur_doubt_ind]

		# use a maximum number of tries; 
		# just to be sure I don't shoot myself in the foot when debugging
		num_tries += 1
		if num_tries > max_tries:
			print("ERROR! Infinite loop when teleporting")
			return

	# set position directly to there
	# (well, the tile above it, obviously)
	set_position_directly(cur_teleport.TILEMAP_POS + Vector3(-1,-1,1))
	
	# play teleporting sound
	play_sound('doubts-2', true)

func move_forward(forward):
	# we are NOT allowed to move simultaneously with the other player
	if is_moving or is_rotating or other_player.is_moving or is_stuck or wait_frames > 0:
		return
	
	# check if move is legal; 
	# if so, execute + register into undo + remove any previous effects (such as butterflies)
	# if not, do nothing
	var new_pos = TILEMAP_POS + get_dir_vector()*forward
	if check_tile_availability(new_pos):
		# position particles near our backside
		var pos = get_dir_vector() * forward * -1
		var pos_iso = Vector2((pos.x - pos.y) * 65, (pos.x + pos.y) * 32)
		$MovementParticles.set_position(pos_iso)
		
		# emit movement particles
		$MovementParticles.emitting = true
		
		# only play sliding sound if we're actually moving on the ground, of course
		play_sound("slide")
		
		# determine if last move was backward (for win condition)
		if forward < 0:
			last_move_backward = true
		else:
			last_move_backward = false
		
		# register move into the undo_manager
		my_last_move = TILEMAP_POS
		undo_manager.register_state()
		
		# disable butterflies (if they were enabled anyway)
		deactivate_butterfly()
		
		# remember we moved by input
		moved_by_input = true
		
		move( get_dir_vector()*forward )

func update_eyes():
	# if eyes are visible, set them to the correct frame
	var blink_frames = [0,2,1]
	var blink_positions = [Vector2(26, -36), Vector2(6.45, -32.5), Vector2(-20.5, -37.4)]
	if frame <= 2:
		$Eyes.frame = blink_frames[frame]
		$Eyes.show()
		$Eyes.set_position(blink_positions[frame])
	else:
		$Eyes.hide()

func _on_Tween_tween_completed(object, key):
	# if this was a FRAME tween ...
	# it means we're rotating (or have finished a rotation)
	if key == ":wanted_rotation_frame":
		frame = wanted_rotation_frame
		
		# if this is an EVEN number, it's a finished frame!
		if (frame % 2 == 0):
			rotation_finished()
		
		# if this is an ODD number, we're in the middle of a rotation!
		elif (frame % 2 == 1):
			var next_frame = (frame + 8 + cur_rotate_dir) % 8
			tween.interpolate_property(self, "wanted_rotation_frame",
									   frame, next_frame,
									  rotation_speed * 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
			tween.start()
		
		update_eyes()
			
	# if this was a position tween ... (aka movement)
	# NOTE: Previously, I checked the ":position" property => DON'T DO THIS
	#       It caused slight imprecisions in TILEMAP_POS, because position tween ended _before_ the TILEMAP_POS
	#		These imprecisions caused huge depth sorting issues over time.
	elif key == ":TILEMAP_POS":
		# ... reset movement variable
		is_moving = false
		
		# always reset particles
		# (they might not be on, because we're being dragged or something)
		# (but hey, just to be sure)
		$MovementParticles.emitting = false
		
		# update bounds one last time
		update_bounds()
		
		# update depth sort one last time
		root_node.update_depth_sort = true
		
		var dist = check_distance()
		
		###
		# CHECK DOUBTS
		###
		# Only trigger when we MOVED using INPUT
		# (so not when falling, or when rotating, or whatever)
		if moved_by_input:
			if other_player.is_doubting:
				# teleport it to the next doubt tile
				other_player.teleport_to_doubt()
			
			# reset input move checker
			moved_by_input = false
		
		# if we're doubting ourselves, stop that whenever we move
		if is_doubting:
			stop_doubts()
		
		# update light value
		update_light_value()
		
		# check what this player can see
		# (this also takes into account mirrors, lights, etc.)
		# (if we can see the other player, it's GAME OVER)
		# IMPORTANT: We only do this once something is done moving and the world is static again => huge performance improvement
		root_node.update_sight_lines()

		# check if there's something blocking the view towards this player
		root_node.check_blocking_objects()
		
		# update possible moves (highlight/unhighlight)
		root_node.update_possible_moves()
		
		# check if we're standing on a BUTTON that should be activated
		var pos_3d_below = v3_to_index(TILEMAP_POS + Vector3(1,1,-1))
		if GRID.has(pos_3d_below):
			var val = GRID[pos_3d_below]
			
			if val.CELL_TYPE in button_cells:
				# find the connected object (whatever it is; an elevator, mirror, light, etc.)
				var ind = button_cells.find(val.CELL_TYPE) % 3
				var objects = root_node.button_objects[ind]
				
				# play sound
				play_sound("switch")
				
				# activate it!
				for obj in objects:
					obj.activate()
			
			# check if we're standing on a BUTTERFLY
			# if so, activate it
			elif val.CELL_TYPE in butterfly_cells:
				activate_butterfly(val)
			
			# check if we're standing on a FEAR tile
			elif val.CELL_TYPE in fear_cells:
				if dist > 1:
					# if so, make us stick to this tile
					stick()
			
			# check if we're standing on a DOUBT tile
			elif val.CELL_TYPE in doubt_cells:
				# Toggle a variable to remember we're in doubt
				start_doubts(val)


func play_sound(path, wav = false):
#	# don't play if something is already playing
#	# (mainly to prevent duplicate sounds)
#	if $AudioStreamPlayer2D.playing:
#		return
	
	$AudioStreamPlayer2D.volume_db = Global.get_soundfx_level()
	
	if path == 'butterflies-short':
		$AudioStreamPlayer2D.volume_db = Global.get_soundfx_level() + 6

	# if path = null, it means I want the thing to stop
	if path == null:
		$AudioStreamPlayer2D.playing = false
		return
	
	# otherwise, play the sound at specified path
	if wav:
		$AudioStreamPlayer2D.stream = load("res://Sound/" + str(path) + ".wav")
	else:
		$AudioStreamPlayer2D.stream = load("res://Sound/" + str(path) + ".ogg")
	$AudioStreamPlayer2D.pitch_scale = rand_range(0.95,1.05)
	$AudioStreamPlayer2D.playing = true
	
	if path == 'rotate2' or path == 'rotate2-edited':
		$AudioStreamPlayer2D.pitch_scale = 2

func display_exclamation_mark():
	var seo = get_node("SeeingEachOther")
	seo.set_visible(true)
	
	# NOTE: I already set the z-index to 1001 for exclamation marks,
	#       no need to set it dynamically or anything
	#seo.z_index = TILEMAP_POS.x + (CUR_HEIGHT + 1) * 3.0 + TILEMAP_POS.y
	
	return seo

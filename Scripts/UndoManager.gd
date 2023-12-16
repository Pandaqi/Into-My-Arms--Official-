extends Node

var moves = []
var dynamic_objects = []

func initialize():
	# remove undo button if not needed
	# (we're not in easy mode, or we're on mobile)
	if (not Global.get_mode()) or Global.get_device() == "Android":
		get_node("/root/Node2D/GUI/Undo").hide()
	
	# cache the list of all dynamic objects
	dynamic_objects = get_tree().get_nodes_in_group("DynamicObjects")
	
	# register state once
	register_state()

func can_display_ad():
	return (moves.size() > 4)

func register_state():
	# for each object ...
	var new_state = []
	for obj in dynamic_objects:
		# add the object's current state to the new state
		# (the function on the object determines what gets saved and how)
		new_state.append( obj.register_state() )
	
	# save this new state on the stack
	moves.append(new_state)
	
	# make sure the undo button is enabled
	get_node("/root/Node2D/GUI/Undo").set_disabled(false)

func undo_last_move():
	# if there are no moves to undo, don't execute and throw a debugging error instead
	if moves.size() <= 0:
		print("ERROR! No more moves to undo")
		return
	
	# grab last move from the stack
	# (and remove it from move stack altogether)
	var last_move = moves.pop_back()
	
	# go through all entries in last_move
	for state in last_move:
		# grab the current object
		var obj = state.obj
		
		# if position doesn't match ...
		if state.has('position'):
			if state.position != obj.TILEMAP_POS:
				# set position directly
				obj.set_position_directly(state.position)
		
		# if rotation doesn't match
		if state.has('rotation'):
			if state.rotation != obj.FORWARD_DIR:
				# "undo" the rotation
				# Figure out rotation direction, then call function with the right parameter
				if (state.rotation + 1) % 4 == obj.FORWARD_DIR:
					obj.rotate(-1, true)
				else:
					obj.rotate(1, true)
		
		# if there's a status attached ...
		if state.has('status'):
			# show/hide it based on the value
			if state.status == 'none':
				obj.hide_status()
			else:
				obj.show_status(state.status)
		
		# if state is about a mirror ...
		if state.has('mirror_normal'):
			# and the mirror rotation has changed between states ...
			if state.mirror_normal != obj.mirror_normal:
				# activate in the opposite direction!
				obj.activate(-1)
		
		# if it has custom parameters, go through all of them and set them directly
		if state.has('custom_parameters'):
			for param in state.custom_parameters:
				obj.set(param, state.custom_parameters[param])
	
	# if warmth is enabled, do an extra check after placing everything
	# (NOTE: the same can be done HERE for any other global effects)
	if get_node("/root/Node2D").warmth_enabled:
		get_node("/root/Node2D").players[0].check_distance()
	
	# if last move stack is now empty,
	# disable the undo button
	if moves.size() <= 0:
		get_node("/root/Node2D/GUI/Undo").set_disabled(true)

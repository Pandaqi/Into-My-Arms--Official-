extends "res://Scripts/TileMain.gd"

var locked = true setget lock_changed

func register_state():
	return {
		"obj": self,
		"custom_parameters": {
			"locked": locked
			}
	}

func lock_changed(v):
	# if the new value is different, properly activate this shit
	if locked != v:
		activate()

func activate():
	# (un)lock) gate
	locked = !locked
	
	var pos_key =  v3_to_index(TILEMAP_POS)
	
	# if we want to UNLOCK it ...
	if not locked:
		# remove us from the grid
		GRID.erase(pos_key)
		
		# hide us
		hide()
	
	# if we want to LOCK it
	else:
		# first, check if this spot is empty
		if GRID.has(pos_key):
			# if not, revert decision, return
			locked = !locked
			return
		else:
			# if it's empty, insert ourselves here
			GRID[pos_key] = self
			
			# and show ourselves
			show()
	
	# changing a gate, will change the possible moves
	root_node.update_possible_moves()
	
	# and it will change the sight lines
	root_node.update_sight_lines()

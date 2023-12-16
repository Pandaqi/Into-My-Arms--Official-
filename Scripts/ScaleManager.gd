extends Node2D

export (bool) var in_level = true

func register_node_for_scaling(node):
	if (node is TextureButton):
		node.set_meta("initial_size", node.rect_min_size)
	
	elif (node is Label) or (node is Button):
		if node.is_in_group("Font48"):
			node.set_meta("initial_size", 48)
		
		elif node.is_in_group("Font32"):
			node.set_meta("initial_size", 32)
		
		elif node.is_in_group("Font8"):
			node.set_meta("initial_size", 8)
		
		else:
			node.set_meta("initial_size", 16)
	
	elif (node is Node2D):
		node.set_meta("initial_size", node.get_scale())
	
	# TO DO: Get initial scale for Labels and Sprites (but HOW)

func _ready():
	###
	# For all resizable nodes, save their initial scale
	###
	for node in get_tree().get_nodes_in_group("ResizableNodes"):
		register_node_for_scaling(node)
	
	###
	# Attach resize signal to this node
	# 
	# This is needed to make the camera zoom and control size correct for different screen sizes
	# (Tried it with controls and stretch settings, but that gave no satisfactory results) 
	###
	get_tree().get_root().connect("size_changed", self, "window_resize")
	
	# call it once, to automatically set the right settings for the current size
	window_resize()

func window_resize():
	var new_size = get_viewport().size
	
	# Update camera zoom
	var base_dim = Vector2(512, 288)
	var base_zoom = Vector2(2,2)
	var preferred_x = base_zoom.x * (base_dim.x / new_size.x)
	var preferred_y = base_zoom.y * (base_dim.y / new_size.y)
	var final_zoom = max(preferred_x, preferred_y)
	
	# EXPERIMENT: see if setting zoom to an integer works better for visual effects
	final_zoom = ceil(final_zoom)
	
	var camera = null
	var mobile_controls_1 = null
	var mobile_controls_2 = null
	
	var keyboard_controls_1 = null
	var keyboard_controls_2 = null
	
	if in_level:
		camera = get_node("/root/Node2D/Camera") 
		if Global.get_device() == "Android":
			mobile_controls_1 = get_node("/root/Node2D/GUI/Player1Controls")
			mobile_controls_2 = get_node("/root/Node2D/GUI/Player2Controls")
		else:
			keyboard_controls_1 = get_node("/root/Node2D/GUI/Player1ControlsKeyboard")
			keyboard_controls_2 = get_node("/root/Node2D/GUI/Player2ControlsKeyboard")
	
	# if we HAVE a camera, set the zoom
	if camera != null: 
		camera.set_zoom(Vector2(final_zoom, final_zoom))
	
	# Get the correct font size, based on screen resolution
	var preferred_font_x = new_size.x / base_dim.x
	var preferred_font_y = new_size.y / base_dim.y
	var scale_level = round( min(preferred_font_x, preferred_font_y) )
	
	# Update all controls to the correct positions
	for node in get_tree().get_nodes_in_group("ResizableNodes"):
		if (node is Label) or (node is Button):
			var font_size = scale_level * int( node.get_meta("initial_size") )
			var path = "res://Fonts/BasicFont" + str(font_size) + ".tres"
			
			var file_check = File.new()
			while not file_check.file_exists(path):
				font_size -= 8
				path = "res://Fonts/BasicFont" + str(font_size) + ".tres"
				
				# create hard minimum at 8pt
				if font_size <= 8:
					path = "res://Fonts/BasicFont16.tres"
					break
			
			node.add_font_override("font", load(path))
		
		# container nodes will always start at scale (1,1) and just use the scale level
		elif node is Node2D:
			node.set_scale( scale_level * node.get_meta("initial_size") )
		
		elif node is TextureButton:
			if node.is_in_group("ResizeExceptions"):
				continue
			
			var new_rect_size = node.get_meta("initial_size") * scale_level
			if node.has_method("on_resize"):
				node.on_resize(new_rect_size)
			
			else:
				# scale minimum size of button (otherwise, button isn't clickable and doesn't center align)
				node.rect_min_size = new_rect_size
				
				# scale sprite(s) that are children
				# I make all buttons 4X the (56, 56) size to support all resolutions (and keep power of 2 scales)
				for child in node.get_children():
					if child is Sprite:
						child.set_scale( (new_rect_size.x / 56.0) * Vector2(0.25,0.25) )
	
	# Update player control anchoring positions (only on mobile)
	if Global.get_device() == "Android":
		if mobile_controls_1 != null and mobile_controls_2 != null:
			mobile_controls_1.set_position(Vector2(0, new_size.y))
			mobile_controls_2.set_position(Vector2(new_size.x, new_size.y))
	else:
		if keyboard_controls_1 != null and keyboard_controls_2 != null:
			keyboard_controls_1.set_position(Vector2(0, new_size.y))
			keyboard_controls_2.set_position(Vector2(new_size.x, new_size.y))
	
	# Update ice indicator (if it exists)
	if has_node("/root/Node2D/GUI/IceIndicator"):
		var ice_indicator = get_node("/root/Node2D/GUI/IceIndicator")
		ice_indicator.set_position(Vector2(0.5*new_size.x, 0))
	
	# Update background stars
	if in_level:
		var particle_node = get_node("/root/Node2D/Background/BackgroundStars")
		particle_node.emission_rect_extents = new_size
		particle_node.amount = 16 * scale_level

extends Camera2D

var players
var dragging = false
var last_drag_pos = Vector2.ZERO
var has_been_dragged = false

# VARIABLES FOR PANNING/PINCHING CONTROL
export(float) var pan_smooth := -5
export(float) var follow_smooth : float
var _cur_vel := Vector2(0,0)
var _last_cam_pos := Vector2(0,0)

export(float) var max_zoom = 4.0
export(float) var min_zoom = 0.25

var _touches = {} # for pinch zoom and drag with multiple fingers
var _touches_info = { "num_touch_last_frame": 0, "radius": 0, "total_pan": 0 }
var _debug_cur_touch = 0

func _ready():
	# if this isn't a retry ...
	if not Global.is_retry():
		# start off screen
		var vp_size = get_viewport().size * get_zoom().x
		self.offset = Vector2(-vp_size.x,0)
	
	# and start with the old camera pos (from previous level)
	if Global.get_prev_camera_pos() != null:
		position.y = Global.get_prev_camera_pos().y
	
	# cache players
	players = get_tree().get_nodes_in_group("Players")

func focus_on_players():
	var t = 0.95
	set_position( get_position() * t + (1.0-t) * find_average_position() )

func find_average_position():
	return 0.5 * ( players[0].get_position() + players[1].get_position() )

func _process(delta):
	# only update average position if player hasn't dragged out of this mode
	if not has_been_dragged:
		focus_on_players()
	
	###
	# For pinching/panning
	###
	
	# if there ARE touches on the screen ...
	if _touches.size() > 0:
		# Remember we're now using custom camera movement,
		# not the default "center on players"
		has_been_dragged = true
		
		# REMEMBER our current velocity
		# (compare current cam position with previous cam position)
		# so we know how fast we're moving the camera, at the moment
		update_vel(delta)
	
	# if there are NO touches on the screen
	else:
		# perform real smoothing
		# => fade out velocity until we've stopped again
		do_real_smoothing(delta)

func zoom_camera(dz):
	# calculate new zoom value
	var delta_zoom = 0.1
	var zoom_bounds = Vector2(0.5, 5)
	var new_zoom = get_zoom().x + dz * delta_zoom
	
	# clamp to zooming bounds
	new_zoom = clamp(new_zoom, zoom_bounds.x, zoom_bounds.y)
	
	# update zoom
	set_zoom(Vector2(new_zoom, new_zoom))

func _input(event):
	_input_touch(event)

func _input_touch(event):
	##
	# Handle actual Multi-touch from capable devices
	##
	
	# If we're touching the screen (touch start, pressed = true)
	if event is InputEventScreenTouch and event.pressed == true:
		# Save this event in the _touches dictionary
		_touches[event.index] = {"start": event, "current": event}
	
	# If we've STOPPED touching the screen (touch end, pressed = false)
	if event is InputEventScreenTouch and event.pressed == false:
		# Erase event from _touches dictionary
		_touches.erase(event.index)
	
	# If we're DRAGGING the screen (update continuously by godot)
	if event is InputEventScreenDrag:
		# Update current event (for this finger)
		_touches[event.index]["current"] = event
		
		# TO DO/QUESTION: Does this need to be commented out or not?
		#update_pinch_gesture()
	
	###
	# Code below simulates multi touch from keyboard + mouse
	###

	# Handle Multi-touch using 'A' key and mouse event instead of Touch event	
	pretend_multi_touch(event)
	
	###
	# Code below is what ACTUALLY creates pinching/moving motion
	###
	
	
	# update touch information
	# => check what's happening, and if needed, perform panning
	update_touch_info()
	
	# update pinch gesture
	# => check if user is pinching, and if so, automatically zoom
	update_pinch_gesture()
	
	
	###
	# This code handles ZOOMING with the computer (scrollwheel or +/- keys)
	###
	
	# Some hacky code to listen for "+" and "-" keys (for zooming)
	var key_str = ""
	if event is InputEventKey and event.unicode != 0:
		key_str = PoolByteArray([event.unicode]).get_string_from_utf8()
	
	# Determine zoom factor (from zoom in/zoom out events)
	var zoom_factor :float = 0.0
	if event.is_action_pressed("zoom_in") or key_str == '+':
		zoom_factor = -1.5 * zoom.x
	elif event.is_action_pressed("zoom_out") or key_str == '-':
		zoom_factor = 1.5 * zoom.x
		
	if zoom_factor != 0.0:
		var prev_zoom : Vector2 = zoom
		_zoom_camera(zoom_factor)
		var new_zoom : Vector2 = zoom
		if event is InputEventMouse and abs((prev_zoom - new_zoom).length_squared()) > 0.00001:
			var pos = event.position
			var vp_size = self.get_viewport().size

			var old_dist = ((event.position - (vp_size / 2.0))*prev_zoom)
			var new_dist = ((event.position - (vp_size / 2.0))*new_zoom)
			var cam_need_move = old_dist - new_dist
			self.position += cam_need_move

# Zoom Camera
func _zoom_camera(dir):
	zoom += Vector2(0.1, 0.1) * dir
	zoom.x = clamp(zoom.x, min_zoom, max_zoom)
	zoom.y = clamp(zoom.y, min_zoom, max_zoom)

func update_touch_info():
	# if there are no touches ...
	if _touches.size() <= 0:
		# remember there were no touches last frame
		# and we shouldn't pan
		# and RETURN
		_touches_info.num_touch_last_frame = _touches.size()
		_touches_info["total_pan"] = 0
		return
	
	# if there were no touches last frame, reset our smoothing
	if _touches_info["num_touch_last_frame"] == 0:
		reset_smooth()
	
	# find the average touch between all of our touches
	# first, loop through all touches, update avg_touch
	var avg_touch = Vector2(0,0)
	for key in _touches:
		avg_touch += _touches[key].current.position
	
	# then divide by total
	_touches_info["cur_pos"] = avg_touch / _touches.size()
	
	# and if the new number of touches doesn't match the previous number ...
	if _touches_info.num_touch_last_frame != _touches.size():
		# save our current position as the next target
		_touches_info["target"] = _touches_info["cur_pos"]

	# update previous number of touches
	_touches_info.num_touch_last_frame = _touches.size()
	
	# FINALLY, perform a multitouch pan
	do_multitouch_pan()
	
func do_multitouch_pan():
	# get difference between current position and target
	var diff = _touches_info.target - _touches_info.cur_pos
	
	# update position based on difference (and take zoom into account)
	var new_pos = self.position + (diff * zoom.x)
	
	# clamp to level bounds
	var bounds = [Vector2(-1000,1000), Vector2(-1000,1000)]
	if new_pos.x < bounds[0].x or new_pos.x > (bounds[0].y):
		new_pos.x = self.position.x
	if new_pos.y < bounds[1].x or new_pos.y > (bounds[1].y):
		new_pos.y = self.position.y
	
	# finally, save new position
	self.position = new_pos
	
	# and make the current position our new target
	_touches_info.target = _touches_info.cur_pos

func pretend_multi_touch(event):
#	# if we press R, reset touches!
#	if event is InputEventKey and event.scancode == KEY_R:
#		_touches.erase(0)
#		_touches.erase(1)
#
#	# if we press the A button
#	if event is InputEventKey and event.scancode == KEY_A:
#		# when pressed, toggle between finger 0 and finger 1
#		if event.pressed:
#			_debug_cur_touch = (_debug_cur_touch + 1) % 2
	
	# if we press the mouse button, count that as a touch
	if event is InputEventMouseButton:
		if event.pressed:
			_touches[_debug_cur_touch] = {"start":event, "current":event}
		else:
			_touches.erase(_debug_cur_touch)
	
	# if we move the mouse, register that as a move event
	if event is InputEventMouseMotion:
		if _debug_cur_touch in _touches:
			_touches[_debug_cur_touch]["current"] = event

func update_pinch_gesture():
	# if there are fewer than 2 touches, we can never have a pinch gesture!
	if _touches.size() < 2:
		_touches_info["radius"] = 0
		_touches_info["previous_radius"] = 0
		return

	# get previous distance between touches
	_touches_info["previous_radius"] = _touches_info["radius"]
	
	# calculate new distance between touches
	_touches_info["radius"] = (_touches.values()[0].current.position - _touches_info["target"]).length()

	# if prevous distance was 0, return
	# (When would that ever happen??)
	if _touches_info["previous_radius"] == 0:
		return
	
	# Calculate zoom factor (based on percentage difference between radii)
	var zoom_factor = (_touches_info["previous_radius"] - _touches_info["radius"]) / _touches_info["previous_radius"]
	var final_zoom = zoom.x + zoom_factor

	# Actually update zoom value on the camera
	zoom = Vector2(final_zoom,final_zoom)
	zoom.x = clamp(zoom.x, min_zoom, max_zoom)
	zoom.y = clamp(zoom.y, min_zoom, max_zoom)

	# Move camera to keep the same object underneath it
	var vp_size = self.get_viewport().size
	var old_dist = ((_touches_info["target"] - (vp_size / 2.0))*(zoom-Vector2(zoom_factor, zoom_factor)))
	var new_dist = ((_touches_info["target"] - (vp_size / 2.0))*zoom)
	var cam_need_move = old_dist - new_dist
	self.position += cam_need_move

func reset_smooth():
	_last_cam_pos = self.position
	_cur_vel = Vector2(0,0)

func update_vel(delta : float):
	var cur_cam_pos := self.position
	var move := _last_cam_pos - cur_cam_pos
	var move_speed : Vector2 = move / delta
	_cur_vel = (_cur_vel + move_speed) / 2.0
	_cur_vel.x = clamp(_cur_vel.x, -10000, 10000)
	_cur_vel.y = clamp(_cur_vel.y, -10000, 10000)
	_last_cam_pos = self.position

func do_real_smoothing(delta : float):
	var l = _cur_vel.length()
	var move_frame = 10 * exp(pan_smooth * ((log(l/10) / pan_smooth)+delta))
	_cur_vel = _cur_vel.normalized() * move_frame
	self.position -= _cur_vel * delta


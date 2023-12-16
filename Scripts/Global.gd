extends Node

var prev_camera_pos = null
var is_retry = false

var cur_level = 0
var play_intro = false

var max_levels = 40
var soundfx_level = 0

var easymode = false
var clouds_enabled = true

var color_schemes_in_order = [
	0,1,2,3,4,5,0,1,2,3, # levels 0-9
	4,5,0,1,2,3,4,5,0,1, # levels 10-19,
	2,3,4,5,0,  # levels 20-24,
	0,0,0,0,    # levels 25-28 (the ICE levels)
	1, # level 29
	2,3,4,5,0,1,2,3,4,5, # level 30-39
	0 # one last color, so we can transition into the outro
	]


var color_scheme_list = [
	# scheme 0 (BLUE)
	{ 
	  "grad_bottom": Color(0.2, 0.2, 1.0), 
	  "grad_top": Color(0.0, 0.6, 1.0), 
	  "hue_variation": -0.27,
	  "modulate": Color(1,1,1)
	},
	
	# scheme 1 (GREEN)
	{ 
	  "grad_bottom": Color(0.1, 0.5, 0.1), 
	  "grad_top": Color(0.0, 0.5, 0.3), 
	  "hue_variation": -0.54,
	  "modulate": Color(1,1,1)
	},
	
	# scheme 2 (RED)
	{ 
	  "grad_bottom": Color(0.5, 0.1, 0.1), 
	  "grad_top": Color(0.5, 0.0, 0.3), 
	  "hue_variation": 0.15,
	  "modulate": Color(1.0,0.6,0.6)
	},
	
	# scheme 3 (PURPLE)
	{ 
	  "grad_bottom": Color(0.5, 0.1, 0.5), 
	  "grad_top": Color(1.0, 0.6, 1.0), 
	  "hue_variation": 0.15,
	  "modulate": Color(1.0,0.6,0.9)
	},
	
	# scheme 4 (TURQOISE)
	{ 
	  "grad_bottom": Color(0.1, 0.5, 0.5), 
	  "grad_top": Color(0.0, 0.5, 0.5), 
	  "hue_variation": -0.27,
	  "modulate": Color(1,1,1)
	},
	
	# scheme 5 (YELLOW/ORANGE)
	{ 
	  "grad_bottom": Color(0.5, 0.5, 0.1), 
	  "grad_top": Color(0.5, 0.5, 0), 
	  "hue_variation": -1,
	  "modulate": Color(255.0,198/255.0,99/255.0)
	}
	
#	# scheme 6 (BLACK)
#	{
#	  "grad_bottom": Color(0.0, 0.0, 0.0), 
#	  "grad_top": Color(0.1, 0.1, 0.2), 
#	  "hue_variation": 0,
#	  "modulate": Color(0.2,0.2,0.2)
#	}
]

# Checks if a save file exists
# If not => creates one
# If so => grab current level
func check_save_file():
	var check_file = File.new()
	if not check_file.file_exists("user://savegame.save"):
		var new_game_dict = { "cur_level": 0 }
		
		cur_level = 0
		play_intro = true
		
		var write_save_game = File.new()
		write_save_game.open("user://savegame.save", File.WRITE)
		write_save_game.store_line(to_json(new_game_dict))
		write_save_game.close()
	else:
		# Retrieves our current level (for starting the game from the main screen)
		var save_game = File.new()
		save_game.open("user://savegame.save", File.READ)
		var content = parse_json(save_game.get_as_text())
		save_game.close()
		
		cur_level = content.cur_level

func set_cur_level(lvl):
	cur_level = lvl

func get_cur_level():
	return cur_level

func set_soundfx_level(lvl):
	soundfx_level = lvl

func get_soundfx_level():
	return soundfx_level

# Saves your progress
# If you finished a new level, unlocks the next level
func save_progress(level_num):
	# load old data
	var save_game = File.new()
	save_game.open("user://savegame.save", File.READ)
	var content = parse_json(save_game.get_as_text())
	save_game.close()
	
	print(level_num)
	print(content["cur_level"])
	
	# increment level counter (if we just finished our current level)
	# (I set it to the next level number, because that allows me to test it more easily)
	# (Using equality ( == ) and incrementing would work just fine here)
	if level_num >= content["cur_level"]:
		content["cur_level"] = level_num + 1
	
	var write_save_game = File.new()
	write_save_game.open("user://savegame.save", File.WRITE)
	write_save_game.store_line(to_json(content))
	write_save_game.close()
	
	# update the cur level counter here
	cur_level += 1

func set_prev_camera_pos(pos):
	prev_camera_pos = pos

func get_prev_camera_pos():
	return prev_camera_pos

func set_retry(val):
	print("Retry? ", val)
	is_retry = val

func is_retry():
	return is_retry

func set_mode(md):
	easymode = md

func get_mode():
	return easymode

func set_clouds(val):
	clouds_enabled = val

func get_clouds():
	return clouds_enabled

# NOTE: We only ever call this function BEFORE we start moving to the next level
# That's why it's the same as grab next color
# TO DO: I should make a distinction between these different types of calls ...
func grab_cur_color():
	return grab_next_color()

func grab_next_color():
	var next_level = cur_level - 1 + 1
	
	if color_schemes_in_order.size() < next_level:
		return color_scheme_list[0]
	
	return color_scheme_list[ color_schemes_in_order[ next_level ] ]

func get_device():
	#return "Android"
	return OS.get_name()

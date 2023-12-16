extends CanvasLayer

var previous_settings = []
var enabled = false

func _ready():
	AdManager.reload_rewarded_video()

func isEnabled():
	return enabled

###
# This input function handles both the AD SCREEN ( if it's showing )
#                             and the GENERAL BUTTONS (top left/right)
###
func _unhandled_input(ev):
	# if the pause screen is active, we cannot be active
	var pause_screen = get_node("/root/Node2D/PauseScreen")
	if pause_screen.enabled:
		return
	
	
	# if we're enabled ...
	if enabled:
		# => pressing U will undo the last move (but via ad screen)
		# => pressing R will restart the level
		# => and pressing ESC will remove the ad screen
		if ev.is_action_pressed("ui_cancel"):
			_on_Close_pressed()
		elif ev.is_action_pressed("ui_restart"):
			pause_screen._on_Retry_pressed()
		elif ev.is_action_pressed("undo") and Global.get_mode():
			_on_Button_pressed()
	
	# if we're NOT enabled!
	else:
		# and the game is NOT paused!
		if not get_tree().paused:
			# => pressing U will immediately undo the last move (doesn't need to go past an ad screen)
			# => pressing R will restart level
			# => and pressing ESC will return to main menu
			if ev.is_action_pressed("ui_cancel"):
				pause_screen._on_Menu_pressed()
			elif ev.is_action_pressed("ui_restart"):
				pause_screen._on_Retry_pressed()
			elif ev.is_action_pressed("undo") and Global.get_mode():
				get_node("/root/Node2D/UndoManager").undo_last_move()
	
	# set most recent input as handled
	get_tree().set_input_as_handled()

func _on_Button_pressed():
	# on Android, we need to watch a rewarded video, before the last move wa sundone
	if Global.get_device() == "Android":
		AdManager.show_rewarded_video()
	
	# otherwise, it's just immediately undone
	else:
		# pretend we just watched an ad
		get_node('/root/Node2D').just_watched_ad = true
	
		# and reset player/re-enable the game
		get_node('/root/Node2D').enable_game_after_ad()

func show_screen(settings):
	previous_settings = settings
	
	var instruc_label = $VBoxContainer/CenterContainer3/Label2
	
	# if we're on MOBILE ...
	if Global.get_device() == "Android":
		# If the undo manager says we can't display an ad, then don't
		# (we only display ads when you're X moves into the level => undoing your first move is pointless)
		if not get_node("/root/Node2D/UndoManager").can_display_ad():
			return false
		
		# if a rewarded video has loaded ...
		if AdManager.rewarded_video_is_loaded():
			instruc_label.set_text("(watch a video ad to undo the last move)")
			
			show_screen_elements()
			
			# pause the game
			get_tree().paused = true
			return true
		
		# otherwise, return false,
		# to tell the game there IS no ad and thus no SCREEN
		return false
	
	# if we're NOT on mobile ...
	else:
		# if EASY MODE is turned off ...
		if Global.get_mode() == false:
			# we don't get to undo last move, so return false
			return false
		
		# otherwise, show screen 
		else:
			instruc_label.set_text("(undo your last move)\n(you can turn off 'easy mode' in the Settings)")
			
			show_screen_elements()
			return true

func show_screen_elements():
	# make our screen visible
	$AnimationPlayer.play("AdScreen Fade")
	
	# but hide the other buttons, for clarity
	get_node("../GUI/Menu").hide()
	get_node("../GUI/Retry2").hide()
	get_node("../GUI/Undo").hide()
	
	# put focus on the BIG undo button
	$VBoxContainer/CenterContainer/TextureButton.grab_focus()
	
	enabled = true

func hide_screen_elements():
	# hide the ad screen again ("show the game")
	$AnimationPlayer.play_backwards("AdScreen Fade")
	
	# and show the other buttons again
	get_node("../GUI/Menu").show()
	get_node("../GUI/Retry2").show()
	
	# only show undo button if we're in easy mode
	if Global.get_mode():
		get_node("../GUI/Undo").show()
	
	# put focus on (general) restart button
	get_node("../GUI/Retry2").grab_focus()
	
	enabled = false

func hide_screen():
	hide_screen_elements()
	
	# un-pause the game
	get_tree().paused = false


func _on_Close_pressed():
	# hide the ad screen
	hide_screen()
	
	# remember we don't want to immediately see an ad again
	get_node("/root/Node2D").just_watched_ad = true
	
	# resume the game (allow it to end, with previous parameters still intact)
	if previous_settings.size() > 0:
		get_node("/root/Node2D").end_level(false, previous_settings[0], previous_settings[1])
	else:
		print("ERROR! Tried to end level, but no previous settings available.")

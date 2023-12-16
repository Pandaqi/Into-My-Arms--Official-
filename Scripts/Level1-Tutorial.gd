extends Node2D

func _ready():
	# Special case: on mobile, the second instruction text should be repositioned
	# Looks better, makes sure it's visible
	if Global.get_device() == "Android":
		# get_node("Instructions-Rule2").margin_top = get_node("Instructions-Rule1").margin_top
		
		# If we're on mobile, we DON't want to see the keyboard controls!
		get_node("Player1ControlInstructions").queue_free()
		get_node("Player2ControlInstructions").queue_free()
	else:
		# If we're on keyboard, we DON'T want the control hints in this level, as it's a tutorial
		get_node("/root/Node2D/GUI/Player1ControlsKeyboard").hide()
		get_node("/root/Node2D/GUI/Player2ControlsKeyboard").hide()

extends CanvasLayer

onready var players = get_tree().get_nodes_in_group("Players")

func _ready():
	# if players are in the wrong order, switch them around
	if players[0].PLAYER_NUM == 1:
		players.invert()
	
	###
	# Here we turn certain tutorial/interface parts on/off
	# based on the PLATFORM/OS on which the game is running
	###
	# We ONLY want to see the mobile controls on actual mobile screens
	if Global.get_device() != "Android":
		$Player1Controls.queue_free()
		$Player2Controls.queue_free()
	else:
		$Player1ControlsKeyboard.queue_free()
		$Player2ControlsKeyboard.queue_free()

###
# Button signals for player 1 (rotate and move)
###
func _on_Left1_pressed():
	players[0].rotate(-1)

func _on_Forward1_pressed():
	players[0].move_forward(1)

func _on_Reverse1_pressed():
	players[0].move_forward(-1)

func _on_Right1_pressed():
	players[0].rotate(1)

###
# Button signals for player 2 (rotate and move)
###
func _on_Left2_pressed():
	players[1].rotate(-1)

func _on_Forward2_pressed():
	players[1].move_forward(1)

func _on_Reverse2_pressed():
	players[1].move_forward(-1)

func _on_Right2_pressed():
	players[1].rotate(1)


func _on_Undo_pressed():
	get_node("/root/Node2D/UndoManager").undo_last_move()

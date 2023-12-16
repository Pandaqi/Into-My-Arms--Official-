extends Control

func _ready():
	get_tree().paused = false
	
	# if a skip node is available, display text that tells user how he can skip this animation
	if has_node("MarginContainer/VBoxContainer/Skip"):
		var skip_node = get_node("MarginContainer/VBoxContainer/Skip")
		if Global.get_device() == "Android":
			skip_node.set_text("Touch screen to skip intro (43 seconds)")
		else:
			skip_node.set_text("Press any key to skip intro (43 seconds)")

func stop_audio():
	GlobalBackgroundAudio.stop()

func next_scene():
	GlobalBackgroundAudio.play()
	get_tree().change_scene("res://Levels/Level0.tscn")

func back_to_main():
	GlobalBackgroundAudio.play()
	get_tree().change_scene("res://MainMenu.tscn")

func _input(ev):
	if ev is InputEventKey or ev is InputEventScreenTouch:
		next_scene()

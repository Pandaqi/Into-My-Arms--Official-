extends Node2D

var sight_path = null

func create_line_of_sight(sight_path):
	self.sight_path = sight_path
	
	update()

func _draw():
	if sight_path != null and sight_path.size() > 2:
		
		# convert pseudo-3D vectors to 2D positions on screen
		for i in range(sight_path.size()):
			var p = sight_path[i]
			var screen_pos = Vector2((p.x - p.y)*64, (p.x + p.y)*32)
			var screen_offset = Vector2(0, 32)
			
			sight_path[i] = screen_pos + screen_offset
		
		# draw the whole sight path
		draw_polyline( sight_path, Color(255,0,0,0.5), 10)

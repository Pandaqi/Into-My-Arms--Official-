tool
extends TextureButton

export (Vector2) var scale = Vector2(56, 56) setget scale_changed
export (int) var frame = 0 setget frame_changed
export (bool) var particles_enabled = true setget particles_changed

export (String) var custom_anchor = 'none'
export (float) var anchor_offset = 0

var modulate_values = [null, null, null, null, 
					   Color(1.0, 0.0, 0.0), Color(0.0, 1.0, 0.0), Color(0.5, 0.5, 0.5), Color(230/255.0, 100/255.0, 14/255.0),
					   Color(110.0 / 255, 1.0, 0.0), Color(134/255.0, 134/255.0, 134/255.0), Color(1.0, 71/255.0, 71/255.0), null,
					   Color(180.0 / 255, 180.0 / 255,0.0), null, null, null]

var base_modulate = Color(1.0, 1.0, 1.0)
var cur_state = ''

func on_resize(val):
	scale_changed(val)
	anchor_changed(val)
	
	# hide the keyboard hint ("which key belongs to this button")
	# if it's on mobile OR the button is positioned non-standard
	if Global.get_device() == "Android" or custom_anchor != 'none':
		$KeyboardHint.hide()
	
	if not particles_enabled:
		$Particles.hide()
		$Particles.set_emitting(false)

func anchor_changed(val):
	if custom_anchor == 'none':
		return
	
	var margin = round( rect_min_size.x * 0.1 )
	var offset = anchor_offset * (rect_min_size.x + margin*2)
	var vp = get_viewport().size
	if custom_anchor == 'top_left':
		self.rect_position = Vector2( margin + offset, margin )
	elif custom_anchor == 'top_right':
		self.rect_position = Vector2( vp.x - margin - self.rect_min_size.x - offset, margin )

func particles_changed(v):
	particles_enabled = v
	
	if v:
		$Particles.show()
		$Particles.set_emitting(true)
	else:
		$Particles.hide()
		$Particles.set_emitting(false)

func scale_changed(v):
	if not has_node("Sprite"):
		return
	
	scale = v
	
	# update scale of texture button
	self.rect_min_size = scale
	
	# update scale of sprite
	$Sprite.set_scale(Vector2(scale.x / 56 / 4, scale.y / 56 / 4))
	$Sprite.set_position(Vector2(scale.x * 0.5, scale.y * 0.5))
	
	# update scale (and other settings) on the particles
	$Particles.emission_rect_extents = Vector2(scale.x / 4, 1)
	$Particles.lifetime = 4
	$Particles.set_position( Vector2(scale.x*0.5, scale.y*0.9))
	$Particles.scale_amount = scale.x / 56 / 4
	$Particles.initial_velocity = scale.y * 0.5
	
	# update scale of keyboard hint
	$KeyboardHint.set_scale(Vector2(scale.x / 56 / 4, scale.y / 56 / 4))

func frame_changed(v):
	if not has_node("Sprite"):
		return
	
	frame = v
	
	$Sprite.frame = frame
	$KeyboardHint.frame = frame
	
	# RESTART button has the hint to the side
	# UNDO button also has hint to the side
	# otherwise it doesn't always fit on the screen
	if frame == 6 or frame == 12:
		$KeyboardHint.offset = Vector2(188, -32)
	
	var new_mod = modulate_values[frame]
	if new_mod != null:
		$Sprite.modulate = new_mod
		$KeyboardHint.modulate = new_mod
		base_modulate = new_mod

func change_state(new_state):
	if cur_state == 'click' and new_state == 'hover':
		new_state = 'default'
	
	match new_state:
		'default':
			$Sprite.modulate.a = 0.8
			$Sprite.modulate = base_modulate
			play_sound(null)
			
		'hover':
			$Sprite.modulate.a = 1.0
			$Sprite.modulate = base_modulate.lightened(0.5)
			
			# if we come from the click state, we don't want the sound playing twice
			if cur_state != 'click': 
				play_sound('click')
				

		'click':
			$Sprite.modulate.a = 1.0
			$Sprite.modulate = base_modulate.darkened(0.5)
			play_sound('click')
	
	cur_state = new_state
	
	var cur_frame = $Sprite.frame
	var rotation = 0
	
	if new_state != 'default':
		rotation = 2*PI
		match cur_frame:
			4:
				rotation = 0.15*PI
			
			5:
				rotation = -0.15*PI
			
			7:
				rotation = 0
			
			8:
				rotation = 0.15*PI
	
	$Tween.interpolate_property($Sprite, "rotation",
								null, rotation, 
								0.2, Tween.TRANS_LINEAR, Tween.TRANS_LINEAR)
	
	$Tween.start()

# Called when the node enters the scene tree for the first time.
func _ready():
	change_state('default')

func play_sound(path):
	if not Global.has_method("get_soundfx_level"):
		return
	
	# mobile controls don't get sound effects (unnecessary and annoying)
	if frame in [0,1,2,3]:
		return
	
	# mobile sound effects are a bit too strong,
	# so I reduce volume
	$AudioStreamPlayer.volume_db = Global.get_soundfx_level()
	
	if path == 'click':
		$AudioStreamPlayer.volume_db -= 12
	
	# don't play if something is already playing
	# or if the button is disabled
	# (mainly to prevent duplicate sounds)
	if $AudioStreamPlayer.playing or self.disabled:
		return
	
	# if path = null, it means I want the thing to stop
	if path == null:
		$AudioStreamPlayer.playing = false
		return
	
	# otherwise, play the sound at specified path
	$AudioStreamPlayer.stream = load("res://Sound/" + str(path) + ".ogg")
	$AudioStreamPlayer.pitch_scale = rand_range(0.95,1.05)
	$AudioStreamPlayer.playing = true

func _on_TextureButton_mouse_entered():
	change_state('hover')

func _on_TextureButton_button_down():
	change_state('click')

func _on_TextureButton_button_up():
	change_state('hover')

func _on_TextureButton_mouse_exited():
	change_state('default')


func _on_TextureButton_focus_entered():
	# grey modulation doesn't look good otherwise
	if frame == 6 or frame == 9:
		$Sprite/ButtonFocus.modulate = Color(0.2, 0.2, 1.0)
	$Sprite/ButtonFocus.show()


func _on_TextureButton_focus_exited():
	$Sprite/ButtonFocus.hide()

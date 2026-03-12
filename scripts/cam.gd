extends Camera2D
	
var paddingY = 96;
@onready var character_body = $"../CharacterBody2D"
	
func _process(delta: float) -> void:
	update_cam(delta)
	
func update_cam(delta):
	var easing: float = 7.0 # higher = faster response
	
	var upper_limit = character_body.position.y + paddingY
	var lower_limit = character_body.position.y - paddingY
	
	if Global.camera_y_lock == 0:
		if position.y > upper_limit:
			position.y = lerp(position.y, upper_limit, easing * delta)
		elif position.y < lower_limit:
			position.y = lerp(position.y, lower_limit, easing * delta)
	else:
		position.y = lerp(position.y, Global.camera_y_lock+124, easing * delta)
		
	if position.x < character_body.position.x:
		position.x = character_body.position.x

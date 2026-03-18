extends Camera2D
	
var paddingY = 96;

func _process(delta: float) -> void:
	update_cam(delta)
	
func update_cam(delta):
	var easing: float = 7.0 # higher = faster response
	
	var upper_limit = Global.player.position.y + paddingY
	var lower_limit = Global.player.position.y - paddingY
	
	if Global.camera_y_lock == null:
		if position.y > upper_limit:
			position.y = lerp(position.y, upper_limit, easing * delta)
		elif position.y < lower_limit:
			position.y = lerp(position.y, lower_limit, easing * delta)
	else:
		position.y = lerp(position.y, Global.camera_y_lock+324.0, easing * delta)
		
	if position.x < Global.player.position.x+Global.player.center.x:
		position.x = Global.player.position.x+Global.player.center.x

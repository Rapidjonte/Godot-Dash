extends Node2D

func _ready() -> void:
	Global.reset()
	$attempts.text = "Attempt " + str(Global.attempt)
	load_level()

func _process(delta: float) -> void:
	queue_redraw()
	if not Global.paused:
		var progress = Global.player.position.x / Global.endX
		progress = min(max(progress, 0),1)
		$cam/Control/Panel/ProgressBar.value = progress*100
		$cam/Control/percent.text = str(floor(progress*10000)/100) + "%"
		if progress >= 1:
			complete()

	if Global.border_blocks != 0:
		#bottom
		var target = 324.0 - 64 * Global.border_blocks
		var easing = 15
		for child in $borders/g.get_children():
			child.position.y = lerp(child.position.y, target, easing * delta)
		target = 449.62 - 64 * Global.border_blocks
		$borders/line/Line.position.y = lerp($borders/line/Line.position.y , target, easing * delta)
		
		#top
		target = 1020.0 - 64 * Global.border_blocks
		for child in $borders/g2.get_children():
			child.position.y = lerp(child.position.y, target, easing * delta)
		target = 22.0 - 64 * Global.border_blocks
		$borders/line2/Line.position.y = lerp($borders/line2/Line.position.y , target, easing * delta)
		
func load_level():
	var instance = Global.level.instantiate()
	instance.position.y = Global.levelOffset
	add_child(instance)
	Global.paused = false

func complete():
	Global.paused = true
	$CharacterBody2D/CPUParticles2D.emitting = true
	$CharacterBody2D/sprite.visible = false

func _draw():
	for circle in Global.circles:
		circle[1] += get_process_delta_time()*400
		var targetRad = 130
		var percent = circle[1]/targetRad
		draw_arc(circle[0], circle[1], 0, TAU, 28, Color(1, 1, 1, 0.5-percent*0.5), 2)
		if circle[1] > targetRad:
			Global.circles.remove_at(Global.circles.find(circle))

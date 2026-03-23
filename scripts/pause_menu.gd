extends Control

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position = $"../cam".position
	if Input.is_action_just_pressed("exit"):
		if not is_inside_tree():
			return
			
		if $CanvasLayer.visible:
			exit()
		else:
			$CanvasLayer.visible = !$CanvasLayer.visible
			get_tree().paused = !get_tree().paused
		
func exit():
	_on_button_pressed()
	if Global.entered_from_editor:
		get_tree().change_scene_to_file("res://scenes/editor.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

# resume
func _on_button_pressed() -> void:
	$CanvasLayer.visible = false
	get_tree().paused = false

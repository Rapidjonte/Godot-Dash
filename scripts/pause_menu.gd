extends Control

var loadedIndex = 0
func _ready() -> void:
	$CanvasLayer.visible = false
	$CanvasLayer/percent.text = str("%0.2f" % 0,"%")
	
	if Global.entered_from_editor:
		return
	
	for row in Global.loaded_data:
		if row["id"] == Global.loadedID:
			break
		loadedIndex += 1

	if !Global.loaded_data[loadedIndex].keys().has("best"):
		Global.loaded_data[loadedIndex]["best"] = 0.0

func check_for_progress():
	if Global.entered_from_editor or Global.practice_mode:
		return
	if $"..".progress*100 > Global.loaded_data[loadedIndex]["best"]:
		Global.loaded_data[loadedIndex]["best"] = $"..".progress*100

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position = $"../cam".position

	if Input.is_action_just_pressed("exit"):
		if not is_inside_tree():
			return
			
		if $CanvasLayer.visible:
			exit()
		else:
			if !Global.entered_from_editor:
				$CanvasLayer/percent.text = str("%0.2f" % (Global.loaded_data[loadedIndex]["best"]),"%")
				$CanvasLayer/TextureProgressBar.value = Global.loaded_data[loadedIndex]["best"]
				$CanvasLayer/title.text = Global.loaded_data[loadedIndex]["title"]
				$CanvasLayer/creator.text = "By " + Global.loaded_data[loadedIndex]["creator"]
			else:
				$CanvasLayer/percent.text = "0.00%"
				$CanvasLayer/TextureProgressBar.value = 0
				$CanvasLayer/title.text = "Local Level"
				$CanvasLayer/creator.text = "By You"
			$CanvasLayer.visible = !$CanvasLayer.visible
			get_tree().paused = !get_tree().paused
	elif Input.is_key_pressed(KEY_SPACE) and $CanvasLayer.visible:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE

		InputMap.action_erase_event("jump", event)
		_on_button_pressed()
		InputMap.action_add_event("jump", event)
		
func exit():
	Global.practice_mode = false
	Global.checkpoints.clear()
	_on_button_pressed()
	if not is_inside_tree():
		return
	if Global.entered_from_editor:
		get_tree().change_scene_to_file("res://scenes/editor.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

# resume
func _on_button_pressed() -> void:
	if not is_inside_tree():
		return
	$CanvasLayer.visible = false
	get_tree().paused = false

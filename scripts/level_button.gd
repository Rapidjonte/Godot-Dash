extends Control

var data : Dictionary

func _ready() -> void:
	visible = false
	$TextureRect.modulate = Color.html(data["color"])
	await set_label_text($title, data["title"], 46)
	await set_label_text($creator, "By " + data["creator"], 33)
	$diff.texture = load("res://images/ui/" + data["difficulty"] + ".png")
	visible = true

func set_label_text(label: Label, text: String, base_size: int):
	label.text = text
	label.label_settings.font_size = base_size
	
	await label.get_tree().process_frame  # wait for layout
	
	var min_size = 12
	var size = base_size
	
	while label.get_line_count() > 1 and size > min_size:
		size -= 1
		label.label_settings.font_size = size
		await label.get_tree().process_frame

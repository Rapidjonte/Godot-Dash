extends Control

var dragging := false
var drag_start := Vector2()
var scroll_start := Vector2()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = event.position
				scroll_start = Vector2(
					get_parent().scroll_horizontal,
					get_parent().scroll_vertical
				)
			else:
				dragging = false

	elif event is InputEventMouseMotion and dragging:
		var delta = event.position - drag_start
		get_parent().scroll_horizontal = scroll_start.x - delta.x
		get_parent().scroll_vertical = scroll_start.y - delta.y

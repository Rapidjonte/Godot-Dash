extends TextureButton

@onready var player := $AnimationPlayer
var mouse_on = false

func _on_mouse_entered() -> void:
	mouse_on = true

func _on_mouse_exited() -> void:
	mouse_on = false

func _on_button_down() -> void:
	if mouse_on:
		player.play("hover")

func _on_button_up() -> void:
	player.play("unhover")
	if mouse_on:
		activate()

func activate():
	pass

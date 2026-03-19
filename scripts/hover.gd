extends TextureButton

@onready var player := $AnimationPlayer

func _on_mouse_entered() -> void:
	player.play("hover")

func _on_mouse_exited() -> void:
	player.play("unhover")
	

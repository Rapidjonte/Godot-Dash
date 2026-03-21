extends TextureRect

func _ready() -> void:
	if !Global.paused and Global.player.position.x < position.x-32:
		Global.player.position = Vector2(position.x-32,position.y+Global.levelOffset)

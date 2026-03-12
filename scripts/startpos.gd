extends TextureRect

func _ready() -> void:
	var character_body = get_node("../../CharacterBody2D")
	if character_body.position.x < position.x-32:
		character_body.position = Vector2(position.x-32,position.y+Global.levelOffset)

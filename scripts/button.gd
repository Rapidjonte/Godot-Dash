extends Button

@export var levelPath: String

var game = load("res://scenes/game.tscn")

func _on_pressed() -> void:
	Global.load_level(levelPath)
	get_tree().change_scene_to_packed(game)

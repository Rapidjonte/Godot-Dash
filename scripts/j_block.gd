extends Area2D

func _ready() -> void:
	if !Global.paused:
		visible = false

func _on_body_entered(body: Node2D) -> void:
	if body == Global.player:
		Input.action_release("jump")

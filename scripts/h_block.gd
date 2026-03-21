extends Area2D

func _ready() -> void:
	if !Global.paused:
		visible = false

func _on_body_entered(body: Node2D) -> void:
	if (Global.player.gamemode.contains("cube") or Global.player.gamemode.contains("robot")) and body == Global.player:
		Global.two_faced_blocks = true

func _on_body_exited(body: Node2D) -> void:
	if (Global.player.gamemode.contains("cube") or Global.player.gamemode.contains("robot")) and body == Global.player:
		Global.two_faced_blocks = false

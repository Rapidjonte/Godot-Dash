extends Area2D

func _ready() -> void:
	if !Global.paused:
		visible = false
		
var me_controlling = false

func _on_body_entered(body: Node2D) -> void:
	if (Global.player.gamemode.contains("cube") or Global.player.gamemode.contains("robot")) and body == Global.player and !Global.two_faced_blocks:
		Global.two_faced_blocks = true
		me_controlling = true

func _on_body_exited(body: Node2D) -> void:
	if (Global.player.gamemode.contains("cube") or Global.player.gamemode.contains("robot")) and body == Global.player and (!Global.two_faced_blocks or me_controlling):
		Global.two_faced_blocks = false
		me_controlling = false

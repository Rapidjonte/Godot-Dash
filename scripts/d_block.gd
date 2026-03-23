extends Area2D

func _ready() -> void:
	if !Global.paused:
		visible = false

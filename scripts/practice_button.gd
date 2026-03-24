extends "res://scripts/hover.gd"

@onready var enter_practice = load("res://images/ui/GJ_practiceBtn_001.png")
@onready var exit_practice = load("res://images/ui/GJ_normalBtn_001.png")

func _ready():
	super._ready() 
	if Global.practice_mode:
		texture_normal = exit_practice
	else:
		texture_normal = enter_practice
	
func activate():
	$"../.."._on_button_pressed()
	Global.checkpoints.clear()
	if !Global.practice_mode:
		texture_normal = exit_practice
		Global.practice_mode = true
	else:
		texture_normal = enter_practice
		Global.practice_mode = false
		if Global.player:
			Global.player.die(true)

extends "res://scripts/hover.gd"

func activate():
	get_tree().change_scene_to_file("res://scenes/editor.tscn")

func _ready():
	super._ready() 

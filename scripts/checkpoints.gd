extends Node2D

@onready var checkpoint_scene = load("res://scenes/checkpoint.tscn")

func _ready() -> void:
	if Global.checkpoints.size() > 0:
		pass #load checkpoint

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !Global.practice_mode or Global.paused:
		return
	if Input.is_action_just_pressed("place_checkpoint"):
		var checkpoint = checkpoint_scene.instantiate()
		checkpoint.position = Global.player.global_position+Global.player.center
		add_child(checkpoint)
	
		var packed_scene = PackedScene.new()
		var result = packed_scene.pack(get_tree().current_scene)
		if result == OK:
			packed_scene = Global.checkpoints.size()
			Global.checkpoints.push_front(packed_scene)
		else:
			print("Pack failed:", result)
	elif Input.is_action_just_pressed("remove_checkpoint"):
		Global.checkpoints.remove_at(Global.checkpoints.size()-1)
		remove_child(get_children().back())

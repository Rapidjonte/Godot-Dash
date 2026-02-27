extends Node2D

func _ready() -> void:
	Global.attempt += 1
	$attempts.text = "Attempt " + str(Global.attempt)
	
	load_level("res://levels/level.tscn")

func _process(delta: float) -> void:
	if not Global.paused:
		var progress = $CharacterBody2D.position.x / Global.endX
		$cam/Control/ProgressBar.value = progress*100
		if progress >= 1:
			complete()

var level_scene : PackedScene
var instance : Node

func load_level(path: String):
	level_scene = load(path)
	instance = level_scene.instantiate()
	instance.position.y = 384
	add_child(instance)
	Global.paused = false
	Global.calculate_end(instance)


func complete():
	Global.paused = true
	$CharacterBody2D/CPUParticles2D.emitting = true
	$CharacterBody2D/sprite.visible = false

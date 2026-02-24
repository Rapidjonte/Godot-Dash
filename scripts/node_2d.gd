extends Node2D

# save here later
var endX = 7700

func _ready() -> void:
	Global.attempt += 1
	$attempts.text = "Attempt " + str(Global.attempt)

func _process(delta: float) -> void:
	var progress = $CharacterBody2D.position.x / endX
	$cam/Control/ProgressBar.value = progress*100
	if progress >= 1:
		complete()
	
func complete():
	pass

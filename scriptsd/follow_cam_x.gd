extends RigidBody2D

@export var offset: float

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x = $"../cam".position.x + $"../cam".offset.x - offset

extends Area2D

@export var boostStrength: float

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CollisionShape2D.disabled = false

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if Global.player == body:
		Global.player.quick_jump_disable = true
		Global.player.velocity.y = 0
		Global.player.flip()
		
		$CollisionShape2D.set_deferred("disabled", true)
		Global.player.velocity.y += boostStrength*(Global.player.gravity/abs(Global.player.gravity))
		var circle = circle_scene.instantiate()
		circle.position.y+=28.0
		$GPUParticles2D.add_child(circle)

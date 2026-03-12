extends Area2D

var character_body
@export var boostStrength: float

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	character_body = get_node("../../CharacterBody2D")
	$CollisionShape2D.disabled = false

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if character_body == body:
		$CollisionShape2D.set_deferred("disabled", true)
		character_body.velocity.y = -boostStrength*(character_body.gravity/abs(character_body.gravity))
		var circle = circle_scene.instantiate()
		circle.position.y+=28.0
		$GPUParticles2D.add_child(circle)

extends CollisionShape2D

var character_body
@export var multiplier: int
@export var force: bool

func _ready():
	character_body = get_node("../../../CharacterBody2D")
	disabled = false

func _on_grav_portal_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body == character_body:
		var prevGrav = character_body.gravity
		
		set_deferred("disabled", true)
		if force:
			character_body.gravity = abs(character_body.gravity) * multiplier
		else:
			character_body.gravity *= multiplier
			
		if prevGrav != character_body.gravity:
			Global.flip_blocks.emit()
			character_body.spinSpeed *= -1
			character_body.velocity.y += character_body.gravity * get_process_delta_time() * 0.1
			character_body.velocity.y *= 0.6
			character_body.up_direction.y *= -1
			character_body.jumpStrength *= -1

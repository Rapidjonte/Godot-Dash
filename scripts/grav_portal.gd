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
		
		disabled = true
		if force:
			character_body.gravity = abs(character_body.gravity) * multiplier
			character_body.spinSpeed = abs(character_body.spinSpeed) * multiplier
		else:
			character_body.gravity *= multiplier
			character_body.spinSpeed *= multiplier
		
		if prevGrav != character_body.gravity:
			character_body.velocity.y += character_body.gravity * get_process_delta_time() * 0.1
			character_body.velocity.y *= 0.6

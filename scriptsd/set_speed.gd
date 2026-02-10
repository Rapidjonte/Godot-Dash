extends CollisionShape2D

var character_body
@export var targetSpeed: float


func _ready():
	character_body = get_node("../../../CharacterBody2D")
	disabled = false

func _on_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	print("speed_changed")
	disabled = true
	character_body.speed = targetSpeed

extends CollisionShape2D

var character_body

func _ready():
	character_body = get_node("../../../CharacterBody2D")
	rotation = -$"..".rotation


func _process(delta: float) -> void:
	if character_body.velocity.y >= 0:
		one_way_collision_margin = 24
	else:
		one_way_collision_margin = 1
		

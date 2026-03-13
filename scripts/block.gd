extends CollisionShape2D

var character_body : CharacterBody2D

func _ready():
	character_body = get_node("../../../CharacterBody2D")
	rotation = -$"..".rotation
	Global.flip_blocks.connect(flip_self)
	
func _process(delta: float) -> void:
	if character_body.gravity * character_body.velocity.y >= -0.0001:
		set_deferred("one_way_collision_margin", 32)
	else:
		set_deferred("one_way_collision_margin", 1)

func flip_self():
	rotation += deg_to_rad(180)

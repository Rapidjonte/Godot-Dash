extends CollisionShape2D

func _ready():
	Global.player = get_node("../../../CharacterBody2D")
	rotation = -$"..".rotation
	Global.flip_blocks.connect(flip_self)
	
func _process(delta: float) -> void:
	if Global.player.gravity * Global.player.velocity.y >= -0.0001:
		set_deferred("one_way_collision_margin", 32)
	else:
		set_deferred("one_way_collision_margin", 1)

func flip_self():
	rotation += deg_to_rad(180)

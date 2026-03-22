extends CollisionShape2D

@onready var otherside = $"../block/CollisionShape2D"

func _ready():
	if !Global.paused:
		rotation = -$"..".rotation
		otherside.rotation = rotation + deg_to_rad(180)
		if !Global.two_faced_blocks:
			otherside.disabled = true
		Global.flip_blocks.connect(flip_self)
		#$"..".body_entered.connect(Global.player._on_area_2d_body_entered)
		#$"../block".body_entered.connect(Global.player._on_area_2d_body_entered)
	
func _physics_process(delta: float) -> void:
	print(get_parent().process_mode )
	if get_parent().process_mode == Node.PROCESS_MODE_PAUSABLE:
		disabled = true
		otherside.disabled = true
		return
		
	if Global.two_faced_blocks:
		if sign(Global.player.gravity) * Global.player.velocity.y > 0:
			disabled = false
		else:
			disabled = true

		otherside.disabled = !disabled
	else:
		disabled = false
		otherside.disabled = true
		if Global.player.gravity * Global.player.velocity.y >= -0.0001:
			set_deferred("one_way_collision_margin", 32)
		else:
			set_deferred("one_way_collision_margin", 1)

func flip_self():
	rotation += deg_to_rad(180)
	otherside.rotation = rotation + deg_to_rad(180)

extends CharacterBody2D

var time = 0;

const HALF_SPEED = 8.4
const NORMAL_SPEED = 10.41667
const DOUBLE_SPEED = 12.91667
const TRIPLE_SPEED = 15.667
const QUADRUPLE_SPEED = 19.2

@export var jumpStrength: float
@export var gravity: float
@export var spinSpeed: float

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time += delta
	position.x = 64 * time * 10.41667
	if not is_on_floor():
		velocity.y += gravity * delta
		$sprite.rotation += spinSpeed * delta
	else:
		var target = deg_to_rad(round(rad_to_deg($sprite.rotation) / 90.0) * 90.0)
		$sprite.rotation = lerp_angle($sprite.rotation, target, 30.0 * delta)

	if $"../cam".position.x < position.x:
		$"../cam".position.x = position.x
	
	if Input.is_action_just_pressed("reset"):
		die()
	
	if Input.is_action_pressed("jump") and (is_on_floor() and velocity.y >= 0):
		print("jumped")
		velocity.y -= jumpStrength
	
	move_and_slide()
	collision_check()

func collision_check():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		print("I collided with ", collision.get_collider().name)
		if collision.get_collider().name.contains("spike"):
			die()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name.contains("block"):
		die()

func die():
	var tree = get_tree()
	if tree != null:
		tree.reload_current_scene()

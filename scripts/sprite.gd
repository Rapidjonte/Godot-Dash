extends CharacterBody2D

var paddingY = 70;

const NORMAL_SPEED = 10.41667
var speed = NORMAL_SPEED

const HALF_SPEED = 8.4
const DOUBLE_SPEED = 12.91667
const TRIPLE_SPEED = 15.667
const QUADRUPLE_SPEED = 19.2

@export var startPos: Vector2

@export var jumpStrength: float
@export var gravity: float
@export var max_velocity: float
@export var spinSpeed: float

@onready var sprite = $sprite
@onready var cam = $"../cam"

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		die(true)
	if Input.is_action_just_pressed("exit"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:	
	if !Global.paused:
		position.x += 64 * delta * speed
		if not is_on_floor():
			velocity.y += gravity * delta
			sprite.rotation += spinSpeed * delta
			if velocity.y > max_velocity:
				velocity.y = max_velocity
			if velocity.y < -max_velocity:
				velocity.y = -max_velocity
		else:
			var target = deg_to_rad(round(rad_to_deg(sprite.rotation) / 90.0) * 90.0)
			sprite.rotation = lerp_angle(sprite.rotation, target, 30.0 * delta)	
		
		if Input.is_action_pressed("jump") and (is_on_floor() and velocity.y >= 0):
			velocity.y -= jumpStrength
		
		move_and_slide()
		collision_check()
		
	update_cam(delta)
	
func update_cam(delta):
	var easing: float = 7.0 # higher = faster response
	
	var upper_limit = position.y + paddingY
	var lower_limit = position.y - paddingY
	
	if cam.position.y > upper_limit:
		cam.position.y = lerp(cam.position.y, upper_limit, easing * delta)
	elif cam.position.y < lower_limit:
		cam.position.y = lerp(cam.position.y, lower_limit, easing * delta)
		
	if cam.position.x < position.x:
		cam.position.x = position.x

func collision_check():
	if Global.paused:
		return
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().name.contains("spike"):
			die()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if Global.paused:
		return
	if body.name.contains("block"):
		die()

func die(instant: bool = false):
	Global.paused = true
	
	if not instant:
		# enable hitboxess
		await get_tree().create_timer(1).timeout
		# disable hitboxes
	
	get_tree().reload_current_scene.call_deferred()

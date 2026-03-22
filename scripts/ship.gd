extends CharacterBody2D

var speed : float = Global.NORMAL_SPEED
@export var gamemode : String

@export var jumpStrength : float
@export var gravity : float
@export var max_velocity : float
@export var spinSpeed : float

@onready var sprite = $sprite
var startUpsideDown = false
@export var center : Vector2

var grounded := false
var excessiveForce = 0
var maxExcessive = 0

var quick_jump_disable = false

func _ready() -> void:
	if startUpsideDown:
		flip(true)

var dying = false
var respawnTimer = 0
var respawnTime = Global.respawn_time
func _process(delta: float) -> void:
	if dying:
		if respawnTimer <= respawnTime:
			respawnTimer += delta
		else:
			die(true)
	if Input.is_action_just_pressed("reset"):
		die(true)
	if Input.is_action_just_pressed("exit"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:	
	if !Global.paused:
		Global.bufferable = false
		position.x += 64 * delta * speed
		if not is_on_floor():
			grounded = false
			velocity.y += gravity * delta

			if excessiveForce > maxExcessive:
				excessiveForce= maxExcessive
			if excessiveForce < -maxExcessive:
				excessiveForce = -maxExcessive
				
			velocity.y += excessiveForce
			excessiveForce = velocity.y
			
			if velocity.y > max_velocity:
				velocity.y = max_velocity
			if velocity.y < -max_velocity:
				velocity.y = -max_velocity
				
			excessiveForce -= velocity.y
		else:
			excessiveForce = 0
			grounded = true
		
		if Input.is_action_just_pressed("jump"):
			Global.bufferable = true
			
		if Input.is_action_pressed("jump"):
			velocity.y -= jumpStrength
		elif Input.is_action_just_released("jump"):
			excessiveForce = 0
		
		if !grounded:
			var target_rot = clamp(velocity.y / max_velocity, -1.0, 1.0) * deg_to_rad(54)
			sprite.rotation = lerp_angle(sprite.rotation, target_rot, spinSpeed * delta)
		else:
			sprite.rotation = lerp_angle(sprite.rotation, 0, spinSpeed * delta)

		$Area2D2/spinbox.rotation = $sprite.rotation

		move_and_slide()
		collision_check()
	
	quick_jump_disable = false

func collision_check():
	if Global.paused:
		return
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var colliderName = collision.get_collider().name
		if colliderName.contains("spike") or colliderName.contains("saw") :
			die()

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if Global.paused:
		return
	if body.name.contains("spike") and !Global.is_divisible_by_90(rad_to_deg(body.rotation)) :
		die()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if Global.paused:
		return
	if body.name.contains("block") or body.name.contains("ground"):
		die()

func die(instant: bool = false):
	Global.paused = true
	
	if not instant:
		dying = true
	
	get_tree().reload_current_scene()

func spidered():
	pass

func flip(skip_flip : bool = false):
	if !skip_flip:
		Global.flip_blocks.emit()
	gravity *= -1
	velocity.y += gravity * get_process_delta_time() * 0.1
	up_direction.y *= -1
	jumpStrength *= -1
	excessiveForce = 0
	sprite.scale.y *= -1

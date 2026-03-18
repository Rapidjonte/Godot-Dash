extends CharacterBody2D

var speed : float = Global.NORMAL_SPEED
var gamemode = "cube"

@export var jumpStrength : float
@export var gravity : float
@export var max_velocity : float
@export var spinSpeed : float

@onready var sprite = $sprite
var startUpsideDown = false
var center = Vector2(32,32)

var grounded := false
var excessiveForce = 0
var maxExcessive = 160

var quick_jump_disable = false

func _ready() -> void:
	Global.player = self
	$friction.emitting = false
	
	var _material = $friction.process_material
	$friction.position.y = 60
	_material.direction = Vector3(12.125,-98.5,0)
	_material.gravity = Vector3(0,422.335,0)
	
	if startUpsideDown:
		flip(true)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		die(true)
	if Input.is_action_just_pressed("exit"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:	
	if !Global.paused:
		$Area2D2/spinbox.rotation = $sprite.rotation
		position.x += 64 * delta * speed
		if not is_on_floor():
			$friction.emitting = false
			grounded = false
			velocity.y += gravity * delta
			sprite.rotation += spinSpeed * delta
			
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
			$friction.emitting = true
			grounded = true
			var target = deg_to_rad(round(rad_to_deg(sprite.rotation) / 90.0) * 90.0)
			sprite.rotation = lerp_angle(sprite.rotation, target, 30.0 * delta)	
		
		if Input.is_action_pressed("jump") and grounded and !quick_jump_disable:
			$friction.emitting = true
			Global.bufferable = false
			if velocity.y >= 0:
				velocity.y -= jumpStrength
		elif Input.is_action_just_released("jump"):
			Global.bufferable = true

		move_and_slide()
		collision_check()
	else:
		$friction.emitting = false
	
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
		# enable hitboxess
		await get_tree().create_timer(1).timeout
		# disable hitboxes
	
	get_tree().reload_current_scene.call_deferred()

func flip_ground_particle():
	var _material = $friction.process_material
	if $friction.position.y == 60:
		$friction.position.y = 3
		_material.direction = Vector3(12.125,98.5,0)
		_material.gravity = Vector3(0,-422.335,0)
	else:
		$friction.position.y = 60
		_material.direction = Vector3(12.125,-98.5,0)
		_material.gravity = Vector3(0,422.335,0)

func spidered():
	sprite.rotation = deg_to_rad(round(rad_to_deg(sprite.rotation) / 90.0) * 90.0)

func flip(skip_flip : bool = false):
	flip_ground_particle()
	if !skip_flip:
		Global.flip_blocks.emit()
	gravity *= -1
	spinSpeed *= -1
	velocity.y += gravity * get_process_delta_time() * 0.1
	up_direction.y *= -1
	jumpStrength *= -1
	excessiveForce = 0

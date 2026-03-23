extends CharacterBody2D

var speed : float = Global.NORMAL_SPEED
@export var gamemode : String

@export var jumpStrength : float
@export var max_velocity : float
@export var spinSpeed : float
@export var degrees : float
var gravity = 1

@onready var sprite = $sprite
var startUpsideDown = false
@export var center : Vector2

var grounded := false
var excessiveForce = 0
var maxExcessive = 0

var quick_jump_disable = false

func _ready() -> void:
	set_collision_mask_value(1, false) 
	set_collision_mask_value(2, true) 
	
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
		if not is_inside_tree():
			return
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:	
	if !Global.paused:
		Global.bufferable = false
		position.x += 64 * delta * speed
		
		if Input.is_action_just_pressed("jump"):
			Global.bufferable = true

		if Input.is_action_pressed("jump"):
			velocity.y -= jumpStrength
		else:
			velocity.y += jumpStrength
	
		if not is_on_floor():
			grounded = false
		else:
			if grounded == false:
				pass
				#emit ground particles
				
			grounded = true

		var speed_per_second = 64.0 * speed
		max_velocity = speed_per_second * tan(deg_to_rad(degrees))
		
		if velocity.y > max_velocity:
			velocity.y = max_velocity
		if velocity.y < -max_velocity:
			velocity.y = -max_velocity
			
		move_and_slide()
		collision_check()
		
		if !grounded:
			var target_rot = sign(velocity.y) * deg_to_rad(degrees)
			sprite.rotation = lerp_angle(sprite.rotation, target_rot, spinSpeed * delta)
		else:
			sprite.rotation = lerp_angle(sprite.rotation, 0, spinSpeed * delta)

		$Area2D2/spinbox.rotation = $sprite.rotation
	
	quick_jump_disable = false
	
	block = false

var block = false
var d_block = false
func collision_check():
	if Global.paused:
		return
	
	check_for_d()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var colliderName = collision.get_collider().name
		if colliderName.contains("spike") or colliderName.contains("saw") :
			die()
		elif colliderName.contains("block"):
			block = true
	
	if block and !d_block:
		die()
	elif d_block:
		set_collision_mask_value(1, true) 
		set_collision_mask_value(2, false) 
	else:
		set_collision_mask_value(1, false) 
		set_collision_mask_value(2, true) 

func check_for_d():
	for area in $Area2D2.get_overlapping_areas():
		if area.name.contains("d_block"):
			d_block = true
			return
	d_block = false

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if Global.paused:
		return
	if body.name.contains("spike") and !Global.is_divisible_by_90(rad_to_deg(body.rotation)) :
		die()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if Global.paused:
		return
	if body.name.contains("ground") or body.name.contains("block") :
		die()

func die(instant: bool = false):
	Global.paused = true
	
	if not instant:
		dying = true
		return
		
	if not is_inside_tree():
		return

	get_tree().reload_current_scene()

func spidered():
	pass

func flip(skip_flip : bool = false):
	if !skip_flip:
		Global.flip_blocks.emit()
	up_direction.y *= -1
	jumpStrength *= -1
	gravity *= -1

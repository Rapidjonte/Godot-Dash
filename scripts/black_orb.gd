extends Area2D

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")
var boostStrength = 2008.405
var prevMax
var newMax
var boosted = false

func _ready():
	if !Global.paused:
		prevMax = Global.player.max_velocity
		newMax = Global.player.max_velocity
		$CollisionShape2D.disabled = false

var circle_emitted = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if get_overlapping_bodies().find(Global.player) != -1 and !Global.paused:
		if !circle_emitted:
			Global.circles.push_back([Vector2(position.x,position.y+Global.levelOffset),0])
			get_viewport().set_input_as_handled()
			circle_emitted=true
		if !Global.player.quick_jump_disable and Input.is_action_pressed("jump") and (Global.bufferable or (Global.player.grounded and Input.is_action_just_pressed("jump"))):
			Global.player.quick_jump_disable = true
			$CollisionShape2D.set_deferred("disabled", true)
			
			if boostStrength > Global.player.max_velocity:
				boosted = true
				prevMax = Global.player.max_velocity
				Global.player.max_velocity = (boostStrength*0.6)
				newMax = Global.player.max_velocity
				
			Global.player.velocity.y = Global.player.max_velocity*(Global.player.gravity/abs(Global.player.gravity))
			Global.bufferable = false
			$GPUParticles2D.add_child(circle_scene.instantiate())
	
	if abs(Global.player.velocity.y)<prevMax and boosted and newMax == Global.player.max_velocity:
		Global.player.max_velocity = prevMax
 
func _process(delta: float) -> void:
	$TextureRect.rotation += delta*3.7

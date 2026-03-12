extends Area2D

var character_body

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")

func _ready():
	character_body = get_node("../../CharacterBody2D")
	$CollisionShape2D.disabled = false

var circle_emitted = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if get_overlapping_bodies().find(character_body) != -1 and !Global.paused:
		if !circle_emitted:
			Global.circles.push_back([Vector2(position.x,position.y+Global.levelOffset),0])
			get_viewport().set_input_as_handled()
			circle_emitted=true
		if Input.is_action_pressed("jump") and (Global.bufferable or (character_body.grounded and Input.is_action_just_pressed("jump"))):
			$CollisionShape2D.set_deferred("disabled", true)
			character_body.velocity.y = character_body.max_velocity*(character_body.gravity/abs(character_body.gravity))
			Global.bufferable = false
			$GPUParticles2D.add_child(circle_scene.instantiate())

func _process(delta: float) -> void:
	$TextureRect.rotation += delta*3.7

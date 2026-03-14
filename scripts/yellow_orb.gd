extends Area2D

@export var boostStrength: float

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")

func _ready():
	$CollisionShape2D.disabled = false

var circle_emitted = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if get_overlapping_bodies().find(Global.player) != -1 and !Global.paused:
		if !circle_emitted:
			Global.circles.push_back([Vector2(position.x,position.y+Global.levelOffset),0])
			get_viewport().set_input_as_handled()
			circle_emitted=true
		if Input.is_action_pressed("jump") and (Global.bufferable or (Global.player.grounded and Input.is_action_just_pressed("jump"))):
			$CollisionShape2D.set_deferred("disabled", true)
			Global.player.velocity.y = -boostStrength*(Global.player.gravity/abs(Global.player.gravity))
			Global.bufferable = false
			$GPUParticles2D.add_child(circle_scene.instantiate())

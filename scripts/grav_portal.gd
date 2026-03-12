extends CollisionShape2D

var character_body
@export var multiplier: int
@export var force: bool

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")

func _ready():
	character_body = get_node("../../../CharacterBody2D")
	disabled = false

func _on_grav_portal_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body == character_body:
		var prevGrav = character_body.gravity
		
		set_deferred("disabled", true)
		var newGravity
		if force:
			newGravity = abs(character_body.gravity) * multiplier
		else:
			newGravity = character_body.gravity * multiplier
			
		var mat = $"../GravityPortal".material as ShaderMaterial
		mat.set_shader_parameter("lightness", 0.99)
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/lightness", 0, 0.4).set_ease(Tween.EASE_IN)
		
		var mat2 = $"../GravityPortal2".material as ShaderMaterial
		mat2.set_shader_parameter("lightness", 0.99)
		var tween2 = create_tween()
		tween2.tween_property(mat2, "shader_parameter/lightness", 0, 0.4).set_ease(Tween.EASE_IN)

		if prevGrav != newGravity:
			if not Input.is_action_pressed("jump"):
				Global.bufferable = true
			
			character_body.flip()
			character_body.velocity.y *= 0.474
			
			#character_body.velocity.y += character_body.gravity * get_process_delta_time() * 0.1
			#character_body.move_and_slide()
			
			var node = circle_scene.instantiate()
			node.scale = Vector2(0.35,0.35)
			add_child(node)

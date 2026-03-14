extends Area2D

var character_body

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")
@export var gamemode_scene : PackedScene

func _ready():
	character_body = get_node("../../CharacterBody2D")
	$CollisionShape2D.disabled = false

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body == character_body:
		$CollisionShape2D.set_deferred("disabled", true)
		
		var mat = $PortalFront.material as ShaderMaterial
		mat.set_shader_parameter("lightness", 0.99)
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/lightness", 0, 0.4).set_ease(Tween.EASE_IN)
		
		var mat2 = $PortalBack.material as ShaderMaterial
		mat2.set_shader_parameter("lightness", 0.99)
		var tween2 = create_tween()
		tween2.tween_property(mat2, "shader_parameter/lightness", 0, 0.4).set_ease(Tween.EASE_IN)

		var node = circle_scene.instantiate()
		node.scale = Vector2(0.35,0.35)
		$GPUParticles2D.add_child(node)
		
		Global.border_blocks = 0
		

extends CollisionShape2D

var character_body
@export var targetSpeed : float

func _ready():
	character_body = get_node("../../../CharacterBody2D")
	disabled = false

func _on_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body == character_body:
		set_deferred("disabled", true)
		character_body.speed = targetSpeed
		Global.circles.push_back([Vector2($"..".position.x,$"..".position.y+Global.levelOffset),0])
		
		var mat = $"../SpeedPortal".material as ShaderMaterial
		mat.set_shader_parameter("lightness", 0.99)
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/lightness", 0, 0.4).set_ease(Tween.EASE_IN)

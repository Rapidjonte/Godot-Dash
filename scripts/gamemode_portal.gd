extends Area2D

# 10 blocks = 0.0625
# 9 blocks = (648 - 576) / 128 = 72 / 128 = 0.5625
# 8 blocks = (648 - 512) / 128 = 136 / 128 = 1.0625

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")
@export var gamemode_scene : PackedScene
@export var mini_scene : PackedScene
@export var border_blocks : float
@export var two_faced_blocks : bool

func _ready():
	$CollisionShape2D.disabled = false
	var mat = $PortalFront.material as ShaderMaterial
	mat.set_shader_parameter("lightness", 0)
	var mat2 = $PortalBack.material as ShaderMaterial
	mat2.set_shader_parameter("lightness", 0)

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body == Global.player:
		$CollisionShape2D.set_deferred("disabled", true)
		
		var mat = $PortalFront.material as ShaderMaterial
		mat.set_shader_parameter("lightness", 0.99)
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/lightness", 0, 0.4).set_ease(Tween.EASE_IN)
		
		var mat2 = $PortalBack.material as ShaderMaterial
		mat2.set_shader_parameter("lightness", 0.99)
		var tween2 = create_tween()
		tween2.tween_property(mat2, "shader_parameter/lightness", 0, 0.4).set_ease(Tween.EASE_IN)
		
		Global.two_faced_blocks = two_faced_blocks
		
		switch_gamemode()
		
		if border_blocks != null:
			Global.border_blocks = border_blocks
		
		if Global.border_blocks != 0:
			Global.camera_y_lock = calculate_y_lock()
		else:
			Global.camera_y_lock = null

func switch_gamemode():
	var new 
	if Global.player.gamemode.contains("mini"):
		new = mini_scene.instantiate()
	else:
		new = gamemode_scene.instantiate()
	if new.gamemode == Global.player.gamemode:
		return
		
	var node = circle_scene.instantiate()
	node.scale = Vector2(0.35,0.35)
	$GPUParticles2D.add_child(node)
	
	new.position = Global.player.position+Global.player.center-new.center
	new.speed = Global.player.speed
	new.velocity = Global.player.velocity
	new.excessiveForce = Global.player.excessiveForce
	if sign(new.gravity) != sign(Global.player.gravity):
		new.startUpsideDown = true
	
	var old_player = Global.player
	Global.player.get_parent().add_child.call_deferred(new)
	Global.player = new
	
	old_player.queue_free()
	
func calculate_y_lock() -> float:
	var block_size: float = 64.0
	var lock_y = min(global_position.y, 96) - 324.0
	var toReturn = roundf(lock_y / block_size) * block_size + 28 + 32
	if Global.border_blocks == 0.563:
		toReturn+=32
	return toReturn

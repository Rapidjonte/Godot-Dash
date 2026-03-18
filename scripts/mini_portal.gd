extends Area2D

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")
@export var big : bool

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

		var node = circle_scene.instantiate()
		node.scale = Vector2(0.35,0.35)
		$GPUParticles2D.add_child(node)

		switch_gamemode()

func switch_gamemode():
	var new
	if !big:
		if Global.player.gamemode.contains("mini"):
			return
			
		new = load("res://scenes/gamemodes/mini_" + Global.player.gamemode + ".tscn").instantiate()
	else:
		if !Global.player.gamemode.contains("mini"):
			return
		
		new = load("res://scenes/gamemodes/" + Global.player.gamemode.substr(5) + ".tscn").instantiate()
	
	print("old pos: ", Global.player.position)
	print("old center: ", Global.player.center)
	print("new center: ", new.center)
	print("result: ", Global.player.position + Global.player.center - new.center)
	print("old gamemode: ", Global.player.gamemode)
	print("new gamemode: ", new.gamemode)
	
	
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

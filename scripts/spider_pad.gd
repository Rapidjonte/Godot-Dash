extends Area2D

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")

func _ready():
	$CollisionShape2D.disabled = false

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body == Global.player:
			$CollisionShape2D.set_deferred("disabled", true)
			var circle = circle_scene.instantiate()
			circle.position.y+=28.0
			$GPUParticles2D.add_child(circle)
			
			var gravMult = get_gravity_multiplier(rotation)
			
			teleport_until_surface(Vector2(0,gravMult))
			
			if Global.player.gravity != abs(Global.player.gravity) * gravMult:
				Global.player.flip()
			
			Global.player.velocity.y = 0
			
			Input.action_release("jump")
			Global.player.spidered()

func teleport_until_surface(direction: Vector2):
	var inner = Global.player.get_node("Area2D/middle box").shape.size.x
	var whole = Global.player.get_node("player_collision").shape.size.x

	var start = Vector2((whole/2)-(inner/2), 32)
	var end = Vector2(whole, 32)

	var offsets := []
	for i in range(6):
		var t = i / 5.0
		var x = lerp(start.x, end.x, t)
		var y = lerp(start.y, end.y, t)
		offsets.append(Vector2(x, y))

	var closest_hit = null
	var min_distance = INF

	for offset in offsets:
		var ray = Global.player.get_node("SpiderRay")
		ray.position = offset
		ray.target_position = direction * 2000
		ray.force_raycast_update()

		if ray.is_colliding():
			if "spike" in ray.get_collider().name:
				Global.player.die()
			var hit_pos = ray.get_collision_point()
			var distance = hit_pos.distance_to(Global.player.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_hit = hit_pos + ray.get_collision_normal() * 4

	if closest_hit != null:
		Global.player.global_position.y = closest_hit.y+direction.y*2
	
	if direction.y >= 1:
		Global.player.global_position.y -= whole+direction.y*2

func get_gravity_multiplier(rotation_rad: float) -> int:
	var deg = fmod(roundi(rad_to_deg(rotation_rad)), 360)
	if deg < 0:
		deg += 360

	if abs(deg - 180) < 0.1: 
		return 1
	else:
		return -1

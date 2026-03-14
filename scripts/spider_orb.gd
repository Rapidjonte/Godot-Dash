extends Area2D

var circle_scene: PackedScene = load("res://scenes/circle_effect.tscn")

func _ready():
	$CollisionShape2D.disabled = false

var circle_emitted = false
func _physics_process(delta: float) -> void:
	if get_overlapping_bodies().find(Global.player) != -1 and !Global.paused:
		if !circle_emitted:
			Global.circles.push_back([Vector2(position.x,position.y+Global.levelOffset),0])
			get_viewport().set_input_as_handled()
			circle_emitted=true
		if Input.is_action_pressed("jump") and (Global.bufferable or (Global.player.grounded and Input.is_action_just_pressed("jump"))):
			$CollisionShape2D.set_deferred("disabled", true)
			Global.bufferable = false
			$GPUParticles2D.add_child(circle_scene.instantiate())
			
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

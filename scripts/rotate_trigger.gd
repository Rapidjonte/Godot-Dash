extends TextureRect

@export var targetID : String
@export var duration : float
@export var degrees : float
@export var pivotID : String
@export var only_spawned : bool
@export var lock_object_rotation : bool

@onready var character_body = get_node("../../CharacterBody2D")
var triggered = false

func _ready() -> void:
	visible = false
	#unless in editor
	
	$Label.text = targetID
	if position.x <= -32 and !only_spawned:
		var tween = create_tween()
		if int(targetID) > 0:
			activate(tween)
 
func _process(delta: float) -> void:
	if triggered:
		return
	
	if character_body.position.x >= position.x-32 and !only_spawned:
		var tween = create_tween()
		if int(targetID) > 0:
			activate(tween)

func activate(tween):
	triggered = true
	
	for node in get_tree().get_nodes_in_group(targetID):
		if int(pivotID) > 0:
			var pivot = get_tree().get_first_node_in_group(pivotID)
			if pivot == null:
				continue

			var start_offset = node.global_position - pivot.global_position
			var start_angle = start_offset.angle()
			var radius = start_offset.length()

			tween.parallel().tween_method(
				func(a):
					node.global_position = pivot.global_position + Vector2.RIGHT.rotated(a) * radius,
				start_angle,
				start_angle + deg_to_rad(degrees),
				duration
			)

			if !lock_object_rotation:
				tween.parallel().tween_property(node, "rotation_degrees", node.rotation_degrees + degrees, duration)
		else:
			tween.parallel().tween_property(node, "rotation_degrees", node.rotation_degrees + degrees, duration)
	
	await tween.finished
	queue_free()

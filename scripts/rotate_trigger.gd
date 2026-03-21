extends TextureRect
@export var targetID : String
@export var duration : float
@export var degrees : float
@export var pivotID : String
@export var only_spawned : bool
@export var lock_object_rotation : bool
@export_enum("Linear", "Ease In", "Ease Out", "Ease In Out") var easing : int = 0
var triggered = false

func _ready() -> void:
	$Label.text = targetID
	property_list_changed.connect(func(): $Label.text = targetID)

	if !Global.paused:
		visible = false
		if position.x <= -32 and !only_spawned:
			if int(targetID) > 0:
				activate()

func _process(delta: float) -> void:
	if triggered:
		return
	if Global.player.position.x >= position.x - 32 and !only_spawned:
		if int(targetID) > 0:
			activate()

func _get_trans() -> int:
	return Tween.TRANS_LINEAR if easing == 0 else Tween.TRANS_SINE

func _get_ease() -> int:
	match easing:
		1: return Tween.EASE_IN
		2: return Tween.EASE_OUT
		3: return Tween.EASE_IN_OUT
		_: return Tween.EASE_IN_OUT

func activate():
	triggered = true

	for node in get_tree().get_nodes_in_group(targetID):
		if node.name.contains("block") and node.get_child_count() > 0:
			continue
		
		var t := create_tween()
		t.set_trans(_get_trans())
		t.set_ease(_get_ease())

		if int(pivotID) > 0:
			var pivot = get_tree().get_first_node_in_group(pivotID)
			if pivot == null:
				continue
			var start_offset = node.global_position - pivot.global_position
			var start_angle  = start_offset.angle()
			var radius       = start_offset.length()
			t.tween_method(
				func(a: float):
					node.global_position = pivot.global_position + Vector2.RIGHT.rotated(a) * radius,
				start_angle,
				start_angle + deg_to_rad(degrees),
				duration
			)
			if !lock_object_rotation:
				t.parallel().tween_property(node, "rotation_degrees", node.rotation_degrees + degrees, duration)
		else:
			t.tween_property(node, "rotation_degrees", node.rotation_degrees + degrees, duration)

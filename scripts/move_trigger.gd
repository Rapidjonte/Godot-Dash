extends TextureRect
@export var targetID : String
@export var duration : float
@export var x_move : float
@export var y_move : float
@export var lock_to_player_x : bool
@export var lock_to_player_y : bool
@export var only_spawned : bool
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
		var t := create_tween()
		t.set_trans(_get_trans())
		t.set_ease(_get_ease())

		if lock_to_player_x and lock_to_player_y:
			# x_move/y_move multiply the player's per-frame delta
			var prev_px := Global.player.global_position.x
			var prev_py := Global.player.global_position.y
			t.tween_method(
				func(_p: float):
					var dpx := Global.player.global_position.x - prev_px
					var dpy := Global.player.global_position.y - prev_py
					node.global_position.x += dpx * x_move
					node.global_position.y += dpy * y_move
					prev_px = Global.player.global_position.x
					prev_py = Global.player.global_position.y,
				0.0, 1.0, duration
			)
		elif lock_to_player_x:
			var prev_px := Global.player.global_position.x
			var start_y = node.global_position.y
			var target_y = start_y + y_move * 6.4
			t.tween_method(
				func(p: float):
					var dpx := Global.player.global_position.x - prev_px
					node.global_position.x += dpx * x_move
					node.global_position.y = lerp(start_y, target_y, p)
					prev_px = Global.player.global_position.x,
				0.0, 1.0, duration
			)
		elif lock_to_player_y:
			var prev_py := Global.player.global_position.y
			var start_x = node.global_position.x
			var target_x = start_x + x_move * 6.4
			t.tween_method(
				func(p: float):
					node.global_position.x = lerp(start_x, target_x, p)
					var dpy := Global.player.global_position.y - prev_py
					node.global_position.y += dpy * y_move
					prev_py = Global.player.global_position.y,
				0.0, 1.0, duration
			)
		else:
			var target_pos = node.global_position + Vector2(x_move * 6.4, y_move * 6.4)
			t.tween_property(node, "global_position", target_pos, duration)

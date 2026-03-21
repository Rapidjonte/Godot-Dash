extends TextureRect
@export var targetID : String
@export var duration : float
@export var targetColor : Color
@export var only_spawned : bool
@export_enum("Linear", "Ease In", "Ease Out", "Ease In Out") var easing : int = 0
var triggered = false

func _ready() -> void:
	$Label.text = targetID
	property_list_changed.connect(func(): $Label.text = targetID)
	if !Global.paused:
		visible = false
		if position.x <= -32 and !only_spawned:
			activate()

func _process(delta: float) -> void:
	if triggered: return
	if Global.player.position.x >= position.x - 32 and !only_spawned:
		activate()

func _get_trans() -> int:
	return Tween.TRANS_LINEAR if easing == 0 else Tween.TRANS_SINE

func _get_ease() -> int:
	match easing:
		1: return Tween.EASE_IN
		2: return Tween.EASE_OUT
		3: return Tween.EASE_IN_OUT
		_: return Tween.EASE_IN_OUT

func _tween_color(node: Node, prop: String) -> void:
	var t := create_tween()
	t.set_trans(_get_trans())
	t.set_ease(_get_ease())
	t.tween_property(node, prop, targetColor, duration)

func activate():
	triggered = true
	match targetID:
		"bg":
			_tween_color($"../../background/bg", "modulate")
		"g":
			_tween_color($"../../ground_tiles/g",  "modulate")
			_tween_color($"../../borders/g",        "modulate")
			_tween_color($"../../borders/g2",       "modulate")
		"l":
			_tween_color($"../../ground_tiles/line", "modulate")
			_tween_color($"../../borders/line",      "modulate")
			_tween_color($"../../borders/line2",     "modulate")
		_:
			if int(targetID) > 0:
				for node in get_tree().get_nodes_in_group(targetID):
					_tween_color(node, "modulate")

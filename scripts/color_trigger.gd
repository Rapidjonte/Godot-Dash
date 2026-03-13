extends TextureRect

@export var targetID : String
@export var duration : float
@export var targetColor : Color
@export var only_spawned : bool

@onready var character_body = get_node("../../CharacterBody2D")
var triggered = false

func _ready() -> void:
	visible = false
	#unless in editor
	
	$Label.text = targetID
	if position.x <= -32 and !only_spawned:
		var tween = create_tween()
		if targetID == "bg":
			triggered = true
			tween.tween_property($"../../background/bg", "modulate", targetColor, duration)
		elif targetID == "g":
			triggered = true
			tween.tween_property($"../../ground_tiles/g", "modulate", targetColor, duration)
			tween.parallel().tween_property($"../../borders/g", "modulate", targetColor, duration)
			tween.parallel().tween_property($"../../borders/g2", "modulate", targetColor, duration)
		elif targetID == "l":
			triggered = true
			tween.tween_property($"../../ground_tiles/line", "modulate", targetColor, duration)
			tween.parallel().tween_property($"../../borders/line", "modulate", targetColor, duration)
			tween.parallel().tween_property($"../../borders/line2", "modulate", targetColor, duration)
		elif int(targetID) > 0:
			activate(tween)

func _process(delta: float) -> void:
	if triggered:
		return
	
	if character_body.position.x >= position.x-32 and !only_spawned:
		var tween = create_tween()
		if targetID == "bg":
			triggered = true
			tween.tween_property($"../../background/bg", "modulate", targetColor, duration)
		elif targetID == "g":
			triggered = true
			tween.tween_property($"../../ground_tiles/g", "modulate", targetColor, duration)
			var tween2 = create_tween()
			tween2.tween_property($"../../borders/g", "modulate", targetColor, duration)
			var tween3 = create_tween()
			tween3.tween_property($"../../borders/g2", "modulate", targetColor, duration)
		elif targetID == "l":
			triggered = true
			tween.tween_property($"../../ground_tiles/line", "modulate", targetColor, duration)
			var tween2 = create_tween()
			tween2.tween_property($"../../borders/line", "modulate", targetColor, duration)
			var tween3 = create_tween()
			tween3.tween_property($"../../borders/line2", "modulate", targetColor, duration)
		elif int(targetID) > 0:
			activate(tween)

func activate(tween):
	triggered = true
	
	for node in get_tree().get_nodes_in_group(targetID):
		tween.parallel().tween_property(node, "modulate:r", targetColor.r, duration)	
		tween.parallel().tween_property(node, "modulate:g", targetColor.g, duration)
		tween.parallel().tween_property(node, "modulate:b", targetColor.b, duration)		
	
	await tween.finished
	queue_free()

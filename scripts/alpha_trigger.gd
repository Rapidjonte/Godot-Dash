extends TextureRect

@export var targetID : String
@export var targetAlpha : float
@export var duration : float

@onready var character_body = get_node("../../CharacterBody2D")
var triggered = false

func _ready() -> void:
	visible = false
	#unless in editor
	
	$Label.text = targetID
	if position.x <= -32:
		var tween = create_tween()
		if int(targetID) > 0:
			activate(tween)

func _process(delta: float) -> void:
	if triggered:
		return
	
	if character_body.position.x >= position.x-32:
		var tween = create_tween()
		if int(targetID) > 0:
			activate(tween)

func activate(tween):
	triggered = true
	
	for node in get_tree().get_nodes_in_group(targetID):
		tween.parallel().tween_property(node, "modulate:a", targetAlpha, duration)	
	
	await tween.finished
	queue_free()

extends TextureRect

@export var targetID : String
@export var delay : float
@export var only_spawned : bool

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
	
	await get_tree().create_timer(delay).timeout
	
	for node in get_tree().get_nodes_in_group(targetID):
		if node.activate:
			node.activate(tween)
	
	await tween.finished
	queue_free()

extends TextureRect

@export var targetID : String
@export var toggle : bool
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
	
	for node in get_tree().get_nodes_in_group(targetID):
		var collide = node.find_child("CollisionShape2D", true)
		if toggle:
			if collide:
				collide.disabled = false
			node.visible = true
		else:
			if collide:
				collide.disabled = true
			node.visible = false
	
	await tween.finished
	queue_free()

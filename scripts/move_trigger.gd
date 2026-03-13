extends TextureRect

@export var targetID : String
@export var duration : float
@export var x_move : float
@export var y_move : float
@export var lock_to_player_x : bool
@export var lock_to_player_y : bool
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
		pass

	await tween.finished
	queue_free()

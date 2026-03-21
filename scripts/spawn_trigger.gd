extends TextureRect

@export var targetID : String
@export var delay : float
@export var only_spawned : bool

var triggered = false

func _ready() -> void:
	$Label.text = targetID
	
	if !Global.paused:
		visible = false
	
		$Label.text = targetID
		if position.x <= -32 and !only_spawned:
			if int(targetID) > 0:
				activate()
 
func _process(delta: float) -> void:
	if triggered:
		return

	if Global.player.position.x >= position.x-32 and !only_spawned:
		if int(targetID) > 0:
			activate()

func activate():
	triggered = true
	
	await get_tree().create_timer(delay).timeout
	
	for node in get_tree().get_nodes_in_group(targetID):
		if node.activate:
			node.activate()
	
	#queue_free()

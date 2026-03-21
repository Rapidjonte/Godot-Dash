extends TextureRect

@export var targetID : String
@export var toggle : bool
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
	if Global.paused:
		$Label.text = targetID
	
	if Global.player.position.x >= position.x-32 and !only_spawned:
		if int(targetID) > 0:
			activate()

func activate():
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
			
	#queue_free()

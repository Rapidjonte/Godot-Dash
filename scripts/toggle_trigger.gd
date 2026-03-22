extends TextureRect

@export var targetID : String
@export var toggle : bool
@export var only_spawned : bool

var triggered = false

func _ready() -> void:
	$Label.text = targetID
	property_list_changed.connect(func(): $Label.text = targetID)
	
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
		if toggle:
			node.process_mode = Node.PROCESS_MODE_INHERIT
			node.visible = true
		else:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.visible = false
		_set_collisions_recursive(node, toggle)
 
func _set_collisions_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", not enabled)
	for child in node.get_children():
		_set_collisions_recursive(child, enabled)
 

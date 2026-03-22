extends TextureRect
@export var targetID : String
@export var only_spawned : bool
var triggered = false

func _ready() -> void:
	$Label.text = targetID
	property_list_changed.connect(func(): $Label.text = targetID)
	if !Global.paused:
		visible = false
		if position.x <= -32 and !only_spawned:
			activate()

func _process(_delta: float) -> void:
	if triggered: return
	if Global.player.position.x >= position.x - 32 and !only_spawned:
		activate()

func activate() -> void:
	triggered = true

	for node in get_tree().get_nodes_in_group(targetID):
		node.queue_free()

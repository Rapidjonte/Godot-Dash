extends Line2D

var queue : Array
@export var MAX_LENGTH : int

func _ready():
	top_level = true

func _physics_process(_delta):
	if Global.paused:
		return

	var pos = _get_position()
	
	queue.push_front(pos)
	
	if queue.size() > MAX_LENGTH:
		queue.pop_back()
	
	clear_points()
	
	for point in queue:
		add_point(point)

func _get_position():
	return get_parent().global_position + get_parent().center - Vector2(11,11)

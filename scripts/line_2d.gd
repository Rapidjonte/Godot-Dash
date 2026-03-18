extends Line2D

var queue : Array
@export var MAX_LENGTH : int

func _physics_process(_delta):
	var pos = _get_position()
	
	queue.push_front(pos)
	
	if queue.size() > MAX_LENGTH:
		queue.pop_back()
	
	clear_points()
	
	for point in queue:
		add_point(point)

func _get_position(): 
	return Vector2(Global.player.position.x+64,Global.player.position.y-352) - Vector2(32,32)+Global.player.center

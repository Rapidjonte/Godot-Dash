extends Line2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	clear_points()
	
	for point in Global.playtest:
		add_point(point+Vector2(-32,-64))

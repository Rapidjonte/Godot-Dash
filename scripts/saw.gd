extends CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var texture : Texture2D = $"..".texture
	if texture:
		var newShape = shape.duplicate()
		newShape.radius = (texture.get_width()*0.532)/2-13.582
		shape = newShape

func _process(delta: float) -> void:
	$"../TextureRect".rotation += delta * PI * 2

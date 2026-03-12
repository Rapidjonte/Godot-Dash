extends RigidBody2D

var offset: float
@onready var cam = $"../cam"

func _ready() -> void:
	offset = cam.position.x - position.x
	Global.flip_blocks.connect(flip_self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x = cam.position.x - offset

func flip_self():
	$CollisionShape2D.rotation += deg_to_rad(180)

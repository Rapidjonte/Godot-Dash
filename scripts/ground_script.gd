extends RigidBody2D

var offset: float
@onready var cam = $"../cam"

func _ready() -> void:
	offset = cam.position.x - position.x
	Global.flip_blocks.connect(flip_self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x = cam.position.x - offset
	$"../ground2".position.x = cam.position.x - offset
	if Global.border_blocks != 0:
		$CollisionShape2D.position.y = cam.position.y-(Global.border_blocks*64)-15
		$ground.position.y = cam.position.y-1054+(Global.border_blocks*64)
		$ground/CollisionShape2D.disabled = false
	else:
		$ground/CollisionShape2D.disabled = true

func flip_self():
	$CollisionShape2D.rotation += deg_to_rad(180)

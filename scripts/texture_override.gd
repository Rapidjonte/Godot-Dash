extends RigidBody2D

@export var texture: Texture
@export var disable_collision: bool

func _ready() -> void:
	if texture != null and $TextureRect:
		$TextureRect.texture = texture
	if disable_collision != null and $CollisionShape2D:
		$CollisionShape2D.disabled = disable_collision

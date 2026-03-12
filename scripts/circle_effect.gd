extends TextureRect

func _ready() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.4)
	var alphaTween = create_tween()
	alphaTween.tween_property(self, "modulate", Color(modulate.r, modulate.g, modulate.b, 0.8), 0.05).from(Color(modulate.r, modulate.g, modulate.b, 0.05))
	await alphaTween.finished
	var alphaTween2 = create_tween()
	alphaTween2.tween_property(self, "modulate", Color(modulate.r, modulate.g, modulate.b, 0), 0.3)
	await tween.finished
	queue_free()

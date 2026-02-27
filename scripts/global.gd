extends Node

var attempt = 0
var paused = false

var endX = 128

func calculate_end(level: Node):
	endX = 128
	for node in level.get_children(true):
		if node.position.x > endX:
			endX = node.position.x + 128

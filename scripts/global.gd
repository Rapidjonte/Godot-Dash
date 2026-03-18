extends Node

signal flip_blocks

var player : CharacterBody2D

const NORMAL_SPEED := 10.41667
const HALF_SPEED := 8.4
const DOUBLE_SPEED := 12.91667
const TRIPLE_SPEED := 15.667
const QUADRUPLE_SPEED := 19.2

var levelOffset := 448

var bufferable := false
var attempt := 0
var paused := false

func reset():
	attempt += 1
	bufferable = true
	circles = []
	border_blocks = 0
	camera_y_lock = null

var level : PackedScene
func load_level(path: String):
	level = load(path)
	calculate_end(level.instantiate())

var endX := 128
func calculate_end(_level: Node):
	var margin = 600
	endX = margin
	for node in _level.get_children(true):
		if node.position.x > endX - margin:
			endX = node.position.x + margin

var circles = []

var camera_y_lock = null
var border_blocks : float = 0

func is_divisible_by_90(value: float, epsilon: float = 0.001) -> bool:
	var remainder = fmod(roundi(value), 90.0)
	return abs(remainder) < epsilon or abs(remainder - 90.0) < epsilon

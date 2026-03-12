extends Control

@onready var cps_label: Label = $cps
@onready var fps_label: Label = $fps

var click_times: Array[float] = []

func _input(event):
	if Input.is_action_just_pressed("jump"):
		click_times.append(Time.get_ticks_msec() / 1000.0)
		cps_label.modulate = Color (0, 1, 0, cps_label.modulate.a)
	if Input.is_action_just_released("jump"):
		cps_label.modulate = Color (1, 1, 1, cps_label.modulate.a)

func _process(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	while click_times.size() > 0 and current_time - click_times[0] > 1.0:
		click_times.pop_front()
	
	cps_label.text = str(click_times.size()) + " CPS"
	fps_label.text = str(int(Engine.get_frames_per_second())) + " FPS"

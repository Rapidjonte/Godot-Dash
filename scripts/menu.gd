extends Control

var http_request: HTTPRequest
var level_button = preload("res://scenes/level_button.tscn")

func _ready() -> void:
	refresh()
	
func refresh():
	print("refreshing")
	$LoadingCircleUhd.visible = true
	
	for child in $ScrollContainer/VBoxContainer.get_children():
		child.queue_free()
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	fetch_csv("https://raw.githubusercontent.com/Rapidjonte/godot-dash-levels/refs/heads/main/index.csv")

func _process(delta: float) -> void:
	if $LoadingCircleUhd.visible:
		$LoadingCircleUhd.rotation += delta

func fetch_csv(url: String):
	var error = http_request.request(url)
	if error != OK:
		push_error("HTTPRequest failed: " + str(error))

func parse_csv(text: String) -> Array[Dictionary]:
	var lines = text.strip_edges().split("\n", false)
	if lines.is_empty():
		return []
	
	var headers = lines[0].split(",")
	var result: Array[Dictionary] = []
	
	for i in range(1, lines.size()):
		var values = lines[i].split(",")
		var row: Dictionary = {}
		for j in headers.size():
			row[headers[j].strip_edges()] = values[j].strip_edges() if j < values.size() else ""
		result.append(row)
	
	return result

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("Request failed. Code: " + str(response_code))
		return
	
	var text = body.get_string_from_utf8()
	var data = parse_csv(text)
	
	for row in data:
		var new = level_button.instantiate()
		new.data = row
		$ScrollContainer/VBoxContainer.add_child(new)
	
	$LoadingCircleUhd.visible = false

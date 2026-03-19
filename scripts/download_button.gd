extends "res://scripts/hover.gd"

var blue_button = load("res://images/ui/GJ_longBtn02_001.png")
var loaded_level: PackedScene

var http: HTTPRequest

func _ready():
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_download_complete)

func activate():
	var id = $"..".data["id"]
	var url = "https://raw.githubusercontent.com/Rapidjonte/godot-dash-levels/refs/heads/main/" + id + ".tscn"
	http.request(url)

	texture_normal = blue_button
	#$button_text.text = "Loading"

func _on_download_complete(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("Failed to download level")
		return
	
	var id = $"..".data["id"]
	var save_path = "user://" + id + ".tscn"
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_buffer(body)
	file.close()
	
	loaded_level = load(save_path)
	
	Global.load_level(loaded_level)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

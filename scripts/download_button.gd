extends "res://scripts/hover.gd"
var blue_button = load("res://images/ui/GJ_longBtn02_001.png")
var green_button = texture_normal
var loaded_level: PackedScene
var http: HTTPRequest

func _ready():
	super._ready()
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_download_complete)

func activate():
	var id = $"..".data["id"]
	var url = "https://raw.githubusercontent.com/Rapidjonte/godot-dash-levels/refs/heads/main/" + id + ".scn"
	http.request(url)
	texture_normal = blue_button

func _on_download_complete(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("Failed to download level")
		texture_normal = green_button
		$button_text.text = "Play"
		return

	var id = $"..".data["id"]
	var save_path = "user://" + id + ".scn"

	# Store raw bytes — binary .scn must not go through text encoding
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_buffer(body)
	file.close()

	loaded_level = load(save_path)
	if loaded_level == null:
		push_error("Downloaded file is not a valid PackedScene: " + save_path)
		return

	Global.load_level(loaded_level)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

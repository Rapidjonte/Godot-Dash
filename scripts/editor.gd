extends Node2D

# ─── Inner class: circular rotation dial ──────────────────────────────────────
class RotateDial extends Control:
	var angle_rad := 0.0
	var _dragging := false
	var _drag_start_angle := 0.0
	var _drag_start_value := 0.0
	signal dial_changed(radians: float)
	signal drag_ended()

	func set_angle_degrees(deg: float) -> void:
		angle_rad = deg_to_rad(fmod(deg, 360.0))
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 6.0
		draw_arc(c, r, 0, TAU, 48, Color(0.18, 0.18, 0.18), r * 2.0)
		draw_arc(c, r, 0, TAU, 48, Color(0.4, 0.4, 0.4), 2.0)
		for i in range(12):
			var a := i * TAU / 12.0
			draw_line(c + Vector2(r * 0.78, 0).rotated(a), c + Vector2(r, 0).rotated(a), Color(0.5, 0.5, 0.5), 1.0)
		var tip := c + Vector2(r * 0.85, 0).rotated(angle_rad)
		draw_line(c, tip, Color(0.3, 1.0, 0.3), 2.5)
		draw_circle(tip, 5.0, Color(0.3, 1.0, 0.3))
		draw_circle(c, 4.0, Color(0.75, 0.75, 0.75))

	func _gui_input(event: InputEvent) -> void:
		var c := size / 2.0
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_start_angle = (event.position - c).angle()
				_drag_start_value = angle_rad
				accept_event()
			else:
				_dragging = false
				drag_ended.emit()
		if event is InputEventMouseMotion and _dragging:
			var cur = (event.position - c).angle()
			var delta = cur - _drag_start_angle
			while delta > PI: delta -= TAU
			while delta < -PI: delta += TAU
			angle_rad = _drag_start_value + delta
			queue_redraw()
			dial_changed.emit(angle_rad)
			accept_event()

# ─── Main editor ──────────────────────────────────────────────────────────────

@onready var level := $level
@onready var cam   := $cam

var selected_nodes: Array[Node] = []
var cycle_index    := 0
var last_candidates: Array[Node] = []

var swipe_enabled := false
var swipe_start   := Vector2.ZERO
var swipe_rect    := Rect2()
var is_swiping    := false

var GRID       := 64
const GRID_MIN := 16
const GRID_MAX := 512

var _draw_node: Node2D
const SCENES_FOLDER := "res://prefabs/"

enum Mode { SELECT, PLACE, FREE_MOVE }
var mode := Mode.SELECT

var is_panning      := false
var pan_start_mouse := Vector2.ZERO
var pan_start_cam   := Vector2.ZERO
var pan_with_lmb    := false

var pending_scene_path  := ""
var active_panel_button: Button = null

var free_move_node:   Node    = null
var free_move_offset: Vector2 = Vector2.ZERO
var free_move_offsets: Dictionary = {}
var is_free_dragging  := false
var free_move_snap    := true

var zoom_level  := 1.0
const ZOOM_MIN  := 0.125
const ZOOM_MAX  := 8.0
const ZOOM_STEP := 0.1

var _swipe_btn:        Button = null
var _free_move_btn:    Button = null
var _snap_toggle_btn:  Button = null
var _pivot_btn:        Button = null
var use_group_pivot    := false
var _custom_pivot:     Vector2 = Vector2.ZERO
var _rot_initial_state: Dictionary = {}
var _rot_pivot_initial: Vector2 = Vector2.ZERO
var _dial_initial_rad  := 0.0
var _dial_is_dragging  := false
var _scale_is_dragging := false

var _last_paint_cell := Vector2(INF, INF)
var _is_painting     := false

# Context menu
var _ctx_layer: CanvasLayer      = null
var _ctx_panel: PanelContainer   = null
var _ctx_node:  Node             = null

# Undo / redo
var _undo_stack: Array = []
var _redo_stack: Array = []
const MAX_UNDO    := 50
var _was_moving   := false
var _move_hold_time := 0.0
const MOVE_HOLD_DELAY := 0.4
const MOVE_REPEAT_RATE := 0.07
var _lmb_started_on_ui := false
var _texture_popup_layer: CanvasLayer = null

# Transform panel (scale + rotate)
var _transform_panel:     PanelContainer = null
var _scale_slider:        HSlider        = null
var _skew_slider:         HSlider        = null
var _rot_spinbox:         SpinBox        = null
var _rotate_dial:         RotateDial     = null
var _updating_xform_ui   := false
var _skew_is_dragging    := false

# ─── UI blocking ──────────────────────────────────────────────────────────────

func _is_over_ui() -> bool:
	var h := get_viewport().gui_get_hovered_control()
	if h == null: return false
	var p: Node = h
	while p != null:
		if p == level: return false
		p = p.get_parent()
	return true

func _is_transform_panel_active() -> bool:
	if _dial_is_dragging: return true
	if _scale_is_dragging: return true
	if _skew_is_dragging: return true
	if _rot_spinbox and _rot_spinbox.has_focus(): return true
	return false

# ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	Global.paused = true
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	_draw_node = Node2D.new()
	cl.add_child(_draw_node)
	_draw_node.draw.connect(_on_overlay_draw)

	_build_object_panel()
	_build_sidebar_buttons()
	_build_top_toolbar()
	_build_transform_panel()
	_build_context_menu()

	if Global.get("last_editor_scene") != null and Global.last_editor_scene is PackedScene:
		_load_packed_scene_into_level(Global.last_editor_scene)
		Global.last_editor_scene = null

	if Global.get("last_editor_cam_pos") != null:
		cam.position = Global.last_editor_cam_pos
	if Global.get("last_editor_zoom") != null:
		zoom_level = Global.last_editor_zoom
		cam.zoom = Vector2(zoom_level, zoom_level)

# ─── Process ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var _delta := delta
	_draw_node.queue_redraw()
	_sync_transform_panel()

	if Input.is_action_just_pressed("exit"):
		_prepare_level_for_save()
		var saved_signals: Array = []
		for child in level.get_children():
			saved_signals.append_array(_strip_signals_recursive(child))
		var ps := PackedScene.new()
		ps.pack(level)
		_restore_signals(saved_signals)
		_restore_level_after_save()
		Global.last_editor_scene = ps
		Global.last_editor_cam_pos = cam.position
		Global.last_editor_zoom = zoom_level
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

	# Hold Ctrl+Z to keep undoing
	var ctrl_held := Input.is_key_pressed(KEY_CTRL)
	if ctrl_held and Input.is_key_pressed(KEY_Z) and not Input.is_key_pressed(KEY_SHIFT):
		_undo_hold_time += _delta
		if not _undo_is_holding and _undo_hold_time >= UNDO_HOLD_DELAY:
			_undo_is_holding = true
		var repeat_rate := UNDO_REPEAT_RATE / 2.0 if _undo_is_holding else UNDO_REPEAT_RATE
		if _undo_is_holding and fmod(_undo_hold_time - UNDO_HOLD_DELAY, repeat_rate) < _delta:
			_undo()
	else:
		_undo_hold_time = 0.0
		_undo_is_holding = false

	var shift := Input.is_key_pressed(KEY_SHIFT)
	var dir   := Vector2.ZERO
	if Input.is_action_pressed("ui_up"):    dir.y -= 1
	if Input.is_action_pressed("ui_down"):  dir.y += 1
	if Input.is_action_pressed("ui_left"):  dir.x -= 1
	if Input.is_action_pressed("ui_right") and not Input.is_key_pressed(KEY_CTRL): dir.x += 1

	if dir != Vector2.ZERO and not selected_nodes.is_empty():
		var first_press := Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right")
		if first_press:
			_move_hold_time = 0.0
			_push_undo()
			_was_moving = true
			for node in selected_nodes:
				if shift:
					var step := int(max(1, GRID / 10))
					if node is Node2D:    node.position += dir * step
					elif node is Control: node.position += dir * step
				else:
					if node is Node2D:    node.position += dir * GRID
					elif node is Control: node.position += dir * GRID
		else:
			_move_hold_time += _delta
			if _move_hold_time >= MOVE_HOLD_DELAY:
				if fmod(_move_hold_time - MOVE_HOLD_DELAY, MOVE_REPEAT_RATE) < _delta:
					_was_moving = true
					for node in selected_nodes:
						if shift:
							var step := int(max(1, GRID / 10))
							if node is Node2D:    node.position += dir * step
							elif node is Control: node.position += dir * step
						else:
							if node is Node2D:    node.position += dir * GRID
							elif node is Control: node.position += dir * GRID
	else:
		if _was_moving: _was_moving = false
		_move_hold_time = 0.0

# ─── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ctrl := Input.is_key_pressed(KEY_CTRL)
		match event.keycode:
			KEY_T: swipe_enabled = !swipe_enabled; _update_swipe_button()
			KEY_F: _set_mode(Mode.FREE_MOVE if mode != Mode.FREE_MOVE else Mode.SELECT)
			KEY_G: free_move_snap = !free_move_snap; _update_snap_toggle_button()
			KEY_Q:
				var angle := -45.0 if Input.is_key_pressed(KEY_SHIFT) else -90.0
				_rotate_selection_around_pivot(angle)
			KEY_E:
				var angle := 45.0 if Input.is_key_pressed(KEY_SHIFT) else 90.0
				_rotate_selection_around_pivot(angle)
			KEY_ESCAPE: _hide_context_menu(); _cancel_placement()
			KEY_DELETE:
				_push_undo()
				for n in selected_nodes: n.queue_free()
				_deselect_all()
			KEY_D:
				if ctrl: _duplicate_selected()
			KEY_Z:
				if ctrl:
					if Input.is_key_pressed(KEY_SHIFT): _redo()
					else: _undo()
			KEY_Y:
				if ctrl: _redo()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_lmb_started_on_ui = event.pressed and (_is_over_ui() or _is_transform_panel_active())
		if _is_over_ui() or _is_transform_panel_active():
			is_swiping = false
			is_panning = false
			pan_with_lmb = false
			return

		var shift := Input.is_key_pressed(KEY_SHIFT)

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if shift: GRID = clampi(GRID * 2, GRID_MIN, GRID_MAX)
			else: _apply_zoom(ZOOM_STEP, get_viewport().get_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if shift: GRID = clampi(GRID / 2, GRID_MIN, GRID_MAX)
			else: _apply_zoom(-ZOOM_STEP, get_viewport().get_mouse_position())

		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed: _start_pan(false)
			else:
				if not pan_with_lmb: is_panning = false

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hit: Array[Node] = []
			for child in level.get_children():
				if _node_contains_point(child, get_global_mouse_position()): hit.append(child)
			if not hit.is_empty():
				var target := hit[hit.size() - 1]
				for n in hit:
					if n in selected_nodes: target = n; break
				_show_context_menu(target)
			else: _hide_context_menu()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_hide_context_menu()
				swipe_start   = get_viewport().get_mouse_position()
				is_swiping    = false
				pan_with_lmb  = false
				_is_painting  = false
				_last_paint_cell = Vector2(INF, INF)

				if mode == Mode.FREE_MOVE:
					var hit: Array[Node] = []
					for child in level.get_children():
						if _node_contains_point(child, get_global_mouse_position()): hit.append(child)
					if not hit.is_empty():
						free_move_node = hit[hit.size() - 1]
						if free_move_node not in selected_nodes:
							selected_nodes = [free_move_node]
						_push_undo()
						free_move_offsets.clear()
						var wm := get_global_mouse_position()
						for n in selected_nodes:
							if n is Node2D:    free_move_offsets[n] = n.global_position - wm
							elif n is Control: free_move_offsets[n] = n.position - wm
						is_free_dragging = true
				elif mode == Mode.PLACE and pending_scene_path != "":
					_place_object(get_global_mouse_position())
					if swipe_enabled:
						_last_paint_cell = _snap_to_cell_center(get_global_mouse_position())
						_is_painting = true
			else:
				_is_painting = false
				if mode == Mode.FREE_MOVE and is_free_dragging:
					is_free_dragging = false
					if free_move_snap and free_move_node != null:
						var old_pos: Vector2
						if free_move_node is Node2D:    old_pos = free_move_node.global_position
						elif free_move_node is Control: old_pos = free_move_node.position
						else: old_pos = Vector2.ZERO
						_snap_node_to_cell(free_move_node)
						var new_pos: Vector2
						if free_move_node is Node2D:    new_pos = free_move_node.global_position
						elif free_move_node is Control: new_pos = free_move_node.position
						else: new_pos = old_pos
						var snap_delta := new_pos - old_pos
						for n in selected_nodes:
							if n == free_move_node: continue
							if not is_instance_valid(n): continue
							if n is Node2D:    n.global_position += snap_delta
							elif n is Control: n.position += snap_delta
					free_move_node = null
					free_move_offsets.clear()
				elif is_panning and pan_with_lmb:
					is_panning = false; pan_with_lmb = false
				elif mode == Mode.PLACE:
					pass
				elif swipe_enabled and is_swiping:
					_finish_swipe(get_global_mouse_position())
				else:
					_handle_click(get_global_mouse_position())
				is_swiping = false

	if event is InputEventMouseMotion:
		if _is_transform_panel_active() or _lmb_started_on_ui: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and is_panning and not pan_with_lmb:
			_apply_pan()

		if mode == Mode.FREE_MOVE and is_free_dragging and free_move_node != null:
			var wm := get_global_mouse_position()
			for n in selected_nodes:
				if not is_instance_valid(n): continue
				if n not in free_move_offsets: continue
				if n is Node2D:    n.global_position = wm + free_move_offsets[n]
				elif n is Control: n.position = wm + free_move_offsets[n]
		elif mode == Mode.PLACE and _is_painting and swipe_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var cell := _snap_to_cell_center(get_global_mouse_position())
			if cell != _last_paint_cell:
				_place_object(get_global_mouse_position())
				_last_paint_cell = cell
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_free_dragging and mode != Mode.PLACE:
			var ms    := get_viewport().get_mouse_position()
			var delta := ms - swipe_start
			if is_panning and pan_with_lmb:
				_apply_pan()
			elif swipe_enabled:
				if delta.length() > 5 and not _is_transform_panel_active():
					is_swiping  = true
					swipe_rect  = Rect2(swipe_start, ms - swipe_start).abs()
			elif mode == Mode.SELECT:
				if not is_panning and not is_swiping and delta.length() > 5:
					var hit: Array[Node] = []
					for child in level.get_children():
						if _node_contains_point(child, get_global_mouse_position()): hit.append(child)
					if hit.is_empty(): _start_pan(true)

# ─── Undo / Redo ──────────────────────────────────────────────────────────────

func _capture_state() -> Dictionary:
	_prepare_level_for_save()
	var saved_sigs: Array = []
	for child in level.get_children():
		saved_sigs.append_array(_strip_signals_recursive(child))
	var ps := PackedScene.new()
	ps.pack(level)
	_restore_signals(saved_sigs)
	_restore_level_after_save()
	var sel_names: Array[String] = []
	for n in selected_nodes:
		if is_instance_valid(n): sel_names.append(n.name)
	return {"scene": ps, "selection": sel_names}

func _push_undo() -> void:
	_undo_stack.append(_capture_state())
	if _undo_stack.size() > MAX_UNDO: _undo_stack.pop_front()
	_redo_stack.clear()

func _apply_state(entry: Dictionary) -> void:
	var ps: PackedScene = entry["scene"]
	var sel_names: Array = entry["selection"]
	_load_packed_scene_into_level(ps)
	selected_nodes.clear()
	for child in level.get_children():
		if child.name in sel_names:
			selected_nodes.append(child)

func _undo() -> void:
	if _undo_stack.is_empty(): return
	_redo_stack.append(_capture_state())
	_apply_state(_undo_stack.pop_back())

func _redo() -> void:
	if _redo_stack.is_empty(): return
	_undo_stack.append(_capture_state())
	_apply_state(_redo_stack.pop_back())

# Hold Ctrl+Z to keep undoing
var _undo_hold_time   := 0.0
var _undo_is_holding  := false
const UNDO_HOLD_DELAY := 0.4
const UNDO_REPEAT_RATE := 0.12

# ─── Duplicate ────────────────────────────────────────────────────────────────

func _duplicate_selected() -> void:
	if selected_nodes.is_empty(): return
	_push_undo()

	# Only duplicate top-level selected nodes
	var roots: Array[Node] = []
	for node in selected_nodes:
		var is_child_of_selected := false
		var p := node.get_parent()
		while p != null and p != level:
			if p in selected_nodes: is_child_of_selected = true; break
			p = p.get_parent()
		if not is_child_of_selected: roots.append(node)

	var stamp_mode := mode == Mode.FREE_MOVE and is_free_dragging

	# Snapshot original positions BEFORE any duplication so originals are not affected
	var original_positions: Dictionary = {}
	for node in roots:
		if node is Node2D:    original_positions[node] = node.position
		elif node is Control: original_positions[node] = node.position

	var new_nodes: Array[Node] = []
	for node in roots:
		var dup := node.duplicate()
		_ignore_mouse_recursive(dup)
		_hide_particles(dup)
		_make_materials_unique(dup)
		level.add_child(dup)
		dup.name = node.name
		_set_owner_recursive(dup, level)

		if stamp_mode:
			# Stamp at the original position — originals keep moving, dupes stay behind
			dup.position = original_positions[node]
		else:
			# Offset copy by one grid cell
			dup.position = original_positions[node] + Vector2(GRID, GRID)

		new_nodes.append(dup)

	if stamp_mode:
		pass
	else:
		selected_nodes.clear()
		for n in new_nodes:
			selected_nodes.append(n)
		# Reset movement state so held arrow keys don't immediately move new dupes
		_move_hold_time = 0.0
		_was_moving = false

# ─── Zoom ─────────────────────────────────────────────────────────────────────

func _apply_zoom(delta: float, pivot_screen: Vector2) -> void:
	var world_before := get_canvas_transform().affine_inverse() * pivot_screen
	zoom_level = clampf(zoom_level + delta, ZOOM_MIN, ZOOM_MAX)
	cam.zoom = Vector2(zoom_level, zoom_level)
	await get_tree().process_frame
	var world_after := get_canvas_transform().affine_inverse() * pivot_screen
	cam.position += world_before - world_after

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _snap_to_cell_center(world_pos: Vector2) -> Vector2:
	return (world_pos / GRID).floor() * GRID + Vector2(GRID, GRID) / 2.0

func _snap_node_to_cell(node: Node) -> void:
	if node is TextureRect:
		var pv: Vector2 = node.pivot_offset if node.pivot_offset != Vector2.ZERO else node.size / 2.0
		var new_center := _snap_to_cell_center(node.position + pv)
		node.position = new_center - pv
	elif node is Node2D:
		node.position = _snap_to_cell_center(node.position)
	elif node is Control:
		node.position = _snap_to_cell_center(node.position)

func _start_pan(lmb: bool) -> void:
	is_panning = true; pan_with_lmb = lmb
	pan_start_mouse = get_viewport().get_mouse_position()
	pan_start_cam   = cam.position

func _apply_pan() -> void:
	cam.position = pan_start_cam - (get_viewport().get_mouse_position() - pan_start_mouse) / zoom_level

func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse_recursive(child)

# ─── Transform panel ──────────────────────────────────────────────────────────

func _build_transform_panel() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 67
	add_child(ui_layer)

	_transform_panel = PanelContainer.new()
	_transform_panel.custom_minimum_size = Vector2(200, 0)
	_transform_panel.anchor_left   = 1.0; _transform_panel.anchor_right  = 1.0
	_transform_panel.anchor_top    = 0.5; _transform_panel.anchor_bottom  = 0.5
	_transform_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_transform_panel.offset_left   = -215; _transform_panel.offset_right  = -70
	_transform_panel.offset_top    = -250; _transform_panel.offset_bottom  = 250
	_transform_panel.visible = false
	ui_layer.add_child(_transform_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_transform_panel.add_child(vbox)

	var slbl := Label.new(); slbl.text = "Scale"
	vbox.add_child(slbl)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.25; _scale_slider.max_value = 4.0
	_scale_slider.step = 0.05; _scale_slider.value = 1.0
	_scale_slider.custom_minimum_size = Vector2(180, 20)
	vbox.add_child(_scale_slider)
	var scale_val_label := Label.new(); scale_val_label.text = "1.0"
	scale_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(scale_val_label)
	_scale_slider.value_changed.connect(func(v: float):
		if _updating_xform_ui: return
		scale_val_label.text = "%.2f" % v
		_apply_scale(v)
	)
	_scale_slider.drag_started.connect(func(): _scale_is_dragging = true)
	_scale_slider.drag_ended.connect(func(_changed: bool):
		_scale_is_dragging = false
		_scale_slider.release_focus()
	)

	# Skew
	var sklbl := Label.new(); sklbl.text = "Skew"
	vbox.add_child(sklbl)
	_skew_slider = HSlider.new()
	_skew_slider.min_value = -90.0; _skew_slider.max_value = 90.0
	_skew_slider.step = 0.5; _skew_slider.value = 0.0
	_skew_slider.custom_minimum_size = Vector2(180, 20)
	vbox.add_child(_skew_slider)
	var skew_val_label := Label.new(); skew_val_label.text = "0.0"
	skew_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(skew_val_label)
	_skew_slider.value_changed.connect(func(v: float):
		if _updating_xform_ui: return
		skew_val_label.text = "%.1f" % v
		_push_undo()
		for n in selected_nodes:
			if "trigger" in n.name.to_lower(): continue
			if n.get("skew") != null:
				n.set("skew", deg_to_rad(v))
	)
	_skew_slider.drag_started.connect(func(): _skew_is_dragging = true)
	_skew_slider.drag_ended.connect(func(_changed: bool):
		_skew_is_dragging = false
		_skew_slider.release_focus()
	)

	vbox.add_child(HSeparator.new())

	var rlbl := Label.new(); rlbl.text = "Rotation"
	vbox.add_child(rlbl)
	_rot_spinbox = SpinBox.new()
	_rot_spinbox.min_value = -360.0; _rot_spinbox.max_value = 360.0
	_rot_spinbox.step = 1.0; _rot_spinbox.value = 0.0
	_rot_spinbox.custom_minimum_size = Vector2(180, 24)
	vbox.add_child(_rot_spinbox)
	_rot_spinbox.value_changed.connect(func(v: float):
		if _updating_xform_ui: return
		if _rot_initial_state.is_empty(): _capture_rot_initial()
		# v is the new absolute value for the first selected node
		# compute delta from that node's initial rotation
		var first_init_rot: float = 0.0
		if not _rot_initial_state.is_empty():
			first_init_rot = _rot_initial_state.values()[0]["rot"]
		var delta := v - first_init_rot
		_apply_rotation_delta(delta)
		_updating_xform_ui = true
		if _rotate_dial: _rotate_dial.set_angle_degrees(v)
		_updating_xform_ui = false
	)
	_rot_spinbox.focus_entered.connect(func(): _push_undo(); _capture_rot_initial())
	_rot_spinbox.focus_exited.connect(func(): _rot_initial_state.clear())

	var dial_margin := MarginContainer.new()
	dial_margin.add_theme_constant_override("margin_top", 47)
	dial_margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(dial_margin)
	_rotate_dial = RotateDial.new()
	_rotate_dial.custom_minimum_size = Vector2(100, 100)
	_rotate_dial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dial_margin.add_child(_rotate_dial)
	_rotate_dial.dial_changed.connect(func(rad: float):
		if _updating_xform_ui: return
		if not _dial_is_dragging:
			_dial_is_dragging = true
			_dial_initial_rad = rad
			_push_undo()
			_capture_rot_initial()
		var delta_deg := rad_to_deg(rad - _dial_initial_rad)
		_apply_rotation_delta(delta_deg)
		_updating_xform_ui = true
		_rot_spinbox.value = fmod((_rot_initial_state.values()[0]["rot"] if not _rot_initial_state.is_empty() else 0.0) + delta_deg, 360.0)
		_updating_xform_ui = false
	)
	_rotate_dial.drag_ended.connect(func():
		_dial_is_dragging = false
		_rot_initial_state.clear()
	)

func _apply_scale(v: float) -> void:
	if selected_nodes.is_empty(): return
	if "trigger" in selected_nodes[0].name.to_lower(): return
	_scale_selection_around_pivot(v)

func _sync_transform_panel() -> void:
	var has_sel := not selected_nodes.is_empty()
	if _transform_panel: _transform_panel.visible = has_sel
	if not has_sel or _updating_xform_ui: return
	var first := selected_nodes[0]
	if not is_instance_valid(first): return
	_updating_xform_ui = true
	var is_trigger := "trigger" in first.name.to_lower()
	if _scale_slider:
		var sc := 1.0
		if first is Node2D:    sc = first.scale.x
		elif first is Control: sc = first.scale.x
		_scale_slider.editable = not is_trigger
		_scale_slider.value = sc
	if _skew_slider:
		var has_skew := not is_trigger and first.get("skew") != null
		_skew_slider.editable = has_skew
		if has_skew:
			_skew_slider.value = rad_to_deg(first.get("skew"))
		else:
			_skew_slider.value = 0.0
	if _rot_spinbox:
		var rd := 0.0
		if first is Node2D:    rd = first.rotation_degrees
		elif first is Control: rd = first.rotation_degrees
		_rot_spinbox.value = rd
		if _rotate_dial: _rotate_dial.set_angle_degrees(rd)
	_updating_xform_ui = false

# ─── Top toolbar ──────────────────────────────────────────────────────────────

func _build_top_toolbar() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 68
	add_child(ui_layer)

	var hbox := HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.offset_top   = 6; hbox.offset_bottom = 42
	hbox.offset_left  = 6; hbox.offset_right  = -6
	hbox.add_theme_constant_override("separation", 6)
	ui_layer.add_child(hbox)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var play_btn := _make_toolbar_button("Play", Color(0.1, 0.6, 0.2))
	play_btn.pressed.connect(_on_play)
	hbox.add_child(play_btn)

	var export_btn := _make_toolbar_button("Export", Color(0.2, 0.4, 0.7))
	export_btn.pressed.connect(_on_export)
	hbox.add_child(export_btn)

	var import_btn := _make_toolbar_button("Import", Color(0.5, 0.3, 0.1))
	import_btn.pressed.connect(_on_import)
	hbox.add_child(import_btn)

	var share_btn := _make_toolbar_button("Share", Color(0.5, 0.1, 0.5))
	share_btn.pressed.connect(_on_share)
	hbox.add_child(share_btn)

	var tex_btn := _make_toolbar_button("Texture", Color(0.15, 0.4, 0.5))
	tex_btn.pressed.connect(func():
		if is_instance_valid(_texture_popup_layer):
			_texture_popup_layer.queue_free()
			_texture_popup_layer = null
		else:
			_on_add_texture()
	)
	hbox.add_child(tex_btn)

func _make_toolbar_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 30)
	btn.focus_mode = Control.FOCUS_NONE
	var s := StyleBoxFlat.new()
	s.bg_color = color.darkened(0.2)
	s.corner_radius_top_left    = 5; s.corner_radius_top_right    = 5
	s.corner_radius_bottom_left = 5; s.corner_radius_bottom_right = 5
	var h := StyleBoxFlat.new(); h.bg_color = color
	h.corner_radius_top_left    = 5; h.corner_radius_top_right    = 5
	h.corner_radius_bottom_left = 5; h.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	return btn

func _strip_signals_recursive(node: Node) -> Array:
	var saved: Array = []
	for sig in node.get_signal_list():
		var sname: String = sig["name"]
		for conn in node.get_signal_connection_list(sname).duplicate():
			var cb: Callable = conn["callable"]
			var obj = cb.get_object()
			# Only strip connections to scripted nodes — ignore engine-internal callables
			if obj != null and obj is Node and obj.get_script() != null:
				saved.append([node, sname, cb, conn.get("flags", 0)])
				node.disconnect(sname, cb)
	for child in node.get_children():
		saved.append_array(_strip_signals_recursive(child))
	return saved

func _restore_signals(saved: Array) -> void:
	for entry in saved:
		var node: Node = entry[0]
		var sname: String = entry[1]
		var cb: Callable = entry[2]
		var flags: int = entry[3]
		if is_instance_valid(node) and not node.is_connected(sname, cb):
			node.connect(sname, cb, flags)

func _on_play() -> void:
	_prepare_level_for_save()
	var saved_signals: Array = []
	for child in level.get_children():
		saved_signals.append_array(_strip_signals_recursive(child))
	var ps := PackedScene.new()
	ps.pack(level)
	_restore_signals(saved_signals)
	_restore_level_after_save()
	Global.load_level(ps)
	Global.last_editor_scene = ps
	Global.last_editor_cam_pos = cam.position
	Global.last_editor_zoom = zoom_level
	Global.entered_from_editor = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_export() -> void:
	_prepare_level_for_save()
	var saved_signals: Array = []
	for child in level.get_children():
		saved_signals.append_array(_strip_signals_recursive(child))
	var ps := PackedScene.new()
	ps.pack(level)
	_restore_signals(saved_signals)
	_restore_level_after_save()
	var dialog := FileDialog.new()
	dialog.file_mode  = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access     = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.scn", "Godot Binary Scene")
	dialog.add_filter("*.tscn", "Godot Text Scene")
	dialog.title      = "Export Level"
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 450))
	dialog.file_selected.connect(func(path: String):
		ResourceSaver.save(ps, path, ResourceSaver.FLAG_COMPRESS)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

func _safe_disconnect_recursive(node: Node) -> void:
	for sig in node.get_signal_list():
		var sname: String = sig["name"]
		for conn in node.get_signal_connection_list(sname).duplicate():
			var cb: Callable = conn["callable"]
			if cb.get_object() != null and cb.get_object() is Node:
				if node.is_connected(sname, cb):
					node.disconnect(sname, cb)
	for child in node.get_children():
		_safe_disconnect_recursive(child)

func _load_packed_scene_into_level(ps: PackedScene) -> void:
	_deselect_all()
	for child in level.get_children():
		child.free()
	var inst := ps.instantiate()
	var children_to_move: Array[Node] = []
	for child in inst.get_children():
		children_to_move.append(child)
	for child in children_to_move:
		inst.remove_child(child)
		_safe_disconnect_recursive(child)
		_hide_particles(child)
		_ignore_mouse_recursive(child)
		level.add_child(child)
		_fix_auto_names(child)
		_set_owner_recursive(child, level)
		_fix_texturerect_pivots(child)
	inst.free()

func _fix_texturerect_pivots(node: Node) -> void:
	if node is TextureRect:
		var sz = node.size if node.size != Vector2.ZERO else (node.texture.get_size() if node.texture else Vector2.ZERO)
		if sz != Vector2.ZERO and node.pivot_offset == Vector2.ZERO:
			node.pivot_offset = sz / 2.0
	for child in node.get_children():
		_fix_texturerect_pivots(child)

func _on_import() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access    = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.scn", "Godot Binary Scene")
	dialog.add_filter("*.tscn", "Godot Text Scene")
	dialog.title     = "Import Level"
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 450))
	dialog.file_selected.connect(func(path: String):
		var ps = load(path) as PackedScene
		if ps == null: dialog.queue_free(); return
		_push_undo()
		await _load_packed_scene_into_level(ps)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

# ─── Share ────────────────────────────────────────────────────────────────────

const GOOGLE_FORM_URL   := "https://docs.google.com/forms/d/e/1FAIpQLSftEGau3sHF5EqUirW0ovkFYRMBus-5bKHFWNpsOfk799UAcA/viewform?usp=dialog"
const GOOGLE_FORM_ENTRY := "entry.000000000"

func _on_share() -> void:
	var saved_signals: Array = []
	for child in level.get_children():
		saved_signals.append_array(_strip_signals_recursive(child))
	_prepare_level_for_save()
	var ps := PackedScene.new()
	ps.pack(level)
	_restore_signals(saved_signals)
	_restore_level_after_save()

	var tmp_path := "user://share_level.scn"
	var err := ResourceSaver.save(ps, tmp_path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Share: failed to save scene (%d)" % err)
		return

	var f := FileAccess.open(tmp_path, FileAccess.READ)
	var raw := f.get_buffer(f.get_length())
	f.close()

	var b64 := Marshalls.raw_to_base64(raw)
	DisplayServer.clipboard_set(b64)
	OS.shell_open(GOOGLE_FORM_URL)

	var popup := AcceptDialog.new()
	popup.title = "Share"
	popup.dialog_text = "Level copied to clipboard as Base64 (%d chars).\nPaste it into your submission form." % b64.length()
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

# ─── Add Texture ──────────────────────────────────────────────────────────────

const TEXTURE_SCALE := 0.533
const IMAGES_FOLDER := "res://images"

func _on_add_texture() -> void:
	var popup_layer := CanvasLayer.new()
	popup_layer.layer = 300
	_texture_popup_layer = popup_layer
	add_child(popup_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 540)
	panel.offset_left = -210; panel.offset_right  =  210
	panel.offset_top  = -270; panel.offset_bottom =  270
	popup_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var header := HBoxContainer.new(); vbox.add_child(header)
	var title := Label.new(); title.text = "Pick Texture"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	var close_btn := Button.new(); close_btn.text = "✕"; close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.pressed.connect(func(): popup_layer.queue_free(); _texture_popup_layer = null)
	header.add_child(close_btn)
	_make_draggable(panel, header)

	var search := LineEdit.new()
	search.placeholder_text = "Filter..."; search.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(search)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6); vbox.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 460)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2); scroll.add_child(list)

	var prev_panel := PanelContainer.new()
	prev_panel.custom_minimum_size = Vector2(150, 460); body.add_child(prev_panel)
	var prev_vbox := VBoxContainer.new(); prev_panel.add_child(prev_vbox)
	var prev_img := TextureRect.new()
	prev_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_img.custom_minimum_size = Vector2(148, 148)
	prev_img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_img.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	prev_vbox.add_child(prev_img)
	var prev_lbl := Label.new()
	prev_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prev_lbl.add_theme_font_size_override("font_size", 9); prev_vbox.add_child(prev_lbl)

	var image_files: Array[String] = []
	_scan_images(IMAGES_FOLDER, image_files); image_files.sort()

	var all_btns: Array[Button] = []
	for img_path in image_files:
		var btn := Button.new()
		btn.text = img_path.get_file().get_basename()
		btn.set_meta("path", img_path)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.mouse_entered.connect(func():
			var t = load(img_path) as Texture2D
			if t:
				prev_img.texture = t
				prev_lbl.text = "%s\n%dx%d" % [img_path.get_file(), t.get_width(), t.get_height()]
		)
		btn.pressed.connect(func():
			var t = load(img_path) as Texture2D
			if t == null: return
			popup_layer.queue_free()
			_texture_popup_layer = null
			_spawn_texture_rect(t, img_path)
		)
		list.add_child(btn); all_btns.append(btn)

	if all_btns.is_empty():
		var lbl := Label.new(); lbl.text = "(no images found)"; list.add_child(lbl)

	search.text_changed.connect(func(q: String):
		var ql := q.to_lower()
		for b in all_btns:
			b.visible = ql.is_empty() or (b.get_meta("path") as String).get_file().to_lower().contains(ql)
	)

func _scan_images(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with("."):
			fname = dir.get_next(); continue
		var full := path + "/" + fname
		if dir.current_is_dir():
			_scan_images(full, out)
		elif fname.ends_with(".png") or fname.ends_with(".jpg") or fname.ends_with(".jpeg") or fname.ends_with(".webp"):
			out.append(full)
		fname = dir.get_next()
	dir.list_dir_end()

func _spawn_texture_rect(tex: Texture2D, img_path: String) -> void:
	var tr := TextureRect.new()
	tr.texture      = tex
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size         = tex.get_size()
	tr.scale        = Vector2(TEXTURE_SCALE, TEXTURE_SCALE)
	tr.pivot_offset = tr.size / 2.0
	_ensure_blend_mode(tr)
	_ignore_mouse_recursive(tr)

	var snapped := _snap_to_cell_center(get_global_mouse_position()
		if get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position())
		else get_canvas_transform().affine_inverse() * (get_viewport().get_visible_rect().size / 2.0))

	tr.position = snapped - tr.pivot_offset
	tr.name     = img_path.get_file().get_basename()

	level.add_child(tr)
	_fix_auto_names(tr)
	_set_owner_recursive(tr, level)

	_deselect_all()
	selected_nodes = [tr]

func _build_sidebar_buttons() -> void:
	var ui_layer := CanvasLayer.new(); ui_layer.layer = 65; add_child(ui_layer)
	var vbox := VBoxContainer.new()
	vbox.anchor_left     = 1.0; vbox.anchor_right   = 1.0
	vbox.anchor_top      = 0.5; vbox.anchor_bottom   = 0.5
	vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vbox.offset_left     = -60; vbox.offset_right   = -10
	vbox.offset_top      = -155; vbox.offset_bottom  = 155
	vbox.add_theme_constant_override("separation", 8)
	ui_layer.add_child(vbox)

	var desel_btn := _make_sidebar_button("✕", Color(0.8, 0.2, 0.2))
	desel_btn.pressed.connect(func(): _deselect_all(); _cancel_placement(); _set_mode(Mode.SELECT))
	vbox.add_child(desel_btn)

	_swipe_btn = _make_sidebar_button("⬚", Color(0.2, 0.5, 0.8))
	_swipe_btn.pressed.connect(func(): swipe_enabled = !swipe_enabled; _update_swipe_button())
	vbox.add_child(_swipe_btn); _update_swipe_button()

	_free_move_btn = _make_sidebar_button("✥", Color(0.6, 0.4, 0.1))
	_free_move_btn.pressed.connect(func(): _set_mode(Mode.FREE_MOVE if mode != Mode.FREE_MOVE else Mode.SELECT))
	vbox.add_child(_free_move_btn)

	_snap_toggle_btn = _make_sidebar_button("⊹", Color(0.2, 0.6, 0.4))
	_snap_toggle_btn.pressed.connect(func(): free_move_snap = !free_move_snap; _update_snap_toggle_button())
	vbox.add_child(_snap_toggle_btn); _update_snap_toggle_button()

	var snap_now := _make_sidebar_button("⊞", Color(0.3, 0.3, 0.6))
	snap_now.pressed.connect(func():
		_push_undo()
		for n in selected_nodes:
			_snap_node_to_cell(n)
	)
	vbox.add_child(snap_now)

	_pivot_btn = _make_sidebar_button("◎", Color(0.5, 0.1, 0.7))
	_pivot_btn.pressed.connect(func(): use_group_pivot = !use_group_pivot; _update_pivot_button())
	vbox.add_child(_pivot_btn); _update_pivot_button()

func _set_mode(new_mode: Mode) -> void:
	mode = new_mode; is_free_dragging = false; free_move_node = null
	is_swiping = false; _is_painting = false
	if mode != Mode.PLACE: _cancel_placement()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.8, 0.6, 0.0) if mode == Mode.FREE_MOVE else Color(0.4, 0.27, 0.07)
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	if _free_move_btn: _free_move_btn.add_theme_stylebox_override("normal", s)

func _make_sidebar_button(text: String, color: Color) -> Button:
	var btn := Button.new(); btn.text = text
	btn.custom_minimum_size = Vector2(48, 48); btn.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new(); normal.bg_color = color.darkened(0.3)
	normal.corner_radius_top_left    = 6; normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left = 6; normal.corner_radius_bottom_right = 6
	var hover := StyleBoxFlat.new(); hover.bg_color = color
	hover.corner_radius_top_left    = 6; hover.corner_radius_top_right    = 6
	hover.corner_radius_bottom_left = 6; hover.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal",  normal); btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal); btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 20)
	return btn

func _update_swipe_button() -> void:
	if not _swipe_btn: return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.7, 0.2) if swipe_enabled else Color(0.1, 0.3, 0.5)
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	_swipe_btn.add_theme_stylebox_override("normal", s)

func _update_snap_toggle_button() -> void:
	if not _snap_toggle_btn: return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.7, 0.4) if free_move_snap else Color(0.15, 0.3, 0.25)
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	_snap_toggle_btn.add_theme_stylebox_override("normal", s)

func _update_pivot_button() -> void:
	if not _pivot_btn: return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.7, 0.1, 1.0) if use_group_pivot else Color(0.25, 0.05, 0.35)
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	_pivot_btn.add_theme_stylebox_override("normal", s)

func _capture_rot_initial() -> void:
	_rot_initial_state.clear()
	_rot_pivot_initial = _get_group_center()
	for n in selected_nodes:
		if not is_instance_valid(n): continue
		var pos: Vector2
		if n is Node2D:    pos = n.global_position
		elif n is Control: pos = n.global_position
		else: continue
		_rot_initial_state[n] = {"pos": pos, "rot": n.rotation_degrees if n is Node2D else n.rotation_degrees}

func _apply_rotation_delta(delta_deg: float) -> void:
	# Additive: each node rotates by delta_deg from its own initial rotation
	if _rot_initial_state.is_empty(): return
	var delta_rad := deg_to_rad(delta_deg)
	for n in selected_nodes:
		if not is_instance_valid(n): continue
		if not _rot_initial_state.has(n): continue
		var init = _rot_initial_state[n]
		var new_rot = init["rot"] + delta_deg
		if use_group_pivot and selected_nodes.size() > 1:
			var init_offset: Vector2 = init["pos"] - _rot_pivot_initial
			var new_pos := _rot_pivot_initial + init_offset.rotated(delta_rad)
			if n is Node2D:    n.global_position = new_pos
			elif n is Control: n.global_position = new_pos
		if n is Node2D:    n.rotation_degrees = new_rot
		elif n is Control: n.rotation_degrees = new_rot

func _apply_rotation_from_initial(target_deg: float) -> void:
	if _rot_initial_state.is_empty(): return
	if selected_nodes.size() > 1 and use_group_pivot:
		# All nodes orbit around pivot + rotate on own axis, relative to initial snapshot
		var angle_rad := deg_to_rad(target_deg - (_rot_initial_state.values()[0]["rot"] if not _rot_initial_state.is_empty() else 0.0))
		# Use first node's initial rotation as reference for the dial angle
		# Actually: rotate ALL nodes by the SAME delta from their own initial rotation
		# and orbit them around the pivot by that same delta
		var first_initial_rot: float = 0.0
		if not _rot_initial_state.is_empty():
			first_initial_rot = _rot_initial_state.values()[0]["rot"]
		var delta_deg := target_deg - first_initial_rot
		var delta_rad := deg_to_rad(delta_deg)
		for n in selected_nodes:
			if not is_instance_valid(n): continue
			if not _rot_initial_state.has(n): continue
			var init = _rot_initial_state[n]
			var init_offset: Vector2 = init["pos"] - _rot_pivot_initial
			var new_pos := _rot_pivot_initial + init_offset.rotated(delta_rad)
			var new_rot = init["rot"] + delta_deg
			if n is Node2D:
				n.global_position = new_pos
				n.rotation_degrees = new_rot
			elif n is Control:
				n.global_position = new_pos
				n.rotation_degrees = new_rot
	else:
		# Single selection or no group pivot: just set rotation
		for n in selected_nodes:
			if not is_instance_valid(n): continue
			if n is Node2D:    n.rotation_degrees = target_deg
			elif n is Control: n.rotation_degrees = target_deg

func _get_group_center() -> Vector2:
	if selected_nodes.is_empty(): return Vector2.ZERO
	var min_x := INF; var max_x := -INF
	var min_y := INF; var max_y := -INF
	for n in selected_nodes:
		if not is_instance_valid(n): continue
		var pos: Vector2
		if n is Node2D:    pos = n.global_position
		elif n is Control: pos = n.global_position
		else: continue
		min_x = minf(min_x, pos.x); max_x = maxf(max_x, pos.x)
		min_y = minf(min_y, pos.y); max_y = maxf(max_y, pos.y)
	if min_x == INF: return Vector2.ZERO
	return Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)

func _rotate_selection_around_pivot(angle_deg: float) -> void:
	_push_undo()
	if use_group_pivot and selected_nodes.size() > 1:
		var pivot := _get_group_center()
		var angle_rad := deg_to_rad(angle_deg)
		for n in selected_nodes:
			if not is_instance_valid(n): continue
			var offset: Vector2
			if n is Node2D:    offset = n.global_position - pivot
			elif n is Control: offset = n.global_position - pivot
			else: continue
			if n is Node2D:
				n.global_position = pivot + offset.rotated(angle_rad)
				n.rotation_degrees += angle_deg
			elif n is Control:
				n.global_position = pivot + offset.rotated(angle_rad)
				n.rotation_degrees += angle_deg
	else:
		for n in selected_nodes:
			if n is Node2D:    n.rotation_degrees += angle_deg
			elif n is Control: n.rotation_degrees += angle_deg

func _scale_selection_around_pivot(v: float) -> void:
	_push_undo()
	if not use_group_pivot:
		for n in selected_nodes:
			if n is Node2D:    n.scale = Vector2(v, v)
			elif n is Control: n.scale = Vector2(v, v)
		return
	var pivot := _get_group_center()
	for n in selected_nodes:
		if not is_instance_valid(n): continue
		# Move node so distance from pivot scales proportionally
		var old_scale := 1.0
		if n is Node2D:    old_scale = n.scale.x
		elif n is Control: old_scale = n.scale.x
		if old_scale == 0.0: old_scale = 1.0
		var ratio := v / old_scale
		var offset: Vector2
		if n is Node2D:    offset = n.global_position - pivot
		elif n is Control: offset = n.global_position - pivot
		else: continue
		if n is Node2D:
			n.global_position = pivot + offset * ratio
			n.scale = Vector2(v, v)
		elif n is Control:
			n.global_position = pivot + offset * ratio
			n.scale = Vector2(v, v)

# ─── Object Panel ─────────────────────────────────────────────────────────────

func _build_object_panel() -> void:
	var ui_layer := CanvasLayer.new(); ui_layer.layer = 64; add_child(ui_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 50); panel.custom_minimum_size = Vector2(180, 0)
	ui_layer.add_child(panel)
	var vbox := VBoxContainer.new(); panel.add_child(vbox)
	var label := Label.new(); label.text = "Objects"; vbox.add_child(label)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(180, 460); vbox.add_child(scroll)
	# Block panning and swiping when scrollbar is dragged
	scroll.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			is_panning = false; pan_with_lmb = false; is_swiping = false
	)
	var grid := GridContainer.new(); grid.columns = 2; scroll.add_child(grid)

	var dir := DirAccess.open(SCENES_FOLDER)
	if dir == null:
		var err := Label.new(); err.text = "(folder not found)"; grid.add_child(err); return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tscn"): files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort_custom(func(a: String, b: String) -> bool:
		var ka := a.get_basename()
		var kb := b.get_basename()
		var ia := ka.find("_")
		var ib := kb.find("_")
		if ia >= 0: ka = ka.substr(ia + 1)
		if ib >= 0: kb = kb.substr(ib + 1)
		return ka.to_lower() < kb.to_lower()
	)
	for f in files: _add_panel_button(grid, f)

func _add_panel_button(parent: Node, fname: String) -> void:
	const SIZE := 80.0
	var scene_path := SCENES_FOLDER + fname
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SIZE, SIZE); btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.clip_contents = true; btn.focus_mode = Control.FOCUS_NONE; btn.text = ""
	var normal_style := _make_panel_style(Color(0.15, 0.15, 0.15), false)
	var hover_style  := _make_panel_style(Color(0.25, 0.25, 0.25), false)
	var sel_style    := _make_panel_style(Color(0.1, 0.4, 0.1), true)
	btn.add_theme_stylebox_override("normal",  normal_style)
	btn.add_theme_stylebox_override("hover",   hover_style)
	btn.add_theme_stylebox_override("pressed", sel_style)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

	var svp := SubViewport.new()
	svp.size = Vector2i(SIZE, SIZE); svp.transparent_bg = true; svp.disable_3d = true
	svp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	svp.process_mode = Node.PROCESS_MODE_DISABLED
	var preview_root := Node2D.new(); svp.add_child(preview_root)
	var packed := load(scene_path) as PackedScene
	if packed:
		var pi := packed.instantiate()
		_strip_scripts(pi); _hide_particles(pi); preview_root.add_child(pi)
		var bounds := _get_preview_bounds(pi)
		if bounds.size.x > 0 and bounds.size.y > 0:
			var sf := minf((SIZE * 0.65) / bounds.size.x, (SIZE * 0.65) / bounds.size.y)
			preview_root.scale = Vector2(sf, sf)
			preview_root.position = Vector2(SIZE / 2.0, SIZE / 2.0) - bounds.get_center() * sf

	var svc := SubViewportContainer.new()
	svc.stretch = true; svc.custom_minimum_size = Vector2(SIZE, SIZE); svc.size = Vector2(SIZE, SIZE)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE; svc.add_child(svp); btn.add_child(svc)

	var lbl := Label.new(); lbl.text = fname.get_basename()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.anchor_top = 1.0; lbl.anchor_bottom = 1.0; lbl.anchor_right = 1.0; lbl.offset_top = -20
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; btn.add_child(lbl)

	btn.pressed.connect(func():
		if active_panel_button == btn: _cancel_placement(); return
		_cancel_placement(); active_panel_button = btn; pending_scene_path = scene_path
		btn.add_theme_stylebox_override("normal", sel_style); _set_mode(Mode.PLACE)
	)
	parent.add_child(btn)
	await get_tree().process_frame
	svp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children(): _strip_scripts(child)

func _make_panel_style(color: Color, border: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = color
	s.corner_radius_top_left    = 4; s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	if border:
		s.border_color = Color(0.3, 1.0, 0.3)
		s.border_width_top = 2; s.border_width_bottom = 2
		s.border_width_left = 2; s.border_width_right  = 2
	return s

func _cancel_placement() -> void:
	pending_scene_path = ""; _is_painting = false
	if active_panel_button != null:
		active_panel_button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.15, 0.15, 0.15), false))
		active_panel_button = null
	if mode == Mode.PLACE: mode = Mode.SELECT

# ─── Placement ────────────────────────────────────────────────────────────────

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner

func _fix_auto_names(node: Node) -> void:
	if node.name.begins_with("@"):
		node.name = node.get_class()
	for child in node.get_children():
		_fix_auto_names(child)

func _place_object(world_pos: Vector2) -> void:
	_push_undo()  # capture state BEFORE placing
	var packed := load(pending_scene_path) as PackedScene
	if packed == null: _cancel_placement(); return
	var instance := packed.instantiate()
	_hide_particles(instance)
	_ignore_mouse_recursive(instance)
	_make_materials_unique(instance)
	level.add_child(instance)
	var scene_name := pending_scene_path.get_file().get_basename()
	instance.name = scene_name
	_fix_auto_names(instance)
	_set_owner_recursive(instance, level)

	var snapped := _snap_to_cell_center(world_pos)

	if instance is TextureRect:
		var sz: Vector2 = instance.size
		if sz == Vector2.ZERO and instance.texture: sz = instance.texture.get_size()
		if sz == Vector2.ZERO: sz = Vector2(GRID, GRID)
		instance.pivot_offset = sz / 2.0
		instance.position     = snapped - sz / 2.0
	elif instance is Node2D:
		instance.position = snapped
	elif instance is Control:
		var sz: Vector2 = instance.size
		instance.position = snapped - sz / 2.0 if sz != Vector2.ZERO else snapped

	selected_nodes = [instance]

func _make_materials_unique(node: Node) -> void:
	if node is CanvasItem and node.material is ShaderMaterial:
		node.material = node.material.duplicate(true)
		node.material.resource_local_to_scene = true
	for child in node.get_children():
		_make_materials_unique(child)

func _hide_particles(node: Node) -> void:
	if node is GPUParticles2D or node is CPUParticles2D:
		node.visible = false
		return
	for child in node.get_children(): _hide_particles(child)

func _show_particles(node: Node) -> void:
	if node is GPUParticles2D or node is CPUParticles2D:
		node.visible = true
		return
	for child in node.get_children(): _show_particles(child)

func _ensure_blend_mode(node: Node) -> void:
	if node is CanvasItem and node.material == null and node.get_script() == null:
		var mat := CanvasItemMaterial.new()
		mat.resource_local_to_scene = true
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		node.material = mat
	for child in node.get_children(): _ensure_blend_mode(child)

# ─── Pre/post save helpers ────────────────────────────────────────────────────

func _prepare_level_for_save() -> void:
	level.process_mode = Node.PROCESS_MODE_INHERIT
	for child in level.get_children():
		_restore_node_for_save(child)

func _restore_node_for_save(node: Node) -> void:
	if node is GPUParticles2D or node is CPUParticles2D:
		node.visible = true
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.process_mode = Node.PROCESS_MODE_INHERIT
	for child in node.get_children():
		_restore_node_for_save(child)

func _restore_level_after_save() -> void:
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for child in level.get_children():
		_restore_node_for_editor(child)

func _restore_node_for_editor(node: Node) -> void:
	if node is GPUParticles2D or node is CPUParticles2D:
		node.visible = false
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_restore_node_for_editor(child)

# ─── Preview Bounds ───────────────────────────────────────────────────────────

func _get_preview_bounds(node: Node) -> Rect2:
	var combined := Rect2(); var found := false
	var items: Array[Node] = []; _collect_visual_nodes(node, items)
	for item in items:
		var r = Rect2()
		if item is Sprite2D and item.texture:
			var ts: Vector2 = item.texture.get_size()
			r = Rect2(item.position - ts / 2.0 if item.centered else item.position, ts)
		elif item is TextureRect:
			var ts = item.texture.get_size() if item.texture else item.size
			r = Rect2(item.position, ts)
		else: continue
		combined = combined.merge(r) if found else r; found = true
	return combined if found else Rect2()

func _collect_visual_nodes(node: Node, out: Array[Node]) -> void:
	if node is Sprite2D or node is TextureRect: out.append(node)
	for child in node.get_children(): _collect_visual_nodes(child, out)

# ─── Context Menu ─────────────────────────────────────────────────────────────

func _make_draggable(panel: Control, drag_handle: Control) -> void:
	var drag_start_mouse := Vector2.ZERO
	var drag_start_panel := Vector2.ZERO
	var dragging := false
	drag_handle.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				drag_start_mouse = drag_handle.get_global_mouse_position()
				drag_start_panel = panel.position
		elif event is InputEventMouseMotion and dragging:
			var drag_delta := drag_handle.get_global_mouse_position() - drag_start_mouse
			panel.position = drag_start_panel + drag_delta
	)

func _build_context_menu() -> void:
	_ctx_layer = CanvasLayer.new(); _ctx_layer.layer = 200; add_child(_ctx_layer)
	_ctx_panel = PanelContainer.new(); _ctx_panel.visible = false
	_ctx_panel.custom_minimum_size = Vector2(310, 0); _ctx_layer.add_child(_ctx_panel)

func _show_context_menu(node: Node) -> void:
	_ctx_node = node
	for c in _ctx_panel.get_children(): c.queue_free()
	var mp := get_viewport().get_mouse_position()
	var vps := get_viewport().get_visible_rect().size
	_ctx_panel.position = Vector2(minf(mp.x + 12, vps.x - 320), minf(mp.y + 12, vps.y - 420))
	var outer := VBoxContainer.new(); _ctx_panel.add_child(outer)
	var header := HBoxContainer.new(); outer.add_child(header)
	var title := Label.new()
	title.text = node.name + (" (%d selected)" % selected_nodes.size() if selected_nodes.size() > 1 else "")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	var close_btn := Button.new(); close_btn.text = "✕"; close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.pressed.connect(_hide_context_menu); header.add_child(close_btn)
	_make_draggable(_ctx_panel, header)
	outer.add_child(HSeparator.new())
	var tabs := TabContainer.new(); tabs.custom_minimum_size = Vector2(300, 300); outer.add_child(tabs)
	var gs := ScrollContainer.new(); gs.name = "Groups"; gs.custom_minimum_size = Vector2(0, 280); tabs.add_child(gs)
	var gv := VBoxContainer.new(); gv.add_theme_constant_override("separation", 4); gs.add_child(gv); _fill_groups_tab(gv)
	var ps2 := ScrollContainer.new(); ps2.name = "Properties"; ps2.custom_minimum_size = Vector2(0, 280); tabs.add_child(ps2)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 4); ps2.add_child(pv); _fill_props_tab(pv)
	_ctx_panel.visible = true

func _hide_context_menu() -> void:
	_ctx_panel.visible = false; _ctx_node = null

func _get_targets() -> Array[Node]:
	var targets: Array[Node] = []
	if selected_nodes.size() > 1: targets = selected_nodes
	elif is_instance_valid(_ctx_node): targets.append(_ctx_node)
	return targets

func _fill_groups_tab(container: VBoxContainer) -> void:
	if not is_instance_valid(_ctx_node): return
	for g in _ctx_node.get_groups():
		var row := HBoxContainer.new(); container.add_child(row)
		var lbl := Label.new(); lbl.text = str(g); lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(lbl)
		var rm := Button.new(); rm.text = "✕"; rm.focus_mode = Control.FOCUS_NONE
		rm.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var cg = g
		rm.pressed.connect(func():
			for n in _get_targets(): if is_instance_valid(n): n.remove_from_group(cg)
			_show_context_menu(_ctx_node))
		row.add_child(rm)
	container.add_child(HSeparator.new())
	var add_row := HBoxContainer.new(); container.add_child(add_row)
	var input := LineEdit.new(); input.placeholder_text = "Group name..."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; add_row.add_child(input)
	var add_btn := Button.new(); add_btn.text = "Add"; add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.pressed.connect(func():
		var t := input.text.strip_edges()
		if t != "":
			for n in _get_targets(): if is_instance_valid(n): n.add_to_group(t, true)
			_show_context_menu(_ctx_node))
	add_row.add_child(add_btn)

func _fill_props_tab(container: VBoxContainer) -> void:
	if not is_instance_valid(_ctx_node): return
	var targets := _get_targets()
	_add_prop_row(container, "z_index", TYPE_INT, _ctx_node.get("z_index") if _ctx_node.get("z_index") != null else 0, targets, "z_index")
	var blend_row := HBoxContainer.new(); blend_row.add_theme_constant_override("separation", 6); container.add_child(blend_row)
	var blend_lbl := Label.new(); blend_lbl.text = "blend_mode"; blend_lbl.custom_minimum_size = Vector2(90, 0); blend_row.add_child(blend_lbl)
	var blend_opt := OptionButton.new()
	blend_opt.add_item("Mix", 0); blend_opt.add_item("Add", 1); blend_opt.add_item("Sub", 2)
	blend_opt.add_item("Mul", 3); blend_opt.add_item("PremAl", 4)
	blend_opt.focus_mode = Control.FOCUS_NONE
	if _ctx_node is CanvasItem and _ctx_node.material is CanvasItemMaterial:
		blend_opt.selected = _ctx_node.material.blend_mode
	blend_opt.item_selected.connect(func(idx: int):
		for n in targets:
			if not is_instance_valid(n): continue
			if not n is CanvasItem: continue
			var mat := CanvasItemMaterial.new()
			mat.resource_local_to_scene = true
			mat.blend_mode = idx
			n.material = mat)
	blend_row.add_child(blend_opt)
	container.add_child(HSeparator.new())
	if _ctx_node.get_script() == null:
		var lbl := Label.new(); lbl.text = "(no script)"; container.add_child(lbl); return
	var found := false
	for prop in _ctx_node.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		if prop["name"].begins_with("_"): continue
		found = true
		_add_prop_row(container, prop["name"], prop["type"], _ctx_node.get(prop["name"]), targets, prop["name"])
	if not found:
		var lbl := Label.new(); lbl.text = "(no exported variables)"; container.add_child(lbl)

func _add_prop_row(container: VBoxContainer, label_text: String, type: int, value: Variant, targets: Array[Node], prop_name: String) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); container.add_child(row)
	var lbl := Label.new(); lbl.text = label_text; lbl.custom_minimum_size = Vector2(90, 0)
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; row.add_child(lbl)
	_make_prop_editor(row, type, prop_name, value, targets)

func _get_first_visual(node: Node) -> Variant:
	if node is Sprite2D or node is TextureRect or node is AnimatedSprite2D: return node
	for child in node.get_children():
		if child is Sprite2D or child is TextureRect or child is AnimatedSprite2D: return child
	return null

func _make_prop_editor(row: HBoxContainer, type: int, prop_name: String, value: Variant, targets: Array[Node]) -> void:
	match type:
		TYPE_BOOL:
			var check := CheckButton.new(); check.button_pressed = bool(value)
			check.toggled.connect(func(v: bool): for n in targets: if is_instance_valid(n): n.set(prop_name, v))
			row.add_child(check)
		TYPE_INT:
			var edit := LineEdit.new(); edit.text = str(value); edit.custom_minimum_size = Vector2(80, 0)
			edit.text_submitted.connect(func(t: String): for n in targets: if is_instance_valid(n): n.set(prop_name, int(t)))
			row.add_child(edit)
		TYPE_FLOAT:
			var edit := LineEdit.new(); edit.text = str(value); edit.custom_minimum_size = Vector2(80, 0)
			edit.text_submitted.connect(func(t: String): for n in targets: if is_instance_valid(n): n.set(prop_name, float(t)))
			row.add_child(edit)
		TYPE_STRING:
			var edit := LineEdit.new(); edit.text = str(value); edit.custom_minimum_size = Vector2(120, 0)
			edit.text_submitted.connect(func(t: String): for n in targets: if is_instance_valid(n): n.set(prop_name, t))
			row.add_child(edit)
		TYPE_COLOR:
			var cpb := ColorPickerButton.new()
			if value is Color: cpb.color = value
			cpb.custom_minimum_size = Vector2(60, 24)
			cpb.color_changed.connect(func(c: Color): for n in targets: if is_instance_valid(n): n.set(prop_name, c))
			row.add_child(cpb)
		TYPE_VECTOR2:
			var v2 = value if value is Vector2 else Vector2.ZERO
			var ex := LineEdit.new(); ex.text = str(v2.x); ex.custom_minimum_size = Vector2(55, 0)
			ex.text_submitted.connect(func(t: String): for n in targets: if is_instance_valid(n): n.set(prop_name, Vector2(float(t), n.get(prop_name).y)))
			row.add_child(ex)
			var ey := LineEdit.new(); ey.text = str(v2.y); ey.custom_minimum_size = Vector2(55, 0)
			ey.text_submitted.connect(func(t: String): for n in targets: if is_instance_valid(n): n.set(prop_name, Vector2(n.get(prop_name).x, float(t))))
			row.add_child(ey)
		_:
			var lbl := Label.new(); lbl.text = str(value); row.add_child(lbl)

# ─── Overlay Draw ─────────────────────────────────────────────────────────────

func _on_overlay_draw() -> void:
	var vp         := get_viewport().get_visible_rect()
	var cam_offset := get_canvas_transform().origin
	var left := 0.0; var right  := vp.size.x
	var top  := 0.0; var bottom := vp.size.y
	var thin  := Color(1, 1, 1, 0.08); var thick := Color(1, 1, 1, 0.5)
	var gx := GRID * zoom_level; var gy := GRID * zoom_level

	var start_x := fmod(cam_offset.x, gx)
	if start_x > 0: start_x -= gx
	var x := start_x
	while x <= right:
		var is_axis: bool = abs(x - cam_offset.x) < 1.5
		_draw_node.draw_line(Vector2(x, top), Vector2(x, bottom), thick if is_axis else thin, 3.0 if is_axis else 1.0)
		x += gx

	var start_y := fmod(cam_offset.y, gy)
	if start_y > 0: start_y -= gy
	var y := start_y
	while y <= bottom:
		var is_axis: bool = abs(y - cam_offset.y) < 1.5
		_draw_node.draw_line(Vector2(left, y), Vector2(right, y), thick if is_axis else thin, 3.0 if is_axis else 1.0)
		y += gy

	if is_swiping and swipe_enabled:
		_draw_node.draw_rect(swipe_rect, Color(0.3, 1, 0.3, 0.2), true)
		_draw_node.draw_rect(swipe_rect, Color(0.3, 1, 0.3, 0.9), false, 1.5)

	if mode == Mode.PLACE and pending_scene_path != "":
		var snapped    := _snap_to_cell_center(get_global_mouse_position())
		var ct         := get_canvas_transform()
		var screen_pos := ct * snapped
		var half       := GRID * zoom_level / 2.0
		_draw_node.draw_rect(Rect2(screen_pos - Vector2(half, half), Vector2(half * 2, half * 2)), Color(0.3, 1, 0.3, 0.15), true)
		_draw_node.draw_rect(Rect2(screen_pos - Vector2(half, half), Vector2(half * 2, half * 2)), Color(0.3, 1, 0.3, 0.7), false, 2.0)

	for node in selected_nodes:
		if not is_instance_valid(node): continue
		var poly := _get_visual_screen_poly(node)
		if poly.size() < 4: continue
		_draw_node.draw_colored_polygon(poly, Color(0.3, 1, 0.3, 0.2))
		for i in range(4): _draw_node.draw_line(poly[i], poly[(i + 1) % 4], Color(0.3, 1, 0.3, 1.0), 2.0)

	if mode == Mode.FREE_MOVE and not is_free_dragging:
		var hover: Array[Node] = []
		for child in level.get_children():
			if _node_contains_point(child, get_global_mouse_position()): hover.append(child)
		if not hover.is_empty():
			var poly := _get_visual_screen_poly(hover[hover.size() - 1])
			if poly.size() >= 4:
				for i in range(4): _draw_node.draw_line(poly[i], poly[(i + 1) % 4], Color(1, 0.7, 0.1, 0.8), 2.0)

	# Draw group pivot point
	if use_group_pivot and selected_nodes.size() > 1:
		var ct := get_canvas_transform()
		var pivot_screen := ct * _get_group_center()
		_draw_node.draw_circle(pivot_screen, 7.0, Color(0.7, 0.1, 1.0, 0.9))
		_draw_node.draw_arc(pivot_screen, 7.0, 0, TAU, 24, Color(1, 1, 1, 0.8), 1.5)
		_draw_node.draw_line(pivot_screen - Vector2(10, 0), pivot_screen + Vector2(10, 0), Color(1, 1, 1, 0.8), 1.5)
		_draw_node.draw_line(pivot_screen - Vector2(0, 10), pivot_screen + Vector2(0, 10), Color(1, 1, 1, 0.8), 1.5)

# ─── Selection / Hit Detection / Visual Polygon ──────────────────────────────

func _first_visual(node: Node) -> Node:
	if node is Sprite2D and node.texture: return node
	if node is TextureRect: return node
	for child in node.get_children():
		if child is Sprite2D and child.texture: return child
		if child is TextureRect: return child
	return null

func _node_world_poly(node: Node) -> PackedVector2Array:
	var vis := _first_visual(node)
	if vis == null: return PackedVector2Array()

	if vis is Sprite2D:
		var sz: Vector2 = vis.texture.get_size()
		var gt: Transform2D = vis.get_global_transform()
		var corners: Array
		if vis.centered:
			corners = [Vector2(-sz.x/2.0, -sz.y/2.0), Vector2(sz.x/2.0, -sz.y/2.0),
					   Vector2(sz.x/2.0,  sz.y/2.0),  Vector2(-sz.x/2.0, sz.y/2.0)]
		else:
			corners = [Vector2.ZERO, Vector2(sz.x,0), sz, Vector2(0,sz.y)]
		var poly := PackedVector2Array()
		for c in corners: poly.append(gt * c)
		return poly

	if vis is TextureRect:
		var sz = vis.size if vis.size != Vector2.ZERO else (vis.texture.get_size() if vis.texture else Vector2.ZERO)
		if sz == Vector2.ZERO: return PackedVector2Array()
		var parent_gt := Transform2D.IDENTITY
		var p := vis.get_parent()
		while p != null:
			if p is Node2D:
				parent_gt = (p as Node2D).get_global_transform()
				break
			p = p.get_parent()
		var pv: Vector2 = vis.pivot_offset
		var poly := PackedVector2Array()
		for c in [Vector2.ZERO, Vector2(sz.x,0), sz, Vector2(0,sz.y)]:
			var lc: Vector2 = (c - pv) * vis.scale
			lc = lc.rotated(vis.rotation)
			lc += vis.position + pv
			poly.append(parent_gt * lc)
		return poly

	return PackedVector2Array()

func _world_to_screen_poly(world_poly: PackedVector2Array) -> PackedVector2Array:
	var ct := get_canvas_transform()
	var out := PackedVector2Array()
	for p in world_poly: out.append(ct * p)
	return out

func _get_visual_screen_poly(node: Node) -> PackedVector2Array:
	return _world_to_screen_poly(_node_world_poly(node))

# ─── Selection ────────────────────────────────────────────────────────────────

func _deselect_all() -> void:
	selected_nodes.clear(); last_candidates.clear()

func _handle_click(pos: Vector2) -> void:
	var candidates: Array[Node] = []
	for child in level.get_children():
		if _node_contains_point(child, pos): candidates.append(child)
	if candidates.is_empty(): _deselect_all(); return

	if selected_nodes.size() == 1 and selected_nodes[0] in candidates and candidates == last_candidates:
		cycle_index = (candidates.find(selected_nodes[0]) + 1) % candidates.size()
	else:
		cycle_index = 0

	if not swipe_enabled: selected_nodes.clear()
	last_candidates = candidates
	var picked := candidates[cycle_index]
	if picked not in selected_nodes:
		_push_undo()
		selected_nodes.append(picked)

func _finish_swipe(_pos: Vector2) -> void:
	var ct := get_canvas_transform()
	var world_rect := Rect2(ct.affine_inverse() * swipe_rect.position, swipe_rect.size / ct.get_scale())
	var added := false
	for child in level.get_children():
		var bounds := _get_node_bounds(child)
		if bounds != Rect2() and world_rect.intersects(bounds):
			if child not in selected_nodes:
				if not added: _push_undo(); added = true
				selected_nodes.append(child)

# ─── Hit Detection ────────────────────────────────────────────────────────────

func _node_contains_point(node: Node, world_pos: Vector2) -> bool:
	var wpoly := _node_world_poly(node)
	if wpoly.size() >= 4:
		return Geometry2D.is_point_in_polygon(world_pos, wpoly)
	return false

func _get_node_bounds(node: Node) -> Rect2:
	var wpoly := _node_world_poly(node)
	if wpoly.size() < 4: return Rect2()
	var mn := wpoly[0]; var mx := wpoly[0]
	for p in wpoly:
		mn.x = minf(mn.x, p.x); mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x); mx.y = maxf(mx.y, p.y)
	return Rect2(mn, mx - mn)

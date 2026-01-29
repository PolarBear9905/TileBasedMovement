extends CharacterBody2D

@export var move_speed : float = 100
@export var river_push_speed : float = 100
@export var starting_direction : Vector2 = Vector2(0,1)

@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")

@onready var tile_map: TileMapLayer = $"../TileMap/Base"
@onready var river_map: TileMapLayer = $"../TileMap/River"

var last_input_direction : Vector2 = Vector2.ZERO
var sliding = false

var _step_active := false
var _step_dir := Vector2.ZERO
var _step_remaining := 0.0
const _STEP_PIXELS := 16.0

# Queue steps of the player
const _MAX_QUEUE := 6
var _dir_queue: Array[Vector2] = []
var _last_pressed_dir := Vector2.ZERO

func _ready():
	update_animation_parameters(starting_direction)
	last_input_direction = starting_direction

func _physics_process(delta):
	sliding = is_on_ice()

	var river_dir = get_river_dir()
	var river_sliding = river_dir != Vector2.ZERO
	var force_slide = sliding or river_sliding

	_capture_queue_inputs()

	var input_direction = Vector2.ZERO

	# Force slide part
	if force_slide:
		_dir_queue.clear()
		_step_active = false
		_step_remaining = 0.0

		if river_sliding:
			input_direction = river_dir
			last_input_direction = river_dir
		elif sliding and last_input_direction != Vector2.ZERO:
			input_direction = last_input_direction
		else:
			input_direction = Vector2.ZERO

		update_animation_parameters(last_input_direction if force_slide else input_direction)

		if river_sliding:
			center_on_river(river_dir, delta)
			velocity = river_dir * river_push_speed
			move_and_slide()
		else:
			velocity = input_direction * move_speed
			move_and_slide()

		if get_slide_collision_count() > 0:
			last_input_direction = Vector2.ZERO

		pick_new_state(true)
		return

	if not _step_active:
		_try_start_step_from_queue_or_hold()

	if _step_active:
		input_direction = _step_dir
	else:
		input_direction = Vector2.ZERO

	update_animation_parameters(input_direction if input_direction != Vector2.ZERO else last_input_direction)

	if _step_active:
		var move_amount = min(move_speed * delta, _step_remaining)
		var motion = _step_dir * move_amount
		var col = move_and_collide(motion)

		if col:
			_step_active = false
			_step_remaining = 0.0
			velocity = Vector2.ZERO
			_dir_queue.clear()
		else:
			_step_remaining -= move_amount
			velocity = _step_dir * move_speed

			if _step_remaining <= 0.0:
				_step_active = false
				_step_remaining = 0.0
				velocity = Vector2.ZERO
				_try_start_step_from_queue_or_hold()
	else:
		velocity = Vector2.ZERO

	pick_new_state(false)

# Queue movement helper code
func _capture_queue_inputs():
	var d := _get_just_pressed_dir()
	if d != Vector2.ZERO:
		_last_pressed_dir = d
		if _dir_queue.size() < _MAX_QUEUE:
			_dir_queue.append(d)

func _try_start_step_from_queue_or_hold():
	var dir := Vector2.ZERO

	if _dir_queue.size() > 0:
		dir = _dir_queue.pop_front()
	else:
		dir = _get_held_dir()

	if dir != Vector2.ZERO:
		_step_active = true
		_step_dir = dir
		_step_remaining = _STEP_PIXELS
		last_input_direction = dir

func _get_just_pressed_dir() -> Vector2:
	if Input.is_action_just_pressed("left"):
		return Vector2(-1, 0)
	if Input.is_action_just_pressed("right"):
		return Vector2(1, 0)
	if Input.is_action_just_pressed("up"):
		return Vector2(0, -1)
	if Input.is_action_just_pressed("down"):
		return Vector2(0, 1)
	return Vector2.ZERO

# Holding down a key function
func _get_held_dir() -> Vector2:
	if _last_pressed_dir != Vector2.ZERO:
		if _last_pressed_dir == Vector2(-1, 0) and Input.is_action_pressed("left"):
			return _last_pressed_dir
		if _last_pressed_dir == Vector2(1, 0) and Input.is_action_pressed("right"):
			return _last_pressed_dir
		if _last_pressed_dir == Vector2(0, -1) and Input.is_action_pressed("up"):
			return _last_pressed_dir
		if _last_pressed_dir == Vector2(0, 1) and Input.is_action_pressed("down"):
			return _last_pressed_dir

	if Input.is_action_pressed("left"):
		return Vector2(-1, 0)
	if Input.is_action_pressed("right"):
		return Vector2(1, 0)
	if Input.is_action_pressed("up"):
		return Vector2(0, -1)
	if Input.is_action_pressed("down"):
		return Vector2(0, 1)

	return Vector2.ZERO

func is_on_ice() -> bool:
	if not tile_map: return false

	var current_tile = tile_map.local_to_map(global_position + Vector2(0, 4))
	var data = tile_map.get_cell_tile_data(current_tile)

	if data:
		return data.get_custom_data("is_ice")
	return false

func get_river_dir() -> Vector2:
	if not river_map:
		return Vector2.ZERO

	var current_tile = river_map.local_to_map(global_position)
	var data = river_map.get_cell_tile_data(current_tile)

	if data:
		if data.get_custom_data("river_down") == true:
			return Vector2(0, 1)
		if data.get_custom_data("river_right") == true:
			return Vector2(1, 0)
	return Vector2.ZERO

func center_on_river(river_dir: Vector2, delta: float):
	var tile_pos = river_map.local_to_map(global_position)
	var tile_center = river_map.map_to_local(tile_pos) + Vector2(6, 6)

	if river_dir.y != 0:
		global_position.x = lerp(global_position.x, tile_center.x, 5 * delta)

	if river_dir.x != 0:
		global_position.y = lerp(global_position.y, tile_center.y, 5 * delta)

func update_animation_parameters(move_input : Vector2):
	if move_input != Vector2.ZERO:
		animation_tree.set("parameters/Walk/blend_position", move_input)
		animation_tree.set("parameters/Idle/blend_position", move_input)

func pick_new_state(force_slide: bool):
	if velocity != Vector2.ZERO and not force_slide:
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")

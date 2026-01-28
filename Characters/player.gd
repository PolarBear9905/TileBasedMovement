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
const _STEP_PIXELS := 16.0   # 1 TILE = 16 PX

func _ready():
	update_animation_parameters(starting_direction)
	last_input_direction = starting_direction

func _physics_process(delta):
	sliding = is_on_ice()

	var river_dir = get_river_dir()
	var river_sliding = river_dir != Vector2.ZERO
	var force_slide = sliding or river_sliding

	var input_direction = Vector2.ZERO

	if river_sliding:
		input_direction = river_dir
		last_input_direction = river_dir
	elif sliding and last_input_direction != Vector2.ZERO:
		input_direction = last_input_direction
	else:
		if not _step_active:
			var dir = _get_step_dir()
			if dir != Vector2.ZERO:
				_step_active = true
				_step_dir = dir
				_step_remaining = _STEP_PIXELS
				last_input_direction = dir

		if _step_active:
			input_direction = _step_dir
		else:
			input_direction = Vector2.ZERO

	update_animation_parameters(last_input_direction if force_slide else input_direction)

	if river_sliding:
		center_on_river(river_dir, delta)
		velocity = river_dir * river_push_speed
		move_and_slide()
	else:
		if force_slide:
			velocity = input_direction * move_speed
			move_and_slide()
		else:
			if _step_active:
				var move_amount = min(move_speed * delta, _step_remaining)
				var motion = _step_dir * move_amount
				var col = move_and_collide(motion)

				if col:
					_step_active = false
					_step_remaining = 0.0
					velocity = Vector2.ZERO
				else:
					_step_remaining -= move_amount
					velocity = _step_dir * move_speed
					if _step_remaining <= 0.0:
						_step_active = false
						_step_remaining = 0.0
						velocity = Vector2.ZERO
			else:
				velocity = Vector2.ZERO

	if force_slide and get_slide_collision_count() > 0:
		last_input_direction = Vector2.ZERO

	pick_new_state(force_slide)

func _get_step_dir() -> Vector2:
	if Input.is_action_just_pressed("left"):
		return Vector2(-1, 0)
	if Input.is_action_just_pressed("right"):
		return Vector2(1, 0)
	if Input.is_action_just_pressed("up"):
		return Vector2(0, -1)
	if Input.is_action_just_pressed("down"):
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

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

func _ready():
	update_animation_parameters(starting_direction)
	last_input_direction = starting_direction
	
func _physics_process(_delta):
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
		var x = Input.get_axis("left", "right")
		var y = Input.get_axis("up", "down")
	
		if abs(x) >= abs(y):
			input_direction = Vector2(x, 0)
		else:
			input_direction = Vector2(0, y)
		
		if input_direction != Vector2.ZERO:
			last_input_direction = input_direction.normalized()
	
	update_animation_parameters(last_input_direction if force_slide else input_direction)
	
	if river_sliding:
		velocity = river_dir * river_push_speed
	else:
		velocity = input_direction * move_speed
	
	move_and_slide()
	
	if force_slide and get_slide_collision_count() > 0:
		last_input_direction = Vector2.ZERO
	
	pick_new_state(force_slide)
	
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
	
	var current_tile = river_map.local_to_map(global_position + Vector2(0, 4))
	var data = river_map.get_cell_tile_data(current_tile)
	
	if data:
		if data.get_custom_data("river_down") == true:
			return Vector2(0, 1)
		if data.get_custom_data("river_right") == true:
			return Vector2(1, 0)
	return Vector2.ZERO

func update_animation_parameters(move_input : Vector2):
	if(move_input != Vector2.ZERO):
		animation_tree.set("parameters/Walk/blend_position", move_input)
		animation_tree.set("parameters/Idle/blend_position", move_input)
		
func pick_new_state(force_slide: bool):
	if velocity != Vector2.ZERO and not force_slide:
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")

extends CharacterBody2D

@export var move_speed : float = 100
@export var starting_direction : Vector2 = Vector2(0,1)

@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")

# Using your specific node path
@onready var tile_map: TileMapLayer = $"../TileMap/Base"

var last_input_direction : Vector2 = Vector2.ZERO
var sliding = false 

func _ready():
	update_animation_parameters(starting_direction)
	last_input_direction = starting_direction
	
func _physics_process(_delta):
	sliding = is_on_ice()
	
	var input_direction = Vector2.ZERO
	
	# If we are on ice AND we haven't hit a wall yet
	if sliding and last_input_direction != Vector2.ZERO:
		input_direction = last_input_direction
	else:
		# Normal walking logic
		var x = Input.get_axis("left", "right")
		var y = Input.get_axis("up", "down")
	
		if abs(x) >= abs(y):
			input_direction = Vector2(x, 0)
		else:
			input_direction = Vector2(0, y)
		
		if input_direction != Vector2.ZERO:
			last_input_direction = input_direction.normalized()
	
	# Face the direction of travel
	update_animation_parameters(last_input_direction if sliding else input_direction)
	
	velocity = input_direction * move_speed
	
	# Move the player and check for collisions
	move_and_slide()
	
	# --- FIX FOR FACING THE TREE ---
	# If we are sliding but our 'real' movement stopped (we hit the tree)
	if sliding and get_slide_collision_count() > 0:
		last_input_direction = Vector2.ZERO # This stops the 'force' into the tree
	
	pick_new_state()
	
func is_on_ice() -> bool:
	if not tile_map: return false
	
	# Adjust (0, 4) if your player needs to be deeper into the tile to slide
	var current_tile = tile_map.local_to_map(global_position + Vector2(0, 4))
	var data = tile_map.get_cell_tile_data(current_tile)
	
	if data:
		return data.get_custom_data("is_ice")
	return false

func update_animation_parameters(move_input : Vector2):
	if(move_input != Vector2.ZERO):
		animation_tree.set("parameters/Walk/blend_position", move_input)
		animation_tree.set("parameters/Idle/blend_position", move_input)
		
func pick_new_state():
	# Only walk if we have actual velocity and aren't sliding
	if velocity != Vector2.ZERO and not sliding:
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")

extends Node2D

# Collection of packed scenes for each block type
@export var block_scenes : Array[PackedScene]
# Grey block that won't connect or pop
@export var grey_block_scene : PackedScene
# Size of the board, in blocks
@export var board_size := Vector2i(14, 18)
# Size of the blocks, in pixels
@export var block_size := Vector2i(32, 32)
# Initial fall speed for clump
@export var initial_fall_speed : float = 5
# How much to increase fall speed by
@export var fall_acceleration : float = 1
# How much to increase the fall speed by when holding down
@export var fall_speed_multiplier : float = 2
# Width of line to draw between blocks
@export var line_width : float = 5.0
# Chance of spawning a grey block
@export var grey_block_spawn_chance : float = 0.5
# Node that holds the next clump display's position
@export var next_clump_position : Node2D

# Timer that determines the amoount of time you can move the clump while it's on the floor
@onready var grace_timer = $"Grace Timer"

# Colors the blocks can be 
const COLORS = preload("res://Scenes/colors_enum.gd").colors
# States the game board can be in
enum states {CLUMP_FALLING, BLOCKS_FALLING, CHECKING_FOR_LOOPS}
# Current state
var state : int = states.CLUMP_FALLING
# Stores the dropped blocks, from left to right, top to bottom in that order
var board : Array[Block]
# Stores the four dropping blocks
var clump : Array[Block]
# Stores the next clump
var next_clump : Array[Block]
# Stores the position of the clump
var clump_position : Vector2
# Stores the falling blocks
var falling_blocks : Array[Block]
# Stores the blocks to erase from falling blocks array
var blocks_to_erase : Array[Block]
# Stores whether a loop has been found
var loop_found : bool = false
# Blocks to "pop" or remove from board
var blocks_to_pop : Array[Block]
# Fall speed for clump
var fall_speed : float = initial_fall_speed

func _ready() -> void:
	randomize()
	initialize_board()
	initialize_clump()

func _process(delta: float) -> void:
	# Process inputs if the current state is CLUMP_FALLING
	if state == states.CLUMP_FALLING:
		# Process rotation input
		if Input.is_action_just_pressed("rotate_ccw"):
			rotate_CCW()
		if Input.is_action_just_pressed("rotate_cw"):
			rotate_CW()
		# Process movement input
		var movement = Vector2.DOWN
		if Input.is_action_just_pressed("ui_left"):
			movement += Vector2.LEFT
		if Input.is_action_just_pressed("ui_right"):
			movement += Vector2.RIGHT
		move_clump(movement, delta)
	# Make blocks fall if current state is BLOCKS_FALLING
	if state == states.BLOCKS_FALLING:
		mark_blocks_to_drop()
		if falling_blocks:
			drop_blocks(delta)
		else:
			state = states.CHECKING_FOR_LOOPS
	# Check for loops
	if state == states.CHECKING_FOR_LOOPS:
		check_for_loops()
		if blocks_to_pop:
			pop_blocks()
			state = states.BLOCKS_FALLING
		else:
			state = states.CLUMP_FALLING

func _draw() -> void:
	draw_board()
	draw_border()
	draw_clump()
	draw_next_clump()
	draw_falling_blocks()
	draw_connection_lines()

# Initializes the board to be empty, and of the proper length
func initialize_board() -> void:
	board = []
	board.resize(board_size.x * board_size.y)

# Initialize the clump
func initialize_clump() -> void:
	clump_position.x = int(board_size.x / 2) - 1
	clump_position.y = -2
	clump = fill_clump()
	next_clump = fill_clump()

# Initializes the clump, which stores blocks in a clockwise order starting at the top left corner
func reset_clump() -> void:
	clump_position.x = int(board_size.x / 2) - 1
	clump_position.y = -2
	clump = next_clump
	next_clump = fill_clump()

# Draw board of static blocks
func draw_board() -> void:
	for x in board_size.x:
		for y in board_size.y:
			if get_if_board_with_borders(Vector2i(x,y)):
				draw_texture(get_board(Vector2i(x,y)).texture, Vector2i(x * block_size.x, y * block_size.y))

# Draw border
func draw_border() -> void:
	draw_rect(Rect2(Vector2i(-1,-1), (board_size * block_size) + Vector2i(2,2)), Color.WHITE, false)

# Draw clump
func draw_clump() -> void:
	draw_texture(clump[0].texture, Vector2(clump_position.x * block_size.x, clump_position.y * block_size.y))
	draw_texture(clump[1].texture, Vector2((clump_position.x + 1) * block_size.x, clump_position.y * block_size.y))
	draw_texture(clump[2].texture, Vector2((clump_position.x + 1) * block_size.x, (clump_position.y + 1) * block_size.y))
	draw_texture(clump[3].texture, Vector2(clump_position.x * block_size.x, (clump_position.y + 1) * block_size.y))

# Draw next clump display
func draw_next_clump() -> void:
	draw_texture(next_clump[0].texture, next_clump_position.position)
	draw_texture(next_clump[1].texture, next_clump_position.position + Vector2(block_size.x, 0))
	draw_texture(next_clump[2].texture, next_clump_position.position + Vector2(block_size.x, block_size.y))
	draw_texture(next_clump[3].texture, next_clump_position.position + Vector2(0, block_size.y))

# Draw any falling blocks
func draw_falling_blocks() -> void:
	if falling_blocks:
		for block in falling_blocks:
			draw_texture(block.texture, Vector2(block.pos.x * block_size.x, block.pos.y * block_size.y))
		queue_redraw()

# Draw lines that connect blocks
func draw_connection_lines() -> void:
	for x in board_size.x:
		for y in board_size.y:
			if get_if_board_with_borders(Vector2i(x, y)):
				if get_board(Vector2i(x, y)).color != COLORS.GREY:
					var line_color = get_board(Vector2i(x, y)).line_color
					# Check and draw lines for matching block to the right
					if get_if_board_without_borders(Vector2i(x + 1, y)):
						var right_block = get_board(Vector2i(x + 1, y))
						if line_color == right_block.line_color:
							var starting_block_midpoint = Vector2((x * block_size.x) + (block_size.x / 2), (y * block_size.y) + (block_size.y / 2))
							var ending_block_midpoint = Vector2(((x + 1) * block_size.x) + (block_size.x / 2), (y * block_size.y) + (block_size.y / 2))
							draw_line(starting_block_midpoint, ending_block_midpoint,line_color, line_width)
					# Check and draw lines for matching block below
					if get_if_board_without_borders(Vector2i(x, y + 1)):
						var below_block = get_board(Vector2i(x, y + 1))
						if line_color == below_block.line_color:
							var starting_block_midpoint = Vector2((x * block_size.x) + (block_size.x / 2), (y * block_size.y) + (block_size.y / 2))
							var ending_block_midpoint = Vector2((x * block_size.x) + (block_size.x / 2), ((y + 1) * block_size.y) + (block_size.y / 2))
							draw_line(starting_block_midpoint, ending_block_midpoint,line_color, line_width)

# Return a filled array of 4 blocks for use as a clump
func fill_clump() -> Array[Block]:
	var block_array : Array[Block] = []
	var random : float = randf()
	# Case if no grey block spawned
	if random > grey_block_spawn_chance:
		for i in range(4):
			var random_block : int = randi_range(0, block_scenes.size() - 1)
			block_array.append(block_scenes[random_block].instantiate())
	# Case if grey block spawned
	else:
		# Spawn one grey block in a random position
		var spawn_num = randi_range(0, 3)
		for i in range(4):
			if i == spawn_num:
				block_array.append(grey_block_scene.instantiate())
			else:
				var random_block : int = randi_range(0, block_scenes.size() - 1)
				block_array.append(block_scenes[random_block].instantiate())
	return block_array

# Check for loops of blocks in the board
func check_for_loops() -> void:
	for x in board_size.x:
		for y in board_size.y:
			if get_if_board_without_borders(Vector2i(x, y)):
				if not get_board(Vector2i(x, y)).visited:
					if get_board(Vector2i(x,y)).color != COLORS.GREY:
						var path : Array[Block] = []
						search(get_board(Vector2i(x, y)), get_board(Vector2i(x, y)), path)
						if loop_found:
							handle_loop(path)
						loop_found = false
	reset_visited()

# Do a depth first search recursively to find loops
func search(current_block : Block, previous_block : Block, path : Array) -> void:
	path.append(current_block)
	current_block.visited = true
	var current_position = Vector2i(current_block.pos)
	var current_color = previous_block.color
	var neighbors : Array[Vector2i] = [
		current_position + Vector2i.UP,
		current_position + Vector2i.RIGHT,
		current_position + Vector2i.DOWN,
		current_position + Vector2i.LEFT
	]
	for neighbor in neighbors:
		if get_if_board_without_borders(neighbor):
			var block : Block = get_board(neighbor)
			if block != previous_block and block.color == current_color:
				if block.visited:
					loop_found = true
				else:
					search(block, current_block, path)

# What to do when a loop is found
func handle_loop(path : Array[Block]) -> void:
	print("loop found: ")
	print(path)
	blocks_to_pop.append_array(path)

# Pop blocks on board, handle score, etc
func pop_blocks() -> void:
	for block in blocks_to_pop:
		remove_from_board(block.pos)
	blocks_to_pop = []
	queue_redraw()

# Reset board's visited tags
func reset_visited() -> void:
	for block in board:
		if block:
			block.visited = false

# Returns whether a block is present in the passed board position or not
func get_if_board_with_borders(board_position : Vector2i) -> bool:
	if board_position.x < 0 or board_position.x >= board_size.x or board_position.y >= board_size.y:
		return true
	elif get_board(board_position):
		return true
	else:
		return false

# Returns whether a block exists on board without concern for block borders
func get_if_board_without_borders(board_position : Vector2i) -> bool:
	if board_position.x < 0 or board_position.x >= board_size.x or board_position.y >= board_size.y:
		return false
	elif get_board(board_position):
		return true
	else:
		return false

# Returns the block corresponding to the grid position, or null if nothing's there
func get_board(board_position : Vector2i) -> Block:
	return board[board_position.x + board_position.y * board_size.x]

# Sets the grid position to the passed block, returns false if there's already a block there
func set_board(board_position : Vector2i, block : Block) -> bool:
	if not get_board(board_position):
		board[board_position.x + board_position.y * board_size.x] = block
		block.pos = board_position
		return true
	else:
		return false

# Remove block from board given grid position
func remove_from_board(board_position : Vector2i) -> void:
	if get_board(board_position):
		var block = board[board_position.x + board_position.y * board_size.x]
		print(block.color)
		board[board_position.x + board_position.y * board_size.x] = null
		block.queue_free()

# Moves the clump based on the direction passed in
func move_clump(direction : Vector2i, delta : float) -> void:
	# Check horizontal movement
	var test_position = clump_position
	# Test for left movement
	if direction.x < 0:
		test_position.x -= 1
		if get_if_board_with_borders(Vector2i(floori(test_position.x), ceili(test_position.y) + 1)):
			test_position = clump_position
	# Test for right movement
	if direction.x > 0:
		test_position.x += 1
		if get_if_board_with_borders(Vector2i(floori(test_position.x + 1), ceili(test_position.y) + 1)):
			test_position = clump_position
	# Check vertical movement
	if Input.is_action_pressed("ui_down"):
		test_position.y = clump_position.y + (direction.y * fall_speed * fall_speed_multiplier * delta)
	else:
		test_position.y = clump_position.y + (direction.y * fall_speed * delta)
	# Check left block
	if get_if_board_with_borders(Vector2i(floori(test_position.x), ceili(test_position.y + 1))):
		test_position.y = ceili(clump_position.y)
	# Check right block
	if get_if_board_with_borders(Vector2i(floori(test_position.x + 1), ceili(test_position.y + 1))):
		test_position.y = ceili(clump_position.y)
	# Check if there's no vertical movement
	if (test_position.y == clump_position.y) and grace_timer.is_stopped():
		grace_timer.start()
	elif (test_position.y != clump_position.y):
		grace_timer.stop()
	# Finish movement
	clump_position = test_position
	queue_redraw()

# Set up blocks to fall
func mark_blocks_to_drop() -> void:
	for x in range(board_size.x - 1, -1, -1):
		for y in range(board_size.y - 1, -1, -1):
			if not get_if_board_with_borders(Vector2i(x, y)):
				for y2 in range(y - 1, -1, -1):
					if get_if_board_with_borders(Vector2i(x, y2)):
						var block = get_board(Vector2i(x, y2))
						board[x + (y2 * board_size.x)] = null
						block.pos = Vector2(x, y2)
						falling_blocks.append(block)

# Drop down single blocks
func drop_blocks(delta : float) -> void:
	for block in falling_blocks:
		var test_position = block.pos
		test_position.y = block.pos.y + (fall_speed * fall_speed_multiplier * delta)
		if get_if_board_with_borders(Vector2i(floori(test_position.x), ceili(test_position.y))):
			test_position.y = ceili(block.pos.y)
			set_board(Vector2i(block.pos.x, ceili(block.pos.y)), block)
			blocks_to_erase.append(block)
		# Finish movement
		block.pos = test_position
	for block in blocks_to_erase:
		falling_blocks.erase(block)
	blocks_to_erase.clear()
	queue_redraw()

# Transfer the blocks from the clump to the board
func transfer_clump_blocks() -> void:
	state = states.BLOCKS_FALLING
	set_board(clump_position, clump[0])
	set_board(clump_position + Vector2(1,0), clump[1])
	set_board(clump_position + Vector2(1,1), clump[2])
	set_board(clump_position + Vector2(0,1), clump[3])
	reset_clump()
	mark_blocks_to_drop()

# Rotate clump clockwise
func rotate_CW() -> void:
	rotate_blocks(3)

# Rotate clump counter-clockwise
func rotate_CCW() -> void:
	rotate_blocks(1)

# Function that actually does the rotating
func rotate_blocks(starting_value: int) -> void:
	var blocks := []
	for block in clump:
		blocks.append(block)
	var counter := starting_value
	clump = []
	for block in range(4):
		clump.append(blocks[counter % 4])
		counter += 1

# Increase the fall speed of the clump
func increase_fall_speed() -> void:
	fall_speed += fall_acceleration

func _on_grace_timer_timeout():
	transfer_clump_blocks()

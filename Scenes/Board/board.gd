extends Node2D

# Collection of packed scenes for each block type
@export var block_scenes : Array[PackedScene]
# Size of the board, in blocks
@export var board_size := Vector2(8, 12)
# Size of the blocks, in pixels
@export var block_size := Vector2(32, 32)
# Initial fall speed for clump
@export var initial_fall_speed : float = 5
# How much to increase fall speed by
@export var fall_acceleration : float = 1
# How much to increase the fall speed by when holding down
@export var fall_speed_multiplier : float = 2

# Timer that determines the amoount of time you can move the clump while it's on the floor
@onready var grace_timer = $"Grace Timer"
# Node that holds the next clump
@onready var next_clump_position = $"Next Clump"

# Stores the dropped blocks, from left to right, top to bottom in that order
var board : Array
# Stores the four dropping blocks
var clump : Array
# Stores the next clump
var next_clump : Array
# Stores the position of the clump
var clump_position : Vector2
# Fall speed for clump
var fall_speed : float = initial_fall_speed

func _ready() -> void:
	randomize()
	initialize_board()
	initialize_clump()

func _process(delta: float) -> void:
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

func _draw() -> void:
	draw_board()
	draw_border()
	draw_clump()
	draw_next_clump()

# Initializes the board to be empty, and of the proper length
func initialize_board() -> void:
	board = []
	board.resize(board_size.x * board_size.y)

# Initialize the clump
func initialize_clump() -> void:
	clump_position.x = int(board_size.x / 2) - 1
	clump_position.y = -2
	clump = []
	for i in range(4):
		var random : int = randi_range(0, block_scenes.size() - 1)
		clump.append(block_scenes[random].instantiate())
	for i in range(4):
		var random : int = randi_range(0, block_scenes.size() - 1)
		next_clump.append(block_scenes[random].instantiate())

# Initializes the clump, which stores blocks in a clockwise order starting at the top left corner
func reset_clump() -> void:
	clump_position.x = int(board_size.x / 2) - 1
	clump_position.y = -2
	clump = next_clump
	next_clump = []
	for i in range(4):
		var random : int = randi_range(0, block_scenes.size() - 1)
		next_clump.append(block_scenes[random].instantiate())

# Draw board of static blocks
func draw_board() -> void:
	for x in board_size.x:
		for y in board_size.y:
			if get_if_board(Vector2i(x,y)):
				draw_texture(get_board(Vector2i(x,y)).texture, Vector2i(x * block_size.x, y * block_size.y))

# Draw border
func draw_border() -> void:
	draw_rect(Rect2(Vector2(-1,-1), (board_size * block_size) + Vector2(2,2)), Color.WHITE, false)

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

# Returns whether a block is present in the passed board position or not
func get_if_board(board_position : Vector2i) -> bool:
	if board_position.x < 0 or board_position.x >= board_size.x or board_position.y >= board_size.y:
		return true
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
		return true
	else:
		return false

# Moves the clump based on the direction passed in
func move_clump(direction : Vector2i, delta : float) -> void:
	# Check horizontal movement
	var test_position = clump_position
	# Test for left movement
	if direction.x < 0:
		test_position.x -= 1
		if get_if_board(Vector2i(floori(test_position.x), ceili(test_position.y) + 1)):
			test_position = clump_position
	# Test for right movement
	if direction.x > 0:
		test_position.x += 1
		if get_if_board(Vector2i(floori(test_position.x + 1), ceili(test_position.y) + 1)):
			test_position = clump_position
	# Check vertical movement
	if Input.is_action_pressed("ui_down"):
		test_position.y = clump_position.y + (direction.y * fall_speed * fall_speed_multiplier * delta)
	else:
		test_position.y = clump_position.y + (direction.y * fall_speed * delta)
	# Check left block
	if get_if_board(Vector2i(floori(test_position.x), ceili(test_position.y + 1))):
		test_position.y = ceili(clump_position.y)
	# Check right block
	if get_if_board(Vector2i(floori(test_position.x + 1), ceili(test_position.y + 1))):
		test_position.y = ceili(clump_position.y)
	# Check if there's no vertical movement
	if (test_position.y == clump_position.y) and grace_timer.is_stopped():
		grace_timer.start()
	elif (test_position.y != clump_position.y):
		grace_timer.stop()
	# Finish movement
	clump_position = test_position
	queue_redraw()

# Transfer the blocks from the clump to the board
func transfer_clump_blocks() -> void:
	set_board(clump_position, clump[0])
	set_board(clump_position + Vector2(1,0), clump[1])
	set_board(clump_position + Vector2(1,1), clump[2])
	set_board(clump_position + Vector2(0,1), clump[3])
	reset_clump()

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

# Check for hanging blocks and drop them
#func check_for_hanging_blocks():
#	for x in range(board_size.x):
#		for y in range(board_size.y - 1, -1, -1):
#			if not get_if_board(Vector2i(x, y)):
#				var bottom_empty = Vector2i(x, y)
#				for y2 in range(y - 1, -1, -1):
#					if get_if_board(x, y2):
#						var tween = create_tween()
#						tween.tween_property()
				


# Increase the fall speed of the clump
func increase_fall_speed() -> void:
	fall_speed += fall_acceleration

func _on_grace_timer_timeout():
	transfer_clump_blocks()

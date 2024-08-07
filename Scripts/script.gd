extends Node2D

# Grid size
var grid_width = 20
var grid_height = 20

# Tile IDs
const PATH_TILE_ID = 0
const CAMPFIRE_TILE_ID = 1

@onready var path_tilemap = $PathTileMap
@onready var campfire_tilemap = $PathTileMap

func _ready():
	print("Starting generation...")
	randomize()
	await generate_loop_path()
	print("Generation completed.")

func generate_loop_path() -> void:
	if path_tilemap == null:
		print("PathTileMap not found.")
		return
	if campfire_tilemap == null:
		print("CampfireTileMap not found.")
		return

	print("TileMap nodes found.")
	
	# Initialize grid
	var map_grid = []
	for i in range(grid_width):
		map_grid.append([])
		for j in range(grid_height):
			map_grid[i].append(0)

	print("Grid initialized.")

	# Starting position (more centered)
	var start_x = randi() % 5 + 8
	var start_y = randi() % 5 + 8
	var x = start_x
	var y = start_y
	map_grid[x][y] = 1
	campfire_tilemap.set_cell(0, Vector2i(x, y), CAMPFIRE_TILE_ID, Vector2i(0, 0), 0)

	print("Starting position: ", x, y)

	# Generate the loop path
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]  # Left, right, up, down
	var path_stack = [Vector2(x, y)]
	var loop_created = false
	var max_path_length = 50
	var next_x = x
	var next_y = y

	while not loop_created and path_stack.size() > 0:
		var current = path_stack[path_stack.size() - 1]
		x = int(current.x)
		y = int(current.y)

		var valid_directions = get_valid_directions(map_grid, x, y)

		if valid_directions.size() == 0:
			path_stack.pop_back()
			continue

		valid_directions.shuffle() # Shuffle to add randomness
		for direction in valid_directions:
			next_x = x + int(direction.x) * 2
			next_y = y + int(direction.y) * 2

			if is_within_bounds(next_x, next_y) and map_grid[next_x][next_y] == 0 and map_grid[x + int(direction.x)][y + int(direction.y)] == 0:
				if not will_block_loop(map_grid, next_x, next_y):
					map_grid[next_x][next_y] = 1
					map_grid[x + int(direction.x)][y + int(direction.y)] = 1
					path_tilemap.set_cell(0, Vector2i(next_x, next_y), PATH_TILE_ID, Vector2i(0, 1), 0)
					path_tilemap.set_cell(0, Vector2i(x + int(direction.x), y + int(direction.y)), PATH_TILE_ID, Vector2i(0, 1), 0)
					path_stack.append(Vector2(next_x, next_y))
					await get_tree().create_timer(0.1).timeout

					# Check for closed loop or if path length is greater than max_path_length
					if (abs(next_x - start_x) <= 2 and abs(next_y - start_y) <= 2 and path_stack.size() > 10) or path_stack.size() > max_path_length:
						# Try to connect back to campfire
						loop_created = connect_to_campfire(map_grid, path_tilemap, next_x, next_y, start_x, start_y)
						if loop_created:
							break
					break

	print("Path rendering completed.")
	# Ensure no dead ends remain
	remove_dead_ends(map_grid)
	return

func get_valid_directions(grid, x, y):
	var directions = []
	if is_within_bounds(x - 2, y) and grid[x - 2][y] == 0 and grid[x - 1][y] == 0:
		directions.append(Vector2(-1, 0))  # Left
	if is_within_bounds(x + 2, y) and grid[x + 2][y] == 0 and grid[x + 1][y] == 0:
		directions.append(Vector2(1, 0))  # Right
	if is_within_bounds(x, y - 2) and grid[x][y - 2] == 0 and grid[x][y - 1] == 0:
		directions.append(Vector2(0, -1))  # Up
	if is_within_bounds(x, y + 2) and grid[x][y + 2] == 0 and grid[x][y + 1] == 0:
		directions.append(Vector2(0, 1))  # Down
	return directions

func is_within_bounds(x, y):
	return x > 0 and x < grid_width - 1 and y > 0 and y < grid_height - 1

func connect_to_campfire(grid, tilemap, x, y, start_x, start_y):
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	for direction in directions:
		var next_x = x + int(direction.x)
		var next_y = y + int(direction.y)
		if is_within_bounds(next_x, next_y) and abs(next_x - start_x) <= 1 and abs(next_y - start_y) <= 1:
			grid[next_x][next_y] = 1
			tilemap.set_cell(0, Vector2i(next_x, next_y), PATH_TILE_ID, Vector2i(0, 1), 0)
			return true
	return false

func will_block_loop(grid, x, y):
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	var count = 0
	for direction in directions:
		var nx = x + int(direction.x)
		var ny = y + int(direction.y)
		if is_within_bounds(nx, ny) and grid[nx][ny] == 1:
			count += 1
	return count >= 2

func remove_dead_ends(grid):
	var changes_made = true
	while changes_made:
		changes_made = false
		for x in range(grid_width):
			for y in range(grid_height):
				if grid[x][y] == 1 and count_adjacent_paths(grid, x, y) == 1:
					grid[x][y] = 0
					path_tilemap.set_cell(0, Vector2i(x, y), -1)
					changes_made = true

func count_adjacent_paths(grid, x, y):
	var count = 0
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	for direction in directions:
		var nx = x + int(direction.x)
		var ny = y + int(direction.y)
		if is_within_bounds(nx, ny) and grid[nx][ny] == 1:
			count += 1
	return count

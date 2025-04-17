extends Control

@export var source_image: Texture2D

var cell_width: int
var grid: Array[Cell]


var _cell_rect := Rect2()
var _cell_color := Color()


func _ready() -> void:
	cell_width = int(size.x / Globals.GRID_SIZE)
	Tile.extract_tiles(source_image)
	
	for tile in Tile._tiles:
		tile.calculate_neighbors()
	
	init_grid()
	wfc()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0))
	
	for cell: Cell in grid:
		_show_cell(cell)
		cell.is_checked = false


func _process(delta: float) -> void:
	wfc()


func wfc() -> void:
	for cell: Cell in grid:
		cell.calculate_entropy()
	
	var min_entropy: float = INF;
	var lowest_entropy_cells: Array[Cell] = [];
	for cell: Cell in grid:
		if not cell.is_collapsed:
			if cell.entropy < min_entropy:
				min_entropy = cell.entropy
				lowest_entropy_cells = [cell]
			elif cell.entropy == min_entropy:
				lowest_entropy_cells.push_back(cell)
	
	if lowest_entropy_cells.size() == 0:
		set_physics_process(false)
		set_process(false)
		return
		

	var random_cell: Cell = lowest_entropy_cells.pick_random()
	random_cell.is_collapsed = true

	if random_cell.options.size() == 0:
		print ("ran into a conflict")
		init_grid()
		return
	
	var pick: int = random_cell.options.pick_random()

	random_cell.options = [pick]
	
	
	reduce_entropy(random_cell, 0)
	
	
	var mt := Mutex.new()
	
	var callable := func process_cell(p_index: int) -> void:
		mt.lock()
		
		var cell := grid[p_index]
		if cell.options.size() == 1:
			cell.is_collapsed = true
			reduce_entropy(cell, 0)
		mt.unlock()
	
	
	var group_id: int = WorkerThreadPool.add_group_task(callable, grid.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(group_id)

	#for cell: Cell in grid:
		#if cell.options.size() == 1:
			#cell.is_collapsed = true
			#reduce_entropy(cell, 0);
	
	queue_redraw()


func reduce_entropy_parallel(p_cell: Cell, p_depth: int) -> void:
	if (p_depth > Globals.MAX_RECURSION_DEPTH or p_cell.is_checked):
		return

	p_cell.is_checked = true
	const GRID_SIZE := Globals.GRID_SIZE
	var i := int(p_cell.index % GRID_SIZE)
	var j := int(float(p_cell.index) / GRID_SIZE)
	
	var task_ids := []
	
	if i + 1 < GRID_SIZE:
		var callable := func():
			var right_cell: Cell = grid[i + 1 + j * GRID_SIZE]
			if check_options(p_cell, right_cell, Tile.Direction.EAST):
				reduce_entropy_parallel(right_cell, p_depth + 1)
		
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			var id := WorkerThreadPool.add_task(callable, true, "i + i < GRID_SIZE")
			task_ids.push_back(id)
		else:
			callable.call()

	if i - 1 >= 0:
		var callable := func():
			var left_cell = grid[i - 1 + j * GRID_SIZE]
			if check_options(p_cell, left_cell, Tile.Direction.WEST):
				reduce_entropy_parallel(left_cell, p_depth + 1)
		
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			var id := WorkerThreadPool.add_task(callable, true, "i - 1 >= 0")
			task_ids.push_back(id)
		else:
			callable.call()

	if j + 1 < GRID_SIZE:
		var callable := func():
			var down_cell = grid[i + (j + 1) * GRID_SIZE]
			if check_options(p_cell, down_cell, Tile.Direction.SOUTH):
				reduce_entropy_parallel(down_cell, p_depth + 1)
		
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			var id := WorkerThreadPool.add_task(callable, true, "j + 1 < GRID_SIZE")
			task_ids.push_back(id)
		else:
			callable.call()

	if j - 1 >= 0:
		var callable := func():
			var up_cell = grid[i + (j - 1) * GRID_SIZE]
			if check_options(p_cell, up_cell, Tile.Direction.NORTH):
				reduce_entropy_parallel(up_cell, p_depth + 1)
		
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			var id := WorkerThreadPool.add_task(callable, true, "j - 1 >= 0")
			task_ids.push_back(id)
		else:
			callable.call()
	
	for id: int in task_ids:
		var error := WorkerThreadPool.wait_for_task_completion(id)
		if not error == OK:
			print("Task id=", id, " failed with error=", error)

func reduce_entropy(p_cell: Cell, p_depth: int) -> void:
	if (p_depth > Globals.MAX_RECURSION_DEPTH or p_cell.is_checked):
		return

	p_cell.is_checked = true
	const GRID_SIZE := Globals.GRID_SIZE
	var i := int(p_cell.index % GRID_SIZE)
	var j := int(float(p_cell.index) / GRID_SIZE)

	#if OS.get_thread_caller_id() == OS.get_main_thread_id():
	if i + 1 < GRID_SIZE:
		var right_cell: Cell = grid[i + 1 + j * GRID_SIZE]
		if check_options(p_cell, right_cell, Tile.Direction.EAST):
			reduce_entropy(right_cell, p_depth + 1)

	if i - 1 >= 0:
		var left_cell = grid[i - 1 + j * GRID_SIZE]
		if check_options(p_cell, left_cell, Tile.Direction.WEST):
			reduce_entropy(left_cell, p_depth + 1)

	if j + 1 < GRID_SIZE:
		var down_cell = grid[i + (j + 1) * GRID_SIZE]
		if check_options(p_cell, down_cell, Tile.Direction.SOUTH):
			reduce_entropy(down_cell, p_depth + 1)

	if j - 1 >= 0:
		var up_cell = grid[i + (j - 1) * GRID_SIZE]
		if check_options(p_cell, up_cell, Tile.Direction.NORTH):
			reduce_entropy(up_cell, p_depth + 1)




func check_options(p_cell: Cell, p_neighbor: Cell, p_direction: Tile.Direction) -> bool:
	if p_neighbor and not p_neighbor.is_collapsed:
		#var valid_options: Array = []
		var valid_options: Dictionary[int, bool] = {}
		for option: int in p_cell.options:
			for i: int in Tile._tiles[option].neighbors[p_direction]:
				valid_options[i] = true
			
			#valid_options.append_array()
		# Slow!
		p_neighbor.options = p_neighbor.options.filter(func filter_options(option: int) -> bool:
			return option in valid_options
		)
		return true
	
	return false


func init_grid() -> void:
	grid = []
	
	var count: int = 0
	
	for j: int in Globals.GRID_SIZE:
		for i: int in Globals.GRID_SIZE:
			grid.push_back(Cell.new(i * cell_width, j * cell_width, cell_width, count))
			count += 1


func _show_cell(p_cell: Cell) -> void:
	if p_cell.options.size() == 0:
		return
	
	if p_cell.is_collapsed:
		var tile_index: int = p_cell.options[0]
		var tile := Tile._tiles[tile_index]
		_render_cell_center(tile, p_cell.x, p_cell.y, p_cell.width)
		
		return
	
	_render_cell_average(p_cell)



func _render_cell_center(p_tile: Tile, p_x: int, p_y: int, p_width: int) -> void:
	var i: int = Globals.TILE_SIZE >> 1
	
	_cell_rect.position.x = p_x
	_cell_rect.position.y = p_y
	_cell_rect.size.x = p_width
	_cell_rect.size.y = p_width
	
	draw_rect(_cell_rect, p_tile.sub_region.get_pixel(i, i))


func _render_cell_average(p_cell: Cell) -> void:
	var sum_r: int = 0
	var sum_g: int = 0
	var sum_b: int = 0
	
	const TILE_SIZE: int = Globals.TILE_SIZE
	const CENTER_INDEX := TILE_SIZE >> 1
	
	var options_size := p_cell.options.size()
	#for i: int in p_cell.options.size():
	for option: int in p_cell.options:
		var center_color: Color = Tile._tiles[option].sub_region.get_pixel(CENTER_INDEX, CENTER_INDEX)
		
		sum_r += center_color.r8
		sum_g += center_color.g8
		sum_b += center_color.b8
	
	_cell_color.r8 = int(sum_r / options_size)
	_cell_color.g8 = int(sum_g / options_size)
	_cell_color.b8 = int(sum_b / options_size)
	
	_cell_rect.position.x = p_cell.x
	_cell_rect.position.y = p_cell.y
	_cell_rect.size.x = p_cell.width
	_cell_rect.size.y = p_cell.width
	
	draw_rect(_cell_rect, _cell_color, true)

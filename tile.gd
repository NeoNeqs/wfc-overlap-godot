class_name Tile
extends RefCounted

var sub_region: Image
var index: int

var frequency: int

var neighbors: Array[Array] # Array[Array[int]]

static var _tiles: Array[Tile]

enum Direction {
	EAST,
	WEST,
	NORTH,
	SOUTH
}


func _init(p_region: Image, p_index: int) -> void:
	sub_region = p_region
	index = p_index
	frequency = 1
	
	neighbors = []
	neighbors.resize(Direction.keys().size())
	
	for direction: Direction in Direction.values():
		neighbors[direction] = []


func calculate_neighbors() -> void:
	for i: int in _tiles.size():
		for direction: int in Direction.values():
			if is_overlapping(_tiles[i], direction):
				neighbors[direction].push_back(i)


func is_overlapping(p_other: Tile, p_direction: Direction) -> bool:
	if p_direction == Direction.EAST:
		for i: int in Vector2i(1, Globals.TILE_SIZE):
			for j: int in Vector2i(0, Globals.TILE_SIZE):
				if not sub_region.get_pixel(i, j) == p_other.sub_region.get_pixel(i - 1, j):
					return false
	elif p_direction == Direction.WEST:
		for i: int in Vector2i(0, Globals.TILE_SIZE - 1):
			for j: int in Vector2i(0, Globals.TILE_SIZE):
				if not sub_region.get_pixel(i, j) == p_other.sub_region.get_pixel(i + 1, j):
					return false
	elif p_direction == Direction.NORTH:
		for j: int in Vector2i(0, Globals.TILE_SIZE - 1):
			for i: int in Vector2i(0, Globals.TILE_SIZE):
				if not sub_region.get_pixel(i, j) == p_other.sub_region.get_pixel(i, j + 1):
					return false
	elif p_direction == Direction.SOUTH:
		for j: int in Vector2i(1, Globals.TILE_SIZE):
			for i: int in Vector2i(0, Globals.TILE_SIZE):
				if not sub_region.get_pixel(i, j) == p_other.sub_region.get_pixel(i, j - 1):
					return false
	
	return true


static func extract_tiles(p_source_texture: Texture2D) -> void:
	var unique_tiles: Dictionary[int, Tile] = {}
	
	var index_counter: int = 0
	for j: int in p_source_texture.get_height():
		for i: int in p_source_texture.get_width():
			#var sub_region := Rect2i(i, j, Globals.TILE_SIZE, Globals.TILE_SIZE)
			# TODO: Kepp Rect2i instead of Image in the Tile class. 
			#       Might just be faster to refrence the sub-region from the original file
			var sub_image: Image = copy_tile(p_source_texture.get_image(), i, j, Globals.TILE_SIZE)
			var image_hash: int = Array(sub_image.get_data()).hash()
			if image_hash not in unique_tiles:
				index_counter += 1
				unique_tiles[image_hash] = Tile.new(sub_image, index_counter)
			else:
				unique_tiles[image_hash].frequency += 1
	
	_tiles = unique_tiles.values()


static func copy_tile(p_source: Image, p_from_x: int, p_from_y: int, p_width: int) -> Image:
	var destination := Image.create_empty(p_width, p_width, false, Image.FORMAT_RGBA8)
	
	for j: int in p_width:
		for i: int in p_width:
			var wrapped_x: int = (p_from_x + i) % p_source.get_width()
			var wrapped_y: int = (p_from_y + j) % p_source.get_height()
			destination.set_pixel(i, j, p_source.get_pixel(wrapped_x, wrapped_y))
	
	return destination

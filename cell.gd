class_name Cell
extends RefCounted

const log2: float = log(2)

var x: int
var y: int
var width: int
var index: int
var options: Array
var is_collapsed: bool
var is_checked: bool
var entropy: float

var prev_total_options: int

func _init(p_x: int, p_y: int, p_width: int, p_index: int) -> void:
	x = p_x
	y = p_y
	width = p_width
	index = p_index
	
	options = range(Tile._tiles.size())
	
	is_checked = false
	is_collapsed = false
	
	prev_total_options = -1

 # OPTIMIZE
func calculate_entropy() -> void:
	if prev_total_options == options.size():
		return
	
	prev_total_options = options.size()
	
	var total_frequency: int = 0
	for option: int in options:
		total_frequency += Tile._tiles[option].frequency
	
	entropy = 0
	for option: int in options:
		var frequency := float(Tile._tiles[option].frequency)
		var probability := frequency / total_frequency
		entropy -= probability * (log(probability) / log2)

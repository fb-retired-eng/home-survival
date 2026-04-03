extends Node
class_name FogController

const FOG_MEMORY_CELL_SIZE := 80.0
const FOG_VISIT_RADIUS_CELLS := 1

var player
var hud
var player_camera
var _fog_home_world_position: Vector2 = Vector2.ZERO
var _fog_world_min: Vector2 = Vector2(-1280.0, -720.0)
var _fog_world_max: Vector2 = Vector2(3840.0, 2160.0)
var _fog_memory_image: Image
var _fog_memory_texture: ImageTexture
var _fog_memory_cells_x: int = 0
var _fog_memory_cells_y: int = 0
var _fog_last_revealed_cell: Vector2i = Vector2i(2147483647, 2147483647)


func configure(config: Dictionary) -> void:
	player = config.get("player")
	hud = config.get("hud")
	player_camera = config.get("player_camera")
	_fog_world_min = config.get("fog_world_min", _fog_world_min)
	_fog_world_max = config.get("fog_world_max", _fog_world_max)
	if player != null and is_instance_valid(player):
		_fog_home_world_position = player.global_position
	_initialize_fog_memory()
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_update_fog_memory()
	if hud == null or not is_instance_valid(hud):
		return
	if player == null or not is_instance_valid(player):
		return
	if player_camera == null or not is_instance_valid(player_camera):
		return
	var camera_screen_center: Vector2 = player_camera.get_screen_center_position()
	hud.set_home_fog_state(
		_fog_home_world_position,
		camera_screen_center,
		player_camera.zoom,
		get_viewport().get_visible_rect().size,
		_fog_memory_texture,
		_fog_world_min,
		_fog_world_max
	)


func get_save_state() -> Dictionary:
	if _fog_memory_image == null:
		return {}
	var png_bytes := _fog_memory_image.save_png_to_buffer()
	return {
		"image_base64": Marshalls.raw_to_base64(png_bytes),
		"last_revealed_cell": {
			"x": int(_fog_last_revealed_cell.x),
			"y": int(_fog_last_revealed_cell.y),
		},
	}


func apply_save_state(fog_state: Dictionary) -> void:
	if fog_state.is_empty():
		_initialize_fog_memory()
		return
	var encoded_image := String(fog_state.get("image_base64", ""))
	if encoded_image.is_empty():
		_initialize_fog_memory()
		return
	var image_bytes := Marshalls.base64_to_raw(encoded_image)
	var fog_image := Image.new()
	var error := fog_image.load_png_from_buffer(image_bytes)
	if error != OK:
		_initialize_fog_memory()
		return
	_fog_memory_cells_x = fog_image.get_width()
	_fog_memory_cells_y = fog_image.get_height()
	_fog_memory_image = fog_image
	_fog_memory_texture = ImageTexture.create_from_image(_fog_memory_image)
	var last_revealed: Dictionary = fog_state.get("last_revealed_cell", {})
	_fog_last_revealed_cell = Vector2i(
		int(last_revealed.get("x", 2147483647)),
		int(last_revealed.get("y", 2147483647))
	)


func _initialize_fog_memory() -> void:
	_fog_memory_cells_x = int((_fog_world_max.x - _fog_world_min.x) / FOG_MEMORY_CELL_SIZE)
	_fog_memory_cells_y = int((_fog_world_max.y - _fog_world_min.y) / FOG_MEMORY_CELL_SIZE)
	_fog_memory_image = Image.create(_fog_memory_cells_x, _fog_memory_cells_y, false, Image.FORMAT_RGBA8)
	_fog_memory_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_fog_memory_texture = ImageTexture.create_from_image(_fog_memory_image)
	_reveal_fog_at_world_position(_fog_home_world_position)


func _update_fog_memory() -> void:
	if player == null or not is_instance_valid(player):
		return
	_reveal_fog_at_world_position(player.global_position)


func _reveal_fog_at_world_position(world_position: Vector2) -> void:
	if _fog_memory_image == null:
		return
	var cell := _fog_world_position_to_cell(world_position)
	if cell == _fog_last_revealed_cell:
		return
	_fog_last_revealed_cell = cell
	for dx in range(-FOG_VISIT_RADIUS_CELLS, FOG_VISIT_RADIUS_CELLS + 1):
		for dy in range(-FOG_VISIT_RADIUS_CELLS, FOG_VISIT_RADIUS_CELLS + 1):
			var reveal_cell := Vector2i(cell.x + dx, cell.y + dy)
			if not _is_fog_cell_in_bounds(reveal_cell):
				continue
			_fog_memory_image.set_pixel(reveal_cell.x, reveal_cell.y, Color(1.0, 1.0, 1.0, 1.0))
	_fog_memory_texture = ImageTexture.create_from_image(_fog_memory_image)


func _fog_world_position_to_cell(world_position: Vector2) -> Vector2i:
	var local := world_position - _fog_world_min
	return Vector2i(floori(local.x / FOG_MEMORY_CELL_SIZE), floori(local.y / FOG_MEMORY_CELL_SIZE))


func _is_fog_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _fog_memory_cells_x and cell.y < _fog_memory_cells_y

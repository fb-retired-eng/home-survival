extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame


func _sample_fog_alpha(material: ShaderMaterial, world_position: Vector2, camera_position: Vector2, viewport_size: Vector2, camera_zoom: Vector2) -> float:
	var home_world_position_variant: Variant = material.get_shader_parameter("home_world_position")
	var fog_start_variant: Variant = material.get_shader_parameter("fog_start_distance")
	var fog_end_variant: Variant = material.get_shader_parameter("fog_end_distance")
	var fog_max_variant: Variant = material.get_shader_parameter("fog_max_alpha")
	var player_world_position_variant: Variant = material.get_shader_parameter("player_world_position")
	var player_clear_radius_variant: Variant = material.get_shader_parameter("player_clear_radius")
	var player_clear_fade_radius_variant: Variant = material.get_shader_parameter("player_clear_fade_radius")
	var reveal_texture_variant: Variant = material.get_shader_parameter("reveal_texture")
	var reveal_world_min_variant: Variant = material.get_shader_parameter("reveal_world_min")
	var reveal_world_max_variant: Variant = material.get_shader_parameter("reveal_world_max")
	if home_world_position_variant == null or fog_start_variant == null or fog_end_variant == null or fog_max_variant == null:
		return 0.0
	var home_world_position: Vector2 = home_world_position_variant
	var fog_start_distance: float = fog_start_variant
	var fog_end_distance: float = fog_end_variant
	var fog_max_alpha: float = fog_max_variant
	var player_world_position: Vector2 = Vector2.ZERO
	if player_world_position_variant != null:
		player_world_position = player_world_position_variant as Vector2
	var player_clear_radius: float = 0.0
	if player_clear_radius_variant != null:
		player_clear_radius = float(player_clear_radius_variant)
	var player_clear_fade_radius: float = player_clear_radius
	if player_clear_fade_radius_variant != null:
		player_clear_fade_radius = float(player_clear_fade_radius_variant)
	var revealed := false
	if reveal_texture_variant != null and reveal_world_min_variant != null and reveal_world_max_variant != null:
		var reveal_texture := reveal_texture_variant as Texture2D
		var reveal_world_min: Vector2 = reveal_world_min_variant
		var reveal_world_max: Vector2 = reveal_world_max_variant
		if reveal_texture != null:
			var reveal_image := reveal_texture.get_image()
			if reveal_image != null and reveal_image.get_width() > 0 and reveal_image.get_height() > 0:
				var reveal_span := reveal_world_max - reveal_world_min
				var reveal_uv := Vector2(
					clamp((world_position.x - reveal_world_min.x) / reveal_span.x, 0.0, 0.9999),
					clamp((world_position.y - reveal_world_min.y) / reveal_span.y, 0.0, 0.9999)
				)
				var reveal_x := int(floor(reveal_uv.x * float(reveal_image.get_width())))
				var reveal_y := int(floor(reveal_uv.y * float(reveal_image.get_height())))
				revealed = reveal_image.get_pixel(reveal_x, reveal_y).r >= 0.5
	if revealed:
		return 0.0
	var distance_from_home := world_position.distance_to(home_world_position)
	var fog_amount := 0.0
	if fog_end_distance > fog_start_distance:
		fog_amount = clamp((distance_from_home - fog_start_distance) / (fog_end_distance - fog_start_distance), 0.0, 1.0)
	var alpha := fog_amount * fog_max_alpha
	var distance_from_player := world_position.distance_to(player_world_position)
	if player_clear_fade_radius > player_clear_radius:
		var player_clear: float = clamp((distance_from_player - player_clear_radius) / (player_clear_fade_radius - player_clear_radius), 0.0, 1.0)
		alpha *= player_clear
	elif distance_from_player <= player_clear_radius:
		alpha = 0.0
	return alpha


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	var hud = game.hud
	var fog_overlay = hud.get_node("FogOverlay") as ColorRect
	var material := fog_overlay.material as ShaderMaterial
	var camera := game.player.get_node("Camera2D") as Camera2D
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var home_position: Vector2 = game.player.global_position
	var canvas_to_world: Transform2D = game.get_viewport().get_canvas_transform().affine_inverse()
	var screen_world_top_left: Vector2 = canvas_to_world * Vector2.ZERO
	var screen_world_bottom_right: Vector2 = canvas_to_world * viewport_size

	var home_alpha := _sample_fog_alpha(material, home_position, camera.get_screen_center_position(), viewport_size, camera.zoom)
	var far_position := Vector2(2355.0, 220.0)
	var far_alpha_before := _sample_fog_alpha(material, far_position, camera.get_screen_center_position(), viewport_size, camera.zoom)

	game.player.global_position = far_position
	await _wait_frames()
	canvas_to_world = game.get_viewport().get_canvas_transform().affine_inverse()
	screen_world_top_left = canvas_to_world * Vector2.ZERO
	screen_world_bottom_right = canvas_to_world * viewport_size
	var far_alpha_after_visit := _sample_fog_alpha(material, far_position, camera.get_screen_center_position(), viewport_size, camera.zoom)
	var player_alpha_after_move := _sample_fog_alpha(material, game.player.global_position, camera.get_screen_center_position(), viewport_size, camera.zoom)

	print("map_fog_probe_home_alpha=%.3f" % home_alpha)
	print("map_fog_probe_far_alpha_before_visit=%.3f" % far_alpha_before)
	print("map_fog_probe_far_alpha_after_visit=%.3f" % far_alpha_after_visit)
	print("map_fog_probe_player_alpha_after_move=%.3f" % player_alpha_after_move)
	print("map_fog_probe_overlay_visible=%s" % str(fog_overlay.visible))
	print("map_fog_probe_home_center=%s" % str(material.get_shader_parameter("home_world_position")))
	print("map_fog_probe_screen_world_top_left=%s" % str(material.get_shader_parameter("screen_world_top_left")))
	print("map_fog_probe_screen_world_bottom_right=%s" % str(material.get_shader_parameter("screen_world_bottom_right")))
	print("map_fog_probe_canvas_top_left=%s" % str(screen_world_top_left))
	print("map_fog_probe_canvas_bottom_right=%s" % str(screen_world_bottom_right))
	quit()

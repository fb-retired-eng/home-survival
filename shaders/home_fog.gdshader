shader_type canvas_item;
render_mode unshaded;

uniform vec2 home_world_position = vec2(1280.0, 720.0);
uniform vec2 camera_world_position = vec2(1280.0, 720.0);
uniform vec2 camera_zoom = vec2(1.0, 1.0);
uniform vec2 viewport_size = vec2(2560.0, 1440.0);
uniform sampler2D reveal_texture;
uniform vec2 reveal_world_min = vec2(-1280.0, -720.0);
uniform vec2 reveal_world_max = vec2(3840.0, 2160.0);
uniform float fog_start_distance = 720.0;
uniform float fog_end_distance = 1320.0;
uniform float fog_max_alpha = 0.82;
uniform float reveal_threshold = 0.5;
uniform vec4 fog_color : source_color = vec4(0.03, 0.05, 0.06, 1.0);


void fragment() {
	vec2 zoom = max(camera_zoom, vec2(0.001, 0.001));
	vec2 world_pos = camera_world_position + (SCREEN_UV - vec2(0.5, 0.5)) * viewport_size / zoom;
	float distance_from_home = distance(world_pos, home_world_position);
	float fog_amount = smoothstep(fog_start_distance, fog_end_distance, distance_from_home);
	float alpha = fog_amount * fog_max_alpha;
	vec2 reveal_span = max(reveal_world_max - reveal_world_min, vec2(0.001, 0.001));
	vec2 reveal_uv = clamp((world_pos - reveal_world_min) / reveal_span, vec2(0.0, 0.0), vec2(1.0, 1.0));
	float revealed = texture(reveal_texture, reveal_uv).r;
	if (revealed >= reveal_threshold) {
		alpha = 0.0;
	}
	COLOR = vec4(fog_color.rgb, alpha);
}

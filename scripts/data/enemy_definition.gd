extends Resource
class_name EnemyDefinition

@export var enemy_id: StringName = &"enemy"
@export var max_health: int = 50
@export var move_speed: float = 70.0
@export var player_damage: int = 10
@export var structure_damage: int = 10
@export var attack_interval: float = 1.0
@export var drop_salvage: int = 0
@export var drop_parts: int = 0
@export_range(0.0, 1.0, 0.01) var medicine_drop_chance: float = 0.0

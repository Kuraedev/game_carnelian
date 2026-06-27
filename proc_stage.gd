extends Node2D

## Procedurally generated stage. Generates terrain via the LevelGenerator TileMapLayer,
## then spawns the player at the start, enemies along the way, and the boss at the end.
## Experimental alternative to the hand-built main.tscn.

@export var player_scene: PackedScene
@export var melee_scene: PackedScene
@export var ranged_scene: PackedScene
@export var boss_scene: PackedScene
@export var enemy_count := 6
@export var level_seed := 0           ## 0 = random each run
@export var spawn_drop := 200.0       ## spawn this far above ground; gravity settles them
@export var ranged_hover := 420.0     ## height above ground for flying (ranged) enemies

@onready var generator: LevelGenerator = $TileMapLayer
@onready var kill_zone: Area2D = $KillZone

func _ready() -> void:
	GameManager.reset_run()
	generator.generate(level_seed)

	# Tell the crossfading background how wide the level is (for area transitions).
	var bg := get_node_or_null("AreaBackground")
	if bg:
		bg.level_width = generator.surface_world(generator.last_ground_column()).x

	kill_zone.position.y = generator.lowest_world_y() + 600.0
	kill_zone.body_entered.connect(_on_kill_zone_entered)

	_spawn_player()
	_spawn_enemies()
	_spawn_boss()

func _spawn_player() -> void:
	# Prefer the character chosen on the select screen; fall back to the scene's default.
	var scene := GameManager.selected_player_scene if GameManager.selected_player_scene else player_scene
	if scene == null:
		return
	var p := scene.instantiate()
	add_child(p)
	var col := generator.first_ground_column() + 2
	p.global_position = generator.surface_world(col) - Vector2(0, spawn_drop)

func _spawn_enemies() -> void:
	var points := generator.find_spawn_points(enemy_count)
	for i in points.size():
		var scene: PackedScene = melee_scene if i % 2 == 0 else ranged_scene
		if scene == null:
			continue
		var e := scene.instantiate()
		add_child(e)
		# Flying enemies hover well above the ground; grounded ones drop onto it.
		var lift := ranged_hover if e.get("flies") else spawn_drop * 0.6
		e.global_position = points[i] - Vector2(0, lift)

func _spawn_boss() -> void:
	if boss_scene == null:
		return
	var b := boss_scene.instantiate()
	add_child(b)
	var col := generator.boss_arena_center_column()
	b.global_position = generator.surface_world(col) - Vector2(0, spawn_drop)

func _on_kill_zone_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var hp: Health = body.get_node_or_null("Health")
		if hp:
			hp.take_damage(hp.max_health * 2.0)

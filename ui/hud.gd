extends CanvasLayer

## Screen-space HUD + meta overlays. Listens to GameManager signals for Pyroplasts/XP/level,
## binds the HP bar to the player's Health, and drives the level-up / stage-clear / death panels.
## Root process_mode is ALWAYS so the panels' buttons work while the tree is paused.

const UPGRADES := [
	{"stat": "max_hp", "amount": 25.0, "label": "+25 Max HP"},
	{"stat": "damage", "amount": 5.0, "label": "+5 Damage"},
	{"stat": "move_speed", "amount": 60.0, "label": "+60 Move Speed"},
	{"stat": "attack_speed", "amount": 0.15, "label": "+15% Attack Speed"},
]

@onready var health_bar: ProgressBar = $TopLeft/Stats/HealthBar
@onready var pyro_label: Label = $TopLeft/Stats/PyroLabel
@onready var level_label: Label = $TopLeft/Stats/LevelLabel
@onready var xp_bar: ProgressBar = $TopLeft/Stats/XPBar
@onready var levelup_panel: Control = $LevelUpPanel
@onready var stage_clear_panel: Control = $StageClearPanel
@onready var stage_clear_result: Label = $StageClearPanel/Center/Box/ResultLabel
@onready var death_panel: Control = $DeathPanel
@onready var levelup_buttons: Array = [
	$LevelUpPanel/Center/Box/Opt0,
	$LevelUpPanel/Center/Box/Opt1,
	$LevelUpPanel/Center/Box/Opt2,
]

var _current_options: Array = []

func _ready() -> void:
	levelup_panel.hide()
	stage_clear_panel.hide()
	death_panel.hide()

	GameManager.pyroplasts_changed.connect(_on_pyroplasts_changed)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up.connect(_on_level_up)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	GameManager.player_died.connect(_on_player_died)

	_on_pyroplasts_changed(GameManager.pyroplasts)
	_on_xp_changed(GameManager.xp, GameManager.xp_to_next, GameManager.level)

	for i in levelup_buttons.size():
		levelup_buttons[i].pressed.connect(_on_upgrade_chosen.bind(i))
	$StageClearPanel/Center/Box/RestartButton.pressed.connect(_restart)
	$DeathPanel/Center/Box/DeathRestart.pressed.connect(_restart)

	call_deferred("_bind_player_health")

func _bind_player_health() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0]
	var hp: Health = player.get_node_or_null("Health")
	if hp:
		hp.health_changed.connect(_on_health_changed)
		_on_health_changed(hp.current_health, hp.max_health)

func _on_health_changed(cur: float, mx: float) -> void:
	health_bar.max_value = mx
	health_bar.value = cur

func _on_pyroplasts_changed(total: int) -> void:
	pyro_label.text = "Pyroplasts: %d" % total

func _on_xp_changed(xp: int, to_next: int, level: int) -> void:
	level_label.text = "Level %d" % level
	xp_bar.max_value = to_next
	xp_bar.value = xp

func _on_level_up(_level: int) -> void:
	_current_options = UPGRADES.duplicate()
	_current_options.shuffle()
	_current_options = _current_options.slice(0, 3)
	for i in levelup_buttons.size():
		levelup_buttons[i].text = _current_options[i]["label"]
	levelup_panel.show()
	get_tree().paused = true

func _on_upgrade_chosen(index: int) -> void:
	var opt: Dictionary = _current_options[index]
	GameManager.apply_upgrade(opt["stat"], opt["amount"])
	levelup_panel.hide()
	get_tree().paused = false

func _on_stage_cleared(pyroplasts: int) -> void:
	stage_clear_result.text = "Pyroplasts collected: %d" % pyroplasts
	stage_clear_panel.show()
	get_tree().paused = true

func _on_player_died() -> void:
	death_panel.show()
	get_tree().paused = true

func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameManager.reset_run()
	get_tree().reload_current_scene()

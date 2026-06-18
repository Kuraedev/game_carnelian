extends Node

## Autoload singleton (registered as "GameManager" in project.godot).
## Owns the run-level meta state: Pyroplast currency, XP/level, owned artifacts,
## and the stage-clear / level-up signals the UI listens to.

signal pyroplasts_changed(total: int)
signal xp_changed(xp: int, xp_to_next: int, level: int)
signal level_up(level: int)
signal stage_cleared(pyroplasts: int)
signal player_died

var pyroplasts: int = 0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 10

## The active run's PlayerStats; upgrades/artifacts are applied here.
var player_stats: PlayerStats
var owned_artifacts: Array = []

func register_player_stats(stats: PlayerStats) -> void:
	player_stats = stats

func add_pyroplasts(n: int) -> void:
	pyroplasts += n
	pyroplasts_changed.emit(pyroplasts)

func add_xp(n: int) -> void:
	xp += n
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(xp_to_next * 1.5))
		level_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

## Apply a single stat upgrade chosen from the level-up panel.
func apply_upgrade(stat: String, amount: float) -> void:
	if player_stats:
		player_stats.apply_modifier(stat, amount)

## Apply an artifact's stat_modifiers dict (e.g. {"damage": 5, "max_hp": 20}).
func add_artifact(artifact: Resource) -> void:
	owned_artifacts.append(artifact)
	if player_stats and artifact and "stat_modifiers" in artifact:
		for stat in artifact.stat_modifiers:
			player_stats.apply_modifier(stat, artifact.stat_modifiers[stat])

func clear_stage() -> void:
	stage_cleared.emit(pyroplasts)

func notify_player_died() -> void:
	player_died.emit()

## Reset everything for a fresh run (called from stage-clear / death restart).
func reset_run() -> void:
	pyroplasts = 0
	level = 1
	xp = 0
	xp_to_next = 10
	owned_artifacts.clear()
	pyroplasts_changed.emit(pyroplasts)
	xp_changed.emit(xp, xp_to_next, level)

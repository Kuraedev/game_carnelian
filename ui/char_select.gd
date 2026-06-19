extends Control

## Character-select screen. Picking a fighter stores it on GameManager, resets the run,
## and loads the procedural stage (which spawns the chosen character).

const KY: PackedScene = preload("res://ky_player.tscn")
const BRIDGET: PackedScene = preload("res://bridget_player.tscn")

func _ready() -> void:
	$Center/Box/Chars/KyCol/Select.pressed.connect(_select.bind(KY))
	$Center/Box/Chars/BridgetCol/Select.pressed.connect(_select.bind(BRIDGET))
	$BackButton.pressed.connect(_on_back)
	$Center/Box/Chars/KyCol/Select.grab_focus()

func _select(scene: PackedScene) -> void:
	GameManager.selected_player_scene = scene
	GameManager.reset_run()
	get_tree().change_scene_to_file("res://proc_stage.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://ui/title.tscn")

extends Control

## Start screen. Start -> character select; Quit -> exit.

func _ready() -> void:
	$Center/Box/StartButton.pressed.connect(_on_start)
	$Center/Box/QuitButton.pressed.connect(_on_quit)
	$Center/Box/StartButton.grab_focus()

func _on_start() -> void:
	get_tree().change_scene_to_file("res://ui/char_select.tscn")

func _on_quit() -> void:
	get_tree().quit()

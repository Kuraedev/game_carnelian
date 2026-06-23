extends CanvasLayer

## Screen-space background that crossfades between area images as the player advances
## through the level. Being a CanvasLayer it's glued to the view (no world-space tiling,
## so no seams) and drawn at screen resolution (crisp). Behind everything (layer -10).

@export var images: Array[Texture2D] = []
## World X at which progress reaches the last image (set by the stage after generation).
@export var level_width := 32000.0

var _rects: Array[TextureRect] = []
var _player: Node2D

func _ready() -> void:
	for tex in images:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate.a = 0.0
		add_child(tr)
		_rects.append(tr)
	if not _rects.is_empty():
		_rects[0].modulate.a = 1.0

func _process(_delta: float) -> void:
	if _rects.size() < 2:
		return
	if _player == null:
		var ps := get_tree().get_nodes_in_group("player")
		if ps.is_empty():
			return
		_player = ps[0]
	var t := clampf(_player.global_position.x / maxf(1.0, level_width), 0.0, 1.0)
	var seg := t * float(_rects.size() - 1)
	var idx := int(floor(seg))
	var frac := seg - float(idx)
	for i in _rects.size():
		var a := 0.0
		if i == idx:
			a = 1.0 - frac
		elif i == idx + 1:
			a = frac
		_rects[i].modulate.a = a

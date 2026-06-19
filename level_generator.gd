extends TileMapLayer
class_name LevelGenerator

## Procedurally paints a side-scrolling platformer level into this TileMapLayer.
## Produces a continuous, jumpable ground line with height steps, occasional gaps,
## and floating platforms. Exposes helpers to find spawn points on solid ground.
##
## Uses a single solid tile (atlas 0:0 of ground_tileset.tres). Swap SOLID_ATLAS or add
## surface/variant tiles later for nicer visuals.

const SOURCE_ID := 0
const SOLID_ATLAS := Vector2i(0, 0)

@export var width_tiles := 400
@export var baseline_row := 35
@export var fill_depth := 14        ## solid rows painted below the surface
@export var min_row := 32
@export var max_row := 38
@export var max_step := 1           ## max surface height change between flat runs
@export var flat_min := 8
@export var flat_max := 16
@export var gap_chance := 0.06
@export var gap_min := 1
@export var gap_max := 2
## Floating overhead platforms — off by default (they tended to block movement).
@export var add_platforms := false
@export var platform_chance := 0.16
@export var spawn_safe_cols := 8    ## guaranteed flat ground at the start

var rng := RandomNumberGenerator.new()
## Per-column surface row; -1 marks a gap (no ground in that column).
var surface_rows: Array[int] = []

func generate(seed_value: int = 0) -> void:
	clear()
	surface_rows.clear()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var col := 0
	var row := baseline_row
	while col < width_tiles:
		var flat := rng.randi_range(flat_min, flat_max)
		for i in flat:
			if col >= width_tiles:
				break
			_paint_ground_column(col, row)
			col += 1

		if col > spawn_safe_cols and col < width_tiles - 12 and rng.randf() < gap_chance:
			var gap := rng.randi_range(gap_min, gap_max)
			for i in gap:
				if col >= width_tiles:
					break
				surface_rows.append(-1)
				col += 1

		row = clampi(row + rng.randi_range(-max_step, max_step), min_row, max_row)

	if add_platforms:
		_add_platforms()

func _paint_ground_column(col: int, surface_row: int) -> void:
	surface_rows.append(surface_row)
	for r in range(surface_row, surface_row + fill_depth):
		set_cell(Vector2i(col, r), SOURCE_ID, SOLID_ATLAS)

func _add_platforms() -> void:
	for col in range(10, surface_rows.size() - 6):
		if surface_rows[col] == -1:
			continue
		if rng.randf() < platform_chance:
			var plat_row := surface_rows[col] - rng.randi_range(6, 12)
			if plat_row < min_row - 8:
				continue
			var length := rng.randi_range(3, 6)
			for i in length:
				if col + i >= surface_rows.size():
					break
				set_cell(Vector2i(col + i, plat_row), SOURCE_ID, SOLID_ATLAS)

# --- spawn helpers ----------------------------------------------------------

## World position of the top surface of the ground in a column (entity feet rest here).
func surface_world(col: int) -> Vector2:
	col = clampi(col, 0, surface_rows.size() - 1)
	var row := surface_rows[col]
	if row == -1:
		row = baseline_row
	var local := map_to_local(Vector2i(col, row))
	return to_global(local) - Vector2(0, tile_set.tile_size.y * 0.5)

func first_ground_column() -> int:
	for c in surface_rows.size():
		if surface_rows[c] != -1:
			return c
	return 0

func last_ground_column() -> int:
	for c in range(surface_rows.size() - 1, -1, -1):
		if surface_rows[c] != -1:
			return c
	return surface_rows.size() - 1

func _nearest_ground_column(c: int) -> int:
	c = clampi(c, 0, surface_rows.size() - 1)
	for d in range(0, surface_rows.size()):
		if c - d >= 0 and surface_rows[c - d] != -1:
			return c - d
		if c + d < surface_rows.size() and surface_rows[c + d] != -1:
			return c + d
	return -1

## Evenly spaced ground positions for enemy spawning (avoids the start/end columns).
func find_spawn_points(count: int) -> Array:
	var points: Array = []
	if surface_rows.is_empty() or count <= 0:
		return points
	var step := int(float(width_tiles) / float(count + 1))
	for i in range(1, count + 1):
		var c := _nearest_ground_column(i * step)
		if c >= 0:
			points.append(surface_world(c))
	return points

## Lowest world Y any ground could reach — used to place the fall/kill zone safely below.
func lowest_world_y() -> float:
	var local := map_to_local(Vector2i(0, max_row + fill_depth))
	return to_global(local).y

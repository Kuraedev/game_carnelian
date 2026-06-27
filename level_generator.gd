extends TileMapLayer
class_name LevelGenerator

## Procedurally paints a side-scrolling platformer level into this TileMapLayer.
## Produces a continuous, jumpable ground line with height steps, occasional gaps,
## and floating platforms. Exposes helpers to find spawn points on solid ground.
##
## Paints a SURFACE tile on the top row of ground and random FILL tiles below for texture.
## All atlas coords are solid (opaque) tiles from the left half of TileSet1.png; tweak these
## to taste (they must also be defined with collision in ground_tileset.tres).

const SOURCE_ID := 0
# The ground is drawn by TILING a contiguous block of TileSet1.png (cols 15-20) so the
# texture flows instead of repeating one 16px box: a grass row on top, dirt body below.
const TERRAIN_X0 := 15      ## left column of the terrain block
const TERRAIN_W := 6        ## block width (columns) before it repeats horizontally
const GRASS_ROW := 44       ## tileset row used for the grassy surface
const DIRT_Y0 := 33         ## first dirt row below the surface
const DIRT_H := 8           ## dirt block height before it repeats vertically

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
@export var boss_arena_cols := 36   ## flat, gap-free arena at the end for the boss fight

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

	# Procedural terrain up to the boss arena.
	var arena_start := width_tiles - boss_arena_cols
	var col := 0
	var row := baseline_row
	while col < arena_start:
		var flat := rng.randi_range(flat_min, flat_max)
		for i in flat:
			if col >= arena_start:
				break
			_paint_ground_column(col, row)
			col += 1

		if col > spawn_safe_cols and col < arena_start - 12 and rng.randf() < gap_chance:
			var gap := rng.randi_range(gap_min, gap_max)
			for i in gap:
				if col >= arena_start:
					break
				surface_rows.append(-1)
				col += 1

		row = clampi(row + rng.randi_range(-max_step, max_step), min_row, max_row)

	# Flat, gap-free boss arena to the end (all at one row).
	var arena_row := clampi(row, min_row, max_row)
	while col < width_tiles:
		_paint_ground_column(col, arena_row)
		col += 1

	if add_platforms:
		_add_platforms()

## Center column of the flat boss arena (where the boss spawns).
func boss_arena_center_column() -> int:
	return clampi(width_tiles - int(boss_arena_cols / 2), 0, surface_rows.size() - 1)

func _paint_ground_column(col: int, surface_row: int) -> void:
	surface_rows.append(surface_row)
	var tx := TERRAIN_X0 + (col % TERRAIN_W)
	set_cell(Vector2i(col, surface_row), SOURCE_ID, Vector2i(tx, GRASS_ROW))
	var depth := 0
	for r in range(surface_row + 1, surface_row + fill_depth):
		set_cell(Vector2i(col, r), SOURCE_ID, Vector2i(tx, DIRT_Y0 + (depth % DIRT_H)))
		depth += 1

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
				set_cell(Vector2i(col + i, plat_row), SOURCE_ID, Vector2i(TERRAIN_X0 + ((col + i) % TERRAIN_W), GRASS_ROW))

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

## Evenly spaced ground positions for enemy spawning (between the spawn-safe start and the
## boss arena, so regular enemies don't crowd the arena).
func find_spawn_points(count: int) -> Array:
	var points: Array = []
	if surface_rows.is_empty() or count <= 0:
		return points
	var usable := width_tiles - boss_arena_cols - spawn_safe_cols
	var step := int(float(usable) / float(count + 1))
	for i in range(1, count + 1):
		var c := _nearest_ground_column(spawn_safe_cols + i * step)
		if c >= 0:
			points.append(surface_world(c))
	return points

## Lowest world Y any ground could reach — used to place the fall/kill zone safely below.
func lowest_world_y() -> float:
	var local := map_to_local(Vector2i(0, max_row + fill_depth))
	return to_global(local).y

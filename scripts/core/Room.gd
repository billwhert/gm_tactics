# Room.gd - Updated to support variable room sizes
extends Node2D
class_name Room

const TILE_SIZE = 64

# Make room dimensions variable
var ROOM_WIDTH = 12
var ROOM_HEIGHT = 8

var room_number: int
var cr_budget: int
var tiles: Array = []  # 2D array of tile types
var enemies: Array[Enemy] = []
var interactables: Array[Interactable] = []
var party_ref: Array[Hero] = []
var room_template: String = ""  # Track which template was used

# Tile types
enum TileType {
	FLOOR,
	WALL,
	PIT,
	HAZARD,
	DOOR
}

# Generate room using templates or procedural
func generate(room_num: int, party_level: int, use_template: bool = true):
	room_number = room_num
	cr_budget = party_level * 4
	
	if use_template:
		# Use pre-made room templates
		var templates = ["stone_12x8_A", "stone_12x8_B", "stone_12x8_C"]
		room_template = templates[room_num % templates.size()]
		
		var loaded_room = RoomLoader.create_room_from_template(room_template, room_num, party_level)
		if loaded_room:
			# Copy data from loaded room
			ROOM_WIDTH = loaded_room.ROOM_WIDTH
			ROOM_HEIGHT = loaded_room.ROOM_HEIGHT
			tiles = loaded_room.tiles
			enemies = loaded_room.enemies
			interactables = loaded_room.interactables
			return
	
	# Fallback to procedural generation
	generate_procedural(room_num, party_level)

func generate_procedural(room_num: int, party_level: int):
	# Original procedural generation code
	tiles = []
	for y in range(ROOM_HEIGHT):
		var row = []
		for x in range(ROOM_WIDTH):
			if x == 0 or x == ROOM_WIDTH - 1 or y == 0 or y == ROOM_HEIGHT - 1:
				row.append(TileType.WALL)
			else:
				row.append(TileType.FLOOR)
		tiles.append(row)
	
	add_room_features()
	spawn_enemies()
	spawn_interactables()

func add_room_features():
	# Add some pillars or obstacles for tactical positioning
	var num_features = randi_range(2, 4)
	for i in range(num_features):
		var x = randi_range(3, ROOM_WIDTH - 4)
		var y = randi_range(2, ROOM_HEIGHT - 3)
		if x < ROOM_WIDTH and y < ROOM_HEIGHT:
			tiles[y][x] = TileType.WALL
		
		# Sometimes make 2x2 obstacles
		if randf() > 0.5:
			if x < ROOM_WIDTH - 4 and y < ROOM_HEIGHT - 3:
				tiles[y][x+1] = TileType.WALL
				tiles[y+1][x] = TileType.WALL
				tiles[y+1][x+1] = TileType.WALL

func spawn_enemies():
	var spent_budget = 0
	var enemy_positions = []
	
	var enemy_templates = [
		{"name": "Goblin", "cr": 1, "hp": 7, "ac": 13, "damage": "1d6"},
		{"name": "Orc", "cr": 2, "hp": 15, "ac": 14, "damage": "1d8+2"},
		{"name": "Skeleton", "cr": 1, "hp": 10, "ac": 13, "damage": "1d6"},
		{"name": "Bandit", "cr": 1, "hp": 11, "ac": 12, "damage": "1d6+1"},
		{"name": "Wolf", "cr": 1, "hp": 9, "ac": 13, "damage": "2d4"},
	]
	
	while spent_budget < cr_budget:
		var available_templates = enemy_templates.filter(func(t): return t.cr <= cr_budget - spent_budget)
		if available_templates.is_empty():
			break
		
		var template = available_templates[randi() % available_templates.size()]
		var enemy = Enemy.create_from_template(template)
		
		var pos = find_enemy_spawn_position(enemy_positions)
		if pos.x != -1:
			enemy.grid_position = pos
			enemy_positions.append(pos)
			enemies.append(enemy)
			spent_budget += template.cr

func find_enemy_spawn_position(taken_positions: Array) -> Vector2i:
	for attempt in range(20):
		var x = randi_range(ROOM_WIDTH / 2, ROOM_WIDTH - 2)
		var y = randi_range(1, ROOM_HEIGHT - 2)
		var pos = Vector2i(x, y)
		
		if tiles[y][x] == TileType.FLOOR and not pos in taken_positions:
			return pos
	
	return Vector2i(-1, -1)

func spawn_interactables():
	var num_chests = randi_range(1, 3)
	
	for i in range(num_chests):
		var chest = Interactable.new()
		chest.type = "chest"
		chest.trap_chance = 0.25
		chest.mimic_chance = 0.1
		
		for attempt in range(20):
			var x = randi_range(2, ROOM_WIDTH - 2)
			var y = randi_range(1, ROOM_HEIGHT - 2)
			
			if tiles[y][x] == TileType.FLOOR and not has_entity_at(Vector2i(x, y)):
				chest.grid_position = Vector2i(x, y)
				interactables.append(chest)
				break

func has_entity_at(pos: Vector2i) -> bool:
	for enemy in enemies:
		if enemy.grid_position == pos:
			return true
	
	for interactable in interactables:
		if interactable.grid_position == pos:
			return true
	
	return false

func is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= ROOM_WIDTH or pos.y < 0 or pos.y >= ROOM_HEIGHT:
		return false
	
	return tiles[pos.y][pos.x] == TileType.FLOOR and not has_entity_at(pos)

func is_wall(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= ROOM_WIDTH or pos.y < 0 or pos.y >= ROOM_HEIGHT:
		return true
	
	return tiles[pos.y][pos.x] == TileType.WALL

func has_hazard(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= ROOM_WIDTH or pos.y < 0 or pos.y >= ROOM_HEIGHT:
		return false
	
	return tiles[pos.y][pos.x] == TileType.HAZARD or tiles[pos.y][pos.x] == TileType.PIT

func get_alive_enemies() -> Array[Enemy]:
	return enemies.filter(func(e): return e.is_alive())

func all_enemies_dead() -> bool:
	return get_alive_enemies().is_empty()

func get_enemies_within_range(from_pos: Vector2i, range: int) -> Array[Enemy]:
	var in_range = []
	for enemy in get_alive_enemies():
		var dist = abs(from_pos.x - enemy.grid_position.x) + abs(from_pos.y - enemy.grid_position.y)
		if dist <= range:
			in_range.append(enemy)
	return in_range

func get_party() -> Array[Hero]:
	return party_ref

func set_party(party: Array[Hero]):
	party_ref = party

func get_enemy_center() -> Vector2:
	if enemies.is_empty():
		return Vector2(ROOM_WIDTH / 2, ROOM_HEIGHT / 2)
	
	var sum = Vector2.ZERO
	var count = 0
	for enemy in get_alive_enemies():
		sum += Vector2(enemy.grid_position)
		count += 1
	
	return sum / count if count > 0 else Vector2(ROOM_WIDTH / 2, ROOM_HEIGHT / 2)

func get_context() -> Dictionary:
	return RoomContext.get_context(self, party_ref)

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < ROOM_WIDTH and pos.y >= 0 and pos.y < ROOM_HEIGHT

func has_hazard_at(pos: Vector2i) -> bool:
	return has_hazard(pos)

func get_tile_at(pos: Vector2i) -> TileType:
	if not is_valid_position(pos):
		return TileType.WALL
	return tiles[pos.y][pos.x]

func has_line_of_sight(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var diff = to_pos - from_pos
	var steps = max(abs(diff.x), abs(diff.y))
	
	if steps == 0:
		return true
	
	var step_x = float(diff.x) / float(steps)
	var step_y = float(diff.y) / float(steps)
	
	for i in range(1, steps):
		var check_x = int(from_pos.x + step_x * i)
		var check_y = int(from_pos.y + step_y * i)
		
		if tiles[check_y][check_x] == TileType.WALL:
			return false
	
	return true

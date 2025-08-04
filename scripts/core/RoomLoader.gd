# RoomLoader.gd - Loads pre-made room images and converts to game data
extends Node
class_name RoomLoader

# Room templates with their image paths and metadata
static var room_templates = {
	"stone_12x8_A": {
		"image": "res://rooms/stone_12x8_A.png",
		"width": 12,
		"height": 8,
		"doors": [
			{"position": Vector2i(6, 0), "direction": "north"},
			{"position": Vector2i(6, 7), "direction": "south"}
		],
		"spawn_areas": [
			{"type": "hero", "rect": Rect2i(1, 6, 4, 2)},
			{"type": "enemy", "rect": Rect2i(7, 1, 4, 6)},
			{"type": "chest", "positions": [Vector2i(2, 2), Vector2i(9, 5)]}
		]
	},
	"stone_12x8_B": {
		"image": "res://rooms/stone_12x8_B.png",
		"width": 12,
		"height": 8,
		"doors": [
			{"position": Vector2i(6, 7), "direction": "south"}
		],
		"spawn_areas": [
			{"type": "hero", "rect": Rect2i(5, 5, 2, 2)},
			{"type": "enemy", "rect": Rect2i(2, 1, 8, 4)},
			{"type": "chest", "positions": [Vector2i(5, 3)]}
		]
	},
	"stone_12x8_C": {
		"image": "res://rooms/stone_12x8_C.png",
		"width": 12,
		"height": 8,
		"doors": [
			{"position": Vector2i(0, 4), "direction": "west"},
			{"position": Vector2i(11, 4), "direction": "east"}
		],
		"spawn_areas": [
			{"type": "hero", "rect": Rect2i(1, 3, 2, 2)},
			{"type": "enemy", "rect": Rect2i(6, 2, 5, 4)},
			{"type": "chest", "positions": [Vector2i(5, 7)]}
		]
	}
}

# Load room from template
static func load_room_template(template_name: String) -> Dictionary:
	if not room_templates.has(template_name):
		push_error("Room template not found: " + template_name)
		return {}
	
	return room_templates[template_name]

# Parse room image to create tile data
static func parse_room_image(image_path: String, width: int, height: int) -> Array:
	var image = Image.load_from_file(image_path)
	if not image:
		push_error("Failed to load room image: " + image_path)
		return []
	
	# Create tile array
	var tiles = []
	for y in range(height):
		var row = []
		for x in range(width):
			# Sample pixel from center of each tile (accounting for 1-tile padding)
			var sample_x = (x + 1) * 64 + 32  # +1 for padding, +32 for center
			var sample_y = (y + 1) * 64 + 32
			
			var color = image.get_pixel(sample_x, sample_y)
			
			# Determine tile type based on color
			var tile_type = Room.TileType.FLOOR
			if color.r < 0.3 and color.g < 0.3 and color.b < 0.3:
				tile_type = Room.TileType.WALL
			
			row.append(tile_type)
		tiles.append(row)
	
	return tiles

# Create a Room instance from a template
static func create_room_from_template(template_name: String, room_number: int, party_level: int) -> Room:
	var template = load_room_template(template_name)
	if template.is_empty():
		return null
	
	var room = Room.new()
	room.room_number = room_number
	room.ROOM_WIDTH = template.width
	room.ROOM_HEIGHT = template.height
	
	# Parse the image to get tile data
	room.tiles = parse_room_image(template.image, template.width, template.height)
	
	# Set up doors
	for door_data in template.get("doors", []):
		var pos = door_data.position
		if pos.x >= 0 and pos.x < room.ROOM_WIDTH and pos.y >= 0 and pos.y < room.ROOM_HEIGHT:
			room.tiles[pos.y][pos.x] = Room.TileType.DOOR
	
	# Generate enemies based on spawn areas
	room.cr_budget = party_level * 4
	spawn_enemies_in_areas(room, template.get("spawn_areas", []))
	
	# Spawn chests
	spawn_chests_in_areas(room, template.get("spawn_areas", []))
	
	return room

static func spawn_enemies_in_areas(room: Room, spawn_areas: Array):
	var enemy_spawn_rect = Rect2i()
	
	# Find enemy spawn area
	for area in spawn_areas:
		if area.type == "enemy":
			enemy_spawn_rect = area.rect
			break
	
	if enemy_spawn_rect.size.x == 0:
		# No specific area, use right half of room
		enemy_spawn_rect = Rect2i(room.ROOM_WIDTH / 2, 1, room.ROOM_WIDTH / 2 - 1, room.ROOM_HEIGHT - 2)
	
	# Enemy templates
	var enemy_templates = [
		{"name": "Goblin", "cr": 1, "hp": 7, "ac": 13, "damage": "1d6"},
		{"name": "Orc", "cr": 2, "hp": 15, "ac": 14, "damage": "1d8+2"},
		{"name": "Skeleton", "cr": 1, "hp": 10, "ac": 13, "damage": "1d6"},
		{"name": "Bandit", "cr": 1, "hp": 11, "ac": 12, "damage": "1d6+1"},
		{"name": "Wolf", "cr": 1, "hp": 9, "ac": 13, "damage": "2d4"},
	]
	
	var spent_budget = 0
	var enemy_positions = []
	
	while spent_budget < room.cr_budget:
		var available_templates = enemy_templates.filter(func(t): return t.cr <= room.cr_budget - spent_budget)
		if available_templates.is_empty():
			break
		
		var template = available_templates[randi() % available_templates.size()]
		var enemy = Enemy.create_from_template(template)
		
		# Find position in spawn area
		var pos = find_spawn_position_in_rect(room, enemy_spawn_rect, enemy_positions)
		if pos.x != -1:
			enemy.grid_position = pos
			enemy_positions.append(pos)
			room.enemies.append(enemy)
			spent_budget += template.cr

static func spawn_chests_in_areas(room: Room, spawn_areas: Array):
	var chest_positions = []
	
	# Find chest spawn positions
	for area in spawn_areas:
		if area.type == "chest":
			chest_positions = area.positions
			break
	
	if chest_positions.is_empty():
		# Generate random positions
		var num_chests = randi_range(1, 3)
		for i in range(num_chests):
			for attempt in range(20):
				var x = randi_range(2, room.ROOM_WIDTH - 3)
				var y = randi_range(2, room.ROOM_HEIGHT - 3)
				var pos = Vector2i(x, y)
				
				if room.tiles[y][x] == Room.TileType.FLOOR and not room.has_entity_at(pos):
					chest_positions.append(pos)
					break
	
	# Create chests at positions
	for pos in chest_positions:
		if pos.x >= 0 and pos.x < room.ROOM_WIDTH and pos.y >= 0 and pos.y < room.ROOM_HEIGHT:
			if room.tiles[pos.y][pos.x] == Room.TileType.FLOOR and not room.has_entity_at(pos):
				var chest = Interactable.new()
				chest.type = "chest"
				chest.trap_chance = 0.25
				chest.mimic_chance = 0.1
				chest.grid_position = pos
				room.interactables.append(chest)

static func find_spawn_position_in_rect(room: Room, rect: Rect2i, taken_positions: Array) -> Vector2i:
	for attempt in range(20):
		var x = rect.position.x + randi() % rect.size.x
		var y = rect.position.y + randi() % rect.size.y
		var pos = Vector2i(x, y)
		
		if x >= 0 and x < room.ROOM_WIDTH and y >= 0 and y < room.ROOM_HEIGHT:
			if room.tiles[y][x] == Room.TileType.FLOOR and not pos in taken_positions:
				return pos
	
	return Vector2i(-1, -1)

# VisualRoomDisplay.gd - Displays room using pre-made images
extends Node2D
class_name VisualRoomDisplay

const TILE_SIZE = 64

var room: Room
var room_sprite: Sprite2D
var units_container: Node2D
var effects_container: Node2D
var grid_overlay: Node2D

var hero_sprites: Dictionary = {}
var enemy_sprites: Dictionary = {}
var chest_sprites: Dictionary = {}

func _ready():
	# Create containers
	room_sprite = Sprite2D.new()
	room_sprite.name = "RoomBackground"
	add_child(room_sprite)
	
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)
	
	units_container = Node2D.new()
	units_container.name = "Units"
	add_child(units_container)
	
	effects_container = Node2D.new()
	effects_container.name = "Effects"
	add_child(effects_container)

func display_room(new_room: Room):
	room = new_room
	clear_display()
	
	# Load and display the room background image
	if room.room_template != "":
		var template = RoomLoader.load_room_template(room.room_template)
		if template.has("image"):
			var texture = load(template.image)
			if texture:
				room_sprite.texture = texture
				# Position sprite accounting for 1-tile padding
				room_sprite.position = Vector2(-TILE_SIZE, -TILE_SIZE)
	
	# Draw grid overlay (optional)
	if true:  # Make this a setting
		draw_grid_overlay()
	
	# Spawn unit sprites
	spawn_unit_sprites()

func draw_grid_overlay():
	# Clear existing grid
	for child in grid_overlay.get_children():
		child.queue_free()
	
	# Draw grid lines
	for y in range(room.ROOM_HEIGHT + 1):
		var line = Line2D.new()
		line.add_point(Vector2(0, y * TILE_SIZE))
		line.add_point(Vector2(room.ROOM_WIDTH * TILE_SIZE, y * TILE_SIZE))
		line.width = 1.0
		line.default_color = Color(0.3, 0.3, 0.3, 0.3)
		grid_overlay.add_child(line)
	
	for x in range(room.ROOM_WIDTH + 1):
		var line = Line2D.new()
		line.add_point(Vector2(x * TILE_SIZE, 0))
		line.add_point(Vector2(x * TILE_SIZE, room.ROOM_HEIGHT * TILE_SIZE))
		line.width = 1.0
		line.default_color = Color(0.3, 0.3, 0.3, 0.3)
		grid_overlay.add_child(line)

func clear_display():
	# Clear sprites
	for sprite in hero_sprites.values():
		sprite.queue_free()
	for sprite in enemy_sprites.values():
		sprite.queue_free()
	for sprite in chest_sprites.values():
		sprite.queue_free()
	
	hero_sprites.clear()
	enemy_sprites.clear()
	chest_sprites.clear()
	
	# Clear effects
	for child in effects_container.get_children():
		child.queue_free()

func spawn_unit_sprites():
	# Heroes
	for hero in room.get_party():
		if hero.is_alive():
			var sprite = create_hero_sprite(hero)
			hero_sprites[hero] = sprite
			units_container.add_child(sprite)
	
	# Enemies
	for enemy in room.enemies:
		if enemy.is_alive():
			var sprite = create_enemy_sprite(enemy)
			enemy_sprites[enemy] = sprite
			units_container.add_child(sprite)
	
	# Chests
	for interactable in room.interactables:
		if interactable.type == "chest" and not interactable.opened:
			var sprite = create_chest_sprite(interactable)
			chest_sprites[interactable] = sprite
			units_container.add_child(sprite)

func create_hero_sprite(hero: Hero) -> Node2D:
	var container = Node2D.new()
	container.position = grid_to_world(hero.grid_position)
	
	# Create a circle for the hero
	var circle = ColorRect.new()
	circle.size = Vector2(TILE_SIZE * 0.6, TILE_SIZE * 0.6)
	circle.position = -circle.size / 2
	
	# Add rounded corners effect with a shader or just use color
	match hero.class_id:
		"fighter":
			circle.color = Color(0.8, 0.2, 0.2)  # Red
		"cleric":
			circle.color = Color(0.8, 0.8, 0.2)  # Yellow
		"rogue":
			circle.color = Color(0.5, 0.5, 0.8)  # Blue
		"wizard":
			circle.color = Color(0.8, 0.2, 0.8)  # Purple
		_:
			circle.color = Color(0.5, 0.5, 0.5)
	
	container.add_child(circle)
	
	# Add class initial
	var label = Label.new()
	label.text = hero.class_id.substr(0, 1).to_upper()
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-8, -12)
	container.add_child(label)
	
	# Add health bar
	var hp_bar = create_hp_bar(hero)
	container.add_child(hp_bar)
	
	return container

func create_enemy_sprite(enemy: Enemy) -> Node2D:
	var container = Node2D.new()
	container.position = grid_to_world(enemy.grid_position)
	
	# Create a diamond shape for enemies
	var rect = ColorRect.new()
	rect.size = Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	rect.position = -rect.size / 2
	rect.rotation_degrees = 45
	rect.color = Color(0.8, 0.3, 0.3)
	
	container.add_child(rect)
	
	# Add enemy type indicator
	var label = Label.new()
	label.text = enemy.enemy_name.substr(0, 1)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-6, -10)
	container.add_child(label)
	
	# Add health bar
	var hp_bar = create_hp_bar(enemy)
	container.add_child(hp_bar)
	
	return container

func create_chest_sprite(chest: Interactable) -> Node2D:
	var container = Node2D.new()
	container.position = grid_to_world(chest.grid_position)
	
	# Create chest rectangle
	var rect = ColorRect.new()
	rect.size = Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.4)
	rect.position = Vector2(-rect.size.x / 2, -rect.size.y / 2)
	rect.color = Color(0.6, 0.4, 0.2)  # Brown
	
	container.add_child(rect)
	
	# Add chest lid
	var lid = ColorRect.new()
	lid.size = Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.1)
	lid.position = Vector2(-lid.size.x / 2, -rect.size.y / 2 - lid.size.y)
	lid.color = Color(0.7, 0.5, 0.3)
	
	container.add_child(lid)
	
	return container

func create_hp_bar(unit) -> Control:
	var container = Control.new()
	container.position = Vector2(-20, -35)
	container.size = Vector2(40, 4)
	
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2)
	bg.size = container.size
	container.add_child(bg)
	
	var fill = ColorRect.new()
	fill.color = Color(0.8, 0.2, 0.2) if unit is Enemy else Color(0.2, 0.8, 0.2)
	fill.size = Vector2(container.size.x * (float(unit.current_hp) / float(unit.max_hp)), container.size.y)
	container.add_child(fill)
	
	# Connect to HP changes
	fill.set_meta("unit", unit)
	unit.hp_changed.connect(func(new_hp, max_hp): 
		fill.size.x = container.size.x * (float(new_hp) / float(max_hp))
	)
	
	return container

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE/2, grid_pos.y * TILE_SIZE + TILE_SIZE/2)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

# Animation functions
func animate_movement(unit, from_pos: Vector2i, to_pos: Vector2i):
	var sprite = get_sprite_for_unit(unit)
	if not sprite:
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", grid_to_world(to_pos), 0.3)

func animate_attack(attacker, target):
	var attacker_sprite = get_sprite_for_unit(attacker)
	var target_sprite = get_sprite_for_unit(target)
	
	if not attacker_sprite or not target_sprite:
		return
	
	# Quick lunge animation
	var original_pos = attacker_sprite.position
	var direction = (target_sprite.position - attacker_sprite.position).normalized()
	
	var tween = create_tween()
	tween.tween_property(attacker_sprite, "position", original_pos + direction * 20, 0.1)
	tween.tween_property(attacker_sprite, "position", original_pos, 0.1)
	
	# Flash target on hit
	tween.parallel().tween_property(target_sprite, "modulate", Color(2, 2, 2), 0.1)
	tween.tween_property(target_sprite, "modulate", Color.WHITE, 0.1)

func show_damage_number(position: Vector2, damage: int, is_heal: bool = false):
	var label = Label.new()
	label.text = str(damage)
	label.position = position
	label.modulate = Color.GREEN if is_heal else Color.RED
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	
	effects_container.add_child(label)
	
	# Animate floating up and fade
	var tween = create_tween()
	tween.tween_property(label, "position", position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func highlight_tiles(tiles: Array[Vector2i], color: Color):
	for tile_pos in tiles:
		var highlight = ColorRect.new()
		highlight.color = color
		highlight.color.a = 0.3
		highlight.position = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
		highlight.size = Vector2(TILE_SIZE, TILE_SIZE)
		effects_container.add_child(highlight)
		
		# Auto remove after delay
		var tween = create_tween()
		tween.tween_interval(1.0)
		tween.tween_callback(highlight.queue_free)

func highlight_valid_moves(unit, max_range: int):
	var valid_tiles = []
	var start_pos = unit.grid_position
	
	# Simple range check - could be improved with pathfinding
	for y in range(-max_range, max_range + 1):
		for x in range(-max_range, max_range + 1):
			var check_pos = start_pos + Vector2i(x, y)
			var distance = abs(x) + abs(y)  # Manhattan distance
			
			if distance <= max_range and room.is_walkable(check_pos):
				valid_tiles.append(check_pos)
	
	highlight_tiles(valid_tiles, Color(0.2, 0.8, 0.2))

func show_action_preview(hero: Hero, action_type: String):
	match action_type:
		"move":
			highlight_valid_moves(hero, hero.speed)
		"attack":
			var weapon_range = 1  # Get from weapon data
			highlight_tiles(get_tiles_in_range(hero.grid_position, weapon_range), Color(0.8, 0.2, 0.2))
		"heal":
			highlight_tiles(get_tiles_in_range(hero.grid_position, 3), Color(0.2, 0.8, 0.2))

func get_tiles_in_range(center: Vector2i, range: int) -> Array[Vector2i]:
	var tiles = []
	for y in range(-range, range + 1):
		for x in range(-range, range + 1):
			var check_pos = center + Vector2i(x, y)
			var distance = abs(x) + abs(y)
			
			if distance <= range and room.is_valid_position(check_pos):
				tiles.append(check_pos)
	
	return tiles

func get_sprite_for_unit(unit) -> Node2D:
	if unit is Hero:
		return hero_sprites.get(unit)
	elif unit is Enemy:
		return enemy_sprites.get(unit)
	return null

# GridDisplay.gd - Modified version without tileset requirement
extends Node2D
class_name GridDisplay

const TILE_SIZE = 64

var room: Room
var hero_sprites: Dictionary = {}
var enemy_sprites: Dictionary = {}
var chest_sprites: Dictionary = {}

# Visual containers
var tiles_container: Node2D
var units_container: Node2D
var effects_container: Node2D

func _ready():
	# Create containers
	tiles_container = Node2D.new()
	tiles_container.name = "Tiles"
	add_child(tiles_container)
	
	units_container = Node2D.new()
	units_container.name = "Units"
	add_child(units_container)
	
	effects_container = Node2D.new()
	effects_container.name = "Effects"
	add_child(effects_container)

func display_room(new_room: Room):
	room = new_room
	clear_display()
	draw_tiles()
	spawn_unit_sprites()

func clear_display():
	# Clear all children from containers
	for child in tiles_container.get_children():
		child.queue_free()
	for child in units_container.get_children():
		child.queue_free()
	for child in effects_container.get_children():
		child.queue_free()
	
	hero_sprites.clear()
	enemy_sprites.clear()
	chest_sprites.clear()

func draw_tiles():
	# Draw colored rectangles instead of tilemap for now
	for y in range(room.ROOM_HEIGHT):
		for x in range(room.ROOM_WIDTH):
			var tile_type = room.tiles[y][x]
			var tile_rect = ColorRect.new()
			tile_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
			tile_rect.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			
			match tile_type:
				Room.TileType.FLOOR:
					tile_rect.color = Color(0.5, 0.5, 0.5)
				Room.TileType.WALL:
					tile_rect.color = Color(0.2, 0.2, 0.2)
				Room.TileType.PIT:
					tile_rect.color = Color(0.1, 0.1, 0.3)
				Room.TileType.HAZARD:
					tile_rect.color = Color(0.8, 0.2, 0.2)
			
			tiles_container.add_child(tile_rect)

func spawn_unit_sprites():
	# Create simple colored squares for units
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
	
	# Create colored rectangle
	var rect = ColorRect.new()
	rect.size = Vector2(TILE_SIZE * 0.8, TILE_SIZE * 0.8)
	rect.position = -rect.size / 2
	
	# Color based on class
	match hero.class_id:
		"fighter":
			rect.color = Color(0.8, 0.2, 0.2)
		"cleric":
			rect.color = Color(0.8, 0.8, 0.2)
		"rogue":
			rect.color = Color(0.5, 0.5, 0.8)
		"wizard":
			rect.color = Color(0.8, 0.2, 0.8)
		_:
			rect.color = Color(0.5, 0.5, 0.5)
	
	container.add_child(rect)
	
	# Add health bar
	var hp_bar = create_hp_bar(hero)
	container.add_child(hp_bar)
	
	# Add name label
	var name_label = Label.new()
	name_label.text = hero.hero_name if hero.hero_name else hero.class_id
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.position = Vector2(-20, -40)
	container.add_child(name_label)
	
	return container

func create_enemy_sprite(enemy: Enemy) -> Node2D:
	var container = Node2D.new()
	container.position = grid_to_world(enemy.grid_position)
	
	# Create colored rectangle
	var rect = ColorRect.new()
	rect.size = Vector2(TILE_SIZE * 0.8, TILE_SIZE * 0.8)
	rect.position = -rect.size / 2
	rect.color = Color(0.8, 0.4, 0.4)  # Red tint for enemies
	
	container.add_child(rect)
	
	# Add health bar
	var hp_bar = create_hp_bar(enemy)
	container.add_child(hp_bar)
	
	# Add name label
	var name_label = Label.new()
	name_label.text = enemy.enemy_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.position = Vector2(-20, -40)
	container.add_child(name_label)
	
	return container

func create_chest_sprite(chest: Interactable) -> Node2D:
	var container = Node2D.new()
	container.position = grid_to_world(chest.grid_position)
	
	# Create colored rectangle
	var rect = ColorRect.new()
	rect.size = Vector2(TILE_SIZE * 0.6, TILE_SIZE * 0.6)
	rect.position = -rect.size / 2
	rect.color = Color(0.8, 0.6, 0.2)  # Gold color for chests
	
	container.add_child(rect)
	
	return container

# Rest of the methods remain the same...
func create_hp_bar(unit) -> Control:
	var container = Control.new()
	container.position = Vector2(-20, -30)
	container.size = Vector2(40, 6)
	
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2)
	bg.size = Vector2(40, 6)
	container.add_child(bg)
	
	var fill = ColorRect.new()
	fill.color = Color(0.8, 0.2, 0.2) if unit is Enemy else Color(0.2, 0.8, 0.2)
	fill.size = Vector2(40 * (float(unit.current_hp) / float(unit.max_hp)), 6)
	container.add_child(fill)
	
	# Store reference for updates
	fill.set_meta("unit", unit)
	unit.hp_changed.connect(func(new_hp, max_hp): 
		fill.size.x = 40 * (float(new_hp) / float(max_hp))
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
	var target_rect = target_sprite.get_child(0) as ColorRect
	if target_rect:
		var original_color = target_rect.color
		tween.parallel().tween_property(target_rect, "color", Color(2, 2, 2), 0.1)
		tween.tween_property(target_rect, "color", original_color, 0.1)

func show_damage_number(position: Vector2, damage: int, is_heal: bool = false):
	var label = Label.new()
	label.text = str(damage)
	label.position = position
	label.modulate = Color.GREEN if is_heal else Color.RED
	label.add_theme_font_size_override("font_size", 24)
	
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

func get_sprite_for_unit(unit) -> Node2D:
	if unit is Hero:
		return hero_sprites.get(unit)
	elif unit is Enemy:
		return enemy_sprites.get(unit)
	return null

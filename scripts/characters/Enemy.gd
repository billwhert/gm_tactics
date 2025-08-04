# Enemy.gd
extends Node
class_name Enemy

signal hp_changed(new_hp, max_hp)
signal died

var enemy_name: String
var monster_id: String = ""  # For use with GameData
var cr: int = 1
var max_hp: int
var current_hp: int
var ac: int = 10
var speed: int = 5
var damage_dice: String = "1d6"
var tags: Array[String] = []
var grid_position: Vector2i
var conditions: Array[String] = []
var temp_modifiers: Dictionary = {}

# Additional properties for combat
var hp: Dictionary = {"current": 10, "max": 10}
var stats: Dictionary = {
	"STR": 10,
	"DEX": 10,
	"CON": 10,
	"INT": 10,
	"WIS": 10,
	"CHA": 10
}

static func create_from_template(template: Dictionary) -> Enemy:
	var enemy = Enemy.new()
	enemy.enemy_name = template.name
	enemy.cr = template.cr
	enemy.max_hp = template.hp
	enemy.current_hp = template.hp
	enemy.hp.max = template.hp
	enemy.hp.current = template.hp
	enemy.ac = template.ac
	enemy.damage_dice = template.damage
	
	# Add tags based on enemy type
	if template.name in ["Skeleton", "Zombie"]:
		enemy.tags.append("undead")
	if template.name in ["Goblin Shaman", "Orc Shaman"]:
		enemy.tags.append("caster")
	if template.name in ["Orc", "Ogre"]:
		enemy.tags.append("heavy")
	
	# Set some basic stats based on CR
	var base_stat = 10 + enemy.cr
	enemy.stats.STR = base_stat
	enemy.stats.DEX = base_stat
	enemy.stats.CON = base_stat
	
	return enemy

func is_alive() -> bool:
	return current_hp > 0 and hp.current > 0

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	hp.current = current_hp
	emit_signal("hp_changed", current_hp, max_hp)
	if current_hp == 0:
		emit_signal("died")

func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)
	hp.current = current_hp
	emit_signal("hp_changed", current_hp, max_hp)

func has_tag(tag: String) -> bool:
	return tag in tags

func add_condition(condition: String):
	if not condition in conditions:
		conditions.append(condition)

func remove_condition(condition: String):
	conditions.erase(condition)

func has_condition(condition: String) -> bool:
	return condition in conditions

func get_nearest_hero(party: Array[Hero]) -> Hero:
	var nearest = null
	var min_dist = 999
	
	for hero in party:
		if hero.is_alive():
			var dist = distance_to_position(hero.grid_position)
			if dist < min_dist:
				min_dist = dist
				nearest = hero
	
	return nearest

func distance_to_position(pos: Vector2i) -> int:
	# Manhattan distance
	return abs(grid_position.x - pos.x) + abs(grid_position.y - pos.y)

func distance_to(other) -> int:
	if other.has("grid_position"):
		return distance_to_position(other.grid_position)
	return 999

func attack(target: Hero):
	# Simple enemy attack
	var attack_roll = Dice.roll("1d20") + get_to_hit_mod()
	if attack_roll >= target.ac:
		var damage = Dice.roll(damage_dice)
		target.take_damage(damage)
		print("%s hits %s for %d damage!" % [enemy_name, target.hero_name, damage])
	else:
		print("%s misses %s!" % [enemy_name, target.hero_name])

func get_to_hit_mod() -> int:
	# Basic calculation
	var prof_bonus = 2 + (cr / 4)  # Rough proficiency based on CR
	return prof_bonus + modifier(stats.STR)

func get_damage_mod() -> int:
	return modifier(stats.STR)

func modifier(stat_value: int) -> int:
	return (stat_value - 10) / 2

func get_save_mod(save_type: String) -> int:
	# Basic save calculation
	return modifier(stats[save_type])

func get_damage_potential() -> float:
	# Parse damage dice to get average
	var parts = damage_dice.split("d")
	if parts.size() == 2:
		var num_dice = int(parts[0])
		var die_size = int(parts[1].split("+")[0])  # Handle +X modifiers
		var base_damage = num_dice * (die_size + 1) / 2.0
		
		# Add modifier if present
		if "+" in parts[1]:
			var mod = int(parts[1].split("+")[1])
			base_damage += mod
		
		return base_damage
	return 3.5  # Default 1d6 average

func has_line_of_sight(target) -> bool:
	# Simplified - would need room reference for proper check
	if target.has("grid_position"):
		var dist = distance_to_position(target.grid_position)
		return dist <= 10  # Arbitrary sight range
	return false

func can_see(target) -> bool:
	return has_line_of_sight(target)

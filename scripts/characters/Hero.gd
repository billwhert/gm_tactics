# Hero.gd - Updated with proper SRD mechanics and missing methods
extends Node
class_name Hero

signal hp_changed(new_hp, max_hp)
signal died

# Identity
var id: String
var hero_name: String
var race_id: String
var class_id: String
var level: int = 1
var xp: int = 0

# Core D&D Stats
var stats: Dictionary = {
	"STR": 10,
	"DEX": 10,
	"CON": 10,
	"INT": 10,
	"WIS": 10,
	"CHA": 10
}

# Derived stats
var proficiency: int = 2
var hp: Dictionary = {"current": 10, "max": 10}
var ac: int = 10
var speed: int = 5  # Grid squares
var initiative_mod: int = 0
var initiative: int = 0  # Rolled initiative

# Equipment slots
var weapon_id: String = ""
var armor_id: String = ""
var inventory: Array[String] = []

# Features
var quirks: Array[String] = []
var tags: Array[String] = []
var conditions: Array[String] = []

# Combat state
var grid_position: Vector2i
var defending: bool = false
var has_spell_prepared: bool = false
var prepared_spell_id: String = ""
var temp_modifiers: Dictionary = {}

# Reference to game data
var game_data: GameData

# For compatibility with existing code
var current_hp: int:
	get:
		return hp.current
	set(value):
		hp.current = value
		emit_signal("hp_changed", hp.current, hp.max)

var max_hp: int:
	get:
		return hp.max
	set(value):
		hp.max = value

static func create_from_data(p_id: String, p_game_data: GameData) -> Hero:
	var hero = Hero.new()
	hero.game_data = p_game_data
	hero.id = p_id
	
	# This would load from save data or generate new
	hero._generate_default_hero()
	return hero

# Alternative constructor for compatibility
static func create(p_class: String, p_race: String, p_quirks: Array) -> Hero:
	var hero = Hero.new()
	hero.class_id = p_class.to_lower()
	hero.race_id = p_race.to_lower()
	hero.quirks = p_quirks
	hero.hero_name = p_race + " " + p_class
	
	# Set some defaults without GameData
	hero._generate_basic_stats()
	return hero

func _generate_basic_stats():
	# Basic stat generation without full GameData
	match class_id:
		"fighter":
			stats["STR"] = 16
			stats["CON"] = 14
			stats["DEX"] = 12
			hp.max = 10 + modifier(stats.CON)
			ac = 16  # Chain mail + shield
		"cleric":
			stats["WIS"] = 16
			stats["CON"] = 14
			stats["STR"] = 12
			hp.max = 8 + modifier(stats.CON)
			ac = 14  # Scale mail
		"rogue":
			stats["DEX"] = 16
			stats["INT"] = 14
			stats["CHA"] = 12
			hp.max = 8 + modifier(stats.DEX)
			ac = 12 + modifier(stats.DEX)  # Leather armor
		"wizard":
			stats["INT"] = 16
			stats["DEX"] = 14
			stats["CON"] = 12
			hp.max = 6 + modifier(stats.CON)
			ac = 10 + modifier(stats.DEX)  # No armor
	
	hp.current = hp.max
	current_hp = hp.current
	max_hp = hp.max
	_calculate_derived_stats()

func _generate_default_hero():
	# Example hero generation
	race_id = "human"
	class_id = "fighter"
	level = 1
	
	# Apply race bonuses
	var race_data = game_data.get_race(race_id)
	if race_data.has("bonuses"):
		for stat in race_data.bonuses:
			stats[stat] += race_data.bonuses[stat]
	
	# Apply class starting stats
	var class_data = game_data.get_class_data(class_id)
	
	# Set primary stats based on class
	match class_id:
		"fighter":
			stats["STR"] = 16
			stats["CON"] = 14
			stats["DEX"] = 12
			weapon_id = "item_longsword"
			armor_id = "item_chain_shirt"
		"cleric":
			stats["WIS"] = 16
			stats["CON"] = 14
			stats["STR"] = 12
			weapon_id = "item_mace"
			armor_id = "item_scale_mail"
		"rogue":
			stats["DEX"] = 16
			stats["INT"] = 14
			stats["CHA"] = 12
			weapon_id = "item_shortsword"
			armor_id = "item_leather"
		"wizard":
			stats["INT"] = 16
			stats["DEX"] = 14
			stats["CON"] = 12
			weapon_id = "item_staff"
			armor_id = "item_robe"
	
	_calculate_derived_stats()

func _calculate_derived_stats():
	# Proficiency bonus based on level
	proficiency = 2 + (level - 1) / 4
	
	# HP calculation
	if game_data:
		var class_data = game_data.get_class_data(class_id)
		var hit_die = class_data.get("hit_die", "d8")
		var base_hp = int(hit_die.split("d")[1])
		hp.max = base_hp + modifier(stats.CON)
		hp.current = hp.max
	
	# AC calculation
	if game_data and armor_id != "":
		var armor_data = game_data.get_armor(armor_id)
		if armor_data.has("base_ac"):
			ac = armor_data.base_ac
			if armor_data.has("dex_cap"):
				ac += min(modifier(stats.DEX), armor_data.dex_cap)
			else:
				ac += modifier(stats.DEX)
	else:
		ac = 10 + modifier(stats.DEX)
	
	# Initiative
	initiative_mod = modifier(stats.DEX)

func modifier(stat_value: int) -> int:
	return (stat_value - 10) / 2

func get_to_hit_mod() -> int:
	if not game_data:
		# Fallback without GameData
		var stat_to_use = "STR"
		if class_id in ["wizard", "sorcerer"]:
			stat_to_use = "INT"
		elif class_id == "cleric":
			stat_to_use = "WIS"
		return proficiency + modifier(stats[stat_to_use])
	
	var weapon_data = game_data.get_weapon(weapon_id)
	var stat_to_use = "STR"  # Default melee
	
	if weapon_data.has("type") and weapon_data.type == "ranged":
		stat_to_use = "DEX"
	
	return proficiency + modifier(stats[stat_to_use])

func get_damage_mod() -> int:
	if not game_data:
		return modifier(stats.STR)
		
	var weapon_data = game_data.get_weapon(weapon_id)
	var damage_mod_attr = weapon_data.get("damage_mod_attr", "STR")
	return modifier(stats[damage_mod_attr])

func get_weapon_damage_die() -> String:
	if not game_data:
		return "1d6"  # Default
		
	var weapon_data = game_data.get_weapon(weapon_id)
	return weapon_data.get("die", "1d4")

func is_alive() -> bool:
	return hp.current > 0

func take_damage(amount: int):
	hp.current = max(0, hp.current - amount)
	current_hp = hp.current
	emit_signal("hp_changed", hp.current, hp.max)
	if hp.current == 0:
		emit_signal("died")

func heal(amount: int):
	hp.current = min(hp.max, hp.current + amount)
	current_hp = hp.current
	emit_signal("hp_changed", hp.current, hp.max)

func add_condition(condition: String):
	if not condition in conditions:
		conditions.append(condition)

func remove_condition(condition: String):
	conditions.erase(condition)

func has_condition(condition: String) -> bool:
	return condition in conditions

func has_tag(tag: String) -> bool:
	return tag in tags

func has_quirk(quirk: String) -> bool:
	return quirk in quirks

func get_save_mod(save_type: String) -> int:
	if not game_data:
		return modifier(stats[save_type])
		
	# Check class proficiencies
	var class_data = game_data.get_class_data(class_id)
	var save_proficiencies = class_data.get("save_proficiencies", [])
	
	var mod = modifier(stats[save_type])
	if save_type in save_proficiencies:
		mod += proficiency
	
	return mod

func can_cast_spells() -> bool:
	if not game_data:
		return class_id in ["wizard", "cleric", "sorcerer", "druid", "bard", "warlock"]
		
	var class_data = game_data.get_class_data(class_id)
	return class_data.has("spellcasting") or has_spell_prepared

func get_spell_dc() -> int:
	if not game_data:
		# Fallback calculation
		var casting_stat = "INT"
		match class_id:
			"cleric", "druid":
				casting_stat = "WIS"
			"bard", "sorcerer", "warlock", "paladin":
				casting_stat = "CHA"
		return 8 + proficiency + modifier(stats[casting_stat])
		
	var class_data = game_data.get_class_data(class_id)
	var casting_stat = class_data.get("spellcasting_ability", "INT")
	return 8 + proficiency + modifier(stats[casting_stat])

func get_loot_bonuses() -> Dictionary:
	if not game_data:
		return {}
		
	var class_data = game_data.get_class_data(class_id)
	return class_data.get("loot_bonus", {})

# Missing methods that other scripts expect
func distance_to_position(pos: Vector2i) -> int:
	# Manhattan distance
	return abs(grid_position.x - pos.x) + abs(grid_position.y - pos.y)

func has_line_of_sight(target) -> bool:
	# This should check with the room for actual line of sight
	# For now, simple check
	if target.has("grid_position"):
		var dist = distance_to_position(target.grid_position)
		return dist <= 10  # Arbitrary sight range
	return false

func start_defending():
	defending = true
	# AC bonus is handled by the action

func has_item(item_id: String) -> bool:
	return item_id in inventory

func get_damage_potential() -> float:
	# Used for threat assessment
	var base_damage = 4.5  # Average of 1d8
	if weapon_id != "":
		var die_parts = get_weapon_damage_die().split("d")
		if die_parts.size() == 2:
			var num_dice = int(die_parts[0])
			var die_size = int(die_parts[1])
			base_damage = num_dice * (die_size + 1) / 2.0
	
	return base_damage + get_damage_mod()

# For compatibility with enemy targeting
func distance_to(other) -> int:
	if other.has("grid_position"):
		return distance_to_position(other.grid_position)
	return 999

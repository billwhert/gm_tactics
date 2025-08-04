# Interactable.gd
extends Node
class_name Interactable

var type: String = "chest"  # chest, trap, shrine, etc.
var grid_position: Vector2i
var opened: bool = false
var trap_chance: float = 0.25
var mimic_chance: float = 0.1
var loot_table: Array = []

func interact(hero: Hero) -> Dictionary:
	if opened:
		return {"success": false, "message": "Already opened"}
	
	opened = true
	var result = {"success": true, "items": []}
	
	# Check for mimic
	if randf() < mimic_chance:
		result["mimic"] = true
		result["message"] = "It's a mimic!"
		# Spawn mimic enemy at this position
		return result
	
	# Check for trap
	if randf() < trap_chance:
		# Rogue detection
		if hero.hero_class == "Rogue" and randf() < 0.75:  # 75% detection chance
			result["trap_detected"] = true
			result["message"] = "Trap detected and disarmed!"
		else:
			result["trap_triggered"] = true
			var trap_damage = Dice.roll("2d6")
			hero.take_damage(trap_damage)
			result["message"] = "Trap triggered! %d damage!" % trap_damage
	
	# Generate loot
	var loot = generate_loot(hero)
	result["items"] = loot
	
	return result

func generate_loot(hero: Hero) -> Array:
	var items = []
	
	# Basic loot table
	var roll = randf()
	if roll < 0.4:
		# Potion
		var potion = Item.new()
		potion.name = "Healing Potion"
		potion.type = "consumable"
		potion.effect = "heal_2d4+2"
		items.append(potion)
	elif roll < 0.7:
		# Weapon
		var weapon = generate_weapon(hero)
		items.append(weapon)
	elif roll < 0.9:
		# Armor
		var armor = generate_armor(hero)
		items.append(armor)
	else:
		# Scroll
		var scroll = Item.new()
		scroll.name = "Scroll of Fireball"
		scroll.type = "scroll"
		scroll.effect = "fireball_8d6"
		items.append(scroll)
	
	return items

func generate_weapon(hero: Hero) -> Item:
	var weapon = Item.new()
	weapon.type = "weapon"
	
	match hero.hero_class:
		"Fighter", "Paladin":
			weapon.name = "Longsword +1"
			weapon.damage_dice = "1d8"
			weapon.damage_bonus = 1
		"Rogue":
			weapon.name = "Shortsword +1"
			weapon.damage_dice = "1d6"
			weapon.damage_bonus = 1
		"Wizard":
			weapon.name = "Staff of Power"
			weapon.damage_dice = "1d6"
			weapon.damage_bonus = 2
		"Cleric":
			weapon.name = "Mace +1"
			weapon.damage_dice = "1d6"
			weapon.damage_bonus = 1
	
	return weapon

func generate_armor(hero: Hero) -> Item:
	var armor = Item.new()
	armor.type = "armor"
	
	match hero.hero_class:
		"Fighter", "Paladin":
			armor.name = "Plate Mail"
			armor.ac_bonus = 8
		"Rogue":
			armor.name = "Studded Leather +1"
			armor.ac_bonus = 3
		"Wizard":
			armor.name = "Robe of Protection"
			armor.ac_bonus = 1
		"Cleric":
			armor.name = "Chain Mail +1"
			armor.ac_bonus = 6
	
	return armor

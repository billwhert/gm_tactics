# HeroAction.gd
extends Resource
class_name HeroAction

var hero: Hero
var room: Room
var type: String
var subtype: String = ""
var target = null  # Can be Enemy, Hero, or Vector2i
var target_position: Vector2i

# Modifiers
var damage_multiplier: float = 1.0
var damage_bonus: int = 0
var damage_dice: String = ""
var heal_amount: int = 0
var ac_bonus: int = 0
var movement_bonus: int = 0
var bonus: int = 0  # Generic bonus

# Special flags
var instant_equip: bool = false
var first_swing_bonus: float = 1.0
var potion_multiplier: float = 1.0
var instant_use: bool = false
var free_cast_next_turn: bool = false
var trap_detect_chance: float = 0.0
var rarity_bonus: float = 0.0
var ignore_threats: bool = false
var counter_chance: float = 0.0
var dodge_chance: float = 0.0
var push_distance: int = 0
var collision_damage: int = 0
var aoe_radius: int = 0

func execute():
	# This would be implemented with actual game logic
	# For now, just print what would happen
	print("Hero %s performs %s" % [hero.hero_name, type])
	
	match type:
		"attack":
			if target:
				var hit_roll = hero.roll_attack()
				if hit_roll >= target.ac:
					var damage = hero.roll_damage() * damage_multiplier + damage_bonus
					target.take_damage(damage)
					print("Hit for %d damage!" % damage)
				else:
					print("Miss!")
		
		"defend":
			hero.start_defending()
			print("%s takes defensive stance (+%d AC)" % [hero.hero_name, ac_bonus])
		
		"loot":
			if target and target.type == "chest":
				# Loot logic would go here
				print("%s loots chest!" % hero.hero_name)
		
		"heal":
			if target:
				target.heal(heal_amount)
				print("%s heals %s for %d" % [hero.hero_name, target.hero_name, heal_amount])

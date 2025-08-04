# CombatResolver.gd - Handles all combat mechanics
extends Node
class_name CombatResolver

static var game_data: GameData
static var always_hit_mode: bool = false

# Main attack resolution
static func resolve_attack(attacker, target) -> Dictionary:
	var result = {
		"hit": false,
		"damage": 0,
		"crit": false,
		"effects": []
	}
	
	# Always hit mode check
	if always_hit_mode:
		result.hit = true
		result.damage = roll_damage(attacker)
		return result
	
	# Normal attack resolution
	var to_hit_roll = Dice.roll("1d20")  # Fixed: was d20()
	var to_hit_mod = attacker.get_to_hit_mod()
	var total_attack = to_hit_roll + to_hit_mod
	
	# Check for crit/fumble
	if to_hit_roll == 20:
		result.hit = true
		result.crit = true
		result.damage = roll_damage(attacker, true)
	elif to_hit_roll == 1:
		result.hit = false
	else:
		# Normal hit check
		if total_attack >= target.ac:
			result.hit = true
			result.damage = roll_damage(attacker)
	
	return result

static func roll_damage(attacker, is_crit: bool = false) -> int:
	var damage = 0
	
	if attacker is Hero:
		var weapon_die = attacker.get_weapon_damage_die()
		damage = Dice.roll(weapon_die)
		if is_crit:
			damage += Dice.roll(weapon_die)  # Roll twice for crit
		damage += attacker.get_damage_mod()
	elif attacker is Enemy:
		if game_data and attacker.monster_id != "":
			var monster_data = game_data.get_monster(attacker.monster_id)
			var attack_data = monster_data.get("attack", {})
			damage = Dice.roll(attack_data.get("damage", "1d6"))
		else:
			# Fallback to enemy's damage_dice
			damage = Dice.roll(attacker.damage_dice)
		if is_crit:
			damage = int(damage * 1.5)  # Simplified crit for monsters
	
	return max(1, damage)  # Minimum 1 damage

# Saving throw resolution
static func resolve_save(creature, save_type: String, dc: int) -> bool:
	var roll = Dice.roll("1d20")  # Fixed: was d20()
	var save_mod = creature.get_save_mod(save_type)
	return (roll + save_mod) >= dc

# Spell resolution
static func resolve_spell(caster, spell_id: String, targets: Array) -> Dictionary:
	var spell_data = game_data.get_spell(spell_id)
	var result = {
		"affected_targets": [],
		"damage_rolls": {},
		"effects": []
	}
	
	# Area effect determination
	if spell_data.has("area"):
		# Fixed: get_targets_in_area expects Dictionary and Vector2i
		targets = get_targets_in_area(spell_data.area, caster.grid_position)
	
	# Save DC
	var dc = caster.get_spell_dc()
	
	# Roll damage once for all targets
	var damage = 0
	if spell_data.has("damage"):
		damage = Dice.roll(spell_data.damage)
	
	# Apply to each target
	for target in targets:
		var target_result = {
			"target": target,
			"saved": false,
			"damage": damage
		}
		
		# Saving throw
		if spell_data.has("save"):
			target_result.saved = resolve_save(
				target, 
				spell_data.save.type, 
				spell_data.save.get("dc", dc)
			)
			
			# Half damage on save
			if target_result.saved and spell_data.save.get("half_on_save", false):
				target_result.damage = damage / 2
			elif target_result.saved:
				target_result.damage = 0
		
		result.affected_targets.append(target_result)
	
	return result

# Condition application
static func apply_condition(target, condition_id: String):
	if not game_data:
		return
		
	var condition_data = game_data.get_condition(condition_id)
	target.add_condition(condition_id)
	
	# Apply immediate effects
	if condition_data.has("effects"):
		var effects = condition_data.effects
		
		if effects.has("ac_bonus"):
			target.ac += effects.ac_bonus
		
		if effects.has("to_hit_penalty"):
			# Store as a temporary modifier
			target.temp_modifiers["to_hit"] = effects.to_hit_penalty
		
		if effects.has("skip_turn"):
			target.stunned = true

# End of round processing
static func process_end_of_round(creatures: Array):
	for creature in creatures:
		# Process conditions
		var conditions_to_remove = []
		
		for condition_id in creature.conditions:
			if not game_data:
				continue
				
			var condition_data = game_data.get_condition(condition_id)
			
			# Damage over time
			if condition_data.has("effects") and condition_data.effects.has("dot"):
				var dot_damage = Dice.roll(condition_data.effects.dot)
				creature.take_damage(dot_damage)
			
			# Duration countdown
			if creature.has("condition_durations"):
				creature.condition_durations[condition_id] -= 1
				if creature.condition_durations[condition_id] <= 0:
					conditions_to_remove.append(condition_id)
		
		# Remove expired conditions
		for condition_id in conditions_to_remove:
			remove_condition(creature, condition_id)

static func remove_condition(target, condition_id: String):
	if not game_data:
		return
		
	var condition_data = game_data.get_condition(condition_id)
	target.remove_condition(condition_id)
	
	# Remove effects
	if condition_data.has("effects"):
		var effects = condition_data.effects
		
		if effects.has("ac_bonus"):
			target.ac -= effects.ac_bonus
		
		if effects.has("to_hit_penalty"):
			target.temp_modifiers.erase("to_hit")

static func get_targets_in_area(area_data: Dictionary, center_pos: Vector2i) -> Array:
	var targets = []
	# Area targeting logic based on shape and radius
	# This would interact with the room/grid system
	# For now, return empty array - implement when you have room reference
	return targets

# Combat advantage/disadvantage
static func has_advantage(attacker, target) -> bool:
	# Hidden attacker
	if attacker.has_condition("hidden") and not target.can_see(attacker):
		return true
	
	# Target prone
	if target.has_condition("prone") and attacker.distance_to(target) <= 1:
		return true
	
	# Flanking
	if is_flanking(attacker, target):
		return true
	
	return false

static func has_disadvantage(attacker, target) -> bool:
	# Attacker prone
	if attacker.has_condition("prone"):
		return true
	
	# Ranged attack in melee
	if attacker.has_method("using_ranged_weapon") and attacker.using_ranged_weapon() and has_enemy_adjacent(attacker):
		return true
	
	# Poisoned
	if attacker.has_condition("poisoned"):
		return true
	
	return false

static func is_flanking(attacker, target) -> bool:
	# Check if an ally is on opposite side of target
	# This requires grid/position checking
	return false

static func has_enemy_adjacent(creature) -> bool:
	# Check for enemies within 1 square
	return false

# EnemyAI.gd - Smart enemy AI based on type
extends Node
class_name EnemyAI

var room: Room
var party: Array[Hero]

func get_enemy_action(enemy: Enemy) -> Dictionary:
	var action = {
		"type": "attack",
		"target": null,
		"move_to": null
	}
	
	# Determine AI type based on enemy tags
	if enemy.has_tag("caster"):
		return get_caster_action(enemy)
	elif enemy.has_tag("support"):
		return get_support_action(enemy)
	elif enemy.has_tag("ranged"):
		return get_ranged_action(enemy)
	elif enemy.has_tag("heavy"):
		return get_heavy_action(enemy)
	else:
		return get_basic_action(enemy)

func get_basic_action(enemy: Enemy) -> Dictionary:
	# Basic AI: Attack closest hero
	var target = enemy.get_nearest_hero(party)
	
	if not target:
		return {"type": "wait"}
	
	var distance = enemy.distance_to(target)
	
	if distance <= 1:
		# Adjacent - attack
		return {
			"type": "attack",
			"target": target
		}
	else:
		# Move toward target
		return {
			"type": "move",
			"target": get_move_toward_position(enemy, target)
		}

func get_caster_action(enemy: Enemy) -> Dictionary:
	# Casters prefer to stay at range and cast spells
	var lowest_hp_hero = get_lowest_hp_hero()
	var nearest_hero = enemy.get_nearest_hero(party)
	
	if not nearest_hero:
		return {"type": "wait"}
	
	var distance = enemy.distance_to(nearest_hero)
	
	# Try to maintain distance
	if distance < 3:
		# Too close - move away
		return {
			"type": "move",
			"target": get_move_away_position(enemy, nearest_hero)
		}
	elif enemy.has_condition("silenced"):
		# Can't cast - basic attack
		return get_basic_action(enemy)
	else:
		# Cast spell at priority target
		return {
			"type": "spell",
			"spell": "magic_missile",
			"target": lowest_hp_hero or nearest_hero
		}

func get_support_action(enemy: Enemy) -> Dictionary:
	# Support enemies heal allies or buff
	var wounded_allies = get_wounded_enemies(enemy)
	
	if wounded_allies.size() > 0:
		# Heal most wounded ally
		var target = wounded_allies[0]
		return {
			"type": "heal",
			"target": target,
			"amount": "2d4+2"
		}
	else:
		# No healing needed - attack or buff
		if randf() < 0.5:
			return {
				"type": "buff",
				"target": get_strongest_ally(enemy),
				"buff": "attack_bonus"
			}
		else:
			return get_basic_action(enemy)

func get_ranged_action(enemy: Enemy) -> Dictionary:
	# Ranged attackers target priority heroes
	var target = get_priority_target()
	
	if not target:
		return {"type": "wait"}
	
	var distance = enemy.distance_to(target)
	var nearest_hero = enemy.get_nearest_hero(party)
	
	# If hero is adjacent, move away
	if nearest_hero and enemy.distance_to(nearest_hero) <= 1:
		return {
			"type": "move",
			"target": get_move_away_position(enemy, nearest_hero)
		}
	elif enemy.has_line_of_sight(target):
		# Have clear shot
		return {
			"type": "ranged_attack",
			"target": target
		}
	else:
		# Move to get line of sight
		return {
			"type": "move",
			"target": get_flanking_position(enemy, target)
		}

func get_heavy_action(enemy: Enemy) -> Dictionary:
	# Heavy enemies are tanks - they protect others
	var weakest_ally = get_weakest_ally(enemy)
	var threat = get_biggest_threat()
	
	if weakest_ally and weakest_ally != enemy:
		# Move to protect ally
		var protect_pos = get_protect_position(enemy, weakest_ally, threat)
		if protect_pos != enemy.grid_position:
			return {
				"type": "move",
				"target": protect_pos
			}
	
	# Otherwise standard attack
	return get_basic_action(enemy)

# Helper functions
func get_lowest_hp_hero() -> Hero:
	var lowest = null
	var lowest_hp = 999999
	
	for hero in party:
		if hero.is_alive() and hero.current_hp < lowest_hp:
			lowest = hero
			lowest_hp = hero.current_hp
	
	return lowest

func get_priority_target() -> Hero:
	# Priority: Low HP > Casters > Healers > Others
	var targets = party.filter(func(h): return h.is_alive())
	
	# Sort by priority
	targets.sort_custom(func(a, b):
		var a_score = a.current_hp
		if a.class_id in ["wizard", "sorcerer"]:
			a_score -= 50
		elif a.class_id == "cleric":
			a_score -= 40
		
		var b_score = b.current_hp
		if b.class_id in ["wizard", "sorcerer"]:
			b_score -= 50
		elif b.class_id == "cleric":
			b_score -= 40
		
		return a_score < b_score
	)
	
	return targets[0] if targets.size() > 0 else null

func get_biggest_threat() -> Hero:
	# Threat assessment based on damage potential
	var biggest_threat = null
	var highest_threat = 0
	
	for hero in party:
		if hero.is_alive():
			var threat = hero.get_damage_potential() * (hero.current_hp / hero.max_hp)
			if hero.has_condition("rage") or hero.has_condition("champion"):
				threat *= 2
			
			if threat > highest_threat:
				highest_threat = threat
				biggest_threat = hero
	
	return biggest_threat

func get_wounded_enemies(enemy: Enemy) -> Array:
	var wounded = []
	
	for other in room.enemies:
		if other.is_alive() and other != enemy:
			if other.current_hp < other.max_hp * 0.5:
				wounded.append(other)
	
	# Sort by HP percentage
	wounded.sort_custom(func(a, b):
		return float(a.current_hp) / a.max_hp < float(b.current_hp) / b.max_hp
	)
	
	return wounded

func get_strongest_ally(enemy: Enemy) -> Enemy:
	var strongest = null
	var highest_hp = 0
	
	for other in room.enemies:
		if other.is_alive() and other != enemy:
			if other.max_hp > highest_hp:
				highest_hp = other.max_hp
				strongest = other
	
	return strongest

func get_weakest_ally(enemy: Enemy) -> Enemy:
	var weakest = null
	var lowest_hp = 999999
	
	for other in room.enemies:
		if other.is_alive() and other != enemy:
			if other.current_hp < lowest_hp:
				lowest_hp = other.current_hp
				weakest = other
	
	return weakest

func get_move_toward_position(enemy: Enemy, target) -> Vector2i:
	# Simple pathfinding toward target
	var direction = target.grid_position - enemy.grid_position
	var move = Vector2i()
	
	if abs(direction.x) > abs(direction.y):
		move.x = sign(direction.x)
	else:
		move.y = sign(direction.y)
	
	var new_pos = enemy.grid_position + move
	
	# Check if valid
	if room.is_walkable(new_pos):
		return new_pos
	
	# Try alternate direction
	if move.x != 0:
		move = Vector2i(0, sign(direction.y))
	else:
		move = Vector2i(sign(direction.x), 0)
	
	new_pos = enemy.grid_position + move
	if room.is_walkable(new_pos):
		return new_pos
	
	# Can't move
	return enemy.grid_position

func get_move_away_position(enemy: Enemy, threat) -> Vector2i:
	# Move away from threat
	var direction = enemy.grid_position - threat.grid_position
	if direction.length() > 0:
		direction = direction.normalized()
	
	var move = Vector2i(sign(direction.x), sign(direction.y))
	var new_pos = enemy.grid_position + move
	
	if room.is_walkable(new_pos):
		return new_pos
	
	# Try lateral movement
	if move.x != 0:
		for y_offset in [-1, 1]:
			new_pos = enemy.grid_position + Vector2i(move.x, y_offset)
			if room.is_walkable(new_pos):
				return new_pos
	else:
		for x_offset in [-1, 1]:
			new_pos = enemy.grid_position + Vector2i(x_offset, move.y)
			if room.is_walkable(new_pos):
				return new_pos
	
	return enemy.grid_position

func get_flanking_position(enemy: Enemy, target) -> Vector2i:
	# Try to get to side or behind target
	var hero_facing = Vector2i(1, 0)  # Assume facing right
	var ideal_positions = [
		target.grid_position + Vector2i(-hero_facing.x, 0),  # Behind
		target.grid_position + Vector2i(0, 1),  # Side
		target.grid_position + Vector2i(0, -1)  # Other side
	]
	
	# Find closest reachable position
	var best_pos = enemy.grid_position
	var best_dist = 999
	
	for pos in ideal_positions:
		if room.is_walkable(pos):
			var dist = enemy.distance_to_position(pos)
			if dist < best_dist:
				best_dist = dist
				best_pos = pos
	
	# Move toward best position
	return get_move_toward_position(enemy, {"grid_position": best_pos})

func get_protect_position(enemy: Enemy, ally: Enemy, threat: Hero) -> Vector2i:
	# Position between ally and threat
	if not threat:
		return enemy.grid_position
	
	var ideal_pos = ally.grid_position + (threat.grid_position - ally.grid_position).sign()
	
	if room.is_walkable(ideal_pos):
		return get_move_toward_position(enemy, {"grid_position": ideal_pos})
	
	# Find adjacent position to ally
	for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var pos = ally.grid_position + offset
		if room.is_walkable(pos):
			return get_move_toward_position(enemy, {"grid_position": pos})
	
	return enemy.grid_position

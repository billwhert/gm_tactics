# HeroQuirks.gd - Hero personality quirk system
extends Node
class_name HeroQuirks

# Core quirks from design doc
static var quirk_database = {
	"LOOT_GOBLIN": {
		"name": "Loot Goblin",
		"description": "Must loot when chest visible",
		"trigger_chance": 0.35,
		"triggers": {
			"chest_visible": {
				"priority": 9,
				"action": "force_loot",
				"message": "%s can't resist that shiny chest!"
			}
		}
	},
	
	"AGGRO_ADDICT": {
		"name": "Aggro Addict",
		"description": "Targets strongest enemy",
		"trigger_chance": 0.25,
		"triggers": {
			"attack_action": {
				"priority": 7,
				"action": "target_strongest",
				"message": "%s charges at the biggest threat!"
			}
		}
	},
	
	"OVERHEALER": {
		"name": "Overhealer",
		"description": "Heals at 85% HP",
		"trigger_chance": 0.2,
		"triggers": {
			"at_85_percent_hp": {
				"priority": 6,
				"action": "force_heal_self",
				"message": "%s heals minor scratches obsessively!"
			}
		}
	},
	
	"MELEE_WIZARD": {
		"name": "Muscle Wizard",
		"description": "Prefers bonking with staff",
		"trigger_chance": 0.3,
		"triggers": {
			"wizard_attack": {
				"priority": 7,
				"action": "melee_bonk",
				"message": "%s casts FIST!"
			}
		}
	},
	
	"CAUTIOUS": {
		"name": "Cautious",
		"description": "Takes defensive actions when hurt",
		"trigger_chance": 0.25,
		"triggers": {
			"below_half_hp": {
				"priority": 8,
				"action": "force_defend",
				"message": "%s retreats to safety!"
			}
		}
	},
	
	"PERFECTIONIST": {
		"name": "Perfectionist",
		"description": "Won't act unless conditions are perfect",
		"trigger_chance": 0.2,
		"triggers": {
			"suboptimal_target": {
				"priority": 6,
				"action": "wait_for_better",
				"message": "%s waits for the perfect moment..."
			}
		}
	},
	
	"BERSERKER": {
		"name": "Berserker",
		"description": "Gets stronger when hurt",
		"trigger_chance": 0.3,
		"triggers": {
			"low_health_attack": {
				"priority": 9,
				"action": "rage_attack",
				"message": "%s enters a battle rage!"
			}
		}
	},
	
	"COWARD": {
		"name": "Cowardly",
		"description": "Avoids direct confrontation",
		"trigger_chance": 0.25,
		"triggers": {
			"scary_enemy": {
				"priority": 8,
				"action": "hide_behind_ally",
				"message": "%s cowers behind an ally!"
			},
			"alone_with_enemies": {
				"priority": 9,
				"action": "full_retreat",
				"message": "%s panics and flees!"
			}
		}
	},
	
	"SCHOLAR": {
		"name": "Scholar",
		"description": "Analyzes before acting",
		"trigger_chance": 0.2,
		"triggers": {
			"unknown_enemy": {
				"priority": 7,
				"action": "study_first",
				"message": "%s stops to analyze the enemy!"
			}
		}
	},
	
	"KLEPTOMANIAC": {
		"name": "Kleptomaniac",
		"description": "Compulsively steals everything",
		"trigger_chance": 0.35,
		"triggers": {
			"enemy_has_shiny": {
				"priority": 8,
				"action": "pickpocket",
				"message": "%s can't resist that shiny object!"
			}
		}
	},
	
	"PYROMANIAC": {
		"name": "Pyromaniac",
		"description": "Everything should be on fire",
		"trigger_chance": 0.25,
		"triggers": {
			"flammable_environment": {
				"priority": 9,
				"action": "set_fire",
				"message": "%s sets everything ablaze!"
			},
			"non_fire_spell": {
				"priority": 6,
				"action": "make_it_fire",
				"message": "%s adds fire to their spell!"
			}
		}
	},
	
	"PACIFIST": {
		"name": "Pacifist",
		"description": "Avoids violence when possible",
		"trigger_chance": 0.2,
		"triggers": {
			"can_negotiate": {
				"priority": 8,
				"action": "try_diplomacy",
				"message": "%s attempts to negotiate!"
			},
			"lethal_blow": {
				"priority": 7,
				"action": "nonlethal",
				"message": "%s pulls their punch!"
			}
		}
	},
	
	"SHOWOFF": {
		"name": "Showoff",
		"description": "Must look cool at all times",
		"trigger_chance": 0.3,
		"triggers": {
			"audience_present": {
				"priority": 7,
				"action": "flashy_move",
				"message": "%s performs an unnecessary flourish!"
			}
		}
	}
}

static func check_quirk_trigger(hero: Hero, context: Dictionary, intended_word: String) -> Dictionary:
	var result = {
		"triggered": false,
		"quirk": "",
		"action": "",
		"message": "",
		"priority": 0
	}
	
	# Check each of hero's quirks
	for quirk_id in hero.quirks:
		if not quirk_database.has(quirk_id):
			continue
			
		var quirk_data = quirk_database[quirk_id]
		
		# Check if quirk should trigger
		for trigger_type in quirk_data.triggers:
			if should_trigger(hero, context, intended_word, trigger_type):
				var trigger = quirk_data.triggers[trigger_type]
				
				# Check priority
				if trigger.priority > result.priority:
					result.triggered = true
					result.quirk = quirk_id
					result.action = trigger.action
					result.message = trigger.message % hero.hero_name
					result.priority = trigger.priority
	
	return result

static func should_trigger(hero: Hero, context: Dictionary, word: String, trigger_type: String) -> bool:
	match trigger_type:
		"chest_visible":
			return context.get("chest_count", 0) > 0 and word != "LOOT"
		
		"attack_action":
			return word == "ATTACK" and context.get("enemy_count", 0) > 1
		
		"at_85_percent_hp":
			var hp_percent = float(hero.current_hp) / float(hero.max_hp)
			return hp_percent >= 0.85 and hp_percent < 1.0 and word == "HEAL"
		
		"wizard_attack":
			return hero.class_id == "wizard" and word == "ATTACK"
		
		"below_half_hp":
			return hero.current_hp < hero.max_hp / 2 and word != "DEFEND"
		
		"suboptimal_target":
			return word == "ATTACK" and randf() < 0.3  # Sometimes just picky
		
		"low_health_attack":
			return hero.current_hp < hero.max_hp * 0.3 and word == "ATTACK"
		
		"scary_enemy":
			return context.get("has_boss", false) or context.get("enemy_count", 0) > 4
		
		"alone_with_enemies":
			var alive_allies = 0
			for ally in context.get("party", []):
				if ally != hero and ally.is_alive():
					alive_allies += 1
			return alive_allies == 0 and context.get("enemy_count", 0) > 2
		
		"unknown_enemy":
			return word == "ATTACK" and context.get("new_enemy_type", false)
		
		"enemy_has_shiny":
			return word != "LOOT" and context.get("enemy_has_loot", false)
		
		"flammable_environment":
			return context.get("has_flammables", false)
		
		"non_fire_spell":
			return word in ["CAST", "FIREBALL", "METEOR"] and not word.contains("FIRE")
		
		"can_negotiate":
			return word == "ATTACK" and context.get("enemies_are_sentient", false)
		
		"lethal_blow":
			return word == "ATTACK" and context.get("target_low_hp", false)
		
		"audience_present":
			return context.get("party_size", 1) > 2
		
		_:
			return false

static func apply_quirk_to_action(action: HeroAction, quirk_result: Dictionary):
	match quirk_result.action:
		"force_loot":
			action.type = "loot"
			action.target = get_nearest_chest(action.hero, action.room)
		
		"target_strongest":
			action.target = get_strongest_enemy(action.room)
		
		"force_heal_self":
			action.type = "heal"
			action.target = action.hero
		
		"melee_bonk":
			action.type = "melee_attack"
			action.damage_die = "1d6"
			action.damage_bonus = action.hero.get_mod("STR")
		
		"force_defend":
			action.type = "defend"
			action.ac_bonus = 4  # Extra defensive
		
		"wait_for_better":
			action.type = "wait"
		
		"rage_attack":
			action.damage_multiplier = 2.0
			action.reckless = true  # Enemies have advantage
		
		"hide_behind_ally":
			action.type = "move"
			action.target_position = get_position_behind_ally(action.hero, action.room)
		
		"full_retreat":
			action.type = "dash"
			action.target_position = get_furthest_from_enemies(action.hero, action.room)
		
		"study_first":
			action.type = "study"
		
		"pickpocket":
			action.type = "steal"
			action.target = get_enemy_with_loot(action.room)
		
		"set_fire":
			action.fire_damage = true
			action.environmental_damage = "1d6"
		
		"make_it_fire":
			action.damage_type = "fire"
			action.fire_bonus = "1d6"
		
		"try_diplomacy":
			action.type = "negotiate"
		
		"nonlethal":
			action.nonlethal = true
		
		"flashy_move":
			action.flourish = true
			action.inspiration_chance = 0.5

# Helper functions for quirk actions
static func get_nearest_chest(hero: Hero, room: Room) -> Interactable:
	var nearest = null
	var min_dist = 999
	
	for interactable in room.interactables:
		if interactable.type == "chest" and not interactable.opened:
			var dist = hero.distance_to_position(interactable.grid_position)
			if dist < min_dist:
				min_dist = dist
				nearest = interactable
	
	return nearest

static func get_strongest_enemy(room: Room) -> Enemy:
	var strongest = null
	var max_hp = 0
	
	for enemy in room.get_alive_enemies():
		if enemy.max_hp > max_hp:
			max_hp = enemy.max_hp
			strongest = enemy
	
	return strongest

static func get_position_behind_ally(hero: Hero, room: Room) -> Vector2i:
	var allies = room.get_party().filter(func(h): return h != hero and h.is_alive())
	if allies.is_empty():
		return hero.grid_position
	
	# Find ally between hero and enemies
	var protector = allies[0]
	var enemy_center = room.get_enemy_center()
	
	# Position behind protector
	var direction = (protector.grid_position - Vector2i(enemy_center)).sign()
	return protector.grid_position + direction

static func get_furthest_from_enemies(hero: Hero, room: Room) -> Vector2i:
	# Find corner furthest from all enemies
	var corners = [
		Vector2i(1, 1),
		Vector2i(room.ROOM_WIDTH - 2, 1),
		Vector2i(1, room.ROOM_HEIGHT - 2),
		Vector2i(room.ROOM_WIDTH - 2, room.ROOM_HEIGHT - 2)
	]
	
	var best_pos = hero.grid_position
	var max_dist = 0
	
	for corner in corners:
		if room.is_walkable(corner):
			var total_dist = 0
			for enemy in room.get_alive_enemies():
				total_dist += corner.distance_to(enemy.grid_position)
			
			if total_dist > max_dist:
				max_dist = total_dist
				best_pos = corner
	
	return best_pos

static func get_enemy_with_loot(room: Room) -> Enemy:
	# Prioritize enemies that might drop good loot
	for enemy in room.get_alive_enemies():
		if enemy.has_tag("boss") or enemy.has_tag("elite"):
			return enemy
	
	# Otherwise random enemy
	var enemies = room.get_alive_enemies()
	if enemies.size() > 0:
		return enemies[randi() % enemies.size()]
	
	return null

# Get a random quirk for character creation
static func get_random_quirks(count: int = 2) -> Array:
	var all_quirks = quirk_database.keys()
	all_quirks.shuffle()
	
	var selected = []
	for i in range(min(count, all_quirks.size())):
		selected.append(all_quirks[i])
	
	return selected

# Get quirk name and description
static func get_quirk_info(quirk_id: String) -> Dictionary:
	if quirk_database.has(quirk_id):
		var data = quirk_database[quirk_id]
		return {
			"name": data.name,
			"description": data.description
		}
	return {"name": "Unknown", "description": ""}

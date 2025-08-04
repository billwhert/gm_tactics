# EncounterBuilder.gd - Builds balanced encounters using CR
extends Node
class_name EncounterBuilder

# Environment-specific monster pools
static var environment_monsters = {
	"dungeon": {
		"common": ["goblin", "kobold", "skeleton", "giant_rat", "stirge"],
		"uncommon": ["orc", "hobgoblin", "bugbear", "shadow", "ghoul"],
		"rare": ["ogre", "minotaur", "troll", "wight", "gargoyle"],
		"boss": ["young_black_dragon", "beholder", "mind_flayer"]
	},
	"aquatic": {
		"common": ["merfolk", "sahuagin", "giant_crab", "reef_shark"],
		"uncommon": ["sea_hag", "water_elemental", "giant_octopus", "hunter_shark"],
		"rare": ["aboleth", "kraken_spawn", "dragon_turtle"],
		"boss": ["kraken", "ancient_bronze_dragon"]
	},
	"desert": {
		"common": ["dust_mephit", "giant_scorpion", "hyena", "vulture"],
		"uncommon": ["mummy", "giant_hyena", "sand_elemental", "yuan_ti"],
		"rare": ["blue_dragon_wyrmling", "efreeti", "purple_worm"],
		"boss": ["ancient_blue_dragon", "phoenix"]
	},
	"forest": {
		"common": ["wolf", "dire_wolf", "sprite", "awakened_shrub"],
		"uncommon": ["owlbear", "dryad", "dire_bear", "centaur"],
		"rare": ["treant", "unicorn", "green_dragon_wyrmling"],
		"boss": ["ancient_green_dragon", "archfey"]
	},
	"underdark": {
		"common": ["drow", "duergar", "deep_gnome", "giant_spider"],
		"uncommon": ["drider", "mind_flayer", "umber_hulk", "hook_horror"],
		"rare": ["beholder", "purple_worm", "aboleth"],
		"boss": ["elder_brain", "demon_lord"]
	}
}

# CR to XP conversion (from SRD)
static var cr_to_xp = {
	0.0: 10,
	0.125: 25,
	0.25: 50,
	0.5: 100,
	1.0: 200,
	2.0: 450,
	3.0: 700,
	4.0: 1100,
	5.0: 1800,
	6.0: 2300,
	7.0: 2900,
	8.0: 3900,
	9.0: 5000,
	10.0: 5900
}

# Encounter difficulty thresholds per character level
static var difficulty_thresholds = {
	1: {"easy": 25, "medium": 50, "hard": 75, "deadly": 100},
	2: {"easy": 50, "medium": 100, "hard": 150, "deadly": 200},
	3: {"easy": 75, "medium": 150, "hard": 225, "deadly": 400},
	4: {"easy": 125, "medium": 250, "hard": 375, "deadly": 500},
	5: {"easy": 250, "medium": 500, "hard": 750, "deadly": 1100},
	6: {"easy": 300, "medium": 600, "hard": 900, "deadly": 1400},
	7: {"easy": 350, "medium": 750, "hard": 1100, "deadly": 1700},
	8: {"easy": 450, "medium": 900, "hard": 1400, "deadly": 2100},
	9: {"easy": 550, "medium": 1100, "hard": 1600, "deadly": 2400},
	10: {"easy": 600, "medium": 1200, "hard": 1900, "deadly": 2800}
}

# Encounter multipliers based on number of enemies
static var encounter_multipliers = {
	1: 1.0,
	2: 1.5,
	3: 2.0,
	4: 2.0,
	5: 2.5,
	6: 2.5,
	7: 3.0,
	8: 3.0
}

static func build_encounter(party_level: int, party_size: int, difficulty: String, environment: String, game_data: GameData) -> Array:
	# Calculate XP budget
	var xp_budget = calculate_xp_budget(party_level, party_size, difficulty)
	
	# Get available monsters for environment
	var available_monsters = get_monsters_for_environment(environment, party_level, game_data)
	
	# Build encounter
	return generate_encounter(xp_budget, available_monsters, game_data)

static func calculate_xp_budget(party_level: int, party_size: int, difficulty: String) -> int:
	var threshold = difficulty_thresholds[party_level][difficulty]
	return threshold * party_size

static func get_monsters_for_environment(environment: String, party_level: int, game_data: GameData) -> Array:
	var monsters = []
	var env_data = environment_monsters.get(environment, environment_monsters["dungeon"])
	
	# Determine which rarity tiers to include based on party level
	if party_level <= 3:
		monsters.append_array(env_data["common"])
	elif party_level <= 6:
		monsters.append_array(env_data["common"])
		monsters.append_array(env_data["uncommon"])
	elif party_level <= 9:
		monsters.append_array(env_data["uncommon"])
		monsters.append_array(env_data["rare"])
	else:
		monsters.append_array(env_data["rare"])
		if randf() < 0.2:  # 20% chance of boss
			monsters.append_array(env_data["boss"])
	
	# Filter monsters by CR appropriate for party
	var filtered_monsters = []
	for monster_id in monsters:
		var monster_data = game_data.get_monster(monster_id)
		if monster_data.has("cr"):
			var cr = monster_data["cr"]
			# Include monsters with CR from party_level-2 to party_level+2
			if cr >= max(0.25, party_level - 2) and cr <= party_level + 2:
				filtered_monsters.append(monster_id)
	
	return filtered_monsters

static func generate_encounter(xp_budget: int, available_monsters: Array, game_data: GameData) -> Array:
	var encounter = []
	var spent_xp = 0
	var monster_counts = {}
	
	# Shuffle available monsters
	available_monsters.shuffle()
	
	# Try different combinations
	var attempts = 0
	while spent_xp < xp_budget * 0.8 and attempts < 20:  # Allow 80-100% of budget
		attempts += 1
		
		if available_monsters.is_empty():
			break
		
		# Pick a random monster
		var monster_id = available_monsters[randi() % available_monsters.size()]
		var monster_data = game_data.get_monster(monster_id)
		var monster_xp = cr_to_xp.get(monster_data.get("cr", 1.0), 200)
		
		# Check if we can afford this monster
		var current_count = monster_counts.get(monster_id, 0)
		var total_monsters = encounter.size() + 1
		var multiplier = encounter_multipliers.get(min(total_monsters, 8), 3.0)
		var adjusted_xp = monster_xp * multiplier
		
		if spent_xp + adjusted_xp <= xp_budget:
			encounter.append(monster_id)
			monster_counts[monster_id] = current_count + 1
			spent_xp += adjusted_xp
			
			# Limit same monster type to make encounters varied
			if monster_counts[monster_id] >= 3:
				available_monsters.erase(monster_id)
	
	# If we couldn't build a good encounter, add at least one appropriate monster
	if encounter.is_empty() and not available_monsters.is_empty():
		encounter.append(available_monsters[0])
	
	return encounter

static func get_encounter_difficulty(encounter: Array, party_level: int, party_size: int, game_data: GameData) -> String:
	var total_xp = 0
	
	for monster_id in encounter:
		var monster_data = game_data.get_monster(monster_id)
		var cr = monster_data.get("cr", 1.0)
		total_xp += cr_to_xp.get(cr, 200)
	
	# Apply multiplier
	var multiplier = encounter_multipliers.get(min(encounter.size(), 8), 3.0)
	var adjusted_xp = total_xp * multiplier
	
	# Get thresholds
	var thresholds = difficulty_thresholds[party_level]
	var party_thresholds = {
		"easy": thresholds["easy"] * party_size,
		"medium": thresholds["medium"] * party_size,
		"hard": thresholds["hard"] * party_size,
		"deadly": thresholds["deadly"] * party_size
	}
	
	# Determine difficulty
	if adjusted_xp >= party_thresholds["deadly"]:
		return "deadly"
	elif adjusted_xp >= party_thresholds["hard"]:
		return "hard"
	elif adjusted_xp >= party_thresholds["medium"]:
		return "medium"
	else:
		return "easy"

# Helper function to get a balanced mix of encounters for a dungeon
static func generate_dungeon_encounters(party_level: int, party_size: int, num_rooms: int, environment: String, game_data: GameData) -> Array:
	var encounters = []
	
	# Distribution of difficulties
	var difficulty_distribution = {
		"easy": 0.3,
		"medium": 0.4,
		"hard": 0.25,
		"deadly": 0.05
	}
	
	for i in range(num_rooms):
		# Roll for difficulty
		var roll = randf()
		var difficulty = "medium"
		var cumulative = 0.0
		
		for diff in difficulty_distribution:
			cumulative += difficulty_distribution[diff]
			if roll < cumulative:
				difficulty = diff
				break
		
		# Some rooms might be empty
		if randf() < 0.15:  # 15% chance of empty room
			encounters.append([])
		else:
			var encounter = build_encounter(party_level, party_size, difficulty, environment, game_data)
			encounters.append(encounter)
	
	return encounters

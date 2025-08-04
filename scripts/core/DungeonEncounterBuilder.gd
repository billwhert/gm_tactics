# DungeonEncounterBuilder.gd - Builds thematic dungeon encounters
extends Node
class_name DungeonEncounterBuilder

# Encounter templates for different dungeon themes
static var encounter_templates = {
	"goblin_lair": {
		"common": ["goblin_minion", "goblin_warrior"],
		"uncommon": ["goblin_boss", "bugbear_warrior"],
		"guards": ["hobgoblin_warrior", "worg"],
		"boss": ["bugbear_stalker", "ogre"]
	},
	
	"undead_crypt": {
		"common": ["skeleton", "zombie"],
		"uncommon": ["ghoul", "shadow", "specter"],
		"guards": ["ghast", "wight"],
		"boss": ["wraith", "mummy", "vampire_spawn"]
	},
	
	"cult_hideout": {
		"common": ["cultist", "guard"],
		"uncommon": ["cultist_fanatic", "bandit_captain"],
		"guards": ["priest_acolyte", "animated_armor"],
		"boss": ["priest", "imp", "quasit"]
	},
	
	"abandoned_fortress": {
		"common": ["animated_armor", "skeleton", "stirge"],
		"uncommon": ["gargoyle", "animated_flying_sword", "specter"],
		"guards": ["animated_rug", "mimic"],
		"boss": ["shield_guardian", "stone_golem"]
	},
	
	"thieves_den": {
		"common": ["bandit", "thug", "scout"],
		"uncommon": ["bandit_captain", "spy", "assassin"],
		"guards": ["veteran", "gladiator"],
		"boss": ["assassin", "doppelganger"]
	},
	
	"natural_cavern": {
		"common": ["giant_bat", "stirge", "giant_spider"],
		"uncommon": ["darkmantle", "grick", "rust_monster"],
		"guards": ["ettercap", "giant_wolf_spider"],
		"boss": ["roper", "otyugh", "gibbering_mouther"]
	}
}

# Dungeon hazards and traps (not monsters but environmental challenges)
static var dungeon_hazards = [
	"pit_trap", "poison_dart", "rolling_boulder", "swinging_blade",
	"fire_trap", "poison_gas", "collapsing_ceiling", "flooding_room"
]

# Build a themed encounter
static func build_themed_encounter(
	theme: String, 
	party_level: int, 
	party_size: int, 
	difficulty: String,
	room_type: String,
	game_data: GameData
) -> Dictionary:
	
	var result = {
		"monsters": [],
		"hazards": [],
		"treasure": false
	}
	
	# Get appropriate monster pool for theme
	var monster_pool = []
	if encounter_templates.has(theme):
		var template = encounter_templates[theme]
		
		match room_type:
			"entrance":
				monster_pool = template["common"]
			"guard_room":
				monster_pool = template["guards"]
			"boss_room":
				monster_pool = template["boss"]
			_:
				# Standard room - mix of common and uncommon
				monster_pool = template["common"] + template["uncommon"]
	
	# Calculate XP budget
	var xp_budget = EncounterBuilder.calculate_xp_budget(party_level, party_size, difficulty)
	
	# Build encounter from themed pool
	result["monsters"] = generate_themed_encounter(xp_budget, monster_pool, game_data)
	
	# Add hazards for harder difficulties
	if difficulty == "hard" or difficulty == "deadly":
		if randf() < 0.3:  # 30% chance
			result["hazards"].append(dungeon_hazards[randi() % dungeon_hazards.size()])
	
	# Treasure chances
	match room_type:
		"boss_room":
			result["treasure"] = true
		"guard_room":
			result["treasure"] = randf() < 0.5
		_:
			result["treasure"] = randf() < 0.2
	
	return result

static func generate_themed_encounter(xp_budget: int, monster_pool: Array, game_data: GameData) -> Array:
	var encounter = []
	var spent_xp = 0
	
	# Shuffle pool
	monster_pool.shuffle()
	
	for monster_id in monster_pool:
		var monster_data = game_data.get_monster(monster_id)
		if not monster_data:
			continue
			
		var monster_xp = EncounterBuilder.cr_to_xp.get(monster_data.get("cr", 0.25), 50)
		var multiplier = EncounterBuilder.encounter_multipliers.get(encounter.size() + 1, 1.0)
		var adjusted_xp = monster_xp * multiplier
		
		if spent_xp + adjusted_xp <= xp_budget:
			encounter.append(monster_id)
			spent_xp += adjusted_xp
			
			# Maybe add more of the same type for swarm feel
			if monster_id in ["goblin_minion", "skeleton", "zombie", "cultist"]:
				while spent_xp + adjusted_xp <= xp_budget and encounter.count(monster_id) < 4:
					encounter.append(monster_id)
					spent_xp += adjusted_xp
					multiplier = EncounterBuilder.encounter_multipliers.get(encounter.size(), 1.0)
					adjusted_xp = monster_xp * multiplier
		
		if spent_xp >= xp_budget * 0.8:
			break
	
	return encounter

# Generate a full dungeon with connected encounters
static func generate_dungeon_layout(
	num_rooms: int,
	party_level: int,
	party_size: int,
	theme: String,
	game_data: GameData
) -> Array:
	
	var dungeon_rooms = []
	
	for i in range(num_rooms):
		var room = {
			"number": i + 1,
			"type": "standard",
			"encounter": {},
			"connections": []
		}
		
		# Determine room type
		if i == 0:
			room["type"] = "entrance"
		elif i == num_rooms - 1:
			room["type"] = "boss_room"
		elif i % 3 == 0:
			room["type"] = "guard_room"
		elif randf() < 0.15:
			room["type"] = "treasure_room"
		elif randf() < 0.1:
			room["type"] = "trap_room"
		
		# Determine difficulty
		var difficulty = "medium"
		match room["type"]:
			"entrance":
				difficulty = "easy"
			"boss_room":
				difficulty = "deadly"
			"guard_room":
				difficulty = "hard"
			"trap_room":
				difficulty = "hard"
				room["encounter"] = {"monsters": [], "hazards": [dungeon_hazards[randi() % dungeon_hazards.size()]], "treasure": false}
			_:
				# Random difficulty for standard rooms
				var roll = randf()
				if roll < 0.3:
					difficulty = "easy"
				elif roll < 0.7:
					difficulty = "medium"
				else:
					difficulty = "hard"
		
		# Generate encounter (unless it's a special room type)
		if room["type"] != "trap_room":
			room["encounter"] = build_themed_encounter(
				theme,
				party_level,
				party_size,
				difficulty,
				room["type"],
				game_data
			)
		
		# Simple connections (linear for now)
		if i > 0:
			room["connections"].append(i - 1)
			dungeon_rooms[i - 1]["connections"].append(i)
		
		dungeon_rooms.append(room)
	
	return dungeon_rooms

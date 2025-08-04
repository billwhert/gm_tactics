# SRDMonsterEnvironments.gd - Organizing SRD monsters by environment
extends Resource
class_name SRDMonsterEnvironments

# Monsters organized by their likely environments
# Based on the actual SRD 5.2.1 Index provided in images
static var environment_monsters = {
	"dungeon": [
		# Common dungeon inhabitants
		"animated_armor", "animated_flying_sword", "ankheg",
		"assassin", "axe_beak", "azer_sentinel",
		"bandit", "bandit_captain", "barbed_devil", "basilisk",
		"black_pudding", "bugbear_stalker", "bugbear_warrior", "bulette",
		"carrion_crawler", "centaur_trooper", "chain_devil", "chimera",
		"cloaker", "cockatrice", "couatl", "cultist", "cultist_fanatic",
		"darkmantle", "death_dog", "doppelganger", "dretch", "drider",
		"dryad", "dust_mephit", "ettin", "gargoyle", "gelatinous_cube",
		"ghast", "ghost", "ghoul", "gibbering_mouther", "glabrezu",
		"gnoll_warrior", "goblin_boss", "goblin_minion", "goblin_warrior",
		"gorgon", "gray_ooze", "grick", "grimlock", "guard", "guard_captain",
		"guardian_naga", "hell_hound", "hobgoblin_captain", "hobgoblin_warrior",
		"homunculus", "imp", "invisible_stalker", "iron_golem",
		"kobold_warrior", "lemure", "lich", "mage", "medusa",
		"mimic", "minotaur_of_baphomet", "minotaur_skeleton", "mummy",
		"night_hag", "ochre_jelly", "ogre", "ogre_zombie", "oni",
		"otyugh", "phase_spider", "priest", "priest_acolyte",
		"quasit", "rakshasa", "roper", "rust_monster", "shadow",
		"shambling_mound", "shield_guardian", "skeleton", "specter",
		"stone_golem", "succubus", "swarm_of_rats", "troll",
		"vampire", "vampire_spawn", "violet_fungus", "wight",
		"will_o_wisp", "wraith", "xorn", "zombie"
	],
	
	"forest": [
		# Forest and woodland creatures
		"ankheg", "ape", "awakened_shrub", "awakened_tree",
		"axe_beak", "baboon", "badger", "bandit", "basilisk",
		"black_bear", "blink_dog", "blood_hawk", "boar", "brown_bear",
		"bugbear_stalker", "bugbear_warrior", "centaur_trooper", "cockatrice",
		"couatl", "deer", "dire_wolf", "dryad", "elk", "ettercap",
		"giant_ape", "giant_badger", "giant_bat", "giant_boar",
		"giant_elk", "giant_owl", "giant_spider", "giant_wasp",
		"giant_weasel", "giant_wolf_spider", "gnoll_warrior", "goblin_warrior",
		"green_hag", "grick", "griffon", "hawk", "hobgoblin_warrior",
		"jackal", "lion", "lizard", "ogre", "orc", "owlbear",
		"panther", "pegasus", "phase_spider", "pixie", "pseudodragon",
		"rat", "raven", "satyr", "spider", "sprite", "stirge",
		"swarm_of_insects", "swarm_of_ravens", "tiger", "treant",
		"troll", "unicorn", "weasel", "werebear", "wereboar",
		"weretiger", "werewolf", "wolf", "worg", "wyvern"
	],
	
	"swamp": [
		# Swamp and marsh creatures
		"black_dragon_wyrmling", "young_black_dragon", "adult_black_dragon",
		"ancient_black_dragon", "crocodile", "darkmantle", "giant_constrictor_snake",
		"giant_crocodile", "giant_frog", "giant_lizard", "giant_toad",
		"giant_venomous_snake", "green_hag", "hydra", "lizard",
		"ochre_jelly", "otyugh", "shambling_mound", "stirge",
		"swarm_of_insects", "swarm_of_piranhas", "swarm_of_rats",
		"troll", "will_o_wisp", "zombie"
	],
	
	"aquatic": [
		# Water-dwelling creatures
		"aboleth", "constrictor_snake", "crab", "crocodile",
		"dragon_turtle", "giant_constrictor_snake", "giant_crab",
		"giant_crocodile", "giant_octopus", "giant_seahorse", "giant_shark",
		"hunter_shark", "hydra", "killer_whale", "kraken",
		"merfolk_skirmisher", "merrow", "octopus", "piranha",
		"plesiosaurus", "reef_shark", "sahuagin_warrior", "sea_hag",
		"seahorse", "shark", "swarm_of_piranhas", "swarm_of_ravens",
		"water_elemental"
	],
	
	"mountain": [
		# Mountain and high altitude creatures
		"air_elemental", "basilisk", "brown_bear", "chimera",
		"cloud_giant", "couatl", "eagle", "earth_elemental", "ettin",
		"fire_giant", "frost_giant", "gargoyle", "giant_eagle",
		"giant_goat", "griffon", "harpy", "hawk", "hippogriff",
		"manticore", "ogre", "orc", "pegasus", "peryton",
		"roc", "stone_giant", "stone_golem", "wyvern"
	],
	
	"desert": [
		# Desert and arid region creatures
		"blue_dragon_wyrmling", "young_blue_dragon", "adult_blue_dragon",
		"ancient_blue_dragon", "brass_dragon_wyrmling", "young_brass_dragon",
		"adult_brass_dragon", "ancient_brass_dragon", "camel", "death_dog",
		"dust_mephit", "fire_elemental", "giant_hyena", "giant_scorpion",
		"giant_vulture", "gnoll_warrior", "hyena", "jackal", "lamia",
		"lion", "mummy", "mummy_lord", "scorpion", "vulture"
	],
	
	"arctic": [
		# Cold and frozen region creatures
		"frost_giant", "giant_elk", "ice_mephit", "mammoth",
		"polar_bear", "remorhaz", "saber_toothed_tiger", "winter_wolf",
		"white_dragon_wyrmling", "young_white_dragon", "adult_white_dragon",
		"ancient_white_dragon", "yeti"
	],
	
	"urban": [
		# City and town encounters
		"animated_armor", "assassin", "bandit", "bandit_captain",
		"cat", "commoner", "cultist", "cultist_fanatic", "doppelganger",
		"draft_horse", "gargoyle", "ghost", "guard", "guard_captain",
		"invisible_stalker", "knight", "mage", "mastiff", "mimic",
		"noble", "priest", "priest_acolyte", "pseudodragon", "rat",
		"raven", "riding_horse", "scout", "shadow", "specter",
		"spy", "swarm_of_rats", "swarm_of_ravens", "thug", "vampire",
		"vampire_spawn", "warhorse", "wererat", "will_o_wisp", "zombie"
	],
	
	"underground": [
		# Deep underground/Underdark creatures
		"aboleth", "basilisk", "black_pudding", "bulette", "carrion_crawler",
		"chuul", "clay_golem", "cloaker", "darkmantle", "drider",
		"duergar", "earth_elemental", "ettercap", "gargoyle", "gelatinous_cube",
		"ghast", "ghoul", "giant_bat", "giant_centipede", "giant_spider",
		"grick", "grimlock", "hook_horror", "iron_golem", "minotaur",
		"otyugh", "phase_spider", "purple_worm", "roper", "rust_monster",
		"shadow", "stone_golem", "troglodyte", "umber_hulk", "violet_fungus",
		"xorn"
	],
	
	"planar": [
		# Creatures from other planes
		"azer_sentinel", "barbed_devil", "bearded_devil", "bone_devil",
		"chain_devil", "couatl", "deva", "djinni", "dretch", "efreeti",
		"erinyes", "fire_elemental", "glabrezu", "hell_hound", "hezrou",
		"horned_devil", "ice_devil", "imp", "incubus", "invisible_stalker",
		"lemure", "marilith", "nalfeshnee", "nightmare", "pit_fiend",
		"planetar", "quasit", "rakshasa", "salamander", "solar",
		"succubus", "vrock"
	],
	
	"any": [
		# Creatures that could appear almost anywhere
		"bat", "cat", "commoner", "eagle", "frog", "hawk",
		"owl", "rat", "raven", "spider", "weasel",
		# Shape-changers and undead can appear anywhere
		"doppelganger", "ghost", "shadow", "skeleton", "specter",
		"vampire", "werewolf", "wight", "wraith", "zombie"
	]
}

# Special categories
static var dragons_by_type = {
	"black": ["black_dragon_wyrmling", "young_black_dragon", "adult_black_dragon", "ancient_black_dragon"],
	"blue": ["blue_dragon_wyrmling", "young_blue_dragon", "adult_blue_dragon", "ancient_blue_dragon"],
	"brass": ["brass_dragon_wyrmling", "young_brass_dragon", "adult_brass_dragon", "ancient_brass_dragon"],
	"bronze": ["bronze_dragon_wyrmling", "young_bronze_dragon", "adult_bronze_dragon", "ancient_bronze_dragon"],
	"copper": ["copper_dragon_wyrmling", "young_copper_dragon", "adult_copper_dragon", "ancient_copper_dragon"],
	"gold": ["gold_dragon_wyrmling", "young_gold_dragon", "adult_gold_dragon", "ancient_gold_dragon"],
	"green": ["green_dragon_wyrmling", "young_green_dragon", "adult_green_dragon", "ancient_green_dragon"],
	"red": ["red_dragon_wyrmling", "young_red_dragon", "adult_red_dragon", "ancient_red_dragon"],
	"silver": ["silver_dragon_wyrmling", "young_silver_dragon", "adult_silver_dragon", "ancient_silver_dragon"],
	"white": ["white_dragon_wyrmling", "young_white_dragon", "adult_white_dragon", "ancient_white_dragon"]
}

static var giants_list = [
	"cloud_giant", "fire_giant", "frost_giant", "hill_giant", "stone_giant", "storm_giant"
]

static var elementals_list = [
	"air_elemental", "earth_elemental", "fire_elemental", "water_elemental",
	"dust_mephit", "ice_mephit", "magma_mephit", "steam_mephit"
]

static var constructs_list = [
	"animated_armor", "animated_flying_sword", "clay_golem", "flesh_golem",
	"homunculus", "iron_golem", "shield_guardian", "stone_golem"
]

static var oozes_list = [
	"black_pudding", "gelatinous_cube", "gray_ooze", "ochre_jelly"
]

static var undead_list = [
	"banshee", "death_knight", "ghast", "ghost", "ghoul", "lich",
	"minotaur_skeleton", "mummy", "mummy_lord", "shadow", "skeleton",
	"specter", "vampire", "vampire_familiar", "vampire_spawn",
	"warhorse_skeleton", "wight", "will_o_wisp", "wraith", "zombie"
]

# Function to get monsters for a specific environment
static func get_monsters_for_environment(environment: String) -> Array:
	var monsters = []
	
	if environment_monsters.has(environment):
		monsters.append_array(environment_monsters[environment])
	
	# Always include "any" environment monsters
	monsters.append_array(environment_monsters["any"])
	
	# Remove duplicates
	var unique_monsters = []
	for monster in monsters:
		if not monster in unique_monsters:
			unique_monsters.append(monster)
	
	return unique_monsters

# HybridWordSystem.gd - Core hybrid word system with personal + shared pools
extends Node
class_name HybridWordSystem

# Word pools
var shared_pool: Array[WordCard] = []
var shared_pool_available: Array[WordCard] = []  # Tracks which shared words are still available
var hero_class_words: Dictionary = {}  # hero -> array of class words
var basic_actions = ["ATTACK", "DEFEND", "MOVE"]

# Word uses tracking
var word_uses: Dictionary = {}  # hero_id + word -> current uses
var word_max_uses: Dictionary = {}  # hero_id + word -> max uses

# Class word definitions by level
var class_word_progression = {
	"fighter": {
		1: [
			{"id": "CLEAVE", "uses": 3, "description": "Attack all adjacent enemies"},
			{"id": "BLOCK", "uses": 2, "description": "Reduce damage by 50% this turn"}
		],
		3: [
			{"id": "RALLY", "uses": 1, "description": "All allies +2 attack next turn"},
			{"id": "CHARGE", "uses": 2, "description": "Move and attack with +damage"}
		],
		5: [
			{"id": "WHIRLWIND", "uses": 1, "description": "Attack all enemies in room"}
		],
		7: [
			{"id": "CHAMPION", "uses": 1, "description": "Double damage for 3 turns"}
		]
	},
	"wizard": {
		1: [
			{"id": "MAGIC_MISSILE", "uses": 3, "description": "Auto-hit 3 damage"},
			{"id": "SHIELD", "uses": 2, "description": "+5 AC until next turn"}
		],
		3: [
			{"id": "FIREBALL", "uses": 2, "description": "8d6 damage in area"},
			{"id": "MISTY_STEP", "uses": 2, "description": "Teleport to any tile"}
		],
		5: [
			{"id": "TELEPORT", "uses": 1, "description": "Move party to any position"}
		],
		7: [
			{"id": "METEOR", "uses": 1, "description": "Massive damage to all enemies"}
		]
	},
	"cleric": {
		1: [
			{"id": "HEAL", "uses": 3, "description": "Restore 2d4+WIS hp"},
			{"id": "BLESS", "uses": 2, "description": "Ally +1d4 to attacks"}
		],
		3: [
			{"id": "SANCTUARY", "uses": 1, "description": "Ally can't be targeted"},
			{"id": "SPIRITUAL_WEAPON", "uses": 2, "description": "Summon attacking weapon"}
		],
		5: [
			{"id": "REVIVE", "uses": 1, "description": "Bring back fallen ally"}
		],
		7: [
			{"id": "DIVINE", "uses": 1, "description": "Party invulnerable 1 turn"}
		]
	},
	"rogue": {
		1: [
			{"id": "SNEAK", "uses": 3, "description": "Next attack has advantage"},
			{"id": "POISON", "uses": 2, "description": "Target takes damage over time"}
		],
		3: [
			{"id": "VANISH", "uses": 2, "description": "Invisible for 2 turns"},
			{"id": "SMOKE_BOMB", "uses": 1, "description": "All enemies miss next attack"}
		],
		5: [
			{"id": "ASSASSINATE", "uses": 1, "description": "Instant kill if target < 50% hp"}
		],
		7: [
			{"id": "SHADOW_CLONE", "uses": 1, "description": "Create duplicate for 3 turns"}
		]
	}
}

# Shared word pool options (draw from these)
var shared_word_pool = [
	"LOOT", "HEAL", "INSPIRE", "DASH", "STUDY", "FOCUS", 
	"GUARD", "TAUNT", "HIDE", "SEARCH", "PRAY", "RAGE",
	"DODGE", "PARRY", "INTIMIDATE", "ENCOURAGE"
]

signal word_assigned(hero: Hero, word: WordCard)
signal shared_word_claimed(word: WordCard, hero: Hero)
signal class_word_used(hero: Hero, word: String, uses_left: int)

func initialize_hero_words(hero: Hero):
	var class_words = []
	var class_data = class_word_progression.get(hero.class_id, {})
	
	# Add words based on hero level
	for level in class_data:
		if hero.level >= level:
			for word_data in class_data[level]:
				class_words.append(word_data)
				
				# Initialize uses
				var key = hero.id + "_" + word_data.id
				word_uses[key] = word_data.uses
				word_max_uses[key] = word_data.uses
	
	hero_class_words[hero] = class_words

func draw_shared_pool(party_size: int, party_level: int):
	shared_pool.clear()
	shared_pool_available.clear()
	
	# Draw size scales with party level
	var draw_count = 3 + (party_level / 2)
	
	# Shuffle and draw
	var available = shared_word_pool.duplicate()
	available.shuffle()
	
	for i in min(draw_count, available.size()):
		var word = WordCard.new(available[i])
		shared_pool.append(word)
		shared_pool_available.append(word)

func get_available_words_for_hero(hero: Hero) -> Array[WordCard]:
	var available = []
	
	# Always add basic actions
	for basic in basic_actions:
		var card = WordCard.new(basic)
		card.custom_data["type"] = "basic"
		available.append(card)
	
	# Add class words with remaining uses
	if hero in hero_class_words:
		for word_data in hero_class_words[hero]:
			var key = hero.id + "_" + word_data.id
			if word_uses.get(key, 0) > 0:
				var card = WordCard.new(word_data.id)
				card.custom_data["type"] = "class"
				card.custom_data["uses_left"] = word_uses[key]
				card.custom_data["max_uses"] = word_max_uses[key]
				card.description = word_data.description
				available.append(card)
	
	# Add available shared pool words
	for word in shared_pool_available:
		var card = word.clone()
		card.custom_data["type"] = "shared"
		available.append(card)
	
	return available

func can_hero_use_word(hero: Hero, word: WordCard) -> bool:
	var word_type = word.custom_data.get("type", "")
	
	match word_type:
		"basic":
			return true  # Always can use basics
		"class":
			var key = hero.id + "_" + word.word
			return word_uses.get(key, 0) > 0
		"shared":
			return word in shared_pool_available
		_:
			return false

func assign_word_to_hero(hero: Hero, word: WordCard) -> bool:
	if not can_hero_use_word(hero, word):
		return false
	
	var word_type = word.custom_data.get("type", "")
	
	match word_type:
		"class":
			# Consume a use
			var key = hero.id + "_" + word.word
			word_uses[key] -= 1
			emit_signal("class_word_used", hero, word.word, word_uses[key])
		"shared":
			# Remove from available pool
			shared_pool_available.erase(word)
			emit_signal("shared_word_claimed", word, hero)
	
	emit_signal("word_assigned", hero, word)
	return true

func restore_all_uses(hero: Hero):
	# Restore all class word uses
	if hero in hero_class_words:
		for word_data in hero_class_words[hero]:
			var key = hero.id + "_" + word_data.id
			word_uses[key] = word_max_uses[key]

func restore_single_use(hero: Hero, word_id: String):
	var key = hero.id + "_" + word_id
	if key in word_uses and word_uses[key] < word_max_uses[key]:
		word_uses[key] += 1
		return true
	return false

func get_word_uses_display(hero: Hero) -> String:
	var display = "Class Words:\n"
	
	if hero in hero_class_words:
		for word_data in hero_class_words[hero]:
			var key = hero.id + "_" + word_data.id
			var current = word_uses.get(key, 0)
			var max_uses = word_max_uses.get(key, 0)
			display += "  %s (%d/%d)\n" % [word_data.id, current, max_uses]
	
	return display

# Camp word effects
func apply_camp_word(word: String, hero: Hero = null, party: Array = []):
	match word:
		"MEDITATE":
			if hero:
				# Show selection of class words to restore
				var restored = restore_random_class_word(hero)
				print("%s meditates and restores %s" % [hero.hero_name, restored])
		
		"PRACTICE":
			if hero:
				# Temporarily increase uses
				var boosted = boost_random_class_word(hero)
				print("%s practices %s (+1 use next combat)" % [hero.hero_name, boosted])
		
		"STUDY":
			# Preview next room's shared pool
			print("Next room will have: %s" % preview_next_shared_pool())

func restore_random_class_word(hero: Hero) -> String:
	var restorable = []
	
	if hero in hero_class_words:
		for word_data in hero_class_words[hero]:
			var key = hero.id + "_" + word_data.id
			if word_uses[key] < word_max_uses[key]:
				restorable.append(word_data.id)
	
	if restorable.is_empty():
		return "nothing"
	
	var chosen = restorable[randi() % restorable.size()]
	restore_single_use(hero, chosen)
	return chosen

func boost_random_class_word(hero: Hero) -> String:
	if not hero in hero_class_words or hero_class_words[hero].is_empty():
		return "nothing"
	
	var word_data = hero_class_words[hero][randi() % hero_class_words[hero].size()]
	var key = hero.id + "_" + word_data.id
	
	# Temporarily increase max uses
	word_max_uses[key] += 1
	word_uses[key] += 1
	
	return word_data.id

func preview_next_shared_pool() -> Array:
	# Generate preview of next room's words
	var preview = []
	var available = shared_word_pool.duplicate()
	available.shuffle()
	
	for i in min(3, available.size()):
		preview.append(available[i])
	
	return preview

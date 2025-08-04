# MomentumSystem.gd - Tracks and applies momentum bonuses
extends Node
class_name MomentumSystem

# Momentum tracking
var word_momentum: Dictionary = {}  # word -> momentum level
var combo_tracker: Dictionary = {}   # hero -> recent words
var variety_bonus: float = 0.0
var repetition_bonus: Dictionary = {} # word -> stacking bonus

# Momentum thresholds
const MOMENTUM_LEVELS = {
	0: {"name": "Normal", "multiplier": 1.0},
	3: {"name": "Building", "multiplier": 1.1},
	5: {"name": "Flowing", "multiplier": 1.25},
	8: {"name": "Surging", "multiplier": 1.5},
	12: {"name": "Unstoppable", "multiplier": 2.0}
}

const VARIETY_THRESHOLD = 5  # Different words in last N turns
const COMBO_WINDOW = 3      # Turns to maintain combo

signal momentum_changed(word: String, level: int)
signal combo_achieved(hero: Hero, combo: Array)
signal variety_bonus_gained(bonus: float)

func _ready():
	reset_momentum()

func reset_momentum():
	word_momentum.clear()
	combo_tracker.clear()
	variety_bonus = 0.0
	repetition_bonus.clear()

func track_word_use(hero: Hero, word: String):
	# Track individual word momentum
	word_momentum[word] = word_momentum.get(word, 0) + 1
	
	# Track hero's word sequence
	if not hero in combo_tracker:
		combo_tracker[hero] = []
	
	combo_tracker[hero].append(word)
	if combo_tracker[hero].size() > COMBO_WINDOW:
		combo_tracker[hero].pop_front()
	
	# Check for combos
	check_combos(hero)
	
	# Update variety tracking
	update_variety_bonus()
	
	# Update repetition bonus
	update_repetition_bonus(word)
	
	# Emit momentum change
	var level = get_momentum_level(word)
	emit_signal("momentum_changed", word, level)

func get_momentum_level(word: String) -> int:
	var uses = word_momentum.get(word, 0)
	var level = 0
	
	for threshold in MOMENTUM_LEVELS:
		if uses >= threshold:
			level = threshold
	
	return level

func get_momentum_multiplier(word: String) -> float:
	var level = get_momentum_level(word)
	return MOMENTUM_LEVELS[level].multiplier

func get_total_multiplier(hero: Hero, word: String) -> float:
	var base = get_momentum_multiplier(word)
	var variety = 1.0 + variety_bonus
	var repetition = repetition_bonus.get(word, 0.0)
	var combo = get_combo_multiplier(hero)
	
	return base * variety * (1.0 + repetition) * combo

func check_combos(hero: Hero):
	if not hero in combo_tracker:
		return
	
	var recent_words = combo_tracker[hero]
	
	# Check for specific combos
	if recent_words == ["ATTACK", "ATTACK", "ATTACK"]:
		emit_signal("combo_achieved", hero, recent_words)
		apply_combo_effect(hero, "triple_strike")
	
	elif recent_words == ["DEFEND", "COUNTER", "ATTACK"]:
		emit_signal("combo_achieved", hero, recent_words)
		apply_combo_effect(hero, "perfect_riposte")
	
	elif recent_words == ["MOVE", "HIDE", "ATTACK"]:
		emit_signal("combo_achieved", hero, recent_words)
		apply_combo_effect(hero, "ambush")
	
	elif recent_words == ["CAST", "CAST", "CAST"]:
		emit_signal("combo_achieved", hero, recent_words)
		apply_combo_effect(hero, "spell_cascade")
	
	elif recent_words.size() == COMBO_WINDOW and is_all_different(recent_words):
		emit_signal("combo_achieved", hero, recent_words)
		apply_combo_effect(hero, "variety_master")

func is_all_different(words: Array) -> bool:
	var unique = {}
	for word in words:
		if word in unique:
			return false
		unique[word] = true
	return true

func apply_combo_effect(hero: Hero, combo_type: String):
	match combo_type:
		"triple_strike":
			hero.temp_modifiers["damage"] = hero.temp_modifiers.get("damage", 0) + 0.5
			print("%s achieves Triple Strike! +50%% damage this turn!" % hero.hero_name)
		
		"perfect_riposte":
			hero.temp_modifiers["counter_chance"] = 1.0
			print("%s achieves Perfect Riposte! Guaranteed counter!" % hero.hero_name)
		
		"ambush":
			hero.temp_modifiers["crit_chance"] = hero.temp_modifiers.get("crit_chance", 0) + 0.5
			print("%s achieves Ambush! +50%% crit chance!" % hero.hero_name)
		
		"spell_cascade":
			hero.temp_modifiers["spell_echo"] = true
			print("%s achieves Spell Cascade! Spells echo!" % hero.hero_name)
		
		"variety_master":
			hero.temp_modifiers["all_bonus"] = 0.25
			print("%s achieves Variety Master! +25%% to everything!" % hero.hero_name)

func update_variety_bonus():
	# Count unique words used in last N turns
	var all_recent_words = []
	for hero in combo_tracker:
		all_recent_words.append_array(combo_tracker[hero])
	
	var unique_words = {}
	for word in all_recent_words:
		unique_words[word] = true
	
	var old_bonus = variety_bonus
	variety_bonus = min(0.5, unique_words.size() * 0.05)  # 5% per unique word, max 50%
	
	if variety_bonus > old_bonus:
		emit_signal("variety_bonus_gained", variety_bonus)

func update_repetition_bonus(word: String):
	# Consecutive uses of the same word build up power
	var consecutive = count_consecutive_uses(word)
	
	if consecutive >= 2:
		repetition_bonus[word] = min(0.5, consecutive * 0.1)  # 10% per consecutive use, max 50%
	else:
		repetition_bonus.erase(word)

func count_consecutive_uses(word: String) -> int:
	var count = 0
	var all_recent = []
	
	# Collect all recent words in order
	for hero in combo_tracker:
		all_recent.append_array(combo_tracker[hero])
	
	# Count from the end backwards
	for i in range(all_recent.size() - 1, -1, -1):
		if all_recent[i] == word:
			count += 1
		else:
			break
	
	return count

func get_combo_multiplier(hero: Hero) -> float:
	if hero.temp_modifiers.has("all_bonus"):
		return 1.0 + hero.temp_modifiers["all_bonus"]
	return 1.0

func get_momentum_description(word: String) -> String:
	var level = get_momentum_level(word)
	var level_name = MOMENTUM_LEVELS[level].name
	var multiplier = MOMENTUM_LEVELS[level].multiplier
	var uses = word_momentum.get(word, 0)
	
	var desc = "Momentum: %s (×%.1f)" % [level_name, multiplier]
	
	if repetition_bonus.has(word):
		desc += "\nRepetition Bonus: +%.0f%%" % (repetition_bonus[word] * 100)
	
	if variety_bonus > 0:
		desc += "\nVariety Bonus: +%.0f%%" % (variety_bonus * 100)
	
	desc += "\nTotal Uses: %d" % uses
	
	return desc

# Visual feedback helper
func get_momentum_color(word: String) -> Color:
	var level = get_momentum_level(word)
	
	match level:
		0:
			return Color.WHITE
		3:
			return Color(1.0, 1.0, 0.5)  # Light yellow
		5:
			return Color(1.0, 0.8, 0.0)  # Gold
		8:
			return Color(1.0, 0.5, 0.0)  # Orange
		12:
			return Color(1.0, 0.0, 0.0)  # Red
		_:
			return Color.WHITE

# Persistence
func save_momentum_state() -> Dictionary:
	return {
		"word_momentum": word_momentum,
		"variety_bonus": variety_bonus,
		"repetition_bonus": repetition_bonus
	}

func load_momentum_state(data: Dictionary):
	word_momentum = data.get("word_momentum", {})
	variety_bonus = data.get("variety_bonus", 0.0)
	repetition_bonus = data.get("repetition_bonus", {})

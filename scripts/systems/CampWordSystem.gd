# CampWordSystem.gd - Special words available during rest
extends Node
class_name CampWordSystem

# Camp word definitions
var camp_words = {
	"COOK": {
		"description": "Party heals 1d4 HP and gains +1 morale",
		"effect": "party_heal_morale",
		"target": "party",
		"animation": "cooking_pot"
	},
	"WATCH": {
		"description": "Reveal next 2 rooms, party gains +2 initiative",
		"effect": "scout_initiative", 
		"target": "party",
		"animation": "looking_forward"
	},
	"SHARPEN": {
		"description": "Hero gains +2 damage next combat",
		"effect": "damage_boost",
		"target": "single",
		"animation": "weapon_sharpen"
	},
	"MEDITATE": {
		"description": "Restore 1 use of a class word",
		"effect": "restore_ability",
		"target": "single",
		"animation": "meditation"
	},
	"SCOUT": {
		"description": "Find secret room if one exists nearby",
		"effect": "find_secrets",
		"target": "party",
		"animation": "searching"
	},
	"GAMBLE": {
		"description": "Risk 50 gold for 50% chance at 150 gold",
		"effect": "gold_gamble",
		"target": "party",
		"animation": "dice_roll"
	},
	"TRAIN": {
		"description": "Hero gains +1 to primary stat next combat",
		"effect": "stat_boost",
		"target": "single",
		"animation": "training"
	},
	"PRAY": {
		"description": "25% chance to receive divine blessing",
		"effect": "divine_favor",
		"target": "party",
		"animation": "praying"
	},
	"REPAIR": {
		"description": "Fix damaged equipment, +1 AC to armor",
		"effect": "equipment_repair",
		"target": "single",
		"animation": "hammering"
	},
	"FORAGE": {
		"description": "Find 1d3 consumable items",
		"effect": "find_consumables",
		"target": "party",
		"animation": "gathering"
	},
	"STORIES": {
		"description": "Party gains inspiration, +1 to all rolls next combat",
		"effect": "party_inspiration",
		"target": "party",
		"animation": "campfire_tales"
	},
	"PRACTICE": {
		"description": "Hero gets +1 use of a class word next combat",
		"effect": "ability_practice",
		"target": "single",
		"animation": "practicing"
	}
}

# Temporary buffs that carry to next combat
var active_camp_buffs: Dictionary = {}

signal camp_word_executed(word: String, effect_data: Dictionary)
signal buff_applied(hero: Hero, buff: String, value: Variant)

func get_available_camp_words(party_size: int) -> Array[String]:
	# Number of camp words available scales with party
	var num_words = 3 + (party_size / 2)
	
	var available = camp_words.keys()
	available.shuffle()
	
	return available.slice(0, min(num_words, available.size()))

func execute_camp_word(word: String, hero: Hero = null, party: Array[Hero] = []):
	if not word in camp_words:
		push_error("Unknown camp word: " + word)
		return
	
	var word_data = camp_words[word]
	var effect_data = {
		"word": word,
		"hero": hero,
		"party": party,
		"result": {}
	}
	
	match word_data.effect:
		"party_heal_morale":
			effect_data.result = apply_cooking(party)
		
		"scout_initiative":
			effect_data.result = apply_watch(party)
		
		"damage_boost":
			if hero:
				effect_data.result = apply_sharpen(hero)
		
		"restore_ability":
			if hero:
				effect_data.result = apply_meditate(hero)
		
		"find_secrets":
			effect_data.result = apply_scout(party)
		
		"gold_gamble":
			effect_data.result = apply_gamble(party)
		
		"stat_boost":
			if hero:
				effect_data.result = apply_train(hero)
		
		"divine_favor":
			effect_data.result = apply_pray(party)
		
		"equipment_repair":
			if hero:
				effect_data.result = apply_repair(hero)
		
		"find_consumables":
			effect_data.result = apply_forage(party)
		
		"party_inspiration":
			effect_data.result = apply_stories(party)
		
		"ability_practice":
			if hero:
				effect_data.result = apply_practice(hero)
	
	emit_signal("camp_word_executed", word, effect_data)

func apply_cooking(party: Array[Hero]) -> Dictionary:
	var total_healed = 0
	
	for hero in party:
		if hero.is_alive():
			var heal = Dice.roll("1d4")
			hero.heal(heal)
			total_healed += heal
			
			# Apply morale buff
			add_camp_buff(hero, "morale", 1)
	
	return {
		"message": "The party enjoys a hearty meal! Healed %d HP total." % total_healed,
		"success": true
	}

func apply_watch(party: Array[Hero]) -> Dictionary:
	# Reveal next rooms
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.reveal_next_rooms(2)
	
	# Initiative buff
	for hero in party:
		add_camp_buff(hero, "initiative", 2)
	
	return {
		"message": "The watchers spot upcoming dangers. +2 Initiative!",
		"success": true
	}

func apply_sharpen(hero: Hero) -> Dictionary:
	add_camp_buff(hero, "damage", 2)
	
	return {
		"message": "%s sharpens their weapon to a razor edge. +2 damage!" % hero.hero_name,
		"success": true
	}

func apply_meditate(hero: Hero) -> Dictionary:
	var word_system = get_node_or_null("/root/WordSystem")
	if word_system:
		var restored = word_system.restore_random_class_word(hero)
		return {
			"message": "%s meditates and recovers %s!" % [hero.hero_name, restored],
			"success": true
		}
	
	return {"message": "Meditation failed.", "success": false}

func apply_scout(party: Array[Hero]) -> Dictionary:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("reveal_secret_room"):
		if game_manager.reveal_secret_room():
			return {
				"message": "Scouts discovered a secret room!",
				"success": true
			}
	
	return {
		"message": "No secret rooms found in this area.",
		"success": false
	}

func apply_gamble(party: Array[Hero]) -> Dictionary:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.party_gold >= 50:
		game_manager.party_gold -= 50
		
		if randf() < 0.5:
			game_manager.party_gold += 150
			return {
				"message": "Lucky! Won 100 gold!",
				"success": true
			}
		else:
			return {
				"message": "Unlucky... Lost 50 gold.",
				"success": false
			}
	
	return {
		"message": "Not enough gold to gamble.",
		"success": false
	}

func apply_train(hero: Hero) -> Dictionary:
	# Boost primary stat based on class
	var stat_to_boost = get_primary_stat(hero.class_id)
	add_camp_buff(hero, stat_to_boost, 1)
	
	return {
		"message": "%s trains hard! +1 %s" % [hero.hero_name, stat_to_boost],
		"success": true
	}

func apply_pray(party: Array[Hero]) -> Dictionary:
	if randf() < 0.25:
		# Divine blessing!
		for hero in party:
			add_camp_buff(hero, "blessed", true)
			hero.heal(10)
		
		return {
			"message": "Divine blessing received! Party healed and blessed!",
			"success": true
		}
	else:
		return {
			"message": "Your prayers echo in the darkness...",
			"success": false
		}

func apply_repair(hero: Hero) -> Dictionary:
	if hero.armor_id != "":
		add_camp_buff(hero, "ac", 1)
		return {
			"message": "%s's armor is repaired. +1 AC!" % hero.hero_name,
			"success": true
		}
	
	return {
		"message": "%s has no armor to repair." % hero.hero_name,
		"success": false
	}

func apply_forage(party: Array[Hero]) -> Dictionary:
	var items_found = Dice.roll("1d3")
	var items = []
	
	for i in items_found:
		var roll = randf()
		if roll < 0.6:
			items.append("Healing Potion")
		elif roll < 0.85:
			items.append("Antidote")
		else:
			items.append("Smoke Bomb")
	
	# Add to party inventory
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		for item in items:
			game_manager.add_to_party_inventory(item)
	
	return {
		"message": "Foraging found: %s" % ", ".join(items),
		"success": true
	}

func apply_stories(party: Array[Hero]) -> Dictionary:
	for hero in party:
		add_camp_buff(hero, "inspiration", 1)
	
	return {
		"message": "Tales of heroism inspire the party! +1 to all rolls!",
		"success": true
	}

func apply_practice(hero: Hero) -> Dictionary:
	var word_system = get_node_or_null("/root/WordSystem")
	if word_system:
		var boosted = word_system.boost_random_class_word(hero)
		return {
			"message": "%s practices %s. +1 use next combat!" % [hero.hero_name, boosted],
			"success": true
		}
	
	return {"message": "Practice failed.", "success": false}

func add_camp_buff(hero: Hero, buff_type: String, value):
	if not hero.id in active_camp_buffs:
		active_camp_buffs[hero.id] = {}
	
	active_camp_buffs[hero.id][buff_type] = value
	emit_signal("buff_applied", hero, buff_type, value)

func get_camp_buffs_for_hero(hero: Hero) -> Dictionary:
	return active_camp_buffs.get(hero.id, {})

func apply_camp_buffs_to_combat(hero: Hero):
	var buffs = get_camp_buffs_for_hero(hero)
	
	for buff_type in buffs:
		var value = buffs[buff_type]
		
		match buff_type:
			"morale":
				hero.temp_modifiers["morale"] = value
			"initiative":
				hero.initiative_mod += value
			"damage":
				hero.temp_modifiers["damage"] = value
			"ac":
				hero.ac += value
			"blessed":
				hero.add_condition("blessed")
			"inspiration":
				hero.temp_modifiers["all_rolls"] = value
			var stat when stat in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
				hero.temp_modifiers[stat] = value

func clear_camp_buffs():
	active_camp_buffs.clear()

func get_primary_stat(class_id: String) -> String:
	match class_id:
		"fighter", "barbarian":
			return "STR"
		"rogue", "ranger":
			return "DEX"
		"wizard", "sorcerer":
			return "INT"
		"cleric", "druid":
			return "WIS"
		"bard", "warlock":
			return "CHA"
		_:
			return "CON"

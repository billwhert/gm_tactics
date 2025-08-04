# AchievementTracker.gd - Tracks and unlocks achievements
extends Node
class_name AchievementTracker

signal achievement_unlocked(id: String, name: String, description: String)
signal word_unlocked(word_id: String)

var achievements: Dictionary = {}
var statistics: Dictionary = {
	"total_damage": 0,
	"total_healing": 0,
	"enemies_killed": 0,
	"dungeons_completed": 0,
	"words_used": {},
	"quirks_triggered": {},
	"deaths": 0,
	"perfect_rooms": 0
}

func _ready():
	initialize_achievements()

func initialize_achievements():
	achievements = {
		"first_blood": {
			"name": "First Blood",
			"description": "Kill your first enemy",
			"unlocked": false,
			"reward": {"type": "gold", "amount": 100}
		},
		"no_damage_dungeon": {
			"name": "Untouchable",
			"description": "Complete a dungeon without taking damage",
			"unlocked": false,
			"reward": {"type": "word", "word_id": "INVINCIBLE"}
		},
		"all_rogues": {
			"name": "Thieves Guild",
			"description": "Complete a dungeon with 4 rogues",
			"unlocked": false,
			"reward": {"type": "word", "word_id": "SHADOWSTEP"}
		},
		"speed_demon": {
			"name": "Speed Demon",
			"description": "Defeat a boss in 3 turns or less",
			"unlocked": false,
			"reward": {"type": "word", "word_id": "EXECUTE"}
		},
		"devastator": {
			"name": "Devastator",
			"description": "Deal 1000 total damage",
			"unlocked": false,
			"reward": {"type": "word", "word_id": "DEVASTATE"}
		},
		"variety_master": {
			"name": "Variety Master",
			"description": "Use 50 different words",
			"unlocked": false,
			"reward": {"type": "word", "word_id": "SHAPESHIFT"}
		},
		"bloodthirsty": {
			"name": "Bloodthirsty",
			"description": "Kill 5 enemies in one turn",
			"unlocked": false,
			"reward": {"type": "word", "word_id": "BLOODLUST"}
		},
		"survivor": {
			"name": "Survivor",
			"description": "Win a fight with 1 HP remaining",
			"unlocked": false,
			"reward": {"type": "word", "word_id": "GAMBIT"}
		}
	}

func track_damage(amount: int):
	statistics.total_damage += amount
	check_achievement("devastator", statistics.total_damage >= 1000)

func track_healing(amount: int):
	statistics.total_healing += amount

func track_enemy_kill():
	statistics.enemies_killed += 1
	check_achievement("first_blood", statistics.enemies_killed >= 1)

func track_word_use(word: String):
	statistics.words_used[word] = statistics.words_used.get(word, 0) + 1
	check_achievement("variety_master", statistics.words_used.size() >= 50)

func track_quirk_trigger(hero: Hero, quirk: String):
	var key = hero.id + "_" + quirk
	statistics.quirks_triggered[key] = statistics.quirks_triggered.get(key, 0) + 1

func track_perfect_room():
	statistics.perfect_rooms += 1

func track_boss_defeat(turns: int):
	check_achievement("speed_demon", turns <= 3)

func track_dungeon_complete(party: Array, took_damage: bool):
	statistics.dungeons_completed += 1
	
	if not took_damage:
		check_achievement("no_damage_dungeon", true)
	
	# Check for all rogues
	var all_rogues = true
	for hero in party:
		if hero.class_id != "rogue":
			all_rogues = false
			break
	check_achievement("all_rogues", all_rogues)

func track_combat_end(party: Array, enemies_killed_this_turn: int):
	# Check for bloodlust
	check_achievement("bloodthirsty", enemies_killed_this_turn >= 5)
	
	# Check for survivor
	for hero in party:
		if hero.is_alive() and hero.current_hp == 1:
			check_achievement("survivor", true)
			break

func check_achievement(id: String, condition: bool):
	if not achievements.has(id):
		return
	
	var achievement = achievements[id]
	if not achievement.unlocked and condition:
		achievement.unlocked = true
		emit_signal("achievement_unlocked", id, achievement.name, achievement.description)
		
		# Apply reward
		var reward = achievement.reward
		match reward.type:
			"word":
				emit_signal("word_unlocked", reward.word_id)
			"gold":
				var gm = get_node_or_null("/root/GameManager")
				if gm:
					gm.party_gold += reward.amount

func check_level_achievement(hero: Hero):
	# Check for level-based achievements
	match hero.level:
		5:
			check_achievement("experienced", true)
		10:
			check_achievement("veteran", true)
		20:
			check_achievement("legendary", true)

func get_statistics() -> Dictionary:
	return statistics

func get_achievements() -> Dictionary:
	return achievements

func get_unlocked_count() -> int:
	var count = 0
	for id in achievements:
		if achievements[id].unlocked:
			count += 1
	return count

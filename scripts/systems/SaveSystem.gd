# SaveSystem.gd - Handles saving and loading game progress
extends Node
class_name SaveSystem

const SAVE_PATH = "user://one_word_dungeon_save.dat"
const SETTINGS_PATH = "user://settings.cfg"

# Save data structure
var save_data = {
	"version": 1,
	"unlocked_words": [],
	"hero_roster": [],
	"statistics": {},
	"achievements": {},
	"settings": {},
	"current_run": null
}

signal save_complete
signal load_complete
signal save_failed(error: String)
signal load_failed(error: String)

func save_game():
	save_data.version = 1
	save_data.timestamp = Time.get_unix_time_from_system()
	
	# Collect data from various systems
	save_data.unlocked_words = collect_unlocked_words()
	save_data.hero_roster = collect_hero_roster()
	save_data.statistics = collect_statistics()
	save_data.achievements = collect_achievements()
	save_data.current_run = collect_current_run()
	
	# Save to file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		emit_signal("save_complete")
		print("Game saved successfully")
	else:
		emit_signal("save_failed", "Could not create save file")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		emit_signal("load_failed", "No save file found")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		emit_signal("load_failed", "Could not open save file")
		return false
	
	var loaded_data = file.get_var()
	file.close()
	
	# Validate save data
	if not validate_save_data(loaded_data):
		emit_signal("load_failed", "Invalid save data")
		return false
	
	save_data = loaded_data
	
	# Apply loaded data
	apply_unlocked_words()
	apply_hero_roster()
	apply_statistics()
	apply_achievements()
	
	emit_signal("load_complete")
	print("Game loaded successfully")
	return true

func collect_unlocked_words() -> Array:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		return game_manager.special_words_unlocked.duplicate()
	return []

func collect_hero_roster() -> Array:
	var roster = []
	var game_manager = get_node_or_null("/root/GameManager")
	
	if game_manager:
		for hero in game_manager.party:
			roster.append(serialize_hero(hero))
	
	return roster

func serialize_hero(hero: Hero) -> Dictionary:
	return {
		"id": hero.id,
		"name": hero.hero_name,
		"race": hero.race_id,
		"class": hero.class_id,
		"level": hero.level,
		"xp": hero.xp,
		"stats": hero.stats.duplicate(),
		"quirks": hero.quirks.duplicate(),
		"inventory": hero.inventory.duplicate(),
		"weapon": hero.weapon_id,
		"armor": hero.armor_id,
		"alive": hero.is_alive()
	}

func serialize_word_system() -> Dictionary:
	var word_system = get_node_or_null("/root/HybridWordSystem")
	if not word_system:
		return {}
	
	return {
		"word_uses": word_system.word_uses.duplicate(),
		"shared_pool": []  # Would need to serialize current pool
	}

func deserialize_hero(data: Dictionary) -> Hero:
	var hero = Hero.new()
	hero.id = data.get("id", "")
	hero.hero_name = data.get("name", "")
	hero.race_id = data.get("race", "human")
	hero.class_id = data.get("class", "fighter")
	hero.level = data.get("level", 1)
	hero.xp = data.get("xp", 0)
	hero.stats = data.get("stats", {})
	hero.quirks = data.get("quirks", [])
	hero.inventory = data.get("inventory", [])
	hero.weapon_id = data.get("weapon", "")
	hero.armor_id = data.get("armor", "")
	
	# Calculate derived stats
	hero._calculate_derived_stats()
	
	# Set health based on alive status
	if not data.get("alive", true):
		hero.hp.current = 0
	
	return hero

func collect_statistics() -> Dictionary:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		return game_manager.run_statistics.duplicate()
	return {}

func collect_achievements() -> Dictionary:
	# Collect from achievement system
	var achievements = {}
	
	# Check various achievement conditions
	achievements["words_unlocked"] = save_data.unlocked_words.size()
	achievements["heroes_recruited"] = save_data.hero_roster.size()
	achievements["total_damage_dealt"] = save_data.statistics.get("damage_dealt", 0)
	achievements["total_healing_done"] = save_data.statistics.get("healing_done", 0)
	
	return achievements

func collect_current_run() -> Dictionary:
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager or not game_manager.current_room:
		return {}
	
	return {
		"room_number": game_manager.room_count,
		"turn_count": game_manager.turn_count,
		"party_state": serialize_party_state(game_manager.party),
		"momentum_state": collect_momentum_state()
	}

func serialize_party_state(party: Array) -> Array:
	var state = []
	for hero in party:
		state.append({
			"hero_id": hero.id,
			"hp_current": hero.hp.current,
			"conditions": hero.conditions.duplicate(),
			"position": var_to_str(hero.grid_position)
		})
	return state

func collect_momentum_state() -> Dictionary:
	var momentum_system = get_node_or_null("/root/MomentumSystem")
	if momentum_system:
		return momentum_system.save_momentum_state()
	return {}

func apply_unlocked_words():
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.special_words_unlocked = save_data.unlocked_words.duplicate()
		
		# Unlock words in deck
		for word in save_data.unlocked_words:
			game_manager.word_system.unlock_word(word)

func apply_hero_roster():
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and save_data.hero_roster.size() > 0:
		game_manager.party.clear()
		
		for hero_data in save_data.hero_roster:
			var hero = deserialize_hero(hero_data)
			hero.game_data = game_manager.game_data
			game_manager.party.append(hero)

func apply_statistics():
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.run_statistics = save_data.statistics.duplicate()

func apply_achievements():
	# Apply to achievement system when implemented
	pass

func validate_save_data(data) -> bool:
	if not data is Dictionary:
		return false
	
	if not data.has("version"):
		return false
	
	# Check version compatibility
	if data.version > 1:
		push_warning("Save file is from a newer version")
	
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save():
	if has_save_file():
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted")

func save_settings(settings: Dictionary):
	var config = ConfigFile.new()
	
	for key in settings:
		config.set_value("settings", key, settings[key])
	
	config.save(SETTINGS_PATH)

func load_settings() -> Dictionary:
	var settings = {}
	var config = ConfigFile.new()
	
	if config.load(SETTINGS_PATH) == OK:
		for key in config.get_section_keys("settings"):
			settings[key] = config.get_value("settings", key)
	
	return settings

# Auto-save functionality
var auto_save_timer: Timer
var auto_save_enabled: bool = true
var auto_save_interval: float = 60.0  # seconds

func enable_auto_save():
	if not auto_save_timer:
		auto_save_timer = Timer.new()
		auto_save_timer.wait_time = auto_save_interval
		auto_save_timer.timeout.connect(_on_auto_save)
		add_child(auto_save_timer)
	
	auto_save_timer.start()
	auto_save_enabled = true

func disable_auto_save():
	if auto_save_timer:
		auto_save_timer.stop()
	auto_save_enabled = false

func _on_auto_save():
	if auto_save_enabled:
		save_game()
		print("Auto-save completed")

# Quick save/load
func quick_save():
	save_data.is_quick_save = true
	save_game()

func quick_load() -> bool:
	if not has_save_file():
		return false
	
	var success = load_game()
	if success and save_data.get("is_quick_save", false):
		# Resume current run if it was a quick save
		if save_data.has("current_run") and save_data.current_run:
			resume_current_run()
	
	return success

func resume_current_run():
	var run_data = save_data.current_run
	var game_manager = get_node_or_null("/root/GameManager")
	
	if not game_manager:
		return
	
	# Restore run state
	game_manager.room_count = run_data.get("room_number", 1)
	game_manager.turn_count = run_data.get("turn_count", 0)
	
	# Restore party state
	var party_state = run_data.get("party_state", [])
	for i in range(min(party_state.size(), game_manager.party.size())):
		var hero = game_manager.party[i]
		var state = party_state[i]
		
		hero.hp.current = state.get("hp_current", hero.hp.max)
		hero.conditions = state.get("conditions", [])
		hero.grid_position = str_to_var(state.get("position", "Vector2i(0,0)"))
	
	# Restore deck state
	var deck_state = run_data.get("word_system_state", {})
	game_manager.word_system.words_used_this_run = deck_state.get("words_used_this_run", {})
	game_manager.word_system.draw_mode = deck_state.get("draw_mode", "hybrid")
	
	# Restore momentum
	var momentum_state = run_data.get("momentum_state", {})
	var momentum_system = get_node_or_null("/root/MomentumSystem")
	if momentum_system:
		momentum_system.load_momentum_state(momentum_state)
	
	print("Current run resumed")

# Cloud save support (placeholder)
func upload_to_cloud():
	# Implement cloud save functionality
	pass

func download_from_cloud():
	# Implement cloud load functionality
	pass

# Export save data for sharing
func export_save() -> String:
	save_game()  # Ensure latest data
	var json = JSON.new()
	return json.stringify(save_data)

func import_save(json_string: String) -> bool:
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return false
	
	var imported_data = json.data
	if validate_save_data(imported_data):
		save_data = imported_data
		apply_all_save_data()
		return true
	
	return false

func apply_all_save_data():
	apply_unlocked_words()
	apply_hero_roster()
	apply_statistics()
	apply_achievements()
	print("Save data imported successfully")

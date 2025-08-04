# GameData.gd - Central data loading and management
extends Node
class_name GameData

# Data storage
var races: Dictionary = {}
var classes: Dictionary = {}
var weapons: Dictionary = {}
var armor: Dictionary = {}
var consumables: Dictionary = {}
var spells: Dictionary = {}
var monsters: Dictionary = {}
var rooms: Dictionary = {}
var words: Dictionary = {}
var conditions: Dictionary = {}

func _ready():
	load_all_data()

func load_all_data():
	# Load from JSON files in res://data/
	races = load_json_file("res://data/races.json")
	classes = load_json_file("res://data/classes.json")
	weapons = load_json_file("res://data/weapons.json")
	armor = load_json_file("res://data/armor.json")
	consumables = load_json_file("res://data/consumables.json")
	spells = load_json_file("res://data/spells.json")
	monsters = load_json_file("res://data/monsters.json")
	rooms = load_json_file("res://data/rooms.json")
	words = load_json_file("res://data/words.json")
	conditions = load_json_file("res://data/conditions.json")

func load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Data file not found: " + path)
		return {}
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load: " + path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse JSON: " + path)
		return {}
	
	return json.data

# Helper functions to get specific data
func get_race(id: String) -> Dictionary:
	return races.get(id, {})

# Renamed to avoid conflict with Object.get_class()
func get_class_data(id: String) -> Dictionary:
	return classes.get(id, {})

func get_weapon(id: String) -> Dictionary:
	return weapons.get(id, {})

func get_armor(id: String) -> Dictionary:
	return armor.get(id, {})

func get_spell(id: String) -> Dictionary:
	return spells.get(id, {})

func get_monster(id: String) -> Dictionary:
	return monsters.get(id, {})

func get_word(id: String) -> Dictionary:
	return words.get(id, {})

func get_condition(id: String) -> Dictionary:
	return conditions.get(id, {})

func get_item(id: String) -> Dictionary:
	# Check all item types
	var item = weapons.get(id, {})
	if item.is_empty():
		item = armor.get(id, {})
	if item.is_empty():
		item = consumables.get(id, {})
	return item

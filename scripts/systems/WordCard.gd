# WordCard.gd - Updated to match hybrid system
extends Resource
class_name WordCard

var word: String = ""
var word_id: String = ""  # Internal ID
var description: String = ""
var tags: Array[String] = []
var custom_data: Dictionary = {}  # For type, uses_left, etc.

# Display properties
var upgraded: bool = false
var special: bool = false
var original_word: String = ""  # For transformations
var uses_this_run: int = 0

func _init(p_word: String = ""):
	if p_word != "":
		word = p_word
		word_id = p_word.to_upper().replace(" ", "_")

func get_display_name() -> String:
	var name = word
	if upgraded:
		name += "+"
	if special:
		name = "[" + name + "]"
	return name

func can_be_used_by(hero: Hero) -> bool:
	var word_type = custom_data.get("type", "")
	
	match word_type:
		"basic":
			return true  # Everyone can use basics
		"class":
			# Check if hero has this class word
			return hero.class_id in custom_data.get("allowed_classes", [])
		"shared":
			# Shared pool words can be used by anyone
			return true
		"special":
			# Check special requirements
			return check_special_requirements(hero)
		_:
			return false

func check_special_requirements(hero: Hero) -> bool:
	# Check if hero meets requirements for special words
	match word_id:
		"FLURRY":
			return hero.class_id in ["fighter", "monk", "rogue"]
		"NOVA":
			return hero.class_id in ["wizard", "sorcerer"]
		"RESURRECT":
			return hero.class_id in ["cleric", "paladin"]
		"TIMESTOP":
			return hero.class_id == "wizard" and hero.level >= 15
		"SHAPESHIFT":
			return hero.class_id in ["druid", "ranger"]
		"BLOODLUST":
			return hero.class_id in ["barbarian", "fighter", "rogue"]
		"SANCTUARY":
			return hero.class_id in ["cleric", "paladin"]
		"PORTAL":
			return hero.class_id in ["wizard", "sorcerer"]
		"DIVINE":
			return hero.class_id in ["cleric", "paladin"]
		"SHADOW":
			return hero.class_id in ["rogue", "assassin"]
		"ECHO":
			return hero.class_id in ["bard", "wizard"]
		"GAMBIT":
			return true  # Anyone can gamble
		_:
			return true

func clone() -> WordCard:
	var new_card = WordCard.new(word)
	new_card.word_id = word_id
	new_card.description = description
	new_card.tags = tags.duplicate()
	new_card.custom_data = custom_data.duplicate(true)
	new_card.upgraded = upgraded
	new_card.special = special
	new_card.original_word = original_word
	new_card.uses_this_run = uses_this_run
	return new_card

func get_tooltip_text() -> String:
	var text = "[b]%s[/b]\n" % get_display_name()
	
	if description != "":
		text += description + "\n"
	
	# Add type info
	var word_type = custom_data.get("type", "")
	match word_type:
		"basic":
			text += "[i]Basic Action - Always Available[/i]\n"
		"class":
			var uses = custom_data.get("uses_left", 0)
			var max_uses = custom_data.get("max_uses", 0)
			text += "[i]Class Word - %d/%d uses[/i]\n" % [uses, max_uses]
		"shared":
			text += "[i]Shared Pool - First Come First Serve[/i]\n"
		"special":
			text += "[i]Special Unlocked Word[/i]\n"
	
	# Add tags
	if tags.size() > 0:
		text += "Tags: " + ", ".join(tags)
	
	return text

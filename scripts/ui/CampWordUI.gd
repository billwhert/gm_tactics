# CampWordUI.gd - UI for selecting camp words during rest
extends Control
class_name CampWordUI

signal camp_complete
signal skip_camp

@onready var title: Label = $VBox/Title
@onready var word_grid: GridContainer = $VBox/WordGrid
@onready var hero_selector: OptionButton = $VBox/HeroSelector
@onready var execute_button: Button = $VBox/ExecuteButton
@onready var skip_button: Button = $VBox/SkipButton
@onready var result_label: Label = $VBox/ResultLabel

var camp_system: CampWordSystem
var current_party: Array[Hero] = []
var selected_word: String = ""
var assigned_words: Dictionary = {}  # hero -> word

func _ready():
	camp_system = CampWordSystem.new()
	camp_system.camp_word_executed.connect(_on_camp_word_executed)
	
	execute_button.pressed.connect(_on_execute_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

func setup_camp(party: Array[Hero]):
	current_party = party
	assigned_words.clear()
	result_label.text = ""
	
	# Populate hero selector
	hero_selector.clear()
	hero_selector.add_item("Select Hero...")
	for hero in party:
		if hero.is_alive():
			hero_selector.add_item(hero.hero_name)
	
	# Generate available camp words
	var available_words = camp_system.get_available_camp_words(party.size())
	display_camp_words(available_words)

func display_camp_words(words: Array):
	# Clear existing
	for child in word_grid.get_children():
		child.queue_free()
	
	# Create buttons for each word
	for word in words:
		var button = create_camp_word_button(word)
		word_grid.add_child(button)

func create_camp_word_button(word: String) -> Button:
	var button = Button.new()
	button.text = word
	button.tooltip_text = camp_system.camp_words[word].description
	
	# Check if already assigned
	if word in assigned_words.values():
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5)
	
	button.pressed.connect(func(): _on_word_selected(word))
	return button

func _on_word_selected(word: String):
	selected_word = word
	
	# Check if word needs target
	var word_data = camp_system.camp_words[word]
	if word_data.target == "single":
		hero_selector.show()
		hero_selector.disabled = false
		execute_button.text = "Assign to Hero"
	else:
		hero_selector.hide()
		execute_button.text = "Execute Camp Word"
	
	execute_button.disabled = false

func _on_execute_pressed():
	if selected_word == "":
		return
	
	var word_data = camp_system.camp_words[selected_word]
	
	if word_data.target == "single":
		# Need to select a hero
		if hero_selector.selected <= 0:
			result_label.text = "Please select a hero!"
			result_label.modulate = Color.RED
			return
		
		var hero_index = hero_selector.selected - 1
		var hero = current_party.filter(func(h): return h.is_alive())[hero_index]
		
		# Check if hero already has a camp word
		if hero in assigned_words:
			result_label.text = "%s already has a camp word!" % hero.hero_name
			result_label.modulate = Color.RED
			return
		
		assigned_words[hero] = selected_word
		camp_system.execute_camp_word(selected_word, hero, current_party)
	else:
		# Party-wide effect
		if assigned_words.size() > 0:
			result_label.text = "Party effects can only be used first!"
			result_label.modulate = Color.RED
			return
		
		# Mark all heroes as having used their camp action
		for hero in current_party:
			if hero.is_alive():
				assigned_words[hero] = selected_word
		
		camp_system.execute_camp_word(selected_word, null, current_party)
	
	# Refresh display
	display_camp_words(camp_system.get_available_camp_words(current_party.size()))
	
	# Check if all heroes have camp words
	check_camp_complete()

func _on_camp_word_executed(word: String, effect_data: Dictionary):
	var result = effect_data.result
	result_label.text = result.get("message", "Camp word executed!")
	result_label.modulate = Color.GREEN if result.get("success", false) else Color.YELLOW
	
	# Reset selection
	selected_word = ""
	execute_button.disabled = true
	hero_selector.selected = 0

func check_camp_complete():
	var all_assigned = true
	for hero in current_party:
		if hero.is_alive() and not hero in assigned_words:
			all_assigned = false
			break
	
	if all_assigned:
		# All heroes have used camp words
		await get_tree().create_timer(2.0).timeout
		emit_signal("camp_complete")

func _on_skip_pressed():
	# Confirm skip
	skip_button.text = "Really skip camp?"
	skip_button.modulate = Color.RED
	
	if skip_button.has_meta("confirming"):
		emit_signal("skip_camp")
	else:
		skip_button.set_meta("confirming", true)
		await get_tree().create_timer(2.0).timeout
		skip_button.text = "Skip Camp"
		skip_button.modulate = Color.WHITE
		skip_button.remove_meta("confirming")

# HeroWordPanel.gd - Individual hero panel with their available words
extends Panel
class_name HeroWordPanel

signal word_selected(hero: Hero, word: WordCard)

@onready var portrait: TextureRect = $VBox/Portrait
@onready var name_label: Label = $VBox/NameLabel
@onready var hp_bar: ProgressBar = $VBox/HPBar
@onready var basic_actions: HBoxContainer = $VBox/BasicActions
@onready var class_words: VBoxContainer = $VBox/ClassWords
@onready var assigned_display: Control = $VBox/AssignedWord

var hero: Hero
var word_system: HybridWordSystem
var pending_word: WordCard = null
var selectable: bool = false

func setup(p_hero: Hero, p_word_system: HybridWordSystem):
	hero = p_hero
	word_system = p_word_system
	
	# Initialize display
	name_label.text = hero.hero_name
	update_hp_display()
	
	# Initialize hero's words
	word_system.initialize_hero_words(hero)
	
	# Display available words
	display_available_words()

func update_hp_display():
	hp_bar.max_value = hero.max_hp
	hp_bar.value = hero.current_hp
	hp_bar.get_node("Label").text = "%d/%d" % [hero.current_hp, hero.max_hp]

func display_available_words():
	# Clear existing
	for child in basic_actions.get_children():
		child.queue_free()
	for child in class_words.get_children():
		child.queue_free()
	
	var available = word_system.get_available_words_for_hero(hero)
	
	for word in available:
		var button = create_word_button(word)
		
		match word.custom_data.get("type", ""):
			"basic":
				basic_actions.add_child(button)
			"class":
				class_words.add_child(button)

func create_word_button(word: WordCard) -> Button:
	var button = Button.new()
	button.text = word.word
	
	# Add uses display for class words
	if word.custom_data.get("type", "") == "class":
		var uses = word.custom_data.get("uses_left", 0)
		var max_uses = word.custom_data.get("max_uses", 0)
		button.text += " (%d/%d)" % [uses, max_uses]
	
	button.pressed.connect(func(): _on_word_button_pressed(word))
	
	# Disable if no uses left
	if word.custom_data.get("type", "") == "class":
		button.disabled = word.custom_data.get("uses_left", 0) <= 0
	
	return button

func _on_word_button_pressed(word: WordCard):
	emit_signal("word_selected", hero, word)

func set_selectable(value: bool):
	selectable = value
	modulate = Color(1.2, 1.2, 1.2) if value else Color.WHITE

func _input(event):
	if selectable and event is InputEventMouseButton:
		if event.pressed and get_global_rect().has_point(event.global_position):
			if pending_word:
				emit_signal("word_selected", hero, pending_word)
				pending_word = null
				set_selectable(false)

func show_assigned_word(word: WordCard):
	assigned_display.show()
	assigned_display.get_node("Label").text = "→ " + word.word
	
	# Disable word buttons
	for child in basic_actions.get_children():
		child.disabled = true
	for child in class_words.get_children():
		child.disabled = true

func update_class_word_uses(word: String, uses_left: int):
	# Update the button display
	for child in class_words.get_children():
		if child is Button and child.text.begins_with(word):
			var max_uses = word_system.word_max_uses.get(hero.id + "_" + word, 0)
			child.text = "%s (%d/%d)" % [word, uses_left, max_uses]
			child.disabled = uses_left <= 0

# SharedWordCard.gd - UI element for shared pool words
extends Panel
class_name SharedWordCard

signal selected(word_card: WordCard)

@onready var word_label: Label = $VBox/WordLabel
@onready var type_label: Label = $VBox/TypeLabel
@onready var button: Button = $Button

var word_card: WordCard

func setup(card: WordCard):
	word_card = card
	word_label.text = card.word
	
	# Visual feedback for claimed words
	if not card in get_node("/root/HybridWordSystem").shared_pool_available:
		modulate = Color(0.5, 0.5, 0.5)
		button.disabled = true
		type_label.text = "Claimed"

func _ready():
	button.pressed.connect(_on_button_pressed)
	
	# Hover effect
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_button_pressed():
	emit_signal("selected", word_card)

func _on_mouse_entered():
	# Highlight effect
	if not button.disabled:
		modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	if not button.disabled:
		modulate = Color.WHITE

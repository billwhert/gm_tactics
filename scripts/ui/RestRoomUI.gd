# RestRoomUI.gd - UI for rest room choices
extends Control
class_name RestRoomUI

signal choice_made(choice: String)

@onready var rest_info: Label = $CenterContainer/Panel/VBox/RestInfo
@onready var camp_button: Button = $CenterContainer/Panel/VBox/Options/CampButton
@onready var short_rest_button: Button = $CenterContainer/Panel/VBox/Options/ShortRestButton
@onready var skip_button: Button = $CenterContainer/Panel/VBox/Options/SkipButton

var party: Array[Hero]
var short_rests_remaining: int
var camp_system: CampWordSystem

func _ready():
	camp_button.pressed.connect(func(): emit_signal("choice_made", "camp"))
	short_rest_button.pressed.connect(func(): emit_signal("choice_made", "short_rest"))
	skip_button.pressed.connect(func(): emit_signal("choice_made", "skip"))

func setup(p_party: Array[Hero], p_short_rests: int, p_camp_system: CampWordSystem):
	party = p_party
	short_rests_remaining = p_short_rests
	camp_system = p_camp_system
	
	# Update UI
	rest_info.text = "Short Rests Remaining: %d" % short_rests_remaining
	
	# Disable short rest if none remaining
	if short_rests_remaining <= 0:
		short_rest_button.disabled = true
		short_rest_button.tooltip_text = "No short rests remaining"
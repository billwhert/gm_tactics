# SaveManagerUI.gd - UI for save/load functionality
extends Control
class_name SaveManagerUI

@onready var save_button: Button = $VBox/SaveButton
@onready var load_button: Button = $VBox/LoadButton
@onready var quick_save_button: Button = $VBox/QuickSaveButton
@onready var quick_load_button: Button = $VBox/QuickLoadButton
@onready var auto_save_toggle: CheckBox = $VBox/AutoSaveToggle
@onready var save_slots: ItemList = $VBox/SaveSlots
@onready var status_label: Label = $VBox/StatusLabel

var save_system: SaveSystem

func _ready():
	save_system = SaveSystem.new()
	
	# Connect buttons
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quick_save_button.pressed.connect(_on_quick_save_pressed)
	quick_load_button.pressed.connect(_on_quick_load_pressed)
	auto_save_toggle.toggled.connect(_on_auto_save_toggled)
	
	# Connect save system signals
	save_system.save_complete.connect(_on_save_complete)
	save_system.load_complete.connect(_on_load_complete)
	save_system.save_failed.connect(_on_save_failed)
	save_system.load_failed.connect(_on_load_failed)
	
	# Update UI
	refresh_save_slots()
	auto_save_toggle.button_pressed = save_system.auto_save_enabled

func _on_save_pressed():
	save_system.save_game()
	status_label.text = "Saving..."
	status_label.modulate = Color.YELLOW

func _on_load_pressed():
	if save_system.load_game():
		status_label.text = "Loading..."
		status_label.modulate = Color.YELLOW
	else:
		status_label.text = "No save file found"
		status_label.modulate = Color.RED

func _on_quick_save_pressed():
	save_system.quick_save()
	status_label.text = "Quick saving..."
	status_label.modulate = Color.YELLOW

func _on_quick_load_pressed():
	if save_system.quick_load():
		status_label.text = "Quick loading..."
		status_label.modulate = Color.YELLOW
	else:
		status_label.text = "No quick save found"
		status_label.modulate = Color.RED

func _on_auto_save_toggled(enabled: bool):
	if enabled:
		save_system.enable_auto_save()
		status_label.text = "Auto-save enabled"
	else:
		save_system.disable_auto_save()
		status_label.text = "Auto-save disabled"
	
	status_label.modulate = Color.WHITE

func _on_save_complete():
	status_label.text = "Save complete!"
	status_label.modulate = Color.GREEN
	refresh_save_slots()
	
	# Clear message after delay
	await get_tree().create_timer(2.0).timeout
	status_label.text = ""

func _on_load_complete():
	status_label.text = "Load complete!"
	status_label.modulate = Color.GREEN
	
	# Clear message after delay
	await get_tree().create_timer(2.0).timeout
	status_label.text = ""

func _on_save_failed(error: String):
	status_label.text = "Save failed: " + error
	status_label.modulate = Color.RED

func _on_load_failed(error: String):
	status_label.text = "Load failed: " + error
	status_label.modulate = Color.RED

func refresh_save_slots():
	save_slots.clear()
	
	if save_system.has_save_file():
		# In a full implementation, you'd load save metadata
		save_slots.add_item("Save Slot 1 - Room %d" % save_system.save_data.get("room_number", 1))
		
		var timestamp = save_system.save_data.get("timestamp", 0)
		if timestamp > 0:
			var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
			var date_string = "%02d/%02d %02d:%02d" % [
				datetime.month, datetime.day,
				datetime.hour, datetime.minute
			]
			save_slots.set_item_metadata(0, date_string)

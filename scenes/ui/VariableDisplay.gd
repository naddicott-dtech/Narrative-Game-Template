# VariableDisplay.gd
#
# Shows one of your Ink story's variables on screen, and keeps it up to
# date as the story changes it. Nothing to wire: add this node anywhere in
# Main/UI (Add Child Node → VariableDisplay), type the variable's name into
# Variable Name, drag the node where you want it, press Play.
#
#   Variable Name: fuel          → shows "Fuel  100"
#   Display As: Bar, Max Value: 100 → a gauge that empties as fuel drops
#
# It is read-only: the story owns the value. (To let a Godot mini-game
# change an Ink variable you would call the director — a coding challenge.)
# A Variable Name the story doesn't have stops the game with an error that
# lists the variables the story does have.
class_name VariableDisplay
extends HBoxContainer

## The group the director looks in to find displays when a story loads.
const GROUP := "variable_displays"

## The two looks. Pick one in the Inspector.
enum DisplayAs {
	TEXT, ## the value as a number or words
	BAR,  ## a bar that fills up to Max Value
}

## The variable's name exactly as declared in Inky (VAR fuel = 100 → fuel).
@export var variable_name: String = ""
## What to call it on screen. Leave empty to use the variable name.
@export var label_text: String = ""
## Number/words, or a bar.
@export var display_as: DisplayAs = DisplayAs.TEXT
## Bar only: the value that fills the bar completely.
@export var max_value: float = 100.0

var _name_label: Label
var _value_label: Label
var _bar: ProgressBar
var _last_value = null   # remembered in case a value arrives before _ready

func _ready() -> void:
	add_to_group(GROUP)
	add_theme_constant_override("separation", 8)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = label_for()
	add_child(_name_label)

	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	match display_as:
		DisplayAs.TEXT:
			add_child(_value_label)
		DisplayAs.BAR:
			_bar = ProgressBar.new()
			_bar.name = "Bar"
			_bar.min_value = 0.0
			_bar.max_value = max_value
			_bar.show_percentage = false
			_bar.custom_minimum_size = Vector2(160, 24)
			add_child(_bar)
			# The number sits on top of the bar, centered.
			_value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_bar.add_child(_value_label)

	if _last_value != null:
		show_value(_last_value)

# The on-screen name: Label Text if set, else the variable name made readable
# ("elapsed_hours" → "Elapsed Hours").
func label_for() -> String:
	if label_text.strip_edges() != "":
		return label_text
	return variable_name.capitalize()

# Put a value on screen (the director calls this with the story's current
# value when a story loads).
func show_value(value) -> void:
	_last_value = value
	if not is_node_ready():
		return
	_value_label.text = format_value(value)
	if _bar != null:
		_bar.value = clampf(_to_number(value), 0.0, max_value)

# What the Ink story calls when the variable changes (the observer seam).
func on_variable_changed(_variable_name: String, new_value) -> void:
	show_value(new_value)

# Ints print plainly, floats with one decimal, words as they are.
static func format_value(value) -> String:
	if value is bool:
		return "true" if value else "false"
	if value is int:
		return str(value)
	if value is float:
		return str(int(value)) if value == floorf(value) else "%.1f" % value
	return str(value)

static func _to_number(value) -> float:
	if value is bool:
		return 1.0 if value else 0.0
	if value is int or value is float:
		return float(value)
	return 0.0

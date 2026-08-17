# ChoiceButton.gd
#
# One story choice, as a button. NarrativeUI duplicates ChoiceButton.tscn once
# per choice and calls setup(). This is the first thing to restyle if you want
# your choices to look different — it is an ordinary Button.
extends Button

## Fired with this button's choice number when the player picks it.
signal chosen(choice_index: int)

var choice_index := -1

func setup(choice_text: String, index: int) -> void:
	text = choice_text
	choice_index = index

func _ready() -> void:
	pressed.connect(func(): chosen.emit(choice_index))

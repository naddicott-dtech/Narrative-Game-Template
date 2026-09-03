# ErrorBanner.gd
#
# The red strip along the bottom of the screen that lights up when the story
# hits a [Narrative] error. In a published browser game nobody can see Godot's
# Output panel, so every error must be visible on screen too.
#
# It lives in Main's UI layer (not inside the story view), so it is still
# there when the story view is swapped out for a cut scene or another game
# mode. It listens to the SignalBus bulletin board — see SignalBus.gd — and
# needs no wiring: drop it in the scene and it works.
extends Label

func _ready() -> void:
	visible = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_color_override("font_color", Color.RED)
	var backdrop := StyleBoxFlat.new()   # dark strip so red text reads over any art
	backdrop.bg_color = Color(0, 0, 0, 0.75)
	backdrop.set_content_margin_all(8)
	add_theme_stylebox_override("normal", backdrop)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN   # long messages grow upward
	mouse_filter = Control.MOUSE_FILTER_IGNORE      # never eats a click
	SignalBus.narrative_failed.connect(_on_narrative_failed)
	SignalBus.story_started.connect(_on_story_started)

func _on_narrative_failed(message: String) -> void:
	text = message
	visible = true

func _on_story_started() -> void:
	visible = false

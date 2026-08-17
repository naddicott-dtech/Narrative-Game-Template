# NarrativeUI.gd
#
# The visible half of the story player, attached to the NarrativePanel node.
# It shows each story beat in the text area, builds one button per choice,
# and turns the player's clicks (or Space/Enter) into "next line, please".
#
# All five references below must be assigned in the Inspector. If one is
# missing, the panel reports a single clear [Narrative] error and refuses to
# start, instead of crashing somewhere confusing later.
extends Control

## The NarrativeDirector node that runs the story.
@export var director: NarrativeDirector
## The RichTextLabel the story text builds down into.
@export var story_text: RichTextLabel
## The ScrollContainer around the story text (auto-scrolls to new lines).
@export var story_scroll: ScrollContainer
## The container the choice buttons appear in.
@export var choices_container: VBoxContainer
## The ChoiceButton.tscn scene, duplicated once per choice.
@export var choice_button_scene: PackedScene

func _ready() -> void:
	var missing := _missing_references()
	if not missing.is_empty():
		push_error(
			"[Narrative] NarrativePanel is missing Inspector references: "
			+ ", ".join(missing)
			+ ". Select NarrativePanel and assign them in the Inspector."
		)
		return

	director.story_started.connect(_on_story_started)
	director.beat_ready.connect(_on_beat_ready)
	director.choices_ready.connect(_on_choices_ready)
	director.story_ended.connect(_on_story_ended)
	director.narrative_failed.connect(_on_narrative_failed)

	if director.has_failed:
		# The director already failed before we connected; show the truth now.
		_on_narrative_failed(director.last_error)
	else:
		# The director finishes loading one deferred step after the scene is
		# built, so our start request queues right behind it.
		director.start_story.call_deferred()

# Click or tap anywhere on the panel to advance. Buttons and scrollbars
# consume their own clicks first, so they never double as an advance.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()

# Space/Enter advance too (Godot's built-in "ui_accept" action).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()

func _advance() -> void:
	if director != null:
		director.continue_story()

func _on_story_started() -> void:
	story_text.text = ""
	_clear_choices()

func _on_beat_ready(text: String, _tags: Array) -> void:
	story_text.text += text
	_scroll_to_bottom()

func _on_choices_ready(choice_texts: Array) -> void:
	for index in choice_texts.size():
		var button: Button = choice_button_scene.instantiate()
		button.setup(choice_texts[index], index)
		button.chosen.connect(_on_choice_chosen)
		choices_container.add_child(button)

func _on_choice_chosen(choice_index: int) -> void:
	_clear_choices()
	director.choose(choice_index)

func _on_story_ended() -> void:
	# The story's own final line is the ending; nothing extra to show.
	pass

func _on_narrative_failed(message: String) -> void:
	# Keep the last good text visible and add the error beneath it, so the
	# problem is on screen even when nobody is watching the Output panel.
	_clear_choices()
	if story_text.text != "" and not story_text.text.ends_with("\n"):
		story_text.text += "\n"
	story_text.text += message + "\n"
	_scroll_to_bottom()

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

func _scroll_to_bottom() -> void:
	# Wait one frame so the new text has been laid out, then jump down.
	await get_tree().process_frame
	story_scroll.scroll_vertical = int(story_scroll.get_v_scroll_bar().max_value)

func _missing_references() -> Array:
	var missing: Array = []
	if director == null:
		missing.append("Director")
	if story_text == null:
		missing.append("Story Text")
	if story_scroll == null:
		missing.append("Story Scroll")
	if choices_container == null:
		missing.append("Choices Container")
	if choice_button_scene == null:
		missing.append("Choice Button Scene")
	return missing

# NarrativeUI.gd
#
# The visible half of the story player, attached to the NarrativePanel node.
# It shows each story beat in the text area, builds one button per choice,
# and turns the player's clicks (or Space/Enter) into "next line, please".
# The Auto switch (top right) lets the story read itself: each line stays up
# long enough to read, then advances — and always waits at choices.
#
# All six references below must be assigned in the Inspector. If one is
# missing, the panel reports a single clear [Narrative] error and refuses to
# start, instead of crashing somewhere confusing later.
#
# Every [Narrative] error also lights up a red banner along the bottom of the
# screen, because a published browser game has no visible Output panel.
extends Control

## The two ways story text can be shown. Pick one in the Inspector.
enum PresentationMode {
	BUILD_DOWN,         ## every line stays; new lines build down the page
	ONE_BEAT_AT_A_TIME, ## the screen clears and shows only the newest line
}

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
## How story text is presented (see PresentationMode above).
@export var presentation_mode: PresentationMode = PresentationMode.BUILD_DOWN

@export_group("Auto Play")
## The on-screen "Auto" switch (top right) that lets the story read itself.
@export var auto_play_toggle: CheckButton
## Auto-play never flips to the next line faster than this many seconds.
@export_range(0.1, 30.0, 0.1, "or_greater") var auto_play_min_seconds := 1.5
## Extra reading time per letter, so longer lines stay up longer.
@export_range(0.0, 1.0, 0.01, "or_greater") var auto_play_seconds_per_character := 0.05

# False until every Inspector reference checks out; input stays dead before
# that, so a half-wired panel can never silently eat story beats.
var _setup_ok := false

# A red error strip along the bottom, created in code and hidden until
# something goes wrong. In an exported browser game nobody can see Godot's
# Output panel, so every [Narrative] error is also shown on screen.
var _error_banner: Label = null

# The auto-play clock, created in code. One-shot: each beat winds it up once.
var _auto_timer: Timer = null
# How long the currently shown beat should stay up in auto-play.
var _auto_delay := 0.0
# True only while a beat is up and the story is advanceable — false at
# choices, endings, and failures, so flipping the toggle there arms nothing.
var _auto_advance_ok := false

func _ready() -> void:
	_error_banner = _make_error_banner()
	add_child(_error_banner)

	var missing := _missing_references()
	if not missing.is_empty():
		_report_error(
			"[Narrative] NarrativePanel is missing Inspector references: "
			+ ", ".join(missing)
			+ ". Select NarrativePanel and assign them in the Inspector."
		)
		return

	if not _choice_scene_is_usable():
		_report_error(
			"[Narrative] Choice Button Scene must be ChoiceButton.tscn — a Button "
			+ "with ChoiceButton.gd attached. Fix it on NarrativePanel in the Inspector."
		)
		return

	_setup_ok = true
	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.timeout.connect(_advance)
	add_child(_auto_timer)
	auto_play_toggle.toggled.connect(_on_auto_play_toggled)

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
	if _setup_ok:
		director.continue_story()

func _on_story_started() -> void:
	# A fresh story must not inherit the previous story's ticking clock —
	# or its error banner.
	_pause_auto_play()
	story_text.text = ""
	_error_banner.visible = false
	_clear_choices()

func _on_beat_ready(text: String, _tags: Array) -> void:
	match presentation_mode:
		PresentationMode.BUILD_DOWN:
			story_text.text += text
			_scroll_to_bottom()
		PresentationMode.ONE_BEAT_AT_A_TIME:
			story_text.text = text
			story_scroll.scroll_vertical = 0

	# Each beat rewinds the auto-play clock to its own reading time — a manual
	# advance therefore also gives the next beat its full time up.
	_auto_delay = _auto_play_delay_for(text)
	_auto_advance_ok = true
	if auto_play_toggle.button_pressed:
		_auto_timer.stop()
		_auto_timer.start(_auto_delay)

func _on_choices_ready(choice_texts: Array) -> void:
	_pause_auto_play()
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
	_pause_auto_play()

func _on_narrative_failed(message: String) -> void:
	# Keep the last good text visible, add the error beneath it, and light up
	# the red banner — the problem must be on screen, not just in the Output
	# panel (which browser players can never see).
	_pause_auto_play()
	_clear_choices()
	if story_text.text != "" and not story_text.text.ends_with("\n"):
		story_text.text += "\n"
	story_text.text += message + "\n"
	_show_error_banner(message)
	_scroll_to_bottom()

# The player flipped the Auto switch. On: time the beat that is up right now.
# Off: stop the clock (the story simply waits for clicks again).
func _on_auto_play_toggled(auto_on: bool) -> void:
	_auto_timer.stop()
	if auto_on and _auto_advance_ok:
		_auto_timer.start(_auto_delay)

# Auto-play may not run right now: a choice, an ending, or a failure is on
# screen. The toggle can stay on — new beats rewind the clock when they flow.
func _pause_auto_play() -> void:
	_auto_advance_ok = false
	if _auto_timer != null:
		_auto_timer.stop()

# Reading time for one beat: a floor so short lines don't flash past, plus
# time that grows with the length of the line.
func _auto_play_delay_for(text: String) -> float:
	return maxf(auto_play_min_seconds, text.length() * auto_play_seconds_per_character)

# Builds the hidden red strip that failures light up. Anchored along the
# bottom edge; long messages wrap and grow upward.
func _make_error_banner() -> Label:
	var banner := Label.new()
	banner.name = "ErrorBanner"
	banner.visible = false
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_color_override("font_color", Color.RED)
	banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return banner

func _show_error_banner(message: String) -> void:
	_error_banner.text = message
	_error_banner.visible = true

# For the panel's own setup errors: one console error, and the same message
# on screen.
func _report_error(message: String) -> void:
	push_error(message)
	_show_error_banner(message)

func _clear_choices() -> void:
	# Take each button out of the container right away — if the story jumps
	# straight into another choice point, old and new buttons must never
	# share the container, even for one frame.
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()

# Instantiates the assigned scene once to prove it behaves like a
# ChoiceButton before the story starts, so a wrong assignment fails with one
# clear message instead of a mid-story script error.
func _choice_scene_is_usable() -> bool:
	var probe := choice_button_scene.instantiate()
	if probe == null:
		return false
	var usable: bool = probe is Button \
		and probe.has_method("setup") and probe.has_signal("chosen")
	probe.free()
	return usable

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
	if auto_play_toggle == null:
		missing.append("Auto Play Toggle")
	return missing

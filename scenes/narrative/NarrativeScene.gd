# NarrativeScene.gd
#
# The story view: the visible half of the story player, attached to the root
# of NarrativeScene.tscn. It shows each story beat in the dialogue box,
# builds one button per choice, and turns the player's clicks (or Space/Enter)
# into "next line, please". The Auto switch (top right) lets the story read
# itself: each line stays up long enough to read, then advances — and always
# waits at choices.
#
# This whole scene is the ONE child of Main's WorldRoot. Later, a story cue can
# swap it out for a cut scene or another game mode and back again; the story
# itself lives on in the NarrativeDirector (under Main/Managers), which this
# scene finds by its group when it appears.
#
# The five references below must be assigned in the Inspector. If one is
# missing, the scene reports a single clear [Narrative] error and refuses to
# start, instead of crashing somewhere confusing later.
extends Control

## The two ways story text can be shown. Pick one in the Inspector.
enum PresentationMode {
	ONE_BEAT_AT_A_TIME, ## the dialogue box shows only the newest line (the default)
	BUILD_DOWN,         ## every line stays; new lines build down and the box scrolls
}

## The RichTextLabel the story text appears in.
@export var story_text: RichTextLabel
## The ScrollContainer around the story text (auto-scrolls to new lines).
@export var story_scroll: ScrollContainer
## The container the choice buttons appear in.
@export var choices_container: VBoxContainer
## The ChoiceButton.tscn scene, duplicated once per choice.
@export var choice_button_scene: PackedScene
## How story text is presented (see PresentationMode above).
@export var presentation_mode: PresentationMode = PresentationMode.ONE_BEAT_AT_A_TIME

@export_group("Auto Play")
## The on-screen "Auto" switch (top right) that lets the story read itself.
@export var auto_play_toggle: CheckButton
## Auto-play never flips to the next line faster than this many seconds.
@export_range(0.1, 30.0, 0.1, "or_greater") var auto_play_min_seconds := 1.5
## Extra reading time per letter, so longer lines stay up longer.
@export_range(0.0, 1.0, 0.01, "or_greater") var auto_play_seconds_per_character := 0.05

# The NarrativeDirector this scene found in the tree (see _connect_director).
var director: NarrativeDirector = null

# False until every Inspector reference checks out AND a director was found;
# input stays dead before that, so a half-wired scene can never silently eat
# story beats.
var _setup_ok := false

# The auto-play clock, created in code. One-shot: each beat winds it up once.
var _auto_timer: Timer = null
# How long the currently shown beat should stay up in auto-play.
var _auto_delay := 0.0
# True only while a beat is up and the story is advanceable — false at
# choices, endings, and failures, so flipping the toggle there arms nothing.
var _auto_advance_ok := false

func _ready() -> void:
	var missing := _missing_references()
	if not missing.is_empty():
		_report_error(
			"[Narrative] NarrativeScene is missing Inspector references: "
			+ ", ".join(missing)
			+ ". Select NarrativeScene and assign them in the Inspector."
		)
		return

	if not _choice_scene_is_usable():
		_report_error(
			"[Narrative] Choice Button Scene must be ChoiceButton.tscn — a Button "
			+ "with ChoiceButton.gd attached. Fix it on NarrativeScene in the Inspector."
		)
		return

	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.timeout.connect(_advance)
	add_child(_auto_timer)
	auto_play_toggle.toggled.connect(_on_auto_play_toggled)

	# The whole scene tree is still being assembled during _ready(). One
	# deferred step later every node is in place, so look for the director
	# then — no matter which node Godot happened to build first.
	_connect_director.call_deferred()

# Finds the one NarrativeDirector in the running game and subscribes to it.
func _connect_director() -> void:
	director = get_tree().get_first_node_in_group(NarrativeDirector.DIRECTORS_GROUP) as NarrativeDirector
	if director == null:
		_report_error(
			"[Narrative] NarrativeScene found no NarrativeDirector in the scene tree — "
			+ "Main.tscn needs one under Managers."
		)
		return

	director.story_started.connect(_on_story_started)
	director.beat_ready.connect(_on_beat_ready)
	director.choices_ready.connect(_on_choices_ready)
	director.story_ended.connect(_on_story_ended)
	director.narrative_failed.connect(_on_narrative_failed)
	_setup_ok = true

	if director.has_failed:
		# The director already failed before we connected; show the truth now.
		_on_narrative_failed(director.last_error)
	else:
		# If the director hasn't finished loading yet, it remembers this
		# request and starts as soon as it has.
		director.start_story()

# Click or tap anywhere on the scene to advance. Buttons and scrollbars
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
	# A fresh story must not inherit the previous story's ticking clock.
	_pause_auto_play()
	story_text.text = ""
	_clear_choices()

func _on_beat_ready(text: String, _tags: Array) -> void:
	match presentation_mode:
		PresentationMode.ONE_BEAT_AT_A_TIME:
			story_text.text = text
			story_scroll.scroll_vertical = 0
		PresentationMode.BUILD_DOWN:
			story_text.text += text
			_scroll_to_bottom()

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
	# Keep the last good text visible and add the error beneath it. (The red
	# ErrorBanner in Main's UI layer lights up on its own — it listens to
	# SignalBus, which the director already posted to.)
	_pause_auto_play()
	_clear_choices()
	_append_error_text(message)

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

# For the scene's own setup errors: one console error, the same message on
# screen, and a post on the bulletin board so the ErrorBanner lights up.
func _report_error(message: String) -> void:
	push_error(message)
	_append_error_text(message)
	SignalBus.narrative_failed.emit(message)

func _append_error_text(message: String) -> void:
	if story_text == null:
		return
	if story_text.text != "" and not story_text.text.ends_with("\n"):
		story_text.text += "\n"
	story_text.text += message + "\n"
	_scroll_to_bottom()

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
	if story_scroll == null:
		return
	# Wait one frame so the new text has been laid out, then jump down.
	await get_tree().process_frame
	if story_scroll != null:
		story_scroll.scroll_vertical = int(story_scroll.get_v_scroll_bar().max_value)

func _missing_references() -> Array:
	var missing: Array = []
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

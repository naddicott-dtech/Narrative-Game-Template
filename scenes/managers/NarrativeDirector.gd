# NarrativeDirector.gd
#
# The conductor between your compiled Inky story (a .json file) and the game.
# It loads the story, hands each line (a "beat") to the UI one advance at a
# time, and passes the player's choices back to Ink.
#
# If anything goes wrong — a missing file, a broken export, a bad choice —
# it reports ONE clear [Narrative] error, tells the UI, and stops asking Ink
# for more, so you never keep playing a broken story without knowing.
class_name NarrativeDirector
extends Node

## The compiled story exported from Inky. Set this in the Inspector.
@export_file("*.json") var story_file: String = ""

## A fresh story just began (also fires on restart). The UI clears itself.
signal story_started
## One new story line is ready to show. Tags are Ink's extra "# notes".
signal beat_ready(text: String, tags: Array)
## The story is waiting for the player to pick one of these.
signal choices_ready(choice_texts: Array)
## The story reached an ending.
signal story_ended
## Something went wrong. The message is the same one printed in Output.
signal narrative_failed(message: String)

var has_failed := false
var last_error := ""

var _loader: NarrativeStoryLoader = null
var _story: InkStory = null
var _runtime: Node = null
var _created_runtime := false
var _story_over := false
var _at_choices := false
var _presentation_started := false
var _start_requested := false

func _ready() -> void:
	# The Ink runtime must live as a child of the tree root, and the root is
	# still busy assembling the scene during _ready(). One deferred step later
	# it is free again, so the real setup happens in _boot().
	_boot.call_deferred()

func _exit_tree() -> void:
	if _created_runtime and _runtime != null:
		InkRuntimeManager.deinit(get_tree().root)
		_runtime = null

func _boot() -> void:
	_runtime = get_tree().root.get_node_or_null("__InkRuntime")
	if _runtime == null:
		_runtime = InkRuntimeManager.init(get_tree().root, false)
		_created_runtime = true

	_loader = NarrativeStoryLoader.new()
	_loader.failed.connect(_on_loader_failed)

	if story_file.is_empty():
		_fail(
			"[Narrative] No story assigned. Select the NarrativeDirector node "
			+ "and set 'Story File' in the Inspector."
		)
		return

	load_story(story_file)

	# Anyone who asked to start before we finished loading gets their start
	# now. This keeps the scene working no matter which node _ready() ran
	# first.
	var wants_start := _start_requested
	_start_requested = false
	if wants_start and not has_failed and _story != null:
		start_story()

# Loads (or reloads) a compiled story. A successful load forgets any earlier
# failure or ending, so the director is ready to start again.
func load_story(json_path: String) -> bool:
	has_failed = false
	last_error = ""
	_story_over = false
	_at_choices = false
	_presentation_started = false

	_story = _loader.load_from_path(json_path, _runtime)
	return _story != null

func start_story() -> void:
	if has_failed:
		return
	if _story == null:
		# Not loaded yet (the deferred boot hasn't run). Remember the
		# request; _boot() honors it as soon as loading succeeds.
		_start_requested = true
		return
	if _presentation_started:
		return
	_presentation_started = true
	story_started.emit()
	continue_story()

func continue_story() -> void:
	if has_failed or _story == null or _story_over or _at_choices:
		return
	if not _story.can_continue:
		_report_stop_point()
		return

	var text: String = _story.continue_story()
	if has_failed:
		return  # the runtime hit an exception mid-line; already reported

	var tags: Array = _story.current_tags.duplicate()
	var reserved_cue := _first_reserved_cue(tags)
	if reserved_cue != "":
		# The cue asked Godot to do something we cannot do yet, so showing
		# this beat would pretend it worked. Fail before displaying it.
		_fail(
			'[Narrative] Unsupported reserved cue "%s" at "%s" — cue commands arrive with the cue slice'
			% [reserved_cue, text.strip_edges()]
		)
		return

	beat_ready.emit(text, tags)
	_report_stop_point()

func choose(choice_index: int) -> void:
	if has_failed or _story == null or _story_over or not _at_choices:
		return

	var count: int = _story.current_choices.size()
	if choice_index < 0 or choice_index >= count:
		_fail(
			"[Narrative] Choice %d does not exist — valid choices are 0 to %d"
			% [choice_index, count - 1]
		)
		return

	_story.choose_choice_index(choice_index)
	if has_failed:
		return
	_at_choices = false
	continue_story()

# After a beat, tell the UI what the story is waiting for — but only when Ink
# has nothing more to say on the next advance.
func _report_stop_point() -> void:
	if _story.can_continue:
		return
	var choices: Array = _story.current_choices
	if choices.size() > 0:
		_at_choices = true
		var texts: Array = []
		for choice in choices:
			texts.append(choice.text)
		choices_ready.emit(texts)
	else:
		_story_over = true
		story_ended.emit()

func _first_reserved_cue(tags: Array) -> String:
	for tag in tags:
		var trimmed := str(tag).strip_edges()
		if trimmed.begins_with("@"):
			return trimmed
	return ""

# The loader already printed its own [Narrative] error; only record and relay.
func _on_loader_failed(message: String) -> void:
	_enter_failed_state(message)

# For problems the director finds itself: print once, then record and relay.
func _fail(message: String) -> void:
	if has_failed:
		return
	push_error(message)
	_enter_failed_state(message)

func _enter_failed_state(message: String) -> void:
	if has_failed:
		return
	has_failed = true
	last_error = message
	narrative_failed.emit(message)

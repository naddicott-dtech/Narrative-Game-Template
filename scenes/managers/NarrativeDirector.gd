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

## Where story cues ("# @speaker: maya") are performed. A story with no cues
## never needs this; a story WITH cues stops loudly if it is missing.
@export var cue_stage: NarrativeStage

## A fresh story just began (also fires on restart). The UI clears itself.
signal story_started
## One new story line is ready to show. Tags are Ink's ordinary "# notes" —
## cue tags (starting with @) are performed by the stage and never arrive here.
signal beat_ready(text: String, tags: Array)
## The story is waiting for the player to pick one of these.
signal choices_ready(choice_texts: Array)
## The story reached an ending.
signal story_ended
## Something went wrong. The message is the same one printed in Output.
signal narrative_failed(message: String)

# Every live director joins this group; the deferred runtime cleanup checks
# it so it never removes a runtime another director has since adopted.
const DIRECTORS_GROUP := "narrative_directors"

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
	add_to_group(DIRECTORS_GROUP)
	# The Ink runtime must live as a child of the tree root, and the root is
	# still busy assembling the scene during _ready(). One deferred step later
	# it is free again, so the real setup happens in _boot().
	_boot.call_deferred()

func _exit_tree() -> void:
	if _created_runtime and _runtime != null:
		# Deferred: at this moment the root may be busy tearing the scene down
		# (game quit), and removing the runtime synchronously would print an
		# engine error. One step later the root is free again. At quit the
		# deferred call still fires mid-shutdown, so it re-checks that the
		# root and runtime are actually still there before touching them.
		var cleanup := func() -> void:
			var tree := Engine.get_main_loop() as SceneTree
			if tree == null or not is_instance_valid(tree.root):
				return
			if tree.root.get_node_or_null("__InkRuntime") == null:
				return
			# A director that booted while this cleanup sat in the queue has
			# adopted the runtime — removing it would strand them mid-story.
			if not tree.get_nodes_in_group(DIRECTORS_GROUP).is_empty():
				return
			InkRuntimeManager.deinit(tree.root)
		cleanup.call_deferred()
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

	# Every cue on this beat must fully succeed BEFORE the beat is shown —
	# a beat whose requested change didn't happen would be a lie on screen.
	var parsed: Dictionary = CueParser.parse(_story.current_tags.duplicate())
	if parsed["error"] != "":
		_fail(parsed["error"])
		return
	var cues: Array = parsed["cues"]
	if not cues.is_empty() and cue_stage == null:
		_fail(
			"[Narrative] Story uses cues but NarrativeDirector has no Cue Stage "
			+ "assigned. Select NarrativeDirector and set 'Cue Stage' in the Inspector."
		)
		return
	for cue in cues:
		var cue_error: String = cue_stage.execute_cue(
			cue["command"], cue["value"], text.strip_edges()
		)
		if cue_error != "":
			_fail(cue_error)
			return

	beat_ready.emit(text, parsed["plain_tags"])
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

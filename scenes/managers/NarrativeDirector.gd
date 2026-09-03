# NarrativeDirector.gd
#
# The conductor between your compiled Inky story (a .json file) and the game.
# It loads the story, hands each line (a "beat") to the story view one
# advance at a time, and passes the player's choices back to Ink. Story cues
# ("# @speaker: maya") go to the NarrativeStage, which the director finds by
# its group — so the stage can live inside a scene that gets swapped in and
# out (cut scenes, other game modes) while the story itself lives on here.
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
# A "# @scene:" cue is performed on the advance AFTER its line shows.
var _pending_scene: SceneLink = null
# True while the story view is swapped out for a cut scene / game mode.
var _content_up := false
# The stage as it was when we cut away, restored when the story view returns.
var _stage_snapshot: Dictionary = {}

func _ready() -> void:
	add_to_group(DIRECTORS_GROUP)
	# A cut scene / mini-game posts this when it is done (see CutScene.gd).
	SignalBus.content_finished.connect(_on_content_finished)
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
	_pending_scene = null
	_content_up = false
	_stage_snapshot = {}

	_story = _loader.load_from_path(json_path, _runtime)
	if _story == null:
		return false
	_attach_variable_displays()
	return not has_failed

# Every VariableDisplay in the scene gets the story's current value and is
# subscribed to changes (Ink's variable observer). A display naming a
# variable the story doesn't have is a loud failure — the message lists the
# variables that DO exist, so the typo is easy to spot.
func _attach_variable_displays() -> void:
	if not is_inside_tree():
		return
	var variables: InkVariablesState = _story.variables_state
	for display in get_tree().get_nodes_in_group(VariableDisplay.GROUP):
		var variable_name: String = display.variable_name.strip_edges()
		if not variables.global_variable_exists_with_name(variable_name):
			var known: Array = variables._global_variables.keys()
			known.sort()
			_fail(
				'[Narrative] VariableDisplay "%s" watches "%s" but the story has no such variable — known variables: %s'
				% [display.name, variable_name, ", ".join(known)]
			)
			return
		display.show_value(variables.get_variable(variable_name))
		_story.observe_variable(variable_name, display, "on_variable_changed")

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
	# A fresh story inherits nothing from the last one: clear the stage first.
	var stage := _find_stage()
	if stage != null:
		stage.reset()
	story_started.emit()
	SignalBus.story_started.emit()   # the bulletin board copy (ErrorBanner listens)
	continue_story()

func continue_story() -> void:
	if has_failed or _story == null or _story_over or _at_choices:
		return
	if _content_up:
		return   # a cut scene / game mode is on screen; it will tell us when it's done
	if _pending_scene != null:
		_cut_away()   # the line with the @scene cue has been read; now go
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
	var stage: NarrativeStage = null
	if not cues.is_empty():
		stage = _find_stage()
		if stage == null:
			_fail(
				"[Narrative] Story uses cues but there is no NarrativeStage in the scene "
				+ "tree — the NarrativeScene (which contains the Stage) must be loaded to run cues."
			)
			return
	for cue in cues:
		var cue_error: String = stage.execute_cue(
			cue["command"], cue["value"], text.strip_edges()
		)
		if cue_error != "":
			_fail(cue_error)
			return

	# A validated @scene waits until this line has been read.
	if stage != null:
		_pending_scene = stage.take_pending_scene()

	beat_ready.emit(text, parsed["plain_tags"])
	if _pending_scene == null:
		_report_stop_point()

func choose(choice_index: int) -> void:
	if _content_up:
		return
	_choose(choice_index)

func _choose(choice_index: int) -> void:
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

# ---- scene detours ----

# Swap the story view out for the pending SceneLink's scene.
func _cut_away() -> void:
	var link := _pending_scene
	_pending_scene = null
	var manager := _find_content_manager()
	if manager == null:
		_fail("[Narrative] Story uses @scene but Main.tscn has no ContentManager under Managers.")
		return
	var stage := _find_stage()
	_stage_snapshot = stage.snapshot() if stage != null else {}
	var error: String = manager.swap_to(link.scene, link.cue_name)
	if error != "":
		_fail(error)
		return
	_content_up = true
	if link.transition == SceneLink.Transition.FADE:
		var fade := get_tree().get_first_node_in_group("screen_fade")
		if fade == null:
			_fail('[Narrative] SceneLink "%s" asks for a fade but Main/UI has no Fade node — the template ships one; put it back.' % link.cue_name)
			return
		fade.flash()

# The cut scene / game mode is done: bring the story view back and go on.
func _on_content_finished() -> void:
	if not _content_up or has_failed:
		return
	var manager := _find_content_manager()
	if manager == null:
		return
	var error: String = manager.return_to_story()
	if error != "":
		_fail(error)
		return
	_content_up = false
	var stage := _find_stage()
	if stage != null and not _stage_snapshot.is_empty():
		error = stage.restore(_stage_snapshot)
		if error != "":
			_fail(error)
			return
	_stage_snapshot = {}
	# The fresh story view subscribes to us one deferred step from now;
	# continue one step later still, so it hears the next line.
	_resume_after_content.call_deferred()

func _resume_after_content() -> void:
	if has_failed or _story == null or _content_up:
		return
	if _story.can_continue:
		continue_story()
	else:
		_report_stop_point()

func _find_content_manager() -> ContentManager:
	return get_tree().get_first_node_in_group(ContentManager.GROUP) as ContentManager

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
	SignalBus.narrative_failed.emit(message)   # the bulletin board copy (ErrorBanner listens)

# The stage on duty: whichever NarrativeStage is in the running scene tree.
# Null when the story view is swapped out (or was never loaded).
func _find_stage() -> NarrativeStage:
	return get_tree().get_first_node_in_group(NarrativeStage.STAGE_GROUP) as NarrativeStage

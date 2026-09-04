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
# The text of the beat on screen — saved with the checkpoint so Continue can
# show it again.
var _last_beat_text := ""
# A saved game waiting to be restored (set by SaveManager.load_game via
# apply_snapshot; used by the next start_story).
var _pending_restore: Dictionary = {}
# The story ended; the next advance shows the end screen.
var _end_pending := false

func _ready() -> void:
	add_to_group(DIRECTORS_GROUP)
	# A cut scene / mini-game posts this when it is done (see CutScene.gd).
	SignalBus.content_finished.connect(_on_content_finished)
	# The title / end screens' buttons.
	SignalBus.new_game_requested.connect(_on_new_game_requested)
	SignalBus.continue_requested.connect(_on_continue_requested)
	SignalBus.title_requested.connect(_on_title_requested)
	# Checkpoints go through the hub SaveManager: it asks every "savable"
	# node for a snapshot (see get_snapshot / apply_snapshot below).
	add_to_group("savable")
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
	_end_pending = false
	_last_beat_text = ""

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
	if not _pending_restore.is_empty():
		_restore_checkpoint()   # Continue: pick up where the player left off
		return
	continue_story()

func continue_story() -> void:
	if has_failed or _story == null:
		return
	if _end_pending:
		_show_end_screen()   # the last line has been read
		return
	if _story_over or _at_choices:
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

	_last_beat_text = text
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
		_write_checkpoint()   # every choice point is a place Continue can return to
	else:
		_story_over = true
		SaveManager.delete_save()   # a finished story has nothing to continue
		var manager := _find_content_manager()
		_end_pending = manager != null and manager.has_end_screen()
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

# ---- title, end, new game, continue ----

func _on_new_game_requested() -> void:
	SaveManager.delete_save()
	_pending_restore = {}
	if story_file.is_empty() or not load_story(story_file):
		return
	_show_story_view_and_start()

func _on_continue_requested() -> void:
	if not SaveManager.has_save():
		_fail("[Narrative] No saved game to continue — start a New Game.")
		return
	_pending_restore = {}
	if not SaveManager.load_game():   # calls apply_snapshot() on us (by node path)
		_fail("[Narrative] The saved game could not be read — start a New Game.")
		return
	if _pending_restore.is_empty():
		# The director's node path may have changed (a renamed node, a test
		# rig): find the story checkpoint by its contents instead.
		for entry in SaveManager.read_snapshot().get("savables", []):
			var data = entry.get("data", {})
			if data is Dictionary and data.has("ink_state"):
				_pending_restore = data
				break
	if _pending_restore.is_empty():
		_fail("[Narrative] The saved game has no story in it — start a New Game.")
		return
	var saved_file: String = _pending_restore.get("story_file", "")
	if saved_file != story_file:
		_pending_restore = {}
		_fail(
			"[Narrative] The saved game is from a different story (%s) — start a New Game."
			% saved_file
		)
		return
	if not load_story(story_file):
		return
	_show_story_view_and_start()

func _on_title_requested() -> void:
	var manager := _find_content_manager()
	if manager == null:
		return
	var error: String = manager.show_title()
	if error != "":
		_fail(error)
		return
	_presentation_started = false
	_content_up = false

# Put the story view on screen; it starts the story when it connects. With
# no ContentManager (tests, or a Main without one) start right here.
func _show_story_view_and_start() -> void:
	var manager := _find_content_manager()
	if manager == null or manager.is_story_view_up():
		start_story()
		return
	var error: String = manager.return_to_story()
	if error != "":
		_fail(error)
		return
	# The story view subscribes one deferred step from now and normally
	# starts the story itself; if it doesn't (a custom view), start it here.
	start_story.call_deferred()

func _show_end_screen() -> void:
	_end_pending = false
	var manager := _find_content_manager()
	if manager == null:
		return
	var error: String = manager.show_end()
	if error != "":
		_fail(error)

# ---- checkpoints (the hub SaveManager's "savable" convention) ----

func get_snapshot() -> Dictionary:
	if _story == null:
		return {}
	var stage := _find_stage()
	return {
		"story_file": story_file,
		"ink_state": _story.state.to_json(),
		"stage": stage.snapshot() if stage != null else {},
		"beat_text": _last_beat_text,
	}

func apply_snapshot(data: Dictionary) -> void:
	_pending_restore = data

func _write_checkpoint() -> void:
	if has_failed or not is_inside_tree():
		return
	SaveManager.save_game()

# Continue: the story is freshly loaded; put it back where the checkpoint was.
func _restore_checkpoint() -> void:
	var data := _pending_restore
	_pending_restore = {}
	var ink_state: String = data.get("ink_state", "")
	if ink_state.is_empty():
		_fail("[Narrative] The saved game is incomplete — start a New Game.")
		return
	_story.state.load_json(ink_state)
	if has_failed:
		return
	var stage := _find_stage()
	var stage_state: Dictionary = data.get("stage", {})
	if stage != null and not stage_state.is_empty():
		var music: String = stage_state.get("music", "")
		var error: String = stage.restore(stage_state)
		if error == "" and music != "":
			error = stage.execute_cue("music", music, "")   # not playing yet: start it
		if error != "":
			_fail(error)
			return
	_last_beat_text = data.get("beat_text", "")
	beat_ready.emit(_last_beat_text, [])
	_report_stop_point()

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

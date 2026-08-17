# NarrativeStoryLoader.gd
#
# This is the narrow doorway between a compiled Inky JSON file and the large
# Ink runtime under addons/inkgd. It checks the friendly mistakes here first,
# so a bad file produces ONE useful [Narrative] error instead of a cascade of
# mysterious runtime errors.
#
# Most students will not call this directly. NarrativeDirector will own one.
extends RefCounted
class_name NarrativeStoryLoader

signal failed(message: String)

const SUPPORTED_INK_VERSION := 21
const OLDEST_SUPPORTED_INK_VERSION := 18

var has_failed := false
var last_error := ""

# Remembered so a later runtime problem can still say which file it came from.
var _active_json_path := ""

func load_from_path(json_path: String, ink_runtime: Node) -> InkStory:
	has_failed = false
	last_error = ""

	if ink_runtime == null:
		return _fail("[Narrative] Ink runtime is not initialized")

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return _fail("[Narrative] Cannot open Ink JSON: " + json_path)

	var json_text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	if parser.parse(json_text) != OK:
		return _fail("[Narrative] Invalid JSON in " + json_path)

	if not parser.data is Dictionary:
		return _fail("[Narrative] Ink JSON must contain an object: " + json_path)

	var data: Dictionary = parser.data
	if not data.has("inkVersion"):
		return _fail("[Narrative] Ink JSON is missing 'inkVersion': " + json_path)
	if not data.has("root"):
		return _fail("[Narrative] Ink JSON is missing 'root': " + json_path)

	var ink_version := int(data["inkVersion"])
	if ink_version > SUPPORTED_INK_VERSION:
		return _fail(
			"[Narrative] Ink version %d is newer than supported version %d: %s"
			% [ink_version, SUPPORTED_INK_VERSION, json_path]
		)
	if ink_version < OLDEST_SUPPORTED_INK_VERSION:
		return _fail(
			"[Narrative] Ink version %d is older than supported version %d: %s"
			% [ink_version, OLDEST_SUPPORTED_INK_VERSION, json_path]
		)

	_active_json_path = json_path
	_watch_runtime_exceptions(ink_runtime)

	var story := InkStory.new(json_text, ink_runtime)
	if has_failed:
		# The runtime hit an exception while building the story (reported
		# through _on_runtime_exception). The story object is not trustworthy.
		return null
	if story == null or story.state == null:
		return _fail("[Narrative] Ink runtime could not create story: " + json_path)

	story.on_error.connect(_on_story_error)
	return story

# The Ink runtime normally reports internal exceptions two different ways:
# in an exported game it only emits a signal (silent if nobody listens), and
# during development it can freeze the game on an assert deep inside the
# addon. Neither helps a student. We turn both paths into one loud
# [Narrative] error instead.
func _watch_runtime_exceptions(ink_runtime: Node) -> void:
	ink_runtime.stop_execution_on_exception = false
	ink_runtime.stop_execution_on_error = false
	if not ink_runtime.exception_raised.is_connected(_on_runtime_exception):
		ink_runtime.exception_raised.connect(_on_runtime_exception)

func _on_runtime_exception(message: String, _stack_trace) -> void:
	_fail("[Narrative] Ink runtime exception in %s: %s" % [_active_json_path, message])

func _on_story_error(message: String, _error_type) -> void:
	_fail("[Narrative] Ink story error: " + message)

func _fail(message: String):
	has_failed = true
	last_error = message
	push_error(message)
	failed.emit(message)
	return null

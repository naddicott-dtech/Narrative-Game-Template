# NarrativeStage.gd
#
# Everything the story controls on screen besides the text itself: the
# speaker's name and portrait now, backgrounds and audio in later versions.
# The NarrativeDirector hands each story cue here ("@speaker: maya") and this
# stage either performs it and answers "" — or answers with one clear
# [Narrative] error message, and the director stops the story. A cue never
# half-happens.
#
# Characters are SpeakerLink nodes under the Links child — duplicate one per
# character and fill its Inspector fields. After a cue succeeds, the stage
# posts an announcement on SignalBus (the bulletin board), so any script can
# react: SignalBus.speaker_changed.connect(my_function)
class_name NarrativeStage
extends Control

## The Label that shows the current speaker's name.
@export var speaker_label: Label
## The TextureRect that shows the current speaker's portrait.
@export var portrait_rect: TextureRect

# Performs one cue. Returns "" on success, or the full error message —
# the director prints it and halts, so this script never push_errors itself.
# beat_text rides along so error messages can say which story line broke.
func execute_cue(command: String, value: String, beat_text: String) -> String:
	match command:
		"speaker":
			return _do_speaker(value)
		_:
			# A specialist adds a command here: one match branch + one
			# _do_...() function + a link type if it needs assets.
			return (
				'[Narrative] Unsupported reserved cue "@%s: %s" at "%s" — this template does not run that command'
				% [command, value, beat_text]
			)

func _do_speaker(value: String) -> String:
	if speaker_label == null:
		return (
			"[Narrative] NarrativeStage is missing its Speaker Label reference. "
			+ "Select NarrativeStage and assign it in the Inspector."
		)

	# The reserved value "none" means: narrator speaks — clear name and art.
	if value == "none":
		speaker_label.text = ""
		if portrait_rect != null:
			portrait_rect.texture = null
		SignalBus.speaker_changed.emit("none")
		return ""

	var found := _find_speaker_link(value)
	if found["error"] != "":
		return found["error"]
	var link: SpeakerLink = found["link"]

	if link.display_name.strip_edges() == "":
		return (
			'[Narrative] SpeakerLink "%s" has no Display Name — select it and fill the field in the Inspector.'
			% value
		)
	if link.portrait != null and portrait_rect == null:
		return (
			"[Narrative] NarrativeStage is missing its Portrait Rect reference. "
			+ "Select NarrativeStage and assign it in the Inspector."
		)

	speaker_label.text = link.display_name
	if portrait_rect != null:
		portrait_rect.texture = link.portrait
	SignalBus.speaker_changed.emit(value)
	return ""

# Searches everything under the stage for SpeakerLinks (so it keeps working
# however students organize the Links folder). Exactly one match wins.
func _find_speaker_link(value: String) -> Dictionary:
	var matches: Array = []
	var known_names: Array = []
	var to_visit: Array = get_children()
	while not to_visit.is_empty():
		var node: Node = to_visit.pop_back()
		to_visit.append_array(node.get_children())
		if node is SpeakerLink:
			known_names.append(node.cue_name)
			if node.cue_name == value:
				matches.append(node)

	if matches.size() > 1:
		return {"link": null, "error":
			'[Narrative] Two SpeakerLinks share the cue name "%s" — rename one.' % value}
	if matches.is_empty():
		known_names.sort()
		var listing := "(none)" if known_names.is_empty() else ", ".join(known_names)
		return {"link": null, "error":
			'[Narrative] No SpeakerLink named "%s" under NarrativeStage — known names: %s'
			% [value, listing]}
	return {"link": matches[0], "error": ""}

# NarrativeStage.gd
#
# Everything the story controls on screen besides the text itself: the
# background, the two portrait slots, and the speaker's name. The
# NarrativeDirector hands each story cue here ("@speaker: maya") and this
# stage either performs it and answers "" — or answers with one clear
# [Narrative] error message, and the director stops the story. A cue never
# half-happens.
#
# Cues this stage runs:
#   @speaker: <name>      show that SpeakerLink's name + portrait (lit)
#   @speaker: none        narrator — no name; the cast stays, dimmed
#   @exit: <name>         that character leaves the screen (all = everyone)
#   @background: <name>   show that BackgroundLink's picture
#   @background: none     back to the picture the scene started with
#   @music: <name>        play that MusicLink's track (same track again = keeps playing)
#   @music: off           stop the music
#   @sfx: <name>          play that SfxLink's sound once
#
# Characters are SpeakerLink nodes, pictures are BackgroundLink nodes, and
# audio is MusicLink / SfxLink nodes — all under the Links child. Duplicate
# one per character / place / sound and fill its Inspector fields. Audio is
# played by the game's AudioManager (autoload); this stage just hands it the
# right file. After a cue succeeds, the stage posts an announcement
# on SignalBus (the bulletin board), so any script can react:
#     SignalBus.speaker_changed.connect(my_function)
#
# The director finds this stage by its group (see STAGE_GROUP), so the stage
# can live inside a scene that gets swapped in and out.
class_name NarrativeStage
extends Control

## The group the director looks in to find the stage on duty.
const STAGE_GROUP := "narrative_stage"
## How a portrait looks when its character is not the one speaking.
const DIM_COLOR := Color(0.55, 0.55, 0.55, 1.0)

## The full-screen picture behind everything.
@export var background: TextureRect
## Where a Left-side character's portrait appears.
@export var left_portrait: TextureRect
## Where a Right-side character's portrait appears.
@export var right_portrait: TextureRect
## The Label that shows the current speaker's name.
@export var speaker_label: Label

# The background the scene was designed with, restored by reset() and by
# "@background: none".
var _default_background: Texture2D = null
# The cue name of the track playing now ("" = none) — so cueing the same
# track twice does not restart it.
var _current_music := ""

func _ready() -> void:
	add_to_group(STAGE_GROUP)
	if background != null:
		_default_background = background.texture

# Back to the stage's starting look. The director calls this when a story
# starts, so a restarted story never inherits the old story's cast.
func reset() -> void:
	if speaker_label != null:
		speaker_label.text = ""
	for slot in [left_portrait, right_portrait]:
		if slot != null:
			slot.texture = null
			slot.modulate = Color.WHITE
	if background != null:
		background.texture = _default_background
	AudioManager.stop_music()
	_current_music = ""

# Performs one cue. Returns "" on success, or the full error message —
# the director prints it and halts, so this script never push_errors itself.
# beat_text rides along so error messages can say which story line broke.
func execute_cue(command: String, value: String, beat_text: String) -> String:
	match command:
		"speaker":
			return _do_speaker(value)
		"exit":
			return _do_exit(value)
		"background":
			return _do_background(value)
		"music":
			return _do_music(value)
		"sfx":
			return _do_sfx(value)
		_:
			# A specialist adds a command here: one match branch + one
			# _do_...() function + a link type if it needs assets.
			return (
				'[Narrative] Unsupported reserved cue "@%s: %s" at "%s" — this template does not run that command'
				% [command, value, beat_text]
			)

# ---- @speaker ----

func _do_speaker(value: String) -> String:
	if speaker_label == null:
		return _missing_reference("Speaker Label")

	# The reserved value "none" means: the narrator speaks — no name, and the
	# cast on screen dims but stays.
	if value == "none":
		speaker_label.text = ""
		_dim_everyone()
		SignalBus.speaker_changed.emit("none")
		return ""

	var found := _find_link(SpeakerLink, "SpeakerLink", value)
	if found["error"] != "":
		return found["error"]
	var link: SpeakerLink = found["link"]

	if link.display_name.strip_edges() == "":
		return (
			'[Narrative] SpeakerLink "%s" has no Display Name — select it and fill the field in the Inspector.'
			% value
		)

	if link.portrait != null:
		var slot := _slot_for(link.side)
		if slot == null:
			return _missing_reference(_side_name(link.side) + " Portrait")
		slot.texture = link.portrait
		_dim_everyone()
		slot.modulate = Color.WHITE   # the spotlight
	else:
		_dim_everyone()   # a voice with no portrait: nobody on screen is lit

	speaker_label.text = link.display_name
	SignalBus.speaker_changed.emit(value)
	return ""

# ---- @exit ----

func _do_exit(value: String) -> String:
	# The reserved value "all" empties the stage: both slots and the name.
	if value == "all":
		reset_cast()
		SignalBus.character_exited.emit("all")
		return ""

	var found := _find_link(SpeakerLink, "SpeakerLink", value)
	if found["error"] != "":
		return found["error"]
	var link: SpeakerLink = found["link"]

	var slot := _slot_for(link.side)
	if slot != null:
		slot.texture = null
		slot.modulate = Color.WHITE
	# Only clear the name if it was this character who was talking.
	if speaker_label != null and speaker_label.text == link.display_name:
		speaker_label.text = ""
	SignalBus.character_exited.emit(value)
	return ""

# Clears the cast (name + both portraits) but keeps the background.
func reset_cast() -> void:
	if speaker_label != null:
		speaker_label.text = ""
	for slot in [left_portrait, right_portrait]:
		if slot != null:
			slot.texture = null
			slot.modulate = Color.WHITE

# ---- @background ----

func _do_background(value: String) -> String:
	if background == null:
		return _missing_reference("Background")

	# The reserved value "none" means: the picture the scene started with.
	if value == "none":
		background.texture = _default_background
		SignalBus.background_changed.emit("none")
		return ""

	var found := _find_link(BackgroundLink, "BackgroundLink", value)
	if found["error"] != "":
		return found["error"]
	var link: BackgroundLink = found["link"]

	if link.image == null:
		return (
			'[Narrative] BackgroundLink "%s" has no Image — select it and set the field in the Inspector.'
			% value
		)

	if background.texture != link.image:   # same picture again = nothing to do
		background.texture = link.image
	SignalBus.background_changed.emit(value)
	return ""

# ---- @music ----

func _do_music(value: String) -> String:
	# The reserved value "off" means: silence.
	if value == "off":
		AudioManager.stop_music()
		_current_music = ""
		SignalBus.music_changed.emit("off")
		return ""

	var found := _find_link(MusicLink, "MusicLink", value)
	if found["error"] != "":
		return found["error"]
	var link: MusicLink = found["link"]

	if link.music == null:
		return (
			'[Narrative] MusicLink "%s" has no Music — select it and set the field in the Inspector.'
			% value
		)

	if _current_music != value:   # the same track again just keeps playing
		AudioManager.play_music(link.music)
		_current_music = value
	SignalBus.music_changed.emit(value)
	return ""

# ---- @sfx ----

func _do_sfx(value: String) -> String:
	var found := _find_link(SfxLink, "SfxLink", value)
	if found["error"] != "":
		return found["error"]
	var link: SfxLink = found["link"]

	if link.sound == null:
		return (
			'[Narrative] SfxLink "%s" has no Sound — select it and set the field in the Inspector.'
			% value
		)

	AudioManager.play_sfx(link.sound)
	SignalBus.sfx_played.emit(value)
	return ""

# ---- helpers ----

func _slot_for(side: SpeakerLink.ScreenSide) -> TextureRect:
	return left_portrait if side == SpeakerLink.ScreenSide.LEFT else right_portrait

func _side_name(side: SpeakerLink.ScreenSide) -> String:
	return "Left" if side == SpeakerLink.ScreenSide.LEFT else "Right"

func _dim_everyone() -> void:
	for slot in [left_portrait, right_portrait]:
		if slot != null:
			slot.modulate = DIM_COLOR

func _missing_reference(field_name: String) -> String:
	return (
		"[Narrative] NarrativeStage is missing its %s reference. " % field_name
		+ "Select NarrativeStage and assign it in the Inspector."
	)

# Searches everything under the stage for links of one type (so it keeps
# working however students organize the Links folder). Exactly one link with
# the requested cue name wins; the errors list what DOES exist.
func _find_link(link_script: Script, type_name: String, value: String) -> Dictionary:
	var matches: Array = []
	var known_names: Array = []
	var to_visit: Array = get_children()
	while not to_visit.is_empty():
		var node: Node = to_visit.pop_back()
		to_visit.append_array(node.get_children())
		if node.get_script() == link_script:
			known_names.append(node.cue_name)
			if node.cue_name == value:
				matches.append(node)

	if matches.size() > 1:
		return {"link": null, "error":
			'[Narrative] Two %ss share the cue name "%s" — rename one.' % [type_name, value]}
	if matches.is_empty():
		known_names.sort()
		var listing := "(none)" if known_names.is_empty() else ", ".join(known_names)
		return {"link": null, "error":
			'[Narrative] No %s named "%s" under NarrativeStage — known names: %s'
			% [type_name, value, listing]}
	return {"link": matches[0], "error": ""}

# CueParser.gd
#
# Reads the "# tags" attached to one story beat and sorts them into two piles:
#
#   cues        — tags starting with @ are commands for the game,
#                 written in Inky as:  # @speaker: maya
#   plain_tags  — every other tag ("author: Sam") passes through untouched.
#
# The rules ("the cue grammar"): one @command per tag, lowercase snake_case
# command names, whitespace around the command and value is trimmed, and the
# same command may not appear twice on one beat. Anything that breaks a rule
# returns one clear [Narrative] error message and NO cues — the director
# stops the story rather than half-running a broken beat.
class_name CueParser
extends RefCounted

const _COMMAND_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"

# Returns {"cues": [{command, value}, …], "plain_tags": […], "error": ""}.
# On a bad tag, "error" holds the full message and both lists are empty.
static func parse(tags: Array) -> Dictionary:
	var cues: Array = []
	var plain_tags: Array = []
	var seen_commands: Array = []

	for tag in tags:
		var trimmed := str(tag).strip_edges()
		if not trimmed.begins_with("@"):
			plain_tags.append(tag)
			continue

		var colon := trimmed.find(":")
		var command := "" if colon == -1 else trimmed.substr(1, colon - 1).strip_edges()
		var value := "" if colon == -1 else trimmed.substr(colon + 1).strip_edges()
		if colon == -1 or command == "" or value == "" or not _is_snake_case(command):
			return _error(
				'[Narrative] Malformed cue "%s" — cues look like "# @command: value"'
				% trimmed
			)
		if command in seen_commands:
			return _error(
				'[Narrative] Two "@%s" cues on one beat — one command per beat'
				% command
			)

		seen_commands.append(command)
		cues.append({"command": command, "value": value})

	return {"cues": cues, "plain_tags": plain_tags, "error": ""}

static func _is_snake_case(command: String) -> bool:
	for character in command:
		if not character in _COMMAND_CHARS:
			return false
	return true

static func _error(message: String) -> Dictionary:
	return {"cues": [], "plain_tags": [], "error": message}

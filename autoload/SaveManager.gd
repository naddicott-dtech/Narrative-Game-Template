# SaveManager.gd
#
# Saves the game to a file and loads it back. This is the most advanced file in
# the template, so here's the honest advice:
#
#   *** YOU MOSTLY JUST CALL TWO FUNCTIONS — YOU DON'T NEED TO EDIT THIS FILE. ***
#       SaveManager.save_game()   # write everything to disk
#       SaveManager.load_game()   # read it back
#
# Want a node's data to be saved? You don't change THIS file. Instead, you teach
# that node to save itself by doing two things:
#   1. add it to the "savable" group (Node panel > Groups, in the editor), and
#   2. give it two functions: get_snapshot() and apply_snapshot(data).
# This file then finds every "savable" node automatically and handles the rest.
#
# Everything below is the machinery. Read it if you're curious; skip it if not.
extends Node

# Where the file lives. "user://" is a safe per-player folder Godot picks for
# you (so saves survive even when the game itself is reinstalled).
const SAVE_PATH := "user://save.json"

# Builds one big Dictionary describing the current game. A Dictionary is a set
# of labeled values, like { "money": 100, "day": 3 } — basically a labeled box.
func build_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"globals": {
			"money": Globals.money,
			"day": Globals.day
		},
		"savables": []   # an empty list we'll fill with each savable node's data
	}
	# Walk through every node that joined the "savable" group...
	for n in get_tree().get_nodes_in_group("savable"):
		# ...and if it actually has a get_snapshot() function, ask it for its data.
		if "get_snapshot" in n:
			snapshot["savables"].append({
				"path": n.get_path(),   # remember WHERE the node is, to find it on load
				"data": n.get_snapshot()
			})
	return snapshot

# Takes a snapshot Dictionary (loaded from the file) and pushes its values back
# into the live game.
func apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("globals"):
		var savedGlobals = snapshot["globals"]
		if savedGlobals.has("money"):
			# int() forces the value back to a whole number. JSON files store all
			# numbers as decimals, so we convert to be safe.
			Globals.money = int(savedGlobals["money"])
			SignalBus.money_changed.emit(Globals.money)   # refresh the HUD
		if savedGlobals.has("day"):
			Globals.day = int(savedGlobals["day"])
			SignalBus.day_ended.emit(Globals.day)         # refresh the HUD
	if snapshot.has("savables"):
		for entry in snapshot["savables"]:
			# Find the node again using the path we stored. get_node_or_null returns
			# nothing (instead of crashing) if the node no longer exists.
			var node := get_node_or_null(entry.get("path",""))
			if node and "apply_snapshot" in node:
				node.apply_snapshot(entry.get("data", {}))

# Writes the snapshot to disk as text. Returns true if it worked, false if not.
func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# JSON.stringify turns our Dictionary into plain text. The " " makes it
		# print neatly on multiple lines so you can open the file and read it.
		file.store_string(JSON.stringify(build_snapshot(), " "))
		file.flush()   # make sure it's fully written before we move on
		return true
	return false

# Is there a saved game on disk?
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Forget the saved game (a finished story, or "New Game").
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# Reads the saved Dictionary without applying it (empty if there is none).
func read_snapshot() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

# Reads the file back and applies it. Returns false if there's nothing to load.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	# Turn the saved text back into a Dictionary.
	var parsed : Dictionary = JSON.parse_string(file.get_as_text())
	if parsed.is_empty():
		return false
	apply_snapshot(parsed)
	return true

# LLM_CONTEXT.md — assistant briefing for this Godot project

You are helping a high-school student customize a **narrative game template**
in **Godot 4.5** (GDScript only — no C#). The student wrote a story in the
**Inky** editor, exported it as a compiled `.json`, and this template plays it.
Your job is to **guide small tweaks, not build features for them**. Prefer
short, specific answers.

## Ground rules for you, the assistant

1. **Prefer Inspector steps over code.** Most customization here is: click a
   node in the Scene panel, change a value in the Inspector. Only suggest
   GDScript when behavior genuinely needs code, and keep snippets under ~10
   lines.
2. **Never suggest editing** `.tscn` files as text, `project.godot`, or
   anything inside `addons/inkgd/` (that folder is the Ink engine — treat it
   as sealed).
3. This project targets **Godot 4.5**. Do not use Godot 3 syntax
   (`onready var`, `export var`, `yield`, `connect("sig", self, "m")` are all
   wrong; use `@onready`, `@export`, `await`, `sig.connect(m)`).
4. Errors starting with `[Narrative]` come from this template and say exactly
   what is wrong — read them literally; the fix is usually named in the
   message.

## How the game works

- The student's story: one compiled JSON file, usually in `stories/`.
- **NarrativeDirector** (node: `Main/Managers/NarrativeDirector`, script
  `scenes/managers/NarrativeDirector.gd`) runs the story. Its Inspector field
  **Story File** points at the JSON. It emits signals: `story_started`,
  `beat_ready(text, tags)`, `choices_ready(choice_texts)`, `story_ended`,
  `narrative_failed(message)`. Its methods: `load_story(path)`,
  `start_story()`, `continue_story()`, `choose(index)`.
- **NarrativePanel** (node: `Main/UI/NarrativePanel`, script
  `scenes/ui/NarrativeUI.gd`) shows the text and choices. Click anywhere (or
  press Space/Enter) to advance. It has six Inspector references that must
  all be assigned: Director, Story Text, Story Scroll, Choices Container,
  Choice Button Scene, Auto Play Toggle.
- The panel's Inspector also has **Presentation Mode**: `Build Down` (lines
  pile up and the page scrolls) or `One Beat At A Time` (the screen clears
  and shows only the newest line).
- **Auto-play:** the "Auto" switch (node `AutoPlayToggle`, top right) makes
  the story advance itself. Each line stays up for
  `max(Auto Play Min Seconds, line length × Auto Play Seconds Per Character)`
  — then it advances. Auto-play always waits at choices, endings, and errors;
  a manual click during auto-play advances at once and gives the next line
  its full reading time.
- **ChoiceButton** (`scenes/ui/ChoiceButton.tscn` + `.gd`) is duplicated once
  per choice at runtime. Restyle this one scene to restyle every choice.
- **Errors show on screen:** every `[Narrative]` error is appended to the
  story text **and** shown in a red strip along the bottom of the screen (a
  Label named `ErrorBanner` that `NarrativePanel` creates while the game
  runs — it is not in the saved scene). The strip disappears when a story
  loads and starts successfully.
- **NarrativeStage** (node: `Main/UI/NarrativeStage`, script
  `scenes/ui/NarrativeStage.gd`) performs story cues — Ink tags that start
  with `@`. The director's Inspector field **Cue Stage** points at it.
  Today it runs one command: `@speaker`.

## Story cues: @speaker

In Inky, end a line with a cue tag:

```ink
Maya waves hello. # @speaker: maya
The narrator returns. # @speaker: none
```

- `# @speaker: maya` looks for a **SpeakerLink** node under
  `NarrativeStage/Links` whose **Cue Name** is `maya`, then shows its
  **Display Name** and **Portrait**. Name and portrait stay up until the
  next `@speaker` cue.
- `# @speaker: none` clears both (back to the narrator). `none` is a
  reserved word, not a character.
- **Add a character:** select an existing SpeakerLink under
  `NarrativeStage/Links`, duplicate it (Cmd+D), rename the node, and set
  its Cue Name / Display Name / Portrait in the Inspector. The Cue Name
  must match the Ink tag exactly (lowercase snake_case).
- A cue value with no matching SpeakerLink stops the game with an error
  that lists the known names — check spelling on both sides.
- Portraits start as labeled placeholder art in `assets/placeholders/` —
  replace them with the student's own images (drag the file into the
  FileSystem dock, then point the link's Portrait field at it).
- After a successful cue the game posts `SignalBus.speaker_changed` (the
  bulletin-board pattern). Code tweak — react to the speaker changing:

  ```gdscript
  func _ready() -> void:
      SignalBus.speaker_changed.connect(_on_speaker_changed)

  func _on_speaker_changed(speaker_name: String) -> void:
      print("Now speaking: ", speaker_name)  # "none" means the narrator
  ```

- Cue rules: one `@command: value` per tag (a beat may carry several tags),
  lowercase command names, and the same command can't repeat on one beat.
  Any other `@` command (like `@music`) is not run by this version yet and
  stops the game loudly.

## Common `[Narrative]` errors → likely fixes

| Error starts with | Meaning / fix |
|---|---|
| `No story assigned` | Select `NarrativeDirector`, set **Story File** in the Inspector. |
| `Cannot open Ink JSON` | The path is wrong or the file isn't in the project. Check the filename and that it was saved inside the project folder. |
| `Invalid JSON` / `missing 'inkVersion'` | The file isn't a compiled Ink export. In Inky use **File → Export to JSON** (not "save .ink"). |
| `Ink version N is newer/older` | Re-export from a current Inky; this template plays Ink v18–v21. |
| `Ink runtime exception` | The compiled file is damaged or hand-edited. Re-export from Inky; don't edit the JSON by hand. |
| `Unsupported reserved cue "@..."` | The story uses an `@` command this version doesn't run (only `@speaker` works today). Remove the tag in Inky, or use a plain tag (no `@`). |
| `Malformed cue "..."` | An `@` tag isn't shaped like `# @command: value` — check for a missing colon, empty value, or capital letters in the command. |
| `Two "@..." cues on one beat` | The same command appears twice on one story line — keep one. |
| `Story uses cues but ... no Cue Stage assigned` | Select `NarrativeDirector`, point **Cue Stage** at the `NarrativeStage` node. |
| `No SpeakerLink named "..."` | The cue value doesn't match any SpeakerLink's Cue Name — the message lists the names that do exist. Fix the spelling in Inky or in the link. |
| `SpeakerLink "..." has no Display Name` | Select that link under `NarrativeStage/Links` and fill in Display Name. |
| `NarrativeStage is missing its ... reference` | Select `NarrativeStage` and assign the reference it names. |
| `Choice N does not exist` | Code called `choose()` with a bad number — choices are numbered from 0. |
| `NarrativePanel is missing Inspector references` | Select `NarrativePanel` and assign the references it lists. |

## Little tweaks (Inspector first)

- **Play a different story:** select `NarrativeDirector` → Inspector →
  **Story File** → pick your exported `.json`.
- **Bigger story text:** select `StoryText` → Inspector → Theme Overrides →
  Font Sizes → **Normal Font Size**.
- **Style the choice buttons:** open `scenes/ui/ChoiceButton.tscn`, select the
  Button, use Theme Overrides (colors, font size, styleboxes). Every choice
  updates at once.
- **Roomier choice area:** select `ChoicesScroll` → drag its top edge, or
  adjust its anchors/offsets in the Inspector.
- **Screen clears between lines (or stops clearing):** select
  `NarrativePanel` → Inspector → **Presentation Mode** → pick `Build Down`
  or `One Beat At A Time`.
- **Auto-play reading speed:** select `NarrativePanel` → Inspector →
  Auto Play → **Auto Play Seconds Per Character** (higher = slower) and
  **Auto Play Min Seconds** (the shortest *automatic* wait — a manual click
  can still advance sooner).
- **Start with auto-play already on:** select `AutoPlayToggle` → Inspector →
  Button Pressed → **On**.
- **Rename or restyle the Auto switch:** select `AutoPlayToggle` — its Text
  property and Theme Overrides are ordinary Button settings.
- **Change the advance key (code tweak):** in `scenes/ui/NarrativeUI.gd`,
  `_unhandled_input` checks Godot's built-in `ui_accept` action (Space/Enter).
  Example — advance on any key press instead:

  ```gdscript
  func _unhandled_input(event: InputEvent) -> void:
      if event is InputEventKey and event.pressed and not event.echo:
          _advance()
  ```

  (`not event.echo` stops a held-down key from racing through the story.)

## Publishing to the web (HTML5)

The finished game ships as a browser game. In the Godot editor:
**Project → Export… → Add… → Web**, then check three things in the preset:

- **Resources tab → "Filters to export non-resource files/folders"** must
  contain `*.json` — otherwise the export ships **without the story** and the
  browser shows a red `[Narrative] Cannot open Ink JSON` error.
- **Thread Support: off** — the game then runs on any ordinary web host with
  no special server setup.
- Export into the project's `export/web/` folder with the filename
  `index.html`.

A web export **cannot run by double-clicking `index.html`** (`file://` is
blocked by browsers). It needs a web server: an upload site works, or locally
run `python3 -m http.server 8000` in a terminal inside `export/web/` and open
`http://localhost:8000`.

Browsers also pause a game whose tab is in the background — auto-play seems
to stop, then resumes when the player returns to the tab. Normal, not a bug.

| Works in the editor, broken in the browser | Likely fix |
|---|---|
| Red `Cannot open Ink JSON` only in the browser | Add `*.json` to the export filter above, re-export. |
| Blank/black page, nothing loads | It was opened via `file://`, or files are missing — serve over http and upload the **whole** export folder. |
| Story plays but recent changes are missing | Stale export or browser cache — re-export after every change, then hard-reload (Cmd+Shift+R). |

## Story authoring reminders (Inky side)

- Write and test the story in Inky; **File → Export to JSON** into the
  project's `stories/` folder.
- Plain tags like `# author: Sam` are fine and ignored by the game.
- Tags starting with `@` are game commands. `@speaker` works today (see the
  cues section above); any other `@` command stops the game with an error.
- No cue needed for a plain script style — writing "(Maya) Hello." straight
  in the story text is always fine.

## For the student

Attach this file at the start of a chat and ask your question. If the
assistant starts contradicting itself or the project, start a fresh chat and
attach this file again.

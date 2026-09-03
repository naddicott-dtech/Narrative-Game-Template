# LLM_CONTEXT.md — assistant briefing for this Godot project

You are helping a high-school student customize a **narrative game template**
in **Godot 4.5** (GDScript only — no C#). The student wrote a story in the
**Inky** editor, exported it as a compiled `.json`, and this template plays it
like a visual novel: a full-screen background, character portraits left and
right, and a dialogue box along the bottom. Your job is to **guide small
tweaks, not build features for them**. Prefer short, specific answers.

## Ground rules for you, the assistant

1. **Prefer Inspector steps over code.** Most customization here is: click a
   node in the Scene panel, change a value in the Inspector. Only suggest
   GDScript when behavior genuinely needs code, and keep snippets under ~10
   lines.
2. **Never suggest editing** `.tscn` files as text, `project.godot`, or
   anything inside `addons/inkgd/` (that folder is the Ink engine — treat it
   as sealed). Opening a `.tscn` in the editor and changing things in the
   Inspector is the normal way to work — that's fine.
3. This project targets **Godot 4.5**. Do not use Godot 3 syntax
   (`onready var`, `export var`, `yield`, `connect("sig", self, "m")` are all
   wrong; use `@onready`, `@export`, `await`, `sig.connect(m)`).
4. Errors starting with `[Narrative]` come from this template and say exactly
   what is wrong — read them literally; the fix is usually named in the
   message.

## Before you start (the three things everyone gets stuck on)

- **Two scene files.** `scenes/Main.tscn` is the frame — open it to change
  the **Story File** (on `NarrativeDirector`). `scenes/narrative/NarrativeScene.tscn`
  is the story view — open it (double-click in the FileSystem dock) to change
  anything you *see*: characters (`Stage/Links`), the background, the dialogue
  box, the choices. In Main.tscn, `NarrativeScene` appears as one closed node;
  that's normal.
- **Where things are in the editor:** the **Scene panel** (node tree) is top
  left, the **Inspector** (properties of the selected node) is on the right,
  the **FileSystem dock** (your project's files) is bottom left.
- **Using your own picture:** drag the image file from Finder into the
  FileSystem dock (onto the `assets/` folder). Then select the node that
  should show it and drag the file from the FileSystem dock onto its
  **Portrait** (or **Texture**) field — or click the field and choose **Load**.
- **After any change in Inky:** File → Export to JSON again (same file name,
  into `stories/`), then press Play again in Godot. Nothing else to redo.

## How the game works

- The student's story: one compiled JSON file, usually in `stories/`.
- **Main** (`scenes/Main.tscn`) is the frame that never changes while the
  game runs: `Managers` (the story engine), `WorldRoot` (holds the ONE scene
  currently on screen), and `UI` (things that stay on screen no matter what).
- **NarrativeDirector** (node: `Main/Managers/NarrativeDirector`, script
  `scenes/managers/NarrativeDirector.gd`) runs the story. Its Inspector field
  **Story File** points at the JSON. *(For the assistant, code-level:)* it
  emits signals `story_started`, `beat_ready(text, tags)`,
  `choices_ready(choice_texts)`, `story_ended`, `narrative_failed(message)`;
  its methods are `load_story(path)`, `start_story()`, `continue_story()`,
  `choose(index)`.
- **NarrativeScene** (node: `Main/WorldRoot/NarrativeScene`, its own scene
  file `scenes/narrative/NarrativeScene.tscn`, script
  `scenes/narrative/NarrativeScene.gd`) is the story view — everything the
  player sees. Click anywhere (or press Space/Enter) to advance. It finds the
  director by itself; its five Inspector references must all be assigned:
  Story Text, Story Scroll, Choices Container, Choice Button Scene, Auto Play
  Toggle (they are, in the shipped scene).
- Inside NarrativeScene:
  - `Stage` — the art layer (see the cues section): `Background`,
    `LeftPortrait`, `RightPortrait`, and the `Links` folder of characters.
  - `DialogueBox` — the dark panel along the bottom. Inside its `Rows`:
    `SpeakerLabel` (who is talking) above `StoryScroll/StoryText` (what they
    say).
  - `ChoicesScroll/ChoicesContainer` — choices appear here, stacked in the
    upper-middle of the screen.
  - `AutoPlayToggle` — the "Auto" switch, top right.
- A **beat** is one chunk of story text the game shows before waiting for a
  click — normally one line (one paragraph) in Inky.
- The scene's Inspector has **Presentation Mode**: `One Beat At A Time` (the
  default — the box shows only the newest beat) or `Build Down` (beats pile
  up and the box scrolls, like a text adventure).
- **Auto-play:** the "Auto" switch makes the story advance itself. Each line
  stays up for `max(Auto Play Min Seconds, line length × Auto Play Seconds
  Per Character)` — then it advances. Auto-play always waits at choices,
  endings, and errors; a manual click during auto-play advances at once and
  gives the next line its full reading time.
- **ChoiceButton** (`scenes/ui/ChoiceButton.tscn` + `.gd`) is duplicated once
  per choice at runtime. Restyle this one scene to restyle every choice.
- **Errors show on screen:** every `[Narrative]` error is appended to the
  story text **and** shown in a red strip along the bottom of the screen — the
  `ErrorBanner` node at `Main/UI/ErrorBanner`. It listens to the bulletin
  board (`SignalBus.narrative_failed`) and hides when a story starts cleanly.
- *(For the assistant, code-level:)* **SignalBus** (`autoload/SignalBus.gd`)
  is the bulletin board: scripts post announcements there and anyone can
  listen. Story-related posts: `story_started`, `narrative_failed(message)`,
  `speaker_changed(name)`.

## Story cues: @speaker

In Inky, end a line with a cue tag:

```ink
Maya waves hello. # @speaker: maya
The narrator returns. # @speaker: none
```

- `# @speaker: maya` looks for a **SpeakerLink** node under
  `NarrativeScene/Stage/Links` whose **Cue Name** is `maya`, shows its
  **Display Name** above the text, and puts its **Portrait** in the slot
  chosen by its **Side** (Left or Right). The speaking character is bright;
  the other slot dims. Name and portrait stay up until the next `@speaker`.
- `# @speaker: none` clears the name and dims both portraits (the narrator is
  talking; the cast stays on screen). `none` is a reserved word, not a
  character. Portraits leave the screen when a new story starts.
- **Add a character:** the template ships two example links, `Character1`
  (left) and `Character2` (right), under `NarrativeScene/Stage/Links` with
  Cue Names `character_1` / `character_2`. Select one, duplicate it (Cmd+D —
  the copy appears as `Character3`), rename it (double-click its name in the
  Scene panel), and set its Cue Name / Display Name / Portrait / Side in the
  Inspector. Or just edit the two examples in place for your first two
  characters. The
  node's own name is just a label for you; what matters is that **Cue Name
  matches the Ink tag exactly**. Capitals work if both sides match, but
  lowercase words joined by underscores (`dispatcher`, `old_man`) mean you
  never have to think about it.
- **A character with several expressions:** make one SpeakerLink per
  expression with different Cue Names (`maya`, `maya_angry`) pointing at
  different image files, and use the matching tag in Inky.
- **A voice with no picture** (a radio, an off-screen shout): leave Portrait
  empty. The name shows; nobody on screen is lit.
- A cue value with no matching SpeakerLink stops the game with an error
  that lists the known names — check spelling on both sides.
- Portraits start as labeled placeholder art in `assets/placeholders/`
  (`portrait_1.png`, `portrait_2.png`, 300×450 px) — replace them with the
  student's own images (see "Before you start"). Any size works: the slot is
  300×450 and the picture is shrunk to fit, keeping its shape, never cropped.
  A tall portrait-shaped image fills the slot best.
- *(For the assistant, code-level:)* after a successful cue the game posts
  `SignalBus.speaker_changed` (the bulletin-board pattern). Code tweak —
  react to the speaker changing:

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
| `Malformed cue "..."` | An `@` tag isn't shaped like `# @command: value` — a missing colon, an empty value, or a capital letter in the *command* part (`@Speaker`). (The *value* may have capitals — `@speaker: Dispatcher` — as long as the Cue Name matches exactly; if not, you get "No SpeakerLink named" instead.) |
| `Two "@..." cues on one beat` | The same command appears twice on one story line — keep one. |
| `Story uses cues but there is no NarrativeStage in the scene tree` | The `Stage` node (inside `NarrativeScene`) is missing from the running scene — usually `NarrativeScene` was deleted from `Main/WorldRoot` or the Stage was removed. Put it back (undo, or re-instance `scenes/narrative/NarrativeScene.tscn` under `WorldRoot`). |
| `No SpeakerLink named "..."` | The cue value doesn't match any SpeakerLink's Cue Name — the message lists the names that do exist. Fix the spelling in Inky (then re-export the JSON) or in the link's Cue Name, and press Play again. |
| `SpeakerLink "..." has no Display Name` | Select that link under `Stage/Links` and fill in Display Name. |
| `NarrativeStage is missing its ... reference` | Select `Stage` and assign the reference it names (Background, Left Portrait, Right Portrait, or Speaker Label). |
| `NarrativeScene found no NarrativeDirector` | `Main.tscn` has no `NarrativeDirector` under `Managers` — put it back (undo, or add a Node named NarrativeDirector with `scenes/managers/NarrativeDirector.gd` attached). |
| `NarrativeScene is missing Inspector references` | Select `NarrativeScene` and assign the references it lists. |
| `Choice N does not exist` | Code called `choose()` with a bad number — choices are numbered from 0. |

## Little tweaks (Inspector first)

- **Play a different story:** open `Main.tscn`, select `NarrativeDirector` →
  Inspector → **Story File** → pick your exported `.json`. The example story
  can stay in `stories/`; nothing else to remove.
- **Change the background picture:** select `NarrativeScene/Stage/Background`
  → Inspector → **Texture** → pick an image (drag it into the FileSystem
  dock first). This is the picture behind everything.
- **Bigger story text:** select `StoryText` (under
  `NarrativeScene/DialogueBox/Rows/StoryScroll`) → Inspector → Theme
  Overrides → Font Sizes → **Normal Font Size**.
- **Bigger speaker name:** select `SpeakerLabel` → Theme Overrides → Font
  Sizes → **Font Size**. (A Label calls it Font Size; the RichTextLabel
  above calls it Normal Font Size — same idea.)
- **Dialogue box color or transparency:** select `DialogueBox` → Theme
  Overrides → Styles → **Panel** → click the StyleBoxFlat → **BG Color**.
- **Taller/shorter dialogue box:** select `DialogueBox`, then in the
  Inspector open **Layout → Transform**: the box is pinned to the bottom of
  the screen, so its height is the **Offset Top** number — more negative =
  taller (−254 is the default; try −320). Or just drag its top edge in the
  2D view.
- **Move or resize a portrait slot:** select `LeftPortrait` or
  `RightPortrait` under `Stage` and drag it in the 2D view, or edit its
  offsets in Layout.
- **Style the choice buttons:** open `scenes/ui/ChoiceButton.tscn`, select the
  Button, use Theme Overrides (colors, font size, styleboxes). Every choice
  updates at once.
- **Where the choices appear:** select `ChoicesScroll` → Layout → adjust its
  anchors/offsets (it is centered in the upper-middle of the screen).
- **Text adventure look (lines pile up):** select `NarrativeScene` →
  Inspector → **Presentation Mode** → `Build Down`.
- **Auto-play reading speed:** select `NarrativeScene` → Inspector →
  Auto Play → **Auto Play Seconds Per Character** (higher = slower) and
  **Auto Play Min Seconds** (the shortest *automatic* wait — a manual click
  can still advance sooner).
- **Start with auto-play already on:** select `AutoPlayToggle` → Inspector →
  Button Pressed → **On**.
- **Rename or restyle the Auto switch:** select `AutoPlayToggle` — its Text
  property and Theme Overrides are ordinary Button settings.
- **Change the advance key (code tweak — assistant writes it, student pastes it):** in
  `scenes/narrative/NarrativeScene.gd`, `_unhandled_input` checks Godot's
  built-in `ui_accept` action (Space/Enter). Example — advance on any key
  press instead:

  ```gdscript
  func _unhandled_input(event: InputEvent) -> void:
      if event is InputEventKey and event.pressed and not event.echo:
          _advance()
  ```

  (`not event.echo` stops a held-down key from racing through the story.)

## Publishing to the web (HTML5)

The finished game ships as a browser game. This project already includes a
ready **Web** export preset (Project → Export…): Thread Support is off (so
the game runs on any ordinary web host with no special server setup), and it
exports to the project's `html_export/` folder as `index.html`. Compiled Ink
`.json` story files are included automatically — JSON is a normal Godot
resource, no extra filter needed. Click **Export Project…** and you're done.
(First time on a new machine: Editor → Manage Export Templates → download.)

A web export **cannot run by double-clicking `index.html`** (`file://` is
blocked by browsers). It needs a web server: an upload site works, or locally
run `python3 -m http.server 8000` in a terminal inside `html_export/` and
open `http://localhost:8000`.

Browsers also pause a game whose tab is in the background — auto-play seems
to stop, then resumes when the player returns to the tab. Normal, not a bug.

| Works in the editor, broken in the browser | Likely fix |
|---|---|
| Red `Cannot open Ink JSON` only in the browser | The story file was added after the last export, or sits outside the project folder — check its path, then re-export. |
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

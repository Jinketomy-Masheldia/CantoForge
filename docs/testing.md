# Manual testing guide

Use this guide to share device results; completing every item is not a
prerequisite for submitting a useful report. Test with copies of scores.

## Record your environment

- Port release/tag and iPad bundle revision (the diagnostic log records it).
- iPad model and iPadOS version.
- Finger, Pencil, mouse/trackpad or external keyboard input.
- Score format and size; note any external storage provider used.

## Priority 1: preserve score data

1. Create a small score and enter a few notes.
2. Edit its title and another text element; tap blank canvas to finish editing.
3. Undo and redo both notation and text changes.
4. Save as MSCZ, close, and reopen the saved file.
5. Copy it to a computer and open it in official desktop Studio. Check notes,
   text, instrumentation and layout.
6. Edit again, open another score, and exercise save/discard/cancel. Cancelling
   must keep the current score and changes.
7. Background and foreground the app; check that it remains usable and that
   saved data is intact. Do not rely on autosave as the only backup.

## Priority 2: common workflows

- Open a score through Files/document import; edit and save the local copy.
- Play/pause with bundled MS Basic, adjust mixer settings and check sound.
- Export a small score as PDF, MusicXML, MIDI and one audio format. Verify the
  exported files with an appropriate external viewer/player/application.
- For revision 11 and later, export AAC at 32/44.1/48 kHz and several available
  bit rates. Play each file through its final notes and compare its duration
  with the score. Switching from MP3 to AAC must display a supported bit rate.
- Open preferences and switch between pages.
- Open/close About, score creation, export and other dialogs.
- Open File → Open Recent; repeatedly switch submenu rows, then dismiss outside.
- Swipe vertically on palette category titles, symbol cells and Layout rows;
  each should scroll without reordering. Check docked and floating panels.
- Drag the iPad grip on a palette category or Layout row to reorder it. Holding
  that grip must not open a context menu; holding the row body still should.
- Open Clefs and drag a symbol horizontally toward the score, then move it
  freely and drop it. Tap a symbol and drag its corner grip to reorder it in
  an editable palette: the original symbol follows the finger, the target cell
  is outlined, and the order changes only on release. Check first-to-last and
  last-to-first moves, a grip tap, release outside the grid, and touch cancellation.
  Read-only grids must not show a reorder grip. Check the More popup and mouse
  dragging separately; use the symbol body to drag onto the score.
- Drag the score with a finger, tap notes, and long-press for a context menu.
- Tap a movable element to select it, then drag it with a finger. The element
  should move without panning the page. Undo and redo the edit.
- Select a slur/tie and drag each square grip to adjust its shape. Also check
  that a swipe on blank canvas or an unselected element still pans normally.
- Hold a selected element/grip before dragging: a context menu must not take
  over that edit gesture. Long-press an unselected element for its context menu.
- With a mouse, press an unselected movable element and drag without releasing
  the button. Check grip dragging, double-click text editing and secondary click.
- Add a second finger while dragging, then resume scrolling/editing. The
  interrupted drag must finish cleanly and remain undoable.
- In note input, check that a drag or long press does not insert an extra note.

## Priority 3: additional coverage

- External mouse secondary click, hover and keyboard shortcuts.
- Text input with different languages, composition and software keyboards.
- Apple Pencil, portrait rotation and system windowing modes.
- MIDI input/output, Braille, accessibility and audio interruptions.
- Larger scores, additional import/export formats, plug-ins that do not require
  external processes, unusual dialogs and storage providers.

## Report one reproducible issue at a time

Use this repository's **Bug report** form. Describe expected and actual
behavior and provide exact steps. Attach a minimal MSCZ/MusicXML file only
if you have permission to share it; a ZIP may be easier to attach.

For crashes, include the application log and a matching native `.ips` report
if available. For visual/input bugs, a short recording helps. Check attachments
for private score titles, filenames and device details before posting.

If the same issue occurs in official desktop Studio, note its version.
Do not assume every port issue is an upstream defect.

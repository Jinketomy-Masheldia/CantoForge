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
   In particular, edit a tempo marking, exit text editing, and immediately edit
   the same marking again without another action. Repeat and check typing,
   selection, copy/paste, context menus and both touch and external input.
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
- Reorder palette categories, symbol cells and Layout rows with a mouse.
  Touch input must not reorder these items or show extra drag grips.
- Open Clefs and drag a symbol horizontally toward the score, then move it
  freely and drop it. Check the same gesture in the More popup and with a mouse.
  Dragging a symbol back into a palette with a finger must not change its order.
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

### Build 23 crash regression checks

- Repeat the tempo text edit / exit / immediate re-entry sequence described
  above. Also switch directly to another text element or a dialog field.
- Verify native text selection, edit/context menus, copy/paste, undo/redo,
  software keyboard input and external keyboard/mouse input.
- Repeatedly launch the app and load scores with MS Basic. Check that audio
  playback and diagnostic logging continue to work.
- On the Mac, `bash buildscripts/ios/check-logger.sh` checks that removing a
  logger output waits for its active write, and exercises concurrent output
  add/remove/clear/write against the actual vendored logger. Use
  `CANTOFORGE_LOGGER_TSAN=1 bash buildscripts/ios/check-logger.sh` to run the
  same probe with ThreadSanitizer. These host checks do not validate UIKit UI.

### System MP4 export (new source)

- Export a short score with a title, a page change and repeats, using both
  full-page and flexible layout at 1080p. Play the result in Files and check
  that the playback cursor follows the sound and that the audio is complete.
- Check 1440p/4K, Unicode filenames and different audio sample rates/bit rates.
- Cancel during frame generation and during finalization; the app must remain
  responsive, stop the export and permit another export afterwards.
- Check that page layout, visibility settings and the saved score are unchanged
  after export/cancellation. Check export of an extracted part and several parts.
- The maintainer-run Mac backend probe passed 1080p/4K picture/audio decoding,
  colors/orientation, duration, Unicode names and error/cancellation handling.
  The maintainer additionally reports stable score video export on the M2 iPad
  with build 20; this does not establish compatibility with other devices or
  every score. Build 21 translation/layout and update testing remain pending.

### Native iPad printing (newer source)

- From File > Print, check the system print UI, preview, page count and title
  for a multi-page score and a part, including Unicode names.
- Repeat from page, continuous and other score views. Cancelling or completing
  the dialog must retain the original view and editing state.
- Check portrait/landscape and custom paper sizes. A transparent PDF export
  preference must not remove the print page background.
- Cancel and reopen; press the print shortcut repeatedly while the system UI
  is open. Only the active job should remain, without stale content or crashes.
- With an AirPrint printer (or an available Apple Printer Simulator), check
  discovery, page ranges, copies, paper selection and cancellation/error behavior.
  Validate actual physical output, margins and duplex separately on real hardware.
- Until those tests are completed, describe native printing as unverified on
  devices/printers, rather than claiming that it was tested by compiling alone.

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

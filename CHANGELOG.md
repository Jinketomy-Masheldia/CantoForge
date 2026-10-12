# Changelog

## v0.1.0-alpha.2 — 2026-10-12

- Restored finger dragging of selected score elements and slur/tie grips without
  panning the page. Mouse users can still press and drag an unselected element.
- Gave score-editing drags priority over long-press context menus and preserved
  external mouse secondary clicks.
- Let vertical finger swipes scroll palette categories, symbol grids and Layout
  rows. Panel reordering is mouse-only; experimental touch reorder grips and
  previews were removed to restore the original panel appearance.
- Retained horizontal-first touch dragging of palette symbols onto the score.
- Removed the empty fullscreen bottom strip and deferred bottom-edge system
  gestures to reduce accidental exits while editing.
- Targeted host input checks and the arm64 build passed. The maintainer reports
  the final build works well on the test iPad; broader device testing is pending.
- iPad bundle build 19. The port release version remains separate from the
  upstream MuseScore Studio 4.7.5 version.

## v0.1.0-alpha.1 — 2026-10-12

- First experimental CantoForge release, based on MuseScore Studio 4.7.5.
- Adopted the CantoForge name, independent icon and `com.jmx.cantoforge` identity.
- Updated onboarding, About information and Simplified/Traditional Chinese text.
- Disabled cloud publishing/save controls, welcome promotions and desktop update settings on iPad.
- Used Apple AudioToolbox for iOS AAC export; FDK-AAC is not linked.
- Removed local checkout paths from compiler records and excluded macOS metadata from IPA packaging.
- Included matching application/dependency sources, build information and notices in the release materials.
- See the earlier development entries below for the platform and input adaptations.

## Release candidate preparation — 2026-10-11

- Replaced the iOS FDK-AAC encoder with Apple AudioToolbox while retaining
  AAC-LC/ADTS `.aac` export, streaming float PCM input and final-frame flushing.
- Removed FDK-AAC from the iOS target's sources and link dependencies.
- Made AAC bit rate choices reflect the system encoder's supported settings
  and update when the sample rate or export format changes.
- Added encoder finalization error reporting and a reproducible native AAC probe.
- Added optional in-bundle application/dependency license notices for release builds.
- Kept the existing desktop interface, app name, icon and bundle identifier.
- Increased the candidate iPad bundle revision to 11; a public release tag
  remains a separate maintainer action.

## Unreleased — publication snapshot, 2026-10-11

Based on MuseScore Studio 4.7.5. The internal iPad bundle revisions 1–10
were personal development builds, not public release versions. No
`v0.1.0-alpha.1` release is declared by this document.

### Platform support

- Added an `app-ios` configuration, arm64 iPad bundle, CMake presets and
  command-line build/unsigned-IPA packaging helpers.
- Preserved the desktop app shell, editor, palettes, inspector and mixer.
- Excluded desktop-only integrations from the iPad configuration.
- Added AudioQueue/AVAudioSession output and iOS CoreMIDI integration.
- Bundled fonts, SoundFonts, translations, score templates and Braille tables.
- Added security-scoped external document import into local Documents storage,
  file sharing, single-document replacement and application-state handling.
- Added a fullscreen app entry and status-bar hiding.

### Interface and input fixes

- Linked static Qt QML/style plug-ins and corrected startup module/type exports.
- Added selectable, copyable startup interface-error diagnostics.
- Corrected dropdown navigation/aliases used by preferences, export and score
  creation, and guarded failed dialog/page creation.
- Replaced the unavailable cloud score-manager path with a website fallback.
- Added long-press context menus with progress feedback and movement cancellation.
- Made canvas touch panning immediate after a small movement threshold while
  preserving note-entry taps and cancelling tap actions during drags/holds.
- Added touch menu highlighting, persistent submenus and guarded deferred cleanup.
- Preserved the original top menu appearance and prevented finger-generated
  hover from switching to another application menu.
- Added an iPad secondary-pointer bridge for external mouse right clicks.
- Sized the About dialog to its content so the existing confirmation button
  is not clipped.
- Deferred text-popup cleanup and the iOS input-method refresh when ending
  score-text editing. The reported title-editing crash had no native stack;
  wider input-method/device testing is still needed.
- Preserved iOS fatal-signal handling so remaining crashes can generate native
  system reports instead of exiting through the desktop fallback handler.

### Publication preparation

- Added English port documentation, provenance notices and a release checklist.
- Added port-specific issue/PR templates and contribution instructions.
- Removed inherited official release/translation/triage workflows and bot
  configuration from this publication copy; no replacement CI is claimed.
- Removed the early Chinese feasibility note and inherited blame-ignore hashes
  that do not belong to this repository's imported history.
- Preserved the upstream README separately and retained licenses/resources.
- Based the publication branch on upstream `v4.7.5` commit
  `3654226c2e99289916916953a98e585a3d3b315a`, retaining upstream Git history.
- Excluded two generated liblouis headers; CMake recreates them from the
  tracked source templates during configuration.

### Verification limits

The arm64 development build and IPA integrity checks passed. Targeted host
Qt checks covered interface loading, preferences, score creation, menus,
touch input, the About dialog and title editing. Those development probes
were local build artifacts and are not part of the repository's test suite.
The owner reports that many functions work on the M2 iPad. This is not a
complete acceptance result for every feature, format, device or OS version.

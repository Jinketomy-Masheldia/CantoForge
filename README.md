# MuseScore Studio for iPad — Unofficial Port

An experimental iPadOS port of **MuseScore Studio 4.7.5**, preserving the
desktop interface and core notation features.

**This project is not affiliated with or endorsed by MuseScore or Muse Group.**
It is a personal, community-oriented port of the open-source desktop Studio
application. It is not the official MuseScore mobile application.

## Status

The port launches and is usable on the maintainer's 11-inch iPad Pro (2022,
M2), running iPadOS 26.6 as reported by the owner. Many workflows have been
reported usable, but there has not been a complete feature or device audit.
Use copies of important scores while testing.

| Area | Current status |
| --- | --- |
| Desktop interface and score editor | Retained; basic use reported working on the test iPad |
| Score creation, preferences and export dialogs | Platform fixes implemented; targeted host runtime checks passed |
| Playback | CoreAudio output and bundled SoundFont synthesis implemented |
| Files integration | Document import, local score storage and file sharing implemented |
| Touch input | Single-finger canvas panning, tap selection, long-press context menus and touch-aware submenus implemented |
| External mouse and keyboard | Desktop input retained; iPad secondary-click bridge implemented; accessory-specific behavior needs testing |
| Text editing | Title-editing exit and popup-lifetime fixes included; broader input-method testing remains open |
| Import and export formats | Core modules retained; every format has not been verified on iPad |

The build targets **arm64 iPads with iPadOS 17.0 or later**. This is the
configured deployment target, not a claim that all supported OS versions or
iPad models have been tested. Portrait layouts, multitasking, Apple Pencil,
accessibility and larger-score performance need additional reports.

MuseSounds/MuseSampler, desktop VST plug-ins, the desktop updater, subprocess
multiwindow support, cloud integration, automation and video export are
disabled in the iPad configuration. Experimental MNX import/export is disabled
by the helper script. Printing and some desktop/native dialogs remain
unverified. Script/QML extensions are retained, but external-process APIs
are unavailable.

## Build and install

Build on macOS with Xcode, CMake, Ninja, matching Qt iOS/macOS kits, and
HarfBuzz sources. The development build used **Qt 6.11.2** and the
**iPhoneOS 26.5 SDK**.

See [Build and installation instructions](docs/ios-port.md).

The helper generates an **unsigned IPA**. Sign it with your own compatible
sideloading workflow. Signing credentials are not included. No App Store
release is planned for this project at present.

## Testing and feedback

- Read the [manual testing guide](docs/testing.md).
- Report port-specific issues in **this repository's Issues tab**.
- Include the port/bundle revision, iPad model, iPadOS version, input device,
  reproduction steps and a minimal score where possible.
- Logs are available through Files in the application's Documents directory.
  Native crash reports may also be available in iPadOS Analytics Data.

Do not send port-only issues to the upstream team as official Studio bugs.
If the same problem occurs in the official desktop application, say so in
the report so it can be assessed for upstream reporting.

## Source, licensing and releases

The `ipad-port` branch is based on upstream tag **`v4.7.5`**, commit
`3654226c2e99289916916953a98e585a3d3b315a`, and preserves its Git history.
It includes the iPadOS adaptations developed in October 2026. The upstream
development branch is separate from this port; select `ipad-port` when
browsing or cloning the iPad source.

The application is licensed under **GNU GPL version 3**; see [LICENSE.txt](LICENSE.txt).
Existing copyright notices and the upstream font exception are retained.
Third-party libraries, fonts and SoundFonts retain their individual licenses.
See [provenance and notices](NOTICE.md).

Public IPA release materials are still being prepared. In particular, Qt is
statically linked: the repository's automatic source archive alone does not
provide all corresponding dependency sources for an IPA. Follow the
[release preparation guide](docs/releasing.md) before distributing binaries.
This repository preparation is not a completed license audit or a public
binary release.

## Contributing

Bug reports, device testing, documentation fixes and focused patches are
welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

Substantial parts of the port and its documentation were developed with
assistance from **OpenAI Codex**, using build/runtime checks and the
maintainer's device feedback. Further human review and device testing are
welcome; this disclosure does not imply full feature verification.

## Upstream and acknowledgements

- [MuseScore Studio source](https://github.com/musescore/MuseScore)
- [MuseScore.org](https://musescore.org/)
- [Original upstream README](docs/upstream/README.md)

MuseScore Studio, its contributors and the authors of Qt and the bundled
dependencies provide the editor, engraving engine and other foundations of
this port. The original desktop source and resource licenses are preserved.
Project names and trademarks belong to their respective owners; the code
license does not itself grant trademark rights.

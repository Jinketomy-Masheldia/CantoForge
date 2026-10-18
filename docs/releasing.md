# Preparing CantoForge releases

CantoForge is an unofficial iPadOS port of MuseScore Studio 4.7.5. Public
releases use the CantoForge name, the maintainer-supplied logo, and
`com.jmx.cantoforge`. Keep upstream copyrights and component notices intact.

## Prepared v0.1.0 release

The prepared release is **v0.1.0**, iPad bundle build **24**, to be published as
an ordinary release (not a pre-release). Earlier alpha/beta releases must remain
separate and must not be overwritten or retagged. The configured device target
is arm64 with iPadOS 17.0 or later.

The maintainer tested build 23 on an 11-inch iPad Pro (2022, M2), through
LiveContainer. Its crash reports show iPadOS 27.0.1. The previously reproducible
tempo-text edit / exit / immediate re-entry crash and related text/menu/input
checks passed according to the maintainer. Build 24 packages the same runtime
changes from the recorded release commit with updated publication metadata.
Physical AirPrint output remains unverified; this is not a complete
feature/device/install compatibility audit.

The iOS AAC backend uses Apple AudioToolbox. FDK-AAC remains in the upstream
source collection for other platforms but is not linked into the iOS app.

## Source and binary preparation

1. Work on `ipad-port`, based on upstream `v4.7.5`. Review the changes and
   exclude build output, personal logs, signing files and credentials.
2. Update README/NOTICE/CHANGELOG and build/install instructions. Retain
   application, dependency, font and SoundFont notices.
3. Commit the reviewed source and record the full commit. Tag that commit
   with the port release version; record the upstream version separately.
4. Build the device IPA with a new bundle revision and
   `MUE_IOS_INCLUDE_RELEASE_NOTICES=ON`. Supply matching Qt Sources using
   `MUE_QT_SOURCE_DIR`. Build from the recorded commit with no later source
   changes; otherwise record and rebuild the final source instead.
5. Audit the IPA for personal paths, signatures, provisioning profiles,
   credentials, logs and macOS metadata. Do not publish private audit output.
6. Prepare matching application source with `git archive`. Provide the
   separately installed Qt 6.11.2 Sources component, matching Qt kit build
   evidence and HarfBuzz 12.3.0 sources. Unchanged dependency materials may be
   explicitly linked to existing release downloads, with SHA-256 hashes and
   clear access instructions alongside the binary. Check their accessibility
   before publication and keep them available while distributing the binary.
   If a link is unavailable, upload the matching archive directly instead.
   Sources of vendored components and
   their build definitions remain in the application archive. Do not include
   Apple SDKs, signing credentials or personal build directories.
7. Record the source commit, bundle revision, build tools/options, dependency
   versions and SHA-256 checksums. State the actual scope of device testing.
8. Upload the unsigned IPA, matching source materials, build/release
   information and checksums to one GitHub Release. Publish v0.1.0 as an ordinary release and mark it as the latest release.
9. Check that the published downloads and recorded source commit are present.
   Keep corresponding source materials accessible while distributing a binary.

## Release assets

- `CantoForge-v0.1.0-iPad-unsigned.ipa`
- `CantoForge-v0.1.0-source.tar.gz`
- `CantoForge-v0.1.0-build-info.json`
- `DEPENDENCIES.md`: exact links and hashes of the unchanged Qt sources,
  Qt supplier build evidence and HarfBuzz sources from alpha.1.
- `SOURCE-MANIFEST.json`, `PACKAGE-AUDIT.json`, `RELEASE-INFO.md`, and `SHA256SUMS`

These eight files include only one IPA. The three unchanged dependency archives
are prepared separately as fallback attachments:

- `qt-6.11.2-maintenance-tool-source.tar.gz`
- `qt-6.11.2-ios-build-evidence.tar.gz`
- `harfbuzz-12.3.0.tar.xz`

The Qt source and supplier archives contain the unchanged base Qt 6.11.2
materials. The text-overlay fix is provided in the application source archive
as `buildscripts/ios/qt-patches/text-menu-lifetime.patch`, with build helpers
that regenerate the modified platform library locally. Record both the base
and patched artifact hashes in build information.

Qt is statically linked. GitHub's automatic repository source ZIP does not
include Qt or separately downloaded dependency sources. The release assets
provide or explicitly link the separately prepared materials alongside the
application source. Installation requires only the IPA; source and metadata
files are for building, verification and source availability.
Qt modules and their third-party components retain their applicable licenses;
do not describe the complete dependency collection as having a single license.

## Installation and feedback

The IPA is unsigned. Users sign it with their own compatible sideloading
workflow. The public app uses a different identifier from early personal
builds and may install as a separate application. Back up/export scores before
removing the older app. Report port issues in the CantoForge repository.

This guide describes release preparation. It does not claim exhaustive
runtime testing or a legal certification. The manual test guide is in
[testing.md](testing.md); build instructions are in [ios-port.md](ios-port.md).

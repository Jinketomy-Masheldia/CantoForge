# Preparing CantoForge releases

CantoForge is an unofficial iPadOS port of MuseScore Studio 4.7.5. Public
releases use the CantoForge name, the maintainer-supplied logo, and
`com.jmx.cantoforge`. Keep upstream copyrights and component notices intact.

## First release

The first release is **v0.1.0-alpha.1**, marked as a **pre-release**. The
configured device target is arm64 with iPadOS 17.0 or later. The maintainer
reports usability on an 11-inch iPad Pro (2022, M2); this is not a complete
device/feature compatibility audit.

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
   evidence and HarfBuzz 12.3.0 sources. Sources of vendored components and
   their build definitions remain in the application archive. Do not include
   Apple SDKs, signing credentials or personal build directories.
7. Record the source commit, bundle revision, build tools/options, dependency
   versions and SHA-256 checksums. State the actual scope of device testing.
8. Upload the unsigned IPA, matching source materials, build/release
   information and checksums to one GitHub Release. Mark it as a pre-release.
9. Check that the published downloads and recorded source commit are present.
   Keep corresponding source materials accessible while distributing a binary.

## Release assets

- `CantoForge-v0.1.0-alpha.1-iPad-unsigned.ipa`
- `CantoForge-v0.1.0-alpha.1-source.tar.gz`
- `qt-6.11.2-maintenance-tool-source.tar.gz`
- `qt-6.11.2-ios-build-evidence.tar.gz`
- `harfbuzz-12.3.0.tar.xz`
- `CantoForge-v0.1.0-alpha.1-build-info.json`
- `SOURCE-MANIFEST.json`, `RELEASE-INFO.md`, and `SHA256SUMS`

Qt is statically linked. GitHub's automatic repository source ZIP does not
include Qt or separately downloaded dependency sources. The release assets
provide the separately prepared materials alongside the application source.
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

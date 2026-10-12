# Building and installing the iPadOS port

This is an unofficial native Qt/C++ port of MuseScore Studio 4.7.5. It uses
the desktop app shell and core editor. For current scope and limitations,
see the [project README](../README.md).

## Requirements

- macOS with Xcode and an installed iPhoneOS SDK.
- CMake supporting preset format version 6 (CMake 3.25 or later), and Ninja.
- Matching Qt iOS and macOS kits. Development used **Qt 6.11.2**.
- HarfBuzz **12.3.0** sources; preparation is shown below.
- Enough disk space for the source, Qt kits, dependencies and build output.

The development build used the iPhoneOS 26.5 SDK. The configured deployment
target is iPadOS 17.0 and the device architecture is arm64. Device reports
currently come from an 11-inch iPad Pro (2022, M2) with iPadOS 26.6 reported
by its owner. Other combinations are not established as tested.

The macOS-only Homebrew Qt package cannot replace the Qt iOS kit. Install
both the iOS kit and matching macOS host tools for the same Qt version.

## 1. Get the source

Clone this repository with GitHub Desktop or Git and select the `ipad-port`
branch, which is based on upstream tag `v4.7.5`:

```sh
git clone --branch ipad-port https://github.com/Jinketomy-Masheldia/CantoForge.git
cd CantoForge
```

Run the commands below from the repository root. A GitHub source ZIP can
also be used if it includes
all source and resource files; do not use a binary-only package for building.

This baseline has its framework and dependencies in-tree and does not require
the `muse`/`muse_deps` submodules used by the later upstream development branch.

## 2. Check the tools

```sh
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-path
cmake --version
ninja --version
```

If Xcode tools are missing, finish Xcode's first-launch setup and select the
intended Xcode installation. Check that the installed SDK supports the
device you intend to use.

## 3. Prepare HarfBuzz

```sh
mkdir -p build/ios-deps
curl -fL https://github.com/harfbuzz/harfbuzz/releases/download/12.3.0/harfbuzz-12.3.0.tar.xz \
  -o build/ios-deps/harfbuzz-12.3.0.tar.xz
```

The build helper extracts this archive under `build/ios-deps`. Alternatively,
set `MUE_HARFBUZZ_SOURCE_DIR` to an existing HarfBuzz 12.3.0 source directory
containing `src/hb-ft.h`. The downloaded/extracted dependency is ignored by
Git; it is not included in a fresh clone.

## 4. Select Qt and build for a device

Adjust the paths if Qt is installed elsewhere:

```sh
export QT_IOS_DIR="$HOME/Qt/6.11.2/ios"
export QT_HOST_DIR="$HOME/Qt/6.11.2/macos"
buildscripts/ios/build.sh device -DMUE_IOS_BUNDLE_VERSION=19
```

`QT_IOS_DIR/lib/cmake/Qt6/qt.toolchain.cmake` must exist. The helper configures
and builds the `ios-device` preset, then packages the app. It uses up to six
parallel jobs by default. To use fewer jobs:

```sh
export MUSE_IOS_BUILD_JOBS=3
```

The bundle revision is independent of Studio's version number. Increase it
for later personal builds so diagnostics identify the installed revision.

Outputs:

| Output | Path |
| --- | --- |
| App bundle | `build/ios-device/src/app/mscore.app` |
| Unsigned IPA | `build/ios-device/ipa/CantoForge-iPad-unsigned.ipa` |

The helper overwrites the unsigned IPA output on a subsequent successful
package. Preserve separately named copies when comparing builds.

Qt is linked statically. Bundled resources include MS Basic and FluidR3Mono
SoundFonts, translations, templates and liblouis Braille tables. Desktop
HarfBuzz/FreeType binaries are not used as iOS dependencies.

AAC export on iOS uses Apple's system AudioToolbox encoder and retains the
`.aac` ADTS format. The AAC export dialog queries the system codec and offers
only supported bit rates for the chosen sample rate. FDK-AAC remains in the
upstream source tree for other platforms and is not linked into the iOS app.

For a public release candidate, install the matching **Qt Sources** component
and include dependency notices in the bundle:

```sh
buildscripts/ios/build.sh device -DMUE_IOS_BUNDLE_VERSION=19 \
  -DMUE_IOS_INCLUDE_RELEASE_NOTICES=ON \
  -DMUE_QT_SOURCE_DIR="$HOME/Qt/6.11.2/Src"
```

The notices are under `Payload/mscore.app/licenses` inside the IPA. The
matching complete dependency sources must also accompany the release.

To check the Apple AAC writer on macOS using the same backend source:

```sh
bash buildscripts/ios/check-aac.sh
```

This probe encodes and decodes audio, checks supported bit rates, irregular
buffer sizes, final audio, a short stream, UTF-8 paths and failure paths.
It requires access to the system audio codec registry; a restricted execution
environment may not expose the codecs. It does not replace an iPad export test.

Experimental MNX import/export is disabled by the helper because it needs
an additional fetched dependency. It can be enabled explicitly with
`-DMUE_BUILD_IMPEXP_MNX_MODULE=ON` after supplying that dependency. This has
not been established as a tested iPad workflow.

## 5. Application identity

The iPad app is named **CantoForge** and uses **com.jmx.cantoforge**. Its icons
come from the maintainer-supplied logo under `buildscripts/packaging/iOS/icons`.
The packaging helper expects this identity.

Use the same identifier for subsequent updates. The older personal development
identifier was `org.musescore.MuseScore.ipad`; changing identifiers can install
a separate app. Export or back up scores before deleting an older version.

## 6. Sign and install for personal testing

The output IPA is **unsigned**. Import it into a compatible SideStore,
AltStore or other signing/sideloading workflow and use your own account.
Signing requirements and renewal behavior depend on the tool and account.
An unsigned `.app` or IPA cannot be installed directly as a normal signed app.

No signing certificate, private key, provisioning profile or Apple ID
credential is included. This guide does not describe App Store submission.
Before sharing binaries publicly, follow [the release guide](releasing.md).

After installation, open the app and use [the manual testing guide](testing.md).
Start with a copy of a small score, then save it, reopen it, play it and check
the result in official desktop Studio.

## Simulator preset

```sh
buildscripts/ios/build.sh simulator
```

The current `ios-simulator` preset specifies **x86_64**, matching the Qt
simulator libraries available during development. It is not an established
arm64 simulator configuration. CoreSimulator runtime execution was not
available in the development environment; do not treat this preset as a
verified simulator run. Device builds are the primary tested build path.

## Diagnostics

In Files, open the app's shared Documents directory. For the current
development configuration, logs are under:

```text
MuseScore4Development/Diagnostics
```

Find the log created during the failing run. Startup interface failures
also show a selectable message and a **Copy all error text** button when Qt
can render the diagnostic view.

For native crashes, look in iPadOS **Settings → Privacy & Security →
Analytics & Improvements → Analytics Data** for a matching `mscore` or
MuseScore report, if available. Revision 10 preserves the system's fatal
signal handling so it can produce a native report. A normal application
log may end without a stack trace and is not a substitute for that report.

Logs and reports may contain filenames and device details. Remove private
information before attaching them publicly. Include the iPad bundle revision,
input device and exact reproduction steps in this repository's issue form.

## Troubleshooting

- **Qt kit not found:** check both Qt environment variables and version matching.
- **HarfBuzz source missing:** download the archive or set its source directory.
- **Configuration changes seem ineffective:** use a separate build directory
  or a clean build when changing Qt kits, SDKs or platform settings. Preserve
  files you need before removing generated build output.
- **An interface page fails:** collect its full QML error and application log.
- **A score fails to save/export:** report the format and destination, and use
  a minimal score if possible. Formats/providers have not all been tested.
- **A web action behaves differently:** cloud integration is disabled; some
  actions use external website fallbacks.

## Verification boundaries

Release arm64 builds, static QML deployment and IPA/resource checks passed
during development. Targeted native host Qt probes covered the previously
reported interface/input problems, including the title-editing exit path.
Those probes were generated under the local build directory and are not
a committed, reproducible iPad runtime suite.

The owner reports successful launch and broad usability on the M2 iPad.
There is no complete format/device acceptance matrix. Input methods,
accessories, accessibility, multitasking, print dialogs, audio interruptions
and complex score workflows still need physical-device testing.

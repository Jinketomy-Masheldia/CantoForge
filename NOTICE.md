# Provenance and notices

## Upstream application

The initial port was developed from a MuseScore Studio 4.7.5 source snapshot.
The publication branch is now based on upstream tag `v4.7.5`, commit
`3654226c2e99289916916953a98e585a3d3b315a`, preserving the upstream Git history.
The snapshot's source/resources were compared with that baseline before
the iPadOS changes and publication documentation were migrated.

Upstream: https://github.com/musescore/MuseScore

The upstream license identifies:

> Copyright (C) 1999-2026 MuseScore Limited and others

The application remains under GNU GPL version 3 as described in
[LICENSE.txt](LICENSE.txt), including the existing font exception. Copyright
and license notices in individual files remain in place.

## iPadOS modifications

The iPadOS adaptations were developed in October 2026. This publication
snapshot documents those changes through **2026-10-12**. See [CHANGELOG.md](CHANGELOG.md)
for their scope and the repository history for subsequent changes and authors.

This is an unofficial project, maintained separately from MuseScore and
Muse Group. It does not represent an official mobile release or endorsement.
The iPad application uses the independent name **CantoForge**, the maintainer's
supplied logo, and the bundle identifier **com.jmx.cantoforge**. Upstream
copyright and component attribution remain intact. Upstream resource files,
manuals, tutorials and links are retained where applicable. No affiliation,
endorsement or separate permission to use upstream trademarks is claimed.

Substantial port and documentation work used OpenAI Codex assistance.
Maintainer device feedback and targeted build/runtime checks informed the
changes. This is a provenance disclosure, not a claim of complete human
review or exhaustive compatibility testing.

## Third-party components and resources

An application-level GPL notice does not replace the licenses and notices
of its dependencies or assets. Keep the notices shipped with the source
and resources, including:

- Third-party C/C++ libraries under `thirdparty/` and `src/**/thirdparty/`.
- Font licenses under `fonts/`.
- SoundFont notices in [MS Basic_License.md](share/sound/MS%20Basic_License.md)
  and [FluidR3Mono_License.md](share/sound/FluidR3Mono_License.md).
- Qt and other dependencies obtained separately when building.

This list describes where notices can be found; it is not an exhaustive
bill of materials or a completed dependency-license audit.

## Binary distribution status

The first public release is prepared as **v0.1.0-alpha.1**. Its release
materials identify the source revision and include the unsigned IPA, matching
application/dependency source archives, build information, notices and
checksums. See [docs/releasing.md](docs/releasing.md).

No signing certificate, private signing key, provisioning profile or account
credential is intended to be part of this repository or a public release.
The Crashpad test key and its generator are upstream test fixtures, not
credentials for installing or signing this application.

The iOS AAC encoder uses Apple AudioToolbox, provided by the operating system.
FDK-AAC remains in the upstream source tree for other platforms but is not
compiled or linked into this iOS binary. Release builds can bundle application,
Qt and dependency notices using `MUE_IOS_INCLUDE_RELEASE_NOTICES=ON`.

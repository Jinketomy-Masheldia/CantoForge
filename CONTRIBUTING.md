# Contributing

This repository maintains an unofficial iPadOS port of MuseScore Studio.
Please use English for issue reports, pull requests and project documentation.
Existing upstream translations and third-party source remain unchanged.

## Bug reports and testing

Report port-specific issues in this repository using the Bug report form.
Include the port/bundle revision, iPad model, iPadOS version, input device,
exact steps, expected/actual behavior and relevant diagnostics. A minimal
score or short recording is useful when it can be shared.

Read [docs/testing.md](docs/testing.md) for suggested checks. Device test
results and documentation corrections are welcome without code changes.

## Patches

1. Fork this repository and create a focused branch from `ipad-port`.
2. Follow [docs/ios-port.md](docs/ios-port.md) to build when code changes require it.
3. Preserve the desktop appearance and score-editing behavior unless a change
   is necessary for iPad compatibility or agreed in the issue/PR discussion.
4. Keep platform adaptations scoped so desktop builds are not accidentally
   changed. Preserve existing file copyright and license notices.
5. Describe the change, the problem it solves and how it was checked. State
   clearly when hardware/OS behavior has not been tested.
6. Submit a pull request to this repository. Do not include build output,
   private scores, personal logs, generated IPAs or signing credentials.

Contributions must be compatible with the project's GPLv3 licensing and
the applicable licenses of the files being changed. This port does not ask
contributors to sign the upstream MuseScore CLA for a pull request here.
Contributions submitted separately upstream follow upstream's own rules.

Disclose substantial AI assistance in your PR description. For commits that
contain substantially AI-assisted work, use an `Assisted-by:` trailer naming
the tool; do not assign an AI tool human authorship or CLA responsibility.

Upstream development guidance is available at
https://github.com/musescore/MuseScore/wiki/Contributing.

## Community conduct

Follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). The repository maintainer
moderates this project's issues and pull requests independently of upstream.
For conduct concerns involving public content, GitHub's reporting tools can
be used. If the maintainer lists a private contact method on their GitHub
profile, use it for sensitive concerns; do not post private information in
a public issue. No dedicated private reporting channel is currently listed
in this repository.

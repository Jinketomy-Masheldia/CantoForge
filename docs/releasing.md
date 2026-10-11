# Preparing a public release

This repository preparation does not publish an IPA and is not a completed
dependency-license audit. The application still uses development branding
and a development bundle identifier. Keep binary releases as drafts until
their corresponding source and notices are ready.

## Source publication

- Work from `ipad-port`, based on upstream `v4.7.5` commit
  `3654226c2e99289916916953a98e585a3d3b315a`. Publish this branch to the fork
  and make it the default branch before announcing the iPad project. The
  upstream development branch is a separate version and build architecture.
- Keep `LICENSE.txt`, original file notices, dependency licenses and resource
  attribution. State the upstream version, modification date and unofficial
  status in README/NOTICE/CHANGELOG.
- Review the files to be committed. Exclude build output, development IPAs,
  personal logs and signing/account credentials.
- The inherited official GitHub Actions, triage and translation automation
  have been removed from this publication copy. No replacement CI is configured.
- Clone or download the uploaded source into a fresh directory and follow
  `ios-port.md`. Record whether that independent build succeeds. This clean
  publication-copy build remains a pending preparation step.

## Before publishing an IPA

1. Choose the public application name, independent artwork and a bundle
   identifier controlled by the maintainer. Preserve upstream attribution.
   The code license does not itself grant rights to trademarks.
2. Freeze a source commit and tag, for example `v0.1.0-alpha.1`. Record the
   upstream Studio version separately from the port version and bundle revision.
3. Record Xcode/SDK, Qt kit version, build options and all linked dependency
   versions. Determine the actual license option for the Qt modules used.
4. Prepare complete corresponding source materials for the application and
   applicable dependencies. Qt is statically linked; include the matching Qt
   sources, relevant modifications and other required dependency sources,
   including HarfBuzz. Inventory the actual build instead of assuming a short
   list covers everything. Preserve third-party/font/SoundFont notices.
5. Provide clear build and installation instructions. Distinguish source
   dependencies from generally available build tools and system SDKs. Do not
   redistribute Apple SDKs or account credentials as dependency source.
6. Build the IPA from that frozen source and run the priority data-preservation
   checks in `testing.md`. State which device/features were actually tested.
7. Inspect the final package and its license materials. Publish an unsigned
   IPA for users to sign with their own compatible workflow. Include no personal
   signing key, certificate, provisioning profile or account credentials.
8. Place the IPA, source/dependency materials and release notes together in
   a GitHub Release draft. Explicitly identify which source commit produced
   the IPA and where the matching dependency sources can be obtained.
9. Mark the first release as a **pre-release**. Verify download links and
   source completeness before publishing. Keep corresponding source accessible
   for every binary version still being distributed.

A GitHub-generated source ZIP covers this repository's tracked files, not
the separately installed Qt kit or downloaded build dependencies. Linking
only to the original upstream application source does not describe this
modified binary. Supplying complete, clearly identified source archives
alongside the IPA is the simplest initial release arrangement.

## Suggested release note

```text
Unofficial experimental iPadOS port of MuseScore Studio 4.7.5.
Not affiliated with or endorsed by MuseScore or Muse Group.

Port version: [tag]
Source commit: [commit]
iPad bundle revision: [revision]
Tested device and iPadOS: [actual result]
Configured minimum OS: iPadOS 17.0; other versions may be untested.

Installation: unsigned IPA; sign with your own compatible sideloading tool.
Test with copies of scores. Full feature/device compatibility is not established.

Changes: [summary]
Known issues: [list]
Application source: [download/link]
Dependency sources and license notices: [downloads/links]
Build/install instructions: [link]
Report port issues in this repository.
```

## References

- [GNU GPLv3](https://www.gnu.org/licenses/gpl-3.0.html)
- [GNU distribution FAQ](https://www.gnu.org/licenses/gpl-faq.en.html)
- [Qt open-source licensing obligations](https://www.qt.io/development/open-source-lgpl-obligations)
- [GitHub release management](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

Consult the actual licenses for the chosen build. This checklist is a
release preparation aid, not a certification of compliance.

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Collect source notices and Qt supplier attribution for an unsigned iPad bundle."""
import argparse
import json
import re
import shutil
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--project', type=Path, required=True)
parser.add_argument('--qt-source', type=Path, required=True)
parser.add_argument('--qt-kit', type=Path, required=True)
parser.add_argument('--harfbuzz-source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)


def copy(source, relative):
    assert source.is_file(), f'Missing notice: {source}'
    destination = args.output / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


for name in ('LICENSE.txt', 'NOTICE.md', 'README.md'):
    copy(args.project / name, Path('application') / name)
notices = re.compile(r'(license|licence|copying|copyright|notice|authors|attribution)', re.I)
for folder in ('src', 'thirdparty', 'fonts', 'share/sound'):
    for source in (args.project / folder).rglob('*'):
        if not source.is_file() or not notices.search(source.name):
            continue
        relative = source.relative_to(args.project)
        if 'fdk-aac' in relative.parts or '.git' in relative.parts:
            continue # Retained in the source tree, but never linked into the iOS build.
        if folder == 'src' and 'thirdparty' not in relative.parts:
            continue
        copy(source, Path('application') / relative)
copy(args.harfbuzz_source / 'COPYING', Path('harfbuzz-12.3.0/COPYING'))

modules = ['qtbase', 'qtdeclarative', 'qt5compat', 'qtimageformats', 'qtlottie',
           'qtnetworkauth', 'qtquick3d', 'qtshadertools', 'qtsvg', 'qttools', 'qttranslations']
attributions = []
for module in modules:
    source = args.qt_source / module
    assert (source / '.tag').is_file(), f'Qt Sources component missing: {module}'
    for notice in source.rglob('*'):
        if notice.is_file() and (notices.search(notice.name) or 'LICENSES' in notice.parts):
            copy(notice, Path('qt') / module / notice.relative_to(source))
    for attribution in source.rglob('qt_attribution.json'):
        # Some supplier files include literal line breaks in their JSON strings.
        data = json.loads(attribution.read_text(), strict=False)
        for item in data if isinstance(data, list) else [data]:
            attributions.append({'module': module, 'source_location': str(attribution.relative_to(source)), **item})
            license_files = item.get('LicenseFile', [])
            if isinstance(license_files, str):
                license_files = [license_files]
            for name in license_files:
                if name:
                    file = (attribution.parent / name).resolve()
                    copy(file, Path('qt') / module / file.relative_to(source.resolve()))
    for spdx in (args.qt_kit / 'sbom').glob(module + '-*.spdx.json'):
        copy(spdx, Path('qt/sbom') / spdx.name)
    copy(source / '.tag', Path('qt') / module / 'SOURCE_COMMIT')

(args.output / 'qt-attribution.json').write_text(json.dumps(attributions, indent=2, ensure_ascii=False) + '\n')
(args.output / 'README.txt').write_text('''CantoForge - Unofficial iPadOS Port of MuseScore Studio
Not affiliated with or endorsed by MuseScore or Muse Group.

This application derives from MuseScore Studio 4.7.5 under GNU GPL version 3,
with the existing font exception. Original copyrights and component licenses
are retained. See application/LICENSE.txt and application/NOTICE.md.

AAC export on iOS uses Apple AudioToolbox, a system framework. FDK-AAC is not
linked into this iOS binary. Qt is statically linked using its GPLv3-compatible
open-source licensing options; third-party components retain their own licenses.

This directory preserves vendored notices and Qt supplier attribution. Some
entries also cover source components not used by this particular executable.
Font/SoundFont notices are included; additional file-level notices are retained
in the complete corresponding source archives supplied with the release.

Project source and build instructions:
https://github.com/Jinketomy-Masheldia/CantoForge

Download the matching application and dependency source archives alongside
the IPA in its GitHub Release. See that release's source manifest and checksums.
No Apple SDK, signing certificate or provisioning profile is redistributed.
''')
print(f'Collected {sum(p.is_file() for p in args.output.rglob("*"))} notice/attribution files')

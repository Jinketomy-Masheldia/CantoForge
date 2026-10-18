#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Patch one Qt iOS source/object in the build tree; never modify the Qt kit."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def run(*args):
    return subprocess.check_output(args, text=True)


parser = argparse.ArgumentParser(description=__doc__)
commands = parser.add_subparsers(dest='command', required=True)
source = commands.add_parser('source')
source.add_argument('--source', type=Path, required=True)
source.add_argument('--patch', type=Path, required=True)
source.add_argument('--output', type=Path, required=True)
archive = commands.add_parser('archive')
archive.add_argument('--library', type=Path, required=True)
archive.add_argument('--object', type=Path, required=True)
archive.add_argument('--arch', required=True)
archive.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.output = args.output.resolve()
args.output.parent.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix='qt-text-input-', dir=args.output.parent) as temp:
    temp = Path(temp)
    if args.command == 'source':
        patched = temp / args.output.name
        # Strict application fails on an incompatible Qt source instead of
        # silently compiling the unpatched platform code.
        subprocess.run(['/usr/bin/patch', '--batch', '--forward', '--silent', '--fuzz=0',
                        '--output', str(patched), str(args.source.resolve()),
                        str(args.patch.resolve())], check=True)
        if not args.output.exists() or patched.read_bytes() != args.output.read_bytes():
            shutil.copyfile(patched, args.output)
    else:
        library = args.library.resolve()
        replacement = args.object.resolve()
        member = 'qiostextinputoverlay.mm.o'
        if replacement.name != member:
            raise SystemExit(f'Unexpected Qt replacement object: {replacement.name}')
        arches = run('xcrun', 'lipo', '-archs', str(library)).split()
        if args.arch not in arches:
            raise SystemExit(f'Qt platform library does not contain {args.arch}')
        if run('xcrun', 'lipo', '-archs', str(replacement)).split() != [args.arch]:
            raise SystemExit('Replacement object architecture does not match the app')
        patched = temp / args.output.name
        if len(arches) == 1:
            shutil.copyfile(library, patched)
        else:
            run('xcrun', 'lipo', str(library), '-thin', args.arch, '-output', str(patched))
        if run('xcrun', 'ar', '-t', str(patched)).splitlines().count(member) != 1:
            raise SystemExit('Expected exactly one Qt text input overlay object')
        run('xcrun', 'ar', '-rcs', str(patched), str(replacement))
        os.replace(patched, args.output)
        print(f'Built Qt iOS platform library with text-menu lifetime fix ({args.arch})')

#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
studio_root=$(cd "$(dirname "$0")/../.." && pwd)
build_dir=${1:-"$studio_root/build/ios-device"}
app="$build_dir/src/app/mscore.app"
if [[ ! -f "$app/mscore" ]]; then
    echo "Build MuseScoreStudio first: missing $app/mscore" >&2
    exit 1
fi
package_dir="$build_dir/ipa"
mkdir -p "$package_dir"
staging=$(mktemp -d "$package_dir/.staging.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/Payload"
# Keep an unsigned deliverable for the user's signing/sideloading tool.
# Always start from an empty payload so removed resources cannot survive rebuilds.
ditto "$app" "$staging/Payload/mscore.app"
ipa="$package_dir/MuseScoreStudio-iPad-unsigned.ipa"
ditto -c -k --keepParent "$staging/Payload" "$staging/unsigned.ipa"
mv -f "$staging/unsigned.ipa" "$ipa"
echo "Unsigned IPA: $ipa"

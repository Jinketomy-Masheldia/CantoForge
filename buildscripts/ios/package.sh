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
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
display_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$app/Info.plist")
if [[ "$bundle_id" != "com.jmx.cantoforge" || "$display_name" != "CantoForge" ]]; then
    echo 'Rebuild the app with the CantoForge configuration before packaging.' >&2
    exit 1
fi
package_dir="$build_dir/ipa"
mkdir -p "$package_dir"
staging=$(mktemp -d "$package_dir/.staging.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/Payload"
# Keep an unsigned deliverable for the user's signing/sideloading tool.
# Always start from an empty payload so removed resources cannot survive rebuilds.
ditto --norsrc --noextattr --noacl "$app" "$staging/Payload/mscore.app"
ipa="$package_dir/CantoForge-iPad-unsigned.ipa"
ditto --norsrc --noextattr --noacl -c -k --keepParent "$staging/Payload" "$staging/unsigned.ipa"
mv -f "$staging/unsigned.ipa" "$ipa"
echo "Unsigned IPA: $ipa"

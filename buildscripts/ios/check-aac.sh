#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
studio_root=$(cd "$(dirname "$0")/../.." && pwd)
probe_dir="$studio_root/build/aac-probe"
mkdir -p "$probe_dir"
encoder_dir="$studio_root/src/framework/audio/engine/platform/ios"
xcrun --sdk macosx clang++ -std=c++17 -Wall -Wextra -Werror \
    -I"$encoder_dir" "$encoder_dir/appleaacwriter.cpp" \
    "$studio_root/buildscripts/ios/tests/aac_export_probe.cpp" \
    -framework AudioToolbox -framework CoreFoundation -o "$probe_dir/aac-export-probe"
"$probe_dir/aac-export-probe" "$probe_dir/files"

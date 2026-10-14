#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
studio_root=$(cd "$(dirname "$0")/../.." && pwd)
probe_dir="$studio_root/build/video-probe"
qt_host_dir=${QT_HOST_DIR:-"$HOME/Qt/6.11.2/macos"}
audio_file=${1:-"$studio_root/build/aac-probe/files/aac-probe.aac"}
mkdir -p "$probe_dir"
encoder_dir="$studio_root/src/framework/media/internal/platform/apple"
xcrun --sdk macosx clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror -Wno-deprecated-declarations \
    -F"$qt_host_dir/lib" -I"$qt_host_dir/lib/QtCore.framework/Headers" \
    -I"$qt_host_dir/lib/QtGui.framework/Headers" -I"$encoder_dir" \
    "$encoder_dir/applevideowriter.mm" "$studio_root/buildscripts/ios/tests/video_export_probe.mm" \
    -framework QtCore -framework QtGui -framework AVFoundation -framework CoreMedia \
    -framework CoreVideo -framework Foundation -Wl,-rpath,"$qt_host_dir/lib" \
    -o "$probe_dir/video-export-probe"
"$probe_dir/video-export-probe" "$probe_dir/files" "$audio_file"

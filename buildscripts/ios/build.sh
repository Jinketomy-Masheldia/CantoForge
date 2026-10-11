#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

studio_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$studio_root"
platform=${1:-device}
if [[ $# -gt 0 ]]; then shift; fi
case "$platform" in
    device|simulator) ;;
    *) echo 'Usage: buildscripts/ios/build.sh [device|simulator] [CMake -D options...]' >&2; exit 2 ;;
esac

export QT_IOS_DIR=${QT_IOS_DIR:-"$HOME/Qt/6.11.2/ios"}
export QT_HOST_DIR=${QT_HOST_DIR:-"$(dirname "$QT_IOS_DIR")/macos"}
if [[ ! -f "$QT_IOS_DIR/lib/cmake/Qt6/qt.toolchain.cmake" ]]; then
    echo 'Set QT_IOS_DIR to the Qt iOS kit, and QT_HOST_DIR to the matching macOS kit.' >&2
    exit 1
fi

harfbuzz_src=${MUE_HARFBUZZ_SOURCE_DIR:-"$studio_root/build/ios-deps/harfbuzz-12.3.0"}
if [[ ! -f "$harfbuzz_src/src/hb-ft.h" && -f "$studio_root/build/ios-deps/harfbuzz-12.3.0.tar.xz" ]]; then
    tar -xf "$studio_root/build/ios-deps/harfbuzz-12.3.0.tar.xz" -C "$studio_root/build/ios-deps"
fi
if [[ ! -f "$harfbuzz_src/src/hb-ft.h" ]]; then
    echo 'Provide HarfBuzz 12.3.0 sources via MUE_HARFBUZZ_SOURCE_DIR; see docs/ios-port.md.' >&2
    exit 1
fi

# MNX is experimental and needs a separate network-fetched dependency. Enable
# with -DMUE_BUILD_IMPEXP_MNX_MODULE=ON once that dependency is available.
cmake --preset "ios-$platform" \
    "-DMUE_HARFBUZZ_SOURCE_DIR=$harfbuzz_src" \
    -DMUE_BUILD_IMPEXP_MNX_MODULE=OFF "$@"
cmake --build --preset "ios-$platform" --parallel "${MUSE_IOS_BUILD_JOBS:-6}"

if [[ "$platform" == device ]]; then
    "$studio_root/buildscripts/ios/package.sh" "$studio_root/build/ios-device"
fi

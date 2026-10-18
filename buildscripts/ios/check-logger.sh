#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
studio_root=$(cd "$(dirname "$0")/../.." && pwd)
probe_dir="$studio_root/build/logger-probe"
logger_dir="$studio_root/src/framework/global/thirdparty/kors_logger/src"
mkdir -p "$probe_dir"
sanitizer=(-g)
if [[ "${CANTOFORGE_LOGGER_TSAN:-0}" == 1 ]]; then
    sanitizer+=(-fsanitize=thread)
fi
xcrun --sdk macosx clang++ -std=c++17 -Wall -Wextra -Werror -pthread \
    "${sanitizer[@]}" -I"$logger_dir" \
    "$logger_dir/logger.cpp" "$logger_dir/logdefdest.cpp" \
    "$studio_root/buildscripts/ios/tests/logger_lifetime_probe.cpp" \
    -o "$probe_dir/logger-lifetime-probe"
"$probe_dir/logger-lifetime-probe"

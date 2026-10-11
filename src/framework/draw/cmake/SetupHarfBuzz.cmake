# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-CLA-applies
#
# MuseScore
# Music Composition & Notation
#
# Copyright (C) 2024 MuseScore Limited and others
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

if (MUE_COMPILE_USE_SYSTEM_HARFBUZZ)
    find_package(HarfBuzz)

    if (HarfBuzz_FOUND)
        message(STATUS "Found HarfBuzz")

        # See HarfBuzz's harfbuzz-config.cmake, which is quite minimalistic
        set(HARFBUZZ_LIBRARIES harfbuzz::harfbuzz)
        set(HARFBUZZ_INCLUDE_DIRS ${HARFBUZZ_INCLUDE_DIR})

        return()
    else()
        message(WARNING "Set MUE_COMPILE_USE_SYSTEM_HARFBUZZ=ON, but system harfbuzz not found, built-in will be used")
    endif()
endif()

# If not MUE_COMPILE_USE_SYSTEM_HARFBUZZ, or if it was not found,
# download and build harfbuzz

set(MUE_HARFBUZZ_SOURCE_DIR "" CACHE PATH "Local HarfBuzz source tree (for offline/cross builds)")
if(MUE_HARFBUZZ_SOURCE_DIR)
    if(NOT EXISTS "${MUE_HARFBUZZ_SOURCE_DIR}/src/hb-ft.h")
        message(FATAL_ERROR "MUE_HARFBUZZ_SOURCE_DIR must contain HarfBuzz sources including src/hb-ft.h")
    endif()
    set(HB_HAVE_FREETYPE ON CACHE BOOL "Enable HarfBuzz FreeType integration" FORCE)
    set(HB_BUILD_UTILS OFF CACHE BOOL "Do not cross-build HarfBuzz tools" FORCE)
    set(HB_BUILD_SUBSET OFF CACHE BOOL "Do not build HarfBuzz subset library" FORCE)
    function(muse_add_local_harfbuzz)
        # This is an app dependency, not an independently installed SDK.
        set(SKIP_INSTALL_ALL ON)
        add_subdirectory("${MUE_HARFBUZZ_SOURCE_DIR}" "${PROJECT_BINARY_DIR}/harfbuzz")
    endfunction()
    muse_add_local_harfbuzz()
    set(HARFBUZZ_LIBRARIES harfbuzz)
    set(HARFBUZZ_INCLUDE_DIRS "${MUE_HARFBUZZ_SOURCE_DIR}/src")
    return()
endif()

set(REMOTE_ROOT_URL https://raw.githubusercontent.com/musescore/muse_deps/legacy)
set(remote_url ${REMOTE_ROOT_URL}/harfbuzz/12.3.0)
set(local_path ${PROJECT_BINARY_DIR}/_deps/harfbuzz)
if (EXISTS ${local_path}/harfbuzz.cmake)
    file(SIZE ${local_path}/harfbuzz.cmake harfbuzz_script_size)
endif()
if (NOT EXISTS ${local_path}/harfbuzz.cmake OR harfbuzz_script_size EQUAL 0)
    file(MAKE_DIRECTORY ${local_path})
    file(DOWNLOAD ${remote_url}/harfbuzz.cmake ${local_path}/harfbuzz.cmake
        HTTPHEADER "Cache-Control: no-cache"
        STATUS download_status
    )
    list(GET download_status 0 download_code)
    if(NOT download_code EQUAL 0)
        file(REMOVE ${local_path}/harfbuzz.cmake)
        message(FATAL_ERROR "HarfBuzz download failed: ${download_status}. Set MUE_HARFBUZZ_SOURCE_DIR to a local source tree for offline builds.")
    endif()
endif()

include(${local_path}/harfbuzz.cmake)

# func from ${name}.cmake)
cmake_language(CALL harfbuzz_Populate ${remote_url} ${local_path} "source" "" "")

set(HB_HAVE_FREETYPE ON)

add_subdirectory(${local_path}/harfbuzz harfbuzz)

target_no_warning(harfbuzz -Wno-conversion)
target_no_warning(harfbuzz -Wno-unused-parameter)
target_no_warning(harfbuzz -Wno-unused-variable)
target_no_warning(harfbuzz -WMSVC-no-hides-previous)
target_no_warning(harfbuzz -WMSVC-no-unreachable)

#add_subdirectory(thirdparty/msdfgen)

set(HARFBUZZ_LIBRARIES harfbuzz)
set(HARFBUZZ_INCLUDE_DIRS ${local_path}/harfbuzz/harfbuzz/src)

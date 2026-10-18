# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies
#
# MuseScore Studio
# Music Composition & Notation
#
# Copyright (C) 2026 MuseScore Limited and others
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
# along with this program. If not, see <https://www.gnu.org/licenses/>.

muse_create_module(print)

target_sources(print PRIVATE
    printmodule.cpp
    printmodule.h
    iprintprovider.h

    internal/printprovider.h
)

if (OS_IS_IOS)
    enable_language(OBJCXX)
    target_sources(print PRIVATE internal/platform/ios/iosprintprovider.mm)
    set_source_files_properties(internal/platform/ios/iosprintprovider.mm PROPERTIES
        COMPILE_OPTIONS "-fobjc-arc" SKIP_PRECOMPILE_HEADERS ON SKIP_UNITY_BUILD_INCLUSION ON)
    find_library(PRINT_UIKIT_FRAMEWORK NAMES UIKit REQUIRED)
    target_link_libraries(print PRIVATE ${PRINT_UIKIT_FRAMEWORK})
else()
    target_sources(print PRIVATE internal/printprovider.cpp)
    target_link_libraries(print PRIVATE Qt::PrintSupport)
endif()

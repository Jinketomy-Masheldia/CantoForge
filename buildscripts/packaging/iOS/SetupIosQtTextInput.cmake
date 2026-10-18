# SPDX-License-Identifier: GPL-3.0-only
# Recompile only Qt's text overlay and replace its archive member in a local
# copy. The rest of the installed platform plugin, including native text
# selection, clipboard, keyboard and pointer handling, is unchanged.
enable_language(OBJCXX)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

if(NOT MUE_QT_SOURCE_DIR)
    get_filename_component(qt_sources_default "${QT_INSTALL_PREFIX}/../Src" ABSOLUTE)
    set(MUE_QT_SOURCE_DIR "${qt_sources_default}" CACHE PATH "Matching Qt Sources component" FORCE)
endif()
set(qt_overlay_dir "${MUE_QT_SOURCE_DIR}/qtbase/src/plugins/platforms/ios")
if(NOT EXISTS "${qt_overlay_dir}/qiostextinputoverlay.mm")
    message(FATAL_ERROR "Install matching Qt Sources and set MUE_QT_SOURCE_DIR; the iOS text-menu crash fix needs them.")
endif()
file(STRINGS "${MUE_QT_SOURCE_DIR}/qtbase/.cmake.conf" qt_source_version_line
    REGEX "^set\\(QT_REPO_MODULE_VERSION ")
if(NOT qt_source_version_line MATCHES "\"${Qt6Core_VERSION}\"")
    message(FATAL_ERROR "MUE_QT_SOURCE_DIR must match the installed Qt ${Qt6Core_VERSION} kit.")
endif()
list(LENGTH CMAKE_OSX_ARCHITECTURES qt_patch_arch_count)
if(NOT qt_patch_arch_count EQUAL 1)
    message(FATAL_ERROR "Build one iOS architecture at a time (as in the ios-device/ios-simulator presets).")
endif()

set(qt_patch_dir "${PROJECT_BINARY_DIR}/qt-ios-text-input")
set(qt_patch_script "${PROJECT_SOURCE_DIR}/buildscripts/ios/prepare-qt-ios.py")
set(qt_patch "${PROJECT_SOURCE_DIR}/buildscripts/ios/qt-patches/text-menu-lifetime.patch")
set(qt_patched_overlay "${qt_patch_dir}/qiostextinputoverlay.mm")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${qt_overlay_dir}/qiostextinputoverlay.mm" "${qt_patch}" "${qt_patch_script}")
execute_process(COMMAND "${Python3_EXECUTABLE}" "${qt_patch_script}" source
    --source "${qt_overlay_dir}/qiostextinputoverlay.mm"
    --patch "${qt_patch}" --output "${qt_patched_overlay}"
    COMMAND_ERROR_IS_FATAL ANY)

add_library(cantoforge_qt_ios_text_input OBJECT "${qt_patched_overlay}")
set_target_properties(cantoforge_qt_ios_text_input PROPERTIES
    AUTOMOC OFF AUTOUIC OFF AUTORCC OFF UNITY_BUILD OFF DISABLE_PRECOMPILE_HEADERS ON)
target_include_directories(cantoforge_qt_ios_text_input PRIVATE "${qt_overlay_dir}")
target_link_libraries(cantoforge_qt_ios_text_input PRIVATE Qt6::CorePrivate Qt6::GuiPrivate)
target_compile_options(cantoforge_qt_ios_text_input PRIVATE
    -fno-objc-arc "-ffile-prefix-map=${MUE_QT_SOURCE_DIR}=/QtSources")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(qt_plugin_config DEBUG)
else()
    set(qt_plugin_config RELEASE)
endif()
get_target_property(qt_original_plugin Qt6::QIOSIntegrationPlugin "IMPORTED_LOCATION_${qt_plugin_config}")
set(qt_patched_plugin "${qt_patch_dir}/libqios.a")
add_custom_command(OUTPUT "${qt_patched_plugin}"
    COMMAND "${Python3_EXECUTABLE}" "${qt_patch_script}" archive
        --library "${qt_original_plugin}" --object $<TARGET_OBJECTS:cantoforge_qt_ios_text_input>
        --arch "${CMAKE_OSX_ARCHITECTURES}" --output "${qt_patched_plugin}"
    DEPENDS cantoforge_qt_ios_text_input $<TARGET_OBJECTS:cantoforge_qt_ios_text_input>
        "${qt_original_plugin}" "${qt_patch_script}"
    VERBATIM COMMAND_EXPAND_LISTS)
add_custom_target(cantoforge_qt_ios_platform DEPENDS "${qt_patched_plugin}")
set_property(TARGET Qt6::QIOSIntegrationPlugin PROPERTY "IMPORTED_LOCATION_${qt_plugin_config}" "${qt_patched_plugin}")
add_dependencies(MuseScoreStudio cantoforge_qt_ios_platform)
message(STATUS "Qt iOS text-menu lifetime fix enabled (build-local platform plugin)")

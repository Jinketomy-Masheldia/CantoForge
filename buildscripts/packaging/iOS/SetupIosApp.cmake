# SPDX-License-Identifier: GPL-3.0-only
set(MUE_IOS_BUNDLE_IDENTIFIER "com.jmx.cantoforge" CACHE STRING "iPad app bundle identifier")
# Migrate existing build directories that still cache the development identity.
if(MUE_IOS_BUNDLE_IDENTIFIER STREQUAL "org.musescore.MuseScore.ipad")
    set(MUE_IOS_BUNDLE_IDENTIFIER "com.jmx.cantoforge" CACHE STRING "iPad app bundle identifier" FORCE)
endif()
set(MUE_IOS_BUNDLE_VERSION "${CMAKE_BUILD_NUMBER}" CACHE STRING "Personal iPad app build revision")
option(MUE_IOS_INCLUDE_RELEASE_NOTICES "Bundle dependency notices for a public IPA" OFF)
set(MUE_QT_SOURCE_DIR "" CACHE PATH "Matching Qt Sources component")
if(CMAKE_OSX_SYSROOT MATCHES "[Ss]imulator")
    set(MUE_IOS_SUPPORTED_PLATFORM "iPhoneSimulator")
else()
    set(MUE_IOS_SUPPORTED_PLATFORM "iPhoneOS")
endif()

add_custom_command(TARGET MuseScoreStudio POST_BUILD
    COMMAND ${CMAKE_COMMAND}
        "-DSHORTCUTS_QML_TYPES=${PROJECT_BINARY_DIR}/src/framework/shortcuts/qml/Muse/Shortcuts/muse_shortcuts_qml.qmltypes"
        -P "${CMAKE_CURRENT_LIST_DIR}/VerifyIosQmlTypes.cmake"
    VERBATIM)
set_target_properties(MuseScoreStudio PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/Info.plist.in"
    MACOSX_BUNDLE_GUI_IDENTIFIER "${MUE_IOS_BUNDLE_IDENTIFIER}"
    MACOSX_BUNDLE_BUNDLE_NAME "CantoForge"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${MUSE_APP_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${MUE_IOS_BUNDLE_VERSION}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${MUE_IOS_BUNDLE_IDENTIFIER}"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2"
)

if(MUE_IOS_INCLUDE_RELEASE_NOTICES)
    if(NOT EXISTS "${MUE_QT_SOURCE_DIR}/qtbase/.tag")
        message(FATAL_ERROR "Set MUE_QT_SOURCE_DIR to the matching Qt Sources component for release notices.")
    endif()
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(notices_script "${PROJECT_SOURCE_DIR}/buildscripts/ios/collect-notices.py")
    set_property(TARGET MuseScoreStudio APPEND PROPERTY LINK_DEPENDS "${notices_script}")
    add_custom_command(TARGET MuseScoreStudio POST_BUILD
        COMMAND "${Python3_EXECUTABLE}" "${notices_script}"
            --project "${PROJECT_SOURCE_DIR}"
            --qt-source "${MUE_QT_SOURCE_DIR}"
            --qt-kit "${QT_INSTALL_PREFIX}"
            --harfbuzz-source "${MUE_HARFBUZZ_SOURCE_DIR}"
            --output "$<TARGET_BUNDLE_DIR:MuseScoreStudio>/licenses"
        VERBATIM)
endif()

# Precompiled PNG icons keep Ninja builds independent of CoreSimulator/actool.
foreach(icon AppIcon60x60@2x.png AppIcon76x76@2x~ipad.png AppIcon83.5x83.5@2x~ipad.png)
    set(icon_path "${CMAKE_CURRENT_LIST_DIR}/icons/${icon}")
    target_sources(MuseScoreStudio PRIVATE "${icon_path}")
    set_source_files_properties("${icon_path}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
endforeach()

# Install the same data directories used by desktop Studio in the iOS bundle.
# QML and engraving fonts already compiled as Qt resources remain unchanged.
foreach(resource_dir sound templates styles wallpapers workspaces extensions plugins)
    file(GLOB_RECURSE bundle_files CONFIGURE_DEPENDS
        "${PROJECT_SOURCE_DIR}/share/${resource_dir}/*")
    foreach(resource IN LISTS bundle_files)
        if(resource MATCHES "CMakeLists\\.txt$")
            continue()
        endif()
        file(RELATIVE_PATH relative "${PROJECT_SOURCE_DIR}/share" "${resource}")
        get_filename_component(resource_parent "${relative}" DIRECTORY)
        target_sources(MuseScoreStudio PRIVATE "${resource}")
        set_source_files_properties("${resource}" PROPERTIES
            HEADER_FILE_ONLY TRUE
            MACOSX_PACKAGE_LOCATION "Resources/${resource_parent}")
    endforeach()
endforeach()

# Braille conversion loads liblouis tables from the app's data directory.
if(MUE_BUILD_BRAILLE_MODULE)
    foreach(table_dir src/braille/tables src/braille/thirdparty/liblouis/tables)
        file(GLOB braille_tables CONFIGURE_DEPENDS
            "${PROJECT_SOURCE_DIR}/${table_dir}/*.ctb"
            "${PROJECT_SOURCE_DIR}/${table_dir}/*.cti"
            "${PROJECT_SOURCE_DIR}/${table_dir}/*.dis"
            "${PROJECT_SOURCE_DIR}/${table_dir}/*.mus"
            "${PROJECT_SOURCE_DIR}/${table_dir}/*.tbl"
            "${PROJECT_SOURCE_DIR}/${table_dir}/*.utb"
            "${PROJECT_SOURCE_DIR}/${table_dir}/*.uti")
        foreach(table IN LISTS braille_tables)
            target_sources(MuseScoreStudio PRIVATE "${table}")
            set_source_files_properties("${table}" PROPERTIES
                HEADER_FILE_ONLY TRUE
                MACOSX_PACKAGE_LOCATION "Resources/tables")
        endforeach()
    endforeach()
endif()

set(language_index "${PROJECT_SOURCE_DIR}/share/locale/languages.json")
target_sources(MuseScoreStudio PRIVATE "${language_index}")
set_source_files_properties("${language_index}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/locale")
if(TARGET translations)
    add_dependencies(MuseScoreStudio translations)
    add_custom_command(TARGET MuseScoreStudio POST_BUILD
        COMMAND ${CMAKE_COMMAND}
            "-DTRANSLATION_DIR=${PROJECT_BINARY_DIR}/share/locale"
            "-DQT_TRANSLATION_DIR=${QT_INSTALL_PREFIX}/translations"
            "-DAPP_BUNDLE=$<TARGET_BUNDLE_DIR:MuseScoreStudio>"
            -P "${CMAKE_CURRENT_LIST_DIR}/CopyIosTranslations.cmake"
        VERBATIM)
endif()

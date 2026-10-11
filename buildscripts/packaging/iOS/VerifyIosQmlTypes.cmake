# SPDX-License-Identifier: GPL-3.0-only
# Verify the public QML type needed to create AppWindow on iPad. The macOS
# platform-specific implementation is not part of the iOS build.
file(READ "${SHORTCUTS_QML_TYPES}" shortcut_types)
if(NOT shortcut_types MATCHES "Muse\\.Shortcuts/ShortcutsInstanceModel [0-9]+\\.[0-9]+")
    message(FATAL_ERROR "iPad startup requires a named Muse.Shortcuts/ShortcutsInstanceModel export")
endif()
message(STATUS "Verified iPad ShortcutsInstanceModel QML export")

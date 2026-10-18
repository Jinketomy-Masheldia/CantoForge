# Qt iOS text-menu lifetime patch

`text-menu-lifetime.patch` modifies Qt's `qiostextinputoverlay.mm` to invalidate
queued tap-menu requests when focus changes, a gesture is cancelled or a newer
tap starts. Callbacks retain their view and track the original Qt focus object
and window with `QPointer`. Menu delivery also checks the native window before
accessing it, and rechecks focus after synchronous context-menu delivery.

This addresses the build 22 main-thread crash in
`QIOSTapRecognizer::touchesEnded:withEvent:` / `showEditMenu`, at address `0x18`.
Related upstream tracking: https://bugreports.qt.io/browse/QTBUG-146020.
It preserves Qt's normal editing menus, text handles and keyboard input.

The patch was prepared against Qt **6.11.2**. iOS builds require the Qt Sources
component matching the installed kit (`MUE_QT_SOURCE_DIR`). CMake strictly
applies the patch to a build-local copy, compiles that source against the kit's
private headers, and replaces only `qiostextinputoverlay.mm.o` in a build-local
copy of the platform plugin. The installed Qt sources/libraries are untouched.
Build one architecture per build directory, as the existing presets do.
Incompatible sources fail configuration rather than omitting the fix.

When distributing the binary, provide this patch, the build helper and matching
Qt source archive as part of its corresponding sources. Original Qt copyright
and license headers are retained in the generated source. Qt's applicable
GPLv3-compatible license terms and third-party notices remain unchanged.

Build/link verification does not replace iPad regression testing: repeatedly
enter and leave text editing, switch text fields, and check selection, menus,
clipboard, keyboard and pointer behavior. No hardware validation is implied.

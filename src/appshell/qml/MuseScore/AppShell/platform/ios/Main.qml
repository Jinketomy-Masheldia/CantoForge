// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
// Explicit style imports make static builds include Studio's desktop controls
// and their Basic fallback rather than relying on runtime style selection.
import QtQuick.Controls.Fusion
import Muse.Ui
import Muse.UiComponents
import MuseScore.AppShell

// Keep Studio's desktop menu, dock panels, and editor on iPad.
AppWindow {
    id: root
    minimumWidth: 0
    minimumHeight: 0

    Loader {
        id: appMenuBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        source: "../AppMenuBar.qml"
        onLoaded: item.appWindow = root
    }

    WindowContent {
        id: window
        anchors.top: appMenuBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    Component.onCompleted: window.init()
}

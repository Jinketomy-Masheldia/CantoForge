/* SPDX-License-Identifier: GPL-3.0-only */
import QtQuick
import Muse.Ui

MouseArea {
    id: root

    property Item dragTarget
    property bool touchPress: false
    signal dragPressed(var mouse)
    signal dragReleased()
    signal dragCanceled()

    width: 32
    height: 32
    acceptedButtons: Qt.LeftButton
    Accessible.role: Accessible.Button
    Accessible.name: qsTrc("cantoforge/touch", "Drag to move or reorder")
    preventStealing: true
    drag.target: dragTarget
    drag.smoothed: false

    onPressed: function(mouse) {
        touchPress = ui.isTouchInput(root)
        if (touchPress) {
            ui.setTouchDragEditing(root, true)
        }
        root.dragPressed(mouse)
    }
    onReleased: {
        root.dragReleased()
        if (touchPress) {
            ui.setTouchDragEditing(root, false)
        }
    }
    onCanceled: {
        root.dragCanceled()
        if (touchPress) {
            ui.setTouchDragEditing(root, false)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: ui.theme.accentColor
        opacity: root.pressed ? ui.theme.accentOpacityHit : 0
    }
    StyledIconLabel {
        anchors.centerIn: parent
        iconCode: IconCode.TOOLBAR_GRIP
        font.pixelSize: 14
        opacity: root.enabled ? 0.7 : ui.theme.itemOpacityDisabled
    }
}
